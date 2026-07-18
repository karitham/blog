import * as $gose from "../../gose.mjs";
import * as $cbor from "../../gose/cbor.mjs";
import * as $cose from "../../gose/cose.mjs";

export function to_cbor(k) {
  return $cose.key_to_cbor(k);
}

export function from_cbor(data) {
  return $cose.key_from_cbor(data);
}

export function to_cbor_map(k) {
  return $cose.key_to_cbor_map(k);
}

export function from_cbor_map(map) {
  return $cose.key_from_cbor_map(map);
}
