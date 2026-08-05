//! Pure aggregation core: play history → top-N grids per time range.
//!
//! No I/O here — everything is deterministic and testable with plain
//! values. The imperative shell in `main` calls `aggregate`, then
//! `needed` (to know which covers/links to resolve), then
//! `build_ranges` with the resolved data. Keys are typed newtypes
//! (`ArtistKey`/`AlbumRef`/`TrackRef`), so display names can never be
//! mistaken for keys.

use crate::model::{
    AlbumKey, AlbumRef, ArtistKey, Href, MusicBrainzId, ResolvedStats, TrackKey, TrackRef,
};
use serde::Serialize;
use serde_json::json;
use std::collections::{HashMap, HashSet};
use std::str::FromStr;

pub const TOP_N: usize = 9;

// ---------------------------------------------------------------- ranges

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub enum Range {
    OneMonth,
    SixMonths,
    OneYear,
    AllTime,
}

impl Range {
    pub const ALL: [Range; 4] = [
        Range::OneMonth,
        Range::SixMonths,
        Range::OneYear,
        Range::AllTime,
    ];

    /// JSON key, also the `data-range` attribute value in the view.
    pub fn key(self) -> &'static str {
        match self {
            Range::OneMonth => "1m",
            Range::SixMonths => "6m",
            Range::OneYear => "1y",
            Range::AllTime => "all",
        }
    }

    /// Upper bound on play age in days, or `None` for all-time.
    fn max_age_days(self) -> Option<i64> {
        match self {
            Range::OneMonth => Some(30),
            Range::SixMonths => Some(182),
            Range::OneYear => Some(365),
            Range::AllTime => None,
        }
    }
}

// ---------------------------------------------------------------- types

#[derive(Clone, Copy, Default)]
struct Counter {
    plays: u64,
    ms_played: u64,
}

/// Aggregated raw counters before sorting/trimming.
#[derive(Default)]
pub struct Aggregated {
    /// range -> artist_key -> (counter, display name)
    artists: HashMap<Range, HashMap<ArtistKey, (Counter, String)>>,
    /// range -> album_ref -> album entry
    albums: HashMap<Range, HashMap<AlbumRef, AlbumEntry>>,
    /// range -> track_ref -> (counter, artist display, track display, album key)
    tracks: HashMap<Range, HashMap<TrackRef, TrackCounter>>,
    /// artist_key -> (top album key, plays) — used to proxy artist cover art.
    top_albums: HashMap<ArtistKey, (AlbumKey, u64)>,
    /// artist_key -> display name
    artist_names: HashMap<ArtistKey, String>,
}

/// One track's accumulated stats: the counter, the display names, and
/// which album (if any) its cover falls back to.
type TrackCounter = (Counter, String, String, AlbumKey);

/// One album's accumulated stats. `release_mbid` is carried through
/// from the play records (piper/lazuli emit it on recent plays) so
/// cover resolution can hit Cover Art Archive directly instead of
/// searching MusicBrainz by name.
#[derive(Clone, Default)]
pub struct AlbumEntry {
    counter: Counter,
    artist_display: String,
    album_display: String,
    release_mbid: Option<MusicBrainzId>,
}

/// What the top-N grids actually reference: the keys resolution works
/// on, plus the display names queries are built from.
pub struct AlbumNeed {
    pub album: AlbumRef,
    pub artist_display: String,
    pub album_display: String,
    pub mbid: Option<MusicBrainzId>,
}

pub struct ArtistNeed {
    pub key: ArtistKey,
    pub display: String,
}

pub struct TrackNeed {
    pub track: TrackRef,
    pub artist_display: String,
    pub track_display: String,
}

/// Everything one refresh needs resolved, deduplicated across ranges.
#[derive(Default)]
pub struct Needs {
    pub albums: Vec<AlbumNeed>,
    pub artists: Vec<ArtistNeed>,
    pub tracks: Vec<TrackNeed>,
}

