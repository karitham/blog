import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $timestamp from "../../../gleam_time/gleam/time/timestamp.mjs";
import { Ok, Error, toList, CustomType as $CustomType, isEqual } from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $jwe from "../../gose/jose/jwe.mjs";
import * as $jwt from "../../gose/jose/jwt.mjs";

class EncryptedJwt extends $CustomType {
  constructor(alg, enc, kid, claims, claims_json, token) {
    super();
    this.alg = alg;
    this.enc = enc;
    this.kid = kid;
    this.claims = claims;
    this.claims_json = claims_json;
    this.token = token;
  }
}

class KeyDecryptor extends $CustomType {
  constructor(alg, enc, keys, options) {
    super();
    this.alg = alg;
    this.enc = enc;
    this.keys = keys;
    this.options = options;
  }
}

class PasswordDecryptor extends $CustomType {
  constructor(alg, enc, password, options) {
    super();
    this.alg = alg;
    this.enc = enc;
    this.password = password;
    this.options = options;
  }
}

export class PeekHeaders extends $CustomType {
  constructor(alg, enc, kid) {
    super();
    this.alg = alg;
    this.enc = enc;
    this.kid = kid;
  }
}
export const PeekHeaders$PeekHeaders = (alg, enc, kid) =>
  new PeekHeaders(alg, enc, kid);
export const PeekHeaders$isPeekHeaders = (value) =>
  value instanceof PeekHeaders;
export const PeekHeaders$PeekHeaders$alg = (value) => value.alg;
export const PeekHeaders$PeekHeaders$0 = (value) => value.alg;
export const PeekHeaders$PeekHeaders$enc = (value) => value.enc;
export const PeekHeaders$PeekHeaders$1 = (value) => value.enc;
export const PeekHeaders$PeekHeaders$kid = (value) => value.kid;
export const PeekHeaders$PeekHeaders$2 = (value) => value.kid;

function validate_decryption_keys(alg, keys) {
  return $key_helpers.require_non_empty_keys(
    keys,
    () => {
      return $list.try_each(
        keys,
        (_capture) => {
          return $key_helpers.validate_key_for_jwe_decryption(alg, _capture);
        },
      );
    },
  );
}

/**
 * Create a key-based decryptor for symmetric (dir, AES-KW, AES-GCM-KW) or
 * asymmetric (RSA-OAEP, ECDH-ES) algorithms.
 *
 * The decryptor pins the expected algorithms. Tokens with different
 * algorithms will be rejected.
 */
export function key_decryptor(alg, enc, keys, options) {
  let _pipe = validate_decryption_keys(alg, keys);
  let _pipe$1 = $result.replace(
    _pipe,
    new KeyDecryptor(alg, enc, keys, options),
  );
  return $result.map_error(
    _pipe$1,
    (var0) => { return new $jwt.JoseError(var0); },
  );
}

/**
 * Create a password-based decryptor for PBES2 algorithms.
 *
 * The decryptor pins the expected algorithms. Tokens with different
 * algorithms will be rejected.
 */
export function password_decryptor(alg, enc, password, options) {
  return new PasswordDecryptor(alg, enc, password, options);
}

function claims_to_plaintext(claims) {
  let _pipe = $jwt.claims_to_json_string(claims);
  return $bit_array.from_string(_pipe);
}

function do_encrypt_with_key(claims, alg, enc, key, kid) {
  let claims_json = claims_to_plaintext(claims);
  return $result.try$(
    $key_helpers.validate_key_for_jwe_encryption(alg, key),
    (_) => {
      let _pipe = $jwe.encrypt_to_compact(
        alg,
        enc,
        claims_json,
        key,
        kid,
        new $option.Some("JWT"),
        new $option.None(),
      );
      return $result.map(
        _pipe,
        (pair) => {
          let token = pair[0];
          let jwe_alg = pair[1];
          return new EncryptedJwt(jwe_alg, enc, kid, claims, claims_json, token);
        },
      );
    },
  );
}

/**
 * Encrypt claims using a key-based algorithm.
 *
 * Supports all key-based JWE algorithms: direct symmetric (dir), AES Key Wrap,
 * AES-GCM Key Wrap, RSA-OAEP, and ECDH-ES. PBES2 password-based algorithms
 * return an error. Use `encrypt_with_password` for those.
 *
 * Sets `typ: "JWT"` in the header. If the encryption key has a `kid`, it is
 * included in the JWE header.
 */
