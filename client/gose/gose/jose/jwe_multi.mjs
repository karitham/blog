import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
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
  toBitArray,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $content_encryption from "../../gose/internal/content_encryption.mjs";
import * as $key_encryption from "../../gose/internal/key_encryption.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $utils from "../../gose/internal/utils.mjs";
import * as $jose from "../../gose/jose.mjs";

const FILEPATH = "src/gose/jose/jwe_multi.gleam";

class PendingRecipient extends $CustomType {
  constructor(alg, key) {
    super();
    this.alg = alg;
    this.key = key;
  }
}

class SimpleRecipient extends $CustomType {
  constructor(alg_str, encrypted_key) {
    super();
    this.alg_str = alg_str;
    this.encrypted_key = encrypted_key;
  }
}

class EcdhEsRecipient extends $CustomType {
  constructor(alg_str, encrypted_key, epk, apu, apv) {
    super();
    this.alg_str = alg_str;
    this.encrypted_key = encrypted_key;
    this.epk = epk;
    this.apu = apu;
    this.apv = apv;
  }
}

class KwWithIvTagRecipient extends $CustomType {
  constructor(alg_str, encrypted_key, kw_iv, kw_tag) {
    super();
    this.alg_str = alg_str;
    this.encrypted_key = encrypted_key;
    this.kw_iv = kw_iv;
    this.kw_tag = kw_tag;
  }
}

class EcdhEsKwWithIvTagRecipient extends $CustomType {
  constructor(alg_str, encrypted_key, epk, apu, apv, kw_iv, kw_tag) {
    super();
    this.alg_str = alg_str;
    this.encrypted_key = encrypted_key;
    this.epk = epk;
    this.apu = apu;
    this.apv = apv;
    this.kw_iv = kw_iv;
    this.kw_tag = kw_tag;
  }
}

class UnencryptedMultiJwe extends $CustomType {
  constructor(enc, recipients) {
    super();
    this.enc = enc;
    this.recipients = recipients;
  }
}

class EncryptedMultiJwe extends $CustomType {
  constructor(enc, protected_b64, recipients, iv, ciphertext, tag) {
    super();
    this.enc = enc;
    this.protected_b64 = protected_b64;
    this.recipients = recipients;
    this.iv = iv;
    this.ciphertext = ciphertext;
    this.tag = tag;
  }
}

class Decryptor extends $CustomType {
  constructor(key_alg, content_alg, keys) {
    super();
    this.key_alg = key_alg;
    this.content_alg = content_alg;
    this.keys = keys;
  }
}

/**
 * Create a new multi-recipient JWE with the given content encryption algorithm.
 */
export function new$(enc) {
  return new UnencryptedMultiJwe(enc, toList([]));
}

function reject_pbes2_algorithms(alg, continue$) {
  let _block;
  if (alg instanceof $gose.Direct) {
    _block = false;
  } else if (alg instanceof $gose.AesKeyWrap) {
    _block = false;
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    _block = false;
  } else if (alg instanceof $gose.RsaEncryption) {
    _block = false;
  } else if (alg instanceof $gose.EcdhEs) {
    _block = false;
  } else {
    _block = true;
  }
  let is_pbes2 = _block;
  return $bool.guard(
    is_pbes2,
    new Error(
      new $gose.InvalidState(
        "PBES2 algorithms require a password; use the single-recipient JWE API",
      ),
    ),
    () => { return continue$(); },
  );
}

function reject_direct_algorithms(alg, continue$) {
  let _block;
  if (alg instanceof $gose.Direct) {
    _block = true;
  } else if (alg instanceof $gose.AesKeyWrap) {
    _block = false;
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    _block = false;
  } else if (alg instanceof $gose.RsaEncryption) {
    _block = false;
  } else if (alg instanceof $gose.EcdhEs) {
    let $ = alg[0];
    if ($ instanceof $gose.EcdhEsDirect) {
      _block = true;
    } else if ($ instanceof $gose.EcdhEsAesKw) {
      _block = false;
    } else {
      _block = false;
    }
  } else {
    _block = false;
  }
  let is_direct = _block;
  return $bool.guard(
    is_direct,
    new Error(
      new $gose.InvalidState(
        "Direct key agreement cannot be used with multi-recipient JWE",
      ),
    ),
    () => { return continue$(); },
  );
}

/**
 * Add a recipient with the given key encryption algorithm and key.
 */
export function add_recipient(message, alg, key) {
  let enc;
  let recipients;
  if (message instanceof UnencryptedMultiJwe) {
    enc = message.enc;
    recipients = message.recipients;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe_multi",
      137,
      "add_recipient",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 3865,
        end: 3924,
        pattern_start: 3876,
        pattern_end: 3914
      }
    )
  }
  return reject_direct_algorithms(
    alg,
    () => {
      return reject_pbes2_algorithms(
        alg,
        () => {
          return $result.try$(
            $key_helpers.validate_key_for_jwe_encryption(alg, key),
            (_) => {
              let recipient = new PendingRecipient(alg, key);
              return new Ok(
                new UnencryptedMultiJwe(enc, listPrepend(recipient, recipients)),
              );
            },
          );
        },
      );
    },
  );
}

