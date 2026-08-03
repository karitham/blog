import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { Some, Option$None$const } from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $uri from "../../gleam_stdlib/gleam/uri.mjs";
import * as $xrpc from "../atproto/xrpc.mjs";
import { toList, CustomType as $CustomType } from "../gleam.mjs";

export class Backlink extends $CustomType {
  constructor(did, collection, rkey) {
    super();
    this.did = did;
    this.collection = collection;
    this.rkey = rkey;
  }
}
export const Backlink$Backlink = (did, collection, rkey) =>
  new Backlink(did, collection, rkey);
export const Backlink$isBacklink = (value) => value instanceof Backlink;
export const Backlink$Backlink$did = (value) => value.did;
export const Backlink$Backlink$0 = (value) => value.did;
export const Backlink$Backlink$collection = (value) => value.collection;
export const Backlink$Backlink$1 = (value) => value.collection;
export const Backlink$Backlink$rkey = (value) => value.rkey;
export const Backlink$Backlink$2 = (value) => value.rkey;

export class BacklinksPage extends $CustomType {
  constructor(total, records, cursor) {
    super();
    this.total = total;
    this.records = records;
    this.cursor = cursor;
  }
}
export const BacklinksPage$BacklinksPage = (total, records, cursor) =>
  new BacklinksPage(total, records, cursor);
export const BacklinksPage$isBacklinksPage = (value) =>
  value instanceof BacklinksPage;
export const BacklinksPage$BacklinksPage$total = (value) => value.total;
export const BacklinksPage$BacklinksPage$0 = (value) => value.total;
export const BacklinksPage$BacklinksPage$records = (value) => value.records;
export const BacklinksPage$BacklinksPage$1 = (value) => value.records;
export const BacklinksPage$BacklinksPage$cursor = (value) => value.cursor;
export const BacklinksPage$BacklinksPage$2 = (value) => value.cursor;

export const default_host = "https://constellation.microcosm.blue";

function backlink_decoder() {
  return $decode.field(
    "did",
    $decode.string,
    (did) => {
      return $decode.field(
        "collection",
        $decode.string,
        (collection) => {
          return $decode.field(
            "rkey",
            $decode.string,
            (rkey) => {
              return $decode.success(new Backlink(did, collection, rkey));
            },
          );
        },
      );
    },
  );
}

function page_decoder() {
  return $decode.field(
    "total",
    $decode.int,
    (total) => {
      return $decode.field(
        "records",
        $decode.list(backlink_decoder()),
        (records) => {
          return $decode.optional_field(
            "cursor",
            Option$None$const,
            $decode.optional($decode.string),
            (cursor) => {
              return $decode.success(new BacklinksPage(total, records, cursor));
            },
          );
        },
      );
    },
  );
}

/**
 * Records linking to `subject` (an at-uri, DID, or plain URL). `source` names
 * where the link must appear: `<collection>:<json.path>`, e.g.
 * `app.bsky.feed.like:subject.uri`.
 */
export function get_backlinks(client, host, subject, source, limit, cursor) {
  let params = toList([
    ["subject", subject],
    ["source", source],
    ["limit", $int.to_string(limit)],
  ]);
  let _block;
  if (cursor instanceof Some) {
    let c = cursor[0];
    _block = $list.append(params, toList([["cursor", c]]));
  } else {
    _block = params;
  }
  let params$1 = _block;
  let url = (host + "/xrpc/blue.microcosm.links.getBacklinks?") + $uri.query_to_string(
    params$1,
  );
  return $result.try$(
    $xrpc.get(client, url, Option$None$const),
    (resp) => { return $xrpc.parse(resp.body, page_decoder()); },
  );
}

export function record_uri(backlink) {
  return (((("at://" + backlink.did) + "/") + backlink.collection) + "/") + backlink.rkey;
}