export function encrypt_with_key(claims, alg, enc, key) {
  let kid$1 = $option.from_result($gose.kid(key));
  let _pipe = do_encrypt_with_key(claims, alg, enc, key, kid$1);
  return $result.map_error(
    _pipe,
    (var0) => { return new $jwt.JoseError(var0); },
  );
}

function do_encrypt_with_password(claims, alg, enc, password, kid) {
  let claims_json = claims_to_plaintext(claims);
  let _block;
  let _pipe = $jwe.new_pbes2(alg, enc);
  _block = $jwe.with_typ(_pipe, "JWT");
  let unencrypted = _block;
  let _block$1;
  if (kid instanceof $option.Some) {
    let k = kid[0];
    _block$1 = $jwe.with_kid(unencrypted, k);
  } else {
    _block$1 = unencrypted;
  }
  let unencrypted$1 = _block$1;
  return $result.try$(
    $jwe.encrypt_with_password(unencrypted$1, password, claims_json),
    (encrypted) => {
      let _pipe$1 = $jwe.serialize_compact(encrypted);
      return $result.map(
        _pipe$1,
        (token) => {
          return new EncryptedJwt(
            $jwe.alg(encrypted),
            enc,
            kid,
            claims,
            claims_json,
            token,
          );
        },
      );
    },
  );
}

/**
 * Encrypt claims using PBES2 password-based encryption.
 *
 * Sets `typ: "JWT"` in the header.
 */
export function encrypt_with_password(claims, alg, enc, password, kid) {
  let _pipe = do_encrypt_with_password(claims, alg, enc, password, kid);
  return $result.map_error(
    _pipe,
    (var0) => { return new $jwt.JoseError(var0); },
  );
}

/**
 * Return the compact serialization of an encrypted JWT.
 */
export function serialize(jwt) {
  return jwt.token;
}

function parse_jwe(token) {
  let _pipe = $jwe.parse_compact(token);
  return $result.map_error(_pipe, $jwt.gose_error_to_malformed_token_error);
}

/**
 * Peek at the header fields from a token without decrypting.
 */
export function peek_headers(token) {
  let _pipe = parse_jwe(token);
  return $result.map(
    _pipe,
    (parsed_jwe) => {
      return new PeekHeaders(
        $jwe.alg(parsed_jwe),
        $jwe.enc(parsed_jwe),
        $option.from_result($jwe.kid(parsed_jwe)),
      );
    },
  );
}

function parse_plaintext_claims(plaintext) {
  return $jwt.parse_claims_bits(plaintext);
}

function gose_error_to_decryption_failed(err) {
  return new $jwt.DecryptionFailed($gose.error_message(err));
}

function build_jwe_decryptor(decryptor, decryption_keys) {
  if (decryptor instanceof KeyDecryptor) {
    let alg$1 = decryptor.alg;
    let enc$1 = decryptor.enc;
    let _pipe = $jwe.key_decryptor(alg$1, enc$1, decryption_keys);
    return $result.map_error(
      _pipe,
      (var0) => { return new $jwt.JoseError(var0); },
    );
  } else {
    let alg$1 = decryptor.alg;
    let enc$1 = decryptor.enc;
    let password = decryptor.password;
    return new Ok($jwe.password_decryptor(alg$1, enc$1, password));
  }
}

function select_decryption_keys(decryptor, token_kid, kid_policy) {
  if (decryptor instanceof KeyDecryptor) {
    let keys = decryptor.keys;
    return $jwt.select_keys_by_policy(keys, token_kid, kid_policy);
  } else {
    return new Ok(toList([]));
  }
}

function decryptor_options(decryptor) {
  return decryptor.options;
}

function require_matching_algorithms(decryptor, actual_alg, actual_enc) {
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
  let $1 = (!isEqual(expected_alg, actual_alg)) || (!isEqual(
    expected_enc,
    actual_enc
  ));
  if ($1) {
    return new Error(
      new $jwt.JweAlgorithmMismatch(
        expected_alg,
        expected_enc,
        actual_alg,
        actual_enc,
      ),
    );
  } else {
    return new Ok(undefined);
  }
}

