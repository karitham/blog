//! Typed domain model: the shared vocabulary between the pure stats
//! core, the resolution pipeline, and the cache.
//!
//! Keys are newtypes so a display name can never be used where a
//! normalized key is expected and an artist key can never be passed
//! where an album key belongs — the invariants the old `(String,
//! String)` soup enforced by convention are now compile-time. `Href`
//! carries a scheme allow-list because these strings get baked into
//! the site's HTML; `MusicBrainzId` validates the UUID shape so bogus
//! IDs from play records can't leak into API calls.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::str::FromStr;

// ---------------------------------------------------------------- keys

/// Normalized grouping key for artist names: lowercase, punctuation
/// treated as a word boundary, whitespace collapsed. The whole credit
/// is kept: a comma or ampersand inside a real name ("Tyler, The
/// Creator", "Earth, Wind & Fire") must not merge it with a different
/// artist. MBIDs, when present, are used for resolution, not identity.
pub fn normalize(s: &str) -> String {
    s.to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|word| !word.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
}

/// Plain key for album/track name components: collapse whitespace and
/// lowercase. Punctuation is significant here ("Fantastic, Vol. 2").
pub fn normalize_name(s: &str) -> String {
    s.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

macro_rules! key_type {
    ($name:ident, $normalize:expr) => {
        /// Normalized key; the only constructor is `From<&str>`, which
        /// applies the shared normalization so a raw display name can
        /// never be a key.
        #[derive(Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
        pub struct $name(String);

        impl From<&str> for $name {
            fn from(s: &str) -> Self {
                $name($normalize(s))
            }
        }

        impl From<String> for $name {
            fn from(s: String) -> Self {
                $name($normalize(&s))
            }
        }

        impl std::fmt::Debug for $name {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                write!(f, concat!(stringify!($name), "({:?})"), self.0)
            }
        }

        impl AsRef<str> for $name {
            fn as_ref(&self) -> &str {
                &self.0
            }
        }
    };
}

key_type!(ArtistKey, normalize);
key_type!(AlbumKey, normalize_name);
key_type!(TrackKey, normalize_name);

/// An (artist, album) pair key — distinct from `TrackRef` by type.
#[derive(Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Debug, Serialize, Deserialize)]
pub struct AlbumRef {
    pub artist: ArtistKey,
    pub album: AlbumKey,
}

/// An (artist, track) pair key — distinct from `AlbumRef` by type.
#[derive(Clone, PartialEq, Eq, Hash, PartialOrd, Ord, Debug, Serialize, Deserialize)]
pub struct TrackRef {
    pub artist: ArtistKey,
    pub track: TrackKey,
}

// ---------------------------------------------------------------- ids

/// Validated MusicBrainz ID (8-4-4-4-12 lowercase hex).
#[derive(Clone, PartialEq, Eq, Hash, Debug, Serialize, Deserialize)]
pub struct MusicBrainzId(String);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct InvalidId;

impl MusicBrainzId {
    fn validate(s: &str) -> bool {
        let b = s.as_bytes();
        if b.len() != 36 {
            return false;
        }
        b.iter().enumerate().all(|(i, c)| {
            if matches!(i, 8 | 13 | 18 | 23) {
                *c == b'-'
            } else {
                c.is_ascii_hexdigit()
            }
        })
    }
}

impl FromStr for MusicBrainzId {
    type Err = InvalidId;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        // Strip any `mbid:` (or other) prefix — some clients emit it.
        let id = s.rsplit(':').next().unwrap_or(s);
        if !Self::validate(id) {
            return Err(InvalidId);
        }
        Ok(MusicBrainzId(id.to_ascii_lowercase()))
    }
}

impl AsRef<str> for MusicBrainzId {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

/// Validated Wikidata entity ID (`Q` + digits).
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub struct WikidataId(String);

impl FromStr for WikidataId {
    type Err = InvalidId;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let digits = s.strip_prefix('Q').ok_or(InvalidId)?;
        if digits.is_empty() || !digits.bytes().all(|b| b.is_ascii_digit()) {
            return Err(InvalidId);
        }
        Ok(WikidataId(s.to_string()))
    }
}