#[derive(Serialize)]
struct StatsItem {
    name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    artist: Option<String>,
    plays: u64,
    ms_played: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    image: Option<Href>,
    #[serde(skip_serializing_if = "Option::is_none")]
    url: Option<Href>,
}

#[derive(Serialize)]
struct RangeStats {
    artists: Vec<StatsItem>,
    albums: Vec<StatsItem>,
    tracks: Vec<StatsItem>,
}

// ---------------------------------------------------------------- aggregate

/// Aggregate all plays into per-range counters. Plays that fail to
/// parse (missing fields, bad dates) are skipped.
pub fn aggregate(plays: &[serde_json::Value], today: chrono::NaiveDate) -> Aggregated {
    let mut agg = Aggregated::default();

    for play in plays {
        let Some(artists) = play["artists"].as_array() else {
            continue;
        };
        let Some(artist_display) = artists
            .first()
            .and_then(|a| a["artistName"].as_str())
            .map(str::trim)
            .filter(|s| !s.is_empty())
        else {
            continue;
        };
        let Some(track_display) = play["trackName"].as_str().map(str::trim) else {
            continue;
        };
        if track_display.is_empty() {
            continue;
        }

        let artist_key = ArtistKey::from(artist_display);
        let track_key = TrackKey::from(track_display);
        let ms_played = play["msPlayed"].as_u64().unwrap_or(0);

        let (album_key, album_display) = match play["releaseName"].as_str() {
            Some(name) if !name.trim().is_empty() => {
                (AlbumKey::from(name), name.trim().to_string())
            }
            _ => (AlbumKey::from(""), String::new()),
        };
        let release_mbid = play["releaseMbId"]
            .as_str()
            .and_then(|s| MusicBrainzId::from_str(s).ok());

        // Bucket by age; unparseable dates count as all-time only.
        let age_days = play["playedTime"]
            .as_str()
            .and_then(|s| s.get(..10))
            .and_then(|d| chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").ok())
            .map(|date| (today - date).num_days().max(0));

        let ranges: Vec<Range> = Range::ALL
            .into_iter()
            .filter(|r| match (r.max_age_days(), age_days) {
                (Some(max), Some(age)) => age <= max,
                (None, _) => true,
                (Some(_), None) => false,
            })
            .collect();

        agg.artist_names
            .insert(artist_key.clone(), artist_display.to_string());

        for range in ranges {
            let artist = agg
                .artists
                .entry(range)
                .or_default()
                .entry(artist_key.clone())
                .or_insert_with(|| (Counter::default(), artist_display.to_string()));
            artist.0.plays += 1;
            artist.0.ms_played += ms_played;

            if !album_key.as_ref().is_empty() {
                let album = agg
                    .albums
                    .entry(range)
                    .or_default()
                    .entry(AlbumRef {
                        artist: artist_key.clone(),
                        album: album_key.clone(),
                    })
                    .or_insert_with(|| AlbumEntry {
                        counter: Counter::default(),
                        artist_display: artist_display.to_string(),
                        album_display: album_display.clone(),
                        release_mbid: None,
                    });
                album.counter.plays += 1;
                album.counter.ms_played += ms_played;
                // Most recent play wins — newer records carry the MBID.
                if let Some(mbid) = &release_mbid {
                    album.release_mbid = Some(mbid.clone());
                }
            }

            if !track_key.as_ref().is_empty() {
                let track = agg
                    .tracks
                    .entry(range)
                    .or_default()
                    .entry(TrackRef {
                        artist: artist_key.clone(),
                        track: track_key.clone(),
                    })
                    .or_insert_with(|| {
                        (
                            Counter::default(),
                            artist_display.to_string(),
                            track_display.to_string(),
                            album_key.clone(),
                        )
                    });
                track.0.plays += 1;
                track.0.ms_played += ms_played;
            }
        }
    }

    // Per artist, remember the album with the most plays — its cover
    // proxies the artist tile.
    if let Some(map) = agg.albums.get(&Range::AllTime) {
        for (album_ref, entry) in map {
            let record = agg
                .top_albums
                .entry(album_ref.artist.clone())
                .or_insert_with(|| (album_ref.album.clone(), 0));
            if entry.counter.plays > record.1 {
                *record = (album_ref.album.clone(), entry.counter.plays);
            }
        }
    }

    agg
}

// ---------------------------------------------------------------- top-N

fn sort_top<'a, T, I, F>(entries: I, to_item: F) -> Vec<StatsItem>
where
    T: 'a,
    I: Iterator<Item = (T, &'a Counter)>,
    F: Fn(T) -> StatsItem,
{
    let mut list: Vec<(&Counter, StatsItem)> = entries
        .map(|(key, counter)| (counter, to_item(key)))
        .collect();
    list.sort_by(|a, b| {
        b.0.plays
            .cmp(&a.0.plays)
            .then_with(|| b.0.ms_played.cmp(&a.0.ms_played))
            .then_with(|| a.1.name.cmp(&b.1.name))
    });
    list.into_iter().take(TOP_N).map(|(_, item)| item).collect()
}

/// Top-N keys by (plays, ms_played), for picking which covers we need.
/// The key itself breaks ties so the selection is deterministic —
/// HashMap iteration order is random per process, and at a tied
/// top-N boundary it would otherwise pick a different set every run.
fn top_keys<'a, T>(entries: impl Iterator<Item = (T, &'a Counter)>) -> Vec<T>
where
    T: Clone + Ord,
{
    let mut list: Vec<(&Counter, T)> = entries.map(|(key, counter)| (counter, key)).collect();
    list.sort_by(|a, b| {
        b.0.plays
            .cmp(&a.0.plays)
            .then_with(|| b.0.ms_played.cmp(&a.0.ms_played))
            .then_with(|| a.1.cmp(&b.1))
    });
    list.into_iter().take(TOP_N).map(|(_, key)| key).collect()
}

