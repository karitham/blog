import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import { Ok, Error, toList, prepend as listPrepend, CustomType as $CustomType } from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $jwk from "../../gose/jose/jwk.mjs";

class JwkSet extends $CustomType {
  constructor(keys) {
    super();
    this.keys = keys;
  }
}

/**
 * Create a JWK Set from a list of keys.
 */
export function from_list(keys) {
  return new JwkSet(keys);
}

/**
 * Create an empty JWK Set.
 */
export function new$() {
  return new JwkSet(toList([]));
}

/**
 * Serialize a JWK Set to its JSON representation.
 */
export function to_json(jwk_set) {
  let json_keys = $list.map(jwk_set.keys, $jwk.to_json);
  return $json.object(toList([["keys", $json.preprocessed_array(json_keys)]]));
}

/**
 * Get all keys from a JWK Set as a list.
 */
export function to_list(jwk_set) {
  return jwk_set.keys;
}

function parse_keys_lenient(keys_dyn) {
  let keys = $list.filter_map(
    keys_dyn,
    (key_dyn) => {
      let _pipe = $jwk.from_dynamic(key_dyn);
      return $result.replace_error(_pipe, undefined);
    },
  );
  return new JwkSet(keys);
}

function parse_keys_array(parse) {
  let _pipe = parse($decode.at(toList(["keys"]), $decode.list($decode.dynamic)));
  return $result.replace_error(
    _pipe,
    new $gose.ParseError("missing or invalid keys array"),
  );
}

/**
 * Parse a JWK Set from a JSON string.
 *
 * The `keys` array is required. Unknown top-level members are ignored per RFC.
 * Invalid keys are silently skipped.
 */
export function from_json(json_str) {
  let _pipe = parse_keys_array(
    (_capture) => { return $json.parse(json_str, _capture); },
  );
  return $result.map(_pipe, parse_keys_lenient);
}

/**
 * Parse a JWK Set from a JSON BitArray.
 *
 * The `keys` array is required. Unknown top-level members are ignored per RFC.
 * Invalid keys are silently skipped.
 */
export function from_json_bits(json_bits) {
  let _pipe = parse_keys_array(
    (_capture) => { return $json.parse_bits(json_bits, _capture); },
  );
  return $result.map(_pipe, parse_keys_lenient);
}

function parse_keys_strict(keys_dyn) {
  let _pipe = $list.index_fold(
    keys_dyn,
    new Ok(toList([])),
    (acc, key_dyn, index) => {
      return $result.try$(
        acc,
        (keys) => {
          let $ = $jwk.from_dynamic(key_dyn);
          if ($ instanceof Ok) {
            let key = $[0];
            return new Ok(listPrepend(key, keys));
          } else {
            let err = $[0];
            let reason = $gose.error_message(err);
            return new Error(
              new $gose.ParseError(
                (("invalid key at index " + $int.to_string(index)) + ": ") + reason,
              ),
            );
          }
        },
      );
    },
  );
  return $result.map(_pipe, $list.reverse);
}

/**
 * Parse a JWK Set from a JSON string, failing on any invalid key.
 *
 * Unlike `from_json` which silently skips invalid keys, this function
 * returns an error if any key in the array fails to parse. The error
 * message includes the index of the invalid key.
 *
 * Note that RFC 7517 Section 5 says implementations SHOULD ignore JWKs
 * with unrecognised key types, missing required members, or unsupported
 * parameter values. Prefer `from_json` unless you need to guarantee
 * every key in the set is valid.
 */
export function from_json_strict(json_str) {
  let _pipe = parse_keys_array(
    (_capture) => { return $json.parse(json_str, _capture); },
  );
  let _pipe$1 = $result.try$(_pipe, parse_keys_strict);
  return $result.map(_pipe$1, (var0) => { return new JwkSet(var0); });
}

/**
 * Parse a JWK Set from a JSON BitArray, failing on any invalid key.
 *
 * Unlike `from_json_bits` which silently skips invalid keys, this function
 * returns an error if any key in the array fails to parse. The error
 * message includes the index of the invalid key.
 *
 * Note that RFC 7517 Section 5 says implementations SHOULD ignore JWKs
 * with unrecognised key types, missing required members, or unsupported
 * parameter values. Prefer `from_json_bits` unless you need to guarantee
 * every key in the set is valid.
 */
export function from_json_strict_bits(json_bits) {
  let _pipe = parse_keys_array(
    (_capture) => { return $json.parse_bits(json_bits, _capture); },
  );
  let _pipe$1 = $result.try$(_pipe, parse_keys_strict);
  return $result.map(_pipe$1, (var0) => { return new JwkSet(var0); });
}

/**
 * Return a lenient decoder for JWK Set values.
 *
 * Invalid keys are silently skipped, matching `from_json` behavior.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(set) = json.parse(json_string, key_set.decoder())
 * ```
 */
export function decoder() {
  return $decode.field(
    "keys",
    $decode.list($decode.dynamic),
    (keys_dyn) => { return $decode.success(parse_keys_lenient(keys_dyn)); },
  );
}

/**
 * Return a strict decoder for JWK Set values.
 *
 * Unlike `decoder()`, this fails if any key in the set is invalid.
 *
 * Note that RFC 7517 Section 5 says implementations SHOULD ignore JWKs
 * with unrecognised key types, missing required members, or unsupported
 * parameter values. Prefer `decoder()` unless you need to guarantee
 * every key in the set is valid.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(set) = json.parse(json_string, key_set.strict_decoder())
 * ```
 */
export function strict_decoder() {
  return $decode.field(
    "keys",
    $decode.list($jwk.decoder()),
    (keys) => { return $decode.success(new JwkSet(keys)); },
  );
}

/**
 * Find a key by its key ID (kid).
 */
export function get(jwk_set, kid) {
  return $list.find(
    jwk_set.keys,
    (key) => {
      let $ = $gose.kid(key);
      if ($ instanceof Ok) {
        let k = $[0];
        return k === kid;
      } else {
        return false;
      }
    },
  );
}

/**
 * Add a key to the set.
 *
 * Keys are prepended, so if a key with the same `kid` already exists,
 * the newer key shadows the older one and `get` will return the most
 * recently inserted key.
 */
export function insert(jwk_set, key) {
  return new JwkSet(listPrepend(key, jwk_set.keys));
}

/**
 * Remove a key by its key ID (kid).
 *
 * If no key with the given kid exists, returns the set unchanged.
 */
export function delete$(jwk_set, kid) {
  let filtered = $list.filter(
    jwk_set.keys,
    (key) => {
      let $ = $gose.kid(key);
      if ($ instanceof Ok) {
        let k = $[0];
        return k !== kid;
      } else {
        return true;
      }
    },
  );
  return new JwkSet(filtered);
}

/**
 * Filter keys by a predicate function.
 */
export function filter(jwk_set, predicate) {
  return new JwkSet($list.filter(jwk_set.keys, predicate));
}

/**
 * Get the first key in the set.
 *
 * Useful for single-key sets or when any key will suffice.
 */
export function first(jwk_set) {
  return $list.first(jwk_set.keys);
}
