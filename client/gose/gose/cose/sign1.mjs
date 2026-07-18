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
  makeError,
  toBitArray,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $cbor from "../../gose/cbor.mjs";
import * as $cose from "../../gose/cose.mjs";
import * as $cose_structure from "../../gose/internal/cose_structure.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $signing from "../../gose/internal/signing.mjs";

const FILEPATH = "src/gose/cose/sign1.gleam";

class UnsignedSign1 extends $CustomType {
  constructor(protected$, unprotected, detached, aad) {
    super();
    this.protected = protected$;
    this.unprotected = unprotected;
    this.detached = detached;
    this.aad = aad;
  }
}

class SignedSign1 extends $CustomType {
  constructor(protected$, protected_serialized, unprotected, payload, signature) {
    super();
    this.protected = protected$;
    this.protected_serialized = protected_serialized;
    this.unprotected = unprotected;
    this.payload = payload;
    this.signature = signature;
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
 * Create a new unsigned COSE_Sign1 message with the given signature algorithm in the protected header.
 */
export function new$(alg) {
  let alg_id = $cose.signature_alg_to_int(alg);
  return new UnsignedSign1(
    toList([new $cose.Alg(alg_id)]),
    toList([]),
    false,
    toBitArray([]),
  );
}

function build_sig_structure(protected_serialized, aad, payload) {
  return $cbor.encode(
    new $cbor.Array(
      toList([
        new $cbor.Text("Signature1"),
        new $cbor.Bytes(protected_serialized),
        new $cbor.Bytes(aad),
        new $cbor.Bytes(payload),
      ]),
    ),
  );
}

/**
 * Sign the payload with the given key, producing a signed COSE_Sign1 message.
 */
export function sign(message, key, payload) {
  let protected$;
  let unprotected;
  let detached;
  let aad;
  if (message instanceof UnsignedSign1) {
    protected$ = message.protected;
    unprotected = message.unprotected;
    detached = message.detached;
    aad = message.aad;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      91,
      "sign",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 2595,
        end: 2672,
        pattern_start: 2606,
        pattern_end: 2662
      }
    )
  }
  return $result.try$(
    $cose_structure.extract_signing_alg_from_headers(protected$),
    (alg) => {
      return $result.try$(
        $key_helpers.validate_signing_key_type(alg, key),
        (_) => {
          return $result.try$(
            $key_helpers.validate_key_use(key, new $key_helpers.ForSigning()),
            (_) => {
              return $result.try$(
                $key_helpers.validate_key_ops(
                  key,
                  new $key_helpers.ForSigning(),
                ),
                (_) => {
                  return $result.try$(
                    $key_helpers.validate_key_algorithm_signing(key, alg),
                    (_) => {
                      let protected_serialized = $cose_structure.serialize_protected(
                        protected$,
                      );
                      let to_sign = build_sig_structure(
                        protected_serialized,
                        aad,
                        payload,
                      );
                      return $result.try$(
                        $signing.compute_signature(alg, key, to_sign),
                        (sig) => {
                          let _block;
                          if (detached) {
                            _block = new $option.None();
                          } else {
                            _block = new $option.Some(payload);
                          }
                          let stored_payload = _block;
                          return new Ok(
                            new SignedSign1(
                              protected$,
                              protected_serialized,
                              unprotected,
                              stored_payload,
                              sig,
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

function to_cbor_value(message) {
  let protected_serialized;
  let unprotected;
  let payload$1;
  let signature;
  if (message instanceof SignedSign1) {
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    payload$1 = message.payload;
    signature = message.signature;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      131,
      "to_cbor_value",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 3958,
        end: 4078,
        pattern_start: 3969,
        pattern_end: 4068
      }
    )
  }
  let _block;
  if (payload$1 instanceof $option.Some) {
    let p = payload$1[0];
    _block = new $cbor.Bytes(p);
  } else {
    _block = new $cbor.Null();
  }
  let payload_value = _block;
  return new $cbor.Array(
    toList([
      new $cbor.Bytes(protected_serialized),
      new $cbor.Map($cose.headers_to_cbor(unprotected)),
      payload_value,
      new $cbor.Bytes(signature),
    ]),
  );
}

/**
 * Encode a signed message as an untagged CBOR COSE_Sign1 array.
 */
export function serialize(message) {
  return $cbor.encode(to_cbor_value(message));
}

/**
 * Encode a signed message as a CBOR-tagged (tag 18) COSE_Sign1 structure.
 */
export function serialize_tagged(message) {
  return $cbor.encode(new $cbor.Tag(18, to_cbor_value(message)));
}

function parse_cbor_value(value) {
  return $result.try$(
    $cose_structure.parse_cose_array_value(value, 18, 4),
    (items) => {
      if (items instanceof $Empty) {
        return new Error(new $gose.ParseError("invalid COSE_Sign1 structure"));
      } else {
        let $ = items.tail;
        if ($ instanceof $Empty) {
          return new Error(new $gose.ParseError("invalid COSE_Sign1 structure"));
        } else {
          let $1 = $.tail;
          if ($1 instanceof $Empty) {
            return new Error(
              new $gose.ParseError("invalid COSE_Sign1 structure"),
            );
          } else {
            let $2 = $1.tail;
            if ($2 instanceof $Empty) {
              return new Error(
                new $gose.ParseError("invalid COSE_Sign1 structure"),
              );
            } else {
              let $3 = $2.tail;
              if ($3 instanceof $Empty) {
                let $4 = items.head;
                if ($4 instanceof $cbor.Bytes) {
                  let $5 = $.head;
                  if ($5 instanceof $cbor.Map) {
                    let $6 = $2.head;
                    if ($6 instanceof $cbor.Bytes) {
                      let payload_value = $1.head;
                      let protected_serialized = $4[0];
                      let unprotected_cbor = $5[0];
                      let signature = $6[0];
                      return $result.try$(
                        $cose_structure.decode_protected(protected_serialized),
                        (protected$) => {
                          return $result.try$(
                            $cose_structure.decode_unprotected(unprotected_cbor),
                            (unprotected) => {
                              return $result.try$(
                                $cose_structure.validate_no_header_overlap(
                                  protected$,
                                  unprotected,
                                ),
                                (_) => {
                                  return $result.try$(
                                    $cose_structure.validate_iv_partial_iv_exclusion(
                                      protected$,
                                      unprotected,
                                    ),
                                    (_) => {
                                      return $result.try$(
                                        $cose_structure.decode_payload(
                                          payload_value,
                                        ),
                                        (payload) => {
                                          return new Ok(
                                            new SignedSign1(
                                              protected$,
                                              protected_serialized,
                                              unprotected,
                                              payload,
                                              signature,
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
                    } else {
                      return new Error(
                        new $gose.ParseError("invalid COSE_Sign1 structure"),
                      );
                    }
                  } else {
                    return new Error(
                      new $gose.ParseError("invalid COSE_Sign1 structure"),
                    );
                  }
                } else {
                  return new Error(
                    new $gose.ParseError("invalid COSE_Sign1 structure"),
                  );
                }
              } else {
                return new Error(
                  new $gose.ParseError("invalid COSE_Sign1 structure"),
                );
              }
            }
          }
        }
      }
    },
  );
}

/**
 * Decode a CBOR-encoded COSE_Sign1 message, accepting both tagged and untagged forms.
 */
export function parse(data) {
  return $result.try$(
    $cbor.decode(data),
    (value) => { return parse_cbor_value(value); },
  );
}

/**
 * Return the payload from a signed message. Returns `Error(Nil)` if detached.
 */
export function payload(message) {
  let payload$1;
  if (message instanceof SignedSign1) {
    payload$1 = message.payload;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      160,
      "payload",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 4725,
        end: 4771,
        pattern_start: 4736,
        pattern_end: 4761
      }
    )
  }
  return $option.to_result(payload$1, undefined);
}

/**
 * Build a verifier pinned to a single algorithm and one or more keys.
 */
export function verifier(alg, keys) {
  let signing_alg = new $gose.DigitalSignature(alg);
  return $key_helpers.require_non_empty_keys(
    keys,
    () => {
      return $result.try$(
        $list.try_each(
          keys,
          (_capture) => {
            return $key_helpers.validate_key_for_signing_verification(
              signing_alg,
              _capture,
            );
          },
        ),
        (_) => { return new Ok(new Verifier(alg, keys)); },
      );
    },
  );
}

/**
 * Verify the signature with additional externally-supplied authenticated data (AAD).
 */
export function verify_with_aad(verifier, message, aad) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  let expected_signing_alg = new $gose.DigitalSignature(expected_alg);
  let protected$;
  let protected_serialized;
  let unprotected;
  let payload$1;
  let signature;
  if (message instanceof SignedSign1) {
    protected$ = message.protected;
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    payload$1 = message.payload;
    signature = message.signature;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      196,
      "verify_with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 5877,
        end: 6005,
        pattern_start: 5888,
        pattern_end: 5995
      }
    )
  }
  return $result.try$(
    $cose_structure.extract_signing_alg_from_serialized(protected_serialized),
    (actual_alg) => {
      return $result.try$(
        $key_helpers.require_matching_signing_algorithm(
          expected_signing_alg,
          actual_alg,
        ),
        (_) => {
          return $result.try$(
            $cose_structure.validate_crit(protected$, unprotected),
            (_) => {
              return $result.try$(
                $cose_structure.require_embedded_payload(payload$1),
                (payload_bytes) => {
                  let to_sign = build_sig_structure(
                    protected_serialized,
                    aad,
                    payload_bytes,
                  );
                  return $cose_structure.try_verify_keys(
                    expected_signing_alg,
                    keys,
                    to_sign,
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

/**
 * Verify the signature of a signed COSE_Sign1 message against the verifier's expected algorithm and keys.
 */
export function verify(verifier, message) {
  return verify_with_aad(verifier, message, toBitArray([]));
}

/**
 * Verify a detached-payload COSE_Sign1 message with external AAD.
 */
export function verify_detached_with_aad(verifier, message, payload, aad) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  let expected_signing_alg = new $gose.DigitalSignature(expected_alg);
  let protected$;
  let protected_serialized;
  let unprotected;
  let existing_payload;
  let signature;
  if (message instanceof SignedSign1) {
    protected$ = message.protected;
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    existing_payload = message.payload;
    signature = message.signature;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      247,
      "verify_detached_with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 7392,
        end: 7537,
        pattern_start: 7403,
        pattern_end: 7527
      }
    )
  }
  return $result.try$(
    $cose_structure.require_detached_payload(existing_payload),
    (_) => {
      return $result.try$(
        $cose_structure.extract_signing_alg_from_serialized(
          protected_serialized,
        ),
        (actual_alg) => {
          return $result.try$(
            $key_helpers.require_matching_signing_algorithm(
              expected_signing_alg,
              actual_alg,
            ),
            (_) => {
              return $result.try$(
                $cose_structure.validate_crit(protected$, unprotected),
                (_) => {
                  let to_sign = build_sig_structure(
                    protected_serialized,
                    aad,
                    payload,
                  );
                  return $cose_structure.try_verify_keys(
                    expected_signing_alg,
                    keys,
                    to_sign,
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

/**
 * Verify the signature of a detached-payload COSE_Sign1 message.
 *
 * The caller must supply the payload that was detached from the message.
 * Returns an error if the message already contains an embedded payload.
 */
export function verify_detached(verifier, message, payload) {
  return verify_detached_with_aad(verifier, message, payload, toBitArray([]));
}

/**
 * Mark the message for detached payload. The payload is still provided to
 * `sign` for signature computation but not included in the serialized output.
 */
export function with_detached(message) {
  if (!(message instanceof UnsignedSign1)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      278,
      "with_detached",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8343,
        end: 8381,
        pattern_start: 8354,
        pattern_end: 8371
      }
    )
  }
  return new UnsignedSign1(
    message.protected,
    message.unprotected,
    true,
    message.aad,
  );
}

/**
 * Set external additional authenticated data (AAD) for the signing operation.
 */
export function with_aad(message, aad) {
  if (!(message instanceof UnsignedSign1)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      284,
      "with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8592,
        end: 8630,
        pattern_start: 8603,
        pattern_end: 8620
      }
    )
  }
  return new UnsignedSign1(
    message.protected,
    message.unprotected,
    message.detached,
    aad,
  );
}

/**
 * Add a key ID to the unprotected headers.
 */
export function with_kid(message, kid) {
  let unprotected;
  if (message instanceof UnsignedSign1) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      290,
      "with_kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8796,
        end: 8848,
        pattern_start: 8807,
        pattern_end: 8838
      }
    )
  }
  return new UnsignedSign1(
    message.protected,
    listPrepend(new $cose.Kid(kid), unprotected),
    message.detached,
    message.aad,
  );
}

/**
 * Add a content type to the unprotected headers.
 *
 * RFC 9052 permits either bucket. Signed messages place it in unprotected,
 * consistent with `with_kid`.
 */
export function with_content_type(message, ct) {
  let unprotected;
  if (message instanceof UnsignedSign1) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      302,
      "with_content_type",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 9194,
        end: 9246,
        pattern_start: 9205,
        pattern_end: 9236
      }
    )
  }
  return new UnsignedSign1(
    message.protected,
    listPrepend(new $cose.ContentType(ct), unprotected),
    message.detached,
    message.aad,
  );
}

/**
 * Add critical header labels to the protected headers.
 */
export function with_critical(message, labels) {
  let protected$;
  if (message instanceof UnsignedSign1) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      311,
      "with_critical",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 9489,
        end: 9539,
        pattern_start: 9500,
        pattern_end: 9529
      }
    )
  }
  return new UnsignedSign1(
    listPrepend(new $cose.Crit(labels), protected$),
    message.unprotected,
    message.detached,
    message.aad,
  );
}

/**
 * Extract the key ID from the message headers.
 */
export function kid(message) {
  let protected$;
  let unprotected;
  if (message instanceof SignedSign1) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      317,
      "kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 9739,
        end: 9801,
        pattern_start: 9750,
        pattern_end: 9791
      }
    )
  }
  return $cose.kid($list.append(protected$, unprotected));
}

/**
 * Extract the content type from the message headers.
 */
export function content_type(message) {
  let protected$;
  let unprotected;
  if (message instanceof SignedSign1) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      325,
      "content_type",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 10005,
        end: 10067,
        pattern_start: 10016,
        pattern_end: 10057
      }
    )
  }
  return $cose.content_type($list.append(protected$, unprotected));
}

/**
 * Extract the critical header labels from the message headers.
 */
export function critical(message) {
  let protected$;
  let unprotected;
  if (message instanceof SignedSign1) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      331,
      "critical",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 10274,
        end: 10336,
        pattern_start: 10285,
        pattern_end: 10326
      }
    )
  }
  return $cose.critical($list.append(protected$, unprotected));
}

/**
 * Return the raw protected headers.
 */
export function protected_headers(message) {
  let protected$;
  if (message instanceof SignedSign1) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      337,
      "protected_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 10505,
        end: 10553,
        pattern_start: 10516,
        pattern_end: 10543
      }
    )
  }
  return protected$;
}

/**
 * Return the raw unprotected headers.
 */
export function unprotected_headers(message) {
  let unprotected;
  if (message instanceof SignedSign1) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/sign1",
      343,
      "unprotected_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 10685,
        end: 10735,
        pattern_start: 10696,
        pattern_end: 10725
      }
    )
  }
  return unprotected;
}
