//! Pure resolution core: decide what the cache can't satisfy, and turn
//! raw query outcomes into resolutions + cache writes. No I/O — time
//! is passed in as data so TTL decisions are deterministic.

use crate::cache::{Cache, CacheKey, CacheValue};
use crate::model::{AlbumRef, ArtistKey, Href, MusicBrainzId, ResolvedStats, TrackRef};
use crate::stats::Needs;
use std::time::{SystemTime, UNIX_EPOCH};

/// A lookup the cache cannot satisfy from a fresh entry. Carries the
/// display names queries are built from and (for albums) the MBID from
/// the play records, which skips the MusicBrainz search.
#[derive(Clone, Debug, PartialEq)]
pub enum Query {
    AlbumCover {
        album: AlbumRef,
        artist_display: String,
        album_display: String,
        mbid: Option<MusicBrainzId>,
        /// The MBID came from the play record: if its art is missing,
        /// retry once with a name search (the fallback round).
        provided: bool,
    },
    AlbumUrl {
        album: AlbumRef,
        artist_display: String,
        album_display: String,
        mbid: Option<MusicBrainzId>,
    },
    ArtistImage {
        artist: ArtistKey,
        artist_display: String,
    },
    ArtistUrl {
        artist: ArtistKey,
        artist_display: String,
    },
    TrackUrl {
        track: TrackRef,
        artist_display: String,
        track_display: String,
    },
}

/// A found value, tagged with which output map it belongs in.
#[derive(Clone, Debug, PartialEq)]
pub enum Resolution {
    AlbumCover { album: AlbumRef, url: Href },
    AlbumUrl { album: AlbumRef, url: Href },
    ArtistImage { artist: ArtistKey, url: Href },
    ArtistUrl { artist: ArtistKey, url: Href },
    TrackUrl { track: TrackRef, url: Href },
}

/// What one refresh needs: cache hits (no network) + the queries to
/// fetch.
pub struct ResolvePlan {
    pub resolved: Vec<Resolution>,
    pub queries: Vec<Query>,
}

/// The outcome of running the queries: resolutions, staged cache
/// writes, and the fallback round of queries (usually empty).
pub struct Finalized {
    pub resolutions: Vec<Resolution>,
    pub writes: Vec<(CacheKey, CacheValue)>,
    pub pending: Vec<Query>,
}

/// Decide what to fetch: cache hits become resolutions, fresh negative
/// entries are skipped, everything else becomes a query.
pub fn plan(needs: &Needs, cache: &Cache, now: SystemTime) -> ResolvePlan {
    let mut resolved = Vec::new();
    let mut queries = Vec::new();

    for need in &needs.albums {
        match cache.lookup(&CacheKey::AlbumCover(need.album.clone())) {
            Some(CacheValue::Found(url)) => resolved.push(Resolution::AlbumCover {
                album: need.album.clone(),
                url: url.clone(),
            }),
            Some(value) if value.is_fresh_miss(now) => {}
            _ => queries.push(Query::AlbumCover {
                album: need.album.clone(),
                artist_display: need.artist_display.clone(),
                album_display: need.album_display.clone(),
                mbid: need.mbid.clone(),
                provided: need.mbid.is_some(),
            }),
        }
        match cache.lookup(&CacheKey::AlbumUrl(need.album.clone())) {
            Some(CacheValue::Found(url)) => resolved.push(Resolution::AlbumUrl {
                album: need.album.clone(),
                url: url.clone(),
            }),
            Some(value) if value.is_fresh_miss(now) => {}
            _ => queries.push(Query::AlbumUrl {
                album: need.album.clone(),
                artist_display: need.artist_display.clone(),
                album_display: need.album_display.clone(),
                mbid: need.mbid.clone(),
            }),
        }
    }

    for need in &needs.artists {
        match cache.lookup(&CacheKey::ArtistImage(need.key.clone())) {
            Some(CacheValue::Found(url)) => resolved.push(Resolution::ArtistImage {
                artist: need.key.clone(),
                url: url.clone(),
            }),
            Some(value) if value.is_fresh_miss(now) => {}
            _ => queries.push(Query::ArtistImage {
                artist: need.key.clone(),
                artist_display: need.display.clone(),
            }),
        }
        match cache.lookup(&CacheKey::ArtistUrl(need.key.clone())) {
            Some(CacheValue::Found(url)) => resolved.push(Resolution::ArtistUrl {
                artist: need.key.clone(),
                url: url.clone(),
            }),
            Some(value) if value.is_fresh_miss(now) => {}
            _ => queries.push(Query::ArtistUrl {
                artist: need.key.clone(),
                artist_display: need.display.clone(),
            }),
        }
    }

    for need in &needs.tracks {
        match cache.lookup(&CacheKey::TrackUrl(need.track.clone())) {
            Some(CacheValue::Found(url)) => resolved.push(Resolution::TrackUrl {
                track: need.track.clone(),
                url: url.clone(),
            }),
            Some(value) if value.is_fresh_miss(now) => {}
            _ => queries.push(Query::TrackUrl {
                track: need.track.clone(),
                artist_display: need.artist_display.clone(),
                track_display: need.track_display.clone(),
            }),
        }
    }

    ResolvePlan { resolved, queries }
}

