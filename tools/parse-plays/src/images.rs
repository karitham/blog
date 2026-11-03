//! Build-time image mirroring: download every remote image referenced
//! by the stats document into a local cache directory and swap the
//! typed Image values to local paths.
//!
//! The cache is a small JSON manifest beside the image directory,
//! keyed by URL hash. Every entry records the file, content type, and
//! size, so the cache can be validated and garbage-collected instead
//! of guessed from filenames. Downloads are validated by magic bytes;
//! a 200 HTML error page never becomes a .jpg. Writes go through a
//! temp file plus rename, and the manifest is written atomically.

use crate::model::{Href, Image};
use crate::net::{HttpFetch, Limiter};
use crate::sources::RateLimits;
use crate::stats::StatsDocument;
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::path::{Path, PathBuf};

/// Generous cap — covers and artist photos are a few hundred KB.
const MAX_IMAGE_BYTES: u64 = 8 * 1024 * 1024;

/// Stable 16-hex FNV-1a 64 of a URL. The filename stays the same
/// across runs, so the existing cache survives the manifest upgrade.
pub fn short_hash(s: &str) -> String {
    let mut hash: u64 = 0xcbf29ce484222325;
    for b in s.as_bytes() {
        hash ^= *b as u64;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    format!("{hash:016x}")
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ImageKind {
    Jpeg,
    Png,
    Webp,
    Gif,
}

impl ImageKind {
    fn ext(self) -> &'static str {
        match self {
            ImageKind::Jpeg => "jpg",
            ImageKind::Png => "png",
            ImageKind::Webp => "webp",
            ImageKind::Gif => "gif",
        }
    }

    fn content_type(self) -> &'static str {
        match self {
            ImageKind::Jpeg => "image/jpeg",
            ImageKind::Png => "image/png",
            ImageKind::Webp => "image/webp",
            ImageKind::Gif => "image/gif",
        }
    }

    fn from_ext(ext: &str) -> Option<ImageKind> {
        match ext {
            "jpg" | "jpeg" => Some(ImageKind::Jpeg),
            "png" => Some(ImageKind::Png),
            "webp" => Some(ImageKind::Webp),
            "gif" => Some(ImageKind::Gif),
            _ => None,
        }
    }

    fn detect(bytes: &[u8]) -> Option<ImageKind> {
        if bytes.starts_with(&[0xff, 0xd8, 0xff]) {
            Some(ImageKind::Jpeg)
        } else if bytes.starts_with(b"\x89PNG\r\n\x1a\n") {
            Some(ImageKind::Png)
        } else if bytes.starts_with(b"GIF87a") || bytes.starts_with(b"GIF89a") {
            Some(ImageKind::Gif)
        } else if bytes.len() >= 12 && &bytes[0..4] == b"RIFF" && &bytes[8..12] == b"WEBP" {
            Some(ImageKind::Webp)
        } else {
            None
        }
    }
}

/// Which rate limiter an image host belongs to. Kept here, next to the
/// downloader, so adding a host doesn't silently borrow the Commons
/// limiter.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ImageSource {
    CoverArt,
    Bluesky,
    Commons,
}

impl ImageSource {
    fn for_url(url: &Href) -> Self {
        let url = url.as_ref();
        if url.starts_with("https://coverartarchive.org/") {
            ImageSource::CoverArt
        } else if url.starts_with("https://cdn.bsky.app/") || url.starts_with("https://bsky.app/") {
            ImageSource::Bluesky
        } else {
            ImageSource::Commons
        }
    }

