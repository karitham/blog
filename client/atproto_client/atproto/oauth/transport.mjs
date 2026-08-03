import * as $http from "../../../gleam_http/gleam/http.mjs";
import * as $request from "../../../gleam_http/gleam/http/request.mjs";
import * as $response from "../../../gleam_http/gleam/http/response.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import { Some, Option$None$const } from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $uri from "../../../gleam_stdlib/gleam/uri.mjs";
import * as $gose from "../../../gose/gose.mjs";
import * as $dpop from "../../atproto/oauth/dpop.mjs";
import * as $xrpc from "../../atproto/xrpc.mjs";
import { Ok } from "../../gleam.mjs";

function attempt(client, url, form, dpop_key, nonce) {
  return $result.try$(
    $dpop.proof(dpop_key, "POST", url, nonce, Option$None$const),
    (proof) => {
      return $result.try$(
        (() => {
          let _pipe = $request.to(url);
          return $result.replace_error(_pipe, "bad url: " + url);
        })(),
        (base) => {
          let _pipe = base;
          let _pipe$1 = $request.set_method(_pipe, $http.Method$Post$const);
          let _pipe$2 = $request.set_header(
            _pipe$1,
            "content-type",
            "application/x-www-form-urlencoded",
          );
          let _pipe$3 = $request.set_header(_pipe$2, "dpop", proof);
          let _pipe$4 = $request.set_body(_pipe$3, $uri.query_to_string(form));
          return ((_capture) => { return $xrpc.send_text(client, _capture); })(
            _pipe$4,
          );
        },
      );
    },
  );
}

/**
 * The DPoP nonce a server is asking us to use, if it rejected the request with
 * `use_dpop_nonce`. The authorization server (PAR/token) signals this in the
 * JSON body; the PDS resource server signals it in the `WWW-Authenticate`
 * header. Either way the nonce itself comes in the `DPoP-Nonce` header.
 */
export function dpop_nonce_challenge(resp) {
  let stale = (resp.status === 400) || (resp.status === 401);
  let _block;
  let _pipe = $response.get_header(resp, "www-authenticate");
  _block = $result.unwrap(_pipe, "");
  let www_auth = _block;
  let signaled = $string.contains(resp.body, "use_dpop_nonce") || $string.contains(
    www_auth,
    "use_dpop_nonce",
  );
  let $ = stale && signaled;
  if ($) {
    return $option.from_result($response.get_header(resp, "dpop-nonce"));
  } else {
    return Option$None$const;
  }
}

export function post_form_with_dpop(client, url, form, dpop_key) {
  return $result.try$(
    attempt(client, url, form, dpop_key, Option$None$const),
    (first) => {
      let $ = dpop_nonce_challenge(first);
      if ($ instanceof Some) {
        let nonce = $[0];
        return attempt(client, url, form, dpop_key, new Some(nonce));
      } else {
        return new Ok(first);
      }
    },
  );
}