function enc_header_json(enc) {
  let _pipe = $json.object(
    toList([["enc", $json.string($jose.content_alg_to_string(enc))]]),
  );
  let _pipe$1 = $json.to_string(_pipe);
  return $bit_array.from_string(_pipe$1);
}

function wrap_rsa(alg, key, cek) {
  if (alg instanceof $gose.RsaPkcs1v15) {
    return $key_encryption.wrap_rsa_pkcs1v15(key, cek);
  } else if (alg instanceof $gose.RsaOaepSha1) {
    return $key_encryption.wrap_rsa_oaep(key, cek, new $hash.Sha1());
  } else {
    return $key_encryption.wrap_rsa_oaep(key, cek, new $hash.Sha256());
  }
}

function wrap_cek(alg, key, cek) {
  if (alg instanceof $gose.Direct) {
    return new Error(
      new $gose.InvalidState(
        "unsupported algorithm for multi-recipient JWE: " + $jose.key_encryption_alg_to_string(
          alg,
        ),
      ),
    );
  } else if (alg instanceof $gose.AesKeyWrap) {
    let $ = alg[0];
    if ($ instanceof $gose.AesKw) {
      let size = alg[1];
      return $key_encryption.wrap_aes_kw(key, cek, size);
    } else {
      return new Error(
        new $gose.InvalidState(
          "unsupported algorithm for multi-recipient JWE: " + $jose.key_encryption_alg_to_string(
            alg,
          ),
        ),
      );
    }
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    return new Error(
      new $gose.InvalidState(
        "unsupported algorithm for multi-recipient JWE: " + $jose.key_encryption_alg_to_string(
          alg,
        ),
      ),
    );
  } else if (alg instanceof $gose.RsaEncryption) {
    let rsa_alg = alg[0];
    return wrap_rsa(rsa_alg, key, cek);
  } else if (alg instanceof $gose.EcdhEs) {
    return new Error(
      new $gose.InvalidState(
        "unsupported algorithm for multi-recipient JWE: " + $jose.key_encryption_alg_to_string(
          alg,
        ),
      ),
    );
  } else {
    return new Error(
      new $gose.InvalidState(
        "unsupported algorithm for multi-recipient JWE: " + $jose.key_encryption_alg_to_string(
          alg,
        ),
      ),
    );
  }
}

function wrap_chacha20_kw(alg_str, key, cek, variant) {
  return $result.try$(
    $key_encryption.get_octet_key(key, 32),
    (kek) => {
      let nonce_size = $gose.chacha20_kw_nonce_size(variant);
      let kw_iv = $crypto.random_bytes(nonce_size);
      return $result.try$(
        $key_encryption.wrap_chacha20_by_variant(kek, cek, kw_iv, variant),
        (_use0) => {
          let encrypted_cek = _use0[0];
          let kw_tag = _use0[1];
          return new Ok(
            new KwWithIvTagRecipient(alg_str, encrypted_cek, kw_iv, kw_tag),
          );
        },
      );
    },
  );
}

function wrap_aes_gcm_kw(alg_str, key, cek, size) {
  return $result.try$(
    $key_encryption.get_octet_key(key, $gose.aes_key_size(size)),
    (kek) => {
      let kw_iv = $crypto.random_bytes(12);
      return $result.try$(
        $key_encryption.wrap_aes_gcm(kek, cek, kw_iv, size),
        (_use0) => {
          let encrypted_cek = _use0[0];
          let kw_tag = _use0[1];
          return new Ok(
            new KwWithIvTagRecipient(alg_str, encrypted_cek, kw_iv, kw_tag),
          );
        },
      );
    },
  );
}

function wrap_ecdh_es_chacha20_kw(alg_str, key, cek, variant) {
  return $result.try$(
    $key_encryption.wrap_ecdh_es_chacha20_kw(
      key,
      cek,
      variant,
      alg_str,
      new $option.None(),
      new $option.None(),
    ),
    (_use0) => {
      let encrypted_cek = _use0[0];
      let epk = _use0[1];
      let kw_iv = _use0[2];
      let kw_tag = _use0[3];
      return new Ok(
        new EcdhEsKwWithIvTagRecipient(
          alg_str,
          encrypted_cek,
          epk,
          new $option.None(),
          new $option.None(),
          kw_iv,
          kw_tag,
        ),
      );
    },
  );
}

