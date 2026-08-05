//! Shared HTTP boundary: the single owner of "how we talk to the
//! network" — agent construction, retry policy, user agent, rate
//! limiting, and retryable-status classification.
//!
//! Every endpoint we touch (MusicBrainz, Cover Art Archive, Wikidata,
//! Wikimedia Commons) is rate-limited and occasionally flakes. Retrying
//! with jittered exponential backoff keeps us polite while tolerating
//! transient failures: the same error that used to permanently drop a
//! link from this build is now retried, and the jitter stops a herd of
//! parallel workers from hammering the endpoint at identical instants.

use std::sync::Mutex;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

pub const USER_AGENT: &str = "karitham-blog/0.1.0 (https://karitham.dev)";

/// 3 attempts / 4s max: transient storms cost at most ~1.5s of backoff
/// before we give up and (thanks to negative caching) don't repeat.
pub const RETRY_POLICY: RetryPolicy = RetryPolicy {
    max_attempts: 3,
    base_delay: Duration::from_millis(500),
    max_delay: Duration::from_secs(4),
};

/// How hard to try, and how long to wait between attempts.
#[derive(Clone, Copy)]
pub struct RetryPolicy {
    pub max_attempts: u32,
    pub base_delay: Duration,
    pub max_delay: Duration,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self {
            max_attempts: 5,
            base_delay: Duration::from_millis(500),
            max_delay: Duration::from_secs(8),
        }
    }
}

/// One outcome of a single attempt.
pub enum Attempt<T> {
    /// Got a usable answer.
    Done(T),
    /// Permanent failure — retrying cannot help (4xx, missing data).
    Stop,
    /// Transient failure; `Some(n)` = server's `Retry-After` seconds.
    Again(Option<u64>),
}

/// Run `attempt` up to `policy.max_attempts` times with jittered
/// exponential backoff. `Stop` aborts immediately; `Again(None)` waits
/// the backoff, `Again(Some(n))` honors the server's `Retry-After`
/// (capped at `max_delay`). Returns `None` when attempts are exhausted.
pub fn retry<T>(policy: &RetryPolicy, mut attempt: impl FnMut() -> Attempt<T>) -> Option<T> {
    let mut delay = policy.base_delay;
    for i in 0..policy.max_attempts {
        match attempt() {
            Attempt::Done(value) => return Some(value),
            Attempt::Stop => return None,
            Attempt::Again(retry_after) => {
                if i + 1 == policy.max_attempts {
                    return None;
                }
                let wait = retry_after
                    .map(Duration::from_secs)
                    .unwrap_or(delay)
                    .min(policy.max_delay);
                std::thread::sleep(wait + jitter(wait));
            }
        }
        delay = (delay * 2).min(policy.max_delay);
    }
    None
}

/// Add 0–25% of `base` as jitter so parallel workers don't retry in
/// lockstep. Seeded from the clock; good enough to decorrelate ~dozens
/// of retries without pulling in a RNG dependency.
fn jitter(base: Duration) -> Duration {
    let ms = base.as_millis() as u64;
    let salt = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.subsec_nanos() as u64)
        .unwrap_or(0);
    Duration::from_millis(ms + salt % (ms / 4 + 1))
}

/// `Retry-After` header value as seconds, when it is a plain integer.
pub fn retry_after(resp: &ureq::Response) -> Option<u64> {
    resp.header("retry-after")
        .and_then(|v| v.trim().parse().ok())
}

/// HTTP status codes worth retrying: rate limiting and server errors.
pub fn is_retryable(code: u16) -> bool {
    code == 429 || code == 500 || code == 503
}

/// Global rate limiter shared by workers: at most `rate_per_sec`
/// acquisitions per second across all threads.
pub struct Limiter {
    min_interval: Duration,
    last: Mutex<Instant>,
}

impl Limiter {
    pub fn new(rate_per_sec: f64) -> Self {
        Self {
            min_interval: Duration::from_secs_f64(1.0 / rate_per_sec),
            last: Mutex::new(Instant::now()),
        }
    }

    pub fn acquire(&self) {
        let mut last = self.last.lock().unwrap();
        let since = Instant::now().duration_since(*last);
        if since < self.min_interval {
            std::thread::sleep(self.min_interval - since);
        }
        *last = Instant::now();
    }
}

/// One agent, one policy, one user agent — the covers/images copies
/// collapse here. Methods own their retry/backoff internally.
pub struct HttpClient {
    agent: ureq::Agent,
    policy: RetryPolicy,
}

impl HttpClient {
    pub fn new() -> Self {
        Self {
            agent: ureq::AgentBuilder::new()
                .user_agent(USER_AGENT)
                .timeout(Duration::from_secs(15))
                .build(),
            policy: RETRY_POLICY,
        }
    }

