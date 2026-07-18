import * as $json from "../../gleam_json/gleam/json.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $xrpc from "../atproto/xrpc.mjs";
import { toList, CustomType as $CustomType } from "../gleam.mjs";

export class SessionTokens extends $CustomType {
  constructor(did, handle, access_jwt, refresh_jwt) {
    super();
    this.did = did;
    this.handle = handle;
    this.access_jwt = access_jwt;
    this.refresh_jwt = refresh_jwt;
  }
}
export const SessionTokens$SessionTokens = (did, handle, access_jwt, refresh_jwt) =>
  new SessionTokens(did, handle, access_jwt, refresh_jwt);
export const SessionTokens$isSessionTokens = (value) =>
  value instanceof SessionTokens;
export const SessionTokens$SessionTokens$did = (value) => value.did;
export const SessionTokens$SessionTokens$0 = (value) => value.did;
export const SessionTokens$SessionTokens$handle = (value) => value.handle;
export const SessionTokens$SessionTokens$1 = (value) => value.handle;
export const SessionTokens$SessionTokens$access_jwt = (value) =>
  value.access_jwt;
export const SessionTokens$SessionTokens$2 = (value) => value.access_jwt;
export const SessionTokens$SessionTokens$refresh_jwt = (value) =>
  value.refresh_jwt;
export const SessionTokens$SessionTokens$3 = (value) => value.refresh_jwt;

function tokens_decoder() {
  return $decode.field(
    "did",
    $decode.string,
    (did) => {
      return $decode.field(
        "handle",
        $decode.string,
        (handle) => {
          return $decode.field(
            "accessJwt",
            $decode.string,
            (access_jwt) => {
              return $decode.field(
                "refreshJwt",
                $decode.string,
                (refresh_jwt) => {
                  return $decode.success(
                    new SessionTokens(did, handle, access_jwt, refresh_jwt),
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

export function create_session(client, pds, identifier, password) {
  let body = $json.object(
    toList([
      ["identifier", $json.string(identifier)],
      ["password", $json.string(password)],
    ]),
  );
  return $result.try$(
    $xrpc.post_json(
      client,
      pds + "/xrpc/com.atproto.server.createSession",
      new None(),
      body,
    ),
    (resp) => { return $xrpc.parse(resp.body, tokens_decoder()); },
  );
}

/**
 * Exchange a refresh JWT for a fresh session (the refresh token is sent as the
 * bearer credential, per `com.atproto.server.refreshSession`).
 */
export function refresh_session(client, pds, refresh_jwt) {
  return $result.try$(
    $xrpc.post_json(
      client,
      pds + "/xrpc/com.atproto.server.refreshSession",
      new Some(refresh_jwt),
      $json.object(toList([])),
    ),
    (resp) => { return $xrpc.parse(resp.body, tokens_decoder()); },
  );
}
