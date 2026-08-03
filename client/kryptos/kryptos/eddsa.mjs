import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import { CustomType as $CustomType } from "../gleam.mjs";
import {
  eddsaGenerateKeyPair as generate_key_pair,
  eddsaSign as sign,
  eddsaVerify as verify,
  eddsaPrivateKeyFromBytes as from_bytes,
  eddsaPrivateKeyToBytes as to_bytes,
  eddsaPublicKeyFromBytes as public_key_from_bytes,
  eddsaPublicKeyToBytes as public_key_to_bytes,
  eddsaImportPrivateKeyPem as from_pem,
  eddsaImportPrivateKeyDer as from_der,
  eddsaExportPrivateKeyPem as do_to_pem,
  eddsaExportPrivateKeyDer as to_der,
  eddsaImportPublicKeyPem as public_key_from_pem,
  eddsaImportPublicKeyDer as public_key_from_der,
  eddsaExportPublicKeyPem as do_public_key_to_pem,
  eddsaExportPublicKeyDer as public_key_to_der,
  eddsaPublicKeyFromPrivate as public_key_from_private_key,
  eddsaPrivateKeyCurve as curve,
  eddsaPublicKeyCurve as public_key_curve,
} from "../kryptos_ffi.mjs";

export {
  curve,
  from_bytes,
  from_der,
  from_pem,
  generate_key_pair,
  public_key_curve,
  public_key_from_bytes,
  public_key_from_der,
  public_key_from_pem,
  public_key_from_private_key,
  public_key_to_bytes,
  public_key_to_der,
  sign,
  to_bytes,
  to_der,
  verify,
};

/**
 * Ed25519 curve. 32-byte keys, 64-byte signatures.
 */
export class Ed25519 extends $CustomType {}
export const Curve$Ed25519$const = new Ed25519();
export const Curve$Ed25519 = () => Curve$Ed25519$const;
export const Curve$isEd25519 = (value) => value instanceof Ed25519;

/**
 * Ed448 curve. 57-byte keys, 114-byte signatures.
 */
export class Ed448 extends $CustomType {}
export const Curve$Ed448$const = new Ed448();
export const Curve$Ed448 = () => Curve$Ed448$const;
export const Curve$isEd448 = (value) => value instanceof Ed448;

/**
 * Returns the key size in bytes for the given curve.
 */
export function key_size(curve) {
  if (curve instanceof Ed25519) {
    return 32;
  } else {
    return 57;
  }
}

/**
 * Exports an EdDSA private key to PEM format.
 *
 * The key is exported in PKCS#8 format.
 */
export function to_pem(key) {
  let _pipe = do_to_pem(key);
  return $result.map(_pipe, (pem) => { return $string.trim_end(pem) + "\n"; });
}

/**
 * Exports an EdDSA public key to PEM format.
 *
 * The key is exported in SPKI format.
 */
export function public_key_to_pem(key) {
  let _pipe = do_public_key_to_pem(key);
  return $result.map(_pipe, (pem) => { return $string.trim_end(pem) + "\n"; });
}
