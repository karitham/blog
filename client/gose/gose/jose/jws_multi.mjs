import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  prepend as listPrepend,
  CustomType as $CustomType,
  isEqual,
  toBitArray,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $signing from "../../gose/internal/signing.mjs";
import * as $utils from "../../gose/internal/utils.mjs";
import * as $jose from "../../gose/jose.mjs";

class Body extends $CustomType {
  constructor(payload, payload_segment, detached, signatures) {
    super();
    this.payload = payload;
    this.payload_segment = payload_segment;
    this.detached = detached;
    this.signatures = signatures;
  }
}

class Signature extends $CustomType {
  constructor(alg, protected_b64, signature) {
    super();
    this.alg = alg;
    this.protected_b64 = protected_b64;
    this.signature = signature;
  }
}

class MultiJws extends $CustomType {
  constructor(payload, payload_segment, signatures, detached) {
    super();
    this.payload = payload;
    this.payload_segment = payload_segment;
    this.signatures = signatures;
    this.detached = detached;
  }
}

class Verifier extends $CustomType {
  constructor(alg, keys) {
    super();
    this.alg = alg;
    this.keys = keys;
  }
}

/**
 * Create a new body pinned to the payload all signers will sign.
 */
export function new$(payload) {
  return new Body(payload, $utils.encode_base64_url(payload), false, toList([]));
}

/**
 * Mark the body as using a detached payload (RFC 7515 Appendix F).
 *
 * The payload is still signed but omitted from the serialized JSON. Callers
 * verify with `verify_detached`, supplying the payload separately.
 */
export function with_detached(body) {
  return new Body(body.payload, body.payload_segment, true, body.signatures);
}

function simple_header_json(alg) {
  let _pipe = $json.object(
    toList([["alg", $json.string($jose.signing_alg_to_string(alg))]]),
  );
  let _pipe$1 = $json.to_string(_pipe);
  return $bit_array.from_string(_pipe$1);
}

/**
 * Compute a per-signer JWS signature over the body's payload and append it
 * to the body. Transitions the body to `Signed` state, preventing further
 * `with_*` mutations at compile time.
 */
