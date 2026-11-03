//! Impure gather: MusicBrainz / Cover Art Archive / Wikidata / Commons
//! queries. One deep module owning the endpoint URLs, rate limits, and
//! JSON-shape parsing — the rest of the pipeline never knows a hostname.
//!
//! The JSON→typed parsers are pure and tested with fixtures; the
//! endpoint round-trips are tested against a localhost stub server.

use crate::model::{CommonsFilename, Href, MusicBrainzId, WikidataId};
use crate::net::{HttpClient, HttpFetch, Limiter};
use crate::resolve::{Outcome, Query, ResolvePlan};
use rayon::prelude::*;
use serde_json::Value;
use std::str::FromStr;

/// Where each API lives. Production hits the real hosts; tests point
/// every endpoint at one localhost stub.
pub struct EndpointBases {
    pub musicbrainz: String,
    pub coverart: String,
    pub wikidata: String,
    pub commons: String,
}

impl EndpointBases {
    pub fn production() -> Self {
        Self {
            musicbrainz: "https://musicbrainz.org".to_string(),
            coverart: "https://coverartarchive.org".to_string(),
            wikidata: "https://www.wikidata.org".to_string(),
            commons: "https://commons.wikimedia.org".to_string(),
        }
    }

    #[cfg(test)]
    pub fn localhost(port: u16) -> Self {
        let base = format!("http://127.0.0.1:{port}");
        Self {
            musicbrainz: base.clone(),
            coverart: base.clone(),
            wikidata: base.clone(),
            commons: base,
        }
    }
}

/// Per-endpoint rate limits, single-sourced here. MusicBrainz and
/// Cover Art Archive document 1 req/s and enforce it; Wikimedia image
/// serving tolerates more.
pub struct RateLimits {
    pub musicbrainz: Limiter,
    pub coverart: Limiter,
    pub wikidata: Limiter,
    pub commons: Limiter,
    pub coverart_img: Limiter,
    pub bluesky: Limiter,
}

impl RateLimits {
    pub fn production() -> Self {
        Self {
            musicbrainz: Limiter::new(1.0),
            coverart: Limiter::new(1.0),
            wikidata: Limiter::new(1.0),
            commons: Limiter::new(4.0),
            coverart_img: Limiter::new(1.0),
            bluesky: Limiter::new(4.0),
        }
    }

    /// Tests only: no sleeping between requests.
    #[cfg(test)]
    pub fn unthrottled() -> Self {
        Self {
            musicbrainz: Limiter::new(1_000_000.0),
            coverart: Limiter::new(1_000_000.0),
            wikidata: Limiter::new(1_000_000.0),
            commons: Limiter::new(1_000_000.0),
            coverart_img: Limiter::new(1_000_000.0),
            bluesky: Limiter::new(1_000_000.0),
        }
    }
}

/// The impure gather boundary. Owns no cache — returns raw outcomes.
/// The HTTP client is behind the `HttpFetch` seam so tests substitute
/// a canned fake (see `testutil`); the network never leaks into the
/// decision logic.
pub struct MusicSources {
    pub(crate) client: Box<dyn HttpFetch>,
    pub(crate) limits: RateLimits,
    bases: EndpointBases,
}

impl MusicSources {
    pub fn new() -> Self {
        Self {
            client: Box::new(HttpClient::new()),
            limits: RateLimits::production(),
            bases: EndpointBases::production(),
        }
    }

    /// Tests only: all endpoints against one canned fake, no rate
    /// limiting.
    #[cfg(test)]
    pub fn for_tests(client: Box<dyn HttpFetch>) -> Self {
        Self {
            client,
            limits: RateLimits::unthrottled(),
            bases: EndpointBases::localhost(0),
        }
    }

