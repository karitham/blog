import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
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

const FILEPATH = "src/gose/cose/mac0.gleam";

class UntaggedMac0 extends $CustomType {
  constructor(protected$, unprotected, detached, aad) {
    super();
    this.protected = protected$;
    this.unprotected = unprotected;
    this.detached = detached;
    this.aad = aad;
  }
}

class TaggedMac0 extends $CustomType {
  constructor(protected$, protected_serialized, unprotected, payload, mac_tag) {
    super();
    this.protected = protected$;
    this.protected_serialized = protected_serialized;
    this.unprotected = unprotected;
    this.payload = payload;
    this.mac_tag = mac_tag;
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
 * Create a new untagged COSE_Mac0 message with the given MAC algorithm in the protected header.
 */
export function new$(alg) {
  let alg_id = $cose.mac_alg_to_int(alg);
  return new UntaggedMac0(
    toList([new $cose.Alg(alg_id)]),
    $List$Empty$const,
    false,
    toBitArray([]),
  );
}

function build_mac_structure(protected_serialized, aad, payload) {
  return $cbor.encode(
    new $cbor.Array(
      toList([
        new $cbor.Text("MAC0"),
        new $cbor.Bytes(protected_serialized),
        new $cbor.Bytes(aad),
        new $cbor.Bytes(payload),
      ]),
    ),
  );
}

/**
 * Compute the MAC tag over the payload with the given key.
 */
export function tag(message, key, payload) {
  let protected$;
  let unprotected;
  let detached;
  let aad;
  if (message instanceof UntaggedMac0) {
    protected$ = message.protected;
    unprotected = message.unprotected;
    detached = message.detached;
    aad = message.aad;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      90,
      "tag",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 2503,
        end: 2579,
        pattern_start: 2514,
        pattern_end: 2569
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
            $key_helpers.validate_key_use(
              key,
              $key_helpers.KeyPurpose$ForSigning$const,
            ),
            (_) => {
              return $result.try$(
                $key_helpers.validate_key_ops(
                  key,
                  $key_helpers.KeyPurpose$ForSigning$const,
                ),
                (_) => {
                  return $result.try$(
                    $key_helpers.validate_key_algorithm_signing(key, alg),
                    (_) => {
                      let protected_serialized = $cose_structure.serialize_protected(
                        protected$,
                      );
                      let to_mac = build_mac_structure(
                        protected_serialized,
                        aad,
                        payload,
                      );
                      return $result.try$(
                        $signing.compute_signature(alg, key, to_mac),
                        (computed_tag) => {
                          let _block;
                          if (detached) {
                            _block = $option.Option$None$const;
                          } else {
                            _block = new $option.Some(payload);
                          }
                          let stored_payload = _block;
                          return new Ok(
                            new TaggedMac0(
                              protected$,
                              protected_serialized,
                              unprotected,
                              stored_payload,
                              computed_tag,
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
  let mac_tag;
  if (message instanceof TaggedMac0) {
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    payload$1 = message.payload;
    mac_tag = message.mac_tag;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      134,
      "to_cbor_value",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 3890,
        end: 4007,
        pattern_start: 3901,
        pattern_end: 3997
      }
    )
  }
  let _block;
  if (payload$1 instanceof $option.Some) {
    let p = payload$1[0];
    _block = new $cbor.Bytes(p);
  } else {
    _block = $cbor.Value$Null$const;
  }
  let payload_value = _block;
  return new $cbor.Array(
    toList([
      new $cbor.Bytes(protected_serialized),
      new $cbor.Map($cose.headers_to_cbor(unprotected)),
      payload_value,
      new $cbor.Bytes(mac_tag),
    ]),
  );
}

/**
 * Encode a tagged message as an untagged CBOR COSE_Mac0 array.
 */
export function serialize(message) {
  return $cbor.encode(to_cbor_value(message));
}

/**
 * Encode a tagged message as a CBOR-tagged (tag 17) COSE_Mac0 structure.
 */
export function serialize_tagged(message) {
  return $cbor.encode(new $cbor.Tag(17, to_cbor_value(message)));
}

function parse_cbor_value(value) {
  return $result.try$(
    $cose_structure.parse_cose_array_value(value, 17, 4),
    (items) => {
      if (items instanceof $Empty) {
        return new Error(new $gose.ParseError("invalid COSE_Mac0 structure"));
      } else {
        let $ = items.tail;
        if ($ instanceof $Empty) {
          return new Error(new $gose.ParseError("invalid COSE_Mac0 structure"));
        } else {
          let $1 = $.tail;
          if ($1 instanceof $Empty) {
            return new Error(
              new $gose.ParseError("invalid COSE_Mac0 structure"),
            );
          } else {
            let $2 = $1.tail;
            if ($2 instanceof $Empty) {
              return new Error(
                new $gose.ParseError("invalid COSE_Mac0 structure"),
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
                      let mac_tag = $6[0];
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
                                            new TaggedMac0(
                                              protected$,
                                              protected_serialized,
                                              unprotected,
                                              payload,
                                              mac_tag,
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
                        new $gose.ParseError("invalid COSE_Mac0 structure"),
                      );
                    }
                  } else {
                    return new Error(
                      new $gose.ParseError("invalid COSE_Mac0 structure"),
                    );
                  }
                } else {
                  return new Error(
                    new $gose.ParseError("invalid COSE_Mac0 structure"),
                  );
                }
              } else {
                return new Error(
                  new $gose.ParseError("invalid COSE_Mac0 structure"),
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
 * Decode a CBOR-encoded COSE_Mac0 message, accepting both tagged and untagged forms.
 */
export function parse(data) {
  return $result.try$(
    $cbor.decode(data),
    (value) => { return parse_cbor_value(value); },
  );
}

/**
 * Return the payload from a tagged message. Returns `Error(Nil)` if detached.
 */
export function payload(message) {
  let payload$1;
  if (message instanceof TaggedMac0) {
    payload$1 = message.payload;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      163,
      "payload",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 4649,
        end: 4694,
        pattern_start: 4660,
        pattern_end: 4684
      }
    )
  }
  return $option.to_result(payload$1, undefined);
}

/**
 * Build a verifier pinned to a single algorithm and one or more keys.
 */
export function verifier(alg, keys) {
  let signing_alg = new $gose.Mac(alg);
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
 * Verify the MAC tag with additional externally-supplied authenticated data (AAD).
 */
export function verify_with_aad(verifier, message, aad) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  let expected_signing_alg = new $gose.Mac(expected_alg);
  let protected$;
  let protected_serialized;
  let unprotected;
  let payload$1;
  let mac_tag;
  if (message instanceof TaggedMac0) {
    protected$ = message.protected;
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    payload$1 = message.payload;
    mac_tag = message.mac_tag;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      199,
      "verify_with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 5747,
        end: 5872,
        pattern_start: 5758,
        pattern_end: 5862
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
                  let to_mac = build_mac_structure(
                    protected_serialized,
                    aad,
                    payload_bytes,
                  );
                  return $cose_structure.try_verify_keys(
                    expected_signing_alg,
                    keys,
                    to_mac,
                    mac_tag,
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
 * Verify the MAC tag of a COSE_Mac0 message against the verifier's expected algorithm and keys.
 */
export function verify(verifier, message) {
  return verify_with_aad(verifier, message, toBitArray([]));
}

/**
 * Verify a detached-payload COSE_Mac0 message with external AAD.
 */
export function verify_detached_with_aad(verifier, message, payload, aad) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  let expected_signing_alg = new $gose.Mac(expected_alg);
  let protected$;
  let protected_serialized;
  let unprotected;
  let existing_payload;
  let mac_tag;
  if (message instanceof TaggedMac0) {
    protected$ = message.protected;
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    existing_payload = message.payload;
    mac_tag = message.mac_tag;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      250,
      "verify_detached_with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 7246,
        end: 7388,
        pattern_start: 7257,
        pattern_end: 7378
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
                  let to_mac = build_mac_structure(
                    protected_serialized,
                    aad,
                    payload,
                  );
                  return $cose_structure.try_verify_keys(
                    expected_signing_alg,
                    keys,
                    to_mac,
                    mac_tag,
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
 * Verify the MAC tag of a detached-payload COSE_Mac0 message.
 *
 * The caller must supply the payload that was detached from the message.
 * Returns an error if the message already contains an embedded payload.
 */
export function verify_detached(verifier, message, payload) {
  return verify_detached_with_aad(verifier, message, payload, toBitArray([]));
}

/**
 * Mark the message for detached payload. The payload is still provided to
 * `tag` for MAC computation but not included in the serialized output.
 */
export function with_detached(message) {
  if (!(message instanceof UntaggedMac0)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      281,
      "with_detached",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8191,
        end: 8228,
        pattern_start: 8202,
        pattern_end: 8218
      }
    )
  }
  return new UntaggedMac0(
    message.protected,
    message.unprotected,
    true,
    message.aad,
  );
}

/**
 * Set external additional authenticated data (AAD) for the MAC operation.
 */
export function with_aad(message, aad) {
  if (!(message instanceof UntaggedMac0)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      287,
      "with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8432,
        end: 8469,
        pattern_start: 8443,
        pattern_end: 8459
      }
    )
  }
  return new UntaggedMac0(
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
  if (message instanceof UntaggedMac0) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      293,
      "with_kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8632,
        end: 8683,
        pattern_start: 8643,
        pattern_end: 8673
      }
    )
  }
  return new UntaggedMac0(
    message.protected,
    listPrepend(new $cose.Kid(kid), unprotected),
    message.detached,
    message.aad,
  );
}

/**
 * Add a content type to the unprotected headers.
 *
 * RFC 9052 permits either bucket. MACed messages place it in unprotected,
 * consistent with `with_kid`.
 */
export function with_content_type(message, ct) {
  let unprotected;
  if (message instanceof UntaggedMac0) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      305,
      "with_content_type",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 9025,
        end: 9076,
        pattern_start: 9036,
        pattern_end: 9066
      }
    )
  }
  return new UntaggedMac0(
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
  if (message instanceof UntaggedMac0) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      314,
      "with_critical",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 9316,
        end: 9365,
        pattern_start: 9327,
        pattern_end: 9355
      }
    )
  }
  return new UntaggedMac0(
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
  if (message instanceof TaggedMac0) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      320,
      "kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 9563,
        end: 9624,
        pattern_start: 9574,
        pattern_end: 9614
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
  if (message instanceof TaggedMac0) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      328,
      "content_type",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 9827,
        end: 9888,
        pattern_start: 9838,
        pattern_end: 9878
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
  if (message instanceof TaggedMac0) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      334,
      "critical",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 10094,
        end: 10155,
        pattern_start: 10105,
        pattern_end: 10145
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
  if (message instanceof TaggedMac0) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      340,
      "protected_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 10323,
        end: 10370,
        pattern_start: 10334,
        pattern_end: 10360
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
  if (message instanceof TaggedMac0) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/mac0",
      346,
      "unprotected_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 10501,
        end: 10550,
        pattern_start: 10512,
        pattern_end: 10540
      }
    )
  }
  return unprotected;
}
