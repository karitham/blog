import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import { CustomType as $CustomType } from "../gleam.mjs";
import {
  ecGenerateKeyPair as generate_key_pair,
  ecImportPrivateKeyPem as from_pem,
  ecImportPrivateKeyDer as from_der,
  ecExportPrivateKeyPem as do_to_pem,
  ecExportPrivateKeyDer as to_der,
  ecImportPublicKeyPem as public_key_from_pem,
  ecImportPublicKeyDer as public_key_from_der,
  ecPublicKeyFromRawPoint as public_key_from_raw_point,
  ecPublicKeyToRawPoint as public_key_to_raw_point,
  ecExportPublicKeyPem as do_public_key_to_pem,
  ecExportPublicKeyDer as public_key_to_der,
  ecPublicKeyFromPrivate as public_key_from_private_key,
  ecPrivateKeyCurve as curve,
  ecPublicKeyCurve as public_key_curve,
  ecPrivateKeyToBytes as to_bytes,
  ecPrivateKeyFromBytes as from_bytes,
} from "../kryptos_ffi.mjs";

export {
  curve,
  from_bytes,
  from_der,
  from_pem,
  generate_key_pair,
  public_key_curve,
  public_key_from_der,
  public_key_from_pem,
  public_key_from_private_key,
  public_key_from_raw_point,
  public_key_to_der,
  public_key_to_raw_point,
  to_bytes,
  to_der,
};

/**
 * NIST P-256 curve (secp256r1, prime256v1). 256-bit key size.
 */
export class P256 extends $CustomType {}
export const Curve$P256$const = new P256();
export const Curve$P256 = () => Curve$P256$const;
export const Curve$isP256 = (value) => value instanceof P256;

/**
 * NIST P-384 curve (secp384r1). 384-bit key size.
 */
export class P384 extends $CustomType {}
export const Curve$P384$const = new P384();
export const Curve$P384 = () => Curve$P384$const;
export const Curve$isP384 = (value) => value instanceof P384;

/**
 * NIST P-521 curve (secp521r1). 521-bit key size.
 */
export class P521 extends $CustomType {}
export const Curve$P521$const = new P521();
export const Curve$P521 = () => Curve$P521$const;
export const Curve$isP521 = (value) => value instanceof P521;

/**
 * Koblitz curve used by Bitcoin and Ethereum. 256-bit key size.
 */
export class Secp256k1 extends $CustomType {}
export const Curve$Secp256k1$const = new Secp256k1();
export const Curve$Secp256k1 = () => Curve$Secp256k1$const;
export const Curve$isSecp256k1 = (value) => value instanceof Secp256k1;

/**
 * Returns the coordinate size in bytes for the given curve.
 *
 * This is the size of each coordinate (x or y) in an EC point.
 */
export function coordinate_size(curve) {
  if (curve instanceof P256) {
    return 32;
  } else if (curve instanceof P384) {
    return 48;
  } else if (curve instanceof P521) {
    return 66;
  } else {
    return 32;
  }
}

/**
 * Exports an EC private key to PEM format.
 *
 * The key is exported in PKCS#8 format.
 */
export function to_pem(key) {
  let _pipe = do_to_pem(key);
  return $result.map(_pipe, (pem) => { return $string.trim_end(pem) + "\n"; });
}

/**
 * Exports an EC public key to PEM format.
 *
 * The key is exported in SPKI format.
 */
export function public_key_to_pem(key) {
  let _pipe = do_public_key_to_pem(key);
  return $result.map(_pipe, (pem) => { return $string.trim_end(pem) + "\n"; });
}
