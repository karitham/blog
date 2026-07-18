import * as $bit_array from "../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../gleam_stdlib/gleam/bool.mjs";
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import * as $result from "../gleam_stdlib/gleam/result.mjs";
import * as $crypto from "../kryptos/kryptos/crypto.mjs";
import * as $ec from "../kryptos/kryptos/ec.mjs";
import * as $eddsa from "../kryptos/kryptos/eddsa.mjs";
import * as $rsa from "../kryptos/kryptos/rsa.mjs";
import * as $xdh from "../kryptos/kryptos/xdh.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  CustomType as $CustomType,
  isEqual,
  toBitArray,
  bitArraySlice,
} from "./gleam.mjs";

/**
 * Parsing failed: invalid base64, malformed JSON, unexpected structure, etc.
 * The `String` provides a human-readable description of what went wrong.
 */
export class ParseError extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const GoseError$ParseError = ($0) => new ParseError($0);
export const GoseError$isParseError = (value) => value instanceof ParseError;
export const GoseError$ParseError$0 = (value) => value[0];

/**
 * A cryptographic operation failed: signature verification, decryption,
 * key derivation, etc. The `String` describes the failure.
 */
export class CryptoError extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const GoseError$CryptoError = ($0) => new CryptoError($0);
export const GoseError$isCryptoError = (value) => value instanceof CryptoError;
export const GoseError$CryptoError$0 = (value) => value[0];

/**
 * An operation was attempted in an invalid state: wrong key type for the
 * chosen algorithm, missing required header field, etc. The `String`
 * explains which invariant was violated.
 */
export class InvalidState extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const GoseError$InvalidState = ($0) => new InvalidState($0);
export const GoseError$isInvalidState = (value) =>
  value instanceof InvalidState;
export const GoseError$InvalidState$0 = (value) => value[0];

/**
 * Signature or MAC verification failed. Intentionally carries no detail
 * to avoid leaking information that could enable oracle attacks.
 */
export class VerificationFailed extends $CustomType {}
export const GoseError$VerificationFailed = () => new VerificationFailed();
export const GoseError$isVerificationFailed = (value) =>
  value instanceof VerificationFailed;

/**
 * Key is used for signature operations
 */
export class Signing extends $CustomType {}
export const KeyUse$Signing = () => new Signing();
export const KeyUse$isSigning = (value) => value instanceof Signing;

/**
 * Key is used for encryption operations
 */
export class Encrypting extends $CustomType {}
export const KeyUse$Encrypting = () => new Encrypting();
export const KeyUse$isEncrypting = (value) => value instanceof Encrypting;

/**
 * Compute digital signature or MAC
 */
export class Sign extends $CustomType {}
export const KeyOp$Sign = () => new Sign();
export const KeyOp$isSign = (value) => value instanceof Sign;

/**
 * Verify digital signature or MAC
 */
export class Verify extends $CustomType {}
export const KeyOp$Verify = () => new Verify();
export const KeyOp$isVerify = (value) => value instanceof Verify;

/**
 * Encrypt content
 */
export class Encrypt extends $CustomType {}
export const KeyOp$Encrypt = () => new Encrypt();
export const KeyOp$isEncrypt = (value) => value instanceof Encrypt;

/**
 * Decrypt content and validate decryption
 */
export class Decrypt extends $CustomType {}
export const KeyOp$Decrypt = () => new Decrypt();
export const KeyOp$isDecrypt = (value) => value instanceof Decrypt;

/**
 * Encrypt key
 */
export class WrapKey extends $CustomType {}
export const KeyOp$WrapKey = () => new WrapKey();
export const KeyOp$isWrapKey = (value) => value instanceof WrapKey;

/**
 * Decrypt key and validate decryption
 */
export class UnwrapKey extends $CustomType {}
export const KeyOp$UnwrapKey = () => new UnwrapKey();
export const KeyOp$isUnwrapKey = (value) => value instanceof UnwrapKey;

/**
 * Derive key
 */
export class DeriveKey extends $CustomType {}
export const KeyOp$DeriveKey = () => new DeriveKey();
export const KeyOp$isDeriveKey = (value) => value instanceof DeriveKey;

/**
 * Derive bits not to be used as a key
 */
export class DeriveBits extends $CustomType {}
export const KeyOp$DeriveBits = () => new DeriveBits();
export const KeyOp$isDeriveBits = (value) => value instanceof DeriveBits;

/**
 * 128-bit AES key
 */
export class Aes128 extends $CustomType {}
export const AesKeySize$Aes128 = () => new Aes128();
export const AesKeySize$isAes128 = (value) => value instanceof Aes128;

/**
 * 192-bit AES key
 */
export class Aes192 extends $CustomType {}
export const AesKeySize$Aes192 = () => new Aes192();
export const AesKeySize$isAes192 = (value) => value instanceof Aes192;

/**
 * 256-bit AES key
 */
export class Aes256 extends $CustomType {}
export const AesKeySize$Aes256 = () => new Aes256();
export const AesKeySize$isAes256 = (value) => value instanceof Aes256;

/**
 * AES Key Wrap (RFC 3394)
 */
export class AesKw extends $CustomType {}
export const AesKwMode$AesKw = () => new AesKw();
export const AesKwMode$isAesKw = (value) => value instanceof AesKw;

/**
 * AES-GCM Key Wrap
 */
export class AesGcmKw extends $CustomType {}
export const AesKwMode$AesGcmKw = () => new AesGcmKw();
export const AesKwMode$isAesGcmKw = (value) => value instanceof AesGcmKw;

/**
 * ChaCha20-Poly1305 Key Wrap (12-byte nonce)
 */
export class C20PKw extends $CustomType {}
export const ChaCha20Kw$C20PKw = () => new C20PKw();
export const ChaCha20Kw$isC20PKw = (value) => value instanceof C20PKw;

/**
 * XChaCha20-Poly1305 Key Wrap (24-byte nonce)
 */
export class XC20PKw extends $CustomType {}
export const ChaCha20Kw$XC20PKw = () => new XC20PKw();
export const ChaCha20Kw$isXC20PKw = (value) => value instanceof XC20PKw;

/**
 * HMAC using SHA-256
 */
export class HmacSha256 extends $CustomType {}
export const HmacAlg$HmacSha256 = () => new HmacSha256();
export const HmacAlg$isHmacSha256 = (value) => value instanceof HmacSha256;

/**
 * HMAC using SHA-384
 */
export class HmacSha384 extends $CustomType {}
export const HmacAlg$HmacSha384 = () => new HmacSha384();
export const HmacAlg$isHmacSha384 = (value) => value instanceof HmacSha384;

/**
 * HMAC using SHA-512
 */
export class HmacSha512 extends $CustomType {}
export const HmacAlg$HmacSha512 = () => new HmacSha512();
export const HmacAlg$isHmacSha512 = (value) => value instanceof HmacSha512;

/**
 * RSA PKCSv1.5 using SHA-256
 */
export class RsaPkcs1Sha256 extends $CustomType {}
export const RsaPkcs1Alg$RsaPkcs1Sha256 = () => new RsaPkcs1Sha256();
export const RsaPkcs1Alg$isRsaPkcs1Sha256 = (value) =>
  value instanceof RsaPkcs1Sha256;

/**
 * RSA PKCSv1.5 using SHA-384
 */
export class RsaPkcs1Sha384 extends $CustomType {}
export const RsaPkcs1Alg$RsaPkcs1Sha384 = () => new RsaPkcs1Sha384();
export const RsaPkcs1Alg$isRsaPkcs1Sha384 = (value) =>
  value instanceof RsaPkcs1Sha384;

/**
 * RSA PKCSv1.5 using SHA-512
 */
export class RsaPkcs1Sha512 extends $CustomType {}
export const RsaPkcs1Alg$RsaPkcs1Sha512 = () => new RsaPkcs1Sha512();
export const RsaPkcs1Alg$isRsaPkcs1Sha512 = (value) =>
  value instanceof RsaPkcs1Sha512;

/**
 * RSA-PSS using SHA-256 (RSASSA-PSS)
 */
export class RsaPssSha256 extends $CustomType {}
export const RsaPssAlg$RsaPssSha256 = () => new RsaPssSha256();
export const RsaPssAlg$isRsaPssSha256 = (value) =>
  value instanceof RsaPssSha256;

/**
 * RSA-PSS using SHA-384 (RSASSA-PSS)
 */
export class RsaPssSha384 extends $CustomType {}
export const RsaPssAlg$RsaPssSha384 = () => new RsaPssSha384();
export const RsaPssAlg$isRsaPssSha384 = (value) =>
  value instanceof RsaPssSha384;

