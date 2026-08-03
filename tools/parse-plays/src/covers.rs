//! Cover art resolution: the impure boundary between the pure stats
//! core and MusicBrainz / Cover Art Archive.
//!
//! `resolve` is cache-first: with a cache path, known pairs are served
//! instantly and only missing pairs hit the network — two parallel
//! phases (MusicBrainz searches, then Cover Art Archive fetches) with
//! per-endpoint rate limiting and 503/429 retry. The cache is updated
//! atomically after every successful lookup so interrupted runs keep
//! their work. Without a cache path nothing is fetched at all.

use crate::stats;
use rayon::prelude::*;
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

const USER_AGENT: &str = "karitham-blog/0.1.0 (https://karitham.dev)";

/// Global rate limiter shared by workers: at most `rate_per_sec`
/// acquisitions per second across all threads.
struct Limiter {
    min_interval: Duration,
    last: Mutex<Instant>,
}

impl Limiter {
    fn new(rate_per_sec: f64) -> Self {
        Self {
            min_interval: Duration::from_secs_f64(1.0 / rate_per_sec),
            last: Mutex::new(Instant::now()),
        }
    }

    fn acquire(&self) {
        let mut last = self.last.lock().unwrap();
        let since = Instant::now().duration_since(*last);
        if since < self.min_interval {
            std::thread::sleep(self.min_interval - since);
        }
        *last = Instant::now();
    }
}

fn is_retryable(code: u16) -> bool {
    code == 429 || code == 500 || code == 503
}

fn clean_query(s: &str) -> String {
    s.replace('"', "").replace('\\', "")
}

/// MusicBrainz release search → best-guess release MBID. Retries on
/// rate-limit/5xx with exponential backoff, which lets us run a bit
/// hotter than the nominal 1 req/s and have MB push back politely.
fn musicbrainz_release(agent: &ureq::Agent, artist: &str, album: &str) -> Option<String> {
    let query = format!(
        "release:\"{}\" AND artist:\"{}\"",
        clean_query(album),
        clean_query(artist)
    );
    for attempt in 0..3u32 {
        match agent
            .get("https://musicbrainz.org/ws/2/release")
            .query("query", &query)
            .query("fmt", "json")
            .query("limit", "1")
            .call()
        {
            Ok(resp) => {
                let body: serde_json::Value =
                    serde_json::from_str(&resp.into_string().ok()?).ok()?;
                return body["releases"]
                    .as_array()?
                    .first()?
                    .get("id")?
                    .as_str()
                    .map(str::to_string);
            }
            Err(ureq::Error::Status(code, _)) if is_retryable(code) => {
                std::thread::sleep(Duration::from_secs(1 << attempt));
            }
            Err(_) => return None,
        }
    }
    None
}

/// Cover Art Archive front image for a release, 500px. Same retry
/// policy as the MusicBrainz search; a non-2xx response (e.g. 404 —
/// no front art) is a permanent miss.
fn coverart_url(agent: &ureq::Agent, mbid: &str) -> Option<String> {
    let url = format!("https://coverartarchive.org/release/{mbid}/front-500");
    for attempt in 0..3u32 {
        match agent.get(&url).call() {
            Ok(resp) if resp.status() == 200 => return Some(url),
            Ok(_) => return None,
            Err(ureq::Error::Status(code, _)) if is_retryable(code) => {
                std::thread::sleep(Duration::from_secs(1 << attempt));
            }
            Err(_) => return None,
        }
    }
    None
}

fn cache_key(artist: &str, album: &str) -> String {
    format!(
        "{}\u{1f}{}",
        stats::normalize(artist),
        stats::normalize(album)
    )
}

/// Cache key for a real artist image. The leading separator can never
/// collide with an album key (`artist\x1falbum`, non-empty artist side).
fn artist_cache_key(name: &str) -> String {
    format!("\u{1f}{}", stats::normalize(name))
}

/// Cache key for an artist's MusicBrainz page URL. Two leading
/// separators — distinct from artist images (one) and album keys
/// (none). `normalize` drops non-alphanumerics, so separators can
/// never appear inside a name.
fn artist_url_cache_key(name: &str) -> String {
    format!("\u{1f}\u{1f}{}", stats::normalize(name))
}

