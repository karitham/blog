import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $block from "../../../kryptos/kryptos/block.mjs";
import * as $crypto from "../../../kryptos/kryptos/crypto.mjs";
import * as $hash from "../../../kryptos/kryptos/hash.mjs";
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
import * as $cbor from "../../gose/cbor.mjs";
import * as $cose from "../../gose/cose.mjs";
import * as $content_encryption from "../../gose/internal/content_encryption.mjs";
import * as $cose_structure from "../../gose/internal/cose_structure.mjs";
import * as $key_encryption from "../../gose/internal/key_encryption.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";

const FILEPATH = "src/gose/cose/encrypt.gleam";

/**
 * ECDH-ES + HKDF-256 (COSE algorithm -25)
 */
export class EcdhEsHkdf256 extends $CustomType {}
export const EcdhEsDirectVariant$EcdhEsHkdf256 = () => new EcdhEsHkdf256();
export const EcdhEsDirectVariant$isEcdhEsHkdf256 = (value) =>
  value instanceof EcdhEsHkdf256;

/**
 * ECDH-ES + HKDF-512 (COSE algorithm -26)
 */
export class EcdhEsHkdf512 extends $CustomType {}
export const EcdhEsDirectVariant$EcdhEsHkdf512 = () => new EcdhEsHkdf512();
export const EcdhEsDirectVariant$isEcdhEsHkdf512 = (value) =>
  value instanceof EcdhEsHkdf512;

class PendingRecipient extends $CustomType {
  constructor(alg, key, ecdh_es_variant, apu, apv) {
    super();
    this.alg = alg;
    this.key = key;
    this.ecdh_es_variant = ecdh_es_variant;
    this.apu = apu;
    this.apv = apv;
  }
}

class Recipient extends $CustomType {
  constructor(pending) {
    super();
    this.pending = pending;
  }
}

class EncryptedRecipient extends $CustomType {
  constructor(protected$, protected_serialized, unprotected, ciphertext) {
    super();
    this.protected = protected$;
    this.protected_serialized = protected_serialized;
    this.unprotected = unprotected;
    this.ciphertext = ciphertext;
  }
}

class UnencryptedEncrypt extends $CustomType {
  constructor(content_alg, protected$, unprotected, recipients, aad) {
    super();
    this.content_alg = content_alg;
    this.protected = protected$;
    this.unprotected = unprotected;
    this.recipients = recipients;
    this.aad = aad;
  }
}

class EncryptedEncrypt extends $CustomType {
  constructor(protected$, protected_serialized, unprotected, ciphertext, recipients) {
    super();
    this.protected = protected$;
    this.protected_serialized = protected_serialized;
    this.unprotected = unprotected;
    this.ciphertext = ciphertext;
    this.recipients = recipients;
  }
}

class Decryptor extends $CustomType {
  constructor(key_alg, content_alg, keys, ecdh_es_variant) {
    super();
    this.key_alg = key_alg;
    this.content_alg = content_alg;
    this.keys = keys;
    this.ecdh_es_variant = ecdh_es_variant;
  }
}

/**
 * Create a new COSE_Encrypt message with the given content encryption algorithm.
 */
export function new$(enc) {
  return $result.try$(
    $cose.content_alg_to_int(enc),
    (alg_id) => {
      return new Ok(
        new UnencryptedEncrypt(
          enc,
          toList([new $cose.Alg(alg_id)]),
          toList([]),
          toList([]),
          toBitArray([]),
        ),
      );
    },
  );
}

function new_pending(alg, key, ecdh_es_variant) {
  return new Recipient(
    new PendingRecipient(
      alg,
      key,
      ecdh_es_variant,
      new $option.None(),
      new $option.None(),
    ),
  );
}

/**
 * Build a direct-shared-secret recipient.
 */
export function new_direct_recipient(key) {
  let alg = new $gose.Direct();
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(alg, key),
    (_) => { return new Ok(new_pending(alg, key, new $option.None())); },
  );
}

/**
 * Build an AES Key Wrap recipient.
 */
export function new_aes_kw_recipient(size, key) {
  let alg = new $gose.AesKeyWrap(new $gose.AesKw(), size);
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(alg, key),
    (_) => { return new Ok(new_pending(alg, key, new $option.None())); },
  );
}

/**
 * Build an RSA-OAEP recipient.
 */
export function new_rsa_recipient(rsa_alg, key) {
  let alg = new $gose.RsaEncryption(rsa_alg);
  return $result.try$(
    $cose.key_encryption_alg_to_int(alg),
    (_) => {
      return $result.try$(
        $key_helpers.validate_key_for_jwe_encryption(alg, key),
        (_) => { return new Ok(new_pending(alg, key, new $option.None())); },
      );
    },
  );
}

/**
 * Build an ECDH-ES direct recipient with a specific HKDF variant.
 */
export function new_ecdh_es_direct_recipient(variant, key) {
  let alg = new $gose.EcdhEs(new $gose.EcdhEsDirect());
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(alg, key),
    (_) => { return new Ok(new_pending(alg, key, new $option.Some(variant))); },
  );
}

/**
 * Build an ECDH-ES + AES-KW recipient.
 */
export function new_ecdh_es_aes_kw_recipient(size, key) {
  let alg = new $gose.EcdhEs(new $gose.EcdhEsAesKw(size));
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(alg, key),
    (_) => { return new Ok(new_pending(alg, key, new $option.None())); },
  );
}

/**
 * Set the PartyU identity (apu) for an ECDH-ES recipient.
 */
export function with_apu(r, apu) {
  return new Recipient(
    (() => {
      let _record = r.pending;
      return new PendingRecipient(
        _record.alg,
        _record.key,
        _record.ecdh_es_variant,
        new $option.Some(apu),
        _record.apv,
      );
    })(),
  );
}

/**
 * Set the PartyV identity (apv) for an ECDH-ES recipient.
 */
export function with_apv(r, apv) {
  return new Recipient(
    (() => {
      let _record = r.pending;
      return new PendingRecipient(
        _record.alg,
        _record.key,
        _record.ecdh_es_variant,
        _record.apu,
        new $option.Some(apv),
      );
    })(),
  );
}

/**
 * Add a built recipient to the message.
 */