    /// Run every query in the plan (parallel, per-endpoint limiters),
    /// returning per-query outcomes.
    pub fn run_queries(&self, plan: &ResolvePlan) -> Vec<(Query, Outcome)> {
        plan.queries
            .par_iter()
            .map(|query| {
                let outcome = match query {
                    Query::Album {
                        artist_display,
                        album_display,
                        mbid,
                        ..
                    } => {
                        let release = match mbid {
                            Some(mbid) => Some(mbid.clone()),
                            None => self.release_id(artist_display, album_display),
                        };
                        match release {
                            Some(mbid) => Outcome::Album {
                                cover: self.cover_art_url(&mbid),
                                url: self.release_url(&mbid),
                                mbid: Some(mbid),
                            },
                            None => Outcome::Album {
                                mbid: None,
                                cover: None,
                                url: None,
                            },
                        }
                    }
                    Query::Artist {
                        artist_display,
                        mbid,
                        ..
                    } => {
                        let artist = match mbid {
                            Some(mbid) => Some(mbid.clone()),
                            None => self.artist_id(artist_display),
                        };
                        match artist {
                            Some(mbid) => Outcome::Artist {
                                image: self.artist_image_for_id(&mbid),
                                url: self.artist_url(&mbid),
                                mbid: Some(mbid),
                            },
                            None => Outcome::Artist {
                                mbid: None,
                                image: None,
                                url: None,
                            },
                        }
                    }
                    Query::Track {
                        artist_display,
                        track_display,
                        mbid,
                        ..
                    } => {
                        let recording = match mbid {
                            Some(mbid) => Some(mbid.clone()),
                            None => self.recording_id(artist_display, track_display),
                        };
                        match recording {
                            Some(mbid) => Outcome::Track {
                                url: self.recording_url(&mbid),
                                mbid: Some(mbid),
                            },
                            None => Outcome::Track {
                                mbid: None,
                                url: None,
                            },
                        }
                    }
                };
                (query.clone(), outcome)
            })
            .collect()
    }

    // ---------------------------------------------------- endpoints

    fn release_id(&self, artist: &str, album: &str) -> Option<MusicBrainzId> {
        self.limits.musicbrainz.acquire();
        let query = format!(
            "release:\"{}\" AND artist:\"{}\"",
            clean_query(album),
            clean_query(artist)
        );
        let body = self.client.get_json(
            &format!("{}/ws/2/release", self.bases.musicbrainz),
            &[("query", &query), ("fmt", "json"), ("limit", "1")],
        )?;
        release_id_from_json(&body)
    }

    /// Cover Art Archive front image for a release, 500px. A non-2xx
    /// response (404 — no front art) is a permanent miss.
    fn cover_art_url(&self, mbid: &MusicBrainzId) -> Option<Href> {
        self.limits.coverart.acquire();
        let url = format!(
            "{}/release/{}/front-500",
            self.bases.coverart,
            mbid.as_ref()
        );
        self.client
            .check(&url)
            .then(|| Href::from_str(&url).ok())
            .flatten()
    }

    fn release_url(&self, mbid: &MusicBrainzId) -> Option<Href> {
        Href::from_str(&format!(
            "{}/release/{}",
            self.bases.musicbrainz,
            mbid.as_ref()
        ))
        .ok()
    }

    fn artist_id(&self, name: &str) -> Option<MusicBrainzId> {
        self.limits.musicbrainz.acquire();
        let query = format!("artist:\"{}\"", clean_query(name));
        let body = self.client.get_json(
            &format!("{}/ws/2/artist", self.bases.musicbrainz),
            &[("query", &query), ("fmt", "json"), ("limit", "1")],
        )?;
        artist_id_from_json(&body)
    }

    fn artist_url(&self, mbid: &MusicBrainzId) -> Option<Href> {
        Href::from_str(&format!(
            "{}/artist/{}",
            self.bases.musicbrainz,
            mbid.as_ref()
        ))
        .ok()
    }

    /// MB artist lookup with URL relations → the artist's Wikidata QID.
    fn wikidata_qid(&self, mbid: &MusicBrainzId) -> Option<WikidataId> {
        self.limits.musicbrainz.acquire();
        let body = self.client.get_json(
            &format!("{}/ws/2/artist/{}", self.bases.musicbrainz, mbid.as_ref()),
            &[("inc", "url-rels"), ("fmt", "json")],
        )?;
        wikidata_qid_from_json(&body)
    }