    fn limiter(self, limits: &RateLimits) -> &Limiter {
        match self {
            ImageSource::CoverArt => &limits.coverart_img,
            ImageSource::Bluesky => &limits.bluesky,
            ImageSource::Commons => &limits.commons,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct CacheEntry {
    url: Href,
    file: String,
    content_type: String,
    bytes: u64,
}

#[derive(Default, Serialize, Deserialize)]
struct Manifest {
    entries: BTreeMap<String, CacheEntry>,
}

/// Owns one image directory plus its manifest. Read once at the start
/// of a run, written once at the end.
pub struct ImageStore {
    dir: PathBuf,
    manifest_path: PathBuf,
    url_prefix: String,
    manifest: Manifest,
}

impl ImageStore {
    /// Load the manifest beside the image directory. A missing or
    /// corrupt manifest is an empty cache, never a failure; existing
    /// hash-named files are adopted on the next mirror pass.
    pub fn load(dir: &Path, manifest_path: &Path, url_prefix: &str) -> Self {
        let manifest = std::fs::read_to_string(manifest_path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default();
        Self {
            dir: dir.to_path_buf(),
            manifest_path: manifest_path.to_path_buf(),
            url_prefix: url_prefix.trim_end_matches('/').to_string(),
            manifest,
        }
    }

    fn local(&self, file: &str) -> String {
        format!("{}/{}", self.url_prefix, file)
    }

    /// Mirror every unique remote URL into the store and return the
    /// remote to local path map. Downloads run in parallel under the
    /// per-source rate limiter; a failed or invalid download is simply
    /// absent from the map so the caller keeps the remote URL.
    pub fn mirror(
        &mut self,
        client: &dyn HttpFetch,
        limits: &RateLimits,
        urls: &[Href],
    ) -> Result<HashMap<Href, String>, String> {
        std::fs::create_dir_all(&self.dir)
            .map_err(|e| format!("failed to create {}: {e}", self.dir.display()))?;
        remove_temp_files(&self.dir);
        let files = scan_files(&self.dir);
        let existing = self.manifest.entries.clone();
        let unique: HashSet<&Href> = urls.iter().collect();
        let unique: Vec<&Href> = unique.into_iter().collect();

        let results: Vec<(Href, Option<String>, Option<CacheEntry>)> = unique
            .par_iter()
            .map(|url| {
                let hash = short_hash(url.as_ref());
                if let Some(entry) = existing.get(&hash)
                    && self.dir.join(&entry.file).is_file()
                {
                    return ((*url).clone(), Some(self.local(&entry.file)), None);
                }
                if let Some((file, kind)) = files.get(&hash) {
                    let entry = CacheEntry {
                        url: (*url).clone(),
                        file: file.clone(),
                        content_type: kind.content_type().to_string(),
                        bytes: std::fs::metadata(self.dir.join(file))
                            .map(|m| m.len())
                            .unwrap_or(0),
                    };
                    return ((*url).clone(), Some(self.local(file)), Some(entry));
                }

                ImageSource::for_url(url).limiter(limits).acquire();
                let Some((content_type, buf)) =
                    client.get_bytes(url.as_ref(), MAX_IMAGE_BYTES as usize)
                else {
                    return ((*url).clone(), None, None);
                };
                if buf.is_empty() || buf.len() as u64 > MAX_IMAGE_BYTES {
                    return ((*url).clone(), None, None);
                }
                let Some(kind) = ImageKind::detect(&buf) else {
                    return ((*url).clone(), None, None);
                };
                let file = format!("{hash}.{}", kind.ext());
                if !write_atomically(&self.dir, &file, &buf) {
                    return ((*url).clone(), None, None);
                }
                if let Some(old) = existing.get(&hash)
                    && old.file != file
                {
                    let _ = std::fs::remove_file(self.dir.join(&old.file));
                }
                let entry = CacheEntry {
                    url: (*url).clone(),
                    file: file.clone(),
                    content_type: if content_type.is_empty() {
                        kind.content_type().to_string()
                    } else {
                        content_type
                    },
                    bytes: buf.len() as u64,
                };
                ((*url).clone(), Some(self.local(&file)), Some(entry))
            })
            .collect();

        let mut rewrites = HashMap::new();
        for (url, local, entry) in results {
            if let Some(entry) = entry {
                self.manifest
                    .entries
                    .insert(short_hash(url.as_ref()), entry);
            }
            if let Some(local) = local {
                rewrites.insert(url, local);
            }
        }
        self.save()?;
        Ok(rewrites)
    }

    /// Drop entries and files that the current document no longer
    /// references. Keep by file name, not URL: the document may have
    /// been rewritten to local paths, and a resolution can succeed for
    /// an image that no top-N tile ends up using. Called after a
    /// successful mirror so an interrupted run never deletes a
    /// still-referenced image.
    pub fn gc_files(&mut self, keep_files: &HashSet<String>) -> Result<(), String> {
        let mut removed = Vec::new();
        self.manifest.entries.retain(|_, entry| {
            if keep_files.contains(&entry.file) {
                true
            } else {
                removed.push(entry.file.clone());
                false
            }
        });
        for file in removed {
            let _ = std::fs::remove_file(self.dir.join(file));
        }
        for (_, (file, _)) in scan_files(&self.dir) {
            if !keep_files.contains(&file) {
                let _ = std::fs::remove_file(self.dir.join(file));
            }
        }
        self.save()
    }

    fn save(&self) -> Result<(), String> {
        if let Some(parent) = self.manifest_path.parent() {
            std::fs::create_dir_all(parent)
                .map_err(|e| format!("failed to create {}: {e}", parent.display()))?;
        }
        let serialized = serde_json::to_string_pretty(&self.manifest)
            .map_err(|e| format!("failed to serialize image manifest: {e}"))?;
        let tmp = self.manifest_path.with_extension("json.tmp");
        std::fs::write(&tmp, serialized)
            .map_err(|e| format!("failed to write {}: {e}", tmp.display()))?;
        std::fs::rename(&tmp, &self.manifest_path)
            .map_err(|e| format!("failed to rename {}: {e}", tmp.display()))
    }
}

fn write_atomically(dir: &Path, file: &str, bytes: &[u8]) -> bool {
    let tmp = dir.join(format!("{file}.tmp"));
    if std::fs::write(&tmp, bytes).is_err() {
        let _ = std::fs::remove_file(&tmp);
        return false;
    }
    if std::fs::rename(&tmp, dir.join(file)).is_err() {
        let _ = std::fs::remove_file(&tmp);
        return false;
    }
    true
}

fn remove_temp_files(dir: &Path) {
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            if entry.file_name().to_string_lossy().ends_with(".tmp") {
                let _ = std::fs::remove_file(entry.path());
            }
        }
    }
}

/// Index complete image files by their 16-hex hash prefix. Directories
/// and temp files are ignored.
fn scan_files(dir: &Path) -> HashMap<String, (String, ImageKind)> {
    let mut by_hash = HashMap::new();
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            if !entry.file_type().map(|t| t.is_file()).unwrap_or(false) {
                continue;
            }
            let name = entry.file_name().to_string_lossy().into_owned();
            let Some((hash, ext)) = name.split_once('.') else {
                continue;
            };
            if hash.len() != 16 {
                continue;
            }
            if let Some(kind) = ImageKind::from_ext(ext) {
                by_hash.insert(hash.to_string(), (name, kind));
            }
        }
    }
    by_hash
}