impl AsRef<str> for WikidataId {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

/// A Wikimedia Commons image filename (no validation beyond non-empty —
/// the P18 chain is where filename-vs-URL confusion bites, so the type
/// keeps them apart).
#[derive(Clone, PartialEq, Eq, Hash, Debug)]
pub struct CommonsFilename(String);

impl FromStr for CommonsFilename {
    type Err = InvalidId;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        if s.is_empty() {
            return Err(InvalidId);
        }
        Ok(CommonsFilename(s.to_string()))
    }
}

impl AsRef<str> for CommonsFilename {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

// ---------------------------------------------------------------- urls

/// Validated absolute http(s) URL. Only the two safe schemes survive —
/// everything else would be baked into the site's HTML unescaped.
#[derive(Clone, PartialEq, Eq, Hash, Debug, Serialize, Deserialize)]
pub struct Href(String);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct InvalidHref;

impl FromStr for Href {
    type Err = InvalidHref;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let rest = s
            .strip_prefix("https://")
            .or_else(|| s.strip_prefix("http://"))
            .ok_or(InvalidHref)?;
        if rest.is_empty()
            || rest.starts_with('/')
            || rest.contains(|c: char| c.is_whitespace() || c.is_control())
        {
            return Err(InvalidHref);
        }
        Ok(Href(s.to_string()))
    }
}

impl AsRef<str> for Href {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

// ---------------------------------------------------------------- image

/// An image reference in the stats document. Resolution starts with a
/// remote URL; the mirror step swaps it for a local path. Keeping the
/// two states in one type means the serializer never has to guess
/// whether a string is a URL or a /img/... path.
#[derive(Clone, PartialEq, Eq, Debug, Serialize)]
#[serde(untagged)]
pub enum Image {
    Remote(Href),
    Local(String),
}

// ---------------------------------------------------------------- play

/// One normalized listening event. Built once at the raw-record
/// boundary so aggregation never reads transport field names.
///
/// The two Teal eras differ:
/// - alpha records have msPlayed (milliseconds) and no MBIDs;
/// - current records have duration (seconds) and often carry
///   artist/release/recording MBIDs.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Play {
    pub artist: ArtistKey,
    pub artist_display: String,
    pub artist_mbid: Option<MusicBrainzId>,
    pub album: Option<AlbumRef>,
    pub album_display: String,
    pub release_mbid: Option<MusicBrainzId>,
    pub track: TrackRef,
    pub track_display: String,
    pub recording_mbid: Option<MusicBrainzId>,
    pub listened_ms: u64,
    pub played_on: Option<chrono::NaiveDate>,
}

impl Play {
    /// Parse one Teal record. Returns None for records that cannot
    /// contribute to a stats bucket (no first artist, no track name).
    pub fn from_record(record: &serde_json::Value) -> Option<Play> {
        let artist = record.get("artists")?.as_array()?.first()?;
        let artist_display = artist.get("artistName")?.as_str()?.trim();
        if artist_display.is_empty() {
            return None;
        }
        let artist_key = ArtistKey::from(artist_display);

        let track_display = record.get("trackName")?.as_str()?.trim();
        if track_display.is_empty() {
            return None;
        }
        let track_key = TrackKey::from(track_display);

        let (album, album_display) = match record
            .get("releaseName")
            .and_then(serde_json::Value::as_str)
            .map(str::trim)
        {
            Some(name) if !name.is_empty() => (
                Some(AlbumRef {
                    artist: artist_key.clone(),
                    album: AlbumKey::from(name),
                }),
                name.to_string(),
            ),
            _ => (None, String::new()),
        };

        // Alpha records carry milliseconds; current records carry
        // seconds. Normalize both to milliseconds.
        let listened_ms = record
            .get("msPlayed")
            .and_then(serde_json::Value::as_u64)
            .or_else(|| {
                record
                    .get("duration")
                    .and_then(serde_json::Value::as_u64)
                    .map(|seconds| seconds.saturating_mul(1000))
            })
            .unwrap_or(0);

        let played_on = record
            .get("playedTime")
            .and_then(serde_json::Value::as_str)
            .and_then(|s| s.get(..10))
            .and_then(|day| chrono::NaiveDate::parse_from_str(day, "%Y-%m-%d").ok());

        Some(Play {
            artist: artist_key.clone(),
            artist_display: artist_display.to_string(),
            artist_mbid: parse_mbid(artist, "artistMbId"),
            album,
            album_display,
            release_mbid: parse_mbid(record, "releaseMbId"),
            track: TrackRef {
                artist: artist_key,
                track: track_key,
            },
            track_display: track_display.to_string(),
            recording_mbid: parse_mbid(record, "recordingMbId"),
            listened_ms,
            played_on,
        })
    }
}

