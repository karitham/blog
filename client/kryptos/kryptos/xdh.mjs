import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import { Ok, Error, CustomType as $CustomType, bitArraySlice } from "../gleam.mjs";
import {
  xdhGenerateKeyPair as generate_key_pair,
  xdhComputeSharedSecret as do_compute_shared_secret,
  xdhPrivateKeyFromBytes as from_bytes,
  xdhPrivateKeyToBytes as to_bytes,
  xdhPublicKeyFromBytes as public_key_from_bytes,
  xdhPublicKeyToBytes as public_key_to_bytes,
  xdhImportPrivateKeyPem as from_pem,
  xdhImportPrivateKeyDer as from_der,
  xdhExportPrivateKeyPem as do_to_pem,
  xdhExportPrivateKeyDer as to_der,
  xdhImportPublicKeyPem as public_key_from_pem,
  xdhImportPublicKeyDer as public_key_from_der,
  xdhExportPublicKeyPem as do_public_key_to_pem,
  xdhExportPublicKeyDer as public_key_to_der,
  xdhPublicKeyFromPrivate as public_key_from_private_key,
  xdhPrivateKeyCurve as curve,
  xdhPublicKeyCurve as public_key_curve,
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
  to_bytes,
  to_der,
};

/**
 * X25519 curve (Curve25519). 32-byte keys and shared secret.
 */
export class X25519 extends $CustomType {}
export const Curve$X25519$const = new X25519();
export const Curve$X25519 = () => Curve$X25519$const;
export const Curve$isX25519 = (value) => value instanceof X25519;

/**
 * X448 curve (Curve448). 56-byte keys and shared secret.
 */
export class X448 extends $CustomType {}
export const Curve$X448$const = new X448();
export const Curve$X448 = () => Curve$X448$const;
export const Curve$isX448 = (value) => value instanceof X448;

/**
 * Returns the key size in bytes for the given curve.
 */
export function key_size(curve) {
  if (curve instanceof X25519) {
    return 32;
  } else {
    return 56;
  }
}

function is_all_zeros(loop$bytes) {
  while (true) {
    let bytes = loop$bytes;
    if (bytes.bitSize === 0) {
      return true;
    } else if (
      bytes.bitSize >= 8 &&
      bytes.byteAt(0) === 0 &&
      bytes.bitSize % 8 === 0
    ) {
      let rest = bitArraySlice(bytes, 8);
      loop$bytes = rest;
    } else {
      return false;
    }
  }
}

/**
 * Computes a shared secret using XDH key agreement.
 *
 * Both parties compute the same shared secret by combining their private key
 * with the other party's public key.
 *
 * Returns `Error(Nil)` if the keys use different curves, the result is an
 * all-zero shared secret (low-order point attack), or another error occurs.
 *
 * The raw shared secret should be passed through a KDF (like HKDF) before
 * use as a symmetric key.
 */
export function compute_shared_secret(private_key, peer_public_key) {
  return $result.try$(
    do_compute_shared_secret(private_key, peer_public_key),
    (shared) => {
      let $ = is_all_zeros(shared);
      if ($) {
        return new Error(undefined);
      } else {
        return new Ok(shared);
      }
    },
  );
}

/**
 * Exports an XDH private key to PEM format.
 *
 * The key is exported in PKCS#8 format.
 */
export function to_pem(key) {
  let _pipe = do_to_pem(key);
  return $result.map(_pipe, (pem) => { return $string.trim_end(pem) + "\n"; });
}

/**
 * Exports an XDH public key to PEM format.
 *
 * The key is exported in SPKI format.
 */
export function public_key_to_pem(key) {
  let _pipe = do_public_key_to_pem(key);
  return $result.map(_pipe, (pem) => { return $string.trim_end(pem) + "\n"; });
}