function wrap_ecdh_es_aes_kw(alg_str, key, cek, size) {
  return $result.try$(
    $key_encryption.wrap_ecdh_es_kw(
      key,
      cek,
      size,
      alg_str,
      new $option.None(),
      new $option.None(),
    ),
    (_use0) => {
      let wrapped = _use0[0];
      let epk = _use0[1];
      return new Ok(
        new EcdhEsRecipient(
          alg_str,
          wrapped,
          epk,
          new $option.None(),
          new $option.None(),
        ),
      );
    },
  );
}

function wrap_cek_for_recipient(recipient, cek) {
  let alg_str = $jose.key_encryption_alg_to_string(recipient.alg);
  let $ = recipient.alg;
  if ($ instanceof $gose.AesKeyWrap) {
    let $1 = $[0];
    if ($1 instanceof $gose.AesGcmKw) {
      let size = $[1];
      return wrap_aes_gcm_kw(alg_str, recipient.key, cek, size);
    } else {
      return $result.try$(
        wrap_cek(recipient.alg, recipient.key, cek),
        (encrypted_key) => {
          return new Ok(new SimpleRecipient(alg_str, encrypted_key));
        },
      );
    }
  } else if ($ instanceof $gose.ChaCha20KeyWrap) {
    let variant = $[0];
    return wrap_chacha20_kw(alg_str, recipient.key, cek, variant);
  } else if ($ instanceof $gose.EcdhEs) {
    let $1 = $[0];
    if ($1 instanceof $gose.EcdhEsAesKw) {
      let size = $1[0];
      return wrap_ecdh_es_aes_kw(alg_str, recipient.key, cek, size);
    } else if ($1 instanceof $gose.EcdhEsChaCha20Kw) {
      let variant = $1[0];
      return wrap_ecdh_es_chacha20_kw(alg_str, recipient.key, cek, variant);
    } else {
      return $result.try$(
        wrap_cek(recipient.alg, recipient.key, cek),
        (encrypted_key) => {
          return new Ok(new SimpleRecipient(alg_str, encrypted_key));
        },
      );
    }
  } else {
    return $result.try$(
      wrap_cek(recipient.alg, recipient.key, cek),
      (encrypted_key) => {
        return new Ok(new SimpleRecipient(alg_str, encrypted_key));
      },
    );
  }
}

/**
 * Encrypt the plaintext for all recipients.
 */
export function encrypt(message, plaintext) {
  let enc;
  let recipients;
  if (message instanceof UnencryptedMultiJwe) {
    enc = message.enc;
    recipients = message.recipients;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe_multi",
      150,
      "encrypt",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 4382,
        end: 4441,
        pattern_start: 4393,
        pattern_end: 4431
      }
    )
  }
  return $bool.guard(
    $list.is_empty(recipients),
    new Error(new $gose.InvalidState("at least one recipient required")),
    () => {
      let recipients$1 = $list.reverse(recipients);
      let cek = $content_encryption.generate_cek(enc);
      return $result.try$(
        $list.try_map(
          recipients$1,
          (_capture) => { return wrap_cek_for_recipient(_capture, cek); },
        ),
        (encrypted_recipients) => {
          let protected_json = enc_header_json(enc);
          let protected_b64 = $utils.encode_base64_url(protected_json);
          let iv = $content_encryption.generate_iv(enc);
          let aead_aad = $content_encryption.build_jwe_aad(
            protected_b64,
            new $option.None(),
          );
          return $result.try$(
            $content_encryption.encrypt_content(
              enc,
              cek,
              iv,
              aead_aad,
              plaintext,
            ),
            (_use0) => {
              let ciphertext = _use0[0];
              let tag = _use0[1];
              return new Ok(
                new EncryptedMultiJwe(
                  enc,
                  protected_b64,
                  encrypted_recipients,
                  iv,
                  ciphertext,
                  tag,
                ),
              );
            },
          );
        },
      );
    },
  );
}

function build_kw_fields(kw_iv, kw_tag) {
  return toList([
    ["iv", $json.string($utils.encode_base64_url(kw_iv))],
    ["tag", $json.string($utils.encode_base64_url(kw_tag))],
  ]);
}