/**
 * RSA-PSS using SHA-512 (RSASSA-PSS)
 */
export class RsaPssSha512 extends $CustomType {}
export const RsaPssAlg$RsaPssSha512 = () => new RsaPssSha512();
export const RsaPssAlg$isRsaPssSha512 = (value) =>
  value instanceof RsaPssSha512;

/**
 * ECDSA using P-256 and SHA-256
 */
export class EcdsaP256 extends $CustomType {}
export const EcdsaAlg$EcdsaP256 = () => new EcdsaP256();
export const EcdsaAlg$isEcdsaP256 = (value) => value instanceof EcdsaP256;

/**
 * ECDSA using P-384 and SHA-384
 */
export class EcdsaP384 extends $CustomType {}
export const EcdsaAlg$EcdsaP384 = () => new EcdsaP384();
export const EcdsaAlg$isEcdsaP384 = (value) => value instanceof EcdsaP384;

/**
 * ECDSA using P-521 and SHA-512
 */
export class EcdsaP521 extends $CustomType {}
export const EcdsaAlg$EcdsaP521 = () => new EcdsaP521();
export const EcdsaAlg$isEcdsaP521 = (value) => value instanceof EcdsaP521;

/**
 * ECDSA using secp256k1 and SHA-256 (RFC 8812)
 */
export class EcdsaSecp256k1 extends $CustomType {}
export const EcdsaAlg$EcdsaSecp256k1 = () => new EcdsaSecp256k1();
export const EcdsaAlg$isEcdsaSecp256k1 = (value) =>
  value instanceof EcdsaSecp256k1;

/**
 * RSA PKCS#1 v1.5 signing
 */
export class RsaPkcs1 extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const DigitalSignatureAlg$RsaPkcs1 = ($0) => new RsaPkcs1($0);
export const DigitalSignatureAlg$isRsaPkcs1 = (value) =>
  value instanceof RsaPkcs1;
export const DigitalSignatureAlg$RsaPkcs1$0 = (value) => value[0];

/**
 * RSA-PSS signing
 */
export class RsaPss extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const DigitalSignatureAlg$RsaPss = ($0) => new RsaPss($0);
export const DigitalSignatureAlg$isRsaPss = (value) => value instanceof RsaPss;
export const DigitalSignatureAlg$RsaPss$0 = (value) => value[0];

/**
 * ECDSA signing
 */
export class Ecdsa extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const DigitalSignatureAlg$Ecdsa = ($0) => new Ecdsa($0);
export const DigitalSignatureAlg$isEcdsa = (value) => value instanceof Ecdsa;
export const DigitalSignatureAlg$Ecdsa$0 = (value) => value[0];

/**
 * EdDSA (Ed25519 or Ed448, curve determined by key)
 */
export class Eddsa extends $CustomType {}
export const DigitalSignatureAlg$Eddsa = () => new Eddsa();
export const DigitalSignatureAlg$isEddsa = (value) => value instanceof Eddsa;

/**
 * HMAC-based MAC
 */
export class Hmac extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const MacAlg$Hmac = ($0) => new Hmac($0);
export const MacAlg$isHmac = (value) => value instanceof Hmac;
export const MacAlg$Hmac$0 = (value) => value[0];

/**
 * Asymmetric digital signature algorithm
 */
export class DigitalSignature extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SigningAlg$DigitalSignature = ($0) => new DigitalSignature($0);
export const SigningAlg$isDigitalSignature = (value) =>
  value instanceof DigitalSignature;
export const SigningAlg$DigitalSignature$0 = (value) => value[0];

/**
 * MAC algorithm
 */
export class Mac extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const SigningAlg$Mac = ($0) => new Mac($0);
export const SigningAlg$isMac = (value) => value instanceof Mac;
export const SigningAlg$Mac$0 = (value) => value[0];

/**
 * RSAES PKCS1 v1.5 key encryption.
 *
 * **Security Warning:** Vulnerable to padding oracle attacks (Bleichenbacher).
 * Use only for interoperability with legacy systems that require RSA1_5.
 * Prefer `RsaOaepSha256` for new applications.
 *
 * **Note:** Decryption may fail on Node.js 20.x (CVE-2023-46809).
 */
export class RsaPkcs1v15 extends $CustomType {}
export const RsaEncryptionAlg$RsaPkcs1v15 = () => new RsaPkcs1v15();
export const RsaEncryptionAlg$isRsaPkcs1v15 = (value) =>
  value instanceof RsaPkcs1v15;

/**
 * RSAES OAEP using default parameters
 */
export class RsaOaepSha1 extends $CustomType {}
export const RsaEncryptionAlg$RsaOaepSha1 = () => new RsaOaepSha1();
export const RsaEncryptionAlg$isRsaOaepSha1 = (value) =>
  value instanceof RsaOaepSha1;

/**
 * RSAES OAEP using SHA-256 and MGF1 with SHA-256
 */
export class RsaOaepSha256 extends $CustomType {}
export const RsaEncryptionAlg$RsaOaepSha256 = () => new RsaOaepSha256();
export const RsaEncryptionAlg$isRsaOaepSha256 = (value) =>
  value instanceof RsaOaepSha256;

/**
 * ECDH-ES direct key agreement
 */
export class EcdhEsDirect extends $CustomType {}
export const EcdhEsAlg$EcdhEsDirect = () => new EcdhEsDirect();
export const EcdhEsAlg$isEcdhEsDirect = (value) =>
  value instanceof EcdhEsDirect;

/**
 * ECDH-ES with AES Key Wrap
 */
export class EcdhEsAesKw extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const EcdhEsAlg$EcdhEsAesKw = ($0) => new EcdhEsAesKw($0);
export const EcdhEsAlg$isEcdhEsAesKw = (value) => value instanceof EcdhEsAesKw;
export const EcdhEsAlg$EcdhEsAesKw$0 = (value) => value[0];

/**
 * ECDH-ES with ChaCha20-Poly1305 Key Wrap
 */
export class EcdhEsChaCha20Kw extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const EcdhEsAlg$EcdhEsChaCha20Kw = ($0) => new EcdhEsChaCha20Kw($0);
export const EcdhEsAlg$isEcdhEsChaCha20Kw = (value) =>
  value instanceof EcdhEsChaCha20Kw;
export const EcdhEsAlg$EcdhEsChaCha20Kw$0 = (value) => value[0];

/**
 * PBES2 with HMAC-SHA-256 and A128KW wrapping
 */
export class Pbes2Sha256Aes128Kw extends $CustomType {}
export const Pbes2Alg$Pbes2Sha256Aes128Kw = () => new Pbes2Sha256Aes128Kw();
export const Pbes2Alg$isPbes2Sha256Aes128Kw = (value) =>
  value instanceof Pbes2Sha256Aes128Kw;

/**
 * PBES2 with HMAC-SHA-384 and A192KW wrapping
 */
export class Pbes2Sha384Aes192Kw extends $CustomType {}
export const Pbes2Alg$Pbes2Sha384Aes192Kw = () => new Pbes2Sha384Aes192Kw();
export const Pbes2Alg$isPbes2Sha384Aes192Kw = (value) =>
  value instanceof Pbes2Sha384Aes192Kw;

/**
 * PBES2 with HMAC-SHA-512 and A256KW wrapping
 */
export class Pbes2Sha512Aes256Kw extends $CustomType {}
export const Pbes2Alg$Pbes2Sha512Aes256Kw = () => new Pbes2Sha512Aes256Kw();
export const Pbes2Alg$isPbes2Sha512Aes256Kw = (value) =>
  value instanceof Pbes2Sha512Aes256Kw;

/**
 * Direct use of a shared symmetric key
 */
export class Direct extends $CustomType {}
export const KeyEncryptionAlg$Direct = () => new Direct();
export const KeyEncryptionAlg$isDirect = (value) => value instanceof Direct;

/**
 * AES Key Wrap (standard or GCM mode)
 */
export class AesKeyWrap extends $CustomType {
  constructor($0, $1) {
    super();
    this[0] = $0;
    this[1] = $1;
  }
}
export const KeyEncryptionAlg$AesKeyWrap = ($0, $1) => new AesKeyWrap($0, $1);
export const KeyEncryptionAlg$isAesKeyWrap = (value) =>
  value instanceof AesKeyWrap;
export const KeyEncryptionAlg$AesKeyWrap$0 = (value) => value[0];
export const KeyEncryptionAlg$AesKeyWrap$1 = (value) => value[1];

/**
 * ChaCha20-Poly1305 Key Wrap
 */
export class ChaCha20KeyWrap extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const KeyEncryptionAlg$ChaCha20KeyWrap = ($0) => new ChaCha20KeyWrap($0);
export const KeyEncryptionAlg$isChaCha20KeyWrap = (value) =>
  value instanceof ChaCha20KeyWrap;