/// Cache key for an album's MusicBrainz release URL: the album cover
/// key plus a suffix. Album keys contain no separator, so the suffix
/// is unambiguous.
fn album_url_cache_key(artist: &str, album: &str) -> String {
    format!("{}\u{1f}url", cache_key(artist, album))
}

/// Cache key for a track's MusicBrainz recording URL. Three leading
/// separators; includes the artist so same-named tracks don't collide.
fn track_url_cache_key(artist: &str, track: &str) -> String {
    format!(
        "\u{1f}\u{1f}\u{1f}{}\u{1f}{}",
        stats::normalize(artist),
        stats::normalize(track)
    )
}

fn load_cache(path: &str) -> HashMap<String, String> {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

fn save_cache_atomically(path: &str, cache: &HashMap<String, String>) {
    let Ok(serialized) = serde_json::to_string_pretty(cache) else {
        return;
    };
    let tmp = format!("{path}.tmp");
    if std::fs::write(&tmp, serialized).is_ok() {
        let _ = std::fs::rename(&tmp, path);
    }
}

/// Resolve cover URLs for the given (artist, album, optional MBID)
/// triples. See the module docs for the cache-first, parallel,
/// retried behavior. Known MBIDs skip the MusicBrainz search phase,
/// but when a provided MBID has no Cover Art Archive image we fall
/// back to a name search — piper/lazuli MBIDs sometimes point at
/// release variants without art while the canonical release has it.
pub fn resolve(
    pairs: &[(String, String, Option<String>)],
    cache_path: Option<&str>,
) -> HashMap<(String, String), String> {
    let Some(path) = cache_path else {
        return HashMap::new();
    };

    let mut cache = load_cache(path);

    let mut out: HashMap<(String, String), String> = HashMap::new();
    let missing: Vec<(String, String, Option<String>)> = pairs
        .iter()
        .filter_map(
            |(artist, album, mbid)| match cache.get(&cache_key(artist, album)) {
                Some(url) => {
                    out.insert(
                        (stats::normalize(artist), stats::normalize(album)),
                        url.clone(),
                    );
                    None
                }
                None => Some((artist.clone(), album.clone(), mbid.clone())),
            },
        )
        .collect();

    if missing.is_empty() {
        return out;
    }

    let agent = ureq::AgentBuilder::new()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(15))
        .build();

    // Phase 1: MusicBrainz searches for pairs without a known MBID,
    // ~3 req/s across all workers.
    let mb_limiter = &Limiter::new(3.0);
    let searched: Vec<(String, String, String)> = missing
        .par_iter()
        .filter(|(_, _, mbid)| mbid.is_none())
        .filter_map(|(artist, album, _)| {
            mb_limiter.acquire();
            musicbrainz_release(&agent, artist, album)
                .map(|mbid| (artist.clone(), album.clone(), mbid))
        })
        .collect();

    // `provided` records whether the MBID came from the play record —
    // those get a name-search fallback if their art is missing.
    let mut with_mbid: Vec<(String, String, String, bool)> = missing
        .iter()
        .filter_map(|(artist, album, mbid)| {
            mbid.clone()
                .map(|m| (artist.clone(), album.clone(), m, true))
        })
        .collect();
    with_mbid.extend(
        searched
            .into_iter()
            .map(|(artist, album, mbid)| (artist, album, mbid, false)),
    );

    // Phase 2: Cover Art Archive fetches, ~6 req/s across all workers.
    let caa_limiter = &Limiter::new(6.0);
    let caa_outcomes: Vec<(String, String, bool, Option<String>)> = with_mbid
        .par_iter()
        .map(|(artist, album, mbid, provided)| {
            caa_limiter.acquire();
            (
                artist.clone(),
                album.clone(),
                *provided,
                coverart_url(&agent, mbid),
            )
        })
        .collect();

    for (artist, album, _, url) in &caa_outcomes {
        let Some(url) = url else { continue };
        cache.insert(cache_key(artist, album), url.clone());
        // Keys are normalized so the pure `cover` lookup in main
        // (which normalizes both sides) finds them regardless of case.
        out.insert(
            (stats::normalize(artist), stats::normalize(album)),
            url.clone(),
        );
        save_cache_atomically(path, &cache);
    }

    // Fallback: provided MBIDs with no art get a name search — the
    // search usually lands on the canonical release that has art.
    let fallback: Vec<(String, String)> = caa_outcomes
        .par_iter()
        .filter(|(_, _, provided, url)| *provided && url.is_none())
        .map(|(artist, album, _, _)| (artist.clone(), album.clone()))
        .collect();

    if !fallback.is_empty() {
        let searched2: Vec<(String, String, String)> = fallback
            .par_iter()
            .filter_map(|(artist, album)| {
                mb_limiter.acquire();
                musicbrainz_release(&agent, artist, album)
                    .map(|mbid| (artist.clone(), album.clone(), mbid))
            })
            .collect();

        let caa2: Vec<(String, String, String)> = searched2
            .par_iter()
            .filter_map(|(artist, album, mbid)| {
                caa_limiter.acquire();
                coverart_url(&agent, mbid).map(|url| (artist.clone(), album.clone(), url))
            })
            .collect();

        for (artist, album, url) in caa2 {
            cache.insert(cache_key(&artist, &album), url.clone());
            out.insert((stats::normalize(&artist), stats::normalize(&album)), url);
            save_cache_atomically(path, &cache);
        }
    }

    out
}

