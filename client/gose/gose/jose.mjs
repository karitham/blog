import { Ok, Error } from "../gleam.mjs";
import * as $gose from "../gose.mjs";

/**
 * Convert a signing algorithm to its JOSE string representation.
 */
export function signing_alg_to_string(alg) {
  if (alg instanceof $gose.DigitalSignature) {
    let $ = alg[0];
    if ($ instanceof $gose.RsaPkcs1) {
      let $1 = $[0];
      if ($1 instanceof $gose.RsaPkcs1Sha256) {
        return "RS256";
      } else if ($1 instanceof $gose.RsaPkcs1Sha384) {
        return "RS384";
      } else {
        return "RS512";
      }
    } else if ($ instanceof $gose.RsaPss) {
      let $1 = $[0];
      if ($1 instanceof $gose.RsaPssSha256) {
        return "PS256";
      } else if ($1 instanceof $gose.RsaPssSha384) {
        return "PS384";
      } else {
        return "PS512";
      }
    } else if ($ instanceof $gose.Ecdsa) {
      let $1 = $[0];
      if ($1 instanceof $gose.EcdsaP256) {
        return "ES256";
      } else if ($1 instanceof $gose.EcdsaP384) {
        return "ES384";
      } else if ($1 instanceof $gose.EcdsaP521) {
        return "ES512";
      } else {
        return "ES256K";
      }
    } else {
      return "EdDSA";
    }
  } else {
    let $ = alg[0][0];
    if ($ instanceof $gose.HmacSha256) {
      return "HS256";
    } else if ($ instanceof $gose.HmacSha384) {
      return "HS384";
    } else {
      return "HS512";
    }
  }
}

/**
 * Parse a signing algorithm from its JOSE string representation.
 */
export function signing_alg_from_string(alg) {
  if (alg === "HS256") {
    return new Ok(new $gose.Mac(new $gose.Hmac(new $gose.HmacSha256())));
  } else if (alg === "HS384") {
    return new Ok(new $gose.Mac(new $gose.Hmac(new $gose.HmacSha384())));
  } else if (alg === "HS512") {
    return new Ok(new $gose.Mac(new $gose.Hmac(new $gose.HmacSha512())));
  } else if (alg === "RS256") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.RsaPkcs1(new $gose.RsaPkcs1Sha256())),
    );
  } else if (alg === "RS384") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.RsaPkcs1(new $gose.RsaPkcs1Sha384())),
    );
  } else if (alg === "RS512") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.RsaPkcs1(new $gose.RsaPkcs1Sha512())),
    );
  } else if (alg === "PS256") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.RsaPss(new $gose.RsaPssSha256())),
    );
  } else if (alg === "PS384") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.RsaPss(new $gose.RsaPssSha384())),
    );
  } else if (alg === "PS512") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.RsaPss(new $gose.RsaPssSha512())),
    );
  } else if (alg === "ES256") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.Ecdsa(new $gose.EcdsaP256())),
    );
  } else if (alg === "ES384") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.Ecdsa(new $gose.EcdsaP384())),
    );
  } else if (alg === "ES512") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.Ecdsa(new $gose.EcdsaP521())),
    );
  } else if (alg === "ES256K") {
    return new Ok(
      new $gose.DigitalSignature(new $gose.Ecdsa(new $gose.EcdsaSecp256k1())),
    );
  } else if (alg === "EdDSA") {
    return new Ok(new $gose.DigitalSignature(new $gose.Eddsa()));
  } else {
    return new Error(new $gose.ParseError("unknown JWS algorithm: " + alg));
  }
}

/**
 * Convert a key encryption algorithm to its JOSE string representation.
 */
