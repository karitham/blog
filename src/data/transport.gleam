//// HTTP body fetcher for the SSG (Erlang target).
////
//// `fetch_body` does a GET and returns the response body as a string.
//// Status and error handling stay here so the shared decoders in
//// `shared/src/fetch.gleam` can stay pure.

import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/result
import gleam/string

/// GET `url` and return the response body. Returns an error string on
/// network failure, non-2xx status, or invalid URL — the SSG logs
/// these and continues with an empty value where appropriate.
pub fn fetch_body(url: String) -> Result(String, String) {
  use req <- result.try(
    request.to(url)
    |> result.replace_error("invalid url: " <> url),
  )
  use resp <- result.try(httpc.send(req) |> result.map_error(string.inspect))
  case resp.status >= 200 && resp.status < 300 {
    True -> Ok(resp.body)
    False -> Error("HTTP " <> int.to_string(resp.status) <> ": " <> resp.body)
  }
}
