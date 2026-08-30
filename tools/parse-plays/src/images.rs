//! Build-time image mirroring: download every remote image referenced
//! by the stats JSON into a local cache directory and rewrite the
//! `image` fields to point at the local copies.
//!
//! The visitor's browser should never have to hit Cover Art Archive,
//! Wikimedia Commons (the Wikidata chain), or similar third-party
//! hosts at page load — those are slow and every page view burns
//! their bandwidth. Everything the Music section shows is mirrored
//! here once per `just refresh`, then served from `/img/...` beside
//! the rest of the site. Downloads that fail keep their remote URL in
//! the JSON so the tile still renders.

use crate::model::Href;
use crate::net::{HttpClient, HttpFetch};
use crate::sources::RateLimits;
use rayon::prelude::*;
use std::collections::{HashMap, HashSet};
use std::path::Path;
use std::str::FromStr;

/// Generous cap — covers and artist photos are a few hundred KB.
const MAX_IMAGE_BYTES: u64 = 8 * 1024 * 1024;

/// 16 hex chars of fnv-1a 64. Collision-proof enough for a few
/// hundred URLs and stable across runs, so the cache is append-only.
pub fn short_hash(s: &str) -> String {
    let mut hash: u64 = 0xcbf29ce484222325;
    for b in s.as_bytes() {
        hash ^= *b as u64;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    format!("{hash:016x}")
}

fn ext_for_content_type(ct: &str) -> &'static str {
    let ct = ct.to_ascii_lowercase();
    if ct.contains("png") {
        "png"
    } else if ct.contains("webp") {
        "webp"
    } else if ct.contains("gif") {
        "gif"
    } else {
        "jpg"
    }
}

/// Snapshot the cache dir: hash → local URL path for every complete
/// `<hash>.<ext>` file. Leftover `.tmp` files from a killed run are
/// swept and never treated as cache entries.
fn scan_cache(dir: &Path) -> (HashMap<String, String>, Vec<std::path::PathBuf>) {
    let mut by_hash = HashMap::new();
    let mut stale = Vec::new();
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().into_owned();
            if name.ends_with(".tmp") {
                stale.push(entry.path());
                continue;
            }
            if let Some((hash, _)) = name.split_once('.')
                && hash.len() == 16
            {
                by_hash.insert(hash.to_string(), format!("/img/{name}"));
            }
        }
    }
    (by_hash, stale)
}

/// Download `url` into `dir`, returning the local URL path
/// (`/img/<hash>.<ext>`), or `None` on failure. Empty or oversized
/// bodies are dropped so a truncated copy never becomes the cached
/// artifact; writes go through a temp file + rename so a crash
/// mid-write can't leave a partial file behind.
fn fetch_image(client: &dyn HttpFetch, dir: &Path, url: &Href) -> Option<String> {
    let hash = short_hash(url.as_ref());
    let (ct, buf) = client.get_bytes(url.as_ref(), MAX_IMAGE_BYTES as usize)?;
    if buf.is_empty() || buf.len() as u64 > MAX_IMAGE_BYTES {
        return None;
    }
    let name = format!("{hash}.{}", ext_for_content_type(&ct));
    let tmp = dir.join(format!("{name}.tmp"));
    std::fs::write(&tmp, &buf).ok()?;
    std::fs::rename(&tmp, dir.join(&name)).ok()?;
    Some(format!("/img/{name}"))
}

/// Mirror every unique remote `url` into `dir` (cache-first) and
/// return the remote→local path map. Downloads run in parallel under
/// per-host rate limiters; a failed download is simply absent from the
/// map so the caller can keep the remote URL.
pub fn download_many(
    client: &dyn HttpFetch,
    limits: &RateLimits,
    urls: &[Href],
    dir: &Path,
) -> HashMap<Href, String> {
    let _ = std::fs::create_dir_all(dir);
    let (by_hash, stale) = scan_cache(dir);
    for stale_path in stale {
        let _ = std::fs::remove_file(stale_path);
    }

    let unique: HashSet<&Href> = urls.iter().collect();
    let urls: Vec<&Href> = unique.into_iter().collect();
    // Parallel downloads under a shared limiter: with server latency
    // far above the limiter interval, workers overlap the waits.
    let results: Vec<(Href, Option<String>)> = urls
        .par_iter()
        .map(|url| {
            let hash = short_hash(url.as_ref());
            match by_hash.get(&hash) {
                Some(local) => ((*url).clone(), Some(local.clone())),
                None => {
                    if url.as_ref().contains("coverartarchive.org") {
                        limits.coverart_img.acquire();
                    } else {
                        limits.commons.acquire();
                    }
                    ((*url).clone(), fetch_image(client, dir, url))
                }
            }
        })
        .collect();

    let mut rewrites = HashMap::new();
    for (url, local) in results {
        if let Some(local) = local {
            rewrites.insert(url, local);
        }
    }
    rewrites
}