function build_epk_fields(epk, apu, apv) {
  let _block;
  if (epk instanceof $key_encryption.EcEphemeralKey) {
    let curve = epk.curve;
    let x = epk.x;
    let y = epk.y;
    _block = toList([
      [
        "epk",
        $json.object(
          toList([
            ["kty", $json.string("EC")],
            ["crv", $json.string($utils.ec_curve_to_string(curve))],
            ["x", $json.string($utils.encode_base64_url(x))],
            ["y", $json.string($utils.encode_base64_url(y))],
          ]),
        ),
      ],
    ]);
  } else {
    let curve = epk.curve;
    let x = epk.x;
    _block = toList([
      [
        "epk",
        $json.object(
          toList([
            ["kty", $json.string("OKP")],
            ["crv", $json.string($utils.xdh_curve_to_string(curve))],
            ["x", $json.string($utils.encode_base64_url(x))],
          ]),
        ),
      ],
    ]);
  }
  let fields = _block;
  let _block$1;
  if (apu instanceof $option.Some) {
    let a = apu[0];
    _block$1 = listPrepend(
      ["apu", $json.string($utils.encode_base64_url(a))],
      fields,
    );
  } else {
    _block$1 = fields;
  }
  let fields$1 = _block$1;
  if (apv instanceof $option.Some) {
    let a = apv[0];
    return listPrepend(
      ["apv", $json.string($utils.encode_base64_url(a))],
      fields$1,
    );
  } else {
    return fields$1;
  }
}

function recipient_to_json(recipient) {
  let _block;
  if (recipient instanceof SimpleRecipient) {
    let alg_str = recipient.alg_str;
    let encrypted_key = recipient.encrypted_key;
    _block = [alg_str, encrypted_key, toList([])];
  } else if (recipient instanceof EcdhEsRecipient) {
    let alg_str = recipient.alg_str;
    let encrypted_key = recipient.encrypted_key;
    let epk = recipient.epk;
    let apu = recipient.apu;
    let apv = recipient.apv;
    _block = [alg_str, encrypted_key, build_epk_fields(epk, apu, apv)];
  } else if (recipient instanceof KwWithIvTagRecipient) {
    let alg_str = recipient.alg_str;
    let encrypted_key = recipient.encrypted_key;
    let kw_iv = recipient.kw_iv;
    let kw_tag = recipient.kw_tag;
    _block = [alg_str, encrypted_key, build_kw_fields(kw_iv, kw_tag)];
  } else {
    let alg_str = recipient.alg_str;
    let encrypted_key = recipient.encrypted_key;
    let epk = recipient.epk;
    let apu = recipient.apu;
    let apv = recipient.apv;
    let kw_iv = recipient.kw_iv;
    let kw_tag = recipient.kw_tag;
    _block = [
      alg_str,
      encrypted_key,
      $list.append(
        build_epk_fields(epk, apu, apv),
        build_kw_fields(kw_iv, kw_tag),
      ),
    ];
  }
  let $ = _block;
  let alg_str = $[0];
  let encrypted_key = $[1];
  let header_fields = $[2];
  let all_header_fields = listPrepend(
    ["alg", $json.string(alg_str)],
    header_fields,
  );
  let fields = toList([["header", $json.object(all_header_fields)]]);
  let _block$1;
  let $1 = $bit_array.byte_size(encrypted_key);
  if ($1 === 0) {
    _block$1 = fields;
  } else {
    _block$1 = listPrepend(
      ["encrypted_key", $json.string($utils.encode_base64_url(encrypted_key))],
      fields,
    );
  }
  let fields$1 = _block$1;
  return $json.object(fields$1);
}

/**
 * Serialize as JWE JSON General Serialization.
 */
export function serialize_json(message) {
  let protected_b64;
  let recipients;
  let iv;
  let ciphertext;
  let tag;
  if (message instanceof EncryptedMultiJwe) {
    protected_b64 = message.protected_b64;
    recipients = message.recipients;
    iv = message.iv;
    ciphertext = message.ciphertext;
    tag = message.tag;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe_multi",
      187,
      "serialize_json",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 5410,
        end: 5534,
        pattern_start: 5421,
        pattern_end: 5524
      }
    )
  }
  let recipient_objects = $list.map(recipients, recipient_to_json);
  return $json.object(
    toList([
      ["protected", $json.string(protected_b64)],
      ["recipients", $json.preprocessed_array(recipient_objects)],
      ["iv", $json.string($utils.encode_base64_url(iv))],
      ["ciphertext", $json.string($utils.encode_base64_url(ciphertext))],
      ["tag", $json.string($utils.encode_base64_url(tag))],
    ]),
  );
}