fn parse_mbid(value: &serde_json::Value, field: &str) -> Option<MusicBrainzId> {
    value
        .get(field)
        .and_then(serde_json::Value::as_str)
        .and_then(|s| MusicBrainzId::from_str(s).ok())
}

// ---------------------------------------------------------------- resolved

/// What resolution must produce before serialization: cover art,
/// artist images, and MusicBrainz page links for the top-N entries.
#[derive(Default)]
pub struct ResolvedStats {
    pub cover: HashMap<AlbumRef, Href>,
    pub artist_cover: HashMap<ArtistKey, Href>,
    pub album_url: HashMap<AlbumRef, Href>,
    pub artist_url: HashMap<ArtistKey, Href>,
    pub track_url: HashMap<TrackRef, Href>,
}

// ---------------------------------------------------------------- tests

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn key_constructors_normalize() {
        // Spelling variants collapse to one key.
        assert_eq!(ArtistKey::from("JAY-Z"), ArtistKey::from("Jay Z"));
        assert_eq!(ArtistKey::from("A$AP Rocky"), ArtistKey::from("a$ap-rocky"));
        // Embedded commas/ampersands are part of the name, not a collab
        // separator: these must not merge with a different artist.
        assert_ne!(
            ArtistKey::from("Tyler, The Creator"),
            ArtistKey::from("Tyler")
        );
        assert_ne!(
            ArtistKey::from("Earth, Wind & Fire"),
            ArtistKey::from("Earth")
        );
        // Album/track keys normalize whitespace and case only.
        assert_eq!(AlbumKey::from("  Animals "), AlbumKey::from("animals"));
        assert_eq!(AlbumKey::from("Red & Blue"), AlbumKey::from("red & blue"));
        assert_eq!(
            AlbumKey::from("Fantastic, Vol. 2"),
            AlbumKey::from("fantastic,  vol. 2")
        );
        // Key kinds are distinct types: this is a compile-time property,
        // asserted here so it can't silently regress to one string type.
        let _: AlbumRef = AlbumRef {
            artist: ArtistKey::from("a"),
            album: AlbumKey::from("b"),
        };
        let _: TrackRef = TrackRef {
            artist: ArtistKey::from("a"),
            track: TrackKey::from("c"),
        };
    }

    #[test]
    fn mbid_validates_uuid_shape() {
        let ok = "0a0a0a0a-0b0b-0c0c-0d0d-0e0e0f0f0f0f";
        assert_eq!(MusicBrainzId::from_str(ok).unwrap().as_ref(), ok);
        // Mixed case normalizes to lowercase; `mbid:` prefix is stripped.
        assert_eq!(
            MusicBrainzId::from_str(&format!("mbid:{ok}"))
                .unwrap()
                .as_ref(),
            ok
        );
        assert_eq!(
            MusicBrainzId::from_str("0A0A0A0A-0B0B-0C0C-0D0D-0E0E0F0F0F0F")
                .unwrap()
                .as_ref(),
            ok
        );
        for bad in [
            "",
            "0a0a0a0a-0b0b-0c0c-0d0d",              // too short
            "0a0a0a0a-0b0b-0c0c-0d0d-0e0e0f0f0f0g", // non-hex
            "0a0a0a0a0b0b0c0c0d0d0e0e0f0f0f0f",     // no hyphens
            "0a0a0a0a-0b0b-0c0c-0d0d0e0e-0f0f0f0f", // wrong grouping
            "mbid:",                                // empty after prefix
        ] {
            assert!(MusicBrainzId::from_str(bad).is_err(), "{bad:?} should fail");
        }
    }

    #[test]
    fn href_rejects_non_http_schemes() {
        for ok in [
            "https://example.com",
            "http://example.com/a/b.png",
            "https://host",
        ] {
            assert!(Href::from_str(ok).is_ok(), "{ok:?} should pass");
        }
        for bad in [
            "",
            "example.com",   // relative
            "//example.com", // protocol-relative
            "file:///etc/passwd",
            "ftp://example.com",
            "javascript:alert(1)",
            "data:text/html,<b>x</b>",
            "https:///path", // empty host
            "https://exa mple.com",
        ] {
            assert!(Href::from_str(bad).is_err(), "{bad:?} should fail");
        }
    }

    fn raw(play: serde_json::Value) -> Play {
        Play::from_record(&play).expect("valid play")
    }

    #[test]
    fn play_parses_alpha_and_current_shapes() {
        let alpha = raw(serde_json::json!({
            "$type": "fm.teal.alpha.feed.play",
            "artists": [{ "artistName": "New World Sound" }],
            "trackName": "Flute",
            "releaseName": "Flute",
            "msPlayed": 287_503,
            "playedTime": "2014-12-11T04:17:04Z"
        }));
        assert_eq!(alpha.listened_ms, 287_503);
        assert_eq!(
            alpha.played_on,
            Some(chrono::NaiveDate::from_ymd_opt(2014, 12, 11).unwrap())
        );
        assert!(alpha.artist_mbid.is_none());

        let current = raw(serde_json::json!({
            "$type": "fm.teal.feed.play",
            "artists": [{
                "artistName": "Ol’ Dirty Bastard",
                "artistMbId": "mbid:d50548a0-3cfd-4d7a-964b-0aef6545d819"
            }],
            "trackName": "Cuttin' Headz",
            "releaseName": "Return to the 36 Chambers",
            "duration": 148,
            "playedTime": "2026-08-13T14:29:26Z",
            "releaseMbId": "mbid:212ea289-d12d-4820-aff6-fbc5bd60d829",
            "recordingMbId": "mbid:478c78d0-585a-46f1-a245-abfad69265e1"
        }));
        // duration is seconds, normalized to milliseconds.
        assert_eq!(current.listened_ms, 148_000);
        assert_eq!(
            current.artist_mbid.as_ref().unwrap().as_ref(),
            "d50548a0-3cfd-4d7a-964b-0aef6545d819"
        );
        assert_eq!(
            current.release_mbid.as_ref().unwrap().as_ref(),
            "212ea289-d12d-4820-aff6-fbc5bd60d829"
        );
        assert_eq!(
            current.recording_mbid.as_ref().unwrap().as_ref(),
            "478c78d0-585a-46f1-a245-abfad69265e1"
        );
    }

    #[test]
    fn play_rejects_incomplete_records_and_handles_missing_album() {
        assert!(Play::from_record(&serde_json::json!({})).is_none());
        assert!(
            Play::from_record(&serde_json::json!({
                "artists": [],
                "trackName": "x"
            }))
            .is_none()
        );
        assert!(
            Play::from_record(&serde_json::json!({
                "artists": [{ "artistName": "  " }],
                "trackName": "x"
            }))
            .is_none()
        );
        let no_album = raw(serde_json::json!({
            "artists": [{ "artistName": "A" }],
            "trackName": "T",
            "playedTime": "2026-01-01T00:00:00Z"
        }));
        assert!(no_album.album.is_none());
        assert_eq!(no_album.album_display, "");
        assert_eq!(no_album.listened_ms, 0);
    }

    #[test]
    fn wikidata_and_commons_ids() {
        assert!(WikidataId::from_str("Q130798").is_ok());
        assert!(WikidataId::from_str("q130798").is_err()); // uppercase Q only
        assert!(WikidataId::from_str("Q").is_err());
        assert!(WikidataId::from_str("Q12x").is_err());
        assert!(CommonsFilename::from_str("File:X.jpg").is_ok());
        assert!(CommonsFilename::from_str("").is_err());
    }
}