/// Turn raw query outcomes into resolutions + staged cache writes. A
/// `None` outcome books a negative entry; a provided-MBID album with
/// no art gets one more chance via a name-search query.
pub fn finalize(
    plan: &ResolvePlan,
    results: Vec<(Query, Option<Href>)>,
    now: SystemTime,
) -> Finalized {
    let since = now
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let mut resolutions = Vec::new();
    let mut writes = Vec::new();
    let mut pending = Vec::new();

    for (query, result) in results {
        match (query, result) {
            (Query::AlbumCover { album, .. }, Some(url)) => {
                resolutions.push(Resolution::AlbumCover {
                    album: album.clone(),
                    url: url.clone(),
                });
                writes.push((CacheKey::AlbumCover(album), CacheValue::Found(url)));
            }
            (
                Query::AlbumCover {
                    album,
                    artist_display,
                    album_display,
                    provided: true,
                    ..
                },
                None,
            ) => {
                writes.push((
                    CacheKey::AlbumCover(album.clone()),
                    CacheValue::Missing { since },
                ));
                // Name-search fallback: usually lands on the canonical
                // release that has art. Not `provided`, so this never
                // cascades into another fallback round.
                pending.push(Query::AlbumCover {
                    album,
                    artist_display,
                    album_display,
                    mbid: None,
                    provided: false,
                });
            }
            (Query::AlbumCover { album, .. }, None) => {
                writes.push((CacheKey::AlbumCover(album), CacheValue::Missing { since }));
            }
            (Query::AlbumUrl { album, .. }, Some(url)) => {
                resolutions.push(Resolution::AlbumUrl {
                    album: album.clone(),
                    url: url.clone(),
                });
                writes.push((CacheKey::AlbumUrl(album), CacheValue::Found(url)));
            }
            (Query::AlbumUrl { album, .. }, None) => {
                writes.push((CacheKey::AlbumUrl(album), CacheValue::Missing { since }));
            }
            (Query::ArtistImage { artist, .. }, Some(url)) => {
                resolutions.push(Resolution::ArtistImage {
                    artist: artist.clone(),
                    url: url.clone(),
                });
                writes.push((CacheKey::ArtistImage(artist), CacheValue::Found(url)));
            }
            (Query::ArtistImage { artist, .. }, None) => {
                writes.push((CacheKey::ArtistImage(artist), CacheValue::Missing { since }));
            }
            (Query::ArtistUrl { artist, .. }, Some(url)) => {
                resolutions.push(Resolution::ArtistUrl {
                    artist: artist.clone(),
                    url: url.clone(),
                });
                writes.push((CacheKey::ArtistUrl(artist), CacheValue::Found(url)));
            }
            (Query::ArtistUrl { artist, .. }, None) => {
                writes.push((CacheKey::ArtistUrl(artist), CacheValue::Missing { since }));
            }
            (Query::TrackUrl { track, .. }, Some(url)) => {
                resolutions.push(Resolution::TrackUrl {
                    track: track.clone(),
                    url: url.clone(),
                });
                writes.push((CacheKey::TrackUrl(track), CacheValue::Found(url)));
            }
            (Query::TrackUrl { track, .. }, None) => {
                writes.push((CacheKey::TrackUrl(track), CacheValue::Missing { since }));
            }
        }
    }

    let _ = plan;
    Finalized {
        resolutions,
        writes,
        pending,
    }
}