function build_encrypted_recipient(
  alg_str,
  encrypted_key,
  epk,
  apu,
  apv,
  kw_iv,
  kw_tag
) {
  if (epk instanceof $option.Some) {
    if (kw_iv instanceof $option.Some) {
      if (kw_tag instanceof $option.Some) {
        let epk$1 = epk[0];
        let kw_iv$1 = kw_iv[0];
        let kw_tag$1 = kw_tag[0];
        return new Ok(
          new EcdhEsKwWithIvTagRecipient(
            alg_str,
            encrypted_key,
            epk$1,
            apu,
            apv,
            kw_iv$1,
            kw_tag$1,
          ),
        );
      } else {
        return new Error(
          new $gose.ParseError(
            "invalid recipient header field combination for " + alg_str,
          ),
        );
      }
    } else if (kw_tag instanceof $option.None) {
      let epk$1 = epk[0];
      return new Ok(
        new EcdhEsRecipient(alg_str, encrypted_key, epk$1, apu, apv),
      );
    } else {
      return new Error(
        new $gose.ParseError(
          "invalid recipient header field combination for " + alg_str,
        ),
      );
    }
  } else if (kw_iv instanceof $option.Some) {
    if (kw_tag instanceof $option.Some) {
      let kw_iv$1 = kw_iv[0];
      let kw_tag$1 = kw_tag[0];
      return new Ok(
        new KwWithIvTagRecipient(alg_str, encrypted_key, kw_iv$1, kw_tag$1),
      );
    } else {
      return new Error(
        new $gose.ParseError(
          "invalid recipient header field combination for " + alg_str,
        ),
      );
    }
  } else if (kw_tag instanceof $option.None) {
    return new Ok(new SimpleRecipient(alg_str, encrypted_key));
  } else {
    return new Error(
      new $gose.ParseError(
        "invalid recipient header field combination for " + alg_str,
      ),
    );
  }
}

function decode_optional_b64(raw, label) {
  if (raw instanceof $option.Some) {
    let b64 = raw[0];
    let _pipe = $utils.decode_base64_url(b64, label);
    return $result.map(_pipe, (var0) => { return new $option.Some(var0); });
  } else {
    return new Ok(new $option.None());
  }
}