// ---------------------------------------------------------------- needs

/// The (deduplicated) set of keys the top-N grids reference — what the
/// resolution pipeline must fetch. Display names and MBIDs are carried
/// for building queries; `album`/`artist`/`track` are the typed keys
/// the resolved maps are keyed by.
pub fn needed(agg: &Aggregated) -> Needs {
    let mut album_seen: HashSet<AlbumRef> = HashSet::new();
    let mut artist_seen: HashSet<ArtistKey> = HashSet::new();
    let mut track_seen: HashSet<TrackRef> = HashSet::new();

    for range in Range::ALL {
        if let Some(map) = agg.albums.get(&range) {
            for key in top_keys(map.iter().map(|(k, v)| (k.clone(), &v.counter))) {
                album_seen.insert(key);
            }
        }
        if let Some(map) = agg.tracks.get(&range) {
            for key in top_keys(map.iter().map(|(k, v)| (k.clone(), &v.0))) {
                if let Some((_, _, _, album_key)) = map.get(&key)
                    && !album_key.as_ref().is_empty()
                {
                    album_seen.insert(AlbumRef {
                        artist: key.artist.clone(),
                        album: album_key.clone(),
                    });
                }
                track_seen.insert(key);
            }
        }
        if let Some(map) = agg.artists.get(&range) {
            for artist_key in top_keys(map.iter().map(|(k, v)| (k.clone(), &v.0))) {
                if let Some((album_key, _)) = agg.top_albums.get(&artist_key) {
                    album_seen.insert(AlbumRef {
                        artist: artist_key.clone(),
                        album: album_key.clone(),
                    });
                }
                artist_seen.insert(artist_key);
            }
        }
    }

    let all_albums = agg.albums.get(&Range::AllTime);
    let mut albums = Vec::new();
    for album_ref in album_seen {
        let entry = all_albums.and_then(|m| m.get(&album_ref));
        if let (Some(artist_display), Some(entry)) =
            (agg.artist_names.get(&album_ref.artist), entry)
        {
            albums.push(AlbumNeed {
                album: album_ref,
                artist_display: artist_display.clone(),
                album_display: entry.album_display.clone(),
                mbid: entry.release_mbid.clone(),
            });
        }
    }

    let mut artists = Vec::new();
    for key in artist_seen {
        if let Some(display) = agg.artist_names.get(&key) {
            artists.push(ArtistNeed {
                key,
                display: display.clone(),
            });
        }
    }

    // Display names live in the all-time map, which contains every
    // track ever played (so any range top is present there).
    let all_tracks = agg.tracks.get(&Range::AllTime);
    let mut tracks = Vec::new();
    for track_ref in track_seen {
        if let Some((_, artist_display, track_display, _)) =
            all_tracks.and_then(|m| m.get(&track_ref))
        {
            tracks.push(TrackNeed {
                track: track_ref,
                artist_display: artist_display.clone(),
                track_display: track_display.clone(),
            });
        }
    }

    Needs {
        albums,
        artists,
        tracks,
    }
}

