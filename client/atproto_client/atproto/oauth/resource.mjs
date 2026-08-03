import * as $crypto from "../../../gleam_crypto/gleam/crypto.mjs";
import * as $http from "../../../gleam_http/gleam/http.mjs";
import * as $request from "../../../gleam_http/gleam/http/request.mjs";
import * as $response from "../../../gleam_http/gleam/http/response.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import { Some, Option$None$const } from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $uri from "../../../gleam_stdlib/gleam/uri.mjs";
import * as $gose from "../../../gose/gose.mjs";
import * as $dpop from "../../atproto/oauth/dpop.mjs";
import * as $transport from "../../atproto/oauth/transport.mjs";
import * as $xrpc from "../../atproto/xrpc.mjs";
import { Ok } from "../../gleam.mjs";

function send_once(
  base,
  access_token,
  dpop_key,
  req,
  method,
  target,
  ath,
  nonce
) {
  return $result.try$(
    $dpop.proof(dpop_key, method, target, nonce, new Some(ath)),
    (proof) => {
      let _pipe = req;
      let _pipe$1 = $request.set_header(
        _pipe,
        "authorization",
        "DPoP " + access_token,
      );
      let _pipe$2 = $request.set_header(_pipe$1, "dpop", proof);
      return base.send(_pipe$2);
    },
  );
}

function as_text(resp) {
  let _block;
  let $ = $response.get_header(resp, "content-type");
  if ($ instanceof Ok) {
    let content_type = $[0];
    _block = $string.starts_with(content_type, "application/json");
  } else {
    _block = false;
  }
  let json_body = _block;
  return $response.map(
    resp,
    (body) => {
      if (json_body) {
        let _pipe = $bit_array.to_string(body);
        return $result.unwrap(_pipe, "");
      } else {
        return "";
      }
    },
  );
}

function b64(bits) {
  return $bit_array.base64_url_encode(bits, false);
}

/**
 * The DPoP `htu`: the request URI without query or fragment.
 * 
 * @ignore
 */
function htu(req) {
  let u = $request.to_uri(req);
  return $uri.to_string(
    new $uri.Uri(
      u.scheme,
      u.userinfo,
      u.host,
      u.port,
      u.path,
      Option$None$const,
      Option$None$const,
    ),
  );
}

function dpop_send(base, access_token, dpop_key, req) {
  let _block;
  let _pipe = $http.method_to_string(req.method);
  _block = $string.uppercase(_pipe);
  let method = _block;
  let target = htu(req);
  let ath = b64(
    $crypto.hash(
      $crypto.HashAlgorithm$Sha256$const,
      $bit_array.from_string(access_token),
    ),
  );
  return $result.try$(
    send_once(
      base,
      access_token,
      dpop_key,
      req,
      method,
      target,
      ath,
      Option$None$const,
    ),
    (first) => {
      let $ = $transport.dpop_nonce_challenge(as_text(first));
      if ($ instanceof Some) {
        let nonce = $[0];
        return send_once(
          base,
          access_token,
          dpop_key,
          req,
          method,
          target,
          ath,
          new Some(nonce),
        );
      } else {
        return new Ok(first);
      }
    },
  );
}

/**
 * A client that signs every request against the given DPoP-bound access token.
 */
export function client(base, access_token, dpop_key) {
  return new $xrpc.Client(
    (req) => { return dpop_send(base, access_token, dpop_key, req); },
  );
}
