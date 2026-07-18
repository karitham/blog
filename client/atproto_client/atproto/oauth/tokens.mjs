import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import { Some } from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $gose from "../../../gose/gose.mjs";
import * as $flow from "../../atproto/oauth/flow.mjs";
import * as $metadata from "../../atproto/oauth/metadata.mjs";
import * as $transport from "../../atproto/oauth/transport.mjs";
import * as $xrpc from "../../atproto/xrpc.mjs";
import { Ok, Error, toList, CustomType as $CustomType } from "../../gleam.mjs";

export class Tokens extends $CustomType {
  constructor(access_token, refresh_token, sub, expires_in) {
    super();
    this.access_token = access_token;
    this.refresh_token = refresh_token;
    this.sub = sub;
    this.expires_in = expires_in;
  }
}
export const Tokens$Tokens = (access_token, refresh_token, sub, expires_in) =>
  new Tokens(access_token, refresh_token, sub, expires_in);
export const Tokens$isTokens = (value) => value instanceof Tokens;
export const Tokens$Tokens$access_token = (value) => value.access_token;
export const Tokens$Tokens$0 = (value) => value.access_token;
export const Tokens$Tokens$refresh_token = (value) => value.refresh_token;
export const Tokens$Tokens$1 = (value) => value.refresh_token;
export const Tokens$Tokens$sub = (value) => value.sub;
export const Tokens$Tokens$2 = (value) => value.sub;
export const Tokens$Tokens$expires_in = (value) => value.expires_in;
export const Tokens$Tokens$3 = (value) => value.expires_in;

function describe(e) {
  if (e instanceof $xrpc.RequestFailed) {
    let m = e[0];
    return m;
  } else if (e instanceof $xrpc.BadStatus) {
    let status = e.status;
    let body = e.body;
    return ($int.to_string(status) + ": ") + body;
  } else {
    let m = e[0];
    return "decode token response: " + m;
  }
}

function decoder() {
  return $decode.field(
    "access_token",
    $decode.string,
    (access_token) => {
      return $decode.field(
        "refresh_token",
        $decode.string,
        (refresh_token) => {
          return $decode.field(
            "sub",
            $decode.string,
            (sub) => {
              return $decode.optional_field(
                "expires_in",
                3600,
                $decode.int,
                (expires_in) => {
                  return $decode.success(
                    new Tokens(access_token, refresh_token, sub, expires_in),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

function submit(client, token_endpoint, dpop_key, form) {
  return $result.try$(
    $transport.post_form_with_dpop(client, token_endpoint, form, dpop_key),
    (resp) => {
      let $ = (resp.status >= 200) && (resp.status < 300);
      if ($) {
        let _pipe = $xrpc.parse(resp.body, decoder());
        return $result.map_error(_pipe, describe);
      } else {
        return new Error(
          (("token " + $int.to_string(resp.status)) + ": ") + resp.body,
        );
      }
    },
  );
}

export function exchange_code(client, flow, code, redirect_uri, extra_form) {
  return submit(
    client,
    flow.token_endpoint,
    flow.dpop_key,
    $list.append(
      toList([
        ["grant_type", "authorization_code"],
        ["code", code],
        ["code_verifier", flow.pkce_verifier],
        ["redirect_uri", redirect_uri],
        ["client_id", flow.client_id],
      ]),
      extra_form,
    ),
  );
}

export function refresh(
  client,
  token_endpoint,
  refresh_token,
  client_id,
  dpop_key,
  extra_form
) {
  return submit(
    client,
    token_endpoint,
    dpop_key,
    $list.append(
      toList([
        ["grant_type", "refresh_token"],
        ["refresh_token", refresh_token],
        ["client_id", client_id],
      ]),
      extra_form,
    ),
  );
}

/**
 * Best-effort refresh-token revocation at logout: discover the AS revocation
 * endpoint from the issuer and revoke. Failures are ignored (the caller
 * clears its local session regardless).
 */
export function revoke(
  client,
  issuer,
  refresh_token,
  client_id,
  dpop_key,
  extra_form
) {
  let $ = $metadata.fetch_authorization_server(client, issuer);
  if ($ instanceof Ok) {
    let meta = $[0];
    let $1 = meta.revocation_endpoint;
    if ($1 instanceof Some) {
      let endpoint = $1[0];
      let $2 = $transport.post_form_with_dpop(
        client,
        endpoint,
        $list.append(
          toList([
            ["token", refresh_token],
            ["token_type_hint", "refresh_token"],
            ["client_id", client_id],
          ]),
          extra_form,
        ),
        dpop_key,
      );
      
      return undefined;
    } else {
      return undefined;
    }
  } else {
    return undefined;
  }
}