/// Point every `image` field at its local mirror, when one exists.
pub fn apply_rewrites(value: &mut serde_json::Value, rewrites: &HashMap<Href, String>) {
    match value {
        serde_json::Value::Array(items) => {
            for item in items {
                apply_rewrites(item, rewrites);
            }
        }
        serde_json::Value::Object(map) => {
            if let Some(serde_json::Value::String(url)) = map.get("image")
                && let Ok(href) = Href::from_str(url)
                && let Some(local) = rewrites.get(&href)
            {
                map.insert("image".into(), serde_json::Value::String(local.clone()));
            }
            for (_, v) in map {
                apply_rewrites(v, rewrites);
            }
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

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
    fn ext_maps_content_types() {
        assert_eq!(ext_for_content_type("image/jpeg"), "jpg");
        assert_eq!(ext_for_content_type("image/png"), "png");
        assert_eq!(ext_for_content_type("image/webp"), "webp");
        assert_eq!(ext_for_content_type("IMAGE/GIF"), "gif");
        assert_eq!(ext_for_content_type("application/octet-stream"), "jpg");
    }

    #[test]
    fn scan_cache_indexes_complete_files_only() {
        let dir = std::env::temp_dir().join(format!("parse-plays-scan-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let hash = short_hash("https://example.com/cover");
        std::fs::write(dir.join(format!("{hash}.png")), b"x").unwrap();
        std::fs::write(dir.join(format!("{hash}.jpg.tmp")), b"partial").unwrap();
        std::fs::write(dir.join("other.txt"), b"junk").unwrap();

        let (by_hash, stale) = scan_cache(&dir);
        assert_eq!(by_hash.len(), 1);
        assert_eq!(by_hash.get(&hash).unwrap(), &format!("/img/{hash}.png"));
        assert_eq!(stale.len(), 1);
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn download_many_hits_cache_without_network() {
        let dir = std::env::temp_dir().join(format!("parse-plays-dl-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let url = Href::from_str("https://example.com/cover").unwrap();
        let hash = short_hash(url.as_ref());
        std::fs::write(dir.join(format!("{hash}.jpg")), b"x").unwrap();

        let client = HttpClient::new();
        let limits = RateLimits::unthrottled();
        let map = download_many(&client, &limits, std::slice::from_ref(&url), &dir);
        assert_eq!(map.get(&url).unwrap(), &format!("/img/{hash}.jpg"));
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn download_many_fetches_and_404s_are_permanent() {
        let png: &'static [u8] = b"\x89PNG\r\n\x1a\n fake png bytes";
        let stub = crate::testutil::StubClient::new()
            .route(
                "cover.png",
                crate::testutil::Response::Bytes(png, "image/png"),
            )
            .route("missing.png", crate::testutil::Response::Status(404));
        let req_log = stub.request_log();
        let limits = RateLimits::unthrottled();
        let dir = std::env::temp_dir().join(format!("parse-plays-fetch-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();

        let good = Href::from_str("https://example.com/cover.png").unwrap();
        let map = download_many(&stub, &limits, std::slice::from_ref(&good), &dir);
        let local = map.get(&good).unwrap();
        assert!(local.ends_with(".png"), "{local}");
        assert!(dir.join(local.trim_start_matches("/img/")).exists());

        // A 404 URL is a permanent miss: absent from the map, and the
        // download cost exactly one request (no retry).
        let missing = Href::from_str("https://example.com/missing.png").unwrap();
        let map = download_many(&stub, &limits, std::slice::from_ref(&missing), &dir);
        assert!(!map.contains_key(&missing));
        assert_eq!(req_log.lock().unwrap().len(), 2);

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn applies_rewrites_to_image_fields() {
        let mut doc = json!({
            "ranges": {
                "1m": {
                    "artists": [{ "name": "A", "image": "https://a.example/1.jpg" }],
                    "albums": [
                        { "name": "B", "image": "https://b.example/2.png" },
                        { "name": "C", "image": "/img/abc.jpg" },
                    ],
                }
            }
        });
        let rewrites = HashMap::from([(
            Href::from_str("https://a.example/1.jpg").unwrap(),
            "/img/1.jpg".to_string(),
        )]);
        apply_rewrites(&mut doc, &rewrites);
        let image = |name: &str, i: usize| {
            doc["ranges"]["1m"][name][i]["image"]
                .as_str()
                .unwrap()
                .to_string()
        };
        assert_eq!(image("artists", 0), "/img/1.jpg");
        // Unmapped remote URL stays as-is so the tile still renders.
        assert_eq!(image("albums", 0), "https://b.example/2.png");
        // Already-local reference untouched.
        assert_eq!(image("albums", 1), "/img/abc.jpg");
    }
}