/// Resolve real artist images via the Wikidata chain (MusicBrainz
/// artist search → url-rels → P18 → Commons). Cache-first, same
/// append-only pattern.
pub fn resolve_artists(artists: &[String], cache_path: Option<&str>) -> HashMap<String, String> {
    let Some(path) = cache_path else {
        return HashMap::new();
    };

    let mut cache = load_cache(path);

    let mut out: HashMap<String, String> = HashMap::new();
    let missing: Vec<String> = artists
        .iter()
        .filter_map(|name| match cache.get(&artist_cache_key(name)) {
            Some(url) => {
                out.insert(stats::normalize(name), url.clone());
                None
            }
            None => Some(name.clone()),
        })
        .collect();

    if missing.is_empty() {
        return out;
    }

    let agent = ureq::AgentBuilder::new()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(15))
        .build();

    // Per artist: two MusicBrainz requests (search + url-rels lookup)
    // share the MB limiter; Wikidata answers at ~1 req/s.
    let mb_limiter = &Limiter::new(3.0);
    let wd_limiter = &Limiter::new(1.0);
    let results: Vec<(String, String)> = missing
        .par_iter()
        .filter_map(|name| {
            let mbid = {
                mb_limiter.acquire();
                musicbrainz_artist_mbid(&agent, name)
            }?;
            let qid = {
                mb_limiter.acquire();
                wikidata_qid(&agent, &mbid)
            }?;
            wd_limiter.acquire();
            let filename = wikidata_p18(&agent, &qid)?;
            Some((name.clone(), commons_url(&filename)))
        })
        .collect();

    for (name, url) in results {
        cache.insert(artist_cache_key(&name), url.clone());
        out.insert(stats::normalize(&name), url);
        save_cache_atomically(path, &cache);
    }

    out
}

/// MusicBrainz artist search → best-guess artist MBID.
fn musicbrainz_artist_mbid(agent: &ureq::Agent, name: &str) -> Option<String> {
    let query = format!("artist:\"{}\"", clean_query(name));
    for attempt in 0..3u32 {
        match agent
            .get("https://musicbrainz.org/ws/2/artist")
            .query("query", &query)
            .query("fmt", "json")
            .query("limit", "1")
            .call()
        {
            Ok(resp) => {
                let body: serde_json::Value =
                    serde_json::from_str(&resp.into_string().ok()?).ok()?;
                return body["artists"]
                    .as_array()?
                    .first()?
                    .get("id")?
                    .as_str()
                    .map(str::to_string);
            }
            Err(ureq::Error::Status(code, _)) if is_retryable(code) => {
                std::thread::sleep(Duration::from_secs(1 << attempt));
            }
            Err(_) => return None,
        }
    }
    None
}

