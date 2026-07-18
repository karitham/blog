import * as $http from "../../gleam_http/gleam/http.mjs";
import * as $request from "../../gleam_http/gleam/http/request.mjs";
import * as $response from "../../gleam_http/gleam/http/response.mjs";
import * as $json from "../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import { Ok, Error, CustomType as $CustomType } from "../gleam.mjs";

export class Client extends $CustomType {
  constructor(send) {
    super();
    this.send = send;
  }
}
export const Client$Client = (send) => new Client(send);
export const Client$isClient = (value) => value instanceof Client;
export const Client$Client$send = (value) => value.send;
export const Client$Client$0 = (value) => value.send;

export class RequestFailed extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const XrpcError$RequestFailed = ($0) => new RequestFailed($0);
export const XrpcError$isRequestFailed = (value) =>
  value instanceof RequestFailed;
export const XrpcError$RequestFailed$0 = (value) => value[0];

/**
 * A non-2xx response. atproto error bodies are JSON `{error, message}`; both
 * are parsed out (when present) so callers can branch on `error` (e.g.
 * `ExpiredToken`) instead of string-matching the raw body.
 */
export class BadStatus extends $CustomType {
  constructor(status, error, message, body) {
    super();
    this.status = status;
    this.error = error;
    this.message = message;
    this.body = body;
  }
}
export const XrpcError$BadStatus = (status, error, message, body) =>
  new BadStatus(status, error, message, body);
export const XrpcError$isBadStatus = (value) => value instanceof BadStatus;
export const XrpcError$BadStatus$status = (value) => value.status;
export const XrpcError$BadStatus$0 = (value) => value.status;
export const XrpcError$BadStatus$error = (value) => value.error;
export const XrpcError$BadStatus$1 = (value) => value.error;
export const XrpcError$BadStatus$message = (value) => value.message;
export const XrpcError$BadStatus$2 = (value) => value.message;
export const XrpcError$BadStatus$body = (value) => value.body;
export const XrpcError$BadStatus$3 = (value) => value.body;

export class DecodeFailed extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const XrpcError$DecodeFailed = ($0) => new DecodeFailed($0);
export const XrpcError$isDecodeFailed = (value) =>
  value instanceof DecodeFailed;
export const XrpcError$DecodeFailed$0 = (value) => value[0];

/**
 * A one-line human-readable rendering of an error, for CLI and log output.
 */
export function describe(error) {
  if (error instanceof RequestFailed) {
    let e = error[0];
    return "request failed: " + e;
  } else if (error instanceof BadStatus) {
    let status = error.status;
    let code = error.error;
    let message = error.message;
    return (("HTTP " + $string.inspect(status)) + (() => {
      let _pipe = $option.map(code, (c) => { return " " + c; });
      return $option.unwrap(_pipe, "");
    })()) + (() => {
      let _pipe = $option.map(message, (m) => { return ": " + m; });
      return $option.unwrap(_pipe, "");
    })();
  } else {
    let e = error[0];
    return "decode failed: " + e;
  }
}

/**
 * Send a text request and decode the response body as text. The seam between
 * the string-shaped JSON world and the BitArray transport.
 */
export function send_text(client, req) {
  return $result.try$(
    client.send($request.map(req, $bit_array.from_string)),
    (resp) => {
      let $ = $bit_array.to_string(resp.body);
      if ($ instanceof Ok) {
        let body = $[0];
        return new Ok($response.set_body(resp, body));
      } else {
        return new Error("response body is not valid utf-8");
      }
    },
  );
}

function parse_error(body) {
  let decoder = $decode.optional_field(
    "error",
    new None(),
    $decode.optional($decode.string),
    (error) => {
      return $decode.optional_field(
        "message",
        new None(),
        $decode.optional($decode.string),
        (message) => { return $decode.success([error, message]); },
      );
    },
  );
  let _pipe = $json.parse(body, decoder);
  return $result.unwrap(_pipe, [new None(), new None()]);
}

function check_ok(resp) {
  let $ = (resp.status >= 200) && (resp.status < 300);
  if ($) {
    return new Ok(resp);
  } else {
    let $1 = parse_error(resp.body);
    let error = $1[0];
    let message = $1[1];
    return new Error(new BadStatus(resp.status, error, message, resp.body));
  }
}

function with_auth(req, token) {
  if (token instanceof Some) {
    let t = token[0];
    return $request.set_header(req, "authorization", "Bearer " + t);
  } else {
    return req;
  }
}