// ---------------------------------------------------------------- serialize

/// Cover art URL for an artist tile: the artist's own image when
/// resolved, falling back to the cover of its most-played album.
fn artist_image(
    agg: &Aggregated,
    artist_key: &ArtistKey,
    resolved: &ResolvedStats,
) -> Option<Href> {
    if let Some(url) = resolved.artist_cover.get(artist_key) {
        return Some(url.clone());
    }
    let (album_key, _) = agg.top_albums.get(artist_key)?;
    resolved
        .cover
        .get(&AlbumRef {
            artist: artist_key.clone(),
            album: album_key.clone(),
        })
        .cloned()
}

/// Build the top-N lists for one range.
fn build_range_stats(agg: &Aggregated, range: Range, resolved: &ResolvedStats) -> RangeStats {
    let artists = agg.artists.get(&range).map_or(vec![], |map| {
        sort_top(
            map.iter().map(|(key, value)| (key, &value.0)),
            |artist_key| {
                let (counter, display) = &map[artist_key];
                StatsItem {
                    name: display.clone(),
                    artist: None,
                    plays: counter.plays,
                    ms_played: counter.ms_played,
                    image: artist_image(agg, artist_key, resolved),
                    url: resolved.artist_url.get(artist_key).cloned(),
                }
            },
        )
    });

    let albums = agg.albums.get(&range).map_or(vec![], |map| {
        sort_top(
            map.iter().map(|(key, value)| (key, &value.counter)),
            |album_ref| {
                let entry = &map[album_ref];
                StatsItem {
                    name: entry.album_display.clone(),
                    artist: Some(entry.artist_display.clone()),
                    plays: entry.counter.plays,
                    ms_played: entry.counter.ms_played,
                    image: resolved.cover.get(album_ref).cloned(),
                    url: resolved.album_url.get(album_ref).cloned(),
                }
            },
        )
    });

    let tracks = agg.tracks.get(&range).map_or(vec![], |map| {
        sort_top(
            map.iter().map(|(key, value)| (key, &value.0)),
            |track_ref| {
                let (counter, artist_display, track_display, album_key) = &map[track_ref];
                let image = if album_key.as_ref().is_empty() {
                    None
                } else {
                    resolved
                        .cover
                        .get(&AlbumRef {
                            artist: track_ref.artist.clone(),
                            album: album_key.clone(),
                        })
                        .cloned()
                };
                StatsItem {
                    name: track_display.clone(),
                    artist: Some(artist_display.clone()),
                    plays: counter.plays,
                    ms_played: counter.ms_played,
                    image,
                    url: resolved.track_url.get(track_ref).cloned(),
                }
            },
        )
    });

    RangeStats {
        artists,
        albums,
        tracks,
    }
}