export function add_recipient(message, recipient) {
  let recipients;
  if (message instanceof UnencryptedEncrypt) {
    recipients = message.recipients;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      222,
      "add_recipient",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 6735,
        end: 6791,
        pattern_start: 6746,
        pattern_end: 6781
      }
    )
  }
  return new UnencryptedEncrypt(
    message.content_alg,
    message.protected,
    message.unprotected,
    $list.append(recipients, toList([recipient.pending])),
    message.aad,
  );
}

/**
 * Set external additional authenticated data (AAD) for the encryption operation.
 */
export function with_aad(message, aad) {
  if (!(message instanceof UnencryptedEncrypt)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      234,
      "with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 7082,
        end: 7125,
        pattern_start: 7093,
        pattern_end: 7115
      }
    )
  }
  return new UnencryptedEncrypt(
    message.content_alg,
    message.protected,
    message.unprotected,
    message.recipients,
    aad,
  );
}

/**
 * Add a key ID to the unprotected headers.
 */
export function with_kid(message, kid) {
  let unprotected;
  if (message instanceof UnencryptedEncrypt) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      243,
      "with_kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 7309,
        end: 7366,
        pattern_start: 7320,
        pattern_end: 7356
      }
    )
  }
  return new UnencryptedEncrypt(
    message.content_alg,
    message.protected,
    listPrepend(new $cose.Kid(kid), unprotected),
    message.recipients,
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
  if (message instanceof UnencryptedEncrypt) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      255,
      "with_content_type",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 7742,
        end: 7797,
        pattern_start: 7753,
        pattern_end: 7787
      }
    )
  }
  return new UnencryptedEncrypt(
    message.content_alg,
    listPrepend(new $cose.ContentType(ct), protected$),
    message.unprotected,
    message.recipients,
    message.aad,
  );
}

/**
 * Add critical header labels to the protected headers.
 */
export function with_critical(message, labels) {
  let protected$;
  if (message instanceof UnencryptedEncrypt) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      264,
      "with_critical",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8044,
        end: 8099,
        pattern_start: 8055,
        pattern_end: 8089
      }
    )
  }
  return new UnencryptedEncrypt(
    message.content_alg,
    listPrepend(new $cose.Crit(labels), protected$),
    message.unprotected,
    message.recipients,
    message.aad,
  );
}

function epk_to_cbor(epk) {
  if (epk instanceof $key_encryption.EcEphemeralKey) {
    let curve = epk.curve;
    let x = epk.x;
    let y = epk.y;
    let crv_id = $cose.ec_curve_to_cose(curve);
    return new $cbor.Map(
      toList([
        [new $cbor.Int(1), new $cbor.Int(2)],
        [new $cbor.Int(-1), new $cbor.Int(crv_id)],
        [new $cbor.Int(-2), new $cbor.Bytes(x)],
        [new $cbor.Int(-3), new $cbor.Bytes(y)],
      ]),
    );
  } else {
    let curve = epk.curve;
    let x = epk.x;
    let crv_id = $cose.xdh_curve_to_cose(curve);
    return new $cbor.Map(
      toList([
        [new $cbor.Int(1), new $cbor.Int(1)],
        [new $cbor.Int(-1), new $cbor.Int(crv_id)],
        [new $cbor.Int(-2), new $cbor.Bytes(x)],
      ]),
    );
  }
}

function aes_kw_cose_id(size) {
  if (size instanceof $gose.Aes128) {
    return -3;
  } else if (size instanceof $gose.Aes192) {
    return -4;
  } else {
    return -5;
  }
}

function encode_party_info(identity) {
  let _block;
  if (identity instanceof $option.Some) {
    let bytes = identity[0];
    _block = new $cbor.Bytes(bytes);
  } else {
    _block = new $cbor.Null();
  }
  let identity_value = _block;
  return new $cbor.Array(
    toList([identity_value, new $cbor.Null(), new $cbor.Null()]),
  );
}

export function derive_cose_ecdh_key(
  shared_secret,
  hash_algorithm,
  algorithm_id,
  key_data_length,
  recipient_protected,
  party_u_identity,
  party_v_identity
) {
  let context = $cbor.encode(
    new $cbor.Array(
      toList([
        new $cbor.Int(algorithm_id),
        encode_party_info(party_u_identity),
        encode_party_info(party_v_identity),
        new $cbor.Array(
          toList([
            new $cbor.Int(key_data_length * 8),
            new $cbor.Bytes(recipient_protected),
          ]),
        ),
      ]),
    ),
  );
  let _pipe = $crypto.hkdf(
    hash_algorithm,
    shared_secret,
    new $option.None(),
    context,
    key_data_length,
  );
  return $result.replace_error(_pipe, new $gose.CryptoError("HKDF failed"));
}

function append_party_headers(headers, apu, apv) {
  let _block;
  if (apu instanceof $option.Some) {
    let bytes = apu[0];
    _block = listPrepend(
      new $cose.Unknown(new $cbor.Int(-21), new $cbor.Bytes(bytes)),
      headers,
    );
  } else {
    _block = headers;
  }
  let headers$1 = _block;
  if (apv instanceof $option.Some) {
    let bytes = apv[0];
    return listPrepend(
      new $cose.Unknown(new $cbor.Int(-24), new $cbor.Bytes(bytes)),
      headers$1,
    );
  } else {
    return headers$1;
  }
}

