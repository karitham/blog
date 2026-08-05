//// Pure retry classification for the HTTP transport.
////
//// `transport.gleam` performs the actual requests and sleeps between
//// retries; this module decides whether a result is worth retrying so
//// the decision tree is unit-testable without a network.

/// Retryable vs permanent failure. Transport errors and 429/5xx are
/// transient; 4xx and invalid URLs are permanent.
pub type HttpError {
  Transient(String)
  Permanent(String)
}

/// What the retry loop should do after one attempt.
pub type Outcome(a) {
  Succeeded(a)
  GivenUp(String)
  Retry(String)
}

/// Classify a non-2xx HTTP status into transient/permanent. 429 and
/// 5xx are rate-limited/server failures worth retrying; everything
/// else (404, 400, ...) is permanent.
pub fn classify_status(status: Int, reason: String) -> Result(a, HttpError) {
  case status == 429 || status >= 500 {
    True -> Error(Transient(reason))
    False -> Error(Permanent(reason))
  }
}

/// Given one attempt's result and the number of attempts remaining
/// (including this one), decide what the retry loop should do.
pub fn decide(
  result: Result(a, HttpError),
  attempts_remaining: Int,
) -> Outcome(a) {
  case result {
    Ok(value) -> Succeeded(value)
    Error(Permanent(reason)) -> GivenUp(reason)
    Error(Transient(reason)) ->
      case attempts_remaining <= 1 {
        True -> GivenUp(reason)
        False -> Retry(reason)
      }
  }
}