export function sign(body, alg, key) {
  return $result.try$(
    $key_helpers.validate_signing_key_type(alg, key),
    (_) => {
      return $result.try$(
        $key_helpers.validate_key_use(key, new $key_helpers.ForSigning()),
        (_) => {
          return $result.try$(
            $key_helpers.validate_key_ops(key, new $key_helpers.ForSigning()),
            (_) => {
              return $result.try$(
                $key_helpers.validate_key_algorithm_signing(key, alg),
                (_) => {
                  let protected_json = simple_header_json(alg);
                  let protected_b64 = $utils.encode_base64_url(protected_json);
                  let signing_input = (protected_b64 + ".") + body.payload_segment;
                  return $result.try$(
                    $signing.compute_signature(
                      alg,
                      key,
                      $bit_array.from_string(signing_input),
                    ),
                    (sig) => {
                      let signature = new Signature(alg, protected_b64, sig);
                      return new Ok(
                        new Body(
                          body.payload,
                          body.payload_segment,
                          body.detached,
                          listPrepend(signature, body.signatures),
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
}

/**
 * Finalize a signed body into a serializable multi-signer JWS.
 */
export function assemble(body) {
  return new MultiJws(
    body.payload,
    body.payload_segment,
    $list.reverse(body.signatures),
    body.detached,
  );
}

/**
 * Return the payload. Returns an empty `BitArray` for messages parsed with
 * a detached payload.
 */
export function payload(message) {
  return message.payload;
}

/**
 * Check whether the message was built or parsed with a detached payload.
 */
export function is_detached(message) {
  return message.detached;
}

/**
 * Serialize as JWS JSON General Serialization. For messages built with
 * `with_detached`, the payload field is omitted.
 */
export function serialize_json(message) {
  let sig_objects = $list.map(
    message.signatures,
    (sig) => {
      return $json.object(
        toList([
          ["protected", $json.string(sig.protected_b64)],
          ["signature", $json.string($utils.encode_base64_url(sig.signature))],
        ]),
      );
    },
  );
  let _block;
  let $ = message.detached;
  if ($) {
    _block = toList([["signatures", $json.preprocessed_array(sig_objects)]]);
  } else {
    _block = toList([
      ["payload", $json.string(message.payload_segment)],
      ["signatures", $json.preprocessed_array(sig_objects)],
    ]);
  }
  let fields = _block;
  return $json.object(fields);
}

function parse_alg_from_header(header_bytes) {
  let decoder = $decode.field(
    "alg",
    $decode.string,
    (alg_str) => { return $decode.success(alg_str); },
  );
  return $result.try$(
    (() => {
      let _pipe = $json.parse_bits(header_bytes, decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("missing alg in protected header"),
      );
    })(),
    (alg_str) => { return $jose.signing_alg_from_string(alg_str); },
  );
}

function parse_raw_signature(raw) {
  let protected_b64 = raw[0];
  let sig_b64 = raw[1];
  return $result.try$(
    $utils.decode_base64_url(protected_b64, "protected header"),
    (protected_bytes) => {
      return $result.try$(
        parse_alg_from_header(protected_bytes),
        (alg) => {
          return $result.try$(
            $utils.decode_base64_url(sig_b64, "signature"),
            (signature) => {
              return new Ok(new Signature(alg, protected_b64, signature));
            },
          );
        },
      );
    },
  );
}

/**
 * Parse a JWS from JSON General Serialization format. A missing `payload`
 * field indicates a detached payload per RFC 7515 Appendix F.
 */
export function parse_json(json_str) {
  let sig_decoder = $decode.field(
    "protected",
    $decode.string,
    (protected$) => {
      return $decode.field(
        "signature",
        $decode.string,
        (signature) => { return $decode.success([protected$, signature]); },
      );
    },
  );
  let decoder = $decode.optional_field(
    "payload",
    new $option.None(),
    $decode.optional($decode.string),
    (payload) => {
      return $decode.field(
        "signatures",
        $decode.list(sig_decoder),
        (signatures) => { return $decode.success([payload, signatures]); },
      );
    },
  );
  return $result.try$(
    (() => {
      let _pipe = $json.parse(json_str, decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("invalid JWS JSON"),
      );
    })(),
    (_use0) => {
      let payload_b64_opt = _use0[0];
      let raw_sigs = _use0[1];
      return $result.try$(
        $list.try_map(raw_sigs, parse_raw_signature),
        (signatures) => {
          if (payload_b64_opt instanceof $option.Some) {
            let payload_b64 = payload_b64_opt[0];
            return $result.try$(
              $utils.decode_base64_url(payload_b64, "payload"),
              (payload) => {
                return new Ok(
                  new MultiJws(payload, payload_b64, signatures, false),
                );
              },
            );
          } else {
            return new Ok(new MultiJws(toBitArray([]), "", signatures, true));
          }
        },
      );
    },
  );
}

/**
 * Build a verifier pinned to a single algorithm and one or more keys.
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

function do_verify_keys(loop$alg, loop$keys, loop$message, loop$signature) {
  while (true) {
    let alg = loop$alg;
    let keys = loop$keys;
    let message = loop$message;
    let signature = loop$signature;
    if (keys instanceof $Empty) {
      return new Error(new $gose.VerificationFailed());
    } else {
      let key = keys.head;
      let rest = keys.tail;
      let $ = $signing.verify_signature(alg, key, message, signature);
      if ($ instanceof Ok) {
        return $;
      } else {
        let $1 = $[0];
        if ($1 instanceof $gose.VerificationFailed) {
          loop$alg = alg;
          loop$keys = rest;
          loop$message = message;
          loop$signature = signature;
        } else {
          return $;
        }
      }
    }
  }
}

function do_verify(verifier, message, payload_segment) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  let matching = $list.filter(
    message.signatures,
    (sig) => { return isEqual(sig.alg, expected_alg); },
  );
  if (matching instanceof $Empty) {
    return new Error(new $gose.VerificationFailed());
  } else {
    let sig = matching.head;
    let signing_input = (sig.protected_b64 + ".") + payload_segment;
    return do_verify_keys(
      expected_alg,
      keys,
      $bit_array.from_string(signing_input),
      sig.signature,
    );
  }
}

/**
 * Verify the first matching signer's signature.
 *
 * Returns `InvalidState` if the message was parsed with a detached payload;
 * use `verify_detached` instead.
 */
export function verify(verifier, message) {
  return $bool.guard(
    message.detached,
    new Error(
      new $gose.InvalidState(
        "JWS payload is detached; use verify_detached instead",
      ),
    ),
    () => { return do_verify(verifier, message, message.payload_segment); },
  );
}

/**
 * Verify a detached-payload JWS by supplying the payload at verify time.
 */
export function verify_detached(verifier, message, payload) {
  return $bool.guard(
    !message.detached,
    new Error(
      new $gose.InvalidState("JWS payload is not detached; use verify instead"),
    ),
    () => {
      return do_verify(verifier, message, $utils.encode_base64_url(payload));
    },
  );
}
