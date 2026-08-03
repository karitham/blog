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
  isEqual,
  toBitArray,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $cbor from "../../gose/cbor.mjs";
import * as $cose from "../../gose/cose.mjs";
import * as $cose_structure from "../../gose/internal/cose_structure.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $signing from "../../gose/internal/signing.mjs";

class Body extends $CustomType {
  constructor(protected$, unprotected, detached, aad, payload, signatures) {
    super();
    this.protected = protected$;
    this.unprotected = unprotected;
    this.detached = detached;
    this.aad = aad;
    this.payload = payload;
    this.signatures = signatures;
  }
}

class Signature extends $CustomType {
  constructor(protected$, protected_serialized, unprotected, signature) {
    super();
    this.protected = protected$;
    this.protected_serialized = protected_serialized;
    this.unprotected = unprotected;
    this.signature = signature;
  }
}

class SignedSign extends $CustomType {
  constructor(protected$, protected_serialized, unprotected, payload, signatures) {
    super();
    this.protected = protected$;
    this.protected_serialized = protected_serialized;
    this.unprotected = unprotected;
    this.payload = payload;
    this.signatures = signatures;
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
  return new Body(
    $List$Empty$const,
    $List$Empty$const,
    false,
    toBitArray([]),
    payload,
    $List$Empty$const,
  );
}

/**
 * Mark the message for detached payload. The payload captured on
 * `new(payload:)` is still covered by each signature, but `assemble`
 * omits it from the serialized output.
 */
export function with_detached(body) {
  return new Body(
    body.protected,
    body.unprotected,
    true,
    body.aad,
    body.payload,
    body.signatures,
  );
}

/**
 * Set external additional authenticated data (AAD) for the signing operation.
 */
export function with_aad(body, aad) {
  return new Body(
    body.protected,
    body.unprotected,
    body.detached,
    aad,
    body.payload,
    body.signatures,
  );
}

/**
 * Add a key ID to the body's unprotected headers.
 */
export function with_kid(body, kid) {
  return new Body(
    body.protected,
    listPrepend(new $cose.Kid(kid), body.unprotected),
    body.detached,
    body.aad,
    body.payload,
    body.signatures,
  );
}

/**
 * Add a content type to the body's unprotected headers.
 *
 * RFC 9052 permits either bucket. Signed messages place it in unprotected,
 * consistent with `with_kid`.
 */
export function with_content_type(body, ct) {
  return new Body(
    body.protected,
    listPrepend(new $cose.ContentType(ct), body.unprotected),
    body.detached,
    body.aad,
    body.payload,
    body.signatures,
  );
}

/**
 * Add critical header labels to the body's protected headers.
 */
export function with_critical(body, labels) {
  return new Body(
    listPrepend(new $cose.Crit(labels), body.protected),
    body.unprotected,
    body.detached,
    body.aad,
    body.payload,
    body.signatures,
  );
}

function build_sig_structure(body_protected, sign_protected, aad, payload) {
  return $cbor.encode(
    new $cbor.Array(
      toList([
        new $cbor.Text("Signature"),
        new $cbor.Bytes(body_protected),
        new $cbor.Bytes(sign_protected),
        new $cbor.Bytes(aad),
        new $cbor.Bytes(payload),
      ]),
    ),
  );
}

/**
 * Compute a per-signer signature over the body's payload and append it to
 * the body. Transitions the body to `Signed` state, preventing further
 * `with_*` mutations at compile time.
 */
export function sign(body, alg, key) {
  let signing_alg = new $gose.DigitalSignature(alg);
  return $result.try$(
    $key_helpers.validate_signing_key_type(signing_alg, key),
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
                $key_helpers.validate_key_algorithm_signing(key, signing_alg),
                (_) => {
                  let alg_id = $cose.signature_alg_to_int(alg);
                  let sign_protected = toList([new $cose.Alg(alg_id)]);
                  let sign_protected_serialized = $cose_structure.serialize_protected(
                    sign_protected,
                  );
                  let body_protected_serialized = $cose_structure.serialize_protected(
                    body.protected,
                  );
                  let to_sign = build_sig_structure(
                    body_protected_serialized,
                    sign_protected_serialized,
                    body.aad,
                    body.payload,
                  );
                  return $result.try$(
                    $signing.compute_signature(signing_alg, key, to_sign),
                    (sig_bytes) => {
                      let signature = new Signature(
                        sign_protected,
                        sign_protected_serialized,
                        $List$Empty$const,
                        sig_bytes,
                      );
                      return new Ok(
                        new Body(
                          body.protected,
                          body.unprotected,
                          body.detached,
                          body.aad,
                          body.payload,
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
 * Finalize a signed body into a serializable COSE_Sign message.
 */
export function assemble(body) {
  let protected_serialized = $cose_structure.serialize_protected(body.protected);
  let _block;
  let $ = body.detached;
  if ($) {
    _block = $option.Option$None$const;
  } else {
    _block = new $option.Some(body.payload);
  }
  let stored_payload = _block;
  return new SignedSign(
    body.protected,
    protected_serialized,
    body.unprotected,
    stored_payload,
    $list.reverse(body.signatures),
  );
}

/**
 * Return the payload from a signed message. Returns `Error(Nil)` if detached.
 */
export function payload(message) {
  let payload$1 = message.payload;
  return $option.to_result(payload$1, undefined);
}

/**
 * Extract the key ID from the body-level headers.
 */
export function kid(message) {
  let protected$ = message.protected;
  let unprotected = message.unprotected;
  return $cose.kid($list.append(protected$, unprotected));
}

/**
 * Extract the content type from the body-level headers.
 */
export function content_type(message) {
  let protected$ = message.protected;
  let unprotected = message.unprotected;
  return $cose.content_type($list.append(protected$, unprotected));
}

/**
 * Extract the critical header labels from the body-level headers.
 */
export function critical(message) {
  let protected$ = message.protected;
  let unprotected = message.unprotected;
  return $cose.critical($list.append(protected$, unprotected));
}

/**
 * Return the raw body-level protected headers.
 */
export function protected_headers(message) {
  let protected$ = message.protected;
  return protected$;
}

/**
 * Return the raw body-level unprotected headers.
 */
export function unprotected_headers(message) {
  let unprotected = message.unprotected;
  return unprotected;
}

function serialize_signature(sig) {
  return new $cbor.Array(
    toList([
      new $cbor.Bytes(sig.protected_serialized),
      new $cbor.Map($cose.headers_to_cbor(sig.unprotected)),
      new $cbor.Bytes(sig.signature),
    ]),
  );
}

function to_cbor_value(message) {
  let protected_serialized = message.protected_serialized;
  let unprotected = message.unprotected;
  let payload$1 = message.payload;
  let signatures = message.signatures;
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
      new $cbor.Array($list.map(signatures, serialize_signature)),
    ]),
  );
}

/**
 * Encode a signed message as an untagged CBOR COSE_Sign array.
 */
export function serialize(message) {
  return $cbor.encode(to_cbor_value(message));
}

/**
 * Encode a signed message as a CBOR-tagged (tag 98) COSE_Sign structure.
 */
export function serialize_tagged(message) {
  return $cbor.encode(new $cbor.Tag(98, to_cbor_value(message)));
}

function parse_signature(value) {
  if (value instanceof $cbor.Array) {
    let $ = value[0];
    if ($ instanceof $Empty) {
      return new Error(new $gose.ParseError("invalid COSE_Signature structure"));
    } else {
      let $1 = $.tail;
      if ($1 instanceof $Empty) {
        return new Error(
          new $gose.ParseError("invalid COSE_Signature structure"),
        );
      } else {
        let $2 = $1.tail;
        if ($2 instanceof $Empty) {
          return new Error(
            new $gose.ParseError("invalid COSE_Signature structure"),
          );
        } else {
          let $3 = $2.tail;
          if ($3 instanceof $Empty) {
            let $4 = $.head;
            if ($4 instanceof $cbor.Bytes) {
              let $5 = $1.head;
              if ($5 instanceof $cbor.Map) {
                let $6 = $2.head;
                if ($6 instanceof $cbor.Bytes) {
                  let protected_serialized = $4[0];
                  let unprotected_pairs = $5[0];
                  let signature = $6[0];
                  return $result.try$(
                    $cose_structure.decode_protected(protected_serialized),
                    (protected$) => {
                      return $result.try$(
                        $cose_structure.decode_unprotected(unprotected_pairs),
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
                                  return new Ok(
                                    new Signature(
                                      protected$,
                                      protected_serialized,
                                      unprotected,
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
                } else {
                  return new Error(
                    new $gose.ParseError("invalid COSE_Signature structure"),
                  );
                }
              } else {
                return new Error(
                  new $gose.ParseError("invalid COSE_Signature structure"),
                );
              }
            } else {
              return new Error(
                new $gose.ParseError("invalid COSE_Signature structure"),
              );
            }
          } else {
            return new Error(
              new $gose.ParseError("invalid COSE_Signature structure"),
            );
          }
        }
      }
    }
  } else {
    return new Error(new $gose.ParseError("invalid COSE_Signature structure"));
  }
}

function parse_cbor_value(value) {
  return $result.try$(
    $cose_structure.parse_cose_array_value(value, 98, 4),
    (items) => {
      if (items instanceof $Empty) {
        return new Error(new $gose.ParseError("invalid COSE_Sign structure"));
      } else {
        let $ = items.tail;
        if ($ instanceof $Empty) {
          return new Error(new $gose.ParseError("invalid COSE_Sign structure"));
        } else {
          let $1 = $.tail;
          if ($1 instanceof $Empty) {
            return new Error(
              new $gose.ParseError("invalid COSE_Sign structure"),
            );
          } else {
            let $2 = $1.tail;
            if ($2 instanceof $Empty) {
              return new Error(
                new $gose.ParseError("invalid COSE_Sign structure"),
              );
            } else {
              let $3 = $2.tail;
              if ($3 instanceof $Empty) {
                let $4 = items.head;
                if ($4 instanceof $cbor.Bytes) {
                  let $5 = $.head;
                  if ($5 instanceof $cbor.Map) {
                    let $6 = $2.head;
                    if ($6 instanceof $cbor.Array) {
                      let payload_value = $1.head;
                      let protected_serialized = $4[0];
                      let unprotected_pairs = $5[0];
                      let signature_values = $6[0];
                      return $result.try$(
                        $cose_structure.decode_protected(protected_serialized),
                        (protected$) => {
                          return $result.try$(
                            $cose_structure.decode_unprotected(
                              unprotected_pairs,
                            ),
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
                                          return $result.try$(
                                            $list.try_map(
                                              signature_values,
                                              parse_signature,
                                            ),
                                            (signatures) => {
                                              return new Ok(
                                                new SignedSign(
                                                  protected$,
                                                  protected_serialized,
                                                  unprotected,
                                                  payload,
                                                  signatures,
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
                    } else {
                      return new Error(
                        new $gose.ParseError("invalid COSE_Sign structure"),
                      );
                    }
                  } else {
                    return new Error(
                      new $gose.ParseError("invalid COSE_Sign structure"),
                    );
                  }
                } else {
                  return new Error(
                    new $gose.ParseError("invalid COSE_Sign structure"),
                  );
                }
              } else {
                return new Error(
                  new $gose.ParseError("invalid COSE_Sign structure"),
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
 * Decode a CBOR-encoded COSE_Sign message, accepting both tagged and untagged forms.
 */
export function parse(data) {
  return $result.try$(
    $cbor.decode(data),
    (value) => { return parse_cbor_value(value); },
  );
}

/**
 * Build a verifier pinned to a single signature algorithm and one or more keys.
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

function try_verify_one_signature(
  sig,
  signing_alg,
  keys,
  body_protected,
  aad,
  payload
) {
  return $result.try$(
    $cose_structure.validate_crit(sig.protected, sig.unprotected),
    (_) => {
      let to_verify = build_sig_structure(
        body_protected,
        sig.protected_serialized,
        aad,
        payload,
      );
      return $cose_structure.try_verify_keys(
        signing_alg,
        keys,
        to_verify,
        sig.signature,
      );
    },
  );
}

function do_verify_signers(
  loop$signatures,
  loop$signing_alg,
  loop$keys,
  loop$body_protected,
  loop$aad,
  loop$payload,
  loop$last_error
) {
  while (true) {
    let signatures = loop$signatures;
    let signing_alg = loop$signing_alg;
    let keys = loop$keys;
    let body_protected = loop$body_protected;
    let aad = loop$aad;
    let payload = loop$payload;
    let last_error = loop$last_error;
    if (signatures instanceof $Empty) {
      return last_error;
    } else {
      let sig = signatures.head;
      let rest = signatures.tail;
      let $ = try_verify_one_signature(
        sig,
        signing_alg,
        keys,
        body_protected,
        aad,
        payload,
      );
      if ($ instanceof Ok) {
        return $;
      } else {
        let $1 = $[0];
        if ($1 instanceof $gose.CryptoError) {
          let e = $1;
          loop$signatures = rest;
          loop$signing_alg = signing_alg;
          loop$keys = keys;
          loop$body_protected = body_protected;
          loop$aad = aad;
          loop$payload = payload;
          loop$last_error = new Error(e);
        } else if ($1 instanceof $gose.VerificationFailed) {
          let e = $1;
          loop$signatures = rest;
          loop$signing_alg = signing_alg;
          loop$keys = keys;
          loop$body_protected = body_protected;
          loop$aad = aad;
          loop$payload = payload;
          loop$last_error = new Error(e);
        } else {
          return $;
        }
      }
    }
  }
}

function try_verify_signers(verifier, signatures, body_protected, aad, payload) {
  let expected_alg = verifier.alg;
  let keys = verifier.keys;
  let signing_alg = new $gose.DigitalSignature(expected_alg);
  let matching = $list.filter(
    signatures,
    (sig) => {
      return isEqual(
        $cose_structure.extract_signature_alg_from_headers(sig.protected),
        new Ok(expected_alg)
      );
    },
  );
  return do_verify_signers(
    matching,
    signing_alg,
    keys,
    body_protected,
    aad,
    payload,
    new Error($gose.GoseError$VerificationFailed$const),
  );
}

/**
 * Verify with externally-supplied AAD.
 */
export function verify_with_aad(verifier, message, aad) {
  let protected$ = message.protected;
  let protected_serialized = message.protected_serialized;
  let unprotected = message.unprotected;
  let payload$1 = message.payload;
  let signatures = message.signatures;
  return $result.try$(
    $cose_structure.validate_crit(protected$, unprotected),
    (_) => {
      return $result.try$(
        $cose_structure.require_embedded_payload(payload$1),
        (payload_bytes) => {
          return try_verify_signers(
            verifier,
            signatures,
            protected_serialized,
            aad,
            payload_bytes,
          );
        },
      );
    },
  );
}

/**
 * Verify the first matching signer's signature.
 */
export function verify(verifier, message) {
  return verify_with_aad(verifier, message, toBitArray([]));
}

/**
 * Verify a detached-payload message with external AAD.
 */
export function verify_detached_with_aad(verifier, message, payload, aad) {
  let protected$ = message.protected;
  let protected_serialized = message.protected_serialized;
  let unprotected = message.unprotected;
  let existing_payload = message.payload;
  let signatures = message.signatures;
  return $result.try$(
    $cose_structure.validate_crit(protected$, unprotected),
    (_) => {
      return $result.try$(
        $cose_structure.require_detached_payload(existing_payload),
        (_) => {
          return try_verify_signers(
            verifier,
            signatures,
            protected_serialized,
            aad,
            payload,
          );
        },
      );
    },
  );
}

/**
 * Verify a detached-payload message.
 */
export function verify_detached(verifier, message, payload) {
  return verify_detached_with_aad(verifier, message, payload, toBitArray([]));
}
