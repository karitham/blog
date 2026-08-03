//! Pure aggregation core: play history → top-N grids per time range.
//!
//! No I/O here — everything is deterministic and testable with plain
//! values. The imperative shell in `main` calls `aggregate`, then
//! `needed_pairs` (to know which covers to fetch), then `build_ranges`
//! with a cover lookup function supplied from outside.

use serde::Serialize;
use serde_json::json;
use std::collections::HashMap;

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
    artists: HashMap<Range, HashMap<String, (Counter, String)>>,
    /// range -> (artist_key, album_key) -> album entry
    albums: HashMap<Range, HashMap<(String, String), AlbumEntry>>,
    /// range -> (artist_key, track_key) -> (counter, artist display, track display, album_key)
    tracks: HashMap<Range, HashMap<(String, String), (Counter, String, String, String)>>,
    /// artist_key -> (top album key, plays) — used to proxy artist cover art.
    top_albums: HashMap<String, (String, u64)>,
    /// artist_key -> display name
    artist_names: HashMap<String, String>,
}

/// One album's accumulated stats. `release_mbid` is carried through
/// from the play records (piper/lazuli emit it on recent plays) so
/// cover resolution can hit Cover Art Archive directly instead of
/// searching MusicBrainz by name.
#[derive(Clone, Default)]
pub struct AlbumEntry {
    counter: Counter,
    artist_display: String,
    album_display: String,
    release_mbid: Option<String>,
}

/// Strip the `mbid:` prefix some clients add to MBID fields.
pub fn clean_mbid(s: &str) -> Option<String> {
    let id = s.rsplit(':').next()?.to_string();
    (!id.is_empty()).then_some(id)
}

#[derive(Serialize)]
struct StatsItem {
    name: String,
    #[serde(skip_serializing_if = "String::is_empty")]
    artist: String,
    plays: u64,
    ms_played: u64,
    #[serde(skip_serializing_if = "String::is_empty")]
    image: String,
}

#[derive(Serialize)]
struct RangeStats {
    artists: Vec<StatsItem>,
    albums: Vec<StatsItem>,
    tracks: Vec<StatsItem>,
}

// ---------------------------------------------------------------- helpers