    /// GET a JSON API with query params. A 200 that fails to parse is a
    /// permanent miss — the endpoint answered, the shape just isn't
    /// what we expected.
    pub fn get_json(&self, url: &str, params: &[(&str, &str)]) -> Option<serde_json::Value> {
        retry(&self.policy, || {
            let mut req = self.agent.get(url);
            for (key, value) in params {
                req = req.query(key, value);
            }
            match req.call() {
                Ok(resp) if resp.status() == 200 => match resp.into_string() {
                    Ok(body) => match serde_json::from_str(&body) {
                        Ok(value) => Attempt::Done(value),
                        Err(_) => Attempt::Stop,
                    },
                    Err(_) => Attempt::Stop,
                },
                Ok(_) => Attempt::Stop,
                Err(ureq::Error::Status(code, resp)) if is_retryable(code) => {
                    Attempt::Again(retry_after(&resp))
                }
                // Non-retryable status (404, 400...) is a permanent
                // miss — ureq surfaces it as `Error::Status`, and
                // retrying it just burns backoff.
                Err(ureq::Error::Status(_, _)) => Attempt::Stop,
                // Transport-level failures (timeouts, resets, DNS) are
                // transient — retry rather than dropping the link for
                // this whole build.
                Err(_) => Attempt::Again(None),
            }
        })
    }

    /// GET a body, capped at `max` bytes, returning (content-type,
    /// body). Callers check the length — an oversized response must
    /// not become a cached artifact.
    pub fn get_bytes(&self, url: &str, max: usize) -> Option<(String, Vec<u8>)> {
        retry(&self.policy, || match self.agent.get(url).call() {
            Ok(resp) if resp.status() == 200 => {
                let ct = resp
                    .header("content-type")
                    .map(str::to_string)
                    .unwrap_or_default();
                use std::io::Read;
                let mut buf = Vec::new();
                match resp
                    .into_reader()
                    .take(max as u64 + 1)
                    .read_to_end(&mut buf)
                {
                    Ok(_) => Attempt::Done((ct, buf)),
                    Err(_) => Attempt::Stop,
                }
            }
            Ok(_) => Attempt::Stop,
            Err(ureq::Error::Status(code, resp)) if is_retryable(code) => {
                Attempt::Again(retry_after(&resp))
            }
            // Non-retryable status (404, 400...) is a permanent miss.
            Err(ureq::Error::Status(_, _)) => Attempt::Stop,
            Err(_) => Attempt::Again(None),
        })
    }

    /// Probe a URL for a 200 (e.g. Cover Art Archive's front-500
    /// endpoint). A non-2xx response (404 — no art) is a permanent
    /// miss, not worth retrying.
    pub fn check(&self, url: &str) -> bool {
        retry(&self.policy, || match self.agent.get(url).call() {
            Ok(resp) if resp.status() == 200 => Attempt::Done(true),
            Ok(_) => Attempt::Stop,
            Err(ureq::Error::Status(code, resp)) if is_retryable(code) => {
                Attempt::Again(retry_after(&resp))
            }
            Err(ureq::Error::Status(_, _)) => Attempt::Stop,
            Err(_) => Attempt::Again(None),
        })
        .unwrap_or(false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn retries_transient_then_succeeds() {
        let mut calls = 0;
        let out = retry(&RetryPolicy::default(), || {
            calls += 1;
            match calls {
                1..=3 => Attempt::Again(None),
                _ => Attempt::Done("ok"),
            }
        });
        assert_eq!(out, Some("ok"));
        assert_eq!(calls, 4);
    }

    #[test]
    fn stops_on_permanent_failure() {
        let mut calls = 0;
        let out: Option<u8> = retry(&RetryPolicy::default(), || {
            calls += 1;
            Attempt::Stop
        });
        assert_eq!(out, None);
        assert_eq!(calls, 1);
    }

    #[test]
    fn gives_up_after_max_attempts() {
        let policy = RetryPolicy {
            max_attempts: 3,
            ..RetryPolicy::default()
        };
        let mut calls = 0;
        let out: Option<u8> = retry(&policy, || {
            calls += 1;
            Attempt::Again(None)
        });
        assert_eq!(out, None);
        assert_eq!(calls, 3);
    }

    #[test]
    fn honors_retry_after() {
        let mut calls = 0;
        let out: Option<i32> = retry(&RetryPolicy::default(), || {
            calls += 1;
            match calls {
                1 => Attempt::Again(Some(1)),
                _ => Attempt::Done(7),
            }
        });
        assert_eq!(out, Some(7));
        assert_eq!(calls, 2);
    }

    #[test]
    fn jitter_is_bounded() {
        for _ in 0..100 {
            let j = jitter(Duration::from_millis(1000));
            assert!(j >= Duration::from_millis(1000));
            assert!(j < Duration::from_millis(1500));
        }
    }

    #[test]
    fn retryable_status_classification() {
        assert!(is_retryable(429));
        assert!(is_retryable(500));
        assert!(is_retryable(503));
        assert!(!is_retryable(404));
        assert!(!is_retryable(200));
    }
}
