import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import { Ok, Error, CustomType as $CustomType } from "../gleam.mjs";
import * as $hash from "../kryptos/hash.mjs";
import * as $rsa_crt from "../kryptos/internal/rsa_crt.mjs";
import {
  rsaGenerateKeyPair as do_generate_key_pair,
  rsaSign as sign,
  rsaVerify as verify,
  rsaEncrypt as encrypt,
  rsaDecrypt as decrypt,
  rsaImportPrivateKeyPem as from_pem,
  rsaImportPrivateKeyDer as from_der,
  rsaExportPrivateKeyPem as do_to_pem,
  rsaExportPrivateKeyDer as to_der,
  rsaImportPublicKeyPem as public_key_from_pem,
  rsaImportPublicKeyDer as public_key_from_der,
  rsaExportPublicKeyPem as do_public_key_to_pem,
  rsaExportPublicKeyDer as public_key_to_der,
  rsaPublicKeyFromPrivate as public_key_from_private_key,
  rsaPrivateKeyModulusBits as modulus_bits,
  rsaPublicKeyModulusBits as public_key_modulus_bits,
  rsaPrivateKeyPublicExponent as public_exponent,
  rsaPublicKeyPublicExponent as public_key_exponent,
  rsaPrivateKeyModulus as modulus,
  rsaPublicKeyModulus as public_key_modulus,
  rsaPrivateKeyPublicExponentBytes as public_exponent_bytes,
  rsaPublicKeyExponentBytes as public_key_exponent_bytes,
  rsaPrivateKeyPrivateExponentBytes as private_exponent_bytes,
  rsaPrivateKeyPrime1 as prime1,
  rsaPrivateKeyPrime2 as prime2,
  rsaPrivateKeyExponent1 as exponent1,
  rsaPrivateKeyExponent2 as exponent2,
  rsaPrivateKeyCoefficient as coefficient,
  rsaPublicKeyFromComponents as public_key_from_components,
  rsaPrivateKeyFromFullComponents as from_full_components,
} from "../kryptos_ffi.mjs";

export {
  coefficient,
  decrypt,
  encrypt,
  exponent1,
  exponent2,
  from_der,
  from_full_components,
  from_pem,
  modulus,
  modulus_bits,
  prime1,
  prime2,
  private_exponent_bytes,
  public_exponent,
  public_exponent_bytes,
  public_key_exponent,
  public_key_exponent_bytes,
  public_key_from_components,
  public_key_from_der,
  public_key_from_pem,
  public_key_from_private_key,
  public_key_modulus,
  public_key_modulus_bits,
  public_key_to_der,
  sign,
  to_der,
  verify,
};

/**
 * PKCS#8 format (PrivateKeyInfo) - works with all key types.
 */
export class Pkcs8 extends $CustomType {}
export const PrivateKeyFormat$Pkcs8$const = new Pkcs8();
export const PrivateKeyFormat$Pkcs8 = () => PrivateKeyFormat$Pkcs8$const;
export const PrivateKeyFormat$isPkcs8 = (value) => value instanceof Pkcs8;

/**
 * PKCS#1 format (RSAPrivateKey) - RSA-specific.
 */
export class Pkcs1 extends $CustomType {}
export const PrivateKeyFormat$Pkcs1$const = new Pkcs1();
export const PrivateKeyFormat$Pkcs1 = () => PrivateKeyFormat$Pkcs1$const;
export const PrivateKeyFormat$isPkcs1 = (value) => value instanceof Pkcs1;

/**
 * SPKI format (SubjectPublicKeyInfo) - works with all key types.
 */
export class Spki extends $CustomType {}
export const PublicKeyFormat$Spki$const = new Spki();
export const PublicKeyFormat$Spki = () => PublicKeyFormat$Spki$const;
export const PublicKeyFormat$isSpki = (value) => value instanceof Spki;

/**
 * PKCS#1 format (RSAPublicKey) - RSA-specific.
 */
export class RsaPublicKey extends $CustomType {}
export const PublicKeyFormat$RsaPublicKey$const = new RsaPublicKey();
export const PublicKeyFormat$RsaPublicKey = () =>
  PublicKeyFormat$RsaPublicKey$const;
export const PublicKeyFormat$isRsaPublicKey = (value) =>
  value instanceof RsaPublicKey;

/**
 * Salt length equals hash output length (recommended).
 */
export class SaltLengthHashLen extends $CustomType {}
export const PssSaltLength$SaltLengthHashLen$const = new SaltLengthHashLen();
export const PssSaltLength$SaltLengthHashLen = () =>
  PssSaltLength$SaltLengthHashLen$const;
export const PssSaltLength$isSaltLengthHashLen = (value) =>
  value instanceof SaltLengthHashLen;

/**
 * Maximum salt length for the key and hash combination.
 */
export class SaltLengthMax extends $CustomType {}
export const PssSaltLength$SaltLengthMax$const = new SaltLengthMax();
export const PssSaltLength$SaltLengthMax = () =>
  PssSaltLength$SaltLengthMax$const;