    /// Wikidata `P18` (image) claim → Commons filename.
    fn wikidata_p18(&self, qid: &WikidataId) -> Option<CommonsFilename> {
        self.limits.wikidata.acquire();
        let body = self.client.get_json(
            &format!("{}/w/api.php", self.bases.wikidata),
            &[
                ("action", "wbgetclaims"),
                ("property", "P18"),
                ("entity", qid.as_ref()),
                ("format", "json"),
            ],
        )?;
        p18_filename_from_json(&body)
    }

    /// Commons image URL for a filename, resized to 600px. Building
    /// the URL is local; the downloader owns the Commons limiter.
    fn commons_url(&self, filename: &CommonsFilename) -> Option<Href> {
        Href::from_str(&format!(
            "{}/wiki/Special:FilePath/{}?width=600",
            self.bases.commons,
            percent_encode(filename.as_ref())
        ))
        .ok()
    }

    /// Artist photo via the Wikidata chain: url-rels → P18 → Commons
    /// URL. The caller supplies the artist MBID, either from the play
    /// record or from one name search.
    fn artist_image_for_id(&self, mbid: &MusicBrainzId) -> Option<Href> {
        let qid = self.wikidata_qid(mbid)?;
        let filename = self.wikidata_p18(&qid)?;
        self.commons_url(&filename)
    }

    fn recording_id(&self, artist: &str, track: &str) -> Option<MusicBrainzId> {
        self.limits.musicbrainz.acquire();
        let query = format!(
            "recording:\"{}\" AND artist:\"{}\"",
            clean_query(track),
            clean_query(artist)
        );
        let body = self.client.get_json(
            &format!("{}/ws/2/recording", self.bases.musicbrainz),
            &[("query", &query), ("fmt", "json"), ("limit", "1")],
        )?;
        recording_id_from_json(&body)
    }

    fn recording_url(&self, mbid: &MusicBrainzId) -> Option<Href> {
        Href::from_str(&format!(
            "{}/recording/{}",
            self.bases.musicbrainz,
            mbid.as_ref()
        ))
        .ok()
    }
}

// ---------------------------------------------------- pure parsers

/// MusicBrainz release search response → best-guess release MBID.
pub(crate) fn release_id_from_json(body: &Value) -> Option<MusicBrainzId> {
    let id = body["releases"].as_array()?.first()?.get("id")?.as_str()?;
    MusicBrainzId::from_str(id).ok()
}

/// MusicBrainz artist search response → best-guess artist MBID.
pub(crate) fn artist_id_from_json(body: &Value) -> Option<MusicBrainzId> {
    let id = body["artists"].as_array()?.first()?.get("id")?.as_str()?;
    MusicBrainzId::from_str(id).ok()
}

/// MusicBrainz recording search response → best-guess recording MBID.
pub(crate) fn recording_id_from_json(body: &Value) -> Option<MusicBrainzId> {
    let id = body["recordings"]
        .as_array()?
        .first()?
        .get("id")?
        .as_str()?;
    MusicBrainzId::from_str(id).ok()
}

/// MB artist url-rels response → the artist's Wikidata QID.
pub(crate) fn wikidata_qid_from_json(body: &Value) -> Option<WikidataId> {
    for relation in body["relations"].as_array()? {
        if relation["type"].as_str() == Some("wikidata") {
            let url = relation["url"]["resource"].as_str()?;
            // https://www.wikidata.org/wiki/Q130798
            return url
                .rsplit('/')
                .next()
                .and_then(|q| WikidataId::from_str(q).ok());
        }
    }
    None
}

/// Wikidata `wbgetclaims` response → the P18 Commons filename.
pub(crate) fn p18_filename_from_json(body: &Value) -> Option<CommonsFilename> {
    let name = body["claims"]["P18"]
        .as_array()?
        .first()?
        .get("mainsnak")?
        .get("datavalue")?
        .get("value")?
        .as_str()?;
    CommonsFilename::from_str(name).ok()
}