export function key_encryption_alg_to_string(alg) {
  if (alg instanceof $gose.Direct) {
    return "dir";
  } else if (alg instanceof $gose.AesKeyWrap) {
    let $ = alg[0];
    if ($ instanceof $gose.AesKw) {
      let $1 = alg[1];
      if ($1 instanceof $gose.Aes128) {
        return "A128KW";
      } else if ($1 instanceof $gose.Aes192) {
        return "A192KW";
      } else {
        return "A256KW";
      }
    } else {
      let $1 = alg[1];
      if ($1 instanceof $gose.Aes128) {
        return "A128GCMKW";
      } else if ($1 instanceof $gose.Aes192) {
        return "A192GCMKW";
      } else {
        return "A256GCMKW";
      }
    }
  } else if (alg instanceof $gose.ChaCha20KeyWrap) {
    let $ = alg[0];
    if ($ instanceof $gose.C20PKw) {
      return "C20PKW";
    } else {
      return "XC20PKW";
    }
  } else if (alg instanceof $gose.RsaEncryption) {
    let $ = alg[0];
    if ($ instanceof $gose.RsaPkcs1v15) {
      return "RSA1_5";
    } else if ($ instanceof $gose.RsaOaepSha1) {
      return "RSA-OAEP";
    } else {
      return "RSA-OAEP-256";
    }
  } else if (alg instanceof $gose.EcdhEs) {
    let $ = alg[0];
    if ($ instanceof $gose.EcdhEsDirect) {
      return "ECDH-ES";
    } else if ($ instanceof $gose.EcdhEsAesKw) {
      let $1 = $[0];
      if ($1 instanceof $gose.Aes128) {
        return "ECDH-ES+A128KW";
      } else if ($1 instanceof $gose.Aes192) {
        return "ECDH-ES+A192KW";
      } else {
        return "ECDH-ES+A256KW";
      }
    } else {
      let $1 = $[0];
      if ($1 instanceof $gose.C20PKw) {
        return "ECDH-ES+C20PKW";
      } else {
        return "ECDH-ES+XC20PKW";
      }
    }
  } else {
    let $ = alg[0];
    if ($ instanceof $gose.Pbes2Sha256Aes128Kw) {
      return "PBES2-HS256+A128KW";
    } else if ($ instanceof $gose.Pbes2Sha384Aes192Kw) {
      return "PBES2-HS384+A192KW";
    } else {
      return "PBES2-HS512+A256KW";
    }
  }
}

/**
 * Parse a key encryption algorithm from its JOSE string representation.
 */