export const KeyEncryptionAlg$ChaCha20KeyWrap$0 = (value) => value[0];

/**
 * RSA key encryption
 */
export class RsaEncryption extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const KeyEncryptionAlg$RsaEncryption = ($0) => new RsaEncryption($0);
export const KeyEncryptionAlg$isRsaEncryption = (value) =>
  value instanceof RsaEncryption;
export const KeyEncryptionAlg$RsaEncryption$0 = (value) => value[0];

/**
 * ECDH-ES key agreement
 */
export class EcdhEs extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const KeyEncryptionAlg$EcdhEs = ($0) => new EcdhEs($0);
export const KeyEncryptionAlg$isEcdhEs = (value) => value instanceof EcdhEs;
export const KeyEncryptionAlg$EcdhEs$0 = (value) => value[0];

/**
 * PBES2 password-based encryption
 */
export class Pbes2 extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const KeyEncryptionAlg$Pbes2 = ($0) => new Pbes2($0);
export const KeyEncryptionAlg$isPbes2 = (value) => value instanceof Pbes2;
export const KeyEncryptionAlg$Pbes2$0 = (value) => value[0];

/**
 * AES-GCM content encryption
 */
export class AesGcm extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ContentAlg$AesGcm = ($0) => new AesGcm($0);
export const ContentAlg$isAesGcm = (value) => value instanceof AesGcm;
export const ContentAlg$AesGcm$0 = (value) => value[0];

/**
 * AES-CBC with HMAC composite AEAD (CEK is double the AES key size)
 */
export class AesCbcHmac extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ContentAlg$AesCbcHmac = ($0) => new AesCbcHmac($0);
export const ContentAlg$isAesCbcHmac = (value) => value instanceof AesCbcHmac;
export const ContentAlg$AesCbcHmac$0 = (value) => value[0];

/**
 * ChaCha20-Poly1305
 */
export class ChaCha20Poly1305 extends $CustomType {}
export const ContentAlg$ChaCha20Poly1305 = () => new ChaCha20Poly1305();
export const ContentAlg$isChaCha20Poly1305 = (value) =>
  value instanceof ChaCha20Poly1305;

/**
 * XChaCha20-Poly1305
 */
export class XChaCha20Poly1305 extends $CustomType {}
export const ContentAlg$XChaCha20Poly1305 = () => new XChaCha20Poly1305();
export const ContentAlg$isXChaCha20Poly1305 = (value) =>
  value instanceof XChaCha20Poly1305;

/**
 * Signing algorithm
 */
export class SigningAlg extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Alg$SigningAlg = ($0) => new SigningAlg($0);
export const Alg$isSigningAlg = (value) => value instanceof SigningAlg;
export const Alg$SigningAlg$0 = (value) => value[0];

/**
 * Key encryption algorithm
 */
export class KeyEncryptionAlg extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Alg$KeyEncryptionAlg = ($0) => new KeyEncryptionAlg($0);
export const Alg$isKeyEncryptionAlg = (value) =>
  value instanceof KeyEncryptionAlg;
export const Alg$KeyEncryptionAlg$0 = (value) => value[0];

/**
 * Content encryption algorithm
 */
export class ContentAlg extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Alg$ContentAlg = ($0) => new ContentAlg($0);
export const Alg$isContentAlg = (value) => value instanceof ContentAlg;
export const Alg$ContentAlg$0 = (value) => value[0];

export class RsaPrivate extends $CustomType {
  constructor(key, public$) {
    super();
    this.key = key;
    this.public = public$;
  }
}
export const RsaKeyMaterial$RsaPrivate = (key, public$) =>
  new RsaPrivate(key, public$);
export const RsaKeyMaterial$isRsaPrivate = (value) =>
  value instanceof RsaPrivate;
export const RsaKeyMaterial$RsaPrivate$key = (value) => value.key;
export const RsaKeyMaterial$RsaPrivate$0 = (value) => value.key;
export const RsaKeyMaterial$RsaPrivate$public = (value) => value.public;
export const RsaKeyMaterial$RsaPrivate$1 = (value) => value.public;

export class RsaPublic extends $CustomType {
  constructor(key) {
    super();
    this.key = key;
  }
}
export const RsaKeyMaterial$RsaPublic = (key) => new RsaPublic(key);
export const RsaKeyMaterial$isRsaPublic = (value) => value instanceof RsaPublic;
export const RsaKeyMaterial$RsaPublic$key = (value) => value.key;
export const RsaKeyMaterial$RsaPublic$0 = (value) => value.key;

export class EcPrivate extends $CustomType {
  constructor(key, public$, curve) {
    super();
    this.key = key;
    this.public = public$;
    this.curve = curve;
  }
}
export const EcKeyMaterial$EcPrivate = (key, public$, curve) =>
  new EcPrivate(key, public$, curve);
export const EcKeyMaterial$isEcPrivate = (value) => value instanceof EcPrivate;
export const EcKeyMaterial$EcPrivate$key = (value) => value.key;
export const EcKeyMaterial$EcPrivate$0 = (value) => value.key;
export const EcKeyMaterial$EcPrivate$public = (value) => value.public;
export const EcKeyMaterial$EcPrivate$1 = (value) => value.public;
export const EcKeyMaterial$EcPrivate$curve = (value) => value.curve;
export const EcKeyMaterial$EcPrivate$2 = (value) => value.curve;

export class EcPublic extends $CustomType {
  constructor(key, curve) {
    super();
    this.key = key;
    this.curve = curve;
  }
}
export const EcKeyMaterial$EcPublic = (key, curve) => new EcPublic(key, curve);
export const EcKeyMaterial$isEcPublic = (value) => value instanceof EcPublic;
export const EcKeyMaterial$EcPublic$key = (value) => value.key;
export const EcKeyMaterial$EcPublic$0 = (value) => value.key;
export const EcKeyMaterial$EcPublic$curve = (value) => value.curve;
export const EcKeyMaterial$EcPublic$1 = (value) => value.curve;

export class EddsaPrivate extends $CustomType {
  constructor(key, public$, curve) {
    super();
    this.key = key;
    this.public = public$;
    this.curve = curve;
  }
}
export const EddsaKeyMaterial$EddsaPrivate = (key, public$, curve) =>
  new EddsaPrivate(key, public$, curve);
export const EddsaKeyMaterial$isEddsaPrivate = (value) =>
  value instanceof EddsaPrivate;
export const EddsaKeyMaterial$EddsaPrivate$key = (value) => value.key;
export const EddsaKeyMaterial$EddsaPrivate$0 = (value) => value.key;
export const EddsaKeyMaterial$EddsaPrivate$public = (value) => value.public;
export const EddsaKeyMaterial$EddsaPrivate$1 = (value) => value.public;
export const EddsaKeyMaterial$EddsaPrivate$curve = (value) => value.curve;
export const EddsaKeyMaterial$EddsaPrivate$2 = (value) => value.curve;

export class EddsaPublic extends $CustomType {
  constructor(key, curve) {
    super();
    this.key = key;
    this.curve = curve;
  }
}
export const EddsaKeyMaterial$EddsaPublic = (key, curve) =>
  new EddsaPublic(key, curve);
export const EddsaKeyMaterial$isEddsaPublic = (value) =>
  value instanceof EddsaPublic;
export const EddsaKeyMaterial$EddsaPublic$key = (value) => value.key;
export const EddsaKeyMaterial$EddsaPublic$0 = (value) => value.key;
export const EddsaKeyMaterial$EddsaPublic$curve = (value) => value.curve;
export const EddsaKeyMaterial$EddsaPublic$1 = (value) => value.curve;

export class XdhPrivate extends $CustomType {
  constructor(key, public$, curve) {
    super();
    this.key = key;
    this.public = public$;
    this.curve = curve;
  }
}
export const XdhKeyMaterial$XdhPrivate = (key, public$, curve) =>
  new XdhPrivate(key, public$, curve);
export const XdhKeyMaterial$isXdhPrivate = (value) =>
  value instanceof XdhPrivate;
export const XdhKeyMaterial$XdhPrivate$key = (value) => value.key;
export const XdhKeyMaterial$XdhPrivate$0 = (value) => value.key;
export const XdhKeyMaterial$XdhPrivate$public = (value) => value.public;
export const XdhKeyMaterial$XdhPrivate$1 = (value) => value.public;
export const XdhKeyMaterial$XdhPrivate$curve = (value) => value.curve;
export const XdhKeyMaterial$XdhPrivate$2 = (value) => value.curve;

