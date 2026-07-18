import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $pair from "../../../gleam_stdlib/gleam/pair.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $gose from "../../gose.mjs";
import * as $jwe from "../../gose/jose/jwe.mjs";
import * as $jwk from "../../gose/jose/jwk.mjs";

/**
 * Import a JWK from encrypted JSON using a decryptor with algorithm pinning.
 *
 * Works for all algorithms. Create a decryptor with `jwe.key_decryptor`
 * for key-based algorithms or `jwe.password_decryptor` for PBES2.
 *
 * ## Example
 *
 * ```gleam
 * let decryptor =
 *   jwe.password_decryptor(
 *     gose.Pbes2Sha256Aes128Kw,
 *     gose.AesGcm(gose.Aes256),
 *     "my-password",
 *   )
 * let assert Ok(key) = encrypted_key.decrypt(decryptor, encrypted_token)
 * ```
 */
export function decrypt(decryptor, encrypted) {
  return $result.try$(
    $jwe.parse_compact(encrypted),
    (parsed) => {
      return $result.try$(
        $jwe.decrypt(decryptor, parsed),
        (plaintext) => { return $jwk.from_json_bits(plaintext); },
      );
    },
  );
}

function jwk_to_plaintext(key) {
  let _pipe = $jwk.to_json(key);
  let _pipe$1 = $json.to_string(_pipe);
  return $bit_array.from_string(_pipe$1);
}

/**
 * Export a JWK as encrypted JSON using a key-based algorithm.
 *
 * Supports all key-based JWE algorithms: direct symmetric (dir), AES Key Wrap,
 * AES-GCM Key Wrap, RSA-OAEP, and ECDH-ES. PBES2 password-based algorithms
 * return an error. Use `encrypt_with_password` for those.
 *
 * The encryption key type must match the algorithm:
 * - `Direct`: octet key matching the content encryption key size
 * - `AesKeyWrap(AesKw, _)`: octet key (16, 24, or 32 bytes)
 * - `AesKeyWrap(AesGcmKw, _)`: octet key (16, 24, or 32 bytes)
 * - `ChaCha20KeyWrap(_)`: octet key (32 bytes)
 * - `RsaEncryption(_)`: RSA key
 * - `EcdhEs(_)`: EC or XDH key
 *
 * If the encryption key has a `kid`, it is included in the JWE header.
 */
export function encrypt_with_key(key, alg, enc, encryption_key) {
  let plaintext = jwk_to_plaintext(key);
  let kid = $option.from_result($gose.kid(encryption_key));
  let _pipe = $jwe.encrypt_to_compact(
    alg,
    enc,
    plaintext,
    encryption_key,
    kid,
    new $option.None(),
    new $option.Some("jwk+json"),
  );
  return $result.map(_pipe, $pair.first);
}

/**
 * Export a JWK as encrypted JSON using PBES2 password-based encryption.
 *
 * This is the most common method for protecting stored keys with a password.
 * The JWK is serialized to JSON, then encrypted using the specified PBES2
 * algorithm and content encryption algorithm.
 */
export function encrypt_with_password(key, alg, enc, password) {
  let plaintext = jwk_to_plaintext(key);
  let _block;
  let _pipe = $jwe.new_pbes2(alg, enc);
  _block = $jwe.with_cty(_pipe, "jwk+json");
  let encryptor = _block;
  let _pipe$1 = $jwe.encrypt_with_password(encryptor, password, plaintext);
  return $result.try$(_pipe$1, $jwe.serialize_compact);
}
