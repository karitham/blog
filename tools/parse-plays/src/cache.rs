//! Typed lookup cache for the resolution pipeline.
//!
//! Every cacheable lookup is a `CacheKey` variant, so the five
//! namespaces (album covers, artist images, album/artist/track page
//! links) can never collide — the old string keys distinguished them
//! by counting separator characters. Values are either a found URL or
//! a negative entry (a lookup that found nothing) with a TTL, so a
//! permanent miss isn't re-queried on every refresh but a stale one
//! heals itself after `MISS_TTL`.
//!
//! The cache is read-only during resolution (phases hold `&Cache`),
//! and every write is staged through `merge` then committed once by
//! the caller — no shared mutable state mid-run.

use crate::model::{AlbumRef, ArtistKey, Href, TrackRef};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// How long a negative entry stays authoritative before it is
/// re-queried. 14 days: misses are re-checked a couple of times a
/// month so new MusicBrainz/Cover Art Archive/Wikidata entries get
/// picked up, without paying for them on every refresh.
pub(crate) const MISS_TTL: Duration = Duration::from_secs(14 * 24 * 3600);

/// Every cacheable lookup, distinguished by kind — collisions between
/// the five namespaces are impossible by construction.
#[derive(Clone, PartialEq, Eq, Hash, Debug, Serialize, Deserialize)]
pub enum CacheKey {
    AlbumCover(AlbumRef),
    ArtistImage(ArtistKey),
    AlbumUrl(AlbumRef),
    ArtistUrl(ArtistKey),
    TrackUrl(TrackRef),
}

#[derive(Clone, PartialEq, Eq, Debug, Serialize, Deserialize)]
pub enum CacheValue {
    Found(Href),
    /// A lookup that found nothing, timestamped (epoch seconds) so it
    /// expires.
    Missing {
        since: u64,
    },
}

impl CacheValue {
    /// A `Missing` entry recorded within `MISS_TTL` is authoritative —
    /// skip it. `Found` and stale entries are not fresh misses.
    pub fn is_fresh_miss(&self, now: SystemTime) -> bool {
        let CacheValue::Missing { since } = self else {
            return false;
        };
        let now = now
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        now.saturating_sub(*since) < MISS_TTL.as_secs()
    }
}

/// Owned, read-only during resolution, written exactly once. No Mutex.
#[derive(Default)]
pub struct Cache {
    map: HashMap<CacheKey, CacheValue>,
}

impl Cache {
    /// Load from disk; a missing, corrupt, or old-format file is an
    /// empty cache (which re-resolves once), never a failure.
    pub fn load(path: Option<&str>) -> Cache {
        let Some(path) = path else {
            return Cache::default();
        };
        let map: Option<Vec<(CacheKey, CacheValue)>> = std::fs::read_to_string(path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok());
        match map {
            Some(entries) => {
                let mut cache = Cache::default();
                cache.merge(entries);
                cache
            }
            None => Cache::default(),
        }
    }

    pub fn lookup(&self, key: &CacheKey) -> Option<&CacheValue> {
        self.map.get(key)
    }

    /// Stage a batch of writes. Later writes win over earlier ones in
    /// the same batch, so a found URL upgrades a prior miss.
    pub fn merge(&mut self, writes: impl IntoIterator<Item = (CacheKey, CacheValue)>) {
        for (key, value) in writes {
            self.map.insert(key, value);
        }
    }

    /// Persist atomically (tmp + rename) so a crash mid-write never
    /// corrupts the previous state. Stored as a list of pairs because
    /// serde_json map keys must be strings and `CacheKey` is an enum.
    pub fn save_atomically(&self, path: &str) -> Result<(), String> {
        let entries: Vec<(CacheKey, CacheValue)> = self
            .map
            .iter()
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect();
        let serialized = serde_json::to_string_pretty(&entries)
            .map_err(|e| format!("failed to serialize cache: {e}"))?;
        let tmp = format!("{path}.tmp");
        std::fs::write(&tmp, serialized).map_err(|e| format!("failed to write {tmp}: {e}"))?;
        std::fs::rename(&tmp, path).map_err(|e| format!("failed to rename {tmp}: {e}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{AlbumKey, ArtistKey, TrackKey};
    use std::str::FromStr;

    fn t0() -> SystemTime {
        // Far enough past the epoch that `now - MISS_TTL` stays positive.
        SystemTime::UNIX_EPOCH + Duration::from_secs(1_800_000_000)
    }

    fn album_key() -> AlbumRef {
        AlbumRef {
            artist: ArtistKey::from("Artist"),
            album: AlbumKey::from("Album"),
        }
    }

    #[test]
    fn miss_ttl_boundary_fresh_and_stale() {
        let now = t0();
        let fresh = CacheValue::Missing {
            since: now.duration_since(UNIX_EPOCH).unwrap().as_secs() - MISS_TTL.as_secs() + 1,
        };
        assert!(fresh.is_fresh_miss(now));
        let stale = CacheValue::Missing {
            since: now.duration_since(UNIX_EPOCH).unwrap().as_secs() - MISS_TTL.as_secs(),
        };
        assert!(!stale.is_fresh_miss(now));
        // Found is never a miss, regardless of timestamp.
        let found = CacheValue::Found(Href::from_str("https://example.com/x.jpg").unwrap());
        assert!(!found.is_fresh_miss(now));
    }

    #[test]
    fn merge_is_idempotent_and_upgrades() {
        let mut cache = Cache::default();
        let key = CacheKey::AlbumCover(album_key());
        let url = Href::from_str("https://example.com/cover.jpg").unwrap();
        let miss = CacheValue::Missing { since: 0 };

        cache.merge(vec![(key.clone(), miss.clone())]);
        assert_eq!(cache.lookup(&key), Some(&miss));

        // Merging the same batch again doesn't change the map.
        cache.merge(vec![(key.clone(), miss.clone())]);
        assert_eq!(cache.lookup(&key), Some(&miss));

        // Found upgrades a prior miss.
        cache.merge(vec![(key.clone(), CacheValue::Found(url.clone()))]);
        assert_eq!(cache.lookup(&key), Some(&CacheValue::Found(url)));
    }

    #[test]
    fn persistence_roundtrip() {
        let dir = std::env::temp_dir().join(format!("parse-plays-cache-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("cache.json");
        let path = path.to_str().unwrap().to_string();

        let mut cache = Cache::default();
        cache.merge(vec![
            (
                CacheKey::AlbumCover(album_key()),
                CacheValue::Found(Href::from_str("https://example.com/cover.jpg").unwrap()),
            ),
            (
                CacheKey::ArtistImage(ArtistKey::from("Mac Miller")),
                CacheValue::Missing { since: 42 },
            ),
            (
                CacheKey::TrackUrl(TrackRef {
                    artist: ArtistKey::from("a"),
                    track: TrackKey::from("b"),
                }),
                CacheValue::Missing { since: 7 },
            ),
        ]);
        cache.save_atomically(&path).unwrap();

        let loaded = Cache::load(Some(&path));
        assert_eq!(
            loaded.lookup(&CacheKey::AlbumCover(album_key())),
            cache.lookup(&CacheKey::AlbumCover(album_key()))
        );

        // Corrupt file → empty cache, never a failure.
        std::fs::write(&path, "{not json").unwrap();
        assert!(
            Cache::load(Some(&path))
                .lookup(&CacheKey::AlbumCover(album_key()))
                .is_none()
        );

        std::fs::remove_dir_all(&dir).ok();
    }
}