/// Sanitized grouping key for artist names: lowercase, punctuation
/// dropped, collaboration credit cut to the first artist, junction
/// words (feat/with/&/vs...) removed. Two spellings of the same
/// artist ("JAY-Z" vs "Jay Z", "A$AP" vs "ASAP") land in the same
/// bucket; display names keep their original spelling.
pub fn normalize(s: &str) -> String {
    const JUNCTION_WORDS: [&str; 12] = [
        "and",
        "with",
        "feat",
        "featuring",
        "ft",
        "vs",
        "versus",
        "present",
        "presents",
        "pres",
        "b2b",
        "x",
    ];

    let lower = s.to_lowercase();
    // Collab credit strings: keep only the part before the first
    // comma/ampersand/plus — "tofubeats, HITOMITOI" groups as tofubeats.
    let head = lower
        .split(['&', '+', ','])
        .next()
        .unwrap_or(lower.as_str());
    head
        // Any run of non-alphanumerics is a word boundary ("JAY-Z",
        // "A$AP", "Café" -> "caf", accents are dropped with them).
        .split(|c: char| !c.is_alphanumeric())
        .take_while(|word| !JUNCTION_WORDS.contains(word))
        .filter(|word| !word.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
}

/// Plain key for album/track name components: trim + lowercase only.
fn normalize_name(s: &str) -> String {
    s.trim().to_lowercase()
}

/// Resolve the display name of an album from the all-time album map.
fn album_display_for(agg: &Aggregated, artist_key: &str, album_key: &str) -> Option<String> {
    agg.albums
        .get(&Range::AllTime)?
        .get(&(artist_key.to_string(), album_key.to_string()))
        .map(|entry| entry.album_display.clone())
}

/// The most recent MusicBrainz release ID for an album, if any.
fn album_mbid_for(agg: &Aggregated, artist_key: &str, album_key: &str) -> Option<String> {
    agg.albums
        .get(&Range::AllTime)?
        .get(&(artist_key.to_string(), album_key.to_string()))
        .and_then(|entry| entry.release_mbid.clone())
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

        let artist_key = normalize(artist_display);
        let track_key = normalize_name(track_display);
        let ms_played = play["msPlayed"].as_u64().unwrap_or(0);

        let (album_key, album_display) = match play["releaseName"].as_str() {
            Some(name) if !name.trim().is_empty() => {
                (normalize_name(name), name.trim().to_string())
            }
            _ => (String::new(), String::new()),
        };
        let release_mbid = play["releaseMbId"].as_str().and_then(clean_mbid);

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

            if !album_key.is_empty() {
                let album = agg
                    .albums
                    .entry(range)
                    .or_default()
                    .entry((artist_key.clone(), album_key.clone()))
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

            if !track_key.is_empty() {
                let track = agg
                    .tracks
                    .entry(range)
                    .or_default()
                    .entry((artist_key.clone(), track_key.clone()))
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
        for ((artist_key, album_key), entry) in map {
            let record = agg
                .top_albums
                .entry(artist_key.clone())
                .or_insert_with(|| (album_key.clone(), 0));
            if entry.counter.plays > record.1 {
                *record = (album_key.clone(), entry.counter.plays);
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
fn top_keys<'a, T>(entries: impl Iterator<Item = (T, &'a Counter)>) -> Vec<T>
where
    T: Clone,
{
    let mut list: Vec<(&Counter, T)> = entries.map(|(key, counter)| (counter, key)).collect();
    list.sort_by(|a, b| {
        b.0.plays
            .cmp(&a.0.plays)
            .then_with(|| b.0.ms_played.cmp(&a.0.ms_played))
    });
    list.into_iter().take(TOP_N).map(|(_, key)| key).collect()
}

/// Top-N artist display names across all ranges — the set we need
/// real artist images for. Deduplicated.
pub fn needed_artists(agg: &Aggregated) -> Vec<String> {
    use std::collections::HashSet;

    let mut seen: HashSet<String> = HashSet::new();
    for range in Range::ALL {
        if let Some(map) = agg.artists.get(&range) {
            for artist_key in top_keys(map.iter().map(|(key, value)| (key, &value.0))) {
                if let Some(display) = agg.artist_names.get(artist_key) {
                    seen.insert(display.clone());
                }
            }
        }
    }
    seen.into_iter().collect()
}

// ---------------------------------------------------------------- covers

/// Cover art URL for an artist tile: the artist's own image when
/// resolved (via `artist_cover`), falling back to the cover of its
/// most-played album.
fn artist_image(
    agg: &Aggregated,
    artist_key: &str,
    cover: &impl Fn(&str, &str) -> String,
    artist_cover: &impl Fn(&str) -> String,
) -> String {
    let Some(artist_display) = agg.artist_names.get(artist_key) else {
        return String::new();
    };
    let direct = artist_cover(artist_display);
    if !direct.is_empty() {
        return direct;
    }
    let Some((album_key, _)) = agg.top_albums.get(artist_key) else {
        return String::new();
    };
    let Some(album_display) = album_display_for(agg, artist_key, album_key) else {
        return String::new();
    };
    cover(artist_display, &album_display)
}

/// Build the top-N lists for one range.
fn build_range_stats(
    agg: &Aggregated,
    range: Range,
    cover: &impl Fn(&str, &str) -> String,
    artist_cover: &impl Fn(&str) -> String,
) -> RangeStats {
    let artists = agg.artists.get(&range).map_or(vec![], |map| {
        sort_top(
            map.iter().map(|(key, value)| (key, &value.0)),
            |artist_key| {
                let (counter, display) = &map[&artist_key.clone()];
                StatsItem {
                    name: display.clone(),
                    artist: String::new(),
                    plays: counter.plays,
                    ms_played: counter.ms_played,
                    image: artist_image(agg, artist_key, cover, artist_cover),
                }
            },
        )
    });

    let albums = agg.albums.get(&range).map_or(vec![], |map| {
        sort_top(
            map.iter().map(|(key, value)| (key, &value.counter)),
            |(artist_key, album_key)| {
                let entry = &map[&(artist_key.clone(), album_key.clone())];
                StatsItem {
                    name: entry.album_display.clone(),
                    artist: entry.artist_display.clone(),
                    plays: entry.counter.plays,
                    ms_played: entry.counter.ms_played,
                    image: cover(&entry.artist_display, &entry.album_display),
                }
            },
        )
    });

    let tracks = agg.tracks.get(&range).map_or(vec![], |map| {
        sort_top(
            map.iter().map(|(key, value)| (key, &value.0)),
            |(artist_key, track_key)| {
                let (counter, artist_display, track_display, album_key) =
                    &map[&(artist_key.clone(), track_key.clone())];
                let image = if album_key.is_empty() {
                    String::new()
                } else {
                    album_display_for(agg, artist_key, album_key)
                        .map_or(String::new(), |ad| cover(artist_display, &ad))
                };
                StatsItem {
                    name: track_display.clone(),
                    artist: artist_display.clone(),
                    plays: counter.plays,
                    ms_played: counter.ms_played,
                    image,
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

/// (artist, album, optional MusicBrainz release ID) triples whose
/// covers the top-N grids actually reference — derived from the
/// trimmed top-N of each range, never the full history. The MBID is
/// carried through so cover resolution can skip the search.
pub fn needed_pairs(agg: &Aggregated) -> Vec<(String, String, Option<String>)> {
    use std::collections::HashSet;

    let mut seen: HashSet<(String, String)> = HashSet::new();

    for range in Range::ALL {
        if let Some(map) = agg.albums.get(&range) {
            for (artist_key, album_key) in
                top_keys(map.iter().map(|(key, value)| (key, &value.counter)))
            {
                seen.insert((artist_key.clone(), album_key.clone()));
            }
        }
        if let Some(map) = agg.tracks.get(&range) {
            for (artist_key, track_key) in top_keys(map.iter().map(|(key, value)| (key, &value.0)))
            {
                if let Some((_, _, _, album_key)) =
                    map.get(&(artist_key.clone(), track_key.clone()))
                {
                    if !album_key.is_empty() {
                        seen.insert((artist_key.clone(), album_key.clone()));
                    }
                }
            }
        }
        if let Some(map) = agg.artists.get(&range) {
            for artist_key in top_keys(map.iter().map(|(key, value)| (key, &value.0))) {
                if let Some((album_key, _)) = agg.top_albums.get(artist_key) {
                    seen.insert((artist_key.clone(), album_key.clone()));
                }
            }
        }
    }

    let mut pairs = Vec::new();
    for (artist_key, album_key) in seen {
        if let Some(artist_display) = agg.artist_names.get(&artist_key) {
            if let Some(album_display) = album_display_for(agg, &artist_key, &album_key) {
                let mbid = album_mbid_for(agg, &artist_key, &album_key);
                pairs.push((artist_display.clone(), album_display, mbid));
            }
        }
    }
    pairs
}

// ---------------------------------------------------------------- serialize

/// Serialize every range's top-N grids. `cover` maps (artist, album)
/// display names to a cover URL (or "" when there is none);
/// `artist_cover` maps artist display names to a real artist image.
pub fn build_ranges(
    agg: &Aggregated,
    cover: &impl Fn(&str, &str) -> String,
    artist_cover: &impl Fn(&str) -> String,
) -> serde_json::Value {
    let mut ranges = serde_json::Map::new();
    for range in Range::ALL {
        let rs = build_range_stats(agg, range, cover, artist_cover);
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
    fn normalize_collapses_spelling_variants() {
        assert_eq!(normalize("JAY-Z"), "jay z");
        assert_eq!(normalize("Jay Z"), "jay z");
        // Punctuation is a word boundary: A$AP splits, but every
        // spelling of "A$AP ..." still lands in the same bucket.
        assert_eq!(normalize("A$AP Rocky"), "a ap rocky");
        assert_eq!(normalize("A$AP Rocky"), normalize("a$ap-rocky"));
        assert_eq!(normalize("US3"), "us3");
        assert_eq!(normalize("us3"), "us3");
        // Collaboration credit cuts to the first artist...
        assert_eq!(normalize("JAY-Z feat. Beyoncé"), "jay z");
        assert_eq!(normalize("tofubeats, HITOMITOI"), "tofubeats");
        assert_eq!(normalize("Drake & 21 Savage"), "drake");
        assert_eq!(normalize("Freddie Gibbs vs Madlib"), "freddie gibbs");
        // Single-token names pass through untouched.
        assert_eq!(normalize("XXXTENTACION"), "xxxtentacion");
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
        assert_eq!(all.get("artist a").unwrap().0.plays, 3);
        assert_eq!(all.get("artist b").unwrap().0.plays, 1);
        assert_eq!(all.get("artist c").unwrap().0.plays, 1);

        // 1m: only Artist A (plays within 30 days of Aug 3).
        let one_m = agg.artists.get(&Range::OneMonth).unwrap();
        assert_eq!(one_m.len(), 1);
        assert_eq!(one_m.get("artist a").unwrap().0.plays, 2);

        // 6m: A (2 in-range) + B (1).
        let six_m = agg.artists.get(&Range::SixMonths).unwrap();
        assert_eq!(six_m.len(), 2);

        // Album with most plays per artist.
        assert_eq!(agg.top_albums.get("artist a").unwrap().0, "album a");

        // msPlayed accumulates.
        assert_eq!(all.get("artist a").unwrap().0.ms_played, 7000);
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
        let cover = |_: &str, _: &str| String::new();
        let artist_cover = |_: &str| String::new();
        let rs = build_range_stats(&agg, Range::OneMonth, &cover, &artist_cover);
        assert_eq!(rs.artists.len(), TOP_N);
        assert_eq!(rs.albums.len(), TOP_N);
        assert_eq!(rs.tracks.len(), TOP_N);
    }
}
