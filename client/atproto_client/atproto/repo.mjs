import * as $json from "../../gleam_json/gleam/json.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $uri from "../../gleam_stdlib/gleam/uri.mjs";
import * as $blob from "../atproto/blob.mjs";
import * as $xrpc from "../atproto/xrpc.mjs";
import { Ok, toList, prepend as listPrepend, CustomType as $CustomType } from "../gleam.mjs";

export class CreatedRecord extends $CustomType {
  constructor(uri, cid) {
    super();
    this.uri = uri;
    this.cid = cid;
  }
}
export const CreatedRecord$CreatedRecord = (uri, cid) =>
  new CreatedRecord(uri, cid);
export const CreatedRecord$isCreatedRecord = (value) =>
  value instanceof CreatedRecord;
export const CreatedRecord$CreatedRecord$uri = (value) => value.uri;
export const CreatedRecord$CreatedRecord$0 = (value) => value.uri;
export const CreatedRecord$CreatedRecord$cid = (value) => value.cid;
export const CreatedRecord$CreatedRecord$1 = (value) => value.cid;

function list_page(
  client,
  pds,
  token,
  did,
  collection,
  row_decoder,
  cursor,
  acc
) {
  let base = toList([
    ["repo", did],
    ["collection", collection],
    ["limit", "100"],
  ]);
  let _block;
  if (cursor instanceof Some) {
    let c = cursor[0];
    _block = listPrepend(["cursor", c], base);
  } else {
    _block = base;
  }
  let params = _block;
  let url = (pds + "/xrpc/com.atproto.repo.listRecords?") + $uri.query_to_string(
    params,
  );
  return $result.try$(
    $xrpc.get(client, url, new Some(token)),
    (resp) => {
      let page = $decode.field(
        "records",
        $decode.list(row_decoder),
        (rows) => {
          return $decode.optional_field(
            "cursor",
            new None(),
            $decode.optional($decode.string),
            (next) => { return $decode.success([rows, next]); },
          );
        },
      );
      return $result.try$(
        $xrpc.parse(resp.body, page),
        (_use0) => {
          let rows = _use0[0];
          let next = _use0[1];
          let all = $list.append(acc, rows);
          if (next instanceof Some) {
            let $ = next[0];
            if ($ === "") {
              return new Ok(all);
            } else {
              let c = $;
              return list_page(
                client,
                pds,
                token,
                did,
                collection,
                row_decoder,
                new Some(c),
                all,
              );
            }
          } else {
            return new Ok(all);
          }
        },
      );
    },
  );
}

/**
 * List every record in a collection, following the cursor across pages (the
 * XRPC endpoint caps each page at 100). Returns the full set.
 */
export function list_records(client, pds, token, did, collection, row_decoder) {
  return list_page(
    client,
    pds,
    token,
    did,
    collection,
    row_decoder,
    new None(),
    toList([]),
  );
}

export function create_record(client, pds, token, did, collection, record) {
  let body = $json.object(
    toList([
      ["repo", $json.string(did)],
      ["collection", $json.string(collection)],
      ["record", record],
    ]),
  );
  return $result.try$(
    $xrpc.post_json(
      client,
      pds + "/xrpc/com.atproto.repo.createRecord",
      new Some(token),
      body,
    ),
    (resp) => {
      let decoder = $decode.field(
        "uri",
        $decode.string,
        (uri) => {
          return $decode.field(
            "cid",
            $decode.string,
            (cid) => { return $decode.success(new CreatedRecord(uri, cid)); },
          );
        },
      );
      return $xrpc.parse(resp.body, decoder);
    },
  );
}

/**
 * Fetch one record, decoding the full envelope (uri/cid/value) with the
 * supplied decoder, e.g. to build a strongRef to it.
 */
export function get_record_envelope(
  client,
  pds,
  token,
  did,
  collection,
  rkey,
  decoder
) {
  let query = $uri.query_to_string(
    toList([["repo", did], ["collection", collection], ["rkey", rkey]]),
  );
  let url = (pds + "/xrpc/com.atproto.repo.getRecord?") + query;
  return $result.try$(
    $xrpc.get(client, url, new Some(token)),
    (resp) => { return $xrpc.parse(resp.body, decoder); },
  );
}

/**
 * Fetch one record and decode its `value` with the supplied decoder.
 */
export function get_record(
  client,
  pds,
  token,
  did,
  collection,
  rkey,
  value_decoder
) {
  let query = $uri.query_to_string(
    toList([["repo", did], ["collection", collection], ["rkey", rkey]]),
  );
  let url = (pds + "/xrpc/com.atproto.repo.getRecord?") + query;
  return $result.try$(
    $xrpc.get(client, url, new Some(token)),
    (resp) => {
      return $xrpc.parse(
        resp.body,
        $decode.at(toList(["value"]), value_decoder),
      );
    },
  );
}

/**
 * Write a record at a known rkey (create or replace), keeping a stable URI.
 */
export function put_record(client, pds, token, did, collection, rkey, record) {
  let body = $json.object(
    toList([
      ["repo", $json.string(did)],
      ["collection", $json.string(collection)],
      ["rkey", $json.string(rkey)],
      ["record", record],
    ]),
  );
  return $result.try$(
    $xrpc.post_json(
      client,
      pds + "/xrpc/com.atproto.repo.putRecord",
      new Some(token),
      body,
    ),
    (resp) => {
      let decoder = $decode.field(
        "uri",
        $decode.string,
        (uri) => {
          return $decode.field(
            "cid",
            $decode.string,
            (cid) => { return $decode.success(new CreatedRecord(uri, cid)); },
          );
        },
      );
      return $xrpc.parse(resp.body, decoder);
    },
  );
}

/**
 * Upload bytes to the authed repo. The returned ref must be embedded in a
 * record before the PDS garbage-collects it.
 */
export function upload_blob(client, pds, token, bytes, mime_type) {
  return $result.try$(
    $xrpc.post_bits(
      client,
      pds + "/xrpc/com.atproto.repo.uploadBlob",
      new Some(token),
      bytes,
      mime_type,
    ),
    (resp) => {
      return $xrpc.parse(
        resp.body,
        $decode.at(toList(["blob"]), $blob.blob_decoder()),
      );
    },
  );
}

export function delete_record(client, pds, token, did, collection, rkey) {
  let body = $json.object(
    toList([
      ["repo", $json.string(did)],
      ["collection", $json.string(collection)],
      ["rkey", $json.string(rkey)],
    ]),
  );
  return $result.try$(
    $xrpc.post_json(
      client,
      pds + "/xrpc/com.atproto.repo.deleteRecord",
      new Some(token),
      body,
    ),
    (_) => { return new Ok(undefined); },
  );
}