export function key_encryption_alg_from_string(alg) {
  if (alg === "dir") {
    return new Ok(new $gose.Direct());
  } else if (alg === "A128KW") {
    return new Ok(new $gose.AesKeyWrap(new $gose.AesKw(), new $gose.Aes128()));
  } else if (alg === "A192KW") {
    return new Ok(new $gose.AesKeyWrap(new $gose.AesKw(), new $gose.Aes192()));
  } else if (alg === "A256KW") {
    return new Ok(new $gose.AesKeyWrap(new $gose.AesKw(), new $gose.Aes256()));
  } else if (alg === "A128GCMKW") {
    return new Ok(
      new $gose.AesKeyWrap(new $gose.AesGcmKw(), new $gose.Aes128()),
    );
  } else if (alg === "A192GCMKW") {
    return new Ok(
      new $gose.AesKeyWrap(new $gose.AesGcmKw(), new $gose.Aes192()),
    );
  } else if (alg === "A256GCMKW") {
    return new Ok(
      new $gose.AesKeyWrap(new $gose.AesGcmKw(), new $gose.Aes256()),
    );
  } else if (alg === "RSA1_5") {
    return new Ok(new $gose.RsaEncryption(new $gose.RsaPkcs1v15()));
  } else if (alg === "RSA-OAEP") {
    return new Ok(new $gose.RsaEncryption(new $gose.RsaOaepSha1()));
  } else if (alg === "RSA-OAEP-256") {
    return new Ok(new $gose.RsaEncryption(new $gose.RsaOaepSha256()));
  } else if (alg === "ECDH-ES") {
    return new Ok(new $gose.EcdhEs(new $gose.EcdhEsDirect()));
  } else if (alg === "ECDH-ES+A128KW") {
    return new Ok(new $gose.EcdhEs(new $gose.EcdhEsAesKw(new $gose.Aes128())));
  } else if (alg === "ECDH-ES+A192KW") {
    return new Ok(new $gose.EcdhEs(new $gose.EcdhEsAesKw(new $gose.Aes192())));
  } else if (alg === "ECDH-ES+A256KW") {
    return new Ok(new $gose.EcdhEs(new $gose.EcdhEsAesKw(new $gose.Aes256())));
  } else if (alg === "ECDH-ES+C20PKW") {
    return new Ok(
      new $gose.EcdhEs(new $gose.EcdhEsChaCha20Kw(new $gose.C20PKw())),
    );
  } else if (alg === "ECDH-ES+XC20PKW") {
    return new Ok(
      new $gose.EcdhEs(new $gose.EcdhEsChaCha20Kw(new $gose.XC20PKw())),
    );
  } else if (alg === "C20PKW") {
    return new Ok(new $gose.ChaCha20KeyWrap(new $gose.C20PKw()));
  } else if (alg === "XC20PKW") {
    return new Ok(new $gose.ChaCha20KeyWrap(new $gose.XC20PKw()));
  } else if (alg === "PBES2-HS256+A128KW") {
    return new Ok(new $gose.Pbes2(new $gose.Pbes2Sha256Aes128Kw()));
  } else if (alg === "PBES2-HS384+A192KW") {
    return new Ok(new $gose.Pbes2(new $gose.Pbes2Sha384Aes192Kw()));
  } else if (alg === "PBES2-HS512+A256KW") {
    return new Ok(new $gose.Pbes2(new $gose.Pbes2Sha512Aes256Kw()));
  } else {
    return new Error(new $gose.ParseError("unknown JWE algorithm: " + alg));
  }
}

/**
 * Convert a content encryption algorithm to its JOSE string representation.
 */
export function content_alg_to_string(alg) {
  if (alg instanceof $gose.AesGcm) {
    let $ = alg[0];
    if ($ instanceof $gose.Aes128) {
      return "A128GCM";
    } else if ($ instanceof $gose.Aes192) {
      return "A192GCM";
    } else {
      return "A256GCM";
    }
  } else if (alg instanceof $gose.AesCbcHmac) {
    let $ = alg[0];
    if ($ instanceof $gose.Aes128) {
      return "A128CBC-HS256";
    } else if ($ instanceof $gose.Aes192) {
      return "A192CBC-HS384";
    } else {
      return "A256CBC-HS512";
    }
  } else if (alg instanceof $gose.ChaCha20Poly1305) {
    return "C20P";
  } else {
    return "XC20P";
  }
}

/**
 * Parse a content encryption algorithm from its JOSE string representation.
 */
export function content_alg_from_string(alg) {
  if (alg === "A128GCM") {
    return new Ok(new $gose.AesGcm(new $gose.Aes128()));
  } else if (alg === "A192GCM") {
    return new Ok(new $gose.AesGcm(new $gose.Aes192()));
  } else if (alg === "A256GCM") {
    return new Ok(new $gose.AesGcm(new $gose.Aes256()));
  } else if (alg === "A128CBC-HS256") {
    return new Ok(new $gose.AesCbcHmac(new $gose.Aes128()));
  } else if (alg === "A192CBC-HS384") {
    return new Ok(new $gose.AesCbcHmac(new $gose.Aes192()));
  } else if (alg === "A256CBC-HS512") {
    return new Ok(new $gose.AesCbcHmac(new $gose.Aes256()));
  } else if (alg === "C20P") {
    return new Ok(new $gose.ChaCha20Poly1305());
  } else if (alg === "XC20P") {
    return new Ok(new $gose.XChaCha20Poly1305());
  } else {
    return new Error(
      new $gose.ParseError("unknown content encryption algorithm: " + alg),
    );
  }
}
