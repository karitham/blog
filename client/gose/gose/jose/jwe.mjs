import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $dict from "../../../gleam_stdlib/gleam/dict.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $set from "../../../gleam_stdlib/gleam/set.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $block from "../../../kryptos/kryptos/block.mjs";
import * as $crypto from "../../../kryptos/kryptos/crypto.mjs";
import * as $hash from "../../../kryptos/kryptos/hash.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
  prepend as listPrepend,
  CustomType as $CustomType,
  makeError,
  isEqual,
  toBitArray,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $content_encryption from "../../gose/internal/content_encryption.mjs";
import * as $key_encryption from "../../gose/internal/key_encryption.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $utils from "../../gose/internal/utils.mjs";
import * as $jose from "../../gose/jose.mjs";

const FILEPATH = "src/gose/jose/jwe.gleam";

class JweHeader extends $CustomType {
  constructor(alg, enc, kid, typ, cty) {
    super();
    this.alg = alg;
    this.enc = enc;
    this.kid = kid;
    this.typ = typ;
    this.cty = cty;
  }
}

class NoBuilderAlgFields extends $CustomType {}
const BuilderAlgFields$NoBuilderAlgFields$const = new NoBuilderAlgFields();

class EcdhEsBuilderFields extends $CustomType {
  constructor(apu, apv) {
    super();
    this.apu = apu;
    this.apv = apv;
  }
}

class Pbes2BuilderFields extends $CustomType {
  constructor(p2c) {
    super();
    this.p2c = p2c;
  }
}

class AesGcmKwBuilderFields extends $CustomType {}
const BuilderAlgFields$AesGcmKwBuilderFields$const = new AesGcmKwBuilderFields();

class ChaCha20KwBuilderFields extends $CustomType {}
const BuilderAlgFields$ChaCha20KwBuilderFields$const =
  new ChaCha20KwBuilderFields();

class NoResolvedAlgFields extends $CustomType {}
const ResolvedAlgFields$NoResolvedAlgFields$const = new NoResolvedAlgFields();

class EcdhEsResolvedFields extends $CustomType {
  constructor(epk, apu, apv) {
    super();
    this.epk = epk;
    this.apu = apu;
    this.apv = apv;
  }
}

class Pbes2ResolvedFields extends $CustomType {
  constructor(p2s, p2c) {
    super();
    this.p2s = p2s;
    this.p2c = p2c;
  }
}

class AesGcmKwResolvedFields extends $CustomType {
  constructor(kw_iv, kw_tag) {
    super();
    this.kw_iv = kw_iv;
    this.kw_tag = kw_tag;
  }
}

class ChaCha20KwResolvedFields extends $CustomType {
  constructor(kw_iv, kw_tag) {
    super();
    this.kw_iv = kw_iv;
    this.kw_tag = kw_tag;
  }
}

class EcdhEsChaCha20KwResolvedFields extends $CustomType {
  constructor(epk, apu, apv, kw_iv, kw_tag) {
    super();
    this.epk = epk;
    this.apu = apu;
    this.apv = apv;
    this.kw_iv = kw_iv;
    this.kw_tag = kw_tag;
  }
}

class ParsedHeader extends $CustomType {
  constructor(header, alg_fields) {
    super();
    this.header = header;
    this.alg_fields = alg_fields;
  }
}

class Jwe extends $CustomType {
  constructor(header, aad, shared_unprotected, per_recipient_unprotected, alg_fields) {
    super();
    this.header = header;
    this.aad = aad;
    this.shared_unprotected = shared_unprotected;
    this.per_recipient_unprotected = per_recipient_unprotected;
    this.alg_fields = alg_fields;
  }
}

class EncryptedJwe extends $CustomType {
  constructor(header, protected_b64, encrypted_key, iv, ciphertext, tag, alg_fields, aad, shared_unprotected, shared_unprotected_raw, per_recipient_unprotected, per_recipient_unprotected_raw) {
    super();
    this.header = header;
    this.protected_b64 = protected_b64;
    this.encrypted_key = encrypted_key;
    this.iv = iv;
    this.ciphertext = ciphertext;
    this.tag = tag;
    this.alg_fields = alg_fields;
    this.aad = aad;
    this.shared_unprotected = shared_unprotected;
    this.shared_unprotected_raw = shared_unprotected_raw;
    this.per_recipient_unprotected = per_recipient_unprotected;
    this.per_recipient_unprotected_raw = per_recipient_unprotected_raw;
  }
}

class KeyDecryptor extends $CustomType {
  constructor(alg, enc, keys) {
    super();
    this.alg = alg;
    this.enc = enc;
    this.keys = keys;
  }
}

class PasswordDecryptor extends $CustomType {
  constructor(alg, enc, password) {
    super();
    this.alg = alg;
    this.enc = enc;
    this.password = password;
  }
}

/**
 * Maximum allowed PBES2 iteration count to prevent DoS attacks.
 * 
 * @ignore
 */
const max_p2c = 10_000_000;

/**
 * Minimum required PBES2 iteration count.
 * 
 * @ignore
 */
const min_p2c = 1000;

/**
 * Headers that MUST be integrity protected.
 * 
 * @ignore
 */
const protected_only_headers = /* @__PURE__ */ toList([
  "alg",
  "enc",
  "crit",
  "zip",
]);

/**
 * Standard JWE header parameters that cannot appear in `crit`.
 * 
 * @ignore
 */
const standard_headers = /* @__PURE__ */ toList([
  "alg",
  "enc",
  "zip",
  "jku",
  "jwk",
  "kid",
  "x5u",
  "x5c",
  "x5t",
  "x5t#S256",
  "typ",
  "cty",
  "apu",
  "apv",
  "epk",
  "iv",
  "tag",
  "p2s",
  "p2c",
  "crit",
]);

/**
 * Create a key-based decryptor for symmetric (dir, AES-KW, AES-GCM-KW) or
 * asymmetric (RSA-OAEP, ECDH-ES) algorithms with multiple keys.
 *
 * The decryptor pins the expected algorithm and encryption method.
 * Tokens with different algorithms will be rejected.
 *
 * When decrypting, keys are tried in order. If the JWE has a `kid` header,
 * a key with matching `kid` is prioritized.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(decryptor) = jwe.key_decryptor(gose.Direct, gose.AesGcm(gose.Aes256), [key])
 * let assert Ok(plaintext) = jwe.decrypt(decryptor, encrypted_jwe)
 * ```
 */
export function key_decryptor(alg, enc, keys) {
  return $key_helpers.require_non_empty_keys(
    keys,
    () => {
      return $result.try$(
        $list.try_each(
          keys,
          (_capture) => {
            return $key_helpers.validate_key_for_jwe_decryption(alg, _capture);
          },
        ),
        (_) => { return new Ok(new KeyDecryptor(alg, enc, keys)); },
      );
    },
  );
}

/**
 * Create a new unencrypted JWE for AES-GCM Key Wrap encryption. A random CEK
 * is generated and wrapped using AES-GCM with the provided symmetric key.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(encrypted) = jwe.new_aes_gcm_kw(gose.Aes256, gose.AesGcm(gose.Aes256))
 *   |> jwe.encrypt(key, <<"hello":utf8>>)
 * ```
 */
export function new_aes_gcm_kw(size, enc) {
  return new Jwe(
    new JweHeader(
      new $gose.AesKeyWrap($gose.AesKwMode$AesGcmKw$const, size),
      enc,
      $option.Option$None$const,
      $option.Option$None$const,
      $option.Option$None$const,
    ),
    $option.Option$None$const,
    $dict.new$(),
    $dict.new$(),
    BuilderAlgFields$AesGcmKwBuilderFields$const,
  );
}

/**
 * Create a new unencrypted JWE for AES Key Wrap encryption. A random CEK is
 * generated and wrapped with the provided symmetric key.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(encrypted) = jwe.new_aes_kw(gose.Aes256, gose.AesGcm(gose.Aes256))
 *   |> jwe.encrypt(key, <<"hello":utf8>>)
 * ```
 */
export function new_aes_kw(size, enc) {
  return new Jwe(
    new JweHeader(
      new $gose.AesKeyWrap($gose.AesKwMode$AesKw$const, size),
      enc,
      $option.Option$None$const,
      $option.Option$None$const,
      $option.Option$None$const,
    ),
    $option.Option$None$const,
    $dict.new$(),
    $dict.new$(),
    BuilderAlgFields$NoBuilderAlgFields$const,
  );
}

/**
 * Create a new unencrypted JWE for ChaCha20-Poly1305 Key Wrap encryption.
 * A random CEK is generated and wrapped using ChaCha20-Poly1305 or
 * XChaCha20-Poly1305 with the provided 32-byte symmetric key.
 *
 * This is a non-standard extension (not defined in RFC 7518).
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(encrypted) = jwe.new_chacha20_kw(gose.XC20PKw, gose.AesGcm(gose.Aes256))
 *   |> jwe.encrypt(key, <<"hello":utf8>>)
 * ```
 */
export function new_chacha20_kw(variant, enc) {
  return new Jwe(
    new JweHeader(
      new $gose.ChaCha20KeyWrap(variant),
      enc,
      $option.Option$None$const,
      $option.Option$None$const,
      $option.Option$None$const,
    ),
    $option.Option$None$const,
    $dict.new$(),
    $dict.new$(),
    BuilderAlgFields$ChaCha20KwBuilderFields$const,
  );
}

/**
 * Create a new unencrypted JWE for direct key encryption. The symmetric key
 * is used directly as the Content Encryption Key (CEK).
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(encrypted) = jwe.new_direct(gose.AesGcm(gose.Aes256))
 *   |> jwe.encrypt(key, <<"hello":utf8>>)
 * ```
 */
export function new_direct(enc) {
  return new Jwe(
    new JweHeader(
      $gose.KeyEncryptionAlg$Direct$const,
      enc,
      $option.Option$None$const,
      $option.Option$None$const,
      $option.Option$None$const,
    ),
    $option.Option$None$const,
    $dict.new$(),
    $dict.new$(),
    BuilderAlgFields$NoBuilderAlgFields$const,
  );
}

/**
 * Create a new unencrypted JWE for ECDH-ES key agreement. An ephemeral key
 * pair is generated during encryption for the key agreement.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(encrypted) = jwe.new_ecdh_es(gose.EcdhEsDirect, gose.AesGcm(gose.Aes256))
 *   |> jwe.encrypt(key, <<"hello":utf8>>)
 * ```
 */
export function new_ecdh_es(alg, enc) {
  let alg_fields = new EcdhEsBuilderFields(
    $option.Option$None$const,
    $option.Option$None$const,
  );
  return new Jwe(
    new JweHeader(
      new $gose.EcdhEs(alg),
      enc,
      $option.Option$None$const,
      $option.Option$None$const,
      $option.Option$None$const,
    ),
    $option.Option$None$const,
    $dict.new$(),
    $dict.new$(),
    alg_fields,
  );
}

/**
 * Create a new unencrypted JWE for PBES2 password-based encryption. The CEK
 * is derived from the password using PBKDF2.
 *
 * Use `with_p2c` to override the default iteration count. The salt
 * is generated automatically.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(encrypted) = jwe.new_pbes2(gose.Pbes2Sha256Aes128Kw, gose.AesGcm(gose.Aes128))
 *   |> jwe.encrypt_with_password("secret", <<"hello":utf8>>)
 * ```
 */
export function new_pbes2(alg, enc) {
  return new Jwe(
    new JweHeader(
      new $gose.Pbes2(alg),
      enc,
      $option.Option$None$const,
      $option.Option$None$const,
      $option.Option$None$const,
    ),
    $option.Option$None$const,
    $dict.new$(),
    $dict.new$(),
    new Pbes2BuilderFields($option.Option$None$const),
  );
}

/**
 * Create a new unencrypted JWE for RSA key encryption. A random CEK is
 * generated and encrypted with the RSA public key.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(encrypted) = jwe.new_rsa(gose.RsaOaepSha256, gose.AesGcm(gose.Aes256))
 *   |> jwe.encrypt(rsa_key, <<"hello":utf8>>)
 * ```
 */
export function new_rsa(alg, enc) {
  return new Jwe(
    new JweHeader(
      new $gose.RsaEncryption(alg),
      enc,
      $option.Option$None$const,
      $option.Option$None$const,
      $option.Option$None$const,
    ),
    $option.Option$None$const,
    $dict.new$(),
    $dict.new$(),
    BuilderAlgFields$NoBuilderAlgFields$const,
  );
}

/**
 * Create a password-based decryptor for PBES2 algorithms.
 *
 * The decryptor pins the expected algorithm and encryption method.
 * Tokens with different algorithms will be rejected.
 *
 * ## Example
 *
 * ```gleam
 * let decryptor = jwe.password_decryptor(
 *   gose.Pbes2Sha256Aes128Kw,
 *   gose.AesGcm(gose.Aes128),
 *   "super-secret",
 * )
 * let assert Ok(plaintext) = jwe.decrypt(decryptor, encrypted_jwe)
 * ```
 */
export function password_decryptor(alg, enc, password) {
  return new PasswordDecryptor(alg, enc, password);
}

/**
 * Set the Additional Authenticated Data (AAD) for JSON serialization.
 *
 * AAD is only supported in JSON serialization (flattened and general formats).
 * Attempting to serialize to compact format with AAD set will return an error.
 */
