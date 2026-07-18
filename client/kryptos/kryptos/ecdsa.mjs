import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../gleam_stdlib/gleam/bool.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import { Ok, Error, toList, makeError, bitArraySlice } from "../gleam.mjs";
import * as $ec from "../kryptos/ec.mjs";
import * as $hash from "../kryptos/hash.mjs";
import * as $der from "../kryptos/internal/der.mjs";
import * as $utils from "../kryptos/internal/utils.mjs";
import { ecdsaSign as sign, ecdsaVerify as verify } from "../kryptos_ffi.mjs";

export { sign, verify };

const FILEPATH = "src/kryptos/ecdsa.gleam";

/**
 * Converts a DER-encoded ECDSA signature to R||S format.
 *
 * R||S format concatenates the r and s integer values, each padded
 * to the curve's coordinate size with leading zeros.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/ec
 * import kryptos/ecdsa
 * import kryptos/hash
 *
 * let #(private_key, _public_key) = ec.generate_key_pair(ec.P256)
 * let der_sig = ecdsa.sign(private_key, <<"hello":utf8>>, hash.Sha256)
 * let assert Ok(rs_sig) = ecdsa.der_to_rs(der_sig, ec.P256)
 * ```
 */
export function der_to_rs(der_sig, curve) {
  let coord_size = $ec.coordinate_size(curve);
  return $result.try$(
    $der.parse_sequence(der_sig),
    (_use0) => {
      let content = _use0[0];
      let remaining = _use0[1];
      return $bool.guard(
        $bit_array.byte_size(remaining) !== 0,
        new Error(undefined),
        () => {
          return $result.try$(
            $der.parse_integer(content),
            (_use0) => {
              let r_bytes = _use0[0];
              let remaining$1 = _use0[1];
              return $result.try$(
                $der.parse_integer(remaining$1),
                (_use0) => {
                  let s_bytes = _use0[0];
                  let remaining$2 = _use0[1];
                  return $bool.guard(
                    $bit_array.byte_size(remaining$2) !== 0,
                    new Error(undefined),
                    () => {
                      let r = $utils.strip_leading_zeros(r_bytes);
                      let s = $utils.strip_leading_zeros(s_bytes);
                      let r_ok = $bit_array.byte_size(r) <= coord_size;
                      let s_ok = $bit_array.byte_size(s) <= coord_size;
                      return $bool.guard(
                        !r_ok || !s_ok,
                        new Error(undefined),
                        () => {
                          return new Ok(
                            $bit_array.concat(
                              toList([
                                $utils.pad_left(r, coord_size),
                                $utils.pad_left(s, coord_size),
                              ]),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Signs a message and returns the signature in R||S format (IEEE P1363).
 *
 * In R||S format, the signature is the concatenation of r and s values,
 * each padded to the curve's coordinate size.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/ec
 * import kryptos/ecdsa
 * import kryptos/hash
 *
 * let #(private_key, _public_key) = ec.generate_key_pair(ec.P256)
 * let signature = ecdsa.sign_rs(private_key, <<"hello":utf8>>, hash.Sha256)
 * ```
 */
export function sign_rs(private_key, message, hash) {
  let der_sig = sign(private_key, message, hash);
  let curve = $ec.curve(private_key);
  let $ = der_to_rs(der_sig, curve);
  let rs_sig;
  if ($ instanceof Ok) {
    rs_sig = $[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "kryptos/ecdsa",
      77,
      "sign_rs",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 2399,
        end: 2448,
        pattern_start: 2410,
        pattern_end: 2420
      }
    )
  }
  return rs_sig;
}

/**
 * Converts an R||S format signature to DER encoding.
 *
 * The R||S input must be exactly 2 * coordinate_size bytes.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/ec
 * import kryptos/ecdsa
 * import kryptos/hash
 *
 * let #(private_key, _public_key) = ec.generate_key_pair(ec.P256)
 * let rs_sig = ecdsa.sign_rs(private_key, <<"hello":utf8>>, hash.Sha256)
 * let assert Ok(der_sig) = ecdsa.rs_to_der(rs_sig, ec.P256)
 * ```
 */
export function rs_to_der(rs, curve) {
  let coord_size = $ec.coordinate_size(curve);
  if (
    coord_size * 8 >= 0 &&
    rs.bitSize >= coord_size * 8 &&
    rs.bitSize === coord_size * 16
  ) {
    let r = bitArraySlice(rs, 0, coord_size * 8);
    let s = bitArraySlice(rs, coord_size * 8, coord_size * 8 + coord_size * 8);
    return $result.try$(
      $der.encode_integer(r),
      (r_encoded) => {
        return $result.try$(
          $der.encode_integer(s),
          (s_encoded) => {
            return $der.encode_sequence(
              $bit_array.concat(toList([r_encoded, s_encoded])),
            );
          },
        );
      },
    );
  } else {
    return new Error(undefined);
  }
}

/**
 * Verifies an R||S format signature against a message.
 *
 * The R||S format is the concatenation of r and s values, each padded
 * to the curve's coordinate size.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/ec
 * import kryptos/ecdsa
 * import kryptos/hash
 *
 * let #(private_key, public_key) = ec.generate_key_pair(ec.P256)
 * let message = <<"hello":utf8>>
 * let signature = ecdsa.sign_rs(private_key, message, hash.Sha256)
 * let valid = ecdsa.verify_rs(public_key, message, signature, hash.Sha256)
 * // valid == True
 * ```
 */
export function verify_rs(public_key, message, signature, hash) {
  let curve = $ec.public_key_curve(public_key);
  let $ = rs_to_der(signature, curve);
  if ($ instanceof Ok) {
    let der_sig = $[0];
    return verify(public_key, message, der_sig, hash);
  } else {
    return false;
  }
}
