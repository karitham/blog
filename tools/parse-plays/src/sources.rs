//! Impure gather: MusicBrainz / Cover Art Archive / Wikidata / Commons
//! queries. One deep module owning the endpoint URLs, rate limits, and
//! JSON-shape parsing — the rest of the pipeline never knows a hostname.
//!
//! The JSON→typed parsers are pure and tested with fixtures; the
//! endpoint round-trips are tested against a localhost stub server.

use crate::model::{CommonsFilename, Href, MusicBrainzId, WikidataId};
use crate::net::{HttpClient, Limiter};
use crate::resolve::{Query, ResolvePlan};
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
}

impl RateLimits {
    pub fn production() -> Self {
        Self {
            musicbrainz: Limiter::new(1.0),
            coverart: Limiter::new(1.0),
            wikidata: Limiter::new(1.0),
            commons: Limiter::new(4.0),
            coverart_img: Limiter::new(1.0),
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
        }
    }
}

/// The impure gather boundary. Owns no cache — returns raw outcomes.
pub struct MusicSources {
    pub(crate) client: HttpClient,
    pub(crate) limits: RateLimits,
    bases: EndpointBases,
}

impl MusicSources {
    pub fn new() -> Self {
        Self {
            client: HttpClient::new(),
            limits: RateLimits::production(),
            bases: EndpointBases::production(),
        }
    }

    /// Tests only: all endpoints against one localhost stub, no rate
    /// limiting.
    #[cfg(test)]
    pub fn for_tests(port: u16) -> Self {
        Self {
            client: HttpClient::new(),
            limits: RateLimits::unthrottled(),
            bases: EndpointBases::localhost(port),
        }
    }