export function with_aad(jwe, aad) {
  if (!(jwe instanceof Jwe)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      510,
      "with_aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 15906,
        end: 15930,
        pattern_start: 15917,
        pattern_end: 15924
      }
    )
  }
  return new Jwe(
    jwe.header,
    new $option.Some(aad),
    jwe.shared_unprotected,
    jwe.per_recipient_unprotected,
    jwe.alg_fields,
  );
}

/**
 * Set the Agreement PartyUInfo (apu) for ECDH-ES algorithms.
 *
 * ## Example
 *
 * ```gleam
 * let jwe = jwe.new_ecdh_es(gose.EcdhEsDirect, gose.AesGcm(gose.Aes256))
 *   |> jwe.with_apu(<<"Alice":utf8>>)
 *   |> jwe.with_apv(<<"Bob":utf8>>)
 * let assert Ok(encrypted) = jwe
 *   |> jwe.encrypt(key, <<"hello":utf8>>)
 * ```
 */
export function with_apu(jwe, apu) {
  if (!(jwe instanceof Jwe)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      529,
      "with_apu",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 16424,
        end: 16448,
        pattern_start: 16435,
        pattern_end: 16442
      }
    )
  }
  let $ = jwe.alg_fields;
  let apv;
  if ($ instanceof EcdhEsBuilderFields) {
    apv = $.apv;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      530,
      "with_apu",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 16451,
        end: 16508,
        pattern_start: 16462,
        pattern_end: 16491
      }
    )
  }
  return new Jwe(
    jwe.header,
    jwe.aad,
    jwe.shared_unprotected,
    jwe.per_recipient_unprotected,
    new EcdhEsBuilderFields(new $option.Some(apu), apv),
  );
}

/**
 * Set the Agreement PartyVInfo (apv) for ECDH-ES algorithms.
 *
 * ## Example
 *
 * ```gleam
 * let jwe = jwe.new_ecdh_es(gose.EcdhEsDirect, gose.AesGcm(gose.Aes256))
 *   |> jwe.with_apu(<<"Alice":utf8>>)
 *   |> jwe.with_apv(<<"Bob":utf8>>)
 * let assert Ok(encrypted) = jwe
 *   |> jwe.encrypt(key, <<"hello":utf8>>)
 * ```
 */
export function with_apv(jwe, apv) {
  if (!(jwe instanceof Jwe)) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      549,
      "with_apv",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 17041,
        end: 17065,
        pattern_start: 17052,
        pattern_end: 17059
      }
    )
  }
  let $ = jwe.alg_fields;
  let apu;
  if ($ instanceof EcdhEsBuilderFields) {
    apu = $.apu;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      550,
      "with_apv",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 17068,
        end: 17125,
        pattern_start: 17079,
        pattern_end: 17108
      }
    )
  }
  return new Jwe(
    jwe.header,
    jwe.aad,
    jwe.shared_unprotected,
    jwe.per_recipient_unprotected,
    new EcdhEsBuilderFields(apu, new $option.Some(apv)),
  );
}

/**
 * Set the content type (cty) header parameter.
 */
export function with_cty(jwe, cty) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      559,
      "with_cty",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 17366,
        end: 17399,
        pattern_start: 17377,
        pattern_end: 17393
      }
    )
  }
  return new Jwe(
    new JweHeader(
      header.alg,
      header.enc,
      header.kid,
      header.typ,
      new $option.Some(cty),
    ),
    jwe.aad,
    jwe.shared_unprotected,
    jwe.per_recipient_unprotected,
    jwe.alg_fields,
  );
}

/**
 * Set the key ID (kid) header parameter.
 */
export function with_kid(jwe, kid) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      568,
      "with_kid",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 17624,
        end: 17657,
        pattern_start: 17635,
        pattern_end: 17651
      }
    )
  }
  return new Jwe(
    new JweHeader(
      header.alg,
      header.enc,
      new $option.Some(kid),
      header.typ,
      header.cty,
    ),
    jwe.aad,
    jwe.shared_unprotected,
    jwe.per_recipient_unprotected,
    jwe.alg_fields,
  );
}

/**
 * Set the PBES2 iteration count (p2c) for password-based encryption.
 *
 * This allows customizing the PBKDF2 iteration count. Production should use
 * a value tuned for the specific use case.
 *
 * Returns an error if iterations is less than 1,000 or greater than
 * 10,000,000.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(jwe) =
 *   jwe.new_pbes2(gose.Pbes2Sha256Aes128Kw, gose.AesGcm(gose.Aes128))
 *   |> jwe.with_p2c(100_000)
 * ```
 */
export function with_p2c(jwe, iterations) {
  return $bool.guard(
    (iterations < min_p2c) || (iterations > max_p2c),
    new Error(
      new $gose.InvalidState(
        (("p2c must be >= " + $int.to_string(min_p2c)) + " and <= ") + $int.to_string(
          max_p2c,
        ),
      ),
    ),
    () => {
      if (jwe instanceof Jwe) {
        let $ = jwe.alg_fields;
        if (!($ instanceof Pbes2BuilderFields)) {
          throw makeError(
            "let_assert",
            FILEPATH,
            "gose/jose/jwe",
            600,
            "with_p2c",
            "Pattern match failed, no pattern matched the value.",
            {
              value: jwe,
              start: 18560,
              end: 18620,
              pattern_start: 18571,
              pattern_end: 18614
            }
          )
        }
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          600,
          "with_p2c",
          "Pattern match failed, no pattern matched the value.",
          {
            value: jwe,
            start: 18560,
            end: 18620,
            pattern_start: 18571,
            pattern_end: 18614
          }
        )
      }
      return new Ok(
        new Jwe(
          jwe.header,
          jwe.aad,
          jwe.shared_unprotected,
          jwe.per_recipient_unprotected,
          new Pbes2BuilderFields(new $option.Some(iterations)),
        ),
      );
    },
  );
}

function epk_to_json_field(epk) {
  if (epk instanceof $key_encryption.EcEphemeralKey) {
    let curve = epk.curve;
    let x = epk.x;
    let y = epk.y;
    return [
      "epk",
      $json.object(
        toList([
          ["kty", $json.string("EC")],
          ["crv", $json.string($utils.ec_curve_to_string(curve))],
          ["x", $json.string($utils.encode_base64_url(x))],
          ["y", $json.string($utils.encode_base64_url(y))],
        ]),
      ),
    ];
  } else {
    let curve = epk.curve;
    let x = epk.x;
    return [
      "epk",
      $json.object(
        toList([
          ["kty", $json.string("OKP")],
          ["crv", $json.string($utils.xdh_curve_to_string(curve))],
          ["x", $json.string($utils.encode_base64_url(x))],
        ]),
      ),
    ];
  }
}

function alg_fields_to_json(alg_fields) {
  if (alg_fields instanceof NoResolvedAlgFields) {
    return $List$Empty$const;
  } else if (alg_fields instanceof EcdhEsResolvedFields) {
    let epk = alg_fields.epk;
    let apu = alg_fields.apu;
    let apv = alg_fields.apv;
    return toList([
      $option.map(epk, epk_to_json_field),
      $option.map(
        apu,
        (a) => { return ["apu", $json.string($utils.encode_base64_url(a))]; },
      ),
      $option.map(
        apv,
        (a) => { return ["apv", $json.string($utils.encode_base64_url(a))]; },
      ),
    ]);
  } else if (alg_fields instanceof Pbes2ResolvedFields) {
    let p2s = alg_fields.p2s;
    let p2c = alg_fields.p2c;
    return toList([
      new $option.Some(["p2s", $json.string($utils.encode_base64_url(p2s))]),
      new $option.Some(["p2c", $json.int(p2c)]),
    ]);
  } else if (alg_fields instanceof AesGcmKwResolvedFields) {
    let kw_iv = alg_fields.kw_iv;
    let kw_tag = alg_fields.kw_tag;
    return toList([
      $option.map(
        kw_iv,
        (iv) => { return ["iv", $json.string($utils.encode_base64_url(iv))]; },
      ),
      $option.map(
        kw_tag,
        (t) => { return ["tag", $json.string($utils.encode_base64_url(t))]; },
      ),
    ]);
  } else if (alg_fields instanceof ChaCha20KwResolvedFields) {
    let kw_iv = alg_fields.kw_iv;
    let kw_tag = alg_fields.kw_tag;
    return toList([
      $option.map(
        kw_iv,
        (iv) => { return ["iv", $json.string($utils.encode_base64_url(iv))]; },
      ),
      $option.map(
        kw_tag,
        (t) => { return ["tag", $json.string($utils.encode_base64_url(t))]; },
      ),
    ]);
  } else {
    let epk = alg_fields.epk;
    let apu = alg_fields.apu;
    let apv = alg_fields.apv;
    let kw_iv = alg_fields.kw_iv;
    let kw_tag = alg_fields.kw_tag;
    return toList([
      $option.map(epk, epk_to_json_field),
      $option.map(
        apu,
        (a) => { return ["apu", $json.string($utils.encode_base64_url(a))]; },
      ),
      $option.map(
        apv,
        (a) => { return ["apv", $json.string($utils.encode_base64_url(a))]; },
      ),
      $option.map(
        kw_iv,
        (iv) => { return ["iv", $json.string($utils.encode_base64_url(iv))]; },
      ),
      $option.map(
        kw_tag,
        (t) => { return ["tag", $json.string($utils.encode_base64_url(t))]; },
      ),
    ]);
  }
}

function header_to_json(header, alg_fields) {
  let alg_field = [
    "alg",
    $json.string($jose.key_encryption_alg_to_string(header.alg)),
  ];
  let enc_field = ["enc", $json.string($jose.content_alg_to_string(header.enc))];
  let _block;
  let _pipe = listPrepend(
    $option.map(header.kid, (k) => { return ["kid", $json.string(k)]; }),
    listPrepend(
      $option.map(header.typ, (t) => { return ["typ", $json.string(t)]; }),
      listPrepend(
        $option.map(header.cty, (c) => { return ["cty", $json.string(c)]; }),
        alg_fields_to_json(alg_fields),
      ),
    ),
  );
  _block = $option.values(_pipe);
  let optional_fields = _block;
  let fields = listPrepend(alg_field, listPrepend(enc_field, optional_fields));
  let _pipe$1 = $json.object(fields);
  let _pipe$2 = $json.to_string(_pipe$1);
  return $bit_array.from_string(_pipe$2);
}

function finalize_encryption(jwe, cek, encrypted_key, alg_fields, plaintext) {
  let header;
  let aad$1;
  let shared_unprotected;
  let per_recipient_unprotected;
  if (jwe instanceof Jwe) {
    header = jwe.header;
    aad$1 = jwe.aad;
    shared_unprotected = jwe.shared_unprotected;
    per_recipient_unprotected = jwe.per_recipient_unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      930,
      "finalize_encryption",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 29914,
        end: 30027,
        pattern_start: 29925,
        pattern_end: 30021
      }
    )
  }
  let iv = $content_encryption.generate_iv(header.enc);
  let protected_json = header_to_json(header, alg_fields);
  let protected_b64 = $utils.encode_base64_url(protected_json);
  let aead_aad = $content_encryption.build_jwe_aad(protected_b64, aad$1);
  return $result.try$(
    $content_encryption.encrypt_content(
      header.enc,
      cek,
      iv,
      aead_aad,
      plaintext,
    ),
    (_use0) => {
      let ciphertext = _use0[0];
      let tag = _use0[1];
      return new Ok(
        new EncryptedJwe(
          header,
          protected_b64,
          encrypted_key,
          iv,
          ciphertext,
          tag,
          alg_fields,
          aad$1,
          shared_unprotected,
          $option.Option$None$const,
          per_recipient_unprotected,
          $option.Option$None$const,
        ),
      );
    },
  );
}

function do_encrypt_chacha20_kw(jwe, key, plaintext) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1006,
      "do_encrypt_chacha20_kw",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 31788,
        end: 31821,
        pattern_start: 31799,
        pattern_end: 31815
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(header.alg, key),
    (_) => {
      let $ = header.alg;
      let variant;
      if ($ instanceof $gose.ChaCha20KeyWrap) {
        variant = $[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          1012,
          "do_encrypt_chacha20_kw",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 31922,
            end: 31975,
            pattern_start: 31933,
            pattern_end: 31962
          }
        )
      }
      return $result.try$(
        $key_encryption.get_octet_key(key, 32),
        (kek) => {
          let cek = $content_encryption.generate_cek(header.enc);
          let nonce_size = $gose.chacha20_kw_nonce_size(variant);
          let kw_iv = $crypto.random_bytes(nonce_size);
          return $result.try$(
            $key_encryption.wrap_chacha20_by_variant(kek, cek, kw_iv, variant),
            (_use0) => {
              let encrypted_cek = _use0[0];
              let kw_tag = _use0[1];
              let out_alg_fields = new ChaCha20KwResolvedFields(
                new $option.Some(kw_iv),
                new $option.Some(kw_tag),
              );
              return finalize_encryption(
                jwe,
                cek,
                encrypted_cek,
                out_alg_fields,
                plaintext,
              );
            },
          );
        },
      );
    },
  );
}

