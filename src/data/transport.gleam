//// HTTP body fetcher for the SSG (Erlang target).
////
//// `fetch_body` does a GET and returns the response body as a string.
//// Status and error handling stay here so the shared decoders in
//// `shared/src/atproto.gleam` can stay pure.
////
//// Both retry transient failures (network errors, 429/5xx) a few times
//// with a short fixed delay, so a blip from the PDS or a CDN doesn't
//// blank out a section for this build. The retry decision tree is pure
//// and lives in `data/transport/core`; this module owns the httpc
//// calls and the sleep.

import data/transport/core.{type HttpError}
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/result
import gleam/string

@external(erlang, "transport_ffi", "sleep")
fn sleep(ms: Int) -> Nil

const max_attempts = 3

const retry_delay_ms = 500

/// GET `url` and return the response body. Returns an error string on
/// network failure, non-2xx status, or invalid URL — the SSG logs
/// these and continues with an empty value where appropriate.
pub fn fetch_body(url: String) -> Result(String, String) {
  retry(fn() { fetch_body_once(url) })
}

fn retry(f: fn() -> Result(a, HttpError)) -> Result(a, String) {
  retry_from(f, max_attempts)
}

fn retry_from(
  f: fn() -> Result(a, HttpError),
  attempts: Int,
) -> Result(a, String) {
  case core.decide(f(), attempts) {
    core.Succeeded(value) -> Ok(value)
    core.GivenUp(reason) -> Error(reason)
    core.Retry(_) -> {
      sleep(retry_delay_ms)
      retry_from(f, attempts - 1)
    }
  }
}

fn fetch_body_once(url: String) -> Result(String, HttpError) {
  let req_result =
    request.to(url)
    |> result.replace_error("invalid url: " <> url)
    |> result.map_error(fn(e) { core.Permanent(e) })
  use req <- result.try(req_result)
  let resp_result =
    httpc.send(req)
    |> result.map_error(fn(e) { core.Transient(string.inspect(e)) })
  use resp <- result.try(resp_result)
  case resp.status >= 200 && resp.status < 300 {
    True -> Ok(resp.body)
    False -> {
      let reason = "HTTP " <> int.to_string(resp.status) <> ": " <> resp.body
      core.classify_status(resp.status, reason)
    }
  }
}