/// MB artist lookup with URL relations → the artist's Wikidata QID.
fn wikidata_qid(agent: &ureq::Agent, mbid: &str) -> Option<String> {
    for attempt in 0..3u32 {
        let resp = match agent
            .get(&format!("https://musicbrainz.org/ws/2/artist/{mbid}"))
            .query("inc", "url-rels")
            .query("fmt", "json")
            .call()
        {
            Ok(resp) => resp,
            Err(ureq::Error::Status(code, _)) if is_retryable(code) => {
                std::thread::sleep(Duration::from_secs(1 << attempt));
                continue;
            }
            Err(_) => return None,
        };
        let body: serde_json::Value = serde_json::from_str(&resp.into_string().ok()?).ok()?;
        for relation in body["relations"].as_array()? {
            if relation["type"].as_str() == Some("wikidata") {
                let url = relation["url"]["resource"].as_str()?;
                // https://www.wikidata.org/wiki/Q130798
                return url.rsplit('/').next().map(str::to_string);
            }
        }
        return None;
    }
    None
}

/// Wikidata `P18` (image) claim → Commons filename.
fn wikidata_p18(agent: &ureq::Agent, qid: &str) -> Option<String> {
    for attempt in 0..3u32 {
        match agent
            .get("https://www.wikidata.org/w/api.php")
            .query("action", "wbgetclaims")
            .query("property", "P18")
            .query("entity", qid)
            .query("format", "json")
            .call()
        {
            Ok(resp) => {
                let body: serde_json::Value =
                    serde_json::from_str(&resp.into_string().ok()?).ok()?;
                return body["claims"]["P18"]
                    .as_array()?
                    .first()?
                    .get("mainsnak")?
                    .get("datavalue")?
                    .get("value")?
                    .as_str()
                    .map(str::to_string);
            }
            Err(ureq::Error::Status(code, _)) if is_retryable(code) => {
                std::thread::sleep(Duration::from_secs(1 << attempt));
            }
            Err(_) => return None,
        }
    }
    None
}

/// Commons image URL for a filename, resized to 600px.
fn commons_url(filename: &str) -> String {
    format!(
        "https://commons.wikimedia.org/wiki/Special:FilePath/{}?width=600",
        percent_encode(filename)
    )
}

/// Minimal percent-encoding for the path component of a Commons URL.
fn percent_encode(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char)
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

/// MusicBrainz recording search → best-guess recording MBID.
fn musicbrainz_recording(agent: &ureq::Agent, artist: &str, track: &str) -> Option<String> {
    let query = format!(
        "recording:\"{}\" AND artist:\"{}\"",
        clean_query(track),
        clean_query(artist)
    );
    for attempt in 0..3u32 {
        match agent
            .get("https://musicbrainz.org/ws/2/recording")
            .query("query", &query)
            .query("fmt", "json")
            .query("limit", "1")
            .call()
        {
            Ok(resp) => {
                let body: serde_json::Value =
                    serde_json::from_str(&resp.into_string().ok()?).ok()?;
                return body["recordings"]
                    .as_array()?
                    .first()?
                    .get("id")?
                    .as_str()
                    .map(str::to_string);
            }
            Err(ureq::Error::Status(code, _)) if is_retryable(code) => {
                std::thread::sleep(Duration::from_secs(1 << attempt));
            }
            Err(_) => return None,
        }
    }
    None
}

