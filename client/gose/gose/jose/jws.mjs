import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $dict from "../../../gleam_stdlib/gleam/dict.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $set from "../../../gleam_stdlib/gleam/set.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  prepend as listPrepend,
  CustomType as $CustomType,
  makeError,
  isEqual,
  toBitArray,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $signing from "../../gose/internal/signing.mjs";
import * as $utils from "../../gose/internal/utils.mjs";
import * as $jose from "../../gose/jose.mjs";

const FILEPATH = "src/gose/jose/jws.gleam";

class JwsHeader extends $CustomType {
  constructor(alg, kid, typ, cty, custom) {
    super();
    this.alg = alg;
    this.kid = kid;
    this.typ = typ;
    this.cty = cty;
    this.custom = custom;
  }
}

class ParsedHeader extends $CustomType {
  constructor(header, unencoded_payload, header_raw, custom_keys) {
    super();
    this.header = header;
    this.unencoded_payload = unencoded_payload;
    this.header_raw = header_raw;
    this.custom_keys = custom_keys;
  }
}

class UnsignedJws extends $CustomType {
  constructor(header, payload, detached, unencoded_payload, unprotected) {
    super();
    this.header = header;
    this.payload = payload;
    this.detached = detached;
    this.unencoded_payload = unencoded_payload;
    this.unprotected = unprotected;
  }
}

class SignedJws extends $CustomType {
  constructor(header, header_raw, payload, detached, unencoded_payload, protected_b64, payload_segment, signature, unprotected, unprotected_raw) {
    super();
    this.header = header;
    this.header_raw = header_raw;
    this.payload = payload;
    this.detached = detached;
    this.unencoded_payload = unencoded_payload;
    this.protected_b64 = protected_b64;
    this.payload_segment = payload_segment;
    this.signature = signature;
    this.unprotected = unprotected;
    this.unprotected_raw = unprotected_raw;
  }
}

class Verifier extends $CustomType {
  constructor(alg, keys) {
    super();
    this.alg = alg;
    this.keys = keys;
  }
}

const reserved_header_names = /* @__PURE__ */ toList([
  "alg",
  "kid",
  "typ",
  "cty",
  "crit",
  "b64",
]);

const protected_only_headers = /* @__PURE__ */ toList(["crit", "b64"]);

/**
 * Known extensions that we support
 * 
 * @ignore
 */
const known_extensions = /* @__PURE__ */ toList(["b64"]);

/**
 * Standard JWS header parameters that must not appear in crit (RFC 7515 Section 4.1)
 * 
 * @ignore
 */
const standard_headers = /* @__PURE__ */ toList([
  "alg",
  "jku",
  "jwk",
  "kid",
  "x5u",
  "x5c",
  "x5t",
  "x5t#S256",
  "typ",
  "cty",
  "crit",
]);

/**
 * Create a new unsigned JWS with the specified signing algorithm. The payload
 * is provided at sign time via `sign`.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(signed) = jws.new(gose.Mac(gose.Hmac(gose.HmacSha256)))
 *   |> jws.sign(key, <<"hello":utf8>>)
 * ```
 */
export function new$(alg) {
  return new UnsignedJws(
    new JwsHeader(
      alg,
      new $option.None(),
      new $option.None(),
      new $option.None(),
      $dict.new$(),
    ),
    toBitArray([]),
    false,
    false,
    $dict.new$(),
  );
}

/**
 * Create a verifier for JWS signature verification.
 *
 * Accepts one or more keys for key rotation scenarios. The verifier pins
 * the expected algorithm and will reject tokens with different algorithms.
 *
 * Key selection during verification:
 * 1. If the JWS has a `kid` header, prioritize keys with matching kid
 * 2. Try keys in order until one succeeds
 * 3. Fail if no key verifies the signature
 */
export function verifier(alg, keys) {
  return $key_helpers.require_non_empty_keys(
    keys,
    () => {
      return $result.try$(
        $list.try_each(
          keys,
          (_capture) => {
            return $key_helpers.validate_key_for_signing_verification(
              alg,
              _capture,
            );
          },
        ),
        (_) => { return new Ok(new Verifier(alg, keys)); },
      );
    },
  );
}

function map_unsigned_header(jws, f) {
  let header;
  let payload$1;
  let detached;
  let unencoded_payload;
  let unprotected;
  if (jws instanceof UnsignedJws) {
    header = jws.header;
    payload$1 = jws.payload;
    detached = jws.detached;
    unencoded_payload = jws.unencoded_payload;
    unprotected = jws.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      385,
      "map_unsigned_header",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 12584,
        end: 12701,
        pattern_start: 12595,
        pattern_end: 12695
      }
    )
  }
  return new UnsignedJws(
    f(header),
    payload$1,
    detached,
    unencoded_payload,
    unprotected,
  );
}

/**
 * Set the content type (cty) header parameter.
 */
export function with_cty(jws, cty) {
  return map_unsigned_header(
    jws,
    (h) => {
      return new JwsHeader(h.alg, h.kid, h.typ, new $option.Some(cty), h.custom);
    },
  );
}

/**
 * Mark this JWS as using a detached payload.
 *
 * The payload will not be included in the serialized output, but is still
 * provided at sign time and used for signature computation.
 */