function wrap_ecdh_by_alg(alg, enc, key, apu, apv) {
  if (alg instanceof $gose.EcdhEsDirect) {
    let alg_id = $jose.content_alg_to_string(enc);
    return $result.try$(
      $key_encryption.wrap_ecdh_es_direct(key, enc, alg_id, apu, apv),
      (_use0) => {
        let derived_cek = _use0[0];
        let epk = _use0[1];
        return new Ok(
          [
            derived_cek,
            toBitArray([]),
            new EcdhEsResolvedFields(new $option.Some(epk), apu, apv),
          ],
        );
      },
    );
  } else if (alg instanceof $gose.EcdhEsAesKw) {
    let size = alg[0];
    let cek = $content_encryption.generate_cek(enc);
    let alg_id = $jose.key_encryption_alg_to_string(
      new $gose.EcdhEs(new $gose.EcdhEsAesKw(size)),
    );
    return $result.try$(
      $key_encryption.wrap_ecdh_es_kw(key, cek, size, alg_id, apu, apv),
      (_use0) => {
        let wrapped = _use0[0];
        let epk = _use0[1];
        return new Ok(
          [
            cek,
            wrapped,
            new EcdhEsResolvedFields(new $option.Some(epk), apu, apv),
          ],
        );
      },
    );
  } else {
    let variant = alg[0];
    let cek = $content_encryption.generate_cek(enc);
    let alg_id = $jose.key_encryption_alg_to_string(
      new $gose.EcdhEs(new $gose.EcdhEsChaCha20Kw(variant)),
    );
    return $result.try$(
      $key_encryption.wrap_ecdh_es_chacha20_kw(
        key,
        cek,
        variant,
        alg_id,
        apu,
        apv,
      ),
      (_use0) => {
        let encrypted_cek = _use0[0];
        let epk = _use0[1];
        let kw_iv = _use0[2];
        let kw_tag = _use0[3];
        return new Ok(
          [
            cek,
            encrypted_cek,
            new EcdhEsChaCha20KwResolvedFields(
              new $option.Some(epk),
              apu,
              apv,
              new $option.Some(kw_iv),
              new $option.Some(kw_tag),
            ),
          ],
        );
      },
    );
  }
}

function extract_ecdh_apu_apv(alg_fields) {
  let apu;
  let apv;
  if (alg_fields instanceof EcdhEsBuilderFields) {
    apu = alg_fields.apu;
    apv = alg_fields.apv;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1144,
      "extract_ecdh_apu_apv",
      "Pattern match failed, no pattern matched the value.",
      {
        value: alg_fields,
        start: 35474,
        end: 35529,
        pattern_start: 35485,
        pattern_end: 35516
      }
    )
  }
  return [apu, apv];
}

function do_encrypt_ecdh(jwe, key, plaintext) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1153,
      "do_encrypt_ecdh",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 35718,
        end: 35751,
        pattern_start: 35729,
        pattern_end: 35745
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(header.alg, key),
    (_) => {
      let $ = extract_ecdh_apu_apv(jwe.alg_fields);
      let apu = $[0];
      let apv = $[1];
      return $bool.guard(
        ($option.is_some(apu) && $option.is_some(apv)) && (isEqual(apu, apv)),
        new Error(new $gose.InvalidState("apu and apv must be distinct")),
        () => {
          let $1 = header.alg;
          let ecdh_alg;
          if ($1 instanceof $gose.EcdhEs) {
            ecdh_alg = $1[0];
          } else {
            throw makeError(
              "let_assert",
              FILEPATH,
              "gose/jose/jwe",
              1166,
              "do_encrypt_ecdh",
              "Pattern match failed, no pattern matched the value.",
              {
                value: $1,
                start: 36074,
                end: 36119,
                pattern_start: 36085,
                pattern_end: 36106
              }
            )
          }
          return $result.try$(
            wrap_ecdh_by_alg(ecdh_alg, header.enc, key, apu, apv),
            (_use0) => {
              let cek = _use0[0];
              let encrypted_key = _use0[1];
              let out_alg_fields = _use0[2];
              return finalize_encryption(
                jwe,
                cek,
                encrypted_key,
                out_alg_fields,
                plaintext,
              );
            },
          );
        },
      );
    },
  );
}

function wrap_rsa_by_alg(alg, key, cek) {
  if (alg instanceof $gose.RsaPkcs1v15) {
    return $key_encryption.wrap_rsa_pkcs1v15(key, cek);
  } else if (alg instanceof $gose.RsaOaepSha1) {
    return $key_encryption.wrap_rsa_oaep(
      key,
      cek,
      $hash.HashAlgorithm$Sha1$const,
    );
  } else {
    return $key_encryption.wrap_rsa_oaep(
      key,
      cek,
      $hash.HashAlgorithm$Sha256$const,
    );
  }
}

function do_encrypt_rsa(jwe, key, plaintext) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1196,
      "do_encrypt_rsa",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 36910,
        end: 36943,
        pattern_start: 36921,
        pattern_end: 36937
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(header.alg, key),
    (_) => {
      let cek = $content_encryption.generate_cek(header.enc);
      let $ = header.alg;
      let rsa_alg;
      if ($ instanceof $gose.RsaEncryption) {
        rsa_alg = $[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          1203,
          "do_encrypt_rsa",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 37100,
            end: 37151,
            pattern_start: 37111,
            pattern_end: 37138
          }
        )
      }
      return $result.try$(
        wrap_rsa_by_alg(rsa_alg, key, cek),
        (encrypted_key) => {
          return finalize_encryption(
            jwe,
            cek,
            encrypted_key,
            ResolvedAlgFields$NoResolvedAlgFields$const,
            plaintext,
          );
        },
      );
    },
  );
}

function do_encrypt_aes_gcm_kw(jwe, key, plaintext) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      971,
      "do_encrypt_aes_gcm_kw",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 30890,
        end: 30923,
        pattern_start: 30901,
        pattern_end: 30917
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(header.alg, key),
    (_) => {
      let $ = header.alg;
      let aes_size;
      if ($ instanceof $gose.AesKeyWrap) {
        aes_size = $[1];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          977,
          "do_encrypt_aes_gcm_kw",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 31024,
            end: 31076,
            pattern_start: 31035,
            pattern_end: 31063
          }
        )
      }
      return $result.try$(
        $key_encryption.get_octet_key(key, $gose.aes_key_size(aes_size)),
        (kek) => {
          let cek = $content_encryption.generate_cek(header.enc);
          let kw_iv = $crypto.random_bytes(12);
          return $result.try$(
            $key_encryption.wrap_aes_gcm(kek, cek, kw_iv, aes_size),
            (_use0) => {
              let encrypted_cek = _use0[0];
              let kw_tag = _use0[1];
              let out_alg_fields = new AesGcmKwResolvedFields(
                new $option.Some(kw_iv),
                new $option.Some(kw_tag),
              );
              return finalize_encryption(
                jwe,
                cek,
                encrypted_cek,
                out_alg_fields,
                plaintext,
              );
            },
          );
        },
      );
    },
  );
}

function do_encrypt_aes_kw(jwe, key, plaintext) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1036,
      "do_encrypt_aes_kw",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 32707,
        end: 32740,
        pattern_start: 32718,
        pattern_end: 32734
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(header.alg, key),
    (_) => {
      let cek = $content_encryption.generate_cek(header.enc);
      let $ = header.alg;
      let aes_size;
      if ($ instanceof $gose.AesKeyWrap) {
        aes_size = $[1];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          1043,
          "do_encrypt_aes_kw",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 32897,
            end: 32949,
            pattern_start: 32908,
            pattern_end: 32936
          }
        )
      }
      return $result.try$(
        $key_encryption.wrap_aes_kw(key, cek, aes_size),
        (encrypted_key) => {
          return finalize_encryption(
            jwe,
            cek,
            encrypted_key,
            ResolvedAlgFields$NoResolvedAlgFields$const,
            plaintext,
          );
        },
      );
    },
  );
}

function do_encrypt_direct(jwe, key, plaintext) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1058,
      "do_encrypt_direct",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 33312,
        end: 33345,
        pattern_start: 33323,
        pattern_end: 33339
      }
    )
  }
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(header.alg, key),
    (_) => {
      return $result.try$(
        $key_encryption.unwrap_direct(key, header.enc),
        (cek) => {
          return finalize_encryption(
            jwe,
            cek,
            toBitArray([]),
            ResolvedAlgFields$NoResolvedAlgFields$const,
            plaintext,
          );
        },
      );
    },
  );
}

/**
 * Encrypt a JWE using the appropriate key-based algorithm.
 *
 * Dispatches to the correct key encryption method based on the algorithm
 * selected when the JWE was created. Supports direct, AES Key Wrap,
 * AES-GCM Key Wrap, RSA, and ECDH-ES algorithms.
 *
 * For PBES2 password-based algorithms, use `encrypt_with_password` instead.
 *
 * JWK metadata (`use`, `key_ops`) is enforced when present:
 * - Keys with `use=sig` are rejected
 * - Keys with `key_ops` that don't include `encrypt` or `wrapKey` are rejected
 *
 * ## Example
 *
 * ```gleam
 * let key = gose.generate_enc_key(gose.AesGcm(gose.Aes256))
 * let assert Ok(encrypted) = jwe.new_direct(gose.AesGcm(gose.Aes256))
 *   |> jwe.encrypt(key, <<"hello":utf8>>)
 * ```
 */
export function encrypt(jwe, key, plaintext) {
  let $ = jwe.header.alg;
  if ($ instanceof $gose.Direct) {
    return do_encrypt_direct(jwe, key, plaintext);
  } else if ($ instanceof $gose.AesKeyWrap) {
    let $1 = $[0];
    if ($1 instanceof $gose.AesKw) {
      return do_encrypt_aes_kw(jwe, key, plaintext);
    } else {
      return do_encrypt_aes_gcm_kw(jwe, key, plaintext);
    }
  } else if ($ instanceof $gose.ChaCha20KeyWrap) {
    return do_encrypt_chacha20_kw(jwe, key, plaintext);
  } else if ($ instanceof $gose.RsaEncryption) {
    return do_encrypt_rsa(jwe, key, plaintext);
  } else if ($ instanceof $gose.EcdhEs) {
    return do_encrypt_ecdh(jwe, key, plaintext);
  } else {
    return new Error(
      new $gose.InvalidState(
        "PBES2 algorithms require a password; use encrypt_with_password",
      ),
    );
  }
}

function resolve_pbes2_params(alg) {
  if (alg instanceof $gose.Pbes2Sha256Aes128Kw) {
    return [
      $hash.HashAlgorithm$Sha256$const,
      $gose.AesKeySize$Aes128$const,
      310_000,
    ];
  } else if (alg instanceof $gose.Pbes2Sha384Aes192Kw) {
    return [
      $hash.HashAlgorithm$Sha384$const,
      $gose.AesKeySize$Aes192$const,
      250_000,
    ];
  } else {
    return [
      $hash.HashAlgorithm$Sha512$const,
      $gose.AesKeySize$Aes256$const,
      120_000,
    ];
  }
}

/**
 * Encrypt a JWE using a password (PBES2).
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(encrypted) = jwe.new_pbes2(gose.Pbes2Sha256Aes128Kw, gose.AesGcm(gose.Aes128))
 *   |> jwe.encrypt_with_password("super-secret", <<"hello":utf8>>)
 * ```
 */
