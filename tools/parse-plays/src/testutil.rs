//! Canned HTTP boundary for tests. No sockets, no threads: responses
//! are keyed by URL substring, and every request is recorded for
//! assertions. `ureq` is assumed correct — what we test is our logic
//! around it, not the wire.

use crate::net::HttpFetch;
use serde_json::Value;
use std::sync::{Arc, Mutex};

/// What a matched route serves.
pub enum Response {
    /// 200 with a JSON body (for `get_json`).
    Json(Value),
    /// 200 with raw bytes and a content type (for `get_bytes`).
    Bytes(&'static [u8], &'static str),
    /// A non-200 status: a permanent miss for `check`/`get_json`.
    Status(u16),
}

/// A fake `HttpFetch`: the first route whose needle matches the URL
/// wins; no match is a transport failure (`None`/`false`). Routing on
/// the URL — not arrival order — keeps parallel-query tests
/// deterministic.
pub struct StubClient {
    routes: Vec<(String, Response)>,
    requests: Arc<Mutex<Vec<String>>>,
}

impl StubClient {
    pub fn new() -> Self {
        Self {
            routes: Vec::new(),
            requests: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn route(mut self, needle: &str, response: Response) -> Self {
        self.routes.push((needle.to_string(), response));
        self
    }

    /// Requests made so far, in order.
    pub fn requests(&self) -> Vec<String> {
        self.requests.lock().unwrap().clone()
    }

    /// A handle on the request log, for tests that hand the client to
    /// `MusicSources::for_tests` and inspect it afterwards.
    pub fn request_log(&self) -> Arc<Mutex<Vec<String>>> {
        self.requests.clone()
    }

    fn record(&self, url: &str) {
        self.requests.lock().unwrap().push(url.to_string());
    }

    /// Match/record the URL the real client would send: `url` plus the
    /// query params (ureq appends them itself).
    fn full_url(url: &str, params: &[(&str, &str)]) -> String {
        if params.is_empty() {
            url.to_string()
        } else {
            let query: Vec<String> = params
                .iter()
                .map(|(key, value)| format!("{key}={value}"))
                .collect();
            format!("{url}?{}", query.join("&"))
        }
    }

    fn route_for(&self, url: &str) -> Option<&Response> {
        self.routes
            .iter()
            .find(|(needle, _)| url.contains(needle))
            .map(|(_, response)| response)
    }
}

impl HttpFetch for StubClient {
    fn get_json(&self, url: &str, params: &[(&str, &str)]) -> Option<Value> {
        let url = Self::full_url(url, params);
        self.record(&url);
        match self.route_for(&url) {
            Some(Response::Json(value)) => Some(value.clone()),
            _ => None,
        }
    }

    fn get_bytes(&self, url: &str, _max: usize) -> Option<(String, Vec<u8>)> {
        self.record(url);
        match self.route_for(url) {
            Some(Response::Bytes(body, content_type)) => {
                Some(((*content_type).to_string(), body.to_vec()))
            }
            _ => None,
        }
    }

    fn check(&self, url: &str) -> bool {
        self.record(url);
        matches!(
            self.route_for(url),
            Some(Response::Status(200))
                | Some(Response::Json(_))
                | Some(Response::Bytes(_, _))
        )
    }
}