export function with_detached(jws) {
  let header;
  let payload$1;
  let unencoded_payload;
  let unprotected;
  if (jws instanceof UnsignedJws) {
    header = jws.header;
    payload$1 = jws.payload;
    unencoded_payload = jws.unencoded_payload;
    unprotected = jws.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      275,
      "with_detached",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 9264,
        end: 9374,
        pattern_start: 9275,
        pattern_end: 9368
      }
    )
  }
  return new UnsignedJws(
    header,
    payload$1,
    true,
    unencoded_payload,
    unprotected,
  );
}

/**
 * Add a custom protected header field.
 *
 * Custom headers are sorted alphabetically by name and appear after standard fields (alg, kid, typ, cty).
 * Returns an error if the name is a reserved header (`alg`, `kid`, `typ`, `cty`,
 * `crit`, `b64`) to prevent security issues like algorithm confusion.
 *
 * If the same header name is set multiple times, the last value wins.
 */
export function with_header(jws, name, value) {
  return $bool.guard(
    $list.contains(reserved_header_names, name),
    new Error(
      new $gose.InvalidState(
        "cannot set reserved header via with_header: " + name,
      ),
    ),
    () => {
      return new Ok(
        map_unsigned_header(
          jws,
          (h) => {
            return new JwsHeader(
              h.alg,
              h.kid,
              h.typ,
              h.cty,
              $dict.insert(h.custom, name, value),
            );
          },
        ),
      );
    },
  );
}

/**
 * Set the key ID (kid) header parameter.
 */
export function with_kid(jws, kid) {
  return map_unsigned_header(
    jws,
    (h) => {
      return new JwsHeader(h.alg, new $option.Some(kid), h.typ, h.cty, h.custom);
    },
  );
}

/**
 * Set the type (typ) header parameter (e.g., "JWT").
 */
export function with_typ(jws, typ) {
  return map_unsigned_header(
    jws,
    (h) => {
      return new JwsHeader(h.alg, h.kid, new $option.Some(typ), h.cty, h.custom);
    },
  );
}

/**
 * Mark this JWS as using an unencoded payload (RFC 7797, b64=false).
 *
 * The payload will be included directly in the serialized output without
 * base64 encoding. The header will include `"crit":["b64"],"b64":false`.
 * The payload is still provided at sign time.
 */
export function with_unencoded(jws) {
  let header;
  let payload$1;
  let detached;
  let unprotected;
  if (jws instanceof UnsignedJws) {
    header = jws.header;
    payload$1 = jws.payload;
    detached = jws.detached;
    unprotected = jws.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      332,
      "with_unencoded",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 11097,
        end: 11173,
        pattern_start: 11108,
        pattern_end: 11167
      }
    )
  }
  return new UnsignedJws(header, payload$1, detached, true, unprotected);
}

/**
 * Add an unprotected header field (for JSON serialization only).
 *
 * **Security Warning:** Unprotected headers are NOT integrity protected.
 * They can be modified by an attacker without invalidating the signature.
 * Only use for non-security-critical metadata.
 *
 * Returns an error if the name is a protected-only header (`crit`, `b64`) which
 * MUST be integrity protected per RFC 7515/7797.
 *
 * Compact serialization will return an error if unprotected headers are present.
 *
 * If the same header name is set multiple times, the last value wins.
 */
export function with_unprotected(jws, name, value) {
  return $bool.guard(
    $list.contains(protected_only_headers, name),
    new Error(
      new $gose.InvalidState(
        "protected-only header cannot be in unprotected: " + name,
      ),
    ),
    () => {
      let header;
      let payload$1;
      let detached;
      let unencoded_payload;
      let unprotected;
      if (jws instanceof UnsignedJws) {
        header = jws.header;
        payload$1 = jws.payload;
        detached = jws.detached;
        unencoded_payload = jws.unencoded_payload;
        unprotected = jws.unprotected;
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jws",
          365,
          "with_unprotected",
          "Pattern match failed, no pattern matched the value.",
          {
            value: jws,
            start: 12202,
            end: 12319,
            pattern_start: 12213,
            pattern_end: 12313
          }
        )
      }
      return new Ok(
        new UnsignedJws(
          header,
          payload$1,
          detached,
          unencoded_payload,
          $dict.insert(unprotected, name, value),
        ),
      );
    },
  );
}

/**
 * Get the algorithm (`alg`) from a JWS.
 */
export function alg(jws) {
  return jws.header.alg;
}

/**
 * Get the content type (cty) from a JWS header.
 */
export function cty(jws) {
  return $option.to_result(jws.header.cty, undefined);
}

/**
 * Decode custom headers from a parsed JWS using a custom decoder.
 *
 * This allows reading non-standard header fields that were present during parsing.
 * For JWS built via `new`, you already know what headers you set.
 */
export function decode_custom_headers(jws, decoder) {
  let header_raw;
  if (jws instanceof SignedJws) {
    header_raw = jws.header_raw;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      419,
      "decode_custom_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 13439,
        end: 13482,
        pattern_start: 13450,
        pattern_end: 13476
      }
    )
  }
  if (header_raw instanceof $option.Some) {
    let raw = header_raw[0];
    let _pipe = $decode.run(raw, decoder);
    return $result.replace_error(
      _pipe,
      new $gose.ParseError("failed to decode custom headers"),
    );
  } else {
    return new Error(new $gose.ParseError("no header data available"));
  }
}

/**
 * Decode the unprotected header using a custom decoder.
 *
 * **Security Warning:** Unprotected headers are NOT integrity protected.
 * They can be modified by an attacker without invalidating the signature.
 * Only use for non-security-critical metadata.
 *
 * This function only works on parsed JWS instances. When building a JWS,
 * you already know what unprotected headers you set - use `has_unprotected_header`
 * to check their presence.
 */
