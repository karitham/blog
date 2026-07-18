import * as $crypto from "../../../gleam_crypto/gleam/crypto.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $uri from "../../../gleam_stdlib/gleam/uri.mjs";
import * as $gose from "../../../gose/gose.mjs";
import * as $identity from "../../atproto/identity.mjs";
import * as $dpop from "../../atproto/oauth/dpop.mjs";
import * as $metadata from "../../atproto/oauth/metadata.mjs";
import * as $pkce from "../../atproto/oauth/pkce.mjs";
import * as $transport from "../../atproto/oauth/transport.mjs";
import * as $xrpc from "../../atproto/xrpc.mjs";
import { Ok, Error, toList, CustomType as $CustomType } from "../../gleam.mjs";

export class Flow extends $CustomType {
  constructor(identifier, pds, issuer, token_endpoint, dpop_key, pkce_verifier, client_id, state) {
    super();
    this.identifier = identifier;
    this.pds = pds;
    this.issuer = issuer;
    this.token_endpoint = token_endpoint;
    this.dpop_key = dpop_key;
    this.pkce_verifier = pkce_verifier;
    this.client_id = client_id;
    this.state = state;
  }
}
export const Flow$Flow = (identifier, pds, issuer, token_endpoint, dpop_key, pkce_verifier, client_id, state) =>
  new Flow(identifier,
  pds,
  issuer,
  token_endpoint,
  dpop_key,
  pkce_verifier,
  client_id,
  state);
export const Flow$isFlow = (value) => value instanceof Flow;
export const Flow$Flow$identifier = (value) => value.identifier;
export const Flow$Flow$0 = (value) => value.identifier;
export const Flow$Flow$pds = (value) => value.pds;
export const Flow$Flow$1 = (value) => value.pds;
export const Flow$Flow$issuer = (value) => value.issuer;
export const Flow$Flow$2 = (value) => value.issuer;
export const Flow$Flow$token_endpoint = (value) => value.token_endpoint;
export const Flow$Flow$3 = (value) => value.token_endpoint;
export const Flow$Flow$dpop_key = (value) => value.dpop_key;
export const Flow$Flow$4 = (value) => value.dpop_key;
export const Flow$Flow$pkce_verifier = (value) => value.pkce_verifier;
export const Flow$Flow$5 = (value) => value.pkce_verifier;
export const Flow$Flow$client_id = (value) => value.client_id;
export const Flow$Flow$6 = (value) => value.client_id;
export const Flow$Flow$state = (value) => value.state;
export const Flow$Flow$7 = (value) => value.state;

export class ResolveFailed extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const FlowError$ResolveFailed = ($0) => new ResolveFailed($0);
export const FlowError$isResolveFailed = (value) =>
  value instanceof ResolveFailed;
export const FlowError$ResolveFailed$0 = (value) => value[0];

export class DiscoverFailed extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const FlowError$DiscoverFailed = ($0) => new DiscoverFailed($0);
export const FlowError$isDiscoverFailed = (value) =>
  value instanceof DiscoverFailed;
export const FlowError$DiscoverFailed$0 = (value) => value[0];

export class ParFailed extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const FlowError$ParFailed = ($0) => new ParFailed($0);
export const FlowError$isParFailed = (value) => value instanceof ParFailed;
export const FlowError$ParFailed$0 = (value) => value[0];

export class DpopFailed extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const FlowError$DpopFailed = ($0) => new DpopFailed($0);
export const FlowError$isDpopFailed = (value) => value instanceof DpopFailed;
export const FlowError$DpopFailed$0 = (value) => value[0];

function push_par(client, meta, form, dpop_key) {
  return $result.try$(
    (() => {
      let _pipe = $transport.post_form_with_dpop(
        client,
        meta.pushed_authorization_request_endpoint,
        form,
        dpop_key,
      );
      return $result.map_error(_pipe, (var0) => { return new ParFailed(var0); });
    })(),
    (resp) => {
      let $ = (resp.status >= 200) && (resp.status < 300);
      if ($) {
        let _pipe = $xrpc.parse(
          resp.body,
          $decode.at(toList(["request_uri"]), $decode.string),
        );
        return $result.map_error(
          _pipe,
          (e) => { return new ParFailed($string.inspect(e)); },
        );
      } else {
        return new Error(
          new ParFailed(
            (("PAR " + $int.to_string(resp.status)) + ": ") + resp.body,
          ),
        );
      }
    },
  );
}

function b64(bits) {
  return $bit_array.base64_url_encode(bits, false);
}

/**
 * Returns the authorization-server URL to send the user to, and the pending
 * flow. The caller must verify the callback's `state` against `flow.state`
 * before exchanging the code.
 */
export function start(
  client,
  resolver,
  identifier,
  client_id,
  redirect_uri,
  scope,
  extra_form
) {
  return $result.try$(
    (() => {
      let _pipe = $identity.resolve_pds(client, resolver, identifier);
      return $result.map_error(
        _pipe,
        (e) => { return new ResolveFailed($string.inspect(e)); },
      );
    })(),
    (pds) => {
      return $result.try$(
        (() => {
          let _pipe = $metadata.discover(client, pds);
          return $result.map_error(
            _pipe,
            (e) => { return new DiscoverFailed($string.inspect(e)); },
          );
        })(),
        (meta) => {
          let pk = $pkce.generate();
          let dpop_key = $dpop.generate_key();
          let state = b64($crypto.strong_random_bytes(16));
          let form = $list.append(
            toList([
              ["client_id", client_id],
              ["response_type", "code"],
              ["code_challenge", pk.challenge],
              ["code_challenge_method", "S256"],
              ["redirect_uri", redirect_uri],
              ["scope", scope],
              ["state", state],
              ["login_hint", identifier],
            ]),
            extra_form,
          );
          return $result.try$(
            push_par(client, meta, form, dpop_key),
            (request_uri) => {
              let flow = new Flow(
                identifier,
                pds,
                meta.issuer,
                meta.token_endpoint,
                dpop_key,
                pk.verifier,
                client_id,
                state,
              );
              let redirect_url = (meta.authorization_endpoint + "?") + $uri.query_to_string(
                toList([["client_id", client_id], ["request_uri", request_uri]]),
              );
              return new Ok([redirect_url, flow]);
            },
          );
        },
      );
    },
  );
}