function decrypt_token(decryptor, token) {
  return $result.try$(
    (() => {
      let _pipe = $jwe.parse_compact(token);
      return $result.map_error(_pipe, $jwt.gose_error_to_malformed_token_error);
    })(),
    (parsed_jwe) => {
      let actual_alg = $jwe.alg(parsed_jwe);
      let actual_enc = $jwe.enc(parsed_jwe);
      let token_kid = $option.from_result($jwe.kid(parsed_jwe));
      return $result.try$(
        require_matching_algorithms(decryptor, actual_alg, actual_enc),
        (_) => {
          let options = decryptor_options(decryptor);
          return $result.try$(
            select_decryption_keys(decryptor, token_kid, options.kid_policy),
            (decryption_keys) => {
              return $result.try$(
                build_jwe_decryptor(decryptor, decryption_keys),
                (jwe_decryptor) => {
                  return $result.try$(
                    (() => {
                      let _pipe = $jwe.decrypt(jwe_decryptor, parsed_jwe);
                      return $result.map_error(
                        _pipe,
                        gose_error_to_decryption_failed,
                      );
                    })(),
                    (plaintext) => {
                      return new Ok(
                        [plaintext, actual_alg, actual_enc, token_kid],
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
 * Decrypt an encrypted JWT, skipping all claim validation.
 *
 * **Warning:** This skips expiration, not-before, issuer, and audience checks.
 * Use only when you have a legitimate reason to bypass validation, such as
 * inspecting claims before deciding on validation policy.
 *
 * Still enforces algorithm pinning for security. **Note:** `kid_policy` only
 * applies to key-based decryptors, not password-based decryptors.
 */
export function dangerously_decrypt_and_skip_validation(decryptor, token) {
  return $result.try$(
    decrypt_token(decryptor, token),
    (_use0) => {
      let plaintext = _use0[0];
      let actual_alg = _use0[1];
      let actual_enc = _use0[2];
      let kid$1 = _use0[3];
      let _pipe = parse_plaintext_claims(plaintext);
      return $result.map(
        _pipe,
        (claims) => {
          return new EncryptedJwt(
            actual_alg,
            actual_enc,
            kid$1,
            claims,
            plaintext,
            token,
          );
        },
      );
    },
  );
}

/**
 * Decrypt an encrypted JWT and validate its claims using a Decryptor.
 *
 * Checks:
 * 1. Token's `alg` and `enc` headers match the decryptor's expected algorithms
 * 2. Decryption succeeds with one of the decryptor's keys
 * 3. Claims pass validation (exp, nbf, iss, aud per options)
 *
 * When multiple keys are configured:
 * - Keys with matching `kid` are tried first (if token has `kid` header)
 * - `kid_policy` controls kid header enforcement (see `KidPolicy` type)
 * - With `NoKidRequirement`, all keys are tried with matching keys prioritized
 */
export function decrypt_and_validate(decryptor, token, now) {
  return $result.try$(
    decrypt_token(decryptor, token),
    (_use0) => {
      let plaintext = _use0[0];
      let actual_alg = _use0[1];
      let actual_enc = _use0[2];
      let kid$1 = _use0[3];
      return $result.try$(
        parse_plaintext_claims(plaintext),
        (claims) => {
          let options = decryptor_options(decryptor);
          let _pipe = $jwt.validate_claims(claims, now, options);
          return $result.replace(
            _pipe,
            new EncryptedJwt(
              actual_alg,
              actual_enc,
              kid$1,
              claims,
              plaintext,
              token,
            ),
          );
        },
      );
    },
  );
}

/**
 * Decode an encrypted JWT's claims using a custom decoder.
 *
 * This allows extracting claims directly into your own types using
 * `gleam/dynamic/decode`. The decoder receives the raw claims JSON.
 */
export function decode(jwt, decoder) {
  let _pipe = $json.parse_bits(jwt.claims_json, decoder);
  return $result.replace_error(
    _pipe,
    new $jwt.ClaimDecodingFailed("failed to decode claims"),
  );
}

/**
 * Get the key encryption algorithm (`alg`) from a decrypted and validated encrypted JWT.
 */
export function alg(jwt) {
  return jwt.alg;
}

/**
 * Get the content encryption algorithm (`enc`) from a decrypted and validated encrypted JWT.
 */
export function enc(jwt) {
  return jwt.enc;
}

/**
 * Get the key ID (kid) from a decrypted and validated encrypted JWT header.
 *
 * **Security Warning:** The `kid` value comes from the token and is untrusted
 * input. If you use it to look up keys (from a database, filesystem, or key
 * store), you must sanitize it first to prevent injection attacks.
 */
export function kid(jwt) {
  return $option.to_result(jwt.kid, undefined);
}