function parse_optional_epk(raw) {
  if (raw instanceof $option.Some) {
    let kty = raw[0][0];
    let crv = raw[0][1];
    let x_b64 = raw[0][2];
    let y_opt = raw[0][3];
    return $result.try$(
      (() => {
        let _pipe = $bit_array.base64_url_decode(x_b64);
        return $result.replace_error(
          _pipe,
          new $gose.ParseError("invalid epk x base64"),
        );
      })(),
      (x) => {
        if (kty === "EC") {
          return $result.try$(
            $option.to_result(
              y_opt,
              new $gose.ParseError("EC epk requires y coordinate"),
            ),
            (y_b64) => {
              return $result.try$(
                (() => {
                  let _pipe = $bit_array.base64_url_decode(y_b64);
                  return $result.replace_error(
                    _pipe,
                    new $gose.ParseError("invalid epk y base64"),
                  );
                })(),
                (y) => {
                  return $result.try$(
                    $utils.ec_curve_from_string(crv),
                    (curve) => {
                      return new Ok(
                        new $option.Some(
                          new $key_encryption.EcEphemeralKey(curve, x, y),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        } else if (kty === "OKP") {
          return $result.try$(
            $utils.xdh_curve_from_string(crv),
            (curve) => {
              return new Ok(
                new $option.Some(new $key_encryption.XdhEphemeralKey(curve, x)),
              );
            },
          );
        } else {
          return new Error(new $gose.ParseError("unsupported epk kty: " + kty));
        }
      },
    );
  } else {
    return new Ok(new $option.None());
  }
}

function decode_optional_encrypted_key(raw) {
  if (raw instanceof $option.Some) {
    let b64 = raw[0];
    return $utils.decode_base64_url(b64, "encrypted_key");
  } else {
    return new Ok(toBitArray([]));
  }
}

function epk_decoder() {
  return $decode.field(
    "kty",
    $decode.string,
    (kty) => {
      return $decode.field(
        "crv",
        $decode.string,
        (crv) => {
          return $decode.field(
            "x",
            $decode.string,
            (x) => {
              return $decode.optional_field(
                "y",
                new $option.None(),
                $decode.optional($decode.string),
                (y) => { return $decode.success([kty, crv, x, y]); },
              );
            },
          );
        },
      );
    },
  );
}

function parse_raw_recipient(raw) {
  let header_raw = raw[0];
  let ek_opt = raw[1];
  let header_decoder = $decode.field(
    "alg",
    $decode.string,
    (alg) => {
      return $decode.optional_field(
        "epk",
        new $option.None(),
        $decode.optional(epk_decoder()),
        (epk) => {
          return $decode.optional_field(
            "apu",
            new $option.None(),
            $decode.optional($decode.string),
            (apu) => {
              return $decode.optional_field(
                "apv",
                new $option.None(),
                $decode.optional($decode.string),
                (apv) => {
                  return $decode.optional_field(
                    "iv",
                    new $option.None(),
                    $decode.optional($decode.string),
                    (iv) => {
                      return $decode.optional_field(
                        "tag",
                        new $option.None(),
                        $decode.optional($decode.string),
                        (tag) => {
                          return $decode.success([alg, epk, apu, apv, iv, tag]);
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
      let _pipe = $decode.run(header_raw, header_decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("missing alg in recipient header"),
      );
    })(),
    (_use0) => {
      let alg_str = _use0[0];
      let epk_raw = _use0[1];
      let apu_b64 = _use0[2];
      let apv_b64 = _use0[3];
      let iv_b64 = _use0[4];
      let tag_b64 = _use0[5];
      return $result.try$(
        decode_optional_encrypted_key(ek_opt),
        (encrypted_key) => {
          return $result.try$(
            parse_optional_epk(epk_raw),
            (epk) => {
              return $result.try$(
                decode_optional_b64(apu_b64, "apu"),
                (apu) => {
                  return $result.try$(
                    decode_optional_b64(apv_b64, "apv"),
                    (apv) => {
                      return $result.try$(
                        decode_optional_b64(iv_b64, "iv"),
                        (kw_iv) => {
                          return $result.try$(
                            decode_optional_b64(tag_b64, "tag"),
                            (kw_tag) => {
                              return build_encrypted_recipient(
                                alg_str,
                                encrypted_key,
                                epk,
                                apu,
                                apv,
                                kw_iv,
                                kw_tag,
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
    },
  );
}

function parse_enc_from_protected(protected_b64) {
  return $result.try$(
    $utils.decode_base64_url(protected_b64, "protected header"),
    (protected_bytes) => {
      let decoder = $decode.field(
        "enc",
        $decode.string,
        (enc_str) => { return $decode.success(enc_str); },
      );
      return $result.try$(
        (() => {
          let _pipe = $json.parse_bits(protected_bytes, decoder);
          return $result.replace_error(
            _pipe,
            new $gose.ParseError("missing enc in protected header"),
          );
        })(),
        (enc_str) => { return $jose.content_alg_from_string(enc_str); },
      );
    },
  );
}

/**
 * Parse a JWE from JSON General Serialization format.
 */
export function parse_json(json_str) {
  let recipient_decoder = $decode.field(
    "header",
    $decode.dynamic,
    (header) => {
      return $decode.optional_field(
        "encrypted_key",
        new $option.None(),
        $decode.optional($decode.string),
        (encrypted_key) => { return $decode.success([header, encrypted_key]); },
      );
    },
  );
  let decoder = $decode.field(
    "protected",
    $decode.string,
    (protected$) => {
      return $decode.field(
        "recipients",
        $decode.list(recipient_decoder),
        (recipients) => {
          return $decode.field(
            "iv",
            $decode.string,
            (iv) => {
              return $decode.field(
                "ciphertext",
                $decode.string,
                (ciphertext) => {
                  return $decode.field(
                    "tag",
                    $decode.string,
                    (tag) => {
                      return $decode.success(
                        [protected$, recipients, iv, ciphertext, tag],
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
      let _pipe = $json.parse(json_str, decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("invalid JWE JSON"),
      );
    })(),
    (_use0) => {
      let protected_b64 = _use0[0];
      let raw_recipients = _use0[1];
      let iv_b64 = _use0[2];
      let ct_b64 = _use0[3];
      let tag_b64 = _use0[4];
      return $result.try$(
        parse_enc_from_protected(protected_b64),
        (enc) => {
          return $result.try$(
            $list.try_map(raw_recipients, parse_raw_recipient),
            (recipients) => {
              return $result.try$(
                $utils.decode_base64_url(iv_b64, "iv"),
                (iv) => {
                  return $result.try$(
                    $utils.decode_base64_url(ct_b64, "ciphertext"),
                    (ciphertext) => {
                      return $result.try$(
                        $utils.decode_base64_url(tag_b64, "tag"),
                        (tag) => {
                          return $result.try$(
                            $content_encryption.validate_iv_tag_sizes(
                              enc,
                              iv,
                              tag,
                            ),
                            (_) => {
                              return new Ok(
                                new EncryptedMultiJwe(
                                  enc,
                                  protected_b64,
                                  recipients,
                                  iv,
                                  ciphertext,
                                  tag,
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
    },
  );
}

/**
 * Build a decryptor pinned to expected algorithms and keys.
 */
export function decryptor(key_alg, content_alg, keys) {
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
        (_) => { return new Ok(new Decryptor(key_alg, content_alg, keys)); },
      );
    },
  );
}

function unwrap_ecdh_es_chacha20_kw(key, recipient, variant) {
  let encrypted_key;
  let epk;
  let apu;
  let apv;
  let kw_iv;
  let kw_tag;
  if (recipient instanceof EcdhEsKwWithIvTagRecipient) {
    encrypted_key = recipient.encrypted_key;
    epk = recipient.epk;
    apu = recipient.apu;
    apv = recipient.apv;
    kw_iv = recipient.kw_iv;
    kw_tag = recipient.kw_tag;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe_multi",
      617,
      "unwrap_ecdh_es_chacha20_kw",
      "Pattern match failed, no pattern matched the value.",
      {
        value: recipient,
        start: 17005,
        end: 17142,
        pattern_start: 17016,
        pattern_end: 17130
      }
    )
  }
  let alg_id = $jose.key_encryption_alg_to_string(
    new $gose.EcdhEs(new $gose.EcdhEsChaCha20Kw(variant)),
  );
  return $key_encryption.unwrap_ecdh_es_chacha20_kw(
    key,
    encrypted_key,
    variant,
    alg_id,
    epk,
    apu,
    apv,
    kw_iv,
    kw_tag,
  );
}

function unwrap_ecdh_es_aes_kw(key, recipient, size) {
  let encrypted_key;
  let epk;
  let apu;
  let apv;
  if (recipient instanceof EcdhEsRecipient) {
    encrypted_key = recipient.encrypted_key;
    epk = recipient.epk;
    apu = recipient.apu;
    apv = recipient.apv;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe_multi",
      598,
      "unwrap_ecdh_es_aes_kw",
      "Pattern match failed, no pattern matched the value.",
      {
        value: recipient,
        start: 16553,
        end: 16629,
        pattern_start: 16564,
        pattern_end: 16617
      }
    )
  }
  let alg_id = $jose.key_encryption_alg_to_string(
    new $gose.EcdhEs(new $gose.EcdhEsAesKw(size)),
  );
  return $key_encryption.unwrap_ecdh_es_kw(
    key,
    encrypted_key,
    size,
    alg_id,
    epk,
    apu,
    apv,
  );
}

function unwrap_chacha20_kw(key, recipient, variant) {
  let encrypted_key;
  let kw_iv;
  let kw_tag;
  if (recipient instanceof KwWithIvTagRecipient) {
    encrypted_key = recipient.encrypted_key;
    kw_iv = recipient.kw_iv;
    kw_tag = recipient.kw_tag;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe_multi",
      581,
      "unwrap_chacha20_kw",
      "Pattern match failed, no pattern matched the value.",
      {
        value: recipient,
        start: 16110,
        end: 16194,
        pattern_start: 16121,
        pattern_end: 16178
      }
    )
  }
  return $result.try$(
    $key_encryption.get_octet_key(key, 32),
    (kek) => {
      return $key_encryption.unwrap_chacha20_by_variant(
        kek,
        encrypted_key,
        kw_iv,
        kw_tag,
        variant,
      );
    },
  );
}

function unwrap_aes_gcm_kw(key, recipient, size) {
  let encrypted_key;
  let kw_iv;
  let kw_tag;
  if (recipient instanceof KwWithIvTagRecipient) {
    encrypted_key = recipient.encrypted_key;
    kw_iv = recipient.kw_iv;
    kw_tag = recipient.kw_tag;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe_multi",
      561,
      "unwrap_aes_gcm_kw",
      "Pattern match failed, no pattern matched the value.",
      {
        value: recipient,
        start: 15651,
        end: 15735,
        pattern_start: 15662,
        pattern_end: 15719
      }
    )
  }
  return $result.try$(
    $key_encryption.get_octet_key(key, $gose.aes_key_size(size)),
    (kek) => {
      return $key_encryption.unwrap_aes_gcm(
        kek,
        encrypted_key,
        kw_iv,
        kw_tag,
        size,
      );
    },
  );
}

function unwrap_cek(alg, key, recipient, enc) {
  if (alg instanceof $gose.Direct) {
    return new Error(
      new $gose.InvalidState(
        "unsupported algorithm for multi-recipient JWE decryption: " + $jose.key_encryption_alg_to_string(
          alg,
        ),
      ),
    );
  } else if (alg instanceof $gose.AesKeyWrap) {
    let $ = alg[0];
    if ($ instanceof $gose.AesKw) {
      let size = alg[1];
      return $key_encryption.unwrap_aes_kw(key, recipient.encrypted_key, size);
    } else {
      let size = alg[1];
      return unwrap_aes_gcm_kw(key, recipient, size);
    }
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    let variant = alg[0];
    return unwrap_chacha20_kw(key, recipient, variant);
  } else if (alg instanceof $gose.RsaEncryption) {
    let $ = alg[0];
    if ($ instanceof $gose.RsaPkcs1v15) {
      return $key_encryption.unwrap_rsa_pkcs1v15_safe(
        key,
        recipient.encrypted_key,
        enc,
      );
    } else if ($ instanceof $gose.RsaOaepSha1) {
      return $key_encryption.unwrap_rsa_oaep(
        key,
        recipient.encrypted_key,
        new $hash.Sha1(),
      );
    } else {
      return $key_encryption.unwrap_rsa_oaep(
        key,
        recipient.encrypted_key,
        new $hash.Sha256(),
      );
    }
  } else if (alg instanceof $gose.EcdhEs) {
    let $ = alg[0];
    if ($ instanceof $gose.EcdhEsDirect) {
      return new Error(
        new $gose.InvalidState(
          "unsupported algorithm for multi-recipient JWE decryption: " + $jose.key_encryption_alg_to_string(
            alg,
          ),
        ),
      );
    } else if ($ instanceof $gose.EcdhEsAesKw) {
      let size = $[0];
      return unwrap_ecdh_es_aes_kw(key, recipient, size);
    } else {
      let variant = $[0];
      return unwrap_ecdh_es_chacha20_kw(key, recipient, variant);
    }
  } else {
    return new Error(
      new $gose.InvalidState(
        "unsupported algorithm for multi-recipient JWE decryption: " + $jose.key_encryption_alg_to_string(
          alg,
        ),
      ),
    );
  }
}

function unwrap_and_decrypt(
  recipient,
  key,
  key_alg,
  enc,
  iv,
  aead_aad,
  ciphertext,
  tag
) {
  return $result.try$(
    unwrap_cek(key_alg, key, recipient, enc),
    (cek) => {
      return $content_encryption.decrypt_content(
        enc,
        cek,
        iv,
        aead_aad,
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
  loop$enc,
  loop$iv,
  loop$aead_aad,
  loop$ciphertext,
  loop$tag,
  loop$last_error
) {
  while (true) {
    let keys = loop$keys;
    let recipient = loop$recipient;
    let key_alg = loop$key_alg;
    let enc = loop$enc;
    let iv = loop$iv;
    let aead_aad = loop$aead_aad;
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
        enc,
        iv,
        aead_aad,
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
          loop$enc = enc;
          loop$iv = iv;
          loop$aead_aad = aead_aad;
          loop$ciphertext = ciphertext;
          loop$tag = tag;
          loop$last_error = new Error(e);
        } else if ($ instanceof $gose.VerificationFailed) {
          let e = $;
          loop$keys = rest;
          loop$recipient = recipient;
          loop$key_alg = key_alg;
          loop$enc = enc;
          loop$iv = iv;
          loop$aead_aad = aead_aad;
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
  enc,
  iv,
  aead_aad,
  ciphertext,
  tag
) {
  return try_keys(
    keys,
    recipient,
    key_alg,
    enc,
    iv,
    aead_aad,
    ciphertext,
    tag,
    new Error(new $gose.CryptoError("no key could decrypt")),
  );
}

function try_decrypt_recipients(
  loop$recipients,
  loop$keys,
  loop$key_alg,
  loop$enc,
  loop$iv,
  loop$aead_aad,
  loop$ciphertext,
  loop$tag,
  loop$last_error
) {
  while (true) {
    let recipients = loop$recipients;
    let keys = loop$keys;
    let key_alg = loop$key_alg;
    let enc = loop$enc;
    let iv = loop$iv;
    let aead_aad = loop$aead_aad;
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
        enc,
        iv,
        aead_aad,
        ciphertext,
        tag,
      );
      if (result instanceof Ok) {
        return result;
      } else {
        let e = result[0];
        loop$recipients = rest;
        loop$keys = keys;
        loop$key_alg = key_alg;
        loop$enc = enc;
        loop$iv = iv;
        loop$aead_aad = aead_aad;
        loop$ciphertext = ciphertext;
        loop$tag = tag;
        loop$last_error = new Error(e);
      }
    }
  }
}

/**
 * Decrypt a multi-recipient JWE.
 */
export function decrypt(decryptor, message) {
  let key_alg = decryptor.key_alg;
  let expected_enc = decryptor.content_alg;
  let keys = decryptor.keys;
  let actual_enc;
  let protected_b64;
  let recipients;
  let iv;
  let ciphertext;
  let tag;
  if (message instanceof EncryptedMultiJwe) {
    actual_enc = message.enc;
    protected_b64 = message.protected_b64;
    recipients = message.recipients;
    iv = message.iv;
    ciphertext = message.ciphertext;
    tag = message.tag;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe_multi",
      273,
      "decrypt",
      "Pattern match failed, no pattern matched the value.",
      {
        value: message,
        start: 8148,
        end: 8285,
        pattern_start: 8159,
        pattern_end: 8275
      }
    )
  }
  return $result.try$(
    $key_helpers.require_matching_content_algorithm(expected_enc, actual_enc),
    (_) => {
      let expected_alg_str = $jose.key_encryption_alg_to_string(key_alg);
      let matching = $list.filter(
        recipients,
        (r) => { return r.alg_str === expected_alg_str; },
      );
      let aead_aad = $content_encryption.build_jwe_aad(
        protected_b64,
        new $option.None(),
      );
      return try_decrypt_recipients(
        matching,
        keys,
        key_alg,
        actual_enc,
        iv,
        aead_aad,
        ciphertext,
        tag,
        new Error(new $gose.CryptoError("no matching recipient found")),
      );
    },
  );
}
