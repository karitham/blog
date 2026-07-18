import * as $json from "../../gleam_json/gleam/json.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $uri from "../../gleam_stdlib/gleam/uri.mjs";
import { toList, CustomType as $CustomType } from "../gleam.mjs";

export class Blob extends $CustomType {
  constructor(cid, mime_type, size) {
    super();
    this.cid = cid;
    this.mime_type = mime_type;
    this.size = size;
  }
}
export const Blob$Blob = (cid, mime_type, size) =>
  new Blob(cid, mime_type, size);
export const Blob$isBlob = (value) => value instanceof Blob;
export const Blob$Blob$cid = (value) => value.cid;
export const Blob$Blob$0 = (value) => value.cid;
export const Blob$Blob$mime_type = (value) => value.mime_type;
export const Blob$Blob$1 = (value) => value.mime_type;
export const Blob$Blob$size = (value) => value.size;
export const Blob$Blob$2 = (value) => value.size;

export function encode_blob(value) {
  return $json.object(
    toList([
      ["$type", $json.string("blob")],
      ["ref", $json.object(toList([["$link", $json.string(value.cid)]]))],
      ["mimeType", $json.string(value.mime_type)],
      ["size", $json.int(value.size)],
    ]),
  );
}

export function blob_decoder() {
  return $decode.field(
    "ref",
    $decode.at(toList(["$link"]), $decode.string),
    (cid) => {
      return $decode.field(
        "mimeType",
        $decode.string,
        (mime_type) => {
          return $decode.field(
            "size",
            $decode.int,
            (size) => { return $decode.success(new Blob(cid, mime_type, size)); },
          );
        },
      );
    },
  );
}

/**
 * The public URL a PDS serves this blob's bytes from.
 */
export function public_url(pds, did, blob) {
  return (pds + "/xrpc/com.atproto.sync.getBlob?") + $uri.query_to_string(
    toList([["did", did], ["cid", blob.cid]]),
  );
}
