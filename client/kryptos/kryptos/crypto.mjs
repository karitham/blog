import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bytes_tree from "../../gleam_stdlib/gleam/bytes_tree.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import { Ok, Error, toBitArray } from "../gleam.mjs";
import * as $hash from "../kryptos/hash.mjs";
import * as $hmac from "../kryptos/hmac.mjs";
import * as $concat_kdf from "../kryptos/internal/concat_kdf.mjs";
import * as $hkdf from "../kryptos/internal/hkdf.mjs";
import * as $pbkdf2 from "../kryptos/internal/pbkdf2.mjs";
import * as $subtle from "../kryptos/internal/subtle.mjs";
import { randomBytes as random_bytes, randomUuid as random_uuid } from "../kryptos_ffi.mjs";

export { random_bytes, random_uuid };

/**
 * Compares two `BitArray` in constant time.
 *
 * Use this function when comparing secrets like MACs, password hashes,
 * API tokens, or any other security-sensitive data. The comparison takes
 * the same amount of time regardless of where the arrays differ, preventing
 * timing attacks.
 *
 * ## Example
 *
 * ```gleam
 * let expected_mac = compute_mac(message, key)
 * let received_mac = get_mac_from_request()
 *
 * // Safe: constant-time comparison prevents timing attacks
 * case crypto.constant_time_equal(expected_mac, received_mac) {
 *   True -> accept_message()
 *   False -> reject_message()
 * }
 * ```
 */
export const constant_time_equal = $subtle.constant_time_equal;

/**
 * Computes the hash digest of input data in one call.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/crypto
 * import kryptos/hash
 *
 * let assert Ok(digest) = crypto.hash(hash.Sha256, <<"hello":utf8>>)
 * ```
 */
export function hash(algorithm, data) {
  return $result.try$(
    $hash.new$(algorithm),
    (hasher) => {
      let _pipe = hasher;
      let _pipe$1 = $hash.update(_pipe, data);
      let _pipe$2 = $hash.final(_pipe$1);
      return new Ok(_pipe$2);
    },
  );
}

/**
 * Computes the HMAC of input data in one call.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/crypto
 * import kryptos/hash
 *
 * let assert Ok(mac) = crypto.hmac(hash.Sha256, key: <<"secret":utf8>>, data: <<"hello":utf8>>)
 * ```
 */
export function hmac(algorithm, key, data) {
  return $result.try$(
    $hmac.new$(algorithm, key),
    (hmac) => {
      let _pipe = hmac;
      let _pipe$1 = $hmac.update(_pipe, data);
      let _pipe$2 = $hmac.final(_pipe$1);
      return new Ok(_pipe$2);
    },
  );
}

/**
 * Derives key material using HKDF (RFC 5869).
 *
 * HKDF combines an extract-then-expand approach to derive cryptographically
 * strong key material from input key material. The algorithm must be
 * HMAC-compatible. Maximum output length is 255 * hash_length bytes.
 * A `None` salt uses hash-length zeros per RFC 5869.
 *
 * ## Example
 *
 * ```gleam
 * import gleam/option
 * import kryptos/crypto
 * import kryptos/hash
 *
 * let ikm = crypto.random_bytes(32)
 * let salt = option.Some(crypto.random_bytes(16))
 * let assert Ok(derived) =
 *   crypto.hkdf(hash.Sha256, input: ikm, salt:, info: <<"app":utf8>>, length: 32)
 * ```
 */
export function hkdf(algorithm, ikm, salt, info, length) {
  let hash_len = $hash.byte_size(algorithm);
  let max_length = 255 * hash_len;
  let salt_bytes = $option.lazy_unwrap(
    salt,
    () => {
      let _pipe = $list.repeat(toBitArray([0]), hash_len);
      return $bit_array.concat(_pipe);
    },
  );
  let $ = $hmac.supported_hash(algorithm);
  let $1 = length > 0;
  let $2 = length <= max_length;
  if ($ && $1 && $2) {
    return $hkdf.do_derive(algorithm, ikm, salt_bytes, info, length);
  } else {
    return new Error(undefined);
  }
}

function concat_kdf_supported_hash(algorithm) {
  if (algorithm instanceof $hash.Blake2b) {
    return false;
  } else if (algorithm instanceof $hash.Blake2s) {
    return false;
  } else if (algorithm instanceof $hash.Md5) {
    return false;
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
    return true;
  } else if (algorithm instanceof $hash.Sha3x256) {
    return true;
  } else if (algorithm instanceof $hash.Sha3x384) {
    return true;
  } else if (algorithm instanceof $hash.Sha3x512) {
    return true;
  } else if (algorithm instanceof $hash.Shake128) {
    return false;
  } else {
    return false;
  }
}

/**
 * Derives key material using Concat KDF (NIST SP 800-56A). Also called the
 * single-step or one-step key derivation function.
 *
 * Concat KDF uses a hash function to derive key material from a shared secret
 * and context-specific information. Supports SHA-1, SHA-2, and SHA-3 family
 * algorithms. Maximum output length is 255 * hash_length bytes.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/crypto
 * import kryptos/hash
 *
 * let secret = crypto.random_bytes(32)
 * let assert Ok(derived) =
 *   crypto.concat_kdf(hash.Sha256, secret:, info: <<"context":utf8>>, length: 32)
 * ```
 */
export function concat_kdf(algorithm, secret, info, length) {
  let max_length = 255 * $hash.byte_size(algorithm);
  let $ = concat_kdf_supported_hash(algorithm);
  let $1 = length > 0;
  let $2 = length <= max_length;
  if ($ && $1 && $2) {
    return $concat_kdf.derive_loop(
      algorithm,
      secret,
      info,
      length,
      1,
      $bytes_tree.new$(),
    );
  } else {
    return new Error(undefined);
  }
}

/**
 * Derives key material from a password using PBKDF2 (RFC 8018).
 *
 * PBKDF2 applies a pseudorandom function (HMAC) to derive keys from passwords.
 * It is designed to be computationally expensive to resist brute-force attacks.
 *
 * **Note:** For password hashing in production applications, consider using
 * [Argus](https://github.com/Pevensie/argus) which provides Argon2 an
 * algorithm specifically designed for password storage. PBKDF2 is primarily
 * useful for interoperability with systems that require it.
 *
 * The algorithm must be HMAC-compatible. SHA-256 or stronger is recommended;
 * MD5 and SHA-1 are weak for password hashing.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/crypto
 * import kryptos/hash
 *
 * let salt = crypto.random_bytes(16)
 * let assert Ok(derived) =
 *   crypto.pbkdf2(
 *     hash.Sha256,
 *     password: <<"hunter2":utf8>>,
 *     salt:,
 *     iterations: 100_000,
 *     length: 32,
 *   )
 * ```
 */
export function pbkdf2(algorithm, password, salt, iterations, length) {
  let $ = $hmac.supported_hash(algorithm);
  let $1 = iterations > 0;
  let $2 = length > 0;
  if ($ && $1 && $2) {
    return $pbkdf2.do_derive(algorithm, password, salt, iterations, length);
  } else {
    return new Error(undefined);
  }
}