export class XdhPublic extends $CustomType {
  constructor(key, curve) {
    super();
    this.key = key;
    this.curve = curve;
  }
}
export const XdhKeyMaterial$XdhPublic = (key, curve) =>
  new XdhPublic(key, curve);
export const XdhKeyMaterial$isXdhPublic = (value) => value instanceof XdhPublic;
export const XdhKeyMaterial$XdhPublic$key = (value) => value.key;
export const XdhKeyMaterial$XdhPublic$0 = (value) => value.key;
export const XdhKeyMaterial$XdhPublic$curve = (value) => value.curve;
export const XdhKeyMaterial$XdhPublic$1 = (value) => value.curve;

export class OctetKey extends $CustomType {
  constructor(secret) {
    super();
    this.secret = secret;
  }
}
export const KeyMaterial$OctetKey = (secret) => new OctetKey(secret);
export const KeyMaterial$isOctetKey = (value) => value instanceof OctetKey;
export const KeyMaterial$OctetKey$secret = (value) => value.secret;
export const KeyMaterial$OctetKey$0 = (value) => value.secret;

export class Rsa extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const KeyMaterial$Rsa = ($0) => new Rsa($0);
export const KeyMaterial$isRsa = (value) => value instanceof Rsa;
export const KeyMaterial$Rsa$0 = (value) => value[0];

export class Elliptic extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const KeyMaterial$Elliptic = ($0) => new Elliptic($0);
export const KeyMaterial$isElliptic = (value) => value instanceof Elliptic;
export const KeyMaterial$Elliptic$0 = (value) => value[0];

export class Edwards extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const KeyMaterial$Edwards = ($0) => new Edwards($0);
export const KeyMaterial$isEdwards = (value) => value instanceof Edwards;
export const KeyMaterial$Edwards$0 = (value) => value[0];

export class Xdh extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const KeyMaterial$Xdh = ($0) => new Xdh($0);
export const KeyMaterial$isXdh = (value) => value instanceof Xdh;
export const KeyMaterial$Xdh$0 = (value) => value[0];

/**
 * Symmetric key (oct)
 */
export class OctKeyType extends $CustomType {}
export const KeyType$OctKeyType = () => new OctKeyType();
export const KeyType$isOctKeyType = (value) => value instanceof OctKeyType;

/**
 * RSA key
 */
export class RsaKeyType extends $CustomType {}
export const KeyType$RsaKeyType = () => new RsaKeyType();
export const KeyType$isRsaKeyType = (value) => value instanceof RsaKeyType;

/**
 * Elliptic Curve key
 */
export class EcKeyType extends $CustomType {}
export const KeyType$EcKeyType = () => new EcKeyType();
export const KeyType$isEcKeyType = (value) => value instanceof EcKeyType;

/**
 * Octet Key Pair (EdDSA, XDH)
 */
export class OkpKeyType extends $CustomType {}
export const KeyType$OkpKeyType = () => new OkpKeyType();
export const KeyType$isOkpKeyType = (value) => value instanceof OkpKeyType;

class Key extends $CustomType {
  constructor(material, kid, key_use, key_ops, alg) {
    super();
    this.material = material;
    this.kid = kid;
    this.key_use = key_use;
    this.key_ops = key_ops;
    this.alg = alg;
  }
}

/**
 * Extract the message string from a GoseError, regardless of variant.
 */
export function error_message(error) {
  if (error instanceof ParseError) {
    let msg = error[0];
    return msg;
  } else if (error instanceof CryptoError) {
    let msg = error[0];
    return msg;
  } else if (error instanceof InvalidState) {
    let msg = error[0];
    return msg;
  } else {
    return "verification failed";
  }
}

export function new_key(material) {
  return new Key(
    material,
    new $option.None(),
    new $option.None(),
    new $option.None(),
    new $option.None(),
  );
}

export function is_private_key(key) {
  let $ = key.material;
  if ($ instanceof OctetKey) {
    return true;
  } else if ($ instanceof Rsa) {
    let $1 = $[0];
    if ($1 instanceof RsaPrivate) {
      return true;
    } else {
      return false;
    }
  } else if ($ instanceof Elliptic) {
    let $1 = $[0];
    if ($1 instanceof EcPrivate) {
      return true;
    } else {
      return false;
    }
  } else if ($ instanceof Edwards) {
    let $1 = $[0];
    if ($1 instanceof EddsaPrivate) {
      return true;
    } else {
      return false;
    }
  } else {
    let $1 = $[0];
    if ($1 instanceof XdhPrivate) {
      return true;
    } else {
      return false;
    }
  }
}

export function material(key) {
  return key.material;
}

export function material_octet_secret(mat) {
  if (mat instanceof OctetKey) {
    let secret = mat.secret;
    return new Ok(secret);
  } else if (mat instanceof Rsa) {
    return new Error(new InvalidState("expected octet key"));
  } else if (mat instanceof Elliptic) {
    return new Error(new InvalidState("expected octet key"));
  } else if (mat instanceof Edwards) {
    return new Error(new InvalidState("expected octet key"));
  } else {
    return new Error(new InvalidState("expected octet key"));
  }
}

export function material_rsa(mat) {
  if (mat instanceof OctetKey) {
    return new Error(new InvalidState("expected RSA key"));
  } else if (mat instanceof Rsa) {
    let rsa = mat[0];
    return new Ok(rsa);
  } else if (mat instanceof Elliptic) {
    return new Error(new InvalidState("expected RSA key"));
  } else if (mat instanceof Edwards) {
    return new Error(new InvalidState("expected RSA key"));
  } else {
    return new Error(new InvalidState("expected RSA key"));
  }
}

export function material_ec(mat) {
  if (mat instanceof OctetKey) {
    return new Error(new InvalidState("expected EC key"));
  } else if (mat instanceof Rsa) {
    return new Error(new InvalidState("expected EC key"));
  } else if (mat instanceof Elliptic) {
    let ec = mat[0];
    return new Ok(ec);
  } else if (mat instanceof Edwards) {
    return new Error(new InvalidState("expected EC key"));
  } else {
    return new Error(new InvalidState("expected EC key"));
  }
}

export function material_eddsa(mat) {
  if (mat instanceof OctetKey) {
    return new Error(new InvalidState("expected EdDSA key"));
  } else if (mat instanceof Rsa) {
    return new Error(new InvalidState("expected EdDSA key"));
  } else if (mat instanceof Elliptic) {
    return new Error(new InvalidState("expected EdDSA key"));
  } else if (mat instanceof Edwards) {
    let eddsa = mat[0];
    return new Ok(eddsa);
  } else {
    return new Error(new InvalidState("expected EdDSA key"));
  }
}

export function material_xdh(mat) {
  if (mat instanceof OctetKey) {
    return new Error(new InvalidState("expected XDH key"));
  } else if (mat instanceof Rsa) {
    return new Error(new InvalidState("expected XDH key"));
  } else if (mat instanceof Elliptic) {
    return new Error(new InvalidState("expected XDH key"));
  } else if (mat instanceof Edwards) {
    return new Error(new InvalidState("expected XDH key"));
  } else {
    let xdh = mat[0];
    return new Ok(xdh);
  }
}

function ec_public_key_internal(public$) {
  let curve = $ec.public_key_curve(public$);
  return new_key(new Elliptic(new EcPublic(public$, curve)));
}

function ec_private_key(pair) {
  let private$ = pair[0];
  let public$ = pair[1];
  let curve = $ec.curve(private$);
  return new_key(new Elliptic(new EcPrivate(private$, public$, curve)));
}

function parse_ec_der(der) {
  let _pipe = $ec.from_der(der);
  let _pipe$1 = $result.map(_pipe, ec_private_key);
  return $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $ec.public_key_from_der(der);
      return $result.map(_pipe$2, ec_public_key_internal);
    },
  );
}

function xdh_public_key_internal(public$) {
  let curve = $xdh.public_key_curve(public$);
  return new_key(new Xdh(new XdhPublic(public$, curve)));
}

function xdh_private_key(pair) {
  let private$ = pair[0];
  let public$ = pair[1];
  let curve = $xdh.curve(private$);
  return new_key(new Xdh(new XdhPrivate(private$, public$, curve)));
}

function parse_xdh_der(der) {
  let _pipe = $xdh.from_der(der);
  let _pipe$1 = $result.map(_pipe, xdh_private_key);
  return $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $xdh.public_key_from_der(der);
      return $result.map(_pipe$2, xdh_public_key_internal);
    },
  );
}

function eddsa_public_key_internal(public$) {
  let curve = $eddsa.public_key_curve(public$);
  return new_key(new Edwards(new EddsaPublic(public$, curve)));
}