export function encrypt_with_password(jwe, password, plaintext) {
  let header;
  let custom_p2c;
  if (jwe instanceof Jwe) {
    let $ = jwe.alg_fields;
    if ($ instanceof Pbes2BuilderFields) {
      header = jwe.header;
      custom_p2c = $.p2c;
    } else {
      throw makeError(
        "let_assert",
        FILEPATH,
        "gose/jose/jwe",
        656,
        "encrypt_with_password",
        "Pattern match failed, no pattern matched the value.",
        {
          value: jwe,
          start: 20670,
          end: 20756,
          pattern_start: 20681,
          pattern_end: 20746
        }
      )
    }
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      656,
      "encrypt_with_password",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 20670,
        end: 20756,
        pattern_start: 20681,
        pattern_end: 20746
      }
    )
  }
  let $1 = header.alg;
  let pbes2_alg;
  if ($1 instanceof $gose.Pbes2) {
    pbes2_alg = $1[0];
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      659,
      "encrypt_with_password",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $1,
        start: 20760,
        end: 20805,
        pattern_start: 20771,
        pattern_end: 20792
      }
    )
  }
  let $2 = resolve_pbes2_params(pbes2_alg);
  let hash_alg = $2[0];
  let kw_size = $2[1];
  let default_iterations = $2[2];
  let kw_key_len = $gose.aes_key_size(kw_size);
  let iterations = $option.unwrap(custom_p2c, default_iterations);
  let salt_input = $crypto.random_bytes(16);
  let alg_str = $jose.key_encryption_alg_to_string(header.alg);
  let salt = $bit_array.concat(
    toList([$bit_array.from_string(alg_str), toBitArray([0]), salt_input]),
  );
  return $result.try$(
    (() => {
      let _pipe = $crypto.pbkdf2(
        hash_alg,
        $bit_array.from_string(password),
        salt,
        iterations,
        kw_key_len,
      );
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("PBKDF2 key derivation failed"),
      );
    })(),
    (kek) => {
      let cek = $content_encryption.generate_cek(header.enc);
      return $result.try$(
        $content_encryption.aes_cipher(kw_size, kek),
        (cipher) => {
          return $result.try$(
            (() => {
              let _pipe = $block.wrap(cipher, cek);
              return $result.replace_error(
                _pipe,
                new $gose.CryptoError("AES Key Wrap failed"),
              );
            })(),
            (encrypted_key) => {
              let out_alg_fields = new Pbes2ResolvedFields(
                salt_input,
                iterations,
              );
              return finalize_encryption(
                jwe,
                cek,
                encrypted_key,
                out_alg_fields,
                plaintext,
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Add a shared unprotected header parameter.
 *
 * **Security Warning:** Shared unprotected headers are NOT integrity protected.
 * They can be modified by an attacker without detection.
 *
 * Returns an error if the name is a protected-only header (`alg`, `enc`,
 * `crit`, `zip`) which must be integrity protected.
 *
 * Shared unprotected headers apply to all recipients in JSON serialization.
 * Compact serialization will return an error if unprotected headers are present.
 *
 * If the same header name is set multiple times, the last value wins.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(jwe) =
 *   jwe.new_direct(gose.AesGcm(gose.Aes256))
 *   |> jwe.with_shared_unprotected("x-request-id", json.string("abc-123"))
 * ```
 */
export function with_shared_unprotected(jwe, name, value) {
  return $bool.guard(
    $list.contains(protected_only_headers, name),
    new Error(
      new $gose.InvalidState(
        "protected-only header cannot be in unprotected: " + name,
      ),
    ),
    () => {
      let shared_unprotected;
      if (jwe instanceof Jwe) {
        shared_unprotected = jwe.shared_unprotected;
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          722,
          "with_shared_unprotected",
          "Pattern match failed, no pattern matched the value.",
          {
            value: jwe,
            start: 23003,
            end: 23048,
            pattern_start: 23014,
            pattern_end: 23042
          }
        )
      }
      return new Ok(
        new Jwe(
          jwe.header,
          jwe.aad,
          $dict.insert(shared_unprotected, name, value),
          jwe.per_recipient_unprotected,
          jwe.alg_fields,
        ),
      );
    },
  );
}

/**
 * Set the type (typ) header parameter (e.g., "JWT").
 */
export function with_typ(jwe, typ) {
  let header;
  if (jwe instanceof Jwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      733,
      "with_typ",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 23312,
        end: 23345,
        pattern_start: 23323,
        pattern_end: 23339
      }
    )
  }
  return new Jwe(
    new JweHeader(
      header.alg,
      header.enc,
      header.kid,
      new $option.Some(typ),
      header.cty,
    ),
    jwe.aad,
    jwe.shared_unprotected,
    jwe.per_recipient_unprotected,
    jwe.alg_fields,
  );
}

/**
 * Add a per-recipient unprotected header parameter.
 *
 * **Security Warning:** Per-recipient unprotected headers are NOT integrity protected.
 * They can be modified by an attacker without detection.
 *
 * Returns an error if the name is a protected-only header (`alg`, `enc`,
 * `crit`, `zip`) which must be integrity protected.
 *
 * Per-recipient headers appear in JSON serialization only and apply to
 * the single recipient. Compact serialization will return an error if
 * unprotected headers are present.
 *
 * If the same header name is set multiple times, the last value wins.
 */
export function with_unprotected(jwe, name, value) {
  return $bool.guard(
    $list.contains(protected_only_headers, name),
    new Error(
      new $gose.InvalidState(
        "protected-only header cannot be in unprotected: " + name,
      ),
    ),
    () => {
      let per_recipient_unprotected;
      if (jwe instanceof Jwe) {
        per_recipient_unprotected = jwe.per_recipient_unprotected;
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          761,
          "with_unprotected",
          "Pattern match failed, no pattern matched the value.",
          {
            value: jwe,
            start: 24383,
            end: 24435,
            pattern_start: 24394,
            pattern_end: 24429
          }
        )
      }
      return new Ok(
        new Jwe(
          jwe.header,
          jwe.aad,
          jwe.shared_unprotected,
          $dict.insert(per_recipient_unprotected, name, value),
          jwe.alg_fields,
        ),
      );
    },
  );
}

/**
 * Get the Additional Authenticated Data (AAD) from an encrypted JWE.
 *
 * Returns `Ok(aad)` if AAD was set, `Error(Nil)` if not.
 * AAD is only present in JSON serialization; compact format never has AAD.
 */
export function aad(jwe) {
  let aad$1;
  if (jwe instanceof EncryptedJwe) {
    aad$1 = jwe.aad;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      779,
      "aad",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 24885,
        end: 24924,
        pattern_start: 24896,
        pattern_end: 24918
      }
    )
  }
  return $option.to_result(aad$1, undefined);
}

/**
 * Get the key encryption algorithm (`alg`) from a JWE.
 */
export function alg(jwe) {
  if (jwe instanceof Jwe) {
    let header = jwe.header;
    return header.alg;
  } else {
    let header = jwe.header;
    return header.alg;
  }
}

/**
 * Get the content type (cty) from a JWE header.
 */
export function cty(jwe) {
  if (jwe instanceof Jwe) {
    let header = jwe.header;
    return $option.to_result(header.cty, undefined);
  } else {
    let header = jwe.header;
    return $option.to_result(header.cty, undefined);
  }
}

/**
 * Decode the shared unprotected header using a custom decoder.
 *
 * **Security Warning:** Shared unprotected headers are NOT integrity protected.
 * Values can be modified by an attacker without detection. Never trust
 * security-critical parameters from unprotected headers.
 *
 * This function only works on parsed JWE instances. When building a JWE,
 * you already know what unprotected headers you set - use `has_shared_unprotected_header`
 * to check their presence.
 *
 * Returns an error if no shared unprotected headers are present.
 *
 * ## Example
 *
 * ```gleam
 * let decoder = {
 *   use id <- decode.field("x-request-id", decode.string)
 *   decode.success(id)
 * }
 * let assert Ok(request_id) =
 *   jwe.decode_shared_unprotected_header(parsed_jwe, decoder)
 * ```
 */
export function decode_shared_unprotected_header(jwe, decoder) {
  let shared_unprotected_raw;
  if (jwe instanceof EncryptedJwe) {
    shared_unprotected_raw = jwe.shared_unprotected_raw;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      824,
      "decode_shared_unprotected_header",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 26349,
        end: 26407,
        pattern_start: 26360,
        pattern_end: 26401
      }
    )
  }
  if (shared_unprotected_raw instanceof $option.Some) {
    let raw = shared_unprotected_raw[0];
    let _pipe = $decode.run(raw, decoder);
    return $result.replace_error(
      _pipe,
      new $gose.ParseError("failed to decode shared unprotected header"),
    );
  } else {
    return new Error(
      new $gose.ParseError("no shared unprotected headers present"),
    );
  }
}

/**
 * Decode the per-recipient unprotected header using a custom decoder.
 *
 * **Security Warning:** Per-recipient unprotected headers are NOT integrity protected.
 * Values can be modified by an attacker without detection. Never trust
 * security-critical parameters from unprotected headers.
 *
 * This function only works on parsed JWE instances. When building a JWE,
 * you already know what unprotected headers you set - use `has_unprotected_header`
 * to check their presence.
 *
 * Returns an error if no per-recipient unprotected headers are present.
 *
 * ## Example
 *
 * ```gleam
 * let decoder = {
 *   use id <- decode.field("x-recipient-id", decode.string)
 *   decode.success(id)
 * }
 * let assert Ok(recipient_id) =
 *   jwe.decode_unprotected_header(parsed_jwe, decoder)
 * ```
 */
export function decode_unprotected_header(jwe, decoder) {
  let per_recipient_unprotected_raw;
  if (jwe instanceof EncryptedJwe) {
    per_recipient_unprotected_raw = jwe.per_recipient_unprotected_raw;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      862,
      "decode_unprotected_header",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 27655,
        end: 27720,
        pattern_start: 27666,
        pattern_end: 27714
      }
    )
  }
  if (per_recipient_unprotected_raw instanceof $option.Some) {
    let raw = per_recipient_unprotected_raw[0];
    let _pipe = $decode.run(raw, decoder);
    return $result.replace_error(
      _pipe,
      new $gose.ParseError("failed to decode per-recipient unprotected header"),
    );
  } else {
    return new Error(
      new $gose.ParseError("no per-recipient unprotected headers present"),
    );
  }
}

/**
 * Get the content encryption algorithm (`enc`) from a JWE.
 */
export function enc(jwe) {
  if (jwe instanceof Jwe) {
    let header = jwe.header;
    return header.enc;
  } else {
    let header = jwe.header;
    return header.enc;
  }
}

/**
 * Check if shared unprotected headers are present.
 *
 * Returns True if the JWE was parsed from JSON with shared unprotected headers,
 * or if shared unprotected headers were added via `with_shared_unprotected`.
 */
export function has_shared_unprotected_header(jwe) {
  let shared_unprotected;
  let shared_unprotected_raw;
  if (jwe instanceof EncryptedJwe) {
    shared_unprotected = jwe.shared_unprotected;
    shared_unprotected_raw = jwe.shared_unprotected_raw;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      888,
      "has_shared_unprotected_header",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 28553,
        end: 28636,
        pattern_start: 28564,
        pattern_end: 28626
      }
    )
  }
  return $option.is_some(shared_unprotected_raw) || !$dict.is_empty(
    shared_unprotected,
  );
}

/**
 * Check if per-recipient unprotected headers are present.
 *
 * Returns True if the JWE was parsed from JSON with per-recipient unprotected headers,
 * or if per-recipient unprotected headers were added via `with_unprotected`.
 */
export function has_unprotected_header(jwe) {
  let per_recipient_unprotected;
  let per_recipient_unprotected_raw;
  if (jwe instanceof EncryptedJwe) {
    per_recipient_unprotected = jwe.per_recipient_unprotected;
    per_recipient_unprotected_raw = jwe.per_recipient_unprotected_raw;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      898,
      "has_unprotected_header",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 29030,
        end: 29140,
        pattern_start: 29041,
        pattern_end: 29134
      }
    )
  }
  return $option.is_some(per_recipient_unprotected_raw) || !$dict.is_empty(
    per_recipient_unprotected,
  );
}

/**
 * Get the key ID (kid) from a JWE header.
 */
export function kid(jwe) {
  if (jwe instanceof Jwe) {
    let header = jwe.header;
    return $option.to_result(header.kid, undefined);
  } else {
    let header = jwe.header;
    return $option.to_result(header.kid, undefined);
  }
}

/**
 * Get the type (typ) from a JWE header.
 */
export function typ(jwe) {
  if (jwe instanceof Jwe) {
    let header = jwe.header;
    return $option.to_result(header.typ, undefined);
  } else {
    let header = jwe.header;
    return $option.to_result(header.typ, undefined);
  }
}

function unwrap_cek_ecdh(ecdh_alg, alg_fields, key, encrypted_key, enc) {
  if (ecdh_alg instanceof $gose.EcdhEsDirect) {
    let epk;
    let apu;
    let apv;
    if (alg_fields instanceof EcdhEsResolvedFields) {
      epk = alg_fields.epk;
      apu = alg_fields.apu;
      apv = alg_fields.apv;
    } else {
      throw makeError(
        "let_assert",
        FILEPATH,
        "gose/jose/jwe",
        1265,
        "unwrap_cek_ecdh",
        "Pattern match failed, no pattern matched the value.",
        {
          value: alg_fields,
          start: 39088,
          end: 39150,
          pattern_start: 39099,
          pattern_end: 39137
        }
      )
    }
    return $result.try$(
      $option.to_result(epk, new $gose.InvalidState("missing epk in header")),
      (epk) => {
        let alg_id = $jose.content_alg_to_string(enc);
        return $key_encryption.unwrap_ecdh_es_direct(
          key,
          enc,
          alg_id,
          epk,
          apu,
          apv,
        );
      },
    );
  } else if (ecdh_alg instanceof $gose.EcdhEsAesKw) {
    let size = ecdh_alg[0];
    let epk;
    let apu;
    let apv;
    if (alg_fields instanceof EcdhEsResolvedFields) {
      epk = alg_fields.epk;
      apu = alg_fields.apu;
      apv = alg_fields.apv;
    } else {
      throw makeError(
        "let_assert",
        FILEPATH,
        "gose/jose/jwe",
        1274,
        "unwrap_cek_ecdh",
        "Pattern match failed, no pattern matched the value.",
        {
          value: alg_fields,
          start: 39447,
          end: 39509,
          pattern_start: 39458,
          pattern_end: 39496
        }
      )
    }
    return $result.try$(
      $option.to_result(epk, new $gose.InvalidState("missing epk in header")),
      (epk) => {
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
      },
    );
  } else {
    let variant = ecdh_alg[0];
    let epk;
    let apu;
    let apv;
    let kw_iv;
    let kw_tag;
    if (alg_fields instanceof EcdhEsChaCha20KwResolvedFields) {
      epk = alg_fields.epk;
      apu = alg_fields.apu;
      apv = alg_fields.apv;
      kw_iv = alg_fields.kw_iv;
      kw_tag = alg_fields.kw_tag;
    } else {
      throw makeError(
        "let_assert",
        FILEPATH,
        "gose/jose/jwe",
        1292,
        "unwrap_cek_ecdh",
        "Pattern match failed, no pattern matched the value.",
        {
          value: alg_fields,
          start: 39939,
          end: 40077,
          pattern_start: 39950,
          pattern_end: 40064
        }
      )
    }
    return $result.try$(
      $option.to_result(epk, new $gose.InvalidState("missing epk in header")),
      (epk) => {
        return $result.try$(
          $option.to_result(
            kw_iv,
            new $gose.ParseError(
              "missing iv header for ECDH-ES+ChaCha20 Key Wrap",
            ),
          ),
          (kw_iv) => {
            return $result.try$(
              $option.to_result(
                kw_tag,
                new $gose.ParseError(
                  "missing tag header for ECDH-ES+ChaCha20 Key Wrap",
                ),
              ),
              (kw_tag) => {
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
              },
            );
          },
        );
      },
    );
  }
}

function unwrap_cek(header, alg_fields, key, encrypted_key) {
  let $ = header.alg;
  if ($ instanceof $gose.Direct) {
    return $key_encryption.unwrap_direct(key, header.enc);
  } else if ($ instanceof $gose.AesKeyWrap) {
    let $1 = $[0];
    if ($1 instanceof $gose.AesKw) {
      let aes_size = $[1];
      return $key_encryption.unwrap_aes_kw(key, encrypted_key, aes_size);
    } else {
      let aes_size = $[1];
      let kw_iv;
      let kw_tag;
      if (alg_fields instanceof AesGcmKwResolvedFields) {
        kw_iv = alg_fields.kw_iv;
        kw_tag = alg_fields.kw_tag;
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          1220,
          "unwrap_cek",
          "Pattern match failed, no pattern matched the value.",
          {
            value: alg_fields,
            start: 37724,
            end: 37787,
            pattern_start: 37735,
            pattern_end: 37774
          }
        )
      }
      return $key_encryption.unwrap_aes_gcm_kw(
        key,
        encrypted_key,
        aes_size,
        kw_iv,
        kw_tag,
      );
    }
  } else if ($ instanceof $gose.ChaCha20KeyWrap) {
    let variant = $[0];
    let kw_iv;
    let kw_tag;
    if (alg_fields instanceof ChaCha20KwResolvedFields) {
      kw_iv = alg_fields.kw_iv;
      kw_tag = alg_fields.kw_tag;
    } else {
      throw makeError(
        "let_assert",
        FILEPATH,
        "gose/jose/jwe",
        1240,
        "unwrap_cek",
        "Pattern match failed, no pattern matched the value.",
        {
          value: alg_fields,
          start: 38406,
          end: 38471,
          pattern_start: 38417,
          pattern_end: 38458
        }
      )
    }
    return $key_encryption.unwrap_chacha20_kw(
      key,
      encrypted_key,
      variant,
      kw_iv,
      kw_tag,
    );
  } else if ($ instanceof $gose.RsaEncryption) {
    let $1 = $[0];
    if ($1 instanceof $gose.RsaPkcs1v15) {
      return $key_encryption.unwrap_rsa_pkcs1v15_safe(
        key,
        encrypted_key,
        header.enc,
      );
    } else if ($1 instanceof $gose.RsaOaepSha1) {
      return $key_encryption.unwrap_rsa_oaep(
        key,
        encrypted_key,
        $hash.HashAlgorithm$Sha1$const,
      );
    } else {
      return $key_encryption.unwrap_rsa_oaep(
        key,
        encrypted_key,
        $hash.HashAlgorithm$Sha256$const,
      );
    }
  } else if ($ instanceof $gose.EcdhEs) {
    let ecdh_alg = $[0];
    return unwrap_cek_ecdh(ecdh_alg, alg_fields, key, encrypted_key, header.enc);
  } else {
    return new Error(
      new $gose.InvalidState("use password_decryptor for PBES2 algorithms"),
    );
  }
}

function decrypt_with_key(jwe, key) {
  let header;
  let protected_b64;
  let encrypted_key;
  let iv;
  let ciphertext;
  let tag;
  let alg_fields;
  let user_aad;
  if (jwe instanceof EncryptedJwe) {
    header = jwe.header;
    protected_b64 = jwe.protected_b64;
    encrypted_key = jwe.encrypted_key;
    iv = jwe.iv;
    ciphertext = jwe.ciphertext;
    tag = jwe.tag;
    alg_fields = jwe.alg_fields;
    user_aad = jwe.aad;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1334,
      "decrypt_with_key",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 40968,
        end: 41135,
        pattern_start: 40979,
        pattern_end: 41129
      }
    )
  }
  let _block;
  let $ = header.alg;
  if ($ instanceof $gose.EcdhEs) {
    _block = $key_helpers.KeyPurpose$ForKeyAgreement$const;
  } else {
    _block = $key_helpers.KeyPurpose$ForDecryption$const;
  }
  let ops_purpose = _block;
  return $result.try$(
    $key_helpers.validate_key_use(key, ops_purpose),
    (_) => {
      return $result.try$(
        $key_helpers.validate_key_ops(key, ops_purpose),
        (_) => {
          return $result.try$(
            $key_helpers.validate_key_algorithm_jwe(key, header.alg),
            (_) => {
              return $result.try$(
                unwrap_cek(header, alg_fields, key, encrypted_key),
                (cek) => {
                  let aead_aad = $content_encryption.build_jwe_aad(
                    protected_b64,
                    user_aad,
                  );
                  return $content_encryption.decrypt_content(
                    header.enc,
                    cek,
                    iv,
                    aead_aad,
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
}

function require_pbes2_alg(alg) {
  if (alg instanceof $gose.Direct) {
    return new Error(new $gose.InvalidState("expected PBES2 algorithm"));
  } else if (alg instanceof $gose.AesKeyWrap) {
    return new Error(new $gose.InvalidState("expected PBES2 algorithm"));
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    return new Error(new $gose.InvalidState("expected PBES2 algorithm"));
  } else if (alg instanceof $gose.RsaEncryption) {
    return new Error(new $gose.InvalidState("expected PBES2 algorithm"));
  } else if (alg instanceof $gose.EcdhEs) {
    return new Error(new $gose.InvalidState("expected PBES2 algorithm"));
  } else {
    let pbes2_alg = alg[0];
    return new Ok(pbes2_alg);
  }
}

function decrypt_with_password(jwe, password) {
  let header;
  let protected_b64;
  let encrypted_key;
  let iv;
  let ciphertext;
  let tag;
  let alg_fields;
  let user_aad;
  if (jwe instanceof EncryptedJwe) {
    header = jwe.header;
    protected_b64 = jwe.protected_b64;
    encrypted_key = jwe.encrypted_key;
    iv = jwe.iv;
    ciphertext = jwe.ciphertext;
    tag = jwe.tag;
    alg_fields = jwe.alg_fields;
    user_aad = jwe.aad;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1394,
      "decrypt_with_password",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 42554,
        end: 42721,
        pattern_start: 42565,
        pattern_end: 42715
      }
    )
  }
  return $result.try$(
    require_pbes2_alg(header.alg),
    (pbes2_alg) => {
      let $ = resolve_pbes2_params(pbes2_alg);
      let hash_alg = $[0];
      let kw_size = $[1];
      let kw_key_len = $gose.aes_key_size(kw_size);
      let salt_input;
      let iterations;
      if (alg_fields instanceof Pbes2ResolvedFields) {
        salt_input = alg_fields.p2s;
        iterations = alg_fields.p2c;
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwe",
          1410,
          "decrypt_with_password",
          "Pattern match failed, no pattern matched the value.",
          {
            value: alg_fields,
            start: 42897,
            end: 42974,
            pattern_start: 42908,
            pattern_end: 42961
          }
        )
      }
      let alg_str = $jose.key_encryption_alg_to_string(header.alg);
      let salt = $bit_array.concat(
        toList([$bit_array.from_string(alg_str), toBitArray([0]), salt_input]),
      );
      return $result.try$(
        (() => {
          let _pipe = $crypto.pbkdf2(
            hash_alg,
            $bit_array.from_string(password),
            salt,
            iterations,
            kw_key_len,
          );
          return $result.replace_error(
            _pipe,
            new $gose.CryptoError("PBKDF2 key derivation failed"),
          );
        })(),
        (kek) => {
          return $result.try$(
            $content_encryption.aes_cipher(kw_size, kek),
            (cipher) => {
              return $result.try$(
                (() => {
                  let _pipe = $block.unwrap(cipher, encrypted_key);
                  return $result.replace_error(
                    _pipe,
                    new $gose.CryptoError("AES Key Unwrap failed"),
                  );
                })(),
                (cek) => {
                  let aead_aad = $content_encryption.build_jwe_aad(
                    protected_b64,
                    user_aad,
                  );
                  return $content_encryption.decrypt_content(
                    header.enc,
                    cek,
                    iv,
                    aead_aad,
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
}

function try_keys(loop$keys, loop$jwe, loop$decrypt_fn, loop$last_error) {
  while (true) {
    let keys = loop$keys;
    let jwe = loop$jwe;
    let decrypt_fn = loop$decrypt_fn;
    let last_error = loop$last_error;
    if (keys instanceof $Empty) {
      return last_error;
    } else {
      let key = keys.head;
      let rest = keys.tail;
      let $ = decrypt_fn(jwe, key);
      if ($ instanceof Ok) {
        return $;
      } else {
        let $1 = $[0];
        if ($1 instanceof $gose.CryptoError) {
          let e = $1;
          loop$keys = rest;
          loop$jwe = jwe;
          loop$decrypt_fn = decrypt_fn;
          loop$last_error = new Error(e);
        } else if ($1 instanceof $gose.VerificationFailed) {
          let e = $1;
          loop$keys = rest;
          loop$jwe = jwe;
          loop$decrypt_fn = decrypt_fn;
          loop$last_error = new Error(e);
        } else {
          return $;
        }
      }
    }
  }
}

function decrypt_with_keys(jwe, keys, decrypt_fn) {
  let ordered_keys = $key_helpers.order_keys_by_kid(
    keys,
    $option.from_result(kid(jwe)),
  );
  return try_keys(
    ordered_keys,
    jwe,
    decrypt_fn,
    new Error(new $gose.InvalidState("no keys provided")),
  );
}

function require_matching_jwe_algorithms(decryptor, actual_alg, actual_enc) {
  let _block;
  if (decryptor instanceof KeyDecryptor) {
    let alg$1 = decryptor.alg;
    let enc$1 = decryptor.enc;
    _block = [alg$1, enc$1];
  } else {
    let alg$1 = decryptor.alg;
    let enc$1 = decryptor.enc;
    _block = [new $gose.Pbes2(alg$1), enc$1];
  }
  let $ = _block;
  let expected_alg = $[0];
  let expected_enc = $[1];
  return $bool.guard(
    !isEqual(expected_alg, actual_alg),
    new Error(
      new $gose.InvalidState(
        (("algorithm mismatch: expected " + $jose.key_encryption_alg_to_string(
          expected_alg,
        )) + ", got ") + $jose.key_encryption_alg_to_string(actual_alg),
      ),
    ),
    () => {
      return $bool.guard(
        !isEqual(expected_enc, actual_enc),
        new Error(
          new $gose.InvalidState(
            (("encryption mismatch: expected " + $jose.content_alg_to_string(
              expected_enc,
            )) + ", got ") + $jose.content_alg_to_string(actual_enc),
          ),
        ),
        () => { return new Ok(undefined); },
      );
    },
  );
}

/**
 * Decrypt a JWE using a decryptor with algorithm pinning.
 *
 * This is the recommended way to decrypt JWEs as it prevents algorithm
 * confusion attacks by validating that the token's algorithms match
 * the expected algorithms configured in the decryptor.
 *
 * ## Example
 *
 * ```gleam
 * // Create a decryptor that only accepts A256GCM with direct encryption
 * let assert Ok(decryptor) = jwe.key_decryptor(gose.Direct, gose.AesGcm(gose.Aes256), [key])
 *
 * // This will fail if the token uses a different algorithm
 * let assert Ok(plaintext) = jwe.decrypt(decryptor, jwe)
 * ```
 */
export function decrypt(decryptor, jwe) {
  let header;
  if (jwe instanceof EncryptedJwe) {
    header = jwe.header;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1463,
      "decrypt",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 44522,
        end: 44564,
        pattern_start: 44533,
        pattern_end: 44558
      }
    )
  }
  return $result.try$(
    require_matching_jwe_algorithms(decryptor, header.alg, header.enc),
    (_) => {
      if (decryptor instanceof KeyDecryptor) {
        let keys = decryptor.keys;
        return decrypt_with_keys(jwe, keys, decrypt_with_key);
      } else {
        let password = decryptor.password;
        return decrypt_with_password(jwe, password);
      }
    },
  );
}

/**
 * Serialize an encrypted JWE to compact format.
 *
 * Format: `{protected}.{encrypted_key}.{iv}.{ciphertext}.{tag}`
 *
 * Returns an error if AAD is set, since compact format does not support AAD.
 * Use `serialize_json_flattened` or `serialize_json_general` for JWEs with AAD.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(token) = jwe.serialize_compact(encrypted)
 * // -> "eyJhbGci...ciphertext...tag"
 * ```
 */
export function serialize_compact(jwe) {
  let protected_b64;
  let encrypted_key;
  let iv;
  let ciphertext;
  let tag;
  let aad$1;
  let shared_unprotected;
  let per_recipient_unprotected;
  if (jwe instanceof EncryptedJwe) {
    protected_b64 = jwe.protected_b64;
    encrypted_key = jwe.encrypted_key;
    iv = jwe.iv;
    ciphertext = jwe.ciphertext;
    tag = jwe.tag;
    aad$1 = jwe.aad;
    shared_unprotected = jwe.shared_unprotected;
    per_recipient_unprotected = jwe.per_recipient_unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      1657,
      "serialize_compact",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 50219,
        end: 50404,
        pattern_start: 50230,
        pattern_end: 50398
      }
    )
  }
  return $bool.guard(
    $option.is_some(aad$1),
    new Error(
      new $gose.InvalidState(
        "cannot serialize to compact format: AAD is only supported in JSON serialization",
      ),
    ),
    () => {
      return $bool.guard(
        !$dict.is_empty(shared_unprotected) || !$dict.is_empty(
          per_recipient_unprotected,
        ),
        new Error(
          new $gose.InvalidState(
            "cannot serialize to compact format: unprotected headers are only supported in JSON serialization",
          ),
        ),
        () => {
          let ek_b64 = $utils.encode_base64_url(encrypted_key);
          let iv_b64 = $utils.encode_base64_url(iv);
          let ct_b64 = $utils.encode_base64_url(ciphertext);
          let tag_b64 = $utils.encode_base64_url(tag);
          return new Ok(
            (((((((protected_b64 + ".") + ek_b64) + ".") + iv_b64) + ".") + ct_b64) + ".") + tag_b64,
          );
        },
      );
    },
  );
}

function validate_encrypted_key_for_algorithm(alg, encrypted_key) {
  let _block;
  if (alg instanceof $gose.Direct) {
    _block = true;
  } else if (alg instanceof $gose.EcdhEs) {
    let $ = alg[0];
    if ($ instanceof $gose.EcdhEsDirect) {
      _block = true;
    } else {
      _block = false;
    }
  } else {
    _block = false;
  }
  let is_direct = _block;
  let key_size = $bit_array.byte_size(encrypted_key);
  if (is_direct) {
    if (key_size === 0) {
      return new Ok(undefined);
    } else {
      return new Error(
        new $gose.ParseError(
          "encrypted_key must be empty for " + $jose.key_encryption_alg_to_string(
            alg,
          ),
        ),
      );
    }
  } else if (key_size === 0) {
    return new Error(
      new $gose.ParseError(
        "encrypted_key required for " + $jose.key_encryption_alg_to_string(alg),
      ),
    );
  } else {
    return new Ok(undefined);
  }
}

function reject_disallowed_headers(loop$alg_str, loop$checks) {
  while (true) {
    let alg_str = loop$alg_str;
    let checks = loop$checks;
    if (checks instanceof $Empty) {
      return new Ok(undefined);
    } else {
      let $ = checks.head[0];
      if ($) {
        let name = checks.head[1];
        return new Error(
          new $gose.ParseError((name + " header not allowed for ") + alg_str),
        );
      } else {
        let rest = checks.tail;
        loop$alg_str = alg_str;
        loop$checks = rest;
      }
    }
  }
}

function validate_apu_apv_distinct(apu, apv) {
  let $ = ($option.is_some(apu) && $option.is_some(apv)) && (isEqual(apu, apv));
  if ($) {
    return new Error(new $gose.ParseError("apu and apv must be distinct"));
  } else {
    return new Ok(undefined);
  }
}

function build_parsed_alg_fields(alg, epk, apu, apv, p2s, p2c, kw_iv, kw_tag) {
  let alg_str = $jose.key_encryption_alg_to_string(alg);
  if (alg instanceof $gose.Direct) {
    return $result.try$(
      reject_disallowed_headers(
        alg_str,
        toList([
          [$option.is_some(epk), "epk"],
          [$option.is_some(apu), "apu"],
          [$option.is_some(apv), "apv"],
          [$option.is_some(p2s), "p2s"],
          [$option.is_some(p2c), "p2c"],
          [$option.is_some(kw_iv), "iv"],
          [$option.is_some(kw_tag), "tag"],
        ]),
      ),
      (_) => { return new Ok(ResolvedAlgFields$NoResolvedAlgFields$const); },
    );
  } else if (alg instanceof $gose.AesKeyWrap) {
    let $ = alg[0];
    if ($ instanceof $gose.AesKw) {
      return $result.try$(
        reject_disallowed_headers(
          alg_str,
          toList([
            [$option.is_some(epk), "epk"],
            [$option.is_some(apu), "apu"],
            [$option.is_some(apv), "apv"],
            [$option.is_some(p2s), "p2s"],
            [$option.is_some(p2c), "p2c"],
            [$option.is_some(kw_iv), "iv"],
            [$option.is_some(kw_tag), "tag"],
          ]),
        ),
        (_) => { return new Ok(ResolvedAlgFields$NoResolvedAlgFields$const); },
      );
    } else {
      return $result.try$(
        reject_disallowed_headers(
          alg_str,
          toList([
            [$option.is_some(epk), "epk"],
            [$option.is_some(apu), "apu"],
            [$option.is_some(apv), "apv"],
            [$option.is_some(p2s), "p2s"],
            [$option.is_some(p2c), "p2c"],
          ]),
        ),
        (_) => { return new Ok(new AesGcmKwResolvedFields(kw_iv, kw_tag)); },
      );
    }
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    return $result.try$(
      reject_disallowed_headers(
        alg_str,
        toList([
          [$option.is_some(epk), "epk"],
          [$option.is_some(apu), "apu"],
          [$option.is_some(apv), "apv"],
          [$option.is_some(p2s), "p2s"],
          [$option.is_some(p2c), "p2c"],
        ]),
      ),
      (_) => { return new Ok(new ChaCha20KwResolvedFields(kw_iv, kw_tag)); },
    );
  } else if (alg instanceof $gose.RsaEncryption) {
    return $result.try$(
      reject_disallowed_headers(
        alg_str,
        toList([
          [$option.is_some(epk), "epk"],
          [$option.is_some(apu), "apu"],
          [$option.is_some(apv), "apv"],
          [$option.is_some(p2s), "p2s"],
          [$option.is_some(p2c), "p2c"],
          [$option.is_some(kw_iv), "iv"],
          [$option.is_some(kw_tag), "tag"],
        ]),
      ),
      (_) => { return new Ok(ResolvedAlgFields$NoResolvedAlgFields$const); },
    );
  } else if (alg instanceof $gose.EcdhEs) {
    let $ = alg[0];
    if ($ instanceof $gose.EcdhEsChaCha20Kw) {
      return $result.try$(
        reject_disallowed_headers(
          alg_str,
          toList([[$option.is_some(p2s), "p2s"], [$option.is_some(p2c), "p2c"]]),
        ),
        (_) => {
          return $result.try$(
            validate_apu_apv_distinct(apu, apv),
            (_) => {
              return new Ok(
                new EcdhEsChaCha20KwResolvedFields(epk, apu, apv, kw_iv, kw_tag),
              );
            },
          );
        },
      );
    } else {
      return $result.try$(
        reject_disallowed_headers(
          alg_str,
          toList([[$option.is_some(p2s), "p2s"], [$option.is_some(p2c), "p2c"]]),
        ),
        (_) => {
          return $result.try$(
            validate_apu_apv_distinct(apu, apv),
            (_) => { return new Ok(new EcdhEsResolvedFields(epk, apu, apv)); },
          );
        },
      );
    }
  } else {
    return $result.try$(
      reject_disallowed_headers(
        alg_str,
        toList([
          [$option.is_some(epk), "epk"],
          [$option.is_some(apu), "apu"],
          [$option.is_some(apv), "apv"],
        ]),
      ),
      (_) => {
        return $result.try$(
          $option.to_result(
            p2s,
            new $gose.ParseError("missing p2s header for " + alg_str),
          ),
          (p2s) => {
            return $bool.guard(
              $bit_array.byte_size(p2s) < 8,
              new Error(new $gose.ParseError("p2s must be at least 8 bytes")),
              () => {
                return $result.try$(
                  $option.to_result(
                    p2c,
                    new $gose.ParseError("missing p2c header for " + alg_str),
                  ),
                  (p2c) => { return new Ok(new Pbes2ResolvedFields(p2s, p2c)); },
                );
              },
            );
          },
        );
      },
    );
  }
}

function parse_optional_base64(opt, name) {
  if (opt instanceof $option.Some) {
    let b64 = opt[0];
    return $result.try$(
      (() => {
        let _pipe = $bit_array.base64_url_decode(b64);
        return $result.replace_error(
          _pipe,
          new $gose.ParseError(("invalid " + name) + " base64"),
        );
      })(),
      (decoded) => { return new Ok(new $option.Some(decoded)); },
    );
  } else {
    return new Ok($option.Option$None$const);
  }
}

function parse_optional_epk(epk_raw) {
  if (epk_raw instanceof $option.Some) {
    let kty = epk_raw[0][0];
    let crv = epk_raw[0][1];
    let x_b64 = epk_raw[0][2];
    let y_opt = epk_raw[0][3];
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
    return new Ok($option.Option$None$const);
  }
}

function validate_crit(crit) {
  if (crit instanceof $option.Some) {
    let extensions = crit[0];
    return $utils.validate_crit_headers(
      extensions,
      standard_headers,
      $List$Empty$const,
    );
  } else {
    return new Ok(undefined);
  }
}

function parse_header_json(json_bits) {
  let epk_decoder = $decode.field(
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
                $option.Option$None$const,
                $decode.optional($decode.string),
                (y) => { return $decode.success([kty, crv, x, y]); },
              );
            },
          );
        },
      );
    },
  );
  let decoder = $decode.field(
    "alg",
    $decode.string,
    (alg) => {
      return $decode.field(
        "enc",
        $decode.string,
        (enc) => {
          return $decode.optional_field(
            "kid",
            $option.Option$None$const,
            $decode.optional($decode.string),
            (kid) => {
              return $decode.optional_field(
                "typ",
                $option.Option$None$const,
                $decode.optional($decode.string),
                (typ) => {
                  return $decode.optional_field(
                    "cty",
                    $option.Option$None$const,
                    $decode.optional($decode.string),
                    (cty) => {
                      return $decode.optional_field(
                        "epk",
                        $option.Option$None$const,
                        $decode.optional(epk_decoder),
                        (epk_raw) => {
                          return $decode.optional_field(
                            "apu",
                            $option.Option$None$const,
                            $decode.optional($decode.string),
                            (apu) => {
                              return $decode.optional_field(
                                "apv",
                                $option.Option$None$const,
                                $decode.optional($decode.string),
                                (apv) => {
                                  return $decode.optional_field(
                                    "p2s",
                                    $option.Option$None$const,
                                    $decode.optional($decode.string),
                                    (p2s) => {
                                      return $decode.optional_field(
                                        "p2c",
                                        $option.Option$None$const,
                                        $decode.optional($decode.int),
                                        (p2c) => {
                                          return $decode.optional_field(
                                            "iv",
                                            $option.Option$None$const,
                                            $decode.optional($decode.string),
                                            (kw_iv) => {
                                              return $decode.optional_field(
                                                "tag",
                                                $option.Option$None$const,
                                                $decode.optional($decode.string),
                                                (kw_tag) => {
                                                  return $decode.optional_field(
                                                    "crit",
                                                    $option.Option$None$const,
                                                    $decode.optional(
                                                      $decode.list(
                                                        $decode.string,
                                                      ),
                                                    ),
                                                    (crit) => {
                                                      return $decode.optional_field(
                                                        "zip",
                                                        $option.Option$None$const,
                                                        $decode.optional(
                                                          $decode.string,
                                                        ),
                                                        (zip) => {
                                                          return $decode.success(
                                                            [
                                                              alg,
                                                              enc,
                                                              kid,
                                                              typ,
                                                              cty,
                                                              epk_raw,
                                                              apu,
                                                              apv,
                                                              p2s,
                                                              p2c,
                                                              kw_iv,
                                                              kw_tag,
                                                              crit,
                                                              zip,
                                                            ],
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
  return $result.try$(
    (() => {
      let _pipe = $json.parse_bits(json_bits, decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("invalid header JSON"),
      );
    })(),
    (_use0) => {
      let alg_str = _use0[0];
      let enc_str = _use0[1];
      let kid$1 = _use0[2];
      let typ$1 = _use0[3];
      let cty$1 = _use0[4];
      let epk_raw = _use0[5];
      let apu_b64 = _use0[6];
      let apv_b64 = _use0[7];
      let p2s_b64 = _use0[8];
      let p2c = _use0[9];
      let kw_iv_b64 = _use0[10];
      let kw_tag_b64 = _use0[11];
      let crit = _use0[12];
      let zip = _use0[13];
      return $result.try$(
        validate_crit(crit),
        (_) => {
          return $bool.guard(
            $option.is_some(zip),
            new Error(new $gose.ParseError("unsupported header: zip")),
            () => {
              let _block;
              if (p2c instanceof $option.Some) {
                let iterations = p2c[0];
                _block = (iterations < min_p2c) || (iterations > max_p2c);
              } else {
                _block = false;
              }
              let p2c_out_of_range = _block;
              return $bool.guard(
                p2c_out_of_range,
                new Error(
                  new $gose.ParseError(
                    (("p2c must be >= " + $int.to_string(min_p2c)) + " and <= ") + $int.to_string(
                      max_p2c,
                    ),
                  ),
                ),
                () => {
                  return $result.try$(
                    $jose.key_encryption_alg_from_string(alg_str),
                    (alg) => {
                      return $result.try$(
                        $jose.content_alg_from_string(enc_str),
                        (enc) => {
                          return $result.try$(
                            parse_optional_epk(epk_raw),
                            (epk) => {
                              return $result.try$(
                                parse_optional_base64(apu_b64, "apu"),
                                (apu) => {
                                  return $result.try$(
                                    parse_optional_base64(apv_b64, "apv"),
                                    (apv) => {
                                      return $result.try$(
                                        parse_optional_base64(p2s_b64, "p2s"),
                                        (p2s) => {
                                          return $result.try$(
                                            parse_optional_base64(
                                              kw_iv_b64,
                                              "iv",
                                            ),
                                            (kw_iv) => {
                                              return $result.try$(
                                                parse_optional_base64(
                                                  kw_tag_b64,
                                                  "tag",
                                                ),
                                                (kw_tag) => {
                                                  return $result.try$(
                                                    build_parsed_alg_fields(
                                                      alg,
                                                      epk,
                                                      apu,
                                                      apv,
                                                      p2s,
                                                      p2c,
                                                      kw_iv,
                                                      kw_tag,
                                                    ),
                                                    (alg_fields) => {
                                                      let header = new JweHeader(
                                                        alg,
                                                        enc,
                                                        kid$1,
                                                        typ$1,
                                                        cty$1,
                                                      );
                                                      return new Ok(
                                                        new ParsedHeader(
                                                          header,
                                                          alg_fields,
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

/**
 * Parse a JWE from compact format.
 *
 * Returns an encrypted JWE that can be decrypted.
 * Uses Nil family since algorithm family isn't known at compile time.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(parsed) = jwe.parse_compact(token)
 * let assert Ok(decryptor) = jwe.key_decryptor(gose.Direct, gose.AesGcm(gose.Aes256), [key])
 * let assert Ok(plaintext) = jwe.decrypt(decryptor, parsed)
 * ```
 */
export function parse_compact(token) {
  let $ = $string.split(token, ".");
  if ($ instanceof $Empty) {
    return new Error(
      new $gose.ParseError("invalid compact serialization: expected 5 parts"),
    );
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      return new Error(
        new $gose.ParseError("invalid compact serialization: expected 5 parts"),
      );
    } else {
      let $2 = $1.tail;
      if ($2 instanceof $Empty) {
        return new Error(
          new $gose.ParseError(
            "invalid compact serialization: expected 5 parts",
          ),
        );
      } else {
        let $3 = $2.tail;
        if ($3 instanceof $Empty) {
          return new Error(
            new $gose.ParseError(
              "invalid compact serialization: expected 5 parts",
            ),
          );
        } else {
          let $4 = $3.tail;
          if ($4 instanceof $Empty) {
            return new Error(
              new $gose.ParseError(
                "invalid compact serialization: expected 5 parts",
              ),
            );
          } else {
            let $5 = $4.tail;
            if ($5 instanceof $Empty) {
              let protected_b64 = $.head;
              let ek_b64 = $1.head;
              let iv_b64 = $2.head;
              let ct_b64 = $3.head;
              let tag_b64 = $4.head;
              return $result.try$(
                parse_protected_header(protected_b64),
                (_use0) => {
                  let header = _use0.header;
                  let alg_fields = _use0.alg_fields;
                  return $result.try$(
                    $utils.decode_base64_url(ek_b64, "encrypted_key"),
                    (encrypted_key) => {
                      return $result.try$(
                        validate_encrypted_key_for_algorithm(
                          header.alg,
                          encrypted_key,
                        ),
                        (_) => {
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
                                          header.enc,
                                          iv,
                                          tag,
                                        ),
                                        (_) => {
                                          return new Ok(
                                            new EncryptedJwe(
                                              header,
                                              protected_b64,
                                              encrypted_key,
                                              iv,
                                              ciphertext,
                                              tag,
                                              alg_fields,
                                              $option.Option$None$const,
                                              $dict.new$(),
                                              $option.Option$None$const,
                                              $dict.new$(),
                                              $option.Option$None$const,
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
            } else {
              return new Error(
                new $gose.ParseError(
                  "invalid compact serialization: expected 5 parts",
                ),
              );
            }
          }
        }
      }
    }
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
 * Parse an unprotected header from a decode.Dynamic value.
 * Returns a tuple of (raw dynamic for decoder, header names for disjointness validation).
 * The dict is not populated. Parsed values are accessed via decoders on the raw dynamic.
 * 
 * @ignore
 */
function parse_unprotected_header(raw) {
  if (raw instanceof $option.Some) {
    let dyn = raw[0];
    return $result.try$(
      (() => {
        let _pipe = $decode.run(
          dyn,
          $decode.dict($decode.string, $decode.dynamic),
        );
        return $result.replace_error(
          _pipe,
          new $gose.ParseError("unprotected header must be a JSON object"),
        );
      })(),
      (unprotected_dict) => {
        let names = $dict.keys(unprotected_dict);
        return $result.try$(
          validate_no_protected_only_headers(names),
          (_) => { return new Ok([new $option.Some(dyn), names]); },
        );
      },
    );
  } else {
    return new Ok([$option.Option$None$const, $List$Empty$const]);
  }
}

function present_field_names(fields) {
  return $list.filter_map(
    fields,
    (field) => {
      let $ = field[0];
      if ($) {
        let name = field[1];
        return new Ok(name);
      } else {
        return new Error(undefined);
      }
    },
  );
}

/**
 * Validate that protected and unprotected headers have disjoint parameter names.
 * Per RFC 7516, the same parameter MUST NOT appear in both protected and unprotected.
 * 
 * @ignore
 */
function validate_jwe_header_disjointness(
  header,
  alg_fields,
  shared_unprotected_names,
  per_recipient_unprotected_names
) {
  let _block;
  if (alg_fields instanceof NoResolvedAlgFields) {
    _block = $List$Empty$const;
  } else if (alg_fields instanceof EcdhEsResolvedFields) {
    let epk = alg_fields.epk;
    let apu = alg_fields.apu;
    let apv = alg_fields.apv;
    _block = present_field_names(
      toList([
        [$option.is_some(epk), "epk"],
        [$option.is_some(apu), "apu"],
        [$option.is_some(apv), "apv"],
      ]),
    );
  } else if (alg_fields instanceof Pbes2ResolvedFields) {
    _block = toList(["p2s", "p2c"]);
  } else if (alg_fields instanceof AesGcmKwResolvedFields) {
    let kw_iv = alg_fields.kw_iv;
    let kw_tag = alg_fields.kw_tag;
    _block = present_field_names(
      toList([[$option.is_some(kw_iv), "iv"], [$option.is_some(kw_tag), "tag"]]),
    );
  } else if (alg_fields instanceof ChaCha20KwResolvedFields) {
    let kw_iv = alg_fields.kw_iv;
    let kw_tag = alg_fields.kw_tag;
    _block = present_field_names(
      toList([[$option.is_some(kw_iv), "iv"], [$option.is_some(kw_tag), "tag"]]),
    );
  } else {
    let epk = alg_fields.epk;
    let apu = alg_fields.apu;
    let apv = alg_fields.apv;
    let kw_iv = alg_fields.kw_iv;
    let kw_tag = alg_fields.kw_tag;
    _block = present_field_names(
      toList([
        [$option.is_some(epk), "epk"],
        [$option.is_some(apu), "apu"],
        [$option.is_some(apv), "apv"],
        [$option.is_some(kw_iv), "iv"],
        [$option.is_some(kw_tag), "tag"],
      ]),
    );
  }
  let alg_specific_names = _block;
  let protected_names = $list.flatten(
    toList([
      toList(["alg", "enc"]),
      present_field_names(
        toList([
          [$option.is_some(header.kid), "kid"],
          [$option.is_some(header.typ), "typ"],
          [$option.is_some(header.cty), "cty"],
        ]),
      ),
      alg_specific_names,
    ]),
  );
  let protected_set = $set.from_list(protected_names);
  let shared_names = shared_unprotected_names;
  let per_recipient_names = per_recipient_unprotected_names;
  let shared_overlap = $list.filter(
    shared_names,
    (_capture) => { return $set.contains(protected_set, _capture); },
  );
  return $bool.guard(
    !$list.is_empty(shared_overlap),
    new Error(
      new $gose.ParseError(
        "header parameter appears in both protected and shared unprotected: " + $string.join(
          shared_overlap,
          ", ",
        ),
      ),
    ),
    () => {
      let per_recipient_overlap = $list.filter(
        per_recipient_names,
        (_capture) => { return $set.contains(protected_set, _capture); },
      );
      return $bool.guard(
        !$list.is_empty(per_recipient_overlap),
        new Error(
          new $gose.ParseError(
            "header parameter appears in both protected and per-recipient unprotected: " + $string.join(
              per_recipient_overlap,
              ", ",
            ),
          ),
        ),
        () => {
          let shared_set = $set.from_list(shared_names);
          let shared_per_recipient_overlap = $list.filter(
            per_recipient_names,
            (_capture) => { return $set.contains(shared_set, _capture); },
          );
          return $bool.guard(
            !$list.is_empty(shared_per_recipient_overlap),
            new Error(
              new $gose.ParseError(
                "header parameter appears in both shared and per-recipient unprotected: " + $string.join(
                  shared_per_recipient_overlap,
                  ", ",
                ),
              ),
            ),
            () => { return new Ok(undefined); },
          );
        },
      );
    },
  );
}

function append_optional_jwe_fields(fields, shared_unprotected, aad) {
  let _block;
  let $ = $dict.is_empty(shared_unprotected);
  if ($) {
    _block = fields;
  } else {
    _block = listPrepend(
      ["unprotected", $json.object($dict.to_list(shared_unprotected))],
      fields,
    );
  }
  let fields$1 = _block;
  if (aad instanceof $option.Some) {
    let aad$1 = aad[0];
    let aad_b64 = $utils.encode_base64_url(aad$1);
    return listPrepend(["aad", $json.string(aad_b64)], fields$1);
  } else {
    return fields$1;
  }
}

/**
 * Serialize an encrypted JWE to JSON Flattened format.
 *
 * Format: `{"protected":"...","encrypted_key":"...","iv":"...","ciphertext":"...","tag":"..."}`
 *
 * For Direct or ECDH-ES algorithms, the encrypted_key field is omitted.
 * When AAD is present, includes the `aad` field.
 * When unprotected headers are present, includes the `unprotected` and/or `header` fields.
 *
 * For multiple recipients, use `gose/jose/jwe_multi`.
 */
export function serialize_json_flattened(jwe) {
  let protected_b64;
  let encrypted_key;
  let iv;
  let ciphertext;
  let tag;
  let aad$1;
  let shared_unprotected;
  let per_recipient_unprotected;
  if (jwe instanceof EncryptedJwe) {
    protected_b64 = jwe.protected_b64;
    encrypted_key = jwe.encrypted_key;
    iv = jwe.iv;
    ciphertext = jwe.ciphertext;
    tag = jwe.tag;
    aad$1 = jwe.aad;
    shared_unprotected = jwe.shared_unprotected;
    per_recipient_unprotected = jwe.per_recipient_unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      2262,
      "serialize_json_flattened",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 67858,
        end: 68043,
        pattern_start: 67869,
        pattern_end: 68037
      }
    )
  }
  let ek_b64 = $utils.encode_base64_url(encrypted_key);
  let iv_b64 = $utils.encode_base64_url(iv);
  let ct_b64 = $utils.encode_base64_url(ciphertext);
  let tag_b64 = $utils.encode_base64_url(tag);
  let _block;
  let $ = $bit_array.byte_size(encrypted_key);
  if ($ === 0) {
    _block = toList([
      ["protected", $json.string(protected_b64)],
      ["iv", $json.string(iv_b64)],
      ["ciphertext", $json.string(ct_b64)],
      ["tag", $json.string(tag_b64)],
    ]);
  } else {
    _block = toList([
      ["protected", $json.string(protected_b64)],
      ["encrypted_key", $json.string(ek_b64)],
      ["iv", $json.string(iv_b64)],
      ["ciphertext", $json.string(ct_b64)],
      ["tag", $json.string(tag_b64)],
    ]);
  }
  let base_fields = _block;
  let _block$1;
  let $1 = $dict.is_empty(per_recipient_unprotected);
  if ($1) {
    _block$1 = base_fields;
  } else {
    _block$1 = listPrepend(
      ["header", $json.object($dict.to_list(per_recipient_unprotected))],
      base_fields,
    );
  }
  let fields_with_header = _block$1;
  let _pipe = fields_with_header;
  let _pipe$1 = append_optional_jwe_fields(_pipe, shared_unprotected, aad$1);
  return $json.object(_pipe$1);
}

/**
 * Serialize an encrypted JWE to JSON General format.
 *
 * Format: `{"protected":"...","recipients":[{"encrypted_key":"..."}],"iv":"...","ciphertext":"...","tag":"..."}`
 *
 * For Direct or ECDH-ES algorithms, the encrypted_key field is omitted.
 * When AAD is present, includes the `aad` field.
 * When unprotected headers are present, includes the `unprotected` field and/or
 * the `header` field in the recipient object.
 *
 * For multiple recipients, use `gose/jose/jwe_multi`.
 */
export function serialize_json_general(jwe) {
  let protected_b64;
  let encrypted_key;
  let iv;
  let ciphertext;
  let tag;
  let aad$1;
  let shared_unprotected;
  let per_recipient_unprotected;
  if (jwe instanceof EncryptedJwe) {
    protected_b64 = jwe.protected_b64;
    encrypted_key = jwe.encrypted_key;
    iv = jwe.iv;
    ciphertext = jwe.ciphertext;
    tag = jwe.tag;
    aad$1 = jwe.aad;
    shared_unprotected = jwe.shared_unprotected;
    per_recipient_unprotected = jwe.per_recipient_unprotected;
  } else {
    throw makeError(
      "let_assert",
      FILEPATH,
      "gose/jose/jwe",
      2319,
      "serialize_json_general",
      "Pattern match failed, no pattern matched the value.",
      {
        value: jwe,
        start: 69615,
        end: 69800,
        pattern_start: 69626,
        pattern_end: 69794
      }
    )
  }
  let ek_b64 = $utils.encode_base64_url(encrypted_key);
  let iv_b64 = $utils.encode_base64_url(iv);
  let ct_b64 = $utils.encode_base64_url(ciphertext);
  let tag_b64 = $utils.encode_base64_url(tag);
  let _block;
  let $ = $bit_array.byte_size(encrypted_key);
  if ($ === 0) {
    _block = $List$Empty$const;
  } else {
    _block = toList([["encrypted_key", $json.string(ek_b64)]]);
  }
  let recipient_fields = _block;
  let _block$1;
  let $1 = $dict.is_empty(per_recipient_unprotected);
  if ($1) {
    _block$1 = recipient_fields;
  } else {
    _block$1 = listPrepend(
      ["header", $json.object($dict.to_list(per_recipient_unprotected))],
      recipient_fields,
    );
  }
  let recipient_with_header = _block$1;
  let recipient = $json.object(recipient_with_header);
  let _pipe = toList([
    ["protected", $json.string(protected_b64)],
    ["iv", $json.string(iv_b64)],
    ["ciphertext", $json.string(ct_b64)],
    ["tag", $json.string(tag_b64)],
    ["recipients", $json.preprocessed_array(toList([recipient]))],
  ]);
  let _pipe$1 = append_optional_jwe_fields(_pipe, shared_unprotected, aad$1);
  return $json.object(_pipe$1);
}

function decode_optional_base64_url(opt, name) {
  if (opt instanceof $option.Some) {
    let b64 = opt[0];
    let _pipe = $utils.decode_base64_url(b64, name);
    return $result.map(_pipe, (var0) => { return new $option.Some(var0); });
  } else {
    return new Ok($option.Option$None$const);
  }
}

function decode_base64_url_or_empty(opt, name) {
  if (opt instanceof $option.Some) {
    let b64 = opt[0];
    return $utils.decode_base64_url(b64, name);
  } else {
    return new Ok(toBitArray([]));
  }
}

function parse_json_flattened(json_str) {
  let decoder = $decode.field(
    "protected",
    $decode.string,
    (protected$) => {
      return $decode.optional_field(
        "encrypted_key",
        $option.Option$None$const,
        $decode.optional($decode.string),
        (encrypted_key) => {
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
                      return $decode.optional_field(
                        "header",
                        $option.Option$None$const,
                        $decode.optional($decode.dynamic),
                        (header_raw) => {
                          return $decode.optional_field(
                            "aad",
                            $option.Option$None$const,
                            $decode.optional($decode.string),
                            (aad_b64) => {
                              return $decode.optional_field(
                                "unprotected",
                                $option.Option$None$const,
                                $decode.optional($decode.dynamic),
                                (unprotected_raw) => {
                                  return $decode.success(
                                    [
                                      protected$,
                                      encrypted_key,
                                      iv,
                                      ciphertext,
                                      tag,
                                      header_raw,
                                      aad_b64,
                                      unprotected_raw,
                                    ],
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
    },
  );
  return $result.try$(
    (() => {
      let _pipe = $json.parse(json_str, decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("invalid JWE JSON (flattened)"),
      );
    })(),
    (_use0) => {
      let protected_b64 = _use0[0];
      let ek_opt = _use0[1];
      let iv_b64 = _use0[2];
      let ct_b64 = _use0[3];
      let tag_b64 = _use0[4];
      let header_raw = _use0[5];
      let aad_b64_opt = _use0[6];
      let unprotected_raw = _use0[7];
      return $result.try$(
        parse_protected_header(protected_b64),
        (_use0) => {
          let header = _use0.header;
          let alg_fields = _use0.alg_fields;
          return $result.try$(
            parse_unprotected_header(unprotected_raw),
            (_use0) => {
              let shared_unprotected_raw = _use0[0];
              let shared_names = _use0[1];
              return $result.try$(
                parse_unprotected_header(header_raw),
                (_use0) => {
                  let per_recipient_unprotected_raw = _use0[0];
                  let per_recipient_names = _use0[1];
                  return $result.try$(
                    validate_jwe_header_disjointness(
                      header,
                      alg_fields,
                      shared_names,
                      per_recipient_names,
                    ),
                    (_) => {
                      return $result.try$(
                        decode_base64_url_or_empty(ek_opt, "encrypted_key"),
                        (encrypted_key) => {
                          return $result.try$(
                            validate_encrypted_key_for_algorithm(
                              header.alg,
                              encrypted_key,
                            ),
                            (_) => {
                              return $result.try$(
                                $utils.decode_base64_url(iv_b64, "iv"),
                                (iv) => {
                                  return $result.try$(
                                    $utils.decode_base64_url(
                                      ct_b64,
                                      "ciphertext",
                                    ),
                                    (ciphertext) => {
                                      return $result.try$(
                                        $utils.decode_base64_url(tag_b64, "tag"),
                                        (tag) => {
                                          return $result.try$(
                                            $content_encryption.validate_iv_tag_sizes(
                                              header.enc,
                                              iv,
                                              tag,
                                            ),
                                            (_) => {
                                              return $result.try$(
                                                decode_optional_base64_url(
                                                  aad_b64_opt,
                                                  "aad",
                                                ),
                                                (user_aad) => {
                                                  return new Ok(
                                                    new EncryptedJwe(
                                                      header,
                                                      protected_b64,
                                                      encrypted_key,
                                                      iv,
                                                      ciphertext,
                                                      tag,
                                                      alg_fields,
                                                      user_aad,
                                                      $dict.new$(),
                                                      shared_unprotected_raw,
                                                      $dict.new$(),
                                                      per_recipient_unprotected_raw,
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

function parse_json_general(json_str) {
  let recipient_decoder = $decode.optional_field(
    "encrypted_key",
    $option.Option$None$const,
    $decode.optional($decode.string),
    (encrypted_key) => {
      return $decode.optional_field(
        "header",
        $option.Option$None$const,
        $decode.optional($decode.dynamic),
        (header_raw) => { return $decode.success([encrypted_key, header_raw]); },
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
                      return $decode.optional_field(
                        "aad",
                        $option.Option$None$const,
                        $decode.optional($decode.string),
                        (aad_b64) => {
                          return $decode.optional_field(
                            "unprotected",
                            $option.Option$None$const,
                            $decode.optional($decode.dynamic),
                            (unprotected_raw) => {
                              return $decode.success(
                                [
                                  protected$,
                                  recipients,
                                  iv,
                                  ciphertext,
                                  tag,
                                  aad_b64,
                                  unprotected_raw,
                                ],
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
  return $result.try$(
    (() => {
      let _pipe = $json.parse(json_str, decoder);
      return $result.replace_error(
        _pipe,
        new $gose.ParseError("invalid JWE JSON (general)"),
      );
    })(),
    (_use0) => {
      let protected_b64 = _use0[0];
      let recipients = _use0[1];
      let iv_b64 = _use0[2];
      let ct_b64 = _use0[3];
      let tag_b64 = _use0[4];
      let aad_b64_opt = _use0[5];
      let unprotected_raw = _use0[6];
      return $result.try$(
        parse_unprotected_header(unprotected_raw),
        (_use0) => {
          let shared_unprotected_raw = _use0[0];
          let shared_names = _use0[1];
          if (recipients instanceof $Empty) {
            return new Error(
              new $gose.ParseError("JWE JSON (general) has no recipients"),
            );
          } else {
            let $ = recipients.tail;
            if ($ instanceof $Empty) {
              let ek_opt = recipients.head[0];
              let header_raw = recipients.head[1];
              return $result.try$(
                parse_protected_header(protected_b64),
                (_use0) => {
                  let header = _use0.header;
                  let alg_fields = _use0.alg_fields;
                  return $result.try$(
                    parse_unprotected_header(header_raw),
                    (_use0) => {
                      let per_recipient_unprotected_raw = _use0[0];
                      let per_recipient_names = _use0[1];
                      return $result.try$(
                        validate_jwe_header_disjointness(
                          header,
                          alg_fields,
                          shared_names,
                          per_recipient_names,
                        ),
                        (_) => {
                          return $result.try$(
                            decode_base64_url_or_empty(ek_opt, "encrypted_key"),
                            (encrypted_key) => {
                              return $result.try$(
                                validate_encrypted_key_for_algorithm(
                                  header.alg,
                                  encrypted_key,
                                ),
                                (_) => {
                                  return $result.try$(
                                    $utils.decode_base64_url(iv_b64, "iv"),
                                    (iv) => {
                                      return $result.try$(
                                        $utils.decode_base64_url(
                                          ct_b64,
                                          "ciphertext",
                                        ),
                                        (ciphertext) => {
                                          return $result.try$(
                                            $utils.decode_base64_url(
                                              tag_b64,
                                              "tag",
                                            ),
                                            (tag) => {
                                              return $result.try$(
                                                $content_encryption.validate_iv_tag_sizes(
                                                  header.enc,
                                                  iv,
                                                  tag,
                                                ),
                                                (_) => {
                                                  return $result.try$(
                                                    decode_optional_base64_url(
                                                      aad_b64_opt,
                                                      "aad",
                                                    ),
                                                    (aad) => {
                                                      return new Ok(
                                                        new EncryptedJwe(
                                                          header,
                                                          protected_b64,
                                                          encrypted_key,
                                                          iv,
                                                          ciphertext,
                                                          tag,
                                                          alg_fields,
                                                          aad,
                                                          $dict.new$(),
                                                          shared_unprotected_raw,
                                                          $dict.new$(),
                                                          per_recipient_unprotected_raw,
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
                        },
                      );
                    },
                  );
                },
              );
            } else {
              return new Error(
                new $gose.ParseError(
                  "JWE JSON (general) has multiple recipients (not supported)",
                ),
              );
            }
          }
        },
      );
    },
  );
}

/**
 * Parse a JWE from JSON format (supports both General and Flattened).
 */
export function parse_json(json_str) {
  let format_detector = $decode.field(
    "recipients",
    $decode.list($decode.dynamic),
    (_) => { return $decode.success(true); },
  );
  let _block;
  let _pipe = $json.parse(json_str, format_detector);
  _block = $result.is_ok(_pipe);
  let is_general_format = _block;
  if (is_general_format) {
    return parse_json_general(json_str);
  } else {
    return parse_json_flattened(json_str);
  }
}

function apply_optional(jwe, value, setter) {
  if (value instanceof $option.Some) {
    let v = value[0];
    return setter(jwe, v);
  } else {
    return jwe;
  }
}

function apply_headers(jwe, kid, typ, cty) {
  let _pipe = jwe;
  let _pipe$1 = apply_optional(_pipe, kid, with_kid);
  let _pipe$2 = apply_optional(_pipe$1, typ, with_typ);
  return apply_optional(_pipe$2, cty, with_cty);
}

function encrypt_and_serialize(unencrypted, alg, key, plaintext) {
  return $result.try$(
    encrypt(unencrypted, key, plaintext),
    (encrypted) => {
      return $result.try$(
        serialize_compact(encrypted),
        (token) => { return new Ok([token, alg]); },
      );
    },
  );
}

export function encrypt_to_compact(alg, enc, plaintext, key, kid, typ, cty) {
  if (alg instanceof $gose.Direct) {
    return encrypt_and_serialize(
      apply_headers(new_direct(enc), kid, typ, cty),
      alg,
      key,
      plaintext,
    );
  } else if (alg instanceof $gose.AesKeyWrap) {
    let $ = alg[0];
    if ($ instanceof $gose.AesKw) {
      let size = alg[1];
      return encrypt_and_serialize(
        apply_headers(new_aes_kw(size, enc), kid, typ, cty),
        alg,
        key,
        plaintext,
      );
    } else {
      let size = alg[1];
      return encrypt_and_serialize(
        apply_headers(new_aes_gcm_kw(size, enc), kid, typ, cty),
        alg,
        key,
        plaintext,
      );
    }
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    let variant = alg[0];
    return encrypt_and_serialize(
      apply_headers(new_chacha20_kw(variant, enc), kid, typ, cty),
      alg,
      key,
      plaintext,
    );
  } else if (alg instanceof $gose.RsaEncryption) {
    let rsa_alg = alg[0];
    return encrypt_and_serialize(
      apply_headers(new_rsa(rsa_alg, enc), kid, typ, cty),
      alg,
      key,
      plaintext,
    );
  } else if (alg instanceof $gose.EcdhEs) {
    let ecdh_alg = alg[0];
    return encrypt_and_serialize(
      apply_headers(new_ecdh_es(ecdh_alg, enc), kid, typ, cty),
      alg,
      key,
      plaintext,
    );
  } else {
    return new Error(
      new $gose.InvalidState("PBES2 algorithms require a password, not a key"),
    );
  }
}