export function decode_unprotected_header(jws, decoder) {
  let unprotected_raw;
  if (jws instanceof SignedJws) {
    unprotected_raw = jws.unprotected_raw;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      441,
      "decode_unprotected_header",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 14299,
        end: 14347,
        pattern_start: 14310,
        pattern_end: 14341
      }
    )
  }
  if (unprotected_raw instanceof $option.Some) {
    let raw = unprotected_raw[0];
    let _pipe = $decode.run(raw, decoder);
    return $result.replace_error(
      _pipe,
      new $gose.ParseError("failed to decode unprotected header"),
    );
  } else {
    return new Error(new $gose.ParseError("no unprotected headers present"));
  }
}

/**
 * Check if the JWS has unprotected headers.
 *
 * Returns True if the JWS was parsed from JSON with unprotected headers,
 * or if unprotected headers were added via `with_unprotected`.
 */
export function has_unprotected_header(jws) {
  let unprotected;
  let unprotected_raw;
  if (jws instanceof SignedJws) {
    unprotected = jws.unprotected;
    unprotected_raw = jws.unprotected_raw;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      457,
      "has_unprotected_header",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 14872,
        end: 14934,
        pattern_start: 14883,
        pattern_end: 14928
      }
    )
  }
  return $option.is_some(unprotected_raw) || !$dict.is_empty(unprotected);
}

/**
 * Check if the JWS has a detached payload.
 */
export function is_detached(jws) {
  if (jws instanceof UnsignedJws) {
    let detached = jws.detached;
    return detached;
  } else {
    let detached = jws.detached;
    return detached;
  }
}

/**
 * Check if the JWS uses an unencoded payload (b64=false per RFC 7797).
 */
export function has_unencoded_payload(jws) {
  if (jws instanceof UnsignedJws) {
    let unencoded_payload = jws.unencoded_payload;
    return unencoded_payload;
  } else {
    let unencoded_payload = jws.unencoded_payload;
    return unencoded_payload;
  }
}

/**
 * Get the key ID (kid) from a JWS header.
 *
 * **Security Warning:** The `kid` value comes from the token and is untrusted
 * input. If you use it to look up keys (from a database, filesystem, or key
 * store), you must sanitize it first to prevent injection attacks:
 * - Use parameterized queries for database lookups
 * - Validate the format matches your expected key ID pattern
 * - Never use it directly in file paths or shell commands
 */
export function kid(jws) {
  return $option.to_result(jws.header.kid, undefined);
}

/**
 * Get the payload from a JWS.
 */
export function payload(jws) {
  if (jws instanceof UnsignedJws) {
    let payload$1 = jws.payload;
    return payload$1;
  } else {
    let payload$1 = jws.payload;
    return payload$1;
  }
}

/**
 * Get the type (typ) from a JWS header.
 */
export function typ(jws) {
  return $option.to_result(jws.header.typ, undefined);
}

function encode_payload_segment(payload, unencoded) {
  if (unencoded) {
    return $bit_array.to_string(payload);
  } else {
    return new Ok($utils.encode_base64_url(payload));
  }
}

function header_to_json(header, unencoded_payload) {
  let alg_field = ["alg", $json.string($jose.signing_alg_to_string(header.alg))];
  let optional_fields = $option.values(
    toList([
      $option.map(header.kid, (k) => { return ["kid", $json.string(k)]; }),
      $option.map(header.typ, (t) => { return ["typ", $json.string(t)]; }),
      $option.map(header.cty, (c) => { return ["cty", $json.string(c)]; }),
    ]),
  );
  let _block;
  if (unencoded_payload) {
    _block = toList([
      ["b64", $json.bool(false)],
      ["crit", $json.array(toList(["b64"]), $json.string)],
    ]);
  } else {
    _block = toList([]);
  }
  let b64_fields = _block;
  let _block$1;
  let _pipe = header.custom;
  let _pipe$1 = $dict.to_list(_pipe);
  _block$1 = $list.sort(
    _pipe$1,
    (a, b) => { return $string.compare(a[0], b[0]); },
  );
  let custom_sorted = _block$1;
  let _block$2;
  let _pipe$2 = listPrepend(alg_field, optional_fields);
  let _pipe$3 = $list.append(_pipe$2, b64_fields);
  _block$2 = $list.append(_pipe$3, custom_sorted);
  let fields = _block$2;
  let _pipe$4 = $json.object(fields);
  let _pipe$5 = $json.to_string(_pipe$4);
  return $bit_array.from_string(_pipe$5);
}

/**
 * Sign an unsigned JWS with the provided key.
 *
 * JWK metadata (`use`, `key_ops`) is enforced when present:
 * - Keys with `use=enc` are rejected
 * - Keys with `key_ops` that don't include `sign` are rejected
 */
