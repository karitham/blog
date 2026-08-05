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
pub fn normalize_name(s: &str) -> String {
    s.trim().to_lowercase()
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
        // Display-name variants collapse to one key.
        assert_eq!(
            ArtistKey::from("JAY-Z feat. Beyoncé"),
            ArtistKey::from("Jay Z")
        );
        assert_eq!(
            ArtistKey::from("tofubeats, HITOMITOI"),
            ArtistKey::from("Tofubeats")
        );
        assert_eq!(ArtistKey::from("A$AP Rocky"), ArtistKey::from("a$ap-rocky"));
        // Album/track keys are trim+lowercase only — junction words stay.
        assert_eq!(AlbumKey::from("  Animals "), AlbumKey::from("animals"));
        assert_eq!(AlbumKey::from("Red & Blue"), AlbumKey::from("red & blue"));
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
