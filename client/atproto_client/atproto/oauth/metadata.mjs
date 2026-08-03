import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import { Option$None$const } from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $xrpc from "../../atproto/xrpc.mjs";
import { toList, CustomType as $CustomType } from "../../gleam.mjs";

export class AuthServerMetadata extends $CustomType {
  constructor(issuer, authorization_endpoint, token_endpoint, pushed_authorization_request_endpoint, revocation_endpoint) {
    super();
    this.issuer = issuer;
    this.authorization_endpoint = authorization_endpoint;
    this.token_endpoint = token_endpoint;
    this.pushed_authorization_request_endpoint = pushed_authorization_request_endpoint;
    this.revocation_endpoint = revocation_endpoint;
  }
}
export const AuthServerMetadata$AuthServerMetadata = (issuer, authorization_endpoint, token_endpoint, pushed_authorization_request_endpoint, revocation_endpoint) =>
  new AuthServerMetadata(issuer,
  authorization_endpoint,
  token_endpoint,
  pushed_authorization_request_endpoint,
  revocation_endpoint);
export const AuthServerMetadata$isAuthServerMetadata = (value) =>
  value instanceof AuthServerMetadata;
export const AuthServerMetadata$AuthServerMetadata$issuer = (value) =>
  value.issuer;
export const AuthServerMetadata$AuthServerMetadata$0 = (value) => value.issuer;
export const AuthServerMetadata$AuthServerMetadata$authorization_endpoint = (value) =>
  value.authorization_endpoint;
export const AuthServerMetadata$AuthServerMetadata$1 = (value) =>
  value.authorization_endpoint;
export const AuthServerMetadata$AuthServerMetadata$token_endpoint = (value) =>
  value.token_endpoint;
export const AuthServerMetadata$AuthServerMetadata$2 = (value) =>
  value.token_endpoint;
export const AuthServerMetadata$AuthServerMetadata$pushed_authorization_request_endpoint = (value) =>
  value.pushed_authorization_request_endpoint;
export const AuthServerMetadata$AuthServerMetadata$3 = (value) =>
  value.pushed_authorization_request_endpoint;
export const AuthServerMetadata$AuthServerMetadata$revocation_endpoint = (value) =>
  value.revocation_endpoint;
export const AuthServerMetadata$AuthServerMetadata$4 = (value) =>
  value.revocation_endpoint;

function protected_resource_decoder() {
  return $decode.at(
    toList(["authorization_servers"]),
    $decode.list($decode.string),
  );
}

function auth_server_decoder() {
  return $decode.field(
    "issuer",
    $decode.string,
    (issuer) => {
      return $decode.field(
        "authorization_endpoint",
        $decode.string,
        (authorization_endpoint) => {
          return $decode.field(
            "token_endpoint",
            $decode.string,
            (token_endpoint) => {
              return $decode.field(
                "pushed_authorization_request_endpoint",
                $decode.string,
                (par) => {
                  return $decode.optional_field(
                    "revocation_endpoint",
                    Option$None$const,
                    $decode.optional($decode.string),
                    (revocation_endpoint) => {
                      return $decode.success(
                        new AuthServerMetadata(
                          issuer,
                          authorization_endpoint,
                          token_endpoint,
                          par,
                          revocation_endpoint,
                        ),
                      );
                    },
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

export function fetch_protected_resource(client, pds) {
  let url = pds + "/.well-known/oauth-protected-resource";
  return $result.try$(
    $xrpc.get(client, url, Option$None$const),
    (resp) => { return $xrpc.parse(resp.body, protected_resource_decoder()); },
  );
}

export function fetch_authorization_server(client, issuer) {
  let url = issuer + "/.well-known/oauth-authorization-server";
  return $result.try$(
    $xrpc.get(client, url, Option$None$const),
    (resp) => { return $xrpc.parse(resp.body, auth_server_decoder()); },
  );
}

/**
 * Resolve a PDS to its authorization server's endpoints in one call.
 */
export function discover(client, pds) {
  return $result.try$(
    fetch_protected_resource(client, pds),
    (servers) => {
      return $result.try$(
        $result.replace_error(
          $list.first(servers),
          new $xrpc.DecodeFailed(
            "no authorization_servers in protected-resource metadata",
          ),
        ),
        (issuer) => { return fetch_authorization_server(client, issuer); },
      );
    },
  );
}
