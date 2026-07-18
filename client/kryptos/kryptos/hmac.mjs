import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import { Ok, Error } from "../gleam.mjs";
import * as $hash from "../kryptos/hash.mjs";
import * as $subtle from "../kryptos/internal/subtle.mjs";
import { hmacNew as do_new, hmacUpdate as update, hmacFinal as final } from "../kryptos_ffi.mjs";

export { final, update };

/**
 * Checks if a hash algorithm is supported for HMAC operations.
 */
export function supported_hash(algorithm) {
  if (algorithm instanceof $hash.Blake2b) {
    return false;
  } else if (algorithm instanceof $hash.Blake2s) {
    return false;
  } else if (algorithm instanceof $hash.Md5) {
    return true;
  } else if (algorithm instanceof $hash.Sha1) {
    return true;
  } else if (algorithm instanceof $hash.Sha256) {
    return true;
  } else if (algorithm instanceof $hash.Sha384) {
    return true;
  } else if (algorithm instanceof $hash.Sha512) {
    return true;
  } else if (algorithm instanceof $hash.Sha512x224) {
    return true;
  } else if (algorithm instanceof $hash.Sha512x256) {
    return true;
  } else if (algorithm instanceof $hash.Sha3x224) {
    return false;
  } else if (algorithm instanceof $hash.Sha3x256) {
    return false;
  } else if (algorithm instanceof $hash.Sha3x384) {
    return false;
  } else if (algorithm instanceof $hash.Sha3x512) {
    return false;
  } else if (algorithm instanceof $hash.Shake128) {
    return false;
  } else {
    return false;
  }
}

/**
 * Creates a new HMAC for incremental authentication.
 *
 * Use this when you need to authenticate data in chunks, such as when streaming
 * or when the full input isn't available at once.
 */
export function new$(algorithm, key) {
  let $ = supported_hash(algorithm);
  if ($) {
    return do_new(algorithm, key);
  } else {
    return new Error(undefined);
  }
}

/**
 * Verifies that a MAC matches the expected value using constant-time comparison.
 *
 * Computes the HMAC and compares it to the expected value in constant time
 * to prevent timing attacks.
 */
export function verify(algorithm, key, data, expected) {
  return $result.try$(
    new$(algorithm, key),
    (hmac_state) => {
      let _block;
      let _pipe = hmac_state;
      let _pipe$1 = update(_pipe, data);
      _block = final(_pipe$1);
      let actual = _block;
      return new Ok($subtle.constant_time_equal(actual, expected));
    },
  );
}