export function sign(jws, key, payload) {
  let header;
  let detached;
  let unencoded_payload;
  let unprotected;
  if (jws instanceof UnsignedJws) {
    header = jws.header;
    detached = jws.detached;
    unencoded_payload = jws.unencoded_payload;
    unprotected = jws.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      512,
      "sign",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 16740,
        end: 16851,
        pattern_start: 16751,
        pattern_end: 16845
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_signing_key_type(header.alg, key),
    (_) => {
      return $result.try$(
        $key_helpers.validate_key_use(key, new $key_helpers.ForSigning()),
        (_) => {
          return $result.try$(
            $key_helpers.validate_key_ops(key, new $key_helpers.ForSigning()),
            (_) => {
              return $result.try$(
                $key_helpers.validate_key_algorithm_signing(key, header.alg),
                (_) => {
                  let protected_json = header_to_json(header, unencoded_payload);
                  let protected_b64 = $utils.encode_base64_url(protected_json);
                  return $result.try$(
                    (() => {
                      let _pipe = encode_payload_segment(
                        payload,
                        unencoded_payload,
                      );
                      return $result.replace_error(
                        _pipe,
                        new $gose.InvalidState(
                          "unencoded payload must be valid UTF-8",
                        ),
                      );
                    })(),
                    (payload_segment) => {
                      let signing_input = (protected_b64 + ".") + payload_segment;
                      return $result.try$(
                        $signing.compute_signature(
                          header.alg,
                          key,
                          $bit_array.from_string(signing_input),
                        ),
                        (signature) => {
                          return new Ok(
                            new SignedJws(
                              header,
                              new $option.None(),
                              payload,
                              detached,
                              unencoded_payload,
                              protected_b64,
                              payload_segment,
                              signature,
                              unprotected,
                              new $option.None(),
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

function do_verify(jws, key) {
  let header;
  let detached;
  let protected_b64;
  let payload_segment;
  let signature;
  if (jws instanceof SignedJws) {
    header = jws.header;
    detached = jws.detached;
    protected_b64 = jws.protected_b64;
    payload_segment = jws.payload_segment;
    signature = jws.signature;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      563,
      "do_verify",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 18056,
        end: 18181,
        pattern_start: 18067,
        pattern_end: 18175
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_key_use(key, new $key_helpers.ForVerification()),
    (_) => {
      return $result.try$(
        $key_helpers.validate_key_ops(key, new $key_helpers.ForVerification()),
        (_) => {
          return $result.try$(
            $key_helpers.validate_key_algorithm_signing(key, header.alg),
            (_) => {
              return $bool.guard(
                detached,
                new Error(
                  new $gose.InvalidState(
                    "Cannot verify detached JWS without payload. Use verify_detached instead.",
                  ),
                ),
                () => {
                  let signing_input = (protected_b64 + ".") + payload_segment;
                  return $signing.verify_signature(
                    header.alg,
                    key,
                    $bit_array.from_string(signing_input),
                    signature,
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

function do_verify_with_payload(jws, payload, key) {
  let header;
  let unencoded_payload;
  let protected_b64;
  let signature;
  if (jws instanceof SignedJws) {
    header = jws.header;
    unencoded_payload = jws.unencoded_payload;
    protected_b64 = jws.protected_b64;
    signature = jws.signature;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      606,
      "do_verify_with_payload",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 18983,
        end: 19095,
        pattern_start: 18994,
        pattern_end: 19089
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_key_use(key, new $key_helpers.ForVerification()),
    (_) => {
      return $result.try$(
        $key_helpers.validate_key_ops(key, new $key_helpers.ForVerification()),
        (_) => {
          return $result.try$(
            $key_helpers.validate_key_algorithm_signing(key, header.alg),
            (_) => {
              return $result.try$(
                (() => {
                  let _pipe = encode_payload_segment(payload, unencoded_payload);
                  return $result.replace_error(
                    _pipe,
                    new $gose.InvalidState(
                      "unencoded payload must be valid UTF-8",
                    ),
                  );
                })(),
                (payload_segment) => {
                  let signing_input = (protected_b64 + ".") + payload_segment;
                  return $signing.verify_signature(
                    header.alg,
                    key,
                    $bit_array.from_string(signing_input),
                    signature,
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

function decode_payload_segment(segment, unencoded) {
  if (unencoded) {
    return new Ok($bit_array.from_string(segment));
  } else {
    return $utils.decode_base64_url(segment, "payload");
  }
}

function validate_crit(crit, b64) {
  return $result.try$(
    $utils.validate_crit_headers(crit, standard_headers, known_extensions),
    (_) => {
      let crit_set = $set.from_list(crit);
      let $ = $set.contains(crit_set, "b64") && $option.is_none(b64);
      if ($) {
        return new Error(
          new $gose.ParseError("b64 listed in crit but not present in header"),
        );
      } else {
        return new Ok(undefined);
      }
    },
  );
}

function validate_optional_crit(crit, b64) {
  if (crit instanceof $option.Some) {
    let crit_list = crit[0];
    return validate_crit(crit_list, b64);
  } else {
    return new Ok(undefined);
  }
}

function try_verify_keys(loop$jws, loop$keys) {
  while (true) {
    let jws = loop$jws;
    let keys = loop$keys;
    if (keys instanceof $Empty) {
      return new Error(new $gose.VerificationFailed());
    } else {
      let key = keys.head;
      let rest = keys.tail;
      let $ = do_verify(jws, key);
      if ($ instanceof Ok) {
        return $;
      } else {
        let $1 = $[0];
        if ($1 instanceof $gose.VerificationFailed) {
          loop$jws = jws;
          loop$keys = rest;
        } else {
          return $;
        }
      }
    }
  }
}

/**
 * Verify a JWS signature using the verifier.
 *
 * Checks:
 * 1. Token's `alg` header matches the verifier's expected algorithm
 * 2. Signature is valid for one of the verifier's keys
 *
 * When multiple keys are configured, keys with matching `kid` are tried first.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(v) =
 *   jws.verifier(gose.Mac(gose.Hmac(gose.HmacSha256)), [key])
 * let assert Ok(parsed) = jws.parse_compact(token)
 * let assert Ok(Nil) = jws.verify(v, parsed)
 * ```
 */
export function verify(verifier, jws) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  return $result.try$(
    $key_helpers.require_matching_signing_algorithm(expected_alg, alg(jws)),
    (_) => {
      let jws_kid = $option.from_result(kid(jws));
      let ordered_keys = $key_helpers.order_keys_by_kid(keys, jws_kid);
      return try_verify_keys(jws, ordered_keys);
    },
  );
}

function try_verify_detached_keys(loop$jws, loop$payload, loop$keys) {
  while (true) {
    let jws = loop$jws;
    let payload = loop$payload;
    let keys = loop$keys;
    if (keys instanceof $Empty) {
      return new Error(new $gose.VerificationFailed());
    } else {
      let key = keys.head;
      let rest = keys.tail;
      let $ = do_verify_with_payload(jws, payload, key);
      if ($ instanceof Ok) {
        return $;
      } else {
        let $1 = $[0];
        if ($1 instanceof $gose.VerificationFailed) {
          loop$jws = jws;
          loop$payload = payload;
          loop$keys = rest;
        } else {
          return $;
        }
      }
    }
  }
}

/**
 * Verify a JWS with a detached payload using the verifier.
 *
 * Use this when the payload was not included in the serialized JWS.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(v) =
 *   jws.verifier(gose.Mac(gose.Hmac(gose.HmacSha256)), [key])
 * let assert Ok(parsed) = jws.parse_compact(detached_token)
 * let assert Ok(Nil) = jws.verify_detached(v, parsed, payload)
 * ```
 */
export function verify_detached(verifier, jws, payload) {
  return $bool.guard(
    !is_detached(jws),
    new Error(
      new $gose.InvalidState("JWS payload is not detached; use verify instead"),
    ),
    () => {
      let expected_alg = verifier.alg;
      let keys = verifier.keys;
      return $result.try$(
        $key_helpers.require_matching_signing_algorithm(expected_alg, alg(jws)),
        (_) => {
          let jws_kid = $option.from_result(kid(jws));
          let ordered_keys = $key_helpers.order_keys_by_kid(keys, jws_kid);
          return try_verify_detached_keys(jws, payload, ordered_keys);
        },
      );
    },
  );
}

function parse_header_json(json_bits) {
  let standard_decoder = $decode.field(
    "alg",
    $decode.string,
    (alg) => {
      return $decode.optional_field(
        "kid",
        new $option.None(),
        $decode.optional($decode.string),
        (kid) => {
          return $decode.optional_field(
            "typ",
            new $option.None(),
            $decode.optional($decode.string),
            (typ) => {
              return $decode.optional_field(
                "cty",
                new $option.None(),
                $decode.optional($decode.string),
                (cty) => {
                  return $decode.optional_field(
                    "crit",
                    new $option.None(),
                    $decode.optional($decode.list($decode.string)),
                    (crit) => {
                      return $decode.optional_field(
                        "b64",
                        new $option.None(),
                        $decode.optional($decode.bool),
                        (b64) => {
                          return $decode.success(
                            [alg, kid, typ, cty, crit, b64],
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
  return $result.try$(
    (() => {
      let _pipe = $json.parse_bits(json_bits, $decode.dynamic);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("invalid header JSON"),
      );
    })(),
    (raw_dynamic) => {
      return $result.try$(
        (() => {
          let _pipe = $decode.run(raw_dynamic, standard_decoder);
          return $result.replace_error(
            _pipe,
            new $gose.ParseError("invalid header JSON"),
          );
        })(),
        (_use0) => {
          let alg_str = _use0[0];
          let kid$1 = _use0[1];
          let typ$1 = _use0[2];
          let cty$1 = _use0[3];
          let crit = _use0[4];
          let b64 = _use0[5];
          return $result.try$(
            validate_optional_crit(crit, b64),
            (_) => {
              let _block;
              let _pipe = $option.map(
                crit,
                (_capture) => { return $list.contains(_capture, "b64"); },
              );
              _block = $option.unwrap(_pipe, false);
              let b64_in_crit = _block;
              return $bool.guard(
                $option.is_some(b64) && !b64_in_crit,
                new Error(
                  new $gose.ParseError("b64 header present but not in crit"),
                ),
                () => {
                  return $result.try$(
                    $jose.signing_alg_from_string(alg_str),
                    (alg) => {
                      let unencoded_payload = isEqual(
                        b64,
                        new $option.Some(false)
                      );
                      return $result.try$(
                        (() => {
                          let _pipe$1 = $decode.run(
                            raw_dynamic,
                            $decode.dict($decode.string, $decode.dynamic),
                          );
                          return $result.replace_error(
                            _pipe$1,
                            new $gose.ParseError("invalid header JSON"),
                          );
                        })(),
                        (all_keys) => {
                          let _block$1;
                          let _pipe$1 = $dict.keys(all_keys);
                          let _pipe$2 = $list.filter(
                            _pipe$1,
                            (k) => {
                              return !$list.contains(reserved_header_names, k);
                            },
                          );
                          _block$1 = $set.from_list(_pipe$2);
                          let custom_keys = _block$1;
                          return new Ok(
                            new ParsedHeader(
                              new JwsHeader(
                                alg,
                                kid$1,
                                typ$1,
                                cty$1,
                                $dict.new$(),
                              ),
                              unencoded_payload,
                              new $option.Some(raw_dynamic),
                              custom_keys,
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

function parse_protected_header(b64) {
  return $result.try$(
    $utils.decode_base64_url(b64, "header"),
    (header_bits) => { return parse_header_json(header_bits); },
  );
}

function build_signed_jws(protected_b64, payload_segment, sig_b64, detached) {
  return $result.try$(
    parse_protected_header(protected_b64),
    (_use0) => {
      let header = _use0.header;
      let unencoded_payload = _use0.unencoded_payload;
      let header_raw = _use0.header_raw;
      return $result.try$(
        $utils.decode_base64_url(sig_b64, "signature"),
        (signature) => {
          return $result.try$(
            decode_payload_segment(payload_segment, unencoded_payload),
            (payload) => {
              return new Ok(
                new SignedJws(
                  header,
                  header_raw,
                  payload,
                  detached,
                  unencoded_payload,
                  protected_b64,
                  payload_segment,
                  signature,
                  $dict.new$(),
                  new $option.None(),
                ),
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Parse a JWS from compact format.
 *
 * Returns a signed JWS that can be verified with a `Verifier`.
 * An empty payload segment (`header..signature`) is treated as a detached
 * payload; use `verify_detached` to verify with the out-of-band payload.
 */
export function parse_compact(token) {
  let $ = $string.split(token, ".");
  if ($ instanceof $Empty) {
    return new Error(
      new $gose.ParseError("invalid compact serialization: expected 3 parts"),
    );
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      return new Error(
        new $gose.ParseError("invalid compact serialization: expected 3 parts"),
      );
    } else {
      let $2 = $1.tail;
      if ($2 instanceof $Empty) {
        return new Error(
          new $gose.ParseError(
            "invalid compact serialization: expected 3 parts",
          ),
        );
      } else {
        let $3 = $2.tail;
        if ($3 instanceof $Empty) {
          let protected_b64 = $.head;
          let payload_b64 = $1.head;
          let sig_b64 = $2.head;
          let detached = payload_b64 === "";
          return build_signed_jws(protected_b64, payload_b64, sig_b64, detached);
        } else {
          return new Error(
            new $gose.ParseError(
              "invalid compact serialization: expected 3 parts",
            ),
          );
        }
      }
    }
  }
}

/**
 * Serialize a signed JWS to compact format.
 *
 * Format: `{base64url(header)}.{base64url(payload)}.{base64url(signature)}`
 *
 * For detached payloads: `{base64url(header)}..{base64url(signature)}`
 *
 * For unencoded payloads (b64=false): `{base64url(header)}.{payload}.{base64url(signature)}`
 *
 * Returns an error if the payload contains `.` characters when using b64=false,
 * as this would create an invalid compact serialization (RFC 7797).
 * Use JSON serialization instead for payloads containing periods.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(token) = jws.serialize_compact(signed)
 * ```
 */
export function serialize_compact(jws) {
  let detached;
  let unencoded_payload;
  let protected_b64;
  let payload_segment;
  let signature;
  let unprotected;
  if (jws instanceof SignedJws) {
    detached = jws.detached;
    unencoded_payload = jws.unencoded_payload;
    protected_b64 = jws.protected_b64;
    payload_segment = jws.payload_segment;
    signature = jws.signature;
    unprotected = jws.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      839,
      "serialize_compact",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 25450,
        end: 25604,
        pattern_start: 25461,
        pattern_end: 25598
      }
    )
  }
  return $bool.guard(
    !$dict.is_empty(unprotected),
    new Error(
      new $gose.InvalidState(
        "cannot serialize to compact format: unprotected headers are only supported in JSON serialization",
      ),
    ),
    () => {
      return $bool.guard(
        (unencoded_payload && !detached) && $string.contains(
          payload_segment,
          ".",
        ),
        new Error(
          new $gose.InvalidState(
            "unencoded payload cannot contain '.' for compact serialization",
          ),
        ),
        () => {
          let sig_b64 = $utils.encode_base64_url(signature);
          if (detached) {
            return new Ok((protected_b64 + "..") + sig_b64);
          } else {
            return new Ok(
              (((protected_b64 + ".") + payload_segment) + ".") + sig_b64,
            );
          }
        },
      );
    },
  );
}

/**
 * Serialize a signed JWS to JSON Flattened format.
 *
 * Format: `{"payload":"...","protected":"...","signature":"..."}`
 *
 * For detached payloads, the payload field is omitted.
 * If unprotected headers are present, includes the `header` field.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(signed) =
 *   jws.new(gose.Mac(gose.Hmac(gose.HmacSha256)))
 *   |> jws.sign(key, payload)
 * let json_str =
 *   jws.serialize_json_flattened(signed)
 *   |> json.to_string
 * ```
 */
export function serialize_json_flattened(jws) {
  let detached;
  let protected_b64;
  let payload_segment;
  let signature;
  let unprotected;
  if (jws instanceof SignedJws) {
    detached = jws.detached;
    protected_b64 = jws.protected_b64;
    payload_segment = jws.payload_segment;
    signature = jws.signature;
    unprotected = jws.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      890,
      "serialize_json_flattened",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 26831,
        end: 26961,
        pattern_start: 26842,
        pattern_end: 26955
      }
    )
  }
  let sig_b64 = $utils.encode_base64_url(signature);
  let _block;
  if (detached) {
    _block = toList([
      ["protected", $json.string(protected_b64)],
      ["signature", $json.string(sig_b64)],
    ]);
  } else {
    _block = toList([
      ["payload", $json.string(payload_segment)],
      ["protected", $json.string(protected_b64)],
      ["signature", $json.string(sig_b64)],
    ]);
  }
  let base_fields = _block;
  let _block$1;
  let $ = $dict.is_empty(unprotected);
  if ($) {
    _block$1 = base_fields;
  } else {
    let header_obj = $json.object($dict.to_list(unprotected));
    _block$1 = listPrepend(["header", header_obj], base_fields);
  }
  let fields = _block$1;
  return $json.object(fields);
}

/**
 * Serialize a signed JWS to JSON General format.
 *
 * Format: `{"payload":"...","signatures":[{"protected":"...","signature":"..."}]}`
 *
 * For detached payloads, the payload field is omitted.
 * If unprotected headers are present, includes the `header` field in the signature entry.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(signed) =
 *   jws.new(gose.Mac(gose.Hmac(gose.HmacSha256)))
 *   |> jws.sign(key, payload)
 * let json_str =
 *   jws.serialize_json_general(signed)
 *   |> json.to_string
 * ```
 */
export function serialize_json_general(jws) {
  let detached;
  let protected_b64;
  let payload_segment;
  let signature;
  let unprotected;
  if (jws instanceof SignedJws) {
    detached = jws.detached;
    protected_b64 = jws.protected_b64;
    payload_segment = jws.payload_segment;
    signature = jws.signature;
    unprotected = jws.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jws",
      941,
      "serialize_json_general",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jws,
        start: 28172,
        end: 28302,
        pattern_start: 28183,
        pattern_end: 28296
      }
    )
  }
  let sig_b64 = $utils.encode_base64_url(signature);
  let sig_base_fields = toList([
    ["protected", $json.string(protected_b64)],
    ["signature", $json.string(sig_b64)],
  ]);
  let _block;
  let $ = $dict.is_empty(unprotected);
  if ($) {
    _block = sig_base_fields;
  } else {
    let header_obj = $json.object($dict.to_list(unprotected));
    _block = listPrepend(["header", header_obj], sig_base_fields);
  }
  let sig_fields = _block;
  let sig_obj = $json.object(sig_fields);
  let _block$1;
  if (detached) {
    _block$1 = toList([
      ["signatures", $json.preprocessed_array(toList([sig_obj]))],
    ]);
  } else {
    _block$1 = toList([
      ["payload", $json.string(payload_segment)],
      ["signatures", $json.preprocessed_array(toList([sig_obj]))],
    ]);
  }
  let fields = _block$1;
  return $json.object(fields);
}

function build_signed_jws_json(
  header,
  header_raw,
  protected_b64,
  signature,
  payload_opt,
  unencoded_payload,
  unprotected,
  unprotected_raw
) {
  let _block;
  if (payload_opt instanceof $option.Some) {
    let p = payload_opt[0];
    _block = [p, false];
  } else {
    _block = ["", true];
  }
  let $ = _block;
  let payload_b64 = $[0];
  let detached = $[1];
  return $result.try$(
    decode_payload_segment(payload_b64, unencoded_payload),
    (payload) => {
      return new Ok(
        new SignedJws(
          header,
          header_raw,
          payload,
          detached,
          unencoded_payload,
          protected_b64,
          payload_b64,
          signature,
          unprotected,
          unprotected_raw,
        ),
      );
    },
  );
}

/**
 * Validate that unprotected header names don't overlap with protected header names.
 * 
 * @ignore
 */
function validate_header_disjointness(
  protected$,
  protected_custom_keys,
  unprotected_names
) {
  let optional_headers = $option.values(
    toList([
      $option.map(protected$.kid, (_) => { return "kid"; }),
      $option.map(protected$.typ, (_) => { return "typ"; }),
      $option.map(protected$.cty, (_) => { return "cty"; }),
    ]),
  );
  let _block;
  let _pipe = $set.from_list(listPrepend("alg", optional_headers));
  _block = $set.union(_pipe, protected_custom_keys);
  let protected_set = _block;
  let unprotected_set = $set.from_list(unprotected_names);
  let overlap = $set.intersection(protected_set, unprotected_set);
  let $ = $set.is_empty(overlap);
  if ($) {
    return new Ok(undefined);
  } else {
    return new Error(
      new $gose.ParseError(
        "header names must be disjoint, overlap: " + $string.join(
          $set.to_list(overlap),
          ", ",
        ),
      ),
    );
  }
}

/**
 * Validate that no protected-only headers appear in unprotected.
 * 
 * @ignore
 */
function validate_no_protected_only_headers(names) {
  let violations = $list.filter(
    names,
    (_capture) => { return $list.contains(protected_only_headers, _capture); },
  );
  let $ = $list.is_empty(violations);
  if ($) {
    return new Ok(undefined);
  } else {
    return new Error(
      new $gose.ParseError(
        "protected-only headers in unprotected: " + $string.join(
          violations,
          ", ",
        ),
      ),
    );
  }
}

/**
 * Parse and validate unprotected headers, checking for disjointness with protected.
 * 
 * @ignore
 */
function parse_unprotected_header(header_raw, protected$, protected_custom_keys) {
  if (header_raw instanceof $option.Some) {
    let raw = header_raw[0];
    return $result.try$(
      (() => {
        let _pipe = $decode.run(
          raw,
          $decode.dict($decode.string, $decode.dynamic),
        );
        return $result.replace_error(
          _pipe,
          new $gose.ParseError("unprotected header must be an object"),
        );
      })(),
      (unprotected_dict) => {
        let unprotected_names = $dict.keys(unprotected_dict);
        return $result.try$(
          validate_no_protected_only_headers(unprotected_names),
          (_) => {
            return $result.try$(
              validate_header_disjointness(
                protected$,
                protected_custom_keys,
                unprotected_names,
              ),
              (_) => { return new Ok([$dict.new$(), new $option.Some(raw)]); },
            );
          },
        );
      },
    );
  } else {
    return new Ok([$dict.new$(), new $option.None()]);
  }
}

function parse_json_flattened(json_str) {
  let decoder = $decode.field(
    "protected",
    $decode.string,
    (protected$) => {
      return $decode.field(
        "signature",
        $decode.string,
        (signature) => {
          return $decode.optional_field(
            "payload",
            new $option.None(),
            $decode.optional($decode.string),
            (payload_opt) => {
              return $decode.optional_field(
                "header",
                new $option.None(),
                $decode.optional($decode.dynamic),
                (unprotected_header_raw) => {
                  return $decode.success(
                    [protected$, signature, payload_opt, unprotected_header_raw],
                  );
                },
              );
            },
          );
        },
      );
    },
  );
  return $result.try$(
    (() => {
      let _pipe = $json.parse(json_str, decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("invalid JWS JSON (flattened)"),
      );
    })(),
    (_use0) => {
      let protected_b64 = _use0[0];
      let sig_b64 = _use0[1];
      let payload_opt = _use0[2];
      let unprotected_header_raw = _use0[3];
      return $result.try$(
        parse_protected_header(protected_b64),
        (_use0) => {
          let header = _use0.header;
          let unencoded_payload = _use0.unencoded_payload;
          let header_raw = _use0.header_raw;
          let custom_keys = _use0.custom_keys;
          return $result.try$(
            parse_unprotected_header(
              unprotected_header_raw,
              header,
              custom_keys,
            ),
            (_use0) => {
              let unprotected = _use0[0];
              let unprotected_raw = _use0[1];
              return $result.try$(
                $utils.decode_base64_url(sig_b64, "signature"),
                (signature) => {
                  return build_signed_jws_json(
                    header,
                    header_raw,
                    protected_b64,
                    signature,
                    payload_opt,
                    unencoded_payload,
                    unprotected,
                    unprotected_raw,
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

function signature_decoder() {
  return $decode.field(
    "protected",
    $decode.string,
    (protected$) => {
      return $decode.field(
        "signature",
        $decode.string,
        (signature) => {
          return $decode.optional_field(
            "header",
            new $option.None(),
            $decode.optional($decode.dynamic),
            (header_raw) => {
              return $decode.success([protected$, signature, header_raw]);
            },
          );
        },
      );
    },
  );
}

/**
 * Parse a JWS from JSON General format.
 *
 * **Note:** Only single signatures are supported here. For multiple
 * signatures per payload, use `gose/jose/jws_multi`.
 * 
 * @ignore
 */
function parse_json_general(json_str) {
  let decoder = $decode.field(
    "signatures",
    $decode.list(signature_decoder()),
    (signatures) => {
      return $decode.optional_field(
        "payload",
        new $option.None(),
        $decode.optional($decode.string),
        (payload_opt) => { return $decode.success([signatures, payload_opt]); },
      );
    },
  );
  return $result.try$(
    (() => {
      let _pipe = $json.parse(json_str, decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("invalid JWS JSON (general)"),
      );
    })(),
    (_use0) => {
      let signatures = _use0[0];
      let payload_opt = _use0[1];
      if (signatures instanceof $Empty) {
        return new Error(
          new $gose.ParseError("JWS JSON (general) has no signatures"),
        );
      } else {
        let $ = signatures.tail;
        if ($ instanceof $Empty) {
          let protected_b64 = signatures.head[0];
          let sig_b64 = signatures.head[1];
          let unprotected_header_raw = signatures.head[2];
          return $result.try$(
            parse_protected_header(protected_b64),
            (_use0) => {
              let header = _use0.header;
              let unencoded_payload = _use0.unencoded_payload;
              let header_raw = _use0.header_raw;
              let custom_keys = _use0.custom_keys;
              return $result.try$(
                parse_unprotected_header(
                  unprotected_header_raw,
                  header,
                  custom_keys,
                ),
                (_use0) => {
                  let unprotected = _use0[0];
                  let unprotected_raw = _use0[1];
                  return $result.try$(
                    $utils.decode_base64_url(sig_b64, "signature"),
                    (signature) => {
                      return build_signed_jws_json(
                        header,
                        header_raw,
                        protected_b64,
                        signature,
                        payload_opt,
                        unencoded_payload,
                        unprotected,
                        unprotected_raw,
                      );
                    },
                  );
                },
              );
            },
          );
        } else {
          return new Error(
            new $gose.ParseError(
              "JWS JSON (general) has multiple signatures (not supported)",
            ),
          );
        }
      }
    },
  );
}

function is_general_json_format(json_str) {
  let detector = $decode.field(
    "signatures",
    $decode.dynamic,
    (_) => { return $decode.success(true); },
  );
  let _pipe = $json.parse(json_str, detector);
  return $result.is_ok(_pipe);
}

/**
 * Parse a JWS from JSON format (supports both General and Flattened).
 */
export function parse_json(json_str) {
  let $ = is_general_json_format(json_str);
  if ($) {
    return parse_json_general(json_str);
  } else {
    return parse_json_flattened(json_str);
  }
}