export function get(client, url, token) {
  return $result.try$(
    (() => {
      let _pipe = $request.to(url);
      return $result.replace_error(_pipe, new RequestFailed("bad url: " + url));
    })(),
    (base) => {
      let _pipe = base;
      let _pipe$1 = with_auth(_pipe, token);
      let _pipe$2 = ((_capture) => { return send_text(client, _capture); })(
        _pipe$1,
      );
      let _pipe$3 = $result.map_error(
        _pipe$2,
        (var0) => { return new RequestFailed(var0); },
      );
      return $result.try$(_pipe$3, check_ok);
    },
  );
}

/**
 * GET returning the raw bytes (e.g. blob or image downloads). The error body
 * on a bad status is decoded leniently for the message.
 */
export function get_bits(client, url, token) {
  return $result.try$(
    (() => {
      let _pipe = $request.to(url);
      return $result.replace_error(_pipe, new RequestFailed("bad url: " + url));
    })(),
    (base) => {
      let _pipe = base;
      let _pipe$1 = with_auth(_pipe, token);
      let _pipe$2 = $request.map(_pipe$1, $bit_array.from_string);
      let _pipe$3 = client.send(_pipe$2);
      let _pipe$4 = $result.map_error(
        _pipe$3,
        (var0) => { return new RequestFailed(var0); },
      );
      return $result.try$(
        _pipe$4,
        (resp) => {
          let $ = (resp.status >= 200) && (resp.status < 300);
          if ($) {
            return new Ok(resp);
          } else {
            let _block;
            let _pipe$5 = $bit_array.to_string(resp.body);
            _block = $result.unwrap(_pipe$5, "<binary body>");
            let body = _block;
            let $1 = parse_error(body);
            let error = $1[0];
            let message = $1[1];
            return new Error(new BadStatus(resp.status, error, message, body));
          }
        },
      );
    },
  );
}

export function post_json(client, url, token, body) {
  return $result.try$(
    (() => {
      let _pipe = $request.to(url);
      return $result.replace_error(_pipe, new RequestFailed("bad url: " + url));
    })(),
    (base) => {
      let _pipe = base;
      let _pipe$1 = $request.set_method(_pipe, new $http.Post());
      let _pipe$2 = $request.set_header(
        _pipe$1,
        "content-type",
        "application/json",
      );
      let _pipe$3 = with_auth(_pipe$2, token);
      let _pipe$4 = $request.set_body(_pipe$3, $json.to_string(body));
      let _pipe$5 = ((_capture) => { return send_text(client, _capture); })(
        _pipe$4,
      );
      let _pipe$6 = $result.map_error(
        _pipe$5,
        (var0) => { return new RequestFailed(var0); },
      );
      return $result.try$(_pipe$6, check_ok);
    },
  );
}

/**
 * POST raw bytes (e.g. `uploadBlob`); the response is decoded as text (JSON).
 */
export function post_bits(client, url, token, body, content_type) {
  return $result.try$(
    (() => {
      let _pipe = $request.to(url);
      return $result.replace_error(_pipe, new RequestFailed("bad url: " + url));
    })(),
    (base) => {
      let _block;
      let _pipe = base;
      let _pipe$1 = $request.set_method(_pipe, new $http.Post());
      let _pipe$2 = $request.set_header(_pipe$1, "content-type", content_type);
      let _pipe$3 = with_auth(_pipe$2, token);
      let _pipe$4 = $request.map(_pipe$3, $bit_array.from_string);
      let _pipe$5 = $request.set_body(_pipe$4, body);
      _block = client.send(_pipe$5);
      let sent = _block;
      return $result.try$(
        (() => {
          let _pipe$6 = sent;
          return $result.map_error(
            _pipe$6,
            (var0) => { return new RequestFailed(var0); },
          );
        })(),
        (resp) => {
          let $ = $bit_array.to_string(resp.body);
          if ($ instanceof Ok) {
            let text = $[0];
            return check_ok($response.set_body(resp, text));
          } else {
            return new Error(
              new RequestFailed("response body is not valid utf-8"),
            );
          }
        },
      );
    },
  );
}

export function parse(body, decoder) {
  let _pipe = $json.parse(body, decoder);
  return $result.map_error(
    _pipe,
    (e) => { return new DecodeFailed($string.inspect(e)); },
  );
}
