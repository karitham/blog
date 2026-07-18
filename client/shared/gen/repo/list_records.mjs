import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $dynamic from "../../../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $internal from "../../gen/internal.mjs";
import { toList, CustomType as $CustomType } from "../../gleam.mjs";

export class Record extends $CustomType {
  constructor(cid, uri, value) {
    super();
    this.cid = cid;
    this.uri = uri;
    this.value = value;
  }
}
export const Record$Record = (cid, uri, value) => new Record(cid, uri, value);
export const Record$isRecord = (value) => value instanceof Record;
export const Record$Record$cid = (value) => value.cid;
export const Record$Record$0 = (value) => value.cid;
export const Record$Record$uri = (value) => value.uri;
export const Record$Record$1 = (value) => value.uri;
export const Record$Record$value = (value) => value.value;
export const Record$Record$2 = (value) => value.value;

export function record_fields(value) {
  return toList([
    ["cid", $json.string(value.cid)],
    ["uri", $json.string(value.uri)],
    ["value", $internal.dynamic_to_json(value.value)],
  ]);
}

export function encode_record(value) {
  return $json.object(record_fields(value));
}

export function record_decoder() {
  return $decode.field(
    "cid",
    $decode.string,
    (cid) => {
      return $decode.field(
        "uri",
        $decode.string,
        (uri) => {
          return $decode.field(
            "value",
            $decode.dynamic,
            (value) => { return $decode.success(new Record(cid, uri, value)); },
          );
        },
      );
    },
  );
}
