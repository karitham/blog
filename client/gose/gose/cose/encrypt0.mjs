import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
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
import * as $content_encryption from "../../gose/internal/content_encryption.mjs";
import * as $cose_structure from "../../gose/internal/cose_structure.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";

const FILEPATH = "src/gose/cose/encrypt0.gleam";

class Decryptor extends $CustomType {
  constructor(alg, key) {
    super();
    this.alg = alg;
    this.key = key;
  }
}

class UnencryptedEncrypt0 extends $CustomType {
  constructor(protected$, unprotected, aad) {
    super();
    this.protected = protected$;
    this.unprotected = unprotected;
    this.aad = aad;
  }
}

class EncryptedEncrypt0 extends $CustomType {
  constructor(protected$, protected_serialized, unprotected, ciphertext) {
    super();
    this.protected = protected$;
    this.protected_serialized = protected_serialized;
    this.unprotected = unprotected;
    this.ciphertext = ciphertext;
  }
}

/**
 * Create a new unencrypted COSE_Encrypt0 message with the given content encryption algorithm.
 */
export function new$(alg) {
  return $result.try$(
    $cose.content_alg_to_int(alg),
    (alg_id) => {
      return new Ok(
        new UnencryptedEncrypt0(
          toList([new $cose.Alg(alg_id)]),
          toList([]),
          toBitArray([]),
        ),
      );
    },
  );
}

function extract_cek(key) {
  return $gose.material_octet_secret($gose.material(key));
}

/**
 * Encrypt the plaintext with the given symmetric key.
 */
