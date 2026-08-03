import * as $json from "../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $dict from "../../gleam_stdlib/gleam/dict.mjs";
import * as $dynamic from "../../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../../gleam_stdlib/gleam/option.mjs";
import { Ok, toList, List$Empty$const as $List$Empty$const, toBitArray } from "../gleam.mjs";

/**
 * One JSON field, or nothing when the value is absent. Keeps optional
 * properties out of the encoded object entirely rather than emitting null.
 */
export function opt(name, value, to_json) {
  if (value instanceof Some) {
    let v = value[0];
    return toList([[name, to_json(v)]]);
  } else {
    return $List$Empty$const;
  }
}

/**
 * A `cid-link` is rendered in JSON as `{ "$link": <cid> }`.
 */
export function encode_cid_link(cid) {
  return $json.object(toList([["$link", $json.string(cid)]]));
}

export function cid_link_decoder() {
  return $decode.at(toList(["$link"]), $decode.string);
}

/**
 * `bytes` are rendered in JSON as `{ "$bytes": <base64, no padding> }`.
 */
export function encode_bytes(bytes) {
  return $json.object(
    toList([["$bytes", $json.string($bit_array.base64_encode(bytes, false))]]),
  );
}

export function bytes_decoder() {
  return $decode.then$(
    $decode.at(toList(["$bytes"]), $decode.string),
    (encoded) => {
      let $ = $bit_array.base64_decode(encoded);
      if ($ instanceof Ok) {
        let bytes = $[0];
        return $decode.success(bytes);
      } else {
        return $decode.failure(toBitArray([]), "bytes");
      }
    },
  );
}

function json_value_decoder() {
  return $decode.recursive(
    () => {
      return $decode.one_of(
        (() => {
          let _pipe = $decode.bool;
          return $decode.map(_pipe, $json.bool);
        })(),
        toList([
          (() => {
            let _pipe = $decode.int;
            return $decode.map(_pipe, $json.int);
          })(),
          (() => {
            let _pipe = $decode.float;
            return $decode.map(_pipe, $json.float);
          })(),
          (() => {
            let _pipe = $decode.string;
            return $decode.map(_pipe, $json.string);
          })(),
          (() => {
            let _pipe = $decode.list(json_value_decoder());
            return $decode.map(_pipe, $json.preprocessed_array);
          })(),
          (() => {
            let _pipe = $decode.dict($decode.string, json_value_decoder());
            return $decode.map(
              _pipe,
              (entries) => { return $json.object($dict.to_list(entries)); },
            );
          })(),
          $decode.success($json.null$()),
        ]),
      );
    },
  );
}

/**
 * Re-encode an already-decoded `unknown` value back to JSON so records that
 * carry one round-trip. Reconstructs the JSON value from the decoded `Dynamic`.
 */
export function dynamic_to_json(value) {
  let $ = $decode.run(value, json_value_decoder());
  if ($ instanceof Ok) {
    let rendered = $[0];
    return rendered;
  } else {
    return $json.null$();
  }
}