fn clean_query(s: &str) -> String {
    s.replace(['"', '\\'], "")
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

// ---------------------------------------------------------------- tests

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{AlbumKey, AlbumRef, ArtistKey, TrackKey, TrackRef};
    use crate::testutil::{Response, StubClient};
    use serde_json::json;

    // -------------------------------------------- pure parsers

    #[test]
    fn parsers_extract_ids_from_json() {
        let release =
            json!({ "releases": [{ "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "title": "X" }] });
        assert_eq!(
            release_id_from_json(&release).unwrap().as_ref(),
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        );
        assert!(release_id_from_json(&json!({ "releases": [] })).is_none());
        assert!(release_id_from_json(&json!({})).is_none());
        assert!(release_id_from_json(&json!({ "releases": [{ "id": "bogus" }] })).is_none());

        let artist = json!({ "artists": [{ "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" }] });
        assert!(artist_id_from_json(&artist).is_some());
        assert!(artist_id_from_json(&json!({ "artists": [] })).is_none());

        let recording = json!({ "recordings": [{ "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee" }] });
        assert!(recording_id_from_json(&recording).is_some());
        assert!(recording_id_from_json(&json!({ "recordings": [] })).is_none());
    }

    #[test]
    fn qid_and_p18_parsers() {
        let rels = json!({
            "relations": [
                { "type": "allmusic", "url": { "resource": "https://www.allmusic.com/artist/x" } },
                { "type": "wikidata", "url": { "resource": "https://www.wikidata.org/wiki/Q130798" } },
            ]
        });
        assert_eq!(wikidata_qid_from_json(&rels).unwrap().as_ref(), "Q130798");
        assert!(wikidata_qid_from_json(&json!({ "relations": [] })).is_none());
        assert!(wikidata_qid_from_json(
            &json!({ "relations": [{ "type": "allmusic", "url": { "resource": "https://x" } }] })
        )
        .is_none());

        let claims = json!({
            "claims": {
                "P18": [{
                    "mainsnak": { "datavalue": { "value": "Mac Miller 2017.jpg" } }
                }]
            }
        });
        assert_eq!(
            p18_filename_from_json(&claims).unwrap().as_ref(),
            "Mac Miller 2017.jpg"
        );
        assert!(p18_filename_from_json(&json!({ "claims": {} })).is_none());
        assert!(p18_filename_from_json(&json!({ "claims": { "P18": [] } })).is_none());
    }

    // -------------------------------------------- endpoint round-trips

    fn album_query(mbid: Option<MusicBrainzId>) -> Query {
        Query::Album {
            album: AlbumRef {
                artist: ArtistKey::from("a"),
                album: AlbumKey::from("b"),
            },
            artist_display: "New World Sound".into(),
            album_display: "Flute".into(),
            mbid,
            provided: false,
        }
    }

    #[test]
    fn roundtrip_album_entity_fills_cover_and_url() {
        let stub = StubClient::new()
            .route(
                "ws/2/release",
                Response::Json(json!({"releases": [{
                    "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                    "title": "Flute"
                }]})),
            )
            .route("front-500", Response::Status(200));
        let req_log = stub.request_log();
        let sources = MusicSources::for_tests(Box::new(stub));
        let plan = ResolvePlan {
            resolved: vec![],
            queries: vec![album_query(None)],
        };
        let results = sources.run_queries(&plan);
        let Outcome::Album { cover, url, mbid } = &results[0].1 else {
            panic!("unexpected outcome: {:?}", results[0].1)
        };
        assert!(mbid.is_some());
        assert!(
            cover
                .as_ref()
                .unwrap()
                .as_ref()
                .contains("/release/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/front-500")
        );
        assert!(
            url.as_ref()
                .unwrap()
                .as_ref()
                .contains("/release/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        );
        // release search, then cover-art probe; the link is built locally.
        let urls = req_log.lock().unwrap();
        assert_eq!(urls.len(), 2);
        assert!(urls[0].contains("ws/2/release"), "{}", urls[0]);
        assert!(urls[1].contains("front-500"), "{}", urls[1]);
    }

    #[test]
    fn roundtrip_cover_art_404_keeps_the_link() {
        let stub = StubClient::new().route("front-500", Response::Status(404));
        let req_log = stub.request_log();
        let sources = MusicSources::for_tests(Box::new(stub));
        let plan = ResolvePlan {
            resolved: vec![],
            queries: vec![album_query(Some(
                MusicBrainzId::from_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee").unwrap(),
            ))],
        };
        let results = sources.run_queries(&plan);
        let Outcome::Album { cover, url, .. } = &results[0].1 else {
            panic!("unexpected outcome: {:?}", results[0].1)
        };
        assert!(cover.is_none());
        assert!(url.is_some());
        // Provided MBID -> single cover-art probe, no search, no retries.
        assert_eq!(req_log.lock().unwrap().len(), 1);
    }

    #[test]
    fn roundtrip_artist_image_chain() {
        let stub = StubClient::new()
            .route(
                "ws/2/artist?",
                Response::Json(json!({"artists": [{
                    "id": "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
                }]})),
            )
            .route(
                "inc=url-rels",
                Response::Json(json!({"relations": [{
                    "type": "wikidata",
                    "url": { "resource": "https://www.wikidata.org/wiki/Q130798" }
                }]})),
            )
            .route(
                "w/api.php",
                Response::Json(json!({"claims": {"P18": [{
                    "mainsnak": { "datavalue": { "value": "Mac Miller 2017.jpg" } }
                }]}})),
            );
        let req_log = stub.request_log();
        let sources = MusicSources::for_tests(Box::new(stub));
        let plan = ResolvePlan {
            resolved: vec![],
            queries: vec![Query::Artist {
                artist: ArtistKey::from("a"),
                artist_display: "Mac Miller".into(),
                mbid: None,
            }],
        };
        let results = sources.run_queries(&plan);
        let Outcome::Artist { image, url, .. } = &results[0].1 else {
            panic!("unexpected outcome: {:?}", results[0].1)
        };
        assert!(
            image
                .as_ref()
                .unwrap()
                .as_ref()
                .contains("Special:FilePath/Mac%20Miller%202017.jpg?width=600")
        );
        assert!(
            url.as_ref()
                .unwrap()
                .as_ref()
                .contains("/artist/bbbbbbbb-cccc-dddd-eeee-ffffffffffff")
        );
        // artist search, url-rels lookup, wikidata claims
        assert_eq!(req_log.lock().unwrap().len(), 3);
    }

    #[test]
    fn roundtrip_provided_mbids_skip_searches() {
        let stub = StubClient::new();
        let req_log = stub.request_log();
        let sources = MusicSources::for_tests(Box::new(stub));
        let track_mbid = MusicBrainzId::from_str("cccccccc-dddd-eeee-ffff-000000000000").unwrap();
        let artist_mbid = MusicBrainzId::from_str("dddddddd-eeee-ffff-0000-111111111111").unwrap();
        let plan = ResolvePlan {
            resolved: vec![],
            queries: vec![
                Query::Track {
                    track: TrackRef {
                        artist: ArtistKey::from("a"),
                        track: TrackKey::from("t"),
                    },
                    artist_display: "New World Sound".into(),
                    track_display: "Flute".into(),
                    mbid: Some(track_mbid),
                },
                Query::Artist {
                    artist: ArtistKey::from("a"),
                    artist_display: "New World Sound".into(),
                    mbid: Some(artist_mbid),
                },
            ],
        };
        let results = sources.run_queries(&plan);
        let Outcome::Track { url, .. } = &results[0].1 else {
            panic!("unexpected outcome: {:?}", results[0].1)
        };
        assert!(
            url.as_ref()
                .unwrap()
                .as_ref()
                .contains("/recording/cccccccc-dddd-eeee-ffff-000000000000")
        );
        let Outcome::Artist { url, .. } = &results[1].1 else {
            panic!("unexpected outcome: {:?}", results[1].1)
        };
        assert!(
            url.as_ref()
                .unwrap()
                .as_ref()
                .contains("/artist/dddddddd-eeee-ffff-0000-111111111111")
        );
        // An artist image lookup still runs (url-rels + wikidata), but
        // the stub 404s both; no name search is issued.
        let urls = req_log.lock().unwrap();
        assert!(
            urls.iter().all(|url| !url.contains("ws/2/artist?")),
            "{urls:?}"
        );
    }
}