function encrypt_ecdh_es_aes_kw_recipient(key, cek, size, apu, apv) {
  return $result.try$(
    $cose.key_encryption_alg_to_int(
      new $gose.EcdhEs(new $gose.EcdhEsAesKw(size)),
    ),
    (alg_id) => {
      return $result.try$(
        $key_encryption.compute_ecdh_shared_secret(key),
        (_use0) => {
          let shared_secret = _use0[0];
          let epk = _use0[1];
          let protected$ = append_party_headers(toList([]), apu, apv);
          let protected_serialized = $cose_structure.serialize_protected(
            protected$,
          );
          let kw_key_len = $gose.aes_key_size(size);
          return $result.try$(
            derive_cose_ecdh_key(
              shared_secret,
              new $hash.Sha256(),
              aes_kw_cose_id(size),
              kw_key_len,
              protected_serialized,
              apu,
              apv,
            ),
            (kek) => {
              return $result.try$(
                $content_encryption.aes_cipher(size, kek),
                (cipher) => {
                  return $result.try$(
                    (() => {
                      let _pipe = $block.wrap(cipher, cek);
                      return $result.replace_error(
                        _pipe,
                        new $gose.CryptoError("AES Key Wrap failed"),
                      );
                    })(),
                    (wrapped) => {
                      return new Ok(
                        new EncryptedRecipient(
                          protected$,
                          protected_serialized,
                          toList([
                            new $cose.Alg(alg_id),
                            new $cose.Unknown(
                              new $cbor.Int(-1),
                              epk_to_cbor(epk),
                            ),
                          ]),
                          wrapped,
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

function rsa_hash_for_alg(rsa_alg) {
  if (rsa_alg instanceof $gose.RsaPkcs1v15) {
    return new Error(
      new $gose.InvalidState("RSA-PKCS1v15 is not supported in COSE"),
    );
  } else if (rsa_alg instanceof $gose.RsaOaepSha1) {
    return new Ok(new $hash.Sha1());
  } else {
    return new Ok(new $hash.Sha256());
  }
}

function encrypt_rsa_oaep_recipient(key, cek, rsa_alg) {
  return $result.try$(
    $cose.key_encryption_alg_to_int(new $gose.RsaEncryption(rsa_alg)),
    (alg_id) => {
      return $result.try$(
        rsa_hash_for_alg(rsa_alg),
        (hash_alg) => {
          return $result.try$(
            $key_encryption.wrap_rsa_oaep(key, cek, hash_alg),
            (encrypted_cek) => {
              return new Ok(
                new EncryptedRecipient(
                  toList([]),
                  toBitArray([]),
                  toList([new $cose.Alg(alg_id)]),
                  encrypted_cek,
                ),
              );
            },
          );
        },
      );
    },
  );
}

function encrypt_aes_kw_recipient(key, cek, size) {
  return $result.try$(
    $cose.key_encryption_alg_to_int(
      new $gose.AesKeyWrap(new $gose.AesKw(), size),
    ),
    (alg_id) => {
      return $result.try$(
        $key_encryption.wrap_aes_kw(key, cek, size),
        (encrypted_cek) => {
          return new Ok(
            new EncryptedRecipient(
              toList([]),
              toBitArray([]),
              toList([new $cose.Alg(alg_id)]),
              encrypted_cek,
            ),
          );
        },
      );
    },
  );
}

function wrap_recipient(recipient, cek) {
  let $ = recipient.alg;
  if ($ instanceof $gose.Direct) {
    return new Error(
      new $gose.InvalidState(
        "unsupported key encryption algorithm for COSE_Encrypt",
      ),
    );
  } else if ($ instanceof $gose.AesKeyWrap) {
    let $1 = $[0];
    if ($1 instanceof $gose.AesKw) {
      let size = $[1];
      return encrypt_aes_kw_recipient(recipient.key, cek, size);
    } else {
      return new Error(
        new $gose.InvalidState(
          "unsupported key encryption algorithm for COSE_Encrypt",
        ),
      );
    }
  } else if ($ instanceof $gose.ChaCha20KeyWrap) {
    return new Error(
      new $gose.InvalidState(
        "unsupported key encryption algorithm for COSE_Encrypt",
      ),
    );
  } else if ($ instanceof $gose.RsaEncryption) {
    let rsa_alg = $[0];
    return encrypt_rsa_oaep_recipient(recipient.key, cek, rsa_alg);
  } else if ($ instanceof $gose.EcdhEs) {
    let $1 = $[0];
    if ($1 instanceof $gose.EcdhEsDirect) {
      return new Error(
        new $gose.InvalidState(
          "unsupported key encryption algorithm for COSE_Encrypt",
        ),
      );
    } else if ($1 instanceof $gose.EcdhEsAesKw) {
      let size = $1[0];
      return encrypt_ecdh_es_aes_kw_recipient(
        recipient.key,
        cek,
        size,
        recipient.apu,
        recipient.apv,
      );
    } else {
      return new Error(
        new $gose.InvalidState(
          "unsupported key encryption algorithm for COSE_Encrypt",
        ),
      );
    }
  } else {
    return new Error(
      new $gose.InvalidState(
        "unsupported key encryption algorithm for COSE_Encrypt",
      ),
    );
  }
}

function ecdh_variant_hash_algorithm(variant) {
  if (variant instanceof EcdhEsHkdf256) {
    return new $hash.Sha256();
  } else {
    return new $hash.Sha512();
  }
}

function ecdh_variant_to_cose_id(variant) {
  if (variant instanceof EcdhEsHkdf256) {
    return -25;
  } else {
    return -26;
  }
}

function encrypt_ecdh_es_direct(key, content_alg, variant, apu, apv) {
  return $result.try$(
    $key_encryption.compute_ecdh_shared_secret(key),
    (_use0) => {
      let shared_secret = _use0[0];
      let epk = _use0[1];
      return $result.try$(
        $cose.content_alg_to_int(content_alg),
        (content_alg_id) => {
          let alg_id = ecdh_variant_to_cose_id(variant);
          let key_len = $gose.content_alg_key_size(content_alg);
          let protected$ = append_party_headers(
            toList([new $cose.Alg(alg_id)]),
            apu,
            apv,
          );
          let recipient_protected = $cose_structure.serialize_protected(
            protected$,
          );
          return $result.try$(
            derive_cose_ecdh_key(
              shared_secret,
              ecdh_variant_hash_algorithm(variant),
              content_alg_id,
              key_len,
              recipient_protected,
              apu,
              apv,
            ),
            (cek) => {
              let recipient = new EncryptedRecipient(
                protected$,
                recipient_protected,
                toList([new $cose.Unknown(new $cbor.Int(-1), epk_to_cbor(epk))]),
                toBitArray([]),
              );
              return new Ok([cek, toList([recipient])]);
            },
          );
        },
      );
    },
  );
}

function encrypt_direct_recipient() {
  return new Ok(
    new EncryptedRecipient(
      toList([]),
      toBitArray([]),
      toList([new $cose.Alg(-6)]),
      toBitArray([]),
    ),
  );
}

function generate_cek_and_wrap_recipients(content_alg, recipients) {
  if (recipients instanceof $Empty) {
    let cek = $content_encryption.generate_cek(content_alg);
    return $result.try$(
      $list.try_map(
        recipients,
        (_capture) => { return wrap_recipient(_capture, cek); },
      ),
      (encrypted_recipients) => { return new Ok([cek, encrypted_recipients]); },
    );
  } else {
    let $ = recipients.tail;
    if ($ instanceof $Empty) {
      let $1 = recipients.head.alg;
      if ($1 instanceof $gose.Direct) {
        let key = recipients.head.key;
        return $result.try$(
          $key_encryption.unwrap_direct(key, content_alg),
          (cek) => {
            return $result.try$(
              encrypt_direct_recipient(),
              (recipient) => { return new Ok([cek, toList([recipient])]); },
            );
          },
        );
      } else if ($1 instanceof $gose.EcdhEs) {
        let $2 = recipients.head.ecdh_es_variant;
        if ($2 instanceof $option.Some) {
          let $3 = $1[0];
          if ($3 instanceof $gose.EcdhEsDirect) {
            let key = recipients.head.key;
            let apu = recipients.head.apu;
            let apv = recipients.head.apv;
            let variant = $2[0];
            return encrypt_ecdh_es_direct(key, content_alg, variant, apu, apv);
          } else {
            let cek = $content_encryption.generate_cek(content_alg);
            return $result.try$(
              $list.try_map(
                recipients,
                (_capture) => { return wrap_recipient(_capture, cek); },
              ),
              (encrypted_recipients) => {
                return new Ok([cek, encrypted_recipients]);
              },
            );
          }
        } else {
          let cek = $content_encryption.generate_cek(content_alg);
          return $result.try$(
            $list.try_map(
              recipients,
              (_capture) => { return wrap_recipient(_capture, cek); },
            ),
            (encrypted_recipients) => {
              return new Ok([cek, encrypted_recipients]);
            },
          );
        }
      } else {
        let cek = $content_encryption.generate_cek(content_alg);
        return $result.try$(
          $list.try_map(
            recipients,
            (_capture) => { return wrap_recipient(_capture, cek); },
          ),
          (encrypted_recipients) => {
            return new Ok([cek, encrypted_recipients]);
          },
        );
      }
    } else {
      let cek = $content_encryption.generate_cek(content_alg);
      return $result.try$(
        $list.try_map(
          recipients,
          (_capture) => { return wrap_recipient(_capture, cek); },
        ),
        (encrypted_recipients) => { return new Ok([cek, encrypted_recipients]); },
      );
    }
  }
}

function validate_single_recipient_constraint(recipients, continue$) {
  let has_direct = $list.any(
    recipients,
    (r) => {
      let $ = r.alg;
      if ($ instanceof $gose.Direct) {
        return true;
      } else if ($ instanceof $gose.AesKeyWrap) {
        return false;
      } else if ($ instanceof $gose.ChaCha20KeyWrap) {
        return false;
      } else if ($ instanceof $gose.RsaEncryption) {
        return false;
      } else if ($ instanceof $gose.EcdhEs) {
        let $1 = $[0];
        if ($1 instanceof $gose.EcdhEsDirect) {
          return true;
        } else if ($1 instanceof $gose.EcdhEsAesKw) {
          return false;
        } else {
          return false;
        }
      } else {
        return false;
      }
    },
  );
  return $bool.guard(
    has_direct && ($list.length(recipients) > 1),
    new Error(
      new $gose.InvalidState(
        "Direct and ECDH-ES Direct key agreement require exactly one recipient",
      ),
    ),
    () => { return continue$(); },
  );
}

function require_non_empty_recipients(recipients, continue$) {
  return $bool.guard(
    $list.is_empty(recipients),
    new Error(new $gose.InvalidState("at least one recipient required")),
    () => { return continue$(); },
  );
}

/**
 * Encrypt the plaintext for all added recipients.
 *
 * Reads `aad` from the builder state set via `with_aad`.
 */
export function encrypt(message, plaintext) {
  let content_alg;
  let protected$;
  let unprotected;
  let recipients;
  let aad;
  if (message instanceof UnencryptedEncrypt) {
    content_alg = message.content_alg;
    protected$ = message.protected;
    unprotected = message.unprotected;
    recipients = message.recipients;
    aad = message.aad;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      275,
      "encrypt",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8429,
        end: 8552,
        pattern_start: 8440,
        pattern_end: 8542
      }
    )
  }
  return require_non_empty_recipients(
    recipients,
    () => {
      return validate_single_recipient_constraint(
        recipients,
        () => {
          let protected_serialized = $cose_structure.serialize_protected(
            protected$,
          );
          return $result.try$(
            generate_cek_and_wrap_recipients(content_alg, recipients),
            (_use0) => {
              let cek = _use0[0];
              let encrypted_recipients = _use0[1];
              let iv = $content_encryption.generate_iv(content_alg);
              let enc_structure = $cose_structure.build_enc_structure(
                "Encrypt",
                protected_serialized,
                aad,
              );
              return $result.try$(
                $content_encryption.encrypt_content(
                  content_alg,
                  cek,
                  iv,
                  enc_structure,
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
                    new EncryptedEncrypt(
                      protected$,
                      protected_serialized,
                      unprotected$1,
                      ciphertext_with_tag,
                      encrypted_recipients,
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
 * Build a decryptor pinned to expected algorithms and keys.
 *
 * For `EcdhEs(EcdhEsDirect)`, use `ecdh_es_direct_decryptor` instead so the
 * HKDF variant (HKDF-256 or HKDF-512) is chosen explicitly.
 */
export function decryptor(key_alg, content_alg, keys) {
  return $bool.guard(
    isEqual(key_alg, new $gose.EcdhEs(new $gose.EcdhEsDirect())),
    new Error(
      new $gose.InvalidState(
        "use ecdh_es_direct_decryptor to choose HKDF variant",
      ),
    ),
    () => {
      return $result.try$(
        $cose.key_encryption_alg_to_int(key_alg),
        (_) => {
          return $key_helpers.require_non_empty_keys(
            keys,
            () => {
              return $result.try$(
                $list.try_each(
                  keys,
                  (_capture) => {
                    return $key_helpers.validate_key_for_jwe_decryption(
                      key_alg,
                      _capture,
                    );
                  },
                ),
                (_) => {
                  return new Ok(
                    new Decryptor(
                      key_alg,
                      content_alg,
                      keys,
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
}

/**
 * Build a decryptor for ECDH-ES direct with a specific HKDF variant.
 *
 * Use this instead of `decryptor` when you need to decrypt messages
 * encrypted with ECDH-ES+HKDF-512 (COSE algorithm -26).
 */
export function ecdh_es_direct_decryptor(variant, content_alg, keys) {
  let key_alg = new $gose.EcdhEs(new $gose.EcdhEsDirect());
  return $key_helpers.require_non_empty_keys(
    keys,
    () => {
      return $result.try$(
        $list.try_each(
          keys,
          (_capture) => {
            return $key_helpers.validate_key_for_jwe_decryption(
              key_alg,
              _capture,
            );
          },
        ),
        (_) => {
          return new Ok(
            new Decryptor(key_alg, content_alg, keys, new $option.Some(variant)),
          );
        },
      );
    },
  );
}

function find_unknown_bytes(loop$headers, loop$label) {
  while (true) {
    let headers = loop$headers;
    let label = loop$label;
    if (headers instanceof $Empty) {
      return new $option.None();
    } else {
      let $ = headers.head;
      if ($ instanceof $cose.Unknown) {
        let $1 = $[0];
        if ($1 instanceof $cbor.Int) {
          let $2 = $[1];
          if ($2 instanceof $cbor.Bytes) {
            let found = $1[0];
            if (found === label) {
              let b = $2[0];
              return new $option.Some(b);
            } else {
              let rest = headers.tail;
              loop$headers = rest;
              loop$label = label;
            }
          } else {
            let rest = headers.tail;
            loop$headers = rest;
            loop$label = label;
          }
        } else {
          let rest = headers.tail;
          loop$headers = rest;
          loop$label = label;
        }
      } else {
        let rest = headers.tail;
        loop$headers = rest;
        loop$label = label;
      }
    }
  }
}

function extract_party_v(headers) {
  return find_unknown_bytes(headers, -24);
}

function extract_party_u(headers) {
  return find_unknown_bytes(headers, -21);
}

function lookup_bytes(pairs, label, error_msg) {
  let $ = $list.key_find(pairs, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Bytes) {
      let v = $1[0];
      return new Ok(v);
    } else {
      return new Error(new $gose.ParseError(error_msg));
    }
  } else {
    return new Error(new $gose.ParseError(error_msg));
  }
}

function lookup_int(pairs, label, error_msg) {
  let $ = $list.key_find(pairs, new $cbor.Int(label));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Int) {
      let v = $1[0];
      return new Ok(v);
    } else {
      return new Error(new $gose.ParseError(error_msg));
    }
  } else {
    return new Error(new $gose.ParseError(error_msg));
  }
}

function parse_okp_epk(pairs) {
  return $result.try$(
    lookup_int(pairs, -1, "missing OKP curve in EPK"),
    (crv_id) => {
      return $result.try$(
        $cose.xdh_curve_from_cose(crv_id),
        (curve) => {
          return $result.try$(
            lookup_bytes(pairs, -2, "missing OKP x in EPK"),
            (x) => {
              return new Ok(new $key_encryption.XdhEphemeralKey(curve, x));
            },
          );
        },
      );
    },
  );
}

function parse_ec_epk(pairs) {
  return $result.try$(
    lookup_int(pairs, -1, "missing EC curve in EPK"),
    (crv_id) => {
      return $result.try$(
        $cose.ec_curve_from_cose(crv_id),
        (curve) => {
          return $result.try$(
            lookup_bytes(pairs, -2, "missing EC x in EPK"),
            (x) => {
              return $result.try$(
                lookup_bytes(pairs, -3, "missing EC y in EPK"),
                (y) => {
                  return new Ok(new $key_encryption.EcEphemeralKey(curve, x, y));
                },
              );
            },
          );
        },
      );
    },
  );
}

function parse_epk(pairs) {
  let $ = $list.key_find(pairs, new $cbor.Int(1));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Int) {
      let $2 = $1[0];
      if ($2 === 2) {
        return parse_ec_epk(pairs);
      } else if ($2 === 1) {
        return parse_okp_epk(pairs);
      } else {
        return new Error(new $gose.ParseError("unsupported EPK key type"));
      }
    } else {
      return new Error(new $gose.ParseError("unsupported EPK key type"));
    }
  } else {
    return new Error(new $gose.ParseError("unsupported EPK key type"));
  }
}

function find_unknown_header(headers, key) {
  return $list.find_map(
    headers,
    (header) => {
      if (header instanceof $cose.Unknown) {
        let k = header[0];
        if (isEqual(k, key)) {
          let v = header[1];
          return new Ok(v);
        } else {
          return new Error(undefined);
        }
      } else {
        return new Error(undefined);
      }
    },
  );
}

function extract_epk(unprotected) {
  let $ = find_unknown_header(unprotected, new $cbor.Int(-1));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Map) {
      let pairs = $1[0];
      return parse_epk(pairs);
    } else {
      return new Error(
        new $gose.ParseError(
          "missing ephemeral public key (label -1) in recipient",
        ),
      );
    }
  } else {
    return new Error(
      new $gose.ParseError(
        "missing ephemeral public key (label -1) in recipient",
      ),
    );
  }
}

function unwrap_ecdh_es_aes_kw(recipient, key, size) {
  return $result.try$(
    extract_epk(recipient.unprotected),
    (epk) => {
      return $result.try$(
        $key_encryption.compute_ecdh_shared_secret_with_epk(key, epk),
        (shared_secret) => {
          let kw_key_len = $gose.aes_key_size(size);
          return $result.try$(
            derive_cose_ecdh_key(
              shared_secret,
              new $hash.Sha256(),
              aes_kw_cose_id(size),
              kw_key_len,
              recipient.protected_serialized,
              extract_party_u(recipient.protected),
              extract_party_v(recipient.protected),
            ),
            (kek) => {
              return $result.try$(
                $content_encryption.aes_cipher(size, kek),
                (cipher) => {
                  let _pipe = $block.unwrap(cipher, recipient.ciphertext);
                  return $result.replace_error(
                    _pipe,
                    new $gose.CryptoError("AES Key Unwrap failed"),
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

function unwrap_ecdh_es_direct(recipient, key, content_alg, variant) {
  return $result.try$(
    extract_epk(recipient.unprotected),
    (epk) => {
      return $result.try$(
        $key_encryption.compute_ecdh_shared_secret_with_epk(key, epk),
        (shared_secret) => {
          return $result.try$(
            $cose.content_alg_to_int(content_alg),
            (content_alg_id) => {
              let key_len = $gose.content_alg_key_size(content_alg);
              return derive_cose_ecdh_key(
                shared_secret,
                ecdh_variant_hash_algorithm(variant),
                content_alg_id,
                key_len,
                recipient.protected_serialized,
                extract_party_u(recipient.protected),
                extract_party_v(recipient.protected),
              );
            },
          );
        },
      );
    },
  );
}

function unwrap_cek(recipient, key, key_alg, content_alg, ecdh_es_variant) {
  if (key_alg instanceof $gose.Direct) {
    return $key_encryption.unwrap_direct(key, content_alg);
  } else if (key_alg instanceof $gose.AesKeyWrap) {
    let $ = key_alg[0];
    if ($ instanceof $gose.AesKw) {
      let size = key_alg[1];
      return $key_encryption.unwrap_aes_kw(key, recipient.ciphertext, size);
    } else {
      return new Error(
        new $gose.InvalidState(
          "unsupported key encryption algorithm for COSE_Encrypt",
        ),
      );
    }
  } else if (key_alg instanceof $gose.ChaCha20KeyWrap) {
    return new Error(
      new $gose.InvalidState(
        "unsupported key encryption algorithm for COSE_Encrypt",
      ),
    );
  } else if (key_alg instanceof $gose.RsaEncryption) {
    let rsa_alg = key_alg[0];
    return $result.try$(
      rsa_hash_for_alg(rsa_alg),
      (hash_alg) => {
        return $key_encryption.unwrap_rsa_oaep(
          key,
          recipient.ciphertext,
          hash_alg,
        );
      },
    );
  } else if (key_alg instanceof $gose.EcdhEs) {
    let $ = key_alg[0];
    if ($ instanceof $gose.EcdhEsDirect) {
      let variant;
      if (ecdh_es_variant instanceof $option.Some) {
        variant = ecdh_es_variant[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/cose/encrypt",
          971,
          "unwrap_cek",
          "Pattern match failed, no pattern matched the value.",
          {
            value: ecdh_es_variant,
            start: 27501,
            end: 27550,
            pattern_start: 27512,
            pattern_end: 27532
          }
        )
      }
      return unwrap_ecdh_es_direct(recipient, key, content_alg, variant);
    } else if ($ instanceof $gose.EcdhEsAesKw) {
      let size = $[0];
      return unwrap_ecdh_es_aes_kw(recipient, key, size);
    } else {
      return new Error(
        new $gose.InvalidState(
          "unsupported key encryption algorithm for COSE_Encrypt",
        ),
      );
    }
  } else {
    return new Error(
      new $gose.InvalidState(
        "unsupported key encryption algorithm for COSE_Encrypt",
      ),
    );
  }
}

function unwrap_and_decrypt(
  recipient,
  key,
  key_alg,
  content_alg,
  ecdh_es_variant,
  iv,
  enc_structure,
  ciphertext,
  tag
) {
  return $result.try$(
    unwrap_cek(recipient, key, key_alg, content_alg, ecdh_es_variant),
    (cek) => {
      return $content_encryption.decrypt_content(
        content_alg,
        cek,
        iv,
        enc_structure,
        ciphertext,
        tag,
      );
    },
  );
}

function try_keys(
  loop$keys,
  loop$recipient,
  loop$key_alg,
  loop$content_alg,
  loop$ecdh_es_variant,
  loop$iv,
  loop$enc_structure,
  loop$ciphertext,
  loop$tag,
  loop$last_error
) {
  while (true) {
    let keys = loop$keys;
    let recipient = loop$recipient;
    let key_alg = loop$key_alg;
    let content_alg = loop$content_alg;
    let ecdh_es_variant = loop$ecdh_es_variant;
    let iv = loop$iv;
    let enc_structure = loop$enc_structure;
    let ciphertext = loop$ciphertext;
    let tag = loop$tag;
    let last_error = loop$last_error;
    if (keys instanceof $Empty) {
      return last_error;
    } else {
      let key = keys.head;
      let rest = keys.tail;
      let result = unwrap_and_decrypt(
        recipient,
        key,
        key_alg,
        content_alg,
        ecdh_es_variant,
        iv,
        enc_structure,
        ciphertext,
        tag,
      );
      if (result instanceof Ok) {
        return result;
      } else {
        let $ = result[0];
        if ($ instanceof $gose.CryptoError) {
          let e = $;
          loop$keys = rest;
          loop$recipient = recipient;
          loop$key_alg = key_alg;
          loop$content_alg = content_alg;
          loop$ecdh_es_variant = ecdh_es_variant;
          loop$iv = iv;
          loop$enc_structure = enc_structure;
          loop$ciphertext = ciphertext;
          loop$tag = tag;
          loop$last_error = new Error(e);
        } else {
          return result;
        }
      }
    }
  }
}

function try_keys_for_recipient(
  recipient,
  keys,
  key_alg,
  content_alg,
  ecdh_es_variant,
  iv,
  enc_structure,
  ciphertext,
  tag
) {
  return $result.try$(
    $cose_structure.validate_crit(recipient.protected, recipient.unprotected),
    (_) => {
      return try_keys(
        keys,
        recipient,
        key_alg,
        content_alg,
        ecdh_es_variant,
        iv,
        enc_structure,
        ciphertext,
        tag,
        new Error(new $gose.CryptoError("no key could decrypt")),
      );
    },
  );
}

function try_decrypt_recipients(
  loop$recipients,
  loop$keys,
  loop$key_alg,
  loop$content_alg,
  loop$ecdh_es_variant,
  loop$iv,
  loop$enc_structure,
  loop$ciphertext,
  loop$tag,
  loop$last_error
) {
  while (true) {
    let recipients = loop$recipients;
    let keys = loop$keys;
    let key_alg = loop$key_alg;
    let content_alg = loop$content_alg;
    let ecdh_es_variant = loop$ecdh_es_variant;
    let iv = loop$iv;
    let enc_structure = loop$enc_structure;
    let ciphertext = loop$ciphertext;
    let tag = loop$tag;
    let last_error = loop$last_error;
    if (recipients instanceof $Empty) {
      return last_error;
    } else {
      let recipient = recipients.head;
      let rest = recipients.tail;
      let result = try_keys_for_recipient(
        recipient,
        keys,
        key_alg,
        content_alg,
        ecdh_es_variant,
        iv,
        enc_structure,
        ciphertext,
        tag,
      );
      if (result instanceof Ok) {
        return result;
      } else {
        let $ = result[0];
        if ($ instanceof $gose.CryptoError) {
          let e = $;
          loop$recipients = rest;
          loop$keys = keys;
          loop$key_alg = key_alg;
          loop$content_alg = content_alg;
          loop$ecdh_es_variant = ecdh_es_variant;
          loop$iv = iv;
          loop$enc_structure = enc_structure;
          loop$ciphertext = ciphertext;
          loop$tag = tag;
          loop$last_error = new Error(e);
        } else {
          return result;
        }
      }
    }
  }
}

function recipient_alg(recipient) {
  let _pipe = $cose_structure.extract_key_encryption_alg_from_headers(
    recipient.protected,
  );
  return $result.lazy_or(
    _pipe,
    () => {
      return $cose_structure.extract_key_encryption_alg_from_headers(
        recipient.unprotected,
      );
    },
  );
}

/**
 * Decrypt with externally-supplied AAD.
 */
export function decrypt_with_aad(decryptor, message, aad) {
  let expected_key_alg = decryptor.key_alg;
  let expected_content_alg = decryptor.content_alg;
  let keys = decryptor.keys;
  let ecdh_es_variant = decryptor.ecdh_es_variant;
  let protected$;
  let protected_serialized;
  let unprotected;
  let ciphertext_with_tag;
  let recipients;
  if (message instanceof EncryptedEncrypt) {
    protected$ = message.protected;
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    ciphertext_with_tag = message.ciphertext;
    recipients = message.recipients;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      384,
      "decrypt_with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 11567,
        end: 11724,
        pattern_start: 11578,
        pattern_end: 11714
      }
    )
  }
  return $result.try$(
    $cose_structure.extract_content_alg_from_serialized(protected_serialized),
    (actual_content_alg) => {
      return $result.try$(
        $key_helpers.require_matching_content_algorithm(
          expected_content_alg,
          actual_content_alg,
        ),
        (_) => {
          return $result.try$(
            $cose_structure.validate_crit(protected$, unprotected),
            (_) => {
              let matching_recipients = $list.filter(
                recipients,
                (r) => {
                  return isEqual(recipient_alg(r), new Ok(expected_key_alg));
                },
              );
              return $result.try$(
                $cose.iv(unprotected),
                (iv) => {
                  return $result.try$(
                    $cose_structure.split_ciphertext_tag(
                      ciphertext_with_tag,
                      $content_encryption.tag_size(actual_content_alg),
                    ),
                    (_use0) => {
                      let ciphertext = _use0[0];
                      let tag = _use0[1];
                      let enc_structure = $cose_structure.build_enc_structure(
                        "Encrypt",
                        protected_serialized,
                        aad,
                      );
                      return try_decrypt_recipients(
                        matching_recipients,
                        keys,
                        expected_key_alg,
                        actual_content_alg,
                        ecdh_es_variant,
                        iv,
                        enc_structure,
                        ciphertext,
                        tag,
                        new Error(
                          new $gose.CryptoError("no matching recipient found"),
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
 * Decrypt a COSE_Encrypt message.
 */
export function decrypt(decryptor, message) {
  return decrypt_with_aad(decryptor, message, toBitArray([]));
}

function serialize_recipient(recipient) {
  return new $cbor.Array(
    toList([
      new $cbor.Bytes(recipient.protected_serialized),
      new $cbor.Map($cose.headers_to_cbor(recipient.unprotected)),
      new $cbor.Bytes(recipient.ciphertext),
    ]),
  );
}

function to_cbor_value(message) {
  let protected_serialized;
  let unprotected;
  let ciphertext;
  let recipients;
  if (message instanceof EncryptedEncrypt) {
    protected_serialized = message.protected_serialized;
    unprotected = message.unprotected;
    ciphertext = message.ciphertext;
    recipients = message.recipients;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      442,
      "to_cbor_value",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 13198,
        end: 13327,
        pattern_start: 13209,
        pattern_end: 13317
      }
    )
  }
  return new $cbor.Array(
    toList([
      new $cbor.Bytes(protected_serialized),
      new $cbor.Map($cose.headers_to_cbor(unprotected)),
      new $cbor.Bytes(ciphertext),
      new $cbor.Array($list.map(recipients, serialize_recipient)),
    ]),
  );
}

/**
 * Encode an encrypted message as an untagged CBOR COSE_Encrypt array.
 */
export function serialize(message) {
  return $cbor.encode(to_cbor_value(message));
}

/**
 * Encode an encrypted message as a CBOR-tagged (tag 96) COSE_Encrypt structure.
 */
export function serialize_tagged(message) {
  return $cbor.encode(new $cbor.Tag(96, to_cbor_value(message)));
}

function validate_no_private_epk(unprotected, continue$) {
  let $ = find_unknown_header(unprotected, new $cbor.Int(-1));
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $cbor.Map) {
      let epk_pairs = $1[0];
      let has_private = $list.any(
        epk_pairs,
        (pair) => { return isEqual(pair[0], new $cbor.Int(-4)); },
      );
      return $bool.guard(
        has_private,
        new Error(
          new $gose.ParseError(
            "ephemeral public key must not contain private material",
          ),
        ),
        () => { return continue$(); },
      );
    } else {
      return continue$();
    }
  } else {
    return continue$();
  }
}

function parse_recipient_fields(
  protected_serialized,
  unprotected_cbor,
  ciphertext
) {
  return $result.try$(
    $cose_structure.decode_protected(protected_serialized),
    (protected$) => {
      return $result.try$(
        $cose_structure.decode_unprotected(unprotected_cbor),
        (unprotected) => {
          return $result.try$(
            $cose_structure.validate_no_header_overlap(protected$, unprotected),
            (_) => {
              return $result.try$(
                $cose_structure.validate_iv_partial_iv_exclusion(
                  protected$,
                  unprotected,
                ),
                (_) => {
                  return validate_no_private_epk(
                    unprotected,
                    () => {
                      return new Ok(
                        new EncryptedRecipient(
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
    },
  );
}

function parse_recipient(value) {
  if (value instanceof $cbor.Array) {
    let $ = value[0];
    if ($ instanceof $Empty) {
      return new Error(new $gose.ParseError("invalid COSE_recipient structure"));
    } else {
      let $1 = $.tail;
      if ($1 instanceof $Empty) {
        return new Error(
          new $gose.ParseError("invalid COSE_recipient structure"),
        );
      } else {
        let $2 = $1.tail;
        if ($2 instanceof $Empty) {
          return new Error(
            new $gose.ParseError("invalid COSE_recipient structure"),
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
                  let unprotected_cbor = $5[0];
                  let ciphertext = $6[0];
                  return parse_recipient_fields(
                    protected_serialized,
                    unprotected_cbor,
                    ciphertext,
                  );
                } else {
                  return new Error(
                    new $gose.ParseError("invalid COSE_recipient structure"),
                  );
                }
              } else {
                return new Error(
                  new $gose.ParseError("invalid COSE_recipient structure"),
                );
              }
            } else {
              return new Error(
                new $gose.ParseError("invalid COSE_recipient structure"),
              );
            }
          } else {
            let $4 = $3.tail;
            if ($4 instanceof $Empty) {
              let $5 = $.head;
              if ($5 instanceof $cbor.Bytes) {
                let $6 = $1.head;
                if ($6 instanceof $cbor.Map) {
                  let $7 = $2.head;
                  if ($7 instanceof $cbor.Bytes) {
                    let $8 = $3.head;
                    if ($8 instanceof $cbor.Array) {
                      return new Error(
                        new $gose.ParseError(
                          "nested COSE recipients are not supported",
                        ),
                      );
                    } else {
                      return new Error(
                        new $gose.ParseError("invalid COSE_recipient structure"),
                      );
                    }
                  } else {
                    return new Error(
                      new $gose.ParseError("invalid COSE_recipient structure"),
                    );
                  }
                } else {
                  return new Error(
                    new $gose.ParseError("invalid COSE_recipient structure"),
                  );
                }
              } else {
                return new Error(
                  new $gose.ParseError("invalid COSE_recipient structure"),
                );
              }
            } else {
              return new Error(
                new $gose.ParseError("invalid COSE_recipient structure"),
              );
            }
          }
        }
      }
    }
  } else {
    return new Error(new $gose.ParseError("invalid COSE_recipient structure"));
  }
}

function parse_cbor_value(value) {
  return $result.try$(
    $cose_structure.parse_cose_array_value(value, 96, 4),
    (items) => {
      if (items instanceof $Empty) {
        return new Error(new $gose.ParseError("invalid COSE_Encrypt structure"));
      } else {
        let $ = items.tail;
        if ($ instanceof $Empty) {
          return new Error(
            new $gose.ParseError("invalid COSE_Encrypt structure"),
          );
        } else {
          let $1 = $.tail;
          if ($1 instanceof $Empty) {
            return new Error(
              new $gose.ParseError("invalid COSE_Encrypt structure"),
            );
          } else {
            let $2 = $1.tail;
            if ($2 instanceof $Empty) {
              return new Error(
                new $gose.ParseError("invalid COSE_Encrypt structure"),
              );
            } else {
              let $3 = $2.tail;
              if ($3 instanceof $Empty) {
                let $4 = items.head;
                if ($4 instanceof $cbor.Bytes) {
                  let $5 = $.head;
                  if ($5 instanceof $cbor.Map) {
                    let $6 = $1.head;
                    if ($6 instanceof $cbor.Bytes) {
                      let $7 = $2.head;
                      if ($7 instanceof $cbor.Array) {
                        let protected_serialized = $4[0];
                        let unprotected_cbor = $5[0];
                        let ciphertext = $6[0];
                        let recipient_values = $7[0];
                        return $result.try$(
                          $cose_structure.decode_protected(protected_serialized),
                          (protected$) => {
                            return $result.try$(
                              $cose_structure.decode_unprotected(
                                unprotected_cbor,
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
                                          $list.try_map(
                                            recipient_values,
                                            parse_recipient,
                                          ),
                                          (recipients) => {
                                            return new Ok(
                                              new EncryptedEncrypt(
                                                protected$,
                                                protected_serialized,
                                                unprotected,
                                                ciphertext,
                                                recipients,
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
                          new $gose.ParseError("invalid COSE_Encrypt structure"),
                        );
                      }
                    } else {
                      return new Error(
                        new $gose.ParseError("invalid COSE_Encrypt structure"),
                      );
                    }
                  } else {
                    return new Error(
                      new $gose.ParseError("invalid COSE_Encrypt structure"),
                    );
                  }
                } else {
                  return new Error(
                    new $gose.ParseError("invalid COSE_Encrypt structure"),
                  );
                }
              } else {
                return new Error(
                  new $gose.ParseError("invalid COSE_Encrypt structure"),
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
 * Decode a CBOR-encoded COSE_Encrypt message, accepting both tagged and untagged forms.
 */
export function parse(data) {
  return $result.try$(
    $cbor.decode(data),
    (value) => { return parse_cbor_value(value); },
  );
}

/**
 * Extract the key ID from the message headers.
 */
export function kid(message) {
  let protected$;
  let unprotected;
  if (message instanceof EncryptedEncrypt) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      466,
      "kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 13896,
        end: 13963,
        pattern_start: 13907,
        pattern_end: 13953
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
  if (message instanceof EncryptedEncrypt) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      474,
      "content_type",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 14172,
        end: 14239,
        pattern_start: 14183,
        pattern_end: 14229
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
  if (message instanceof EncryptedEncrypt) {
    protected$ = message.protected;
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      482,
      "critical",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 14456,
        end: 14523,
        pattern_start: 14467,
        pattern_end: 14513
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
  if (message instanceof EncryptedEncrypt) {
    protected$ = message.protected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      488,
      "protected_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 14697,
        end: 14750,
        pattern_start: 14708,
        pattern_end: 14740
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
  if (message instanceof EncryptedEncrypt) {
    unprotected = message.unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/cose/encrypt",
      494,
      "unprotected_headers",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 14887,
        end: 14942,
        pattern_start: 14898,
        pattern_end: 14932
      }
    )
  }
  return unprotected;
}
