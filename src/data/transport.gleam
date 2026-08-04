//// HTTP body fetcher for the SSG (Erlang target).
////
//// `fetch_body` does a GET and returns the response body as a string;
//// `fetch_image` does a GET and returns raw bytes plus the response's
//// Content-Type (for picking a file extension). Status and error
//// handling stay here so the shared decoders in `shared/src/fetch.gleam`
//// can stay pure.
////
//// Both retry transient failures (network errors, 429/5xx) a few times
//// with a short fixed delay, so a blip from the PDS or a CDN doesn't
//// blank out a section for this build.

import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/result
import gleam/string

@external(erlang, "transport_ffi", "sleep")
fn sleep(ms: Int) -> Nil

/// Retryable vs permanent failure. Transport errors and 429/5xx are
/// transient; 4xx and invalid URLs are permanent.
type HttpError {
  Transient(String)
  Permanent(String)
}

const max_attempts = 3

const retry_delay_ms = 500

/// GET `url` and return the response body. Returns an error string on
/// network failure, non-2xx status, or invalid URL — the SSG logs
/// these and continues with an empty value where appropriate.
pub fn fetch_body(url: String) -> Result(String, String) {
  retry(fn() { fetch_body_once(url) })
}

/// GET `url` and return the raw bytes and Content-Type header. Used to
/// mirror remote images (avatar/banner blobs) into the built site so
/// the visitor's browser never hits the PDS for them.
pub fn fetch_image(url: String) -> Result(#(BitArray, String), String) {
  retry(fn() { fetch_image_once(url) })
}

fn retry(f: fn() -> Result(a, HttpError)) -> Result(a, String) {
  retry_from(f, max_attempts)
}

fn retry_from(
  f: fn() -> Result(a, HttpError),
  attempts: Int,
) -> Result(a, String) {
  case f() {
    Ok(value) -> Ok(value)
    Error(Permanent(reason)) -> Error(reason)
    Error(Transient(reason)) ->
      case attempts <= 1 {
        True -> Error(reason)
        False -> {
          sleep(retry_delay_ms)
          retry_from(f, attempts - 1)
        }
      }
  }
}

fn fetch_body_once(url: String) -> Result(String, HttpError) {
  use req <- result.try(
    request.to(url)
    |> result.replace_error("invalid url: " <> url)
    |> result.map_error(fn(e) { Permanent(e) }),
  )
  use resp <- result.try(
    httpc.send(req) |> result.map_error(fn(e) { Transient(string.inspect(e)) }),
  )
  case resp.status >= 200 && resp.status < 300 {
    True -> Ok(resp.body)
    False -> {
      let reason = "HTTP " <> int.to_string(resp.status) <> ": " <> resp.body
      classify_status(resp.status, reason)
    }
  }
}

fn fetch_image_once(url: String) -> Result(#(BitArray, String), HttpError) {
  use req <- result.try(
    request.to(url)
    |> result.map(fn(req) { request.set_body(req, <<>>) })
    |> result.replace_error("invalid url: " <> url)
    |> result.map_error(fn(e) { Permanent(e) }),
  )
  use resp <- result.try(
    httpc.send_bits(req)
    |> result.map_error(fn(e) { Transient(string.inspect(e)) }),
  )
  case resp.status >= 200 && resp.status < 300 {
    False -> classify_status(resp.status, "HTTP " <> int.to_string(resp.status))
    True -> {
      let content_type = response.get_header(resp, "content-type")
      Ok(#(resp.body, result.unwrap(content_type, "")))
    }
  }
}

fn classify_status(status: Int, reason: String) -> Result(a, HttpError) {
  case status == 429 || status >= 500 {
    True -> Error(Transient(reason))
    False -> Error(Permanent(reason))
  }
}