/// Swap remote image URLs in the typed document for local paths.
pub fn rewrite_document(doc: &mut StatsDocument, rewrites: &HashMap<Href, String>) {
    for range in doc.ranges.values_mut() {
        for item in range
            .artists
            .iter_mut()
            .chain(range.albums.iter_mut())
            .chain(range.tracks.iter_mut())
        {
            if let Some(Image::Remote(href)) = &item.image
                && let Some(local) = rewrites.get(href)
            {
                item.image = Some(Image::Local(local.clone()));
            }
        }
    }
}

/// File names referenced by the typed document's local image paths.
pub fn document_files(doc: &StatsDocument) -> HashSet<String> {
    let mut keep = HashSet::new();
    for range in doc.ranges.values() {
        for item in range
            .artists
            .iter()
            .chain(range.albums.iter())
            .chain(range.tracks.iter())
        {
            if let Some(Image::Local(path)) = &item.image
                && let Some(file) = path.rsplit('/').next()
            {
                keep.insert(file.to_string());
            }
        }
    }
    keep
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::stats::{RangeStats, StatsDocument, StatsItem};
    use std::str::FromStr;

    fn href(s: &str) -> Href {
        Href::from_str(s).unwrap()
    }

    #[test]
    fn short_hash_is_stable() {
        let a = short_hash("https://example.com/a.png");
        let b = short_hash("https://example.com/a.png");
        let c = short_hash("https://example.com/b.png");
        assert_eq!(a.len(), 16);
        assert_eq!(a, b);
        assert_ne!(a, c);
    }

    #[test]
    fn detects_image_kinds() {
        assert_eq!(
            ImageKind::detect(b"\xff\xd8\xff\xe0junk"),
            Some(ImageKind::Jpeg)
        );
        assert_eq!(
            ImageKind::detect(b"\x89PNG\r\n\x1a\nrest"),
            Some(ImageKind::Png)
        );
        assert_eq!(ImageKind::detect(b"GIF89a rest"), Some(ImageKind::Gif));
        assert_eq!(
            ImageKind::detect(b"RIFFxxxxWEBPrest"),
            Some(ImageKind::Webp)
        );
        assert_eq!(ImageKind::detect(b"<html>not an image</html>"), None);
    }

    #[test]
    fn mirror_reuses_existing_files_without_network() {
        let dir = std::env::temp_dir().join(format!("parse-plays-store-{}", std::process::id()));
        let manifest = dir.with_file_name(format!("parse-plays-store-{}.json", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let url = href("https://example.com/cover.jpg");
        let hash = short_hash(url.as_ref());
        std::fs::write(dir.join(format!("{hash}.jpg")), b"\xff\xd8\xff\xe0junk").unwrap();

        let client = crate::testutil::StubClient::new();
        let limits = RateLimits::unthrottled();
        let mut store = ImageStore::load(&dir, &manifest, "/img");
        let map = store
            .mirror(&client, &limits, std::slice::from_ref(&url))
            .unwrap();
        assert_eq!(map.get(&url).unwrap(), &format!("/img/{hash}.jpg"));
        // The file was adopted into the manifest.
        let loaded = ImageStore::load(&dir, &manifest, "/img");
        assert!(loaded.manifest.entries.contains_key(&hash));
        std::fs::remove_dir_all(&dir).ok();
        std::fs::remove_file(&manifest).ok();
    }

    #[test]
    fn mirror_rejects_non_image_bodies() {
        let dir = std::env::temp_dir().join(format!("parse-plays-bad-{}", std::process::id()));
        let manifest = dir.with_file_name(format!("parse-plays-bad-{}.json", std::process::id()));
        let stub = crate::testutil::StubClient::new().route(
            "not-an-image",
            crate::testutil::Response::Bytes(b"<html>oops</html>", "text/html"),
        );
        let url = href("https://example.com/not-an-image");
        let limits = RateLimits::unthrottled();
        let mut store = ImageStore::load(&dir, &manifest, "/img");
        let map = store
            .mirror(&stub, &limits, std::slice::from_ref(&url))
            .unwrap();
        assert!(!map.contains_key(&url));
        std::fs::remove_dir_all(&dir).ok();
        std::fs::remove_file(&manifest).ok();
    }

    #[test]
    fn gc_removes_unreferenced_files_and_entries() {
        let dir = std::env::temp_dir().join(format!("parse-plays-gc-{}", std::process::id()));
        let manifest = dir.with_file_name(format!("parse-plays-gc-{}.json", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let keep_url = href("https://example.com/keep.png");
        let drop_url = href("https://example.com/drop.png");
        let keep_hash = short_hash(keep_url.as_ref());
        let drop_hash = short_hash(drop_url.as_ref());
        std::fs::write(
            dir.join(format!("{keep_hash}.png")),
            b"\x89PNG\r\n\x1a\nkeep",
        )
        .unwrap();
        std::fs::write(
            dir.join(format!("{drop_hash}.png")),
            b"\x89PNG\r\n\x1a\ndrop",
        )
        .unwrap();

        let stub = crate::testutil::StubClient::new();
        let limits = RateLimits::unthrottled();
        let mut store = ImageStore::load(&dir, &manifest, "/img");
        store
            .mirror(&stub, &limits, &[keep_url.clone(), drop_url.clone()])
            .unwrap();
        let keep = HashSet::from([format!("{keep_hash}.png")]);
        store.gc_files(&keep).unwrap();

        assert!(dir.join(format!("{keep_hash}.png")).exists());
        assert!(!dir.join(format!("{drop_hash}.png")).exists());
        let loaded = ImageStore::load(&dir, &manifest, "/img");
        assert!(loaded.manifest.entries.contains_key(&keep_hash));
        assert!(!loaded.manifest.entries.contains_key(&drop_hash));
        std::fs::remove_dir_all(&dir).ok();
        std::fs::remove_file(&manifest).ok();
    }

    #[test]
    fn rewrite_document_touches_only_image_fields() {
        let mut doc = StatsDocument {
            ranges: BTreeMap::from([(
                "all",
                RangeStats {
                    artists: vec![StatsItem {
                        name: "A".into(),
                        artist: None,
                        plays: 1,
                        listened_ms: Some(1000),
                        image: Some(Image::Remote(href("https://example.com/a.jpg"))),
                        url: None,
                    }],
                    albums: vec![StatsItem {
                        name: "B".into(),
                        artist: Some("A".into()),
                        plays: 1,
                        listened_ms: None,
                        image: Some(Image::Remote(href("https://example.com/b.jpg"))),
                        url: None,
                    }],
                    tracks: vec![],
                },
            )]),
        };
        let rewrites =
            HashMap::from([(href("https://example.com/a.jpg"), "/img/a.jpg".to_string())]);
        rewrite_document(&mut doc, &rewrites);
        assert_eq!(
            doc.ranges["all"].artists[0].image,
            Some(Image::Local("/img/a.jpg".into()))
        );
        // Unmapped remote URL stays remote.
        assert_eq!(
            doc.ranges["all"].albums[0].image,
            Some(Image::Remote(href("https://example.com/b.jpg")))
        );
        // The document still serializes the image as a string.
        let value = serde_json::to_value(&doc).unwrap();
        assert_eq!(value["ranges"]["all"]["artists"][0]["image"], "/img/a.jpg");
        assert_eq!(
            value["ranges"]["all"]["albums"][0]["image"],
            "https://example.com/b.jpg"
        );
    }

    #[test]
    fn manifest_is_json_and_documents_entries() {
        let dir = std::env::temp_dir().join(format!("parse-plays-man-{}", std::process::id()));
        let manifest = dir.with_file_name(format!("parse-plays-man-{}.json", std::process::id()));
        let url = href("https://example.com/x.png");
        let hash = short_hash(url.as_ref());
        let stub = crate::testutil::StubClient::new().route(
            "x.png",
            crate::testutil::Response::Bytes(b"\x89PNG\r\n\x1a\nbody", "image/png"),
        );
        let limits = RateLimits::unthrottled();
        let mut store = ImageStore::load(&dir, &manifest, "/img");
        store
            .mirror(&stub, &limits, std::slice::from_ref(&url))
            .unwrap();
        let raw = std::fs::read_to_string(&manifest).unwrap();
        let value: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(
            value["entries"][hash.as_str()]["url"],
            "https://example.com/x.png"
        );
        assert_eq!(value["entries"][hash.as_str()]["content_type"], "image/png");
        std::fs::remove_dir_all(&dir).ok();
        std::fs::remove_file(&manifest).ok();
    }
}