/// Fold cache hits and query results into the maps `build_ranges`
/// looks up.
pub fn collect(plan: &ResolvePlan, fin: &Finalized) -> ResolvedStats {
    let mut stats = ResolvedStats::default();
    for res in plan.resolved.iter().chain(fin.resolutions.iter()) {
        match res {
            Resolution::AlbumCover { album, url } => {
                stats.cover.insert(album.clone(), url.clone());
            }
            Resolution::AlbumUrl { album, url } => {
                stats.album_url.insert(album.clone(), url.clone());
            }
            Resolution::ArtistImage { artist, url } => {
                stats.artist_cover.insert(artist.clone(), url.clone());
            }
            Resolution::ArtistUrl { artist, url } => {
                stats.artist_url.insert(artist.clone(), url.clone());
            }
            Resolution::TrackUrl { track, url } => {
                stats.track_url.insert(track.clone(), url.clone());
            }
        }
    }
    stats
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{AlbumKey, ArtistKey, TrackKey};
    use crate::stats::AlbumNeed;
    use std::str::FromStr;
    use std::time::Duration;

    fn now() -> SystemTime {
        SystemTime::UNIX_EPOCH + Duration::from_secs(1_800_000_000)
    }

    fn album_ref(artist: &str, album: &str) -> AlbumRef {
        AlbumRef {
            artist: ArtistKey::from(artist),
            album: AlbumKey::from(album),
        }
    }

    fn href(s: &str) -> Href {
        Href::from_str(s).unwrap()
    }

    #[test]
    fn plan_serves_hits_skips_fresh_misses_and_requeues() {
        let mut cache = Cache::default();
        // Album 1: cached URL → resolution.
        cache.merge(vec![(
            CacheKey::AlbumCover(album_ref("A", "Hit")),
            CacheValue::Found(href("https://example.com/hit.jpg")),
        )]);
        // Album 2: fresh miss → skipped entirely.
        let now = now();
        let since = now.duration_since(UNIX_EPOCH).unwrap().as_secs();
        cache.merge(vec![(
            CacheKey::AlbumCover(album_ref("A", "Fresh Miss")),
            CacheValue::Missing { since },
        )]);
        // Album 3: stale miss → requeued.
        cache.merge(vec![(
            CacheKey::AlbumCover(album_ref("A", "Stale Miss")),
            CacheValue::Missing { since: 0 },
        )]);

        let needs = Needs {
            albums: vec![
                AlbumNeed {
                    album: album_ref("A", "Hit"),
                    artist_display: "A".into(),
                    album_display: "Hit".into(),
                    mbid: None,
                },
                AlbumNeed {
                    album: album_ref("A", "Fresh Miss"),
                    artist_display: "A".into(),
                    album_display: "Fresh Miss".into(),
                    mbid: None,
                },
                AlbumNeed {
                    album: album_ref("A", "Stale Miss"),
                    artist_display: "A".into(),
                    album_display: "Stale Miss".into(),
                    mbid: None,
                },
                AlbumNeed {
                    album: album_ref("A", "Absent"),
                    artist_display: "A".into(),
                    album_display: "Absent".into(),
                    mbid: None,
                },
            ],
            ..Needs::default()
        };

        let plan = plan(&needs, &cache, now);
        assert_eq!(plan.resolved.len(), 1);
        assert!(matches!(
            &plan.resolved[0],
            Resolution::AlbumCover { album, .. } if *album == album_ref("A", "Hit")
        ));
        // Each album needs a cover query AND an album-url query; the
        // fresh miss is skipped entirely.
        assert_eq!(plan.queries.len(), 6);
        let covers: Vec<_> = plan
            .queries
            .iter()
            .filter_map(|q| match q {
                Query::AlbumCover { album, .. } => Some(album.clone()),
                _ => None,
            })
            .collect();
        assert_eq!(covers.len(), 2);
        assert!(covers.contains(&album_ref("A", "Stale Miss")));
        assert!(covers.contains(&album_ref("A", "Absent")));
        assert!(!covers.contains(&album_ref("A", "Fresh Miss")));
        assert!(!covers.contains(&album_ref("A", "Hit")));
    }

    #[test]
    fn plan_preserves_provided_mbid() {
        let mbid = MusicBrainzId::from_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee").unwrap();
        let needs = Needs {
            albums: vec![AlbumNeed {
                album: album_ref("A", "B"),
                artist_display: "A".into(),
                album_display: "B".into(),
                mbid: Some(mbid.clone()),
            }],
            ..Needs::default()
        };
        let plan = plan(&needs, &Cache::default(), now());
        assert_eq!(plan.queries.len(), 2); // cover + album url
        match &plan.queries[0] {
            Query::AlbumCover {
                mbid: Some(m),
                provided: true,
                ..
            } => assert_eq!(m, &mbid),
            other => panic!("unexpected query: {other:?}"),
        }
    }

    #[test]
    fn finalize_emits_resolution_and_found_write() {
        let query = Query::ArtistImage {
            artist: ArtistKey::from("A"),
            artist_display: "A".into(),
        };
        let url = href("https://example.com/a.jpg");
        let fin = finalize(
            &ResolvePlan {
                resolved: vec![],
                queries: vec![query.clone()],
            },
            vec![(query.clone(), Some(url.clone()))],
            now(),
        );
        assert_eq!(fin.pending.len(), 0);
        assert_eq!(fin.resolutions.len(), 1);
        assert_eq!(
            fin.resolutions[0],
            Resolution::ArtistImage {
                artist: ArtistKey::from("A"),
                url: url.clone()
            }
        );
        assert!(fin.writes.contains(&(
            CacheKey::ArtistImage(ArtistKey::from("A")),
            CacheValue::Found(url)
        )));
    }

    #[test]
    fn finalize_records_miss_with_now_timestamp() {
        let query = Query::TrackUrl {
            track: TrackRef {
                artist: ArtistKey::from("A"),
                track: TrackKey::from("T"),
            },
            artist_display: "A".into(),
            track_display: "T".into(),
        };
        let now = now();
        let fin = finalize(
            &ResolvePlan {
                resolved: vec![],
                queries: vec![query.clone()],
            },
            vec![(query, None)],
            now,
        );
        assert!(fin.resolutions.is_empty());
        assert!(fin.pending.is_empty());
        let since = now.duration_since(UNIX_EPOCH).unwrap().as_secs();
        assert!(fin.writes.contains(&(
            CacheKey::TrackUrl(TrackRef {
                artist: ArtistKey::from("A"),
                track: TrackKey::from("T")
            }),
            CacheValue::Missing { since },
        )));
    }

    #[test]
    fn finalize_fallback_only_for_provided_mbids() {
        let now = now();
        // Provided MBID with no art → pending name-search query.
        let provided = Query::AlbumCover {
            album: album_ref("A", "B"),
            artist_display: "A".into(),
            album_display: "B".into(),
            mbid: Some(MusicBrainzId::from_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee").unwrap()),
            provided: true,
        };
        let fin = finalize(
            &ResolvePlan {
                resolved: vec![],
                queries: vec![provided.clone()],
            },
            vec![(provided, None)],
            now,
        );
        assert_eq!(fin.pending.len(), 1);
        match &fin.pending[0] {
            Query::AlbumCover {
                mbid: None,
                provided: false,
                album,
                ..
            } => {
                assert_eq!(*album, album_ref("A", "B"));
            }
            other => panic!("unexpected pending query: {other:?}"),
        }

        // Not provided → no pending (no infinite fallback loop).
        let searched = Query::AlbumCover {
            album: album_ref("A", "B"),
            artist_display: "A".into(),
            album_display: "B".into(),
            mbid: None,
            provided: false,
        };
        let fin = finalize(
            &ResolvePlan {
                resolved: vec![],
                queries: vec![searched.clone()],
            },
            vec![(searched, None)],
            now,
        );
        assert!(fin.pending.is_empty());

        // Other query kinds never pend either.
        let artist = Query::ArtistImage {
            artist: ArtistKey::from("A"),
            artist_display: "A".into(),
        };
        let fin = finalize(
            &ResolvePlan {
                resolved: vec![],
                queries: vec![artist.clone()],
            },
            vec![(artist, None)],
            now,
        );
        assert!(fin.pending.is_empty());
    }

    #[test]
    fn collect_merges_hits_and_results() {
        let cache_hit = Resolution::AlbumCover {
            album: album_ref("A", "Cached"),
            url: href("https://example.com/cached.jpg"),
        };
        let query_result = Resolution::ArtistImage {
            artist: ArtistKey::from("A"),
            url: href("https://example.com/artist.jpg"),
        };
        let plan = ResolvePlan {
            resolved: vec![cache_hit.clone()],
            queries: vec![],
        };
        let fin = Finalized {
            resolutions: vec![query_result.clone()],
            writes: vec![],
            pending: vec![],
        };
        let stats = collect(&plan, &fin);
        assert_eq!(
            stats.cover.get(&album_ref("A", "Cached")),
            Some(&href("https://example.com/cached.jpg"))
        );
        assert_eq!(
            stats.artist_cover.get(&ArtistKey::from("A")),
            Some(&href("https://example.com/artist.jpg"))
        );
        assert!(stats.track_url.is_empty());
    }
}
