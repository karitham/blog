//// XRPC transport for the SSG (Erlang target).
////
//// Creates an `atproto/xrpc.Client` backed by `gleam_httpc` for use
//// with the generated typed client in `gen/client.gleam`.

import atproto/xrpc
import gleam/bit_array
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response, Response}
import gleam/httpc

import gleam/result
import gleam/string

pub fn http_client() -> xrpc.Client {
  xrpc.Client(send: send)
}

fn body_to_string(bits: BitArray) -> String {
  case bit_array.to_string(bits) {
    Ok(s) -> s
    Error(_) -> ""
  }
}

fn send(req: Request(BitArray)) -> Result(Response(BitArray), String) {
  let text_req =
    Request(
      method: req.method,
      headers: req.headers,
      body: body_to_string(req.body),
      scheme: req.scheme,
      host: req.host,
      port: req.port,
      path: req.path,
      query: req.query,
    )
  use resp <- result.try(
    httpc.send(text_req) |> result.map_error(string.inspect),
  )
  Ok(Response(
    status: resp.status,
    headers: resp.headers,
    body: bit_array.from_string(resp.body),
  ))
}