/// Serialize every range's top-N grids. `resolved` carries the cover
/// art, artist images, and page links (or `None` when absent — the
/// serialized JSON omits those keys entirely).
pub fn build_ranges(agg: &Aggregated, resolved: &ResolvedStats) -> serde_json::Value {
    let mut ranges = serde_json::Map::new();
    for range in Range::ALL {
        let rs = build_range_stats(agg, range, resolved);
        ranges.insert(
            range.key().to_string(),
            serde_json::to_value(rs).expect("serialize range stats"),
        );
    }
    json!(ranges)
}

// ---------------------------------------------------------------- tests

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{AlbumKey, ArtistKey, normalize, normalize_name};

    fn play(track: &str, artist: &str, album: &str, date: &str, ms: u64) -> serde_json::Value {
        json!({
            "trackName": track,
            "artists": [{ "artistName": artist }],
            "releaseName": album,
            "playedTime": date,
            "msPlayed": ms,
        })
    }

    #[test]
    fn aggregates_and_buckets_by_range() {
        let today = chrono::NaiveDate::from_ymd_opt(2026, 8, 3).unwrap();
        let plays = vec![
            play("Alpha", "Artist A", "Album A", "2026-07-20T10:00:00Z", 1000),
            play("Alpha", "Artist A", "Album A", "2026-07-21T10:00:00Z", 2000),
            play("Beta", "Artist B", "Album B", "2026-02-10T10:00:00Z", 3000),
            play("Gamma", "Artist A", "Album C", "2025-05-05T10:00:00Z", 4000),
            play("Delta", "Artist C", "Album D", "2020-01-01T10:00:00Z", 5000),
        ];
        let agg = aggregate(&plays, today);

        let all = agg.artists.get(&Range::AllTime).unwrap();
        assert_eq!(all.get(&ArtistKey::from("Artist A")).unwrap().0.plays, 3);
        assert_eq!(all.get(&ArtistKey::from("Artist B")).unwrap().0.plays, 1);
        assert_eq!(all.get(&ArtistKey::from("Artist C")).unwrap().0.plays, 1);

        // 1m: only Artist A (plays within 30 days of Aug 3).
        let one_m = agg.artists.get(&Range::OneMonth).unwrap();
        assert_eq!(one_m.len(), 1);
        assert_eq!(one_m.get(&ArtistKey::from("Artist A")).unwrap().0.plays, 2);

        // 6m: A (2 in-range) + B (1).
        let six_m = agg.artists.get(&Range::SixMonths).unwrap();
        assert_eq!(six_m.len(), 2);

        // Album with most plays per artist.
        assert_eq!(
            agg.top_albums.get(&ArtistKey::from("Artist A")).unwrap().0,
            AlbumKey::from("Album A")
        );

        // msPlayed accumulates.
        assert_eq!(
            all.get(&ArtistKey::from("Artist A")).unwrap().0.ms_played,
            7000
        );
    }

    #[test]
    fn top_lists_are_trimmed_to_nine() {
        let today = chrono::NaiveDate::from_ymd_opt(2026, 8, 3).unwrap();
        let plays: Vec<serde_json::Value> = (0..12)
            .map(|i| {
                play(
                    &format!("Track {i}"),
                    &format!("Artist {i}"),
                    &format!("Album {i}"),
                    "2026-07-20T10:00:00Z",
                    1000,
                )
            })
            .collect();
        let agg = aggregate(&plays, today);
        let resolved = ResolvedStats::default();
        let rs = build_range_stats(&agg, Range::OneMonth, &resolved);
        assert_eq!(rs.artists.len(), TOP_N);
        assert_eq!(rs.albums.len(), TOP_N);
        assert_eq!(rs.tracks.len(), TOP_N);
    }

    #[test]
    fn build_ranges_emits_exact_json_with_optional_fields() {
        let today = chrono::NaiveDate::from_ymd_opt(2026, 8, 3).unwrap();
        let plays = vec![
            play("Alpha", "Artist A", "Album A", "2026-07-20T10:00:00Z", 1000),
            play("Beta", "Artist B", "Album B", "2026-02-10T10:00:00Z", 3000),
        ];
        let agg = aggregate(&plays, today);

        let mut resolved = ResolvedStats::default();
        resolved.cover.insert(
            AlbumRef {
                artist: ArtistKey::from("Artist A"),
                album: AlbumKey::from("Album A"),
            },
            Href::from_str("https://example.com/cover.jpg").unwrap(),
        );
        resolved.artist_url.insert(
            ArtistKey::from("Artist A"),
            Href::from_str("https://musicbrainz.org/artist/abc").unwrap(),
        );

        let value = build_ranges(&agg, &resolved);

        // Artist tile: no `artist` field; no direct artist image, so
        // the tile falls back to its top album's cover; url present.
        let artist = value["all"]["artists"]
            .as_array()
            .unwrap()
            .iter()
            .find(|a| a["name"] == "Artist A")
            .unwrap();
        assert_eq!(artist["name"], "Artist A");
        assert!(artist.get("artist").is_none());
        assert_eq!(artist["url"], "https://musicbrainz.org/artist/abc");
        assert_eq!(artist["image"], "https://example.com/cover.jpg");

        // Album tile: artist present, cover present, no url.
        let album = value["all"]["albums"]
            .as_array()
            .unwrap()
            .iter()
            .find(|a| a["name"] == "Album A")
            .unwrap();
        assert_eq!(album["artist"], "Artist A");
        assert_eq!(album["image"], "https://example.com/cover.jpg");
        assert!(album.get("url").is_none());

        // The unresolved artist's tile carries no image/url keys at all.
        let artist_b = value["all"]["artists"]
            .as_array()
            .unwrap()
            .iter()
            .find(|a| a["name"] == "Artist B")
            .unwrap();
        assert_eq!(artist_b["name"], "Artist B");
        assert!(artist_b.get("image").is_none());
        assert!(artist_b.get("url").is_none());
    }

    #[test]
    fn needed_dedupes_across_ranges_and_carries_mbids() {
        let today = chrono::NaiveDate::from_ymd_opt(2026, 8, 3).unwrap();
        let mut plays = vec![
            play("Alpha", "Artist A", "Album A", "2026-07-20T10:00:00Z", 1000),
            play("Alpha", "Artist A", "Album A", "2026-01-20T10:00:00Z", 1000),
            play("Beta", "Artist B", "Album B", "2026-01-20T10:00:00Z", 1000),
        ];
        // Give Artist A's album an MBID on the most recent play.
        plays[0]["releaseMbId"] = json!("mbid:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
        let agg = aggregate(&plays, today);

        let needs = needed(&agg);
        // Album A (with MBID) and Album B, each once.
        assert_eq!(needs.albums.len(), 2);
        let album_a = needs
            .albums
            .iter()
            .find(|n| n.album_display == "Album A")
            .unwrap();
        assert_eq!(
            album_a.mbid.as_ref().unwrap().as_ref(),
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        );
        // Artists and tracks deduplicated.
        assert_eq!(needs.artists.len(), 2);
        assert_eq!(needs.tracks.len(), 2);
        let artist_a = needs
            .artists
            .iter()
            .find(|n| n.display == "Artist A")
            .unwrap();
        assert_eq!(artist_a.key, ArtistKey::from("Artist A"));
    }

    #[test]
    fn normalize_collapses_spelling_variants() {
        // The derivation lives in model; a thin smoke check that stats
        // and keys share it.
        assert_eq!(normalize("JAY-Z"), normalize("Jay Z"));
        assert_eq!(normalize_name("  Animals "), "animals");
    }
}
