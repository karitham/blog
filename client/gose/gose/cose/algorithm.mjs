import * as $gose from "../../gose.mjs";
import * as $cose from "../../gose/cose.mjs";

export function signature_alg_to_int(alg) {
  return $cose.signature_alg_to_int(alg);
}

export function signature_alg_from_int(id) {
  return $cose.signature_alg_from_int(id);
}

export function mac_alg_to_int(alg) {
  return $cose.mac_alg_to_int(alg);
}

export function mac_alg_from_int(id) {
  return $cose.mac_alg_from_int(id);
}

export function signing_alg_to_int(alg) {
  return $cose.signing_alg_to_int(alg);
}

export function signing_alg_from_int(id) {
  return $cose.signing_alg_from_int(id);
}

export function key_encryption_alg_to_int(alg) {
  return $cose.key_encryption_alg_to_int(alg);
}

export function key_encryption_alg_from_int(id) {
  return $cose.key_encryption_alg_from_int(id);
}

export function content_alg_to_int(alg) {
  return $cose.content_alg_to_int(alg);
}

export function content_alg_from_int(id) {
  return $cose.content_alg_from_int(id);
}