function eddsa_private_key(pair) {
  let private$ = pair[0];
  let public$ = pair[1];
  let curve = $eddsa.curve(private$);
  return new_key(new Edwards(new EddsaPrivate(private$, public$, curve)));
}

function parse_eddsa_der(der) {
  let _pipe = $eddsa.from_der(der);
  let _pipe$1 = $result.map(_pipe, eddsa_private_key);
  return $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $eddsa.public_key_from_der(der);
      return $result.map(_pipe$2, eddsa_public_key_internal);
    },
  );
}

function rsa_public_key_internal(public$) {
  return new_key(new Rsa(new RsaPublic(public$)));
}

function rsa_private_key_internal(pair) {
  let private$ = pair[0];
  let public$ = pair[1];
  return new_key(new Rsa(new RsaPrivate(private$, public$)));
}

function parse_rsa_der(der) {
  let _pipe = $rsa.from_der(der, new $rsa.Pkcs8());
  let _pipe$1 = $result.map(_pipe, rsa_private_key_internal);
  let _pipe$2 = $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $rsa.from_der(der, new $rsa.Pkcs1());
      return $result.map(_pipe$2, rsa_private_key_internal);
    },
  );
  let _pipe$3 = $result.lazy_or(
    _pipe$2,
    () => {
      let _pipe$3 = $rsa.public_key_from_der(der, new $rsa.Spki());
      return $result.map(_pipe$3, rsa_public_key_internal);
    },
  );
  return $result.lazy_or(
    _pipe$3,
    () => {
      let _pipe$4 = $rsa.public_key_from_der(der, new $rsa.RsaPublicKey());
      return $result.map(_pipe$4, rsa_public_key_internal);
    },
  );
}

/**
 * Create a key from DER-encoded data.
 *
 * Auto-detects key type (RSA, EC, EdDSA, XDH) and format (PKCS#1, PKCS#8, SPKI).
 * Supports both private and public keys.
 */
export function from_der(der) {
  let _pipe = parse_rsa_der(der);
  let _pipe$1 = $result.lazy_or(_pipe, () => { return parse_eddsa_der(der); });
  let _pipe$2 = $result.lazy_or(_pipe$1, () => { return parse_xdh_der(der); });
  let _pipe$3 = $result.lazy_or(_pipe$2, () => { return parse_ec_der(der); });
  return $result.map_error(
    _pipe$3,
    (_) => {
      return new ParseError(
        "invalid DER: not a recognized RSA, EC, EdDSA, or XDH key format",
      );
    },
  );
}

/**
 * Create an EdDSA key pair from raw private key bytes.
 *
 * The public key is derived from the private key.
 * This is the inverse of `to_octet_bits` for EdDSA private keys.
 */
export function from_eddsa_bits(curve, private_bits) {
  let _pipe = $eddsa.from_bytes(curve, private_bits);
  let _pipe$1 = $result.map(
    _pipe,
    (pair) => {
      let private$ = pair[0];
      let public$ = pair[1];
      return new_key(new Edwards(new EddsaPrivate(private$, public$, curve)));
    },
  );
  return $result.replace_error(
    _pipe$1,
    new ParseError("invalid EdDSA private key bits"),
  );
}

/**
 * Create an EdDSA public key from raw bytes.
 *
 * This is the inverse of `to_octet_bits` for EdDSA public keys.
 */
export function from_eddsa_public_bits(curve, public_bits) {
  let _pipe = $eddsa.public_key_from_bytes(curve, public_bits);
  let _pipe$1 = $result.map(
    _pipe,
    (public$) => {
      return new_key(new Edwards(new EddsaPublic(public$, curve)));
    },
  );
  return $result.replace_error(
    _pipe$1,
    new ParseError("invalid EdDSA public key bits"),
  );
}

/**
 * Create a symmetric key from raw bytes.
 *
 * Used for HMAC signing (HS256/384/512) and direct encryption.
 * Returns an error if the secret is empty.
 *
 * ## Example
 *
 * ```gleam
 * let secret = crypto.random_bytes(32)
 * let assert Ok(key) = gose.from_octet_bits(secret)
 * ```
 */
export function from_octet_bits(secret) {
  let $ = $bit_array.byte_size(secret);
  if ($ === 0) {
    return new Error(new InvalidState("oct key must not be empty"));
  } else {
    return new Ok(new_key(new OctetKey(secret)));
  }
}

function parse_ec_pem(pem) {
  let _pipe = $ec.from_pem(pem);
  let _pipe$1 = $result.map(_pipe, ec_private_key);
  return $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $ec.public_key_from_pem(pem);
      return $result.map(_pipe$2, ec_public_key_internal);
    },
  );
}

function parse_xdh_pem(pem) {
  let _pipe = $xdh.from_pem(pem);
  let _pipe$1 = $result.map(_pipe, xdh_private_key);
  return $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $xdh.public_key_from_pem(pem);
      return $result.map(_pipe$2, xdh_public_key_internal);
    },
  );
}

function parse_eddsa_pem(pem) {
  let _pipe = $eddsa.from_pem(pem);
  let _pipe$1 = $result.map(_pipe, eddsa_private_key);
  return $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $eddsa.public_key_from_pem(pem);
      return $result.map(_pipe$2, eddsa_public_key_internal);
    },
  );
}

function parse_rsa_pem(pem) {
  let _pipe = $rsa.from_pem(pem, new $rsa.Pkcs8());
  let _pipe$1 = $result.map(_pipe, rsa_private_key_internal);
  let _pipe$2 = $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $rsa.from_pem(pem, new $rsa.Pkcs1());
      return $result.map(_pipe$2, rsa_private_key_internal);
    },
  );
  let _pipe$3 = $result.lazy_or(
    _pipe$2,
    () => {
      let _pipe$3 = $rsa.public_key_from_pem(pem, new $rsa.Spki());
      return $result.map(_pipe$3, rsa_public_key_internal);
    },
  );
  return $result.lazy_or(
    _pipe$3,
    () => {
      let _pipe$4 = $rsa.public_key_from_pem(pem, new $rsa.RsaPublicKey());
      return $result.map(_pipe$4, rsa_public_key_internal);
    },
  );
}

/**
 * Create a key from PEM-encoded data.
 *
 * Auto-detects key type (RSA, EC, EdDSA, XDH) and format (PKCS#1, PKCS#8, SPKI).
 * Supports both private and public keys.
 */
export function from_pem(pem) {
  let _pipe = parse_rsa_pem(pem);
  let _pipe$1 = $result.lazy_or(_pipe, () => { return parse_eddsa_pem(pem); });
  let _pipe$2 = $result.lazy_or(_pipe$1, () => { return parse_xdh_pem(pem); });
  let _pipe$3 = $result.lazy_or(_pipe$2, () => { return parse_ec_pem(pem); });
  return $result.map_error(
    _pipe$3,
    (_) => {
      return new ParseError(
        "invalid PEM: not a recognized RSA, EC, EdDSA, or XDH key format",
      );
    },
  );
}

/**
 * Create an XDH key pair from raw private key bytes.
 *
 * The public key is derived from the private key.
 * This is the inverse of `to_octet_bits` for XDH private keys.
 */
export function from_xdh_bits(curve, private_bits) {
  let _pipe = $xdh.from_bytes(curve, private_bits);
  let _pipe$1 = $result.map(
    _pipe,
    (pair) => {
      let private$ = pair[0];
      let public$ = pair[1];
      return new_key(new Xdh(new XdhPrivate(private$, public$, curve)));
    },
  );
  return $result.replace_error(
    _pipe$1,
    new ParseError("invalid XDH private key bits"),
  );
}

/**
 * Create an XDH public key from raw bytes.
 *
 * This is the inverse of `to_octet_bits` for XDH public keys.
 */
export function from_xdh_public_bits(curve, public_bits) {
  let _pipe = $xdh.public_key_from_bytes(curve, public_bits);
  let _pipe$1 = $result.map(
    _pipe,
    (public$) => { return new_key(new Xdh(new XdhPublic(public$, curve))); },
  );
  return $result.replace_error(
    _pipe$1,
    new ParseError("invalid XDH public key bits"),
  );
}

/**
 * Generate a new EC key pair for the given curve.
 *
 * Supported curves: P256, P384, P521, Secp256k1.
 */
export function generate_ec(curve) {
  let $ = $ec.generate_key_pair(curve);
  let private$ = $[0];
  let public$ = $[1];
  return new_key(new Elliptic(new EcPrivate(private$, public$, curve)));
}

/**
 * Generate a new EdDSA key pair for the given curve.
 *
 * Supported curves: Ed25519, Ed448.
 */
