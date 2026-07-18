import * as $gose from "../../gose.mjs";
import * as $jose from "../../gose/jose.mjs";

export function signing_alg_to_string(alg) {
  return $jose.signing_alg_to_string(alg);
}

export function signing_alg_from_string(alg) {
  return $jose.signing_alg_from_string(alg);
}

export function key_encryption_alg_to_string(alg) {
  return $jose.key_encryption_alg_to_string(alg);
}

export function key_encryption_alg_from_string(alg) {
  return $jose.key_encryption_alg_from_string(alg);
}

export function content_alg_to_string(alg) {
  return $jose.content_alg_to_string(alg);
}

export function content_alg_from_string(alg) {
  return $jose.content_alg_from_string(alg);
}
