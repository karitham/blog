//! Pure resolution core: decide what the cache can't satisfy, and turn
//! raw query outcomes into resolutions + cache writes. No I/O — time
//! is passed in as data so TTL decisions are deterministic.
//!
//! Queries are per entity, not per output field: one album query can
//! fill both its cover and its MusicBrainz link, and one artist query
//! can fill both its image and its link. That avoids the duplicate
//! MusicBrainz search the old per-field plan performed.

use crate::cache::{Cache, CacheKey, CacheValue};
use crate::model::{AlbumRef, ArtistKey, Href, MusicBrainzId, ResolvedStats, TrackRef};
use crate::stats::Needs;
use std::time::{SystemTime, UNIX_EPOCH};

/// A lookup the cache cannot satisfy. Carries the display names queries
/// are built from and the MBID from the play records when one exists.
#[derive(Clone, Debug, PartialEq)]
pub enum Query {
    Album {
        album: AlbumRef,
        artist_display: String,
        album_display: String,
        mbid: Option<MusicBrainzId>,
        /// The MBID came from the play record: if its art is missing,
        /// retry once with a name search (the fallback round).
        provided: bool,
    },
    Artist {
        artist: ArtistKey,
        artist_display: String,
        mbid: Option<MusicBrainzId>,
    },
    Track {
        track: TrackRef,
        artist_display: String,
        track_display: String,
        mbid: Option<MusicBrainzId>,
    },
}