export function generate_eddsa(curve) {
  let $ = $eddsa.generate_key_pair(curve);
  let private$ = $[0];
  let public$ = $[1];
  return new_key(new Edwards(new EddsaPrivate(private$, public$, curve)));
}

export function hmac_alg_key_size(alg) {
  if (alg instanceof HmacSha256) {
    return 32;
  } else if (alg instanceof HmacSha384) {
    return 48;
  } else {
    return 64;
  }
}

/**
 * Generate a symmetric key for HMAC signing.
 *
 * The key size is derived from the algorithm:
 * - `HmacSha256` → 32 bytes
 * - `HmacSha384` → 48 bytes
 * - `HmacSha512` → 64 bytes
 */
export function generate_hmac_key(alg) {
  let size = hmac_alg_key_size(alg);
  let secret = $crypto.random_bytes(size);
  return new_key(new OctetKey(secret));
}

export function aes_key_size(size) {
  if (size instanceof Aes128) {
    return 16;
  } else if (size instanceof Aes192) {
    return 24;
  } else {
    return 32;
  }
}

export function content_alg_key_size(enc) {
  if (enc instanceof AesGcm) {
    let size = enc[0];
    return aes_key_size(size);
  } else if (enc instanceof AesCbcHmac) {
    let size = enc[0];
    return aes_key_size(size) * 2;
  } else if (enc instanceof ChaCha20Poly1305) {
    return 32;
  } else {
    return 32;
  }
}

/**
 * Generate a symmetric key for JWE content encryption.
 *
 * The key size is derived from the encryption algorithm:
 * - `AesGcm(Aes128)` → 16 bytes
 * - `AesGcm(Aes192)` → 24 bytes
 * - `AesGcm(Aes256)` → 32 bytes
 * - `AesCbcHmac(Aes128)` → 32 bytes (16 + 16 for MAC)
 * - `AesCbcHmac(Aes192)` → 48 bytes (24 + 24 for MAC)
 * - `AesCbcHmac(Aes256)` → 64 bytes (32 + 32 for MAC)
 * - `ChaCha20Poly1305` → 32 bytes
 * - `XChaCha20Poly1305` → 32 bytes
 */
export function generate_enc_key(enc) {
  let size = content_alg_key_size(enc);
  let secret = $crypto.random_bytes(size);
  return new_key(new OctetKey(secret));
}

/**
 * Generate a symmetric key for AES Key Wrap.
 *
 * The key size is derived from the AES variant:
 * - `Aes128` → 16 bytes
 * - `Aes192` → 24 bytes
 * - `Aes256` → 32 bytes
 */
export function generate_aes_kw_key(size) {
  let byte_count = aes_key_size(size);
  let secret = $crypto.random_bytes(byte_count);
  return new_key(new OctetKey(secret));
}

/**
 * Generate a symmetric key for ChaCha20-Poly1305 Key Wrap (C20PKW / XC20PKW).
 *
 * Always generates a 32-byte key, as both ChaCha20 and XChaCha20 use 256-bit keys.
 */
export function generate_chacha20_kw_key() {
  let secret = $crypto.random_bytes(32);
  return new_key(new OctetKey(secret));
}

/**
 * Generate a new RSA key pair with the given key size in bits.
 * Common sizes are 2048, 3072, and 4096. Keys smaller than 2048
 * bits are not recommended for security.
 */
export function generate_rsa(bits) {
  let $ = $rsa.generate_key_pair(bits);
  if ($ instanceof Ok) {
    let private$ = $[0][0];
    let public$ = $[0][1];
    return new Ok(new_key(new Rsa(new RsaPrivate(private$, public$))));
  } else {
    return new Error(new CryptoError("RSA key generation failed"));
  }
}

/**
 * Generate a new XDH key pair for key agreement.
 *
 * Supported curves: X25519, X448.
 */
export function generate_xdh(curve) {
  let $ = $xdh.generate_key_pair(curve);
  let private$ = $[0];
  let public$ = $[1];
  return new_key(new Xdh(new XdhPrivate(private$, public$, curve)));
}

export function ec_public_key_from_raw_coordinates(curve, x, y) {
  let coord_size = $ec.coordinate_size(curve);
  return $bool.guard(
    $bit_array.byte_size(x) !== coord_size,
    new Error(new ParseError("EC x coordinate wrong length")),
    () => {
      return $bool.guard(
        $bit_array.byte_size(y) !== coord_size,
        new Error(new ParseError("EC y coordinate wrong length")),
        () => {
          let raw_point = $bit_array.concat(toList([toBitArray([4]), x, y]));
          let _pipe = $ec.public_key_from_raw_point(curve, raw_point);
          return $result.replace_error(
            _pipe,
            new ParseError("invalid EC coordinates"),
          );
        },
      );
    },
  );
}

/**
 * Create an EC public key from curve and x,y coordinates (big-endian bytes).
 */
export function ec_public_key_from_coordinates(curve, x, y) {
  let _pipe = ec_public_key_from_raw_coordinates(curve, x, y);
  return $result.map(
    _pipe,
    (public$) => { return new_key(new Elliptic(new EcPublic(public$, curve))); },
  );
}

export function ec_raw_coordinates(public$, curve) {
  let coord_size = $ec.coordinate_size(curve);
  let raw_point = $ec.public_key_to_raw_point(public$);
  let expected_size = 1 + coord_size * 2;
  let $ = $bit_array.byte_size(raw_point) === expected_size;
  if ($ && raw_point.bitSize >= 8 && raw_point.byteAt(0) === 4) {
    let rest = bitArraySlice(raw_point, 8);
    let error = new InvalidState("invalid raw point format");
    return $result.try$(
      (() => {
        let _pipe = $bit_array.slice(rest, 0, coord_size);
        return $result.replace_error(_pipe, error);
      })(),
      (x) => {
        return $result.try$(
          (() => {
            let _pipe = $bit_array.slice(rest, coord_size, coord_size);
            return $result.replace_error(_pipe, error);
          })(),
          (y) => { return new Ok([x, y]); },
        );
      },
    );
  } else {
    return new Error(new InvalidState("invalid raw point format"));
  }
}

/**
 * Set the algorithm (`alg`) metadata parameter on a key.
 */
export function with_alg(key, alg) {
  return new Key(
    key.material,
    key.kid,
    key.key_use,
    key.key_ops,
    new $option.Some(alg),
  );
}

function is_encrypting_op(op) {
  if (op instanceof Sign) {
    return false;
  } else if (op instanceof Verify) {
    return false;
  } else if (op instanceof Encrypt) {
    return true;
  } else if (op instanceof Decrypt) {
    return true;
  } else if (op instanceof WrapKey) {
    return true;
  } else if (op instanceof UnwrapKey) {
    return true;
  } else if (op instanceof DeriveKey) {
    return true;
  } else {
    return true;
  }
}

function is_signing_op(op) {
  if (op instanceof Sign) {
    return true;
  } else if (op instanceof Verify) {
    return true;
  } else if (op instanceof Encrypt) {
    return false;
  } else if (op instanceof Decrypt) {
    return false;
  } else if (op instanceof WrapKey) {
    return false;
  } else if (op instanceof UnwrapKey) {
    return false;
  } else if (op instanceof DeriveKey) {
    return false;
  } else {
    return false;
  }
}

export function validate_key_use_ops(key_use, key_ops) {
  if (key_use instanceof $option.Some && key_ops instanceof $option.Some) {
    let $ = key_use[0];
    if ($ instanceof Signing) {
      let ops = key_ops[0];
      let $1 = $list.all(ops, is_signing_op);
      if ($1) {
        return new Ok(undefined);
      } else {
        return new Error(new InvalidState("key_ops incompatible with use=sig"));
      }
    } else {
      let ops = key_ops[0];
      let $1 = $list.all(ops, is_encrypting_op);
      if ($1) {
        return new Ok(undefined);
      } else {
        return new Error(new InvalidState("key_ops incompatible with use=enc"));
      }
    }
  } else {
    return new Ok(undefined);
  }
}

/**
 * Set the key operations parameter.
 *
 * Per RFC 7517, the values should be consistent with `key_use` if both are present:
 * - `Signing` use implies `Sign` and/or `Verify` operations
 * - `Encrypting` use implies `Encrypt`, `Decrypt`, `WrapKey`, `UnwrapKey`, `DeriveKey`, `DeriveBits`
 *
 * Returns an error if the list is empty, contains duplicates, or is
 * incompatible with the key's existing `key_use`.
 */