export function encrypt(message, key, plaintext) {
  let protected$;
  let unprotected;
  let aad;
  if (message instanceof UnencryptedEncrypt0) {
    protected$ = message.protected;
    unprotected = message.unprotected;
    aad = message.aad;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      84,
      "encrypt",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 2517,
        end: 2589,
        pattern_start: 2528,
        pattern_end: 2579
      }
    )
  }
  return $result.try$(
    $cose_structure.extract_content_alg_from_headers(protected$),
    (alg) => {
      return $result.try$(
        $key_helpers.validate_key_for_content_encryption(alg, key),
        (_) => {
          return $result.try$(
            extract_cek(key),
            (cek) => {
              let protected_serialized = $cose_structure.serialize_protected(
                protected$,
              );
              let iv = $content_encryption.generate_iv(alg);
              let aad$1 = $cose_structure.build_enc_structure(
                "Encrypt0",
                protected_serialized,
                aad,
              );
              return $result.try$(
                $content_encryption.encrypt_content(
                  alg,
                  cek,
                  iv,
                  aad$1,
                  plaintext,
                ),
                (_use0) => {
                  let ciphertext = _use0[0];
                  let tag = _use0[1];
                  let ciphertext_with_tag = $bit_array.concat(
                    toList([ciphertext, tag]),
                  );
                  let unprotected$1 = listPrepend(new $cose.Iv(iv), unprotected);
                  return new Ok(
                    new EncryptedEncrypt0(
                      protected$,
                      protected_serialized,
                      unprotected$1,
                      ciphertext_with_tag,
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
}

/**
 * Build a decryptor pinned to a single algorithm and key.
 */
export function decryptor(alg, key) {
  return $result.try$(
    $key_helpers.validate_key_for_content_decryption(alg, key),
    (_) => { return new Ok(new Decryptor(alg, key)); },
  );
}

/**
 * Decrypt with additional externally-supplied authenticated data (AAD).
 */
export function decrypt_with_aad(decryptor, message, aad) {
  let expected_alg = decryptor.alg;
  let key = decryptor.key;
  let protected$;
  let protected_serialized;
  let unprotected;
  let ciphertext_with_tag;
  if (message instanceof EncryptedEncrypt0) {
    protected$ = message.protected;
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    ciphertext_with_tag = message.ciphertext;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      144,
      "decrypt_with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 4228,
        end: 4369,
        pattern_start: 4239,
        pattern_end: 4359
      }
    )
  }
  return $result.try$(
    $cose_structure.extract_content_alg_from_serialized(protected_serialized),
    (actual_alg) => {
      return $result.try$(
        $key_helpers.require_matching_content_algorithm(
          expected_alg,
          actual_alg,
        ),
        (_) => {
          return $result.try$(
            $cose_structure.validate_crit(protected$, unprotected),
            (_) => {
              return $result.try$(
                extract_cek(key),
                (cek) => {
                  return $result.try$(
                    $cose.iv(unprotected),
                    (iv) => {
                      return $result.try$(
                        $cose_structure.split_ciphertext_tag(
                          ciphertext_with_tag,
                          $content_encryption.tag_size(expected_alg),
                        ),
                        (_use0) => {
                          let ciphertext = _use0[0];
                          let tag = _use0[1];
                          let aad$1 = $cose_structure.build_enc_structure(
                            "Encrypt0",
                            protected_serialized,
                            aad,
                          );
                          return $content_encryption.decrypt_content(
                            expected_alg,
                            cek,
                            iv,
                            aad$1,
                            ciphertext,
                            tag,
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
 * Decrypt a COSE_Encrypt0 message, returning the plaintext.
 */
export function decrypt(decryptor, message) {
  return decrypt_with_aad(decryptor, message, toBitArray([]));
}

function to_cbor_value(message) {
  let protected_serialized;
  let unprotected;
  let ciphertext;
  if (message instanceof EncryptedEncrypt0) {
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    ciphertext = message.ciphertext;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      193,
      "to_cbor_value",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 5612,
        end: 5725,
        pattern_start: 5623,
        pattern_end: 5715
      }
    )
  }
  return new $cbor.Array(
    toList([
      new $cbor.Bytes(protected_serialized),
      new $cbor.Map($cose.headers_to_cbor(unprotected)),
      new $cbor.Bytes(ciphertext),
    ]),
  );
}

/**
 * Encode an encrypted message as an untagged CBOR COSE_Encrypt0 array.
 */
export function serialize(message) {
  return $cbor.encode(to_cbor_value(message));
}

/**
 * Encode an encrypted message as a CBOR-tagged (tag 16) COSE_Encrypt0 structure.
 */
export function serialize_tagged(message) {
  return $cbor.encode(new $cbor.Tag(16, to_cbor_value(message)));
}

function parse_cbor_value(value) {
  return $result.try$(
    $cose_structure.parse_cose_array_value(value, 16, 3),
    (items) => {
      if (items instanceof $Empty) {
        return new Error(
          new $gose.ParseError("invalid COSE_Encrypt0 structure"),
        );
      } else {
        let $ = items.tail;
        if ($ instanceof $Empty) {
          return new Error(
            new $gose.ParseError("invalid COSE_Encrypt0 structure"),
          );
        } else {
          let $1 = $.tail;
          if ($1 instanceof $Empty) {
            return new Error(
              new $gose.ParseError("invalid COSE_Encrypt0 structure"),
            );
          } else {
            let $2 = $1.tail;
            if ($2 instanceof $Empty) {
              let $3 = items.head;
              if ($3 instanceof $cbor.Bytes) {
                let $4 = $.head;
                if ($4 instanceof $cbor.Map) {
                  let $5 = $1.head;
                  if ($5 instanceof $cbor.Bytes) {
                    let protected_serialized = $3[0];
                    let unprotected_cbor = $4[0];
                    let ciphertext = $5[0];
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
                                    return new Ok(
                                      new EncryptedEncrypt0(
                                        protected$,
                                        protected_serialized,
                                        unprotected,
                                        ciphertext,
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
                      new $gose.ParseError("invalid COSE_Encrypt0 structure"),
                    );
                  }
                } else {
                  return new Error(
                    new $gose.ParseError("invalid COSE_Encrypt0 structure"),
                  );
                }
              } else {
                return new Error(
                  new $gose.ParseError("invalid COSE_Encrypt0 structure"),
                );
              }
            } else {
              return new Error(
                new $gose.ParseError("invalid COSE_Encrypt0 structure"),
              );
            }
          }
        }
      }
    },
  );
}

/**
 * Decode a CBOR-encoded COSE_Encrypt0 message, accepting both tagged and untagged forms.
 */
export function parse(data) {
  return $result.try$(
    $cbor.decode(data),
    (value) => { return parse_cbor_value(value); },
  );
}

/**
 * Set external additional authenticated data (AAD) for the encryption operation.
 */
export function with_aad(message, aad) {
  if (!(message instanceof UnencryptedEncrypt0)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      218,
      "with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 6294,
        end: 6338,
        pattern_start: 6305,
        pattern_end: 6328
      }
    )
  }
  return new UnencryptedEncrypt0(message.protected, message.unprotected, aad);
}

/**
 * Add a key ID to the unprotected headers.
 */
export function with_kid(message, kid) {
  let unprotected;
  if (message instanceof UnencryptedEncrypt0) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      227,
      "with_kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 6525,
        end: 6583,
        pattern_start: 6536,
        pattern_end: 6573
      }
    )
  }
  return new UnencryptedEncrypt0(
    message.protected,
    listPrepend(new $cose.Kid(kid), unprotected),
    message.aad,
  );
}

/**
 * Add a content type to the protected headers.
 *
 * RFC 9052 permits either bucket. Encrypted messages place it in protected
 * so it is covered by the AEAD authentication.
 */
export function with_content_type(message, ct) {
  let protected$;
  if (message instanceof UnencryptedEncrypt0) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      239,
      "with_content_type",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 6962,
        end: 7018,
        pattern_start: 6973,
        pattern_end: 7008
      }
    )
  }
  return new UnencryptedEncrypt0(
    listPrepend(new $cose.ContentType(ct), protected$),
    message.unprotected,
    message.aad,
  );
}

/**
 * Add critical header labels to the protected headers.
 */
export function with_critical(message, labels) {
  let protected$;
  if (message instanceof UnencryptedEncrypt0) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      248,
      "with_critical",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 7268,
        end: 7324,
        pattern_start: 7279,
        pattern_end: 7314
      }
    )
  }
  return new UnencryptedEncrypt0(
    listPrepend(new $cose.Crit(labels), protected$),
    message.unprotected,
    message.aad,
  );
}

/**
 * Extract the key ID from the message headers.
 */
export function kid(message) {
  let protected$;
  let unprotected;
  if (message instanceof EncryptedEncrypt0) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      254,
      "kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 7536,
        end: 7604,
        pattern_start: 7547,
        pattern_end: 7594
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
  if (message instanceof EncryptedEncrypt0) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      262,
      "content_type",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 7814,
        end: 7882,
        pattern_start: 7825,
        pattern_end: 7872
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
  if (message instanceof EncryptedEncrypt0) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      270,
      "critical",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8100,
        end: 8168,
        pattern_start: 8111,
        pattern_end: 8158
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
  if (message instanceof EncryptedEncrypt0) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      276,
      "protected_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8343,
        end: 8397,
        pattern_start: 8354,
        pattern_end: 8387
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
  if (message instanceof EncryptedEncrypt0) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt0",
      282,
      "unprotected_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8535,
        end: 8591,
        pattern_start: 8546,
        pattern_end: 8581
      }
    )
  }
  return unprotected;
}