/// Resolve MusicBrainz release pages for the top albums. Cache-first,
/// like `resolve`: provided MBIDs are used directly, otherwise a name
/// search finds one. Keys in the returned map are normalized
/// (artist, album) pairs.
pub fn resolve_album_urls(
    pairs: &[(String, String, Option<String>)],
    cache_path: Option<&str>,
) -> HashMap<(String, String), String> {
    let Some(path) = cache_path else {
        return HashMap::new();
    };

    let mut cache = load_cache(path);

    let mut out: HashMap<(String, String), String> = HashMap::new();
    let missing: Vec<(String, String, Option<String>)> = pairs
        .iter()
        .filter_map(
            |(artist, album, mbid)| match cache.get(&album_url_cache_key(artist, album)) {
                Some(url) => {
                    out.insert(
                        (stats::normalize(artist), stats::normalize(album)),
                        url.clone(),
                    );
                    None
                }
                None => Some((artist.clone(), album.clone(), mbid.clone())),
            },
        )
        .collect();

    if missing.is_empty() {
        return out;
    }

    let agent = ureq::AgentBuilder::new()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(15))
        .build();

    let limiter = &Limiter::new(3.0);
    let results: Vec<(String, String, String)> = missing
        .par_iter()
        .filter_map(|(artist, album, mbid)| {
            limiter.acquire();
            let mbid = match mbid {
                Some(mbid) => mbid.clone(),
                None => musicbrainz_release(&agent, artist, album)?,
            };
            Some((
                artist.clone(),
                album.clone(),
                format!("https://musicbrainz.org/release/{mbid}"),
            ))
        })
        .collect();

    for (artist, album, url) in results {
        cache.insert(album_url_cache_key(&artist, &album), url.clone());
        out.insert((stats::normalize(&artist), stats::normalize(&album)), url);
        save_cache_atomically(path, &cache);
    }

    out
}

/// Resolve MusicBrainz artist pages for the top artists. Cache-first;
/// a miss does the same artist search as the image pipeline. Keys are
/// normalized artist names.
pub fn resolve_artist_urls(
    artists: &[String],
    cache_path: Option<&str>,
) -> HashMap<String, String> {
    let Some(path) = cache_path else {
        return HashMap::new();
    };

    let mut cache = load_cache(path);

    let mut out: HashMap<String, String> = HashMap::new();
    let missing: Vec<String> = artists
        .iter()
        .filter_map(|name| match cache.get(&artist_url_cache_key(name)) {
            Some(url) => {
                out.insert(stats::normalize(name), url.clone());
                None
            }
            None => Some(name.clone()),
        })
        .collect();

    if missing.is_empty() {
        return out;
    }

    let agent = ureq::AgentBuilder::new()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(15))
        .build();

    let limiter = &Limiter::new(3.0);
    let results: Vec<(String, String)> = missing
        .par_iter()
        .filter_map(|name| {
            limiter.acquire();
            musicbrainz_artist_mbid(&agent, name).map(|mbid| {
                (
                    name.clone(),
                    format!("https://musicbrainz.org/artist/{mbid}"),
                )
            })
        })
        .collect();

    for (name, url) in results {
        cache.insert(artist_url_cache_key(&name), url.clone());
        out.insert(stats::normalize(&name), url);
        save_cache_atomically(path, &cache);
    }

    out
}

/// Resolve MusicBrainz recording pages for the top tracks. Cache-first;
/// a miss does a `recording:"..." AND artist:"..."` search. Keys are
/// normalized (artist, track) pairs.
pub fn resolve_track_urls(
    tracks: &[(String, String)],
    cache_path: Option<&str>,
) -> HashMap<(String, String), String> {
    let Some(path) = cache_path else {
        return HashMap::new();
    };

    let mut cache = load_cache(path);

    let mut out: HashMap<(String, String), String> = HashMap::new();
    let missing: Vec<(String, String)> = tracks
        .iter()
        .filter_map(
            |(artist, track)| match cache.get(&track_url_cache_key(artist, track)) {
                Some(url) => {
                    out.insert(
                        (stats::normalize(artist), stats::normalize(track)),
                        url.clone(),
                    );
                    None
                }
                None => Some((artist.clone(), track.clone())),
            },
        )
        .collect();

    if missing.is_empty() {
        return out;
    }

    let agent = ureq::AgentBuilder::new()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(15))
        .build();

    let limiter = &Limiter::new(3.0);
    let results: Vec<(String, String, String)> = missing
        .par_iter()
        .filter_map(|(artist, track)| {
            limiter.acquire();
            musicbrainz_recording(&agent, artist, track).map(|mbid| {
                (
                    artist.clone(),
                    track.clone(),
                    format!("https://musicbrainz.org/recording/{mbid}"),
                )
            })
        })
        .collect();

    for (artist, track, url) in results {
        cache.insert(track_url_cache_key(&artist, &track), url.clone());
        out.insert((stats::normalize(&artist), stats::normalize(&track)), url);
        save_cache_atomically(path, &cache);
    }

    out
}