export function with_key_ops(key, ops) {
  if (ops instanceof $Empty) {
    return new Error(new InvalidState("key_ops must not be empty"));
  } else {
    return $bool.guard(
      !isEqual($list.unique(ops), ops),
      new Error(new InvalidState("key_ops must not contain duplicates")),
      () => {
        let _pipe = validate_key_use_ops(key.key_use, new $option.Some(ops));
        return $result.replace(
          _pipe,
          new Key(
            key.material,
            key.kid,
            key.key_use,
            new $option.Some(ops),
            key.alg,
          ),
        );
      },
    );
  }
}

/**
 * Validate key use against RFC 8037 curve restrictions.
 * - EdDSA keys (Ed25519/Ed448): only `sig` allowed
 * - XDH keys (X25519/X448): only `enc` allowed
 * 
 * @ignore
 */
function validate_rfc8037_key_use(material, use_) {
  if (use_ instanceof $option.Some) {
    let $ = use_[0];
    if ($ instanceof Signing) {
      if (material instanceof Xdh) {
        return new Error(
          new InvalidState("XDH keys (X25519/X448) cannot be used for signing"),
        );
      } else {
        return new Ok(undefined);
      }
    } else if (material instanceof Edwards) {
      return new Error(
        new InvalidState(
          "EdDSA keys (Ed25519/Ed448) cannot be used for encryption",
        ),
      );
    } else {
      return new Ok(undefined);
    }
  } else {
    return new Ok(undefined);
  }
}

/**
 * Set the public key use parameter.
 *
 * Returns an error if the key already has `key_ops` that are incompatible with
 * the specified use, or if the use is incompatible with the key type per RFC
 * 8037 (EdDSA keys can only be used for signing, XDH keys can only be used for
 * encryption).
 */
export function with_key_use(key, use_) {
  return $result.try$(
    validate_key_use_ops(new $option.Some(use_), key.key_ops),
    (_) => {
      return $result.try$(
        validate_rfc8037_key_use(key.material, new $option.Some(use_)),
        (_) => {
          return new Ok(
            new Key(
              key.material,
              key.kid,
              new $option.Some(use_),
              key.key_ops,
              key.alg,
            ),
          );
        },
      );
    },
  );
}

/**
 * Set the key ID (`kid`) metadata parameter on a key.
 */
export function with_kid(key, kid) {
  return new Key(
    key.material,
    new $option.Some(kid),
    key.key_use,
    key.key_ops,
    key.alg,
  );
}

/**
 * Set the key ID (`kid`) metadata parameter on a key using raw bytes.
 *
 * In COSE (RFC 9052), kid is a bstr that may contain arbitrary bytes.
 * For JWK interoperability where kid is a JSON string, use `with_kid`.
 */
export function with_kid_bits(key, kid) {
  return new Key(
    key.material,
    new $option.Some(kid),
    key.key_use,
    key.key_ops,
    key.alg,
  );
}

/**
 * Get the algorithm (`alg`) parameter.
 */
export function alg(key) {
  return $option.to_result(key.alg, undefined);
}

/**
 * Get the curve used by an EC key.
 *
 * Returns an error if the key is not an EC key.
 */
export function ec_curve(key) {
  let _pipe = material_ec(key.material);
  return $result.map(
    _pipe,
    (ec) => {
      if (ec instanceof EcPrivate) {
        let curve = ec.curve;
        return curve;
      } else {
        let curve = ec.curve;
        return curve;
      }
    },
  );
}

/**
 * Extract the EC public key.
 *
 * Works with both EC private keys (extracts the public component)
 * and EC public keys.
 *
 * Returns an error if the key is not an EC key.
 */
export function ec_public_key(key) {
  let _pipe = material_ec(key.material);
  return $result.map(
    _pipe,
    (ec) => {
      if (ec instanceof EcPrivate) {
        let public$ = ec.public;
        return public$;
      } else {
        let k = ec.key;
        return k;
      }
    },
  );
}

/**
 * Get the x and y coordinates from an EC public key.
 *
 * The coordinates are returned as raw big-endian bytes, padded to
 * the coordinate size for the curve.
 *
 * Returns an error if the key is not an EC key.
 */
export function ec_public_key_coordinates(key) {
  return $result.try$(
    ec_public_key(key),
    (public$) => {
      return $result.try$(
        ec_curve(key),
        (curve) => { return ec_raw_coordinates(public$, curve); },
      );
    },
  );
}

/**
 * Get the curve used by an EdDSA key.
 *
 * Returns an error if the key is not an EdDSA key.
 */
export function eddsa_curve(key) {
  let _pipe = material_eddsa(key.material);
  return $result.map(
    _pipe,
    (eddsa) => {
      if (eddsa instanceof EddsaPrivate) {
        let curve = eddsa.curve;
        return curve;
      } else {
        let curve = eddsa.curve;
        return curve;
      }
    },
  );
}

/**
 * Extract the EdDSA public key.
 *
 * Works with both EdDSA private keys (extracts the public component)
 * and EdDSA public keys.
 *
 * Returns an error if the key is not an EdDSA key.
 */
export function eddsa_public_key(key) {
  let _pipe = material_eddsa(key.material);
  return $result.map(
    _pipe,
    (eddsa) => {
      if (eddsa instanceof EddsaPrivate) {
        let public$ = eddsa.public;
        return public$;
      } else {
        let k = eddsa.key;
        return k;
      }
    },
  );
}

/**
 * Get the key operations parameter.
 */
export function key_ops(key) {
  return $option.to_result(key.key_ops, undefined);
}

/**
 * Get the key type (kty) for this key.
 */
export function key_type(key) {
  let $ = key.material;
  if ($ instanceof OctetKey) {
    return new OctKeyType();
  } else if ($ instanceof Rsa) {
    return new RsaKeyType();
  } else if ($ instanceof Elliptic) {
    return new EcKeyType();
  } else if ($ instanceof Edwards) {
    return new OkpKeyType();
  } else {
    return new OkpKeyType();
  }
}

/**
 * Get the public key use parameter.
 */
export function key_use(key) {
  return $option.to_result(key.key_use, undefined);
}

/**
 * Get the key ID (kid) parameter.
 *
 * The return type depends on the key's kid type parameter:
 * - `Key(String)` (from JWK) → `Result(String, Nil)`
 * - `Key(BitArray)` (from COSE) → `Result(BitArray, Nil)`
 */
export function kid(key) {
  return $option.to_result(key.kid, undefined);
}

/**
 * Get the size of an octet (symmetric) key in bytes.
 *
 * Returns an error if the key is not an octet key.
 */
export function octet_key_size(key) {
  let $ = material_octet_secret(key.material);
  if ($ instanceof Ok) {
    let secret = $[0];
    return new Ok($bit_array.byte_size(secret));
  } else {
    return new Error(new InvalidState("key is not an octet key"));
  }
}

/**
 * Extract the RSA public key.
 *
 * Works with both RSA private keys (extracts the public component)
 * and RSA public keys.
 *
 * Returns an error if the key is not an RSA key.
 */
export function rsa_public_key(key) {
  let _pipe = material_rsa(key.material);
  return $result.map(
    _pipe,
    (rsa) => {
      if (rsa instanceof RsaPrivate) {
        let public$ = rsa.public;
        return public$;
      } else {
        let k = rsa.key;
        return k;
      }
    },
  );
}

/**
 * Get the curve used by an XDH key.
 *
 * Returns an error if the key is not an XDH key.
 */
export function xdh_curve(key) {
  let _pipe = material_xdh(key.material);
  return $result.map(
    _pipe,
    (xdh) => {
      if (xdh instanceof XdhPrivate) {
        let curve = xdh.curve;
        return curve;
      } else {
        let curve = xdh.curve;
        return curve;
      }
    },
  );
}

/**
 * Extract the XDH public key (X25519/X448).
 *
 * Works with both XDH private keys (extracts the public component)
 * and XDH public keys.
 *
 * Returns an error if the key is not an XDH key.
 */
export function xdh_public_key(key) {
  let _pipe = material_xdh(key.material);
  return $result.map(
    _pipe,
    (xdh) => {
      if (xdh instanceof XdhPrivate) {
        let public$ = xdh.public;
        return public$;
      } else {
        let k = xdh.key;
        return k;
      }
    },
  );
}

function map_public_key_op(op) {
  if (op instanceof Sign) {
    return new Ok(new Verify());
  } else if (op instanceof Verify) {
    return new Ok(op);
  } else if (op instanceof Encrypt) {
    return new Ok(op);
  } else if (op instanceof Decrypt) {
    return new Error(undefined);
  } else if (op instanceof WrapKey) {
    return new Ok(op);
  } else if (op instanceof UnwrapKey) {
    return new Error(undefined);
  } else if (op instanceof DeriveKey) {
    return new Ok(op);
  } else {
    return new Ok(op);
  }
}