/// One entity's raw query result. A query can resolve multiple cache
/// entries; field-level resolutions are split out by finalize.
#[derive(Clone, Debug, PartialEq)]
pub enum Outcome {
    Album {
        mbid: Option<MusicBrainzId>,
        cover: Option<Href>,
        url: Option<Href>,
    },
    Artist {
        mbid: Option<MusicBrainzId>,
        image: Option<Href>,
        url: Option<Href>,
    },
    Track {
        mbid: Option<MusicBrainzId>,
        url: Option<Href>,
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

enum Cached {
    Found(Href),
    FreshMiss,
    NeedsQuery,
}

fn cached(cache: &Cache, key: &CacheKey, now: SystemTime) -> Cached {
    match cache.lookup(key) {
        Some(CacheValue::Found(url)) => Cached::Found(url.clone()),
        Some(value) if value.is_fresh_miss(now) => Cached::FreshMiss,
        _ => Cached::NeedsQuery,
    }
}

/// Decide what to fetch: cached values become resolutions, fresh misses
/// are skipped, and an entity is queried only when at least one of its
/// outputs still needs a lookup.
pub fn plan(needs: &Needs, cache: &Cache, now: SystemTime) -> ResolvePlan {
    let mut resolved = Vec::new();
    let mut queries = Vec::new();

    for need in &needs.albums {
        let cover = cached(cache, &CacheKey::AlbumCover(need.album.clone()), now);
        let url = cached(cache, &CacheKey::AlbumUrl(need.album.clone()), now);
        let mut needs_query = false;

        match cover {
            Cached::Found(url) => resolved.push(Resolution::AlbumCover {
                album: need.album.clone(),
                url,
            }),
            Cached::FreshMiss => {}
            Cached::NeedsQuery => needs_query = true,
        }
        match url {
            Cached::Found(url) => resolved.push(Resolution::AlbumUrl {
                album: need.album.clone(),
                url,
            }),
            Cached::FreshMiss => {}
            Cached::NeedsQuery => needs_query = true,
        }

        if needs_query {
            queries.push(Query::Album {
                album: need.album.clone(),
                artist_display: need.artist_display.clone(),
                album_display: need.album_display.clone(),
                mbid: need.mbid.clone(),
                provided: need.mbid.is_some(),
            });
        }
    }

    for need in &needs.artists {
        let image = cached(cache, &CacheKey::ArtistImage(need.key.clone()), now);
        let url = cached(cache, &CacheKey::ArtistUrl(need.key.clone()), now);
        let mut needs_query = false;

        match image {
            Cached::Found(url) => resolved.push(Resolution::ArtistImage {
                artist: need.key.clone(),
                url,
            }),
            Cached::FreshMiss => {}
            Cached::NeedsQuery => needs_query = true,
        }
        match url {
            Cached::Found(url) => resolved.push(Resolution::ArtistUrl {
                artist: need.key.clone(),
                url,
            }),
            Cached::FreshMiss => {}
            Cached::NeedsQuery => needs_query = true,
        }

        if needs_query {
            queries.push(Query::Artist {
                artist: need.key.clone(),
                artist_display: need.display.clone(),
                mbid: need.mbid.clone(),
            });
        }
    }

    for need in &needs.tracks {
        match cached(cache, &CacheKey::TrackUrl(need.track.clone()), now) {
            Cached::Found(url) => resolved.push(Resolution::TrackUrl {
                track: need.track.clone(),
                url,
            }),
            Cached::FreshMiss => {}
            Cached::NeedsQuery => queries.push(Query::Track {
                track: need.track.clone(),
                artist_display: need.artist_display.clone(),
                track_display: need.track_display.clone(),
                mbid: need.mbid.clone(),
            }),
        }
    }

    ResolvePlan { resolved, queries }
}

/// Turn raw query outcomes into resolutions + staged cache writes. A
/// None output books a negative entry; a provided-MBID album with no
/// art gets one more chance via a name-search query.
pub fn finalize(results: Vec<(Query, Outcome)>, now: SystemTime) -> Finalized {
    let since = now
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let mut resolutions = Vec::new();
    let mut writes = Vec::new();
    let mut pending = Vec::new();

    for (query, outcome) in results {
        match (query, outcome) {
            (
                Query::Album {
                    album,
                    artist_display,
                    album_display,
                    provided,
                    ..
                },
                Outcome::Album { cover, url, .. },
            ) => {
                let needs_fallback = provided && cover.is_none();
                match cover {
                    Some(url) => {
                        resolutions.push(Resolution::AlbumCover {
                            album: album.clone(),
                            url: url.clone(),
                        });
                        writes.push((CacheKey::AlbumCover(album.clone()), CacheValue::Found(url)));
                    }
                    None => writes.push((
                        CacheKey::AlbumCover(album.clone()),
                        CacheValue::Missing { since },
                    )),
                }
                match url {
                    Some(url) => {
                        resolutions.push(Resolution::AlbumUrl {
                            album: album.clone(),
                            url: url.clone(),
                        });
                        writes.push((CacheKey::AlbumUrl(album.clone()), CacheValue::Found(url)));
                    }
                    None => writes.push((
                        CacheKey::AlbumUrl(album.clone()),
                        CacheValue::Missing { since },
                    )),
                }
                if needs_fallback {
                    // Name-search fallback: usually lands on the
                    // canonical release that has art. Not provided, so
                    // this never cascades into another fallback round.
                    pending.push(Query::Album {
                        album,
                        artist_display,
                        album_display,
                        mbid: None,
                        provided: false,
                    });
                }
            }
            (Query::Artist { artist, .. }, Outcome::Artist { image, url, .. }) => {
                match image {
                    Some(url) => {
                        resolutions.push(Resolution::ArtistImage {
                            artist: artist.clone(),
                            url: url.clone(),
                        });
                        writes.push((
                            CacheKey::ArtistImage(artist.clone()),
                            CacheValue::Found(url),
                        ));
                    }
                    None => writes.push((
                        CacheKey::ArtistImage(artist.clone()),
                        CacheValue::Missing { since },
                    )),
                }
                match url {
                    Some(url) => {
                        resolutions.push(Resolution::ArtistUrl {
                            artist: artist.clone(),
                            url: url.clone(),
                        });
                        writes.push((CacheKey::ArtistUrl(artist.clone()), CacheValue::Found(url)));
                    }
                    None => writes.push((
                        CacheKey::ArtistUrl(artist.clone()),
                        CacheValue::Missing { since },
                    )),
                }
            }
            (Query::Track { track, .. }, Outcome::Track { url, .. }) => match url {
                Some(url) => {
                    resolutions.push(Resolution::TrackUrl {
                        track: track.clone(),
                        url: url.clone(),
                    });
                    writes.push((CacheKey::TrackUrl(track), CacheValue::Found(url)));
                }
                None => writes.push((CacheKey::TrackUrl(track), CacheValue::Missing { since })),
            },
            _ => {}
        }
    }

    Finalized {
        resolutions,
        writes,
        pending,
    }
}

/// Fold cache hits and query results into the maps build_document
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

    fn mbid(s: &str) -> MusicBrainzId {
        MusicBrainzId::from_str(s).unwrap()
    }

    #[test]
    fn plan_serves_hits_skips_fresh_misses_and_requeues() {
        let mut cache = Cache::default();
        cache.merge(vec![
            (
                CacheKey::AlbumCover(album_ref("A", "Hit")),
                CacheValue::Found(href("https://example.com/hit.jpg")),
            ),
            (
                CacheKey::AlbumUrl(album_ref("A", "Hit")),
                CacheValue::Found(href("https://musicbrainz.org/release/hit")),
            ),
        ]);
        let now = now();
        let since = now.duration_since(UNIX_EPOCH).unwrap().as_secs();
        cache.merge(vec![
            (
                CacheKey::AlbumCover(album_ref("A", "Fresh Miss")),
                CacheValue::Missing { since },
            ),
            (
                CacheKey::AlbumUrl(album_ref("A", "Fresh Miss")),
                CacheValue::Missing { since },
            ),
        ]);
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
        assert_eq!(plan.resolved.len(), 2);
        // One album query per entity that still needs something.
        assert_eq!(plan.queries.len(), 2);
        let albums: Vec<_> = plan
            .queries
            .iter()
            .filter_map(|q| match q {
                Query::Album { album, .. } => Some(album.clone()),
                _ => None,
            })
            .collect();
        assert_eq!(albums.len(), 2);
        assert!(albums.contains(&album_ref("A", "Stale Miss")));
        assert!(albums.contains(&album_ref("A", "Absent")));
        assert!(!albums.contains(&album_ref("A", "Fresh Miss")));
        assert!(!albums.contains(&album_ref("A", "Hit")));
    }

    #[test]
    fn plan_preserves_provided_mbid() {
        let mbid = mbid("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
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
        assert_eq!(plan.queries.len(), 1);
        match &plan.queries[0] {
            Query::Album {
                mbid: Some(m),
                provided: true,
                ..
            } => assert_eq!(m, &mbid),
            other => panic!("unexpected query: {other:?}"),
        }
    }

    #[test]
    fn finalize_emits_resolutions_and_found_writes() {
        let query = Query::Artist {
            artist: ArtistKey::from("A"),
            artist_display: "A".into(),
            mbid: None,
        };
        let image = href("https://example.com/a.jpg");
        let url = href("https://musicbrainz.org/artist/a");
        let fin = finalize(
            vec![(
                query,
                Outcome::Artist {
                    mbid: None,
                    image: Some(image.clone()),
                    url: Some(url.clone()),
                },
            )],
            now(),
        );
        assert_eq!(fin.pending.len(), 0);
        assert_eq!(fin.resolutions.len(), 2);
        assert!(fin.resolutions.contains(&Resolution::ArtistImage {
            artist: ArtistKey::from("A"),
            url: image.clone()
        }));
        assert!(fin.resolutions.contains(&Resolution::ArtistUrl {
            artist: ArtistKey::from("A"),
            url: url.clone()
        }));
        assert!(fin.writes.contains(&(
            CacheKey::ArtistImage(ArtistKey::from("A")),
            CacheValue::Found(image)
        )));
        assert!(fin.writes.contains(&(
            CacheKey::ArtistUrl(ArtistKey::from("A")),
            CacheValue::Found(url)
        )));
    }

    #[test]
    fn finalize_records_miss_with_now_timestamp() {
        let query = Query::Track {
            track: TrackRef {
                artist: ArtistKey::from("A"),
                track: TrackKey::from("T"),
            },
            artist_display: "A".into(),
            track_display: "T".into(),
            mbid: None,
        };
        let now = now();
        let fin = finalize(
            vec![(
                query,
                Outcome::Track {
                    mbid: None,
                    url: None,
                },
            )],
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
        let provided = Query::Album {
            album: album_ref("A", "B"),
            artist_display: "A".into(),
            album_display: "B".into(),
            mbid: Some(mbid("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")),
            provided: true,
        };
        let fin = finalize(
            vec![(
                provided,
                Outcome::Album {
                    mbid: None,
                    cover: None,
                    url: Some(href("https://musicbrainz.org/release/x")),
                },
            )],
            now,
        );
        assert_eq!(fin.pending.len(), 1);
        match &fin.pending[0] {
            Query::Album {
                mbid: None,
                provided: false,
                album,
                ..
            } => {
                assert_eq!(*album, album_ref("A", "B"));
            }
            other => panic!("unexpected pending query: {other:?}"),
        }

        let searched = Query::Album {
            album: album_ref("A", "B"),
            artist_display: "A".into(),
            album_display: "B".into(),
            mbid: None,
            provided: false,
        };
        let fin = finalize(
            vec![(
                searched,
                Outcome::Album {
                    mbid: None,
                    cover: None,
                    url: None,
                },
            )],
            now,
        );
        assert!(fin.pending.is_empty());

        let artist = Query::Artist {
            artist: ArtistKey::from("A"),
            artist_display: "A".into(),
            mbid: None,
        };
        let fin = finalize(
            vec![(
                artist,
                Outcome::Artist {
                    mbid: None,
                    image: None,
                    url: None,
                },
            )],
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