export const PssSaltLength$isSaltLengthMax = (value) =>
  value instanceof SaltLengthMax;

/**
 * Explicit salt length in bytes.
 */
export class SaltLengthExplicit extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const PssSaltLength$SaltLengthExplicit = ($0) =>
  new SaltLengthExplicit($0);
export const PssSaltLength$isSaltLengthExplicit = (value) =>
  value instanceof SaltLengthExplicit;
export const PssSaltLength$SaltLengthExplicit$0 = (value) => value[0];

/**
 * PKCS#1 v1.5 signature padding.
 */
export class Pkcs1v15 extends $CustomType {}
export const SignPadding$Pkcs1v15$const = new Pkcs1v15();
export const SignPadding$Pkcs1v15 = () => SignPadding$Pkcs1v15$const;
export const SignPadding$isPkcs1v15 = (value) => value instanceof Pkcs1v15;

/**
 * RSA-PSS (Probabilistic Signature Scheme) padding.
 */
export class Pss extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SignPadding$Pss = ($0) => new Pss($0);
export const SignPadding$isPss = (value) => value instanceof Pss;
export const SignPadding$Pss$0 = (value) => value[0];

/**
 * PKCS#1 v1.5 encryption padding.
 *
 * **Warning**: Vulnerable to padding oracle attacks. Prefer OAEP for new applications.
 *
 * **JavaScript target**: Decryption may fail on Node.js 20.x due to CVE-2023-46809
 * which disables PKCS#1 v1.5 decryption to prevent the Marvin timing attack. Use
 * Node.js 22+ or OAEP padding instead.
 */
export class EncryptPkcs1v15 extends $CustomType {}
export const EncryptPadding$EncryptPkcs1v15$const = new EncryptPkcs1v15();
export const EncryptPadding$EncryptPkcs1v15 = () =>
  EncryptPadding$EncryptPkcs1v15$const;
export const EncryptPadding$isEncryptPkcs1v15 = (value) =>
  value instanceof EncryptPkcs1v15;

/**
 * RSA-OAEP (Optimal Asymmetric Encryption Padding).
 *
 * The hash algorithm is used for both OAEP and MGF1.
 * The label is optional associated data (usually empty).
 */
export class Oaep extends $CustomType {
  constructor(hash, label) {
    super();
    this.hash = hash;
    this.label = label;
  }
}
export const EncryptPadding$Oaep = (hash, label) => new Oaep(hash, label);
export const EncryptPadding$isOaep = (value) => value instanceof Oaep;
export const EncryptPadding$Oaep$hash = (value) => value.hash;
export const EncryptPadding$Oaep$0 = (value) => value.hash;
export const EncryptPadding$Oaep$label = (value) => value.label;
export const EncryptPadding$Oaep$1 = (value) => value.label;

/**
 * The minimum allowed RSA key size in bits.
 */
export const min_key_size = 1024;

/**
 * Generates an RSA key pair with the specified key size.
 *
 * The key size must be >= 1024 bits.
 *
 * ## Example
 *
 * ```gleam
 * let assert Ok(#(private_key, public_key)) = rsa.generate_key_pair(2048)
 * ```
 */
export function generate_key_pair(bits) {
  let $ = bits >= min_key_size;
  if ($) {
    return new Ok(do_generate_key_pair(bits));
  } else {
    return new Error(undefined);
  }
}

/**
 * Exports an RSA private key to PEM format.
 */
export function to_pem(key, format) {
  let _pipe = do_to_pem(key, format);
  return $result.map(_pipe, (pem) => { return $string.trim_end(pem) + "\n"; });
}

/**
 * Exports an RSA public key to PEM format.
 */
export function public_key_to_pem(key, format) {
  let _pipe = do_public_key_to_pem(key, format);
  return $result.map(_pipe, (pem) => { return $string.trim_end(pem) + "\n"; });
}

/**
 * Constructs an RSA private key from its components.
 *
 * Creates a private key from the minimal set of components (n, e, d).
 * CRT parameters are computed automatically using Miller's algorithm.
 *
 * Note: This function is not constant-time. The CRT parameter derivation
 * involves operations that may leak timing information. This is acceptable
 * for key import since the caller already possesses the secret material,
 * but avoid calling this in timing-sensitive contexts.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/rsa
 *
 * let assert Ok(#(private_key, _public_key)) = rsa.generate_key_pair(2048)
 * let n = rsa.modulus(private_key)
 * let e = rsa.public_exponent_bytes(private_key)
 * let d = rsa.private_exponent_bytes(private_key)
 * let assert Ok(#(reconstructed, _pub)) = rsa.from_components(n, e, d)
 * ```
 */
export function from_components(n, e, d) {
  return $result.try$(
    $rsa_crt.compute_crt_params(n, e, d),
    (_use0) => {
      let p = _use0[0];
      let q = _use0[1];
      let dp = _use0[2];
      let dq = _use0[3];
      let qi = _use0[4];
      return from_full_components(n, e, d, p, q, dp, dq, qi);
    },
  );
}
