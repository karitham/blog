import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $set from "../../../gleam_stdlib/gleam/set.mjs";
import * as $ec from "../../../kryptos/kryptos/ec.mjs";
import * as $eddsa from "../../../kryptos/kryptos/eddsa.mjs";
import * as $xdh from "../../../kryptos/kryptos/xdh.mjs";
import { Ok, Error, bitArraySlice } from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";

/**
 * Decode a base64url-encoded string, returning a descriptive parse error on failure.
 */
export function decode_base64_url(b64, name) {
  let _pipe = $bit_array.base64_url_decode(b64);
  return $result.replace_error(
    _pipe,
    new $gose.ParseError(("invalid " + name) + " base64"),
  );
}

/**
 * Parse an EC curve from its JWK string representation.
 */
export function ec_curve_from_string(s) {
  if (s === "P-256") {
    return new Ok(new $ec.P256());
  } else if (s === "P-384") {
    return new Ok(new $ec.P384());
  } else if (s === "P-521") {
    return new Ok(new $ec.P521());
  } else if (s === "secp256k1") {
    return new Ok(new $ec.Secp256k1());
  } else {
    return new Error(new $gose.ParseError("unsupported EC curve: " + s));
  }
}

/**
 * Convert an EC curve to its JWK string representation.
 */
export function ec_curve_to_string(curve) {
  if (curve instanceof $ec.P256) {
    return "P-256";
  } else if (curve instanceof $ec.P384) {
    return "P-384";
  } else if (curve instanceof $ec.P521) {
    return "P-521";
  } else {
    return "secp256k1";
  }
}

/**
 * Parse an EdDSA curve from its JWK string representation.
 */
export function eddsa_curve_from_string(s) {
  if (s === "Ed25519") {
    return new Ok(new $eddsa.Ed25519());
  } else if (s === "Ed448") {
    return new Ok(new $eddsa.Ed448());
  } else {
    return new Error(new $gose.ParseError("unsupported EdDSA curve: " + s));
  }
}

/**
 * Convert an EdDSA curve to its JWK string representation.
 */
export function eddsa_curve_to_string(curve) {
  if (curve instanceof $eddsa.Ed25519) {
    return "Ed25519";
  } else {
    return "Ed448";
  }
}

/**
 * Encode a bit array as a base64url string without padding.
 */
export function encode_base64_url(data) {
  return $bit_array.base64_url_encode(data, false);
}

/**
 * Strip leading zero bytes from a bit array, preserving at least one byte.
 */
export function strip_leading_zeros(loop$data) {
  while (true) {
    let data = loop$data;
    if (data.bitSize >= 8 && data.byteAt(0) === 0) {
      let rest = bitArraySlice(data, 8);
      let $ = $bit_array.byte_size(rest) > 0;
      if ($) {
        loop$data = rest;
      } else {
        return data;
      }
    } else {
      return data;
    }
  }
}

/**
 * Validate a JOSE `crit` header list against supported extension rules.
 *
 * Ensures `crit` is non-empty, contains no duplicates, excludes standard
 * headers, and only includes values present in `known_extensions`.
 */
export function validate_crit_headers(
  extensions,
  standard_headers,
  known_extensions
) {
  let standard = $set.from_list(standard_headers);
  let known = $set.from_list(known_extensions);
  let crit_set = $set.from_list(extensions);
  return $bool.guard(
    $set.is_empty(crit_set),
    new Error(new $gose.ParseError("crit array must not be empty")),
    () => {
      return $bool.guard(
        $list.length(extensions) !== $set.size(crit_set),
        new Error(new $gose.ParseError("crit array contains duplicate values")),
        () => {
          return $list.try_each(
            extensions,
            (header) => {
              let $ = $set.contains(standard, header);
              let $1 = $set.contains(known, header);
              if ($) {
                return new Error(
                  new $gose.ParseError("standard header in crit: " + header),
                );
              } else if ($1) {
                return new Ok(undefined);
              } else {
                return new Error(
                  new $gose.ParseError("unsupported critical header: " + header),
                );
              }
            },
          );
        },
      );
    },
  );
}

/**
 * Parse an XDH curve from its JWK string representation.
 */
export function xdh_curve_from_string(s) {
  if (s === "X25519") {
    return new Ok(new $xdh.X25519());
  } else if (s === "X448") {
    return new Ok(new $xdh.X448());
  } else {
    return new Error(new $gose.ParseError("unsupported XDH curve: " + s));
  }
}

/**
 * Convert an XDH curve to its JWK string representation.
 */
export function xdh_curve_to_string(curve) {
  if (curve instanceof $xdh.X25519) {
    return "X25519";
  } else {
    return "X448";
  }
}