    /// Run every query in the plan (parallel, per-endpoint limiters),
    /// returning per-query outcomes.
    pub fn run_queries(&self, plan: &ResolvePlan) -> Vec<(Query, Option<Href>)> {
        plan.queries
            .par_iter()
            .map(|query| {
                let outcome = match query {
                    Query::AlbumCover {
                        artist_display,
                        album_display,
                        mbid,
                        ..
                    } => {
                        let mbid = match mbid {
                            Some(mbid) => Some(mbid.clone()),
                            None => self.release_id(artist_display, album_display),
                        };
                        mbid.and_then(|mbid| self.cover_art_url(&mbid))
                    }
                    Query::AlbumUrl {
                        artist_display,
                        album_display,
                        mbid,
                        ..
                    } => {
                        let mbid = match mbid {
                            Some(mbid) => Some(mbid.clone()),
                            None => self.release_id(artist_display, album_display),
                        };
                        mbid.and_then(|mbid| {
                            Href::from_str(&format!(
                                "{}/release/{}",
                                self.bases.musicbrainz,
                                mbid.as_ref()
                            ))
                            .ok()
                        })
                    }
                    Query::ArtistImage { artist_display, .. } => self.artist_image(artist_display),
                    Query::ArtistUrl { artist_display, .. } => {
                        self.artist_id(artist_display).and_then(|mbid| {
                            Href::from_str(&format!(
                                "{}/artist/{}",
                                self.bases.musicbrainz,
                                mbid.as_ref()
                            ))
                            .ok()
                        })
                    }
                    Query::TrackUrl {
                        artist_display,
                        track_display,
                        ..
                    } => self
                        .recording_id(artist_display, track_display)
                        .and_then(|mbid| {
                            Href::from_str(&format!(
                                "{}/recording/{}",
                                self.bases.musicbrainz,
                                mbid.as_ref()
                            ))
                            .ok()
                        }),
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

    fn artist_id(&self, name: &str) -> Option<MusicBrainzId> {
        self.limits.musicbrainz.acquire();
        let query = format!("artist:\"{}\"", clean_query(name));
        let body = self.client.get_json(
            &format!("{}/ws/2/artist", self.bases.musicbrainz),
            &[("query", &query), ("fmt", "json"), ("limit", "1")],
        )?;
        artist_id_from_json(&body)
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

    /// Commons image URL for a filename, resized to 600px.
    fn commons_url(&self, filename: &CommonsFilename) -> Option<Href> {
        self.limits.commons.acquire();
        Href::from_str(&format!(
            "{}/wiki/Special:FilePath/{}?width=600",
            self.bases.commons,
            percent_encode(filename.as_ref())
        ))
        .ok()
    }

    /// Artist photo via the Wikidata chain: MB artist search →
    /// url-rels → P18 → Commons URL.
    fn artist_image(&self, artist_display: &str) -> Option<Href> {
        let mbid = self.artist_id(artist_display)?;
        let qid = self.wikidata_qid(&mbid)?;
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
    use serde_json::json;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    // -------------------------------------------- pure parsers

    #[test]
    fn parsers_extract_ids_from_json() {
        let release =
            json!({ "releases": [{ "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", "title": "X" }] });
        assert_eq!(
            release_id_from_json(&release).unwrap().as_ref(),
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        );
        // Empty result → None, not a panic.
        assert!(release_id_from_json(&json!({ "releases": [] })).is_none());
        assert!(release_id_from_json(&json!({})).is_none());
        // Invalid ID shape → None.
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

    // -------------------------------------------- stub server

    /// Serve canned responses, recording request lines. One request
    /// per test keeps ordering trivially correct; a sequence reuses
    /// the last response when exhausted. The thread owns a cloned
    /// listener; the struct keeps the original so the port stays bound
    /// for the test's lifetime.
    struct Stub {
        _listener: TcpListener,
        requests: Arc<AtomicUsize>,
    }

    impl Stub {
        fn serve(response: Vec<u8>) -> (Self, u16) {
            Self::serve_sequence(vec![response])
        }

        fn serve_sequence(responses: Vec<Vec<u8>>) -> (Self, u16) {
            let listener = TcpListener::bind("127.0.0.1:0").unwrap();
            let port = listener.local_addr().unwrap().port();
            let thread_listener = listener.try_clone().unwrap();
            let requests = Arc::new(AtomicUsize::new(0));
            let reqs = requests.clone();
            std::thread::spawn(move || {
                for i in 0..16 {
                    let Ok((mut stream, _)) = thread_listener.accept() else {
                        return;
                    };
                    reqs.fetch_add(1, Ordering::SeqCst);
                    let mut buf = [0u8; 4096];
                    let _ = stream.read(&mut buf);
                    let response = &responses[i.min(responses.len() - 1)];
                    let _ = stream.write_all(response);
                }
            });
            (
                Stub {
                    _listener: listener,
                    requests,
                },
                port,
            )
        }

        fn count(&self) -> usize {
            self.requests.load(Ordering::SeqCst)
        }
    }

    fn http_response(status: &str, content_type: &str, body: &'static [u8]) -> Vec<u8> {
        let mut resp = format!(
            "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            body.len()
        )
        .into_bytes();
        resp.extend_from_slice(body);
        resp
    }

    const OK_JSON: &[u8] =
        br#"{"releases":[{"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","title":"Flute"}]}"#;

    #[test]
    fn roundtrip_release_search_and_cover_art() {
        let (stub, port) = Stub::serve(http_response("200 OK", "application/json", OK_JSON));
        let sources = MusicSources::for_tests(port);
        let plan = ResolvePlan {
            resolved: vec![],
            queries: vec![Query::AlbumCover {
                album: AlbumRef {
                    artist: ArtistKey::from("a"),
                    album: AlbumKey::from("b"),
                },
                artist_display: "New World Sound".into(),
                album_display: "Flute".into(),
                mbid: None,
                provided: false,
            }],
        };
        let results = sources.run_queries(&plan);
        assert_eq!(stub.count(), 2); // release search + cover art probe
        let url = results[0].1.as_ref().unwrap().as_ref();
        assert!(
            url.contains("/release/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/front-500"),
            "{url}"
        );
    }

    #[test]
    fn roundtrip_cover_art_404_is_permanent_miss() {
        let (stub, port) = Stub::serve(http_response("404 Not Found", "text/plain", b"nope"));
        let sources = MusicSources::for_tests(port);
        let plan = ResolvePlan {
            resolved: vec![],
            queries: vec![Query::AlbumCover {
                album: AlbumRef {
                    artist: ArtistKey::from("a"),
                    album: AlbumKey::from("b"),
                },
                artist_display: "New World Sound".into(),
                album_display: "Flute".into(),
                mbid: Some(
                    MusicBrainzId::from_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee").unwrap(),
                ),
                provided: true,
            }],
        };
        let results = sources.run_queries(&plan);
        // Provided MBID → single cover-art probe, no search, no retries.
        assert_eq!(stub.count(), 1);
        assert!(results[0].1.is_none());
    }

    #[test]
    fn roundtrip_artist_image_chain() {
        let artist_json = br#"{"artists":[{"id":"bbbbbbbb-cccc-dddd-eeee-ffffffffffff"}]}"#;
        let rels_json = br#"{"relations":[{"type":"wikidata","url":{"resource":"https://www.wikidata.org/wiki/Q130798"}}]}"#;
        let claims_json =
            br#"{"claims":{"P18":[{"mainsnak":{"datavalue":{"value":"Mac Miller 2017.jpg"}}}]}}"#;
        let (stub, port) = Stub::serve_sequence(vec![
            http_response("200 OK", "application/json", artist_json),
            http_response("200 OK", "application/json", rels_json),
            http_response("200 OK", "application/json", claims_json),
        ]);
        let sources = MusicSources::for_tests(port);
        let plan = ResolvePlan {
            resolved: vec![],
            queries: vec![Query::ArtistImage {
                artist: ArtistKey::from("a"),
                artist_display: "Mac Miller".into(),
            }],
        };
        let results = sources.run_queries(&plan);
        assert_eq!(stub.count(), 3);
        let url = results[0].1.as_ref().unwrap().as_ref();
        assert!(
            url.contains("Special:FilePath/Mac%20Miller%202017.jpg?width=600"),
            "{url}"
        );
    }

    #[test]
    fn roundtrip_recording_and_artist_urls() {
        let recording_json = br#"{"recordings":[{"id":"cccccccc-dddd-eeee-ffff-000000000000"}]}"#;
        let artist_json = br#"{"artists":[{"id":"dddddddd-eeee-ffff-0000-111111111111"}]}"#;
        let (stub, port) = Stub::serve_sequence(vec![
            http_response("200 OK", "application/json", recording_json),
            http_response("200 OK", "application/json", artist_json),
        ]);
        let sources = MusicSources::for_tests(port);
        let plan = ResolvePlan {
            resolved: vec![],
            queries: vec![
                Query::TrackUrl {
                    track: TrackRef {
                        artist: ArtistKey::from("a"),
                        track: TrackKey::from("t"),
                    },
                    artist_display: "New World Sound".into(),
                    track_display: "Flute".into(),
                },
                Query::ArtistUrl {
                    artist: ArtistKey::from("a"),
                    artist_display: "New World Sound".into(),
                },
            ],
        };
        let results = sources.run_queries(&plan);
        assert_eq!(stub.count(), 2);
        assert!(
            results[0]
                .1
                .as_ref()
                .unwrap()
                .as_ref()
                .contains("/recording/cccccccc-dddd-eeee-ffff-000000000000")
        );
        assert!(
            results[1]
                .1
                .as_ref()
                .unwrap()
                .as_ref()
                .contains("/artist/dddddddd-eeee-ffff-0000-111111111111")
        );
    }
}
