//! Shared retry/backoff for external HTTP lookups.
//!
//! Every endpoint we touch (MusicBrainz, Cover Art Archive, Wikidata,
//! Wikimedia Commons) is rate-limited and occasionally flakes. Retrying
//! with jittered exponential backoff keeps us polite while tolerating
//! transient failures: the same error that used to permanently drop a
//! link from this build is now retried, and the jitter stops a herd of
//! parallel workers from hammering the endpoint at identical instants.

use std::time::{Duration, SystemTime, UNIX_EPOCH};

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
}