function filter_public_key_ops(ops) {
  let $ = $list.unique($list.filter_map(ops, map_public_key_op));
  if ($ instanceof $Empty) {
    return new Error(undefined);
  } else {
    let filtered = $;
    return new Ok(filtered);
  }
}

/**
 * Extract the public key from an asymmetric key.
 *
 * For private keys, extracts the corresponding public key.
 * For public keys, returns the key unchanged.
 * Returns an error for symmetric octet keys.
 *
 * When extracting a public key, `key_ops` are filtered to public-safe operations:
 * - `Sign` is mapped to `Verify`
 * - `Decrypt` and `UnwrapKey` are removed (private-only)
 * - Other operations are preserved
 *
 * ## Example
 *
 * ```gleam
 * let private_key = gose.generate_ec(ec.P256)
 * let assert Ok(pub_key) = gose.public_key(private_key)
 * ```
 */
export function public_key(key) {
  let _block;
  let _pipe = key.key_ops;
  let _pipe$1 = $option.map(_pipe, filter_public_key_ops);
  _block = $option.then$(_pipe$1, $option.from_result);
  let filtered_ops = _block;
  let $ = key.material;
  if ($ instanceof OctetKey) {
    return new Error(new InvalidState("octet keys are not asymmetric"));
  } else if ($ instanceof Rsa) {
    let $1 = $[0];
    if ($1 instanceof RsaPrivate) {
      let public$ = $1.public;
      return new Ok(
        new Key(
          new Rsa(new RsaPublic(public$)),
          key.kid,
          key.key_use,
          filtered_ops,
          key.alg,
        ),
      );
    } else {
      return new Ok(
        new Key(key.material, key.kid, key.key_use, filtered_ops, key.alg),
      );
    }
  } else if ($ instanceof Elliptic) {
    let $1 = $[0];
    if ($1 instanceof EcPrivate) {
      let public$ = $1.public;
      let curve = $1.curve;
      return new Ok(
        new Key(
          new Elliptic(new EcPublic(public$, curve)),
          key.kid,
          key.key_use,
          filtered_ops,
          key.alg,
        ),
      );
    } else {
      return new Ok(
        new Key(key.material, key.kid, key.key_use, filtered_ops, key.alg),
      );
    }
  } else if ($ instanceof Edwards) {
    let $1 = $[0];
    if ($1 instanceof EddsaPrivate) {
      let public$ = $1.public;
      let curve = $1.curve;
      return new Ok(
        new Key(
          new Edwards(new EddsaPublic(public$, curve)),
          key.kid,
          key.key_use,
          filtered_ops,
          key.alg,
        ),
      );
    } else {
      return new Ok(
        new Key(key.material, key.kid, key.key_use, filtered_ops, key.alg),
      );
    }
  } else {
    let $1 = $[0];
    if ($1 instanceof XdhPrivate) {
      let public$ = $1.public;
      let curve = $1.curve;
      return new Ok(
        new Key(
          new Xdh(new XdhPublic(public$, curve)),
          key.kid,
          key.key_use,
          filtered_ops,
          key.alg,
        ),
      );
    } else {
      return new Ok(
        new Key(key.material, key.kid, key.key_use, filtered_ops, key.alg),
      );
    }
  }
}

/**
 * Serialize a key to DER format.
 *
 * Supports RSA, EC, EdDSA, and XDH keys (both private and public).
 * Uses PKCS#8 for private keys and SPKI for public keys.
 */
export function to_der(key) {
  let $ = key.material;
  if ($ instanceof OctetKey) {
    return new Error(new InvalidState("octet keys cannot be serialized to DER"));
  } else if ($ instanceof Rsa) {
    let $1 = $[0];
    if ($1 instanceof RsaPrivate) {
      let private$ = $1.key;
      let _pipe = $rsa.to_der(private$, new $rsa.Pkcs8());
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize RSA private key"),
      );
    } else {
      let public$ = $1.key;
      let _pipe = $rsa.public_key_to_der(public$, new $rsa.Spki());
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize RSA public key"),
      );
    }
  } else if ($ instanceof Elliptic) {
    let $1 = $[0];
    if ($1 instanceof EcPrivate) {
      let private$ = $1.key;
      let _pipe = $ec.to_der(private$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize EC private key"),
      );
    } else {
      let public$ = $1.key;
      let _pipe = $ec.public_key_to_der(public$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize EC public key"),
      );
    }
  } else if ($ instanceof Edwards) {
    let $1 = $[0];
    if ($1 instanceof EddsaPrivate) {
      let private$ = $1.key;
      let _pipe = $eddsa.to_der(private$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize EdDSA private key"),
      );
    } else {
      let public$ = $1.key;
      let _pipe = $eddsa.public_key_to_der(public$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize EdDSA public key"),
      );
    }
  } else {
    let $1 = $[0];
    if ($1 instanceof XdhPrivate) {
      let private$ = $1.key;
      let _pipe = $xdh.to_der(private$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize XDH private key"),
      );
    } else {
      let public$ = $1.key;
      let _pipe = $xdh.public_key_to_der(public$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize XDH public key"),
      );
    }
  }
}

/**
 * Export the raw bytes of a key.
 *
 * Supported key types:
 * - Octet keys: returns the secret bytes
 * - EdDSA/XDH private keys: returns the private key bytes (d)
 * - EdDSA/XDH public keys: returns the public key bytes (x)
 */
export function to_octet_bits(key) {
  let $ = key.material;
  if ($ instanceof OctetKey) {
    let secret = $.secret;
    return new Ok(secret);
  } else if ($ instanceof Rsa) {
    return new Error(
      new InvalidState("key has no single-value byte representation"),
    );
  } else if ($ instanceof Elliptic) {
    return new Error(
      new InvalidState("key has no single-value byte representation"),
    );
  } else if ($ instanceof Edwards) {
    let $1 = $[0];
    if ($1 instanceof EddsaPrivate) {
      let private$ = $1.key;
      return new Ok($eddsa.to_bytes(private$));
    } else {
      let public$ = $1.key;
      return new Ok($eddsa.public_key_to_bytes(public$));
    }
  } else {
    let $1 = $[0];
    if ($1 instanceof XdhPrivate) {
      let private$ = $1.key;
      return new Ok($xdh.to_bytes(private$));
    } else {
      let public$ = $1.key;
      return new Ok($xdh.public_key_to_bytes(public$));
    }
  }
}

/**
 * Serialize a key to PEM format.
 *
 * Supports RSA, EC, EdDSA, and XDH keys (both private and public).
 * Uses PKCS#8 for private keys and SPKI for public keys.
 */
export function to_pem(key) {
  let $ = key.material;
  if ($ instanceof OctetKey) {
    return new Error(new InvalidState("octet keys cannot be serialized to PEM"));
  } else if ($ instanceof Rsa) {
    let $1 = $[0];
    if ($1 instanceof RsaPrivate) {
      let private$ = $1.key;
      let _pipe = $rsa.to_pem(private$, new $rsa.Pkcs8());
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize RSA private key"),
      );
    } else {
      let public$ = $1.key;
      let _pipe = $rsa.public_key_to_pem(public$, new $rsa.Spki());
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize RSA public key"),
      );
    }
  } else if ($ instanceof Elliptic) {
    let $1 = $[0];
    if ($1 instanceof EcPrivate) {
      let private$ = $1.key;
      let _pipe = $ec.to_pem(private$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize EC private key"),
      );
    } else {
      let public$ = $1.key;
      let _pipe = $ec.public_key_to_pem(public$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize EC public key"),
      );
    }
  } else if ($ instanceof Edwards) {
    let $1 = $[0];
    if ($1 instanceof EddsaPrivate) {
      let private$ = $1.key;
      let _pipe = $eddsa.to_pem(private$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize EdDSA private key"),
      );
    } else {
      let public$ = $1.key;
      let _pipe = $eddsa.public_key_to_pem(public$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize EdDSA public key"),
      );
    }
  } else {
    let $1 = $[0];
    if ($1 instanceof XdhPrivate) {
      let private$ = $1.key;
      let _pipe = $xdh.to_pem(private$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize XDH private key"),
      );
    } else {
      let public$ = $1.key;
      let _pipe = $xdh.public_key_to_pem(public$);
      return $result.replace_error(
        _pipe,
        new InvalidState("failed to serialize XDH public key"),
      );
    }
  }
}

export function build(material, kid, key_use, key_ops, alg) {
  return new Key(material, kid, key_use, key_ops, alg);
}

export function validate_rfc8037_key_use_public(material, use_) {
  return validate_rfc8037_key_use(material, use_);
}

export function chacha20_kw_nonce_size(variant) {
  if (variant instanceof C20PKw) {
    return 12;
  } else {
    return 24;
  }
}
