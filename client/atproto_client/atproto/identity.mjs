import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { Option$None$const } from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $uri from "../../gleam_stdlib/gleam/uri.mjs";
import * as $xrpc from "../atproto/xrpc.mjs";
import { toList, CustomType as $CustomType } from "../gleam.mjs";

export class MiniDoc extends $CustomType {
  constructor(did, pds) {
    super();
    this.did = did;
    this.pds = pds;
  }
}
export const MiniDoc$MiniDoc = (did, pds) => new MiniDoc(did, pds);
export const MiniDoc$isMiniDoc = (value) => value instanceof MiniDoc;
export const MiniDoc$MiniDoc$did = (value) => value.did;
export const MiniDoc$MiniDoc$0 = (value) => value.did;
export const MiniDoc$MiniDoc$pds = (value) => value.pds;
export const MiniDoc$MiniDoc$1 = (value) => value.pds;

export const default_resolver = "https://slingshot.microcosm.blue";

export function resolve_mini_doc(client, resolver, identifier) {
  let query = $uri.query_to_string(toList([["identifier", identifier]]));
  let url = (resolver + "/xrpc/com.bad-example.identity.resolveMiniDoc?") + query;
  return $result.try$(
    $xrpc.get(client, url, Option$None$const),
    (resp) => {
      let decoder = $decode.field(
        "did",
        $decode.string,
        (did) => {
          return $decode.field(
            "pds",
            $decode.string,
            (pds) => { return $decode.success(new MiniDoc(did, pds)); },
          );
        },
      );
      return $xrpc.parse(resp.body, decoder);
    },
  );
}

export function resolve_pds(client, resolver, identifier) {
  let _pipe = resolve_mini_doc(client, resolver, identifier);
  return $result.map(_pipe, (doc) => { return doc.pds; });
}
