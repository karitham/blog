import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $aead from "../../../kryptos/kryptos/aead.mjs";
import * as $block from "../../../kryptos/kryptos/block.mjs";
import * as $crypto from "../../../kryptos/kryptos/crypto.mjs";
import * as $ec from "../../../kryptos/kryptos/ec.mjs";
import * as $ecdh from "../../../kryptos/kryptos/ecdh.mjs";
import * as $hash from "../../../kryptos/kryptos/hash.mjs";
import * as $rsa from "../../../kryptos/kryptos/rsa.mjs";
import * as $xdh from "../../../kryptos/kryptos/xdh.mjs";
import {
  Ok,
  Error,
  toList,
  CustomType as $CustomType,
  isEqual,
  toBitArray,
  sizedInt,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $content_encryption from "../../gose/internal/content_encryption.mjs";
import * as $key_extract from "../../gose/internal/key_extract.mjs";

export class EcEphemeralKey extends $CustomType {
  constructor(curve, x, y) {
    super();
    this.curve = curve;
    this.x = x;
    this.y = y;
  }
}
export const EphemeralPublicKey$EcEphemeralKey = (curve, x, y) =>
  new EcEphemeralKey(curve, x, y);
export const EphemeralPublicKey$isEcEphemeralKey = (value) =>
  value instanceof EcEphemeralKey;
export const EphemeralPublicKey$EcEphemeralKey$curve = (value) => value.curve;
export const EphemeralPublicKey$EcEphemeralKey$0 = (value) => value.curve;
export const EphemeralPublicKey$EcEphemeralKey$x = (value) => value.x;
export const EphemeralPublicKey$EcEphemeralKey$1 = (value) => value.x;
export const EphemeralPublicKey$EcEphemeralKey$y = (value) => value.y;
export const EphemeralPublicKey$EcEphemeralKey$2 = (value) => value.y;

export class XdhEphemeralKey extends $CustomType {
  constructor(curve, x) {
    super();
    this.curve = curve;
    this.x = x;
  }
}
export const EphemeralPublicKey$XdhEphemeralKey = (curve, x) =>
  new XdhEphemeralKey(curve, x);
export const EphemeralPublicKey$isXdhEphemeralKey = (value) =>
  value instanceof XdhEphemeralKey;
export const EphemeralPublicKey$XdhEphemeralKey$curve = (value) => value.curve;
export const EphemeralPublicKey$XdhEphemeralKey$0 = (value) => value.curve;
export const EphemeralPublicKey$XdhEphemeralKey$x = (value) => value.x;
export const EphemeralPublicKey$XdhEphemeralKey$1 = (value) => value.x;

export const EphemeralPublicKey$x = (value) => value.x;

export function get_octet_key(key, expected_size) {
  return $result.try$(
    (() => {
      let _pipe = $gose.material_octet_secret($gose.material(key));
      return $result.replace_error(
        _pipe,
        new $gose.InvalidState("expected octet key"),
      );
    })(),
    (secret) => {
      let actual_size = $bit_array.byte_size(secret);
      return $bool.guard(
        actual_size !== expected_size,
        new Error(
          new $gose.InvalidState(
            (("expected " + $int.to_string(expected_size)) + "-byte key, got ") + $int.to_string(
              actual_size,
            ),
          ),
        ),
        () => { return new Ok(secret); },
      );
    },
  );
}

export function wrap_aes_kw(key, cek, size) {
  return $result.try$(
    get_octet_key(key, $gose.aes_key_size(size)),
    (secret) => {
      return $result.try$(
        $content_encryption.aes_cipher(size, secret),
        (cipher) => {
          let _pipe = $block.wrap(cipher, cek);
          return $result.replace_error(
            _pipe,
            new $gose.CryptoError("AES Key Wrap failed"),
          );
        },
      );
    },
  );
}

export function unwrap_aes_kw(key, encrypted_key, size) {
  return $result.try$(
    get_octet_key(key, $gose.aes_key_size(size)),
    (secret) => {
      return $result.try$(
        $content_encryption.aes_cipher(size, secret),
        (cipher) => {
          let _pipe = $block.unwrap(cipher, encrypted_key);
          return $result.replace_error(
            _pipe,
            new $gose.CryptoError("AES Key Unwrap failed"),
          );
        },
      );
    },
  );
}

export function wrap_aes_gcm(kek, cek, iv, size) {
  return $result.try$(
    $content_encryption.aes_cipher(size, kek),
    (cipher) => {
      let ctx = $aead.gcm(cipher);
      let _pipe = $aead.seal(ctx, iv, cek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("AES-GCM Key Wrap failed"),
      );
    },
  );
}

export function unwrap_aes_gcm(kek, encrypted_cek, iv, tag, size) {
  return $result.try$(
    $content_encryption.aes_cipher(size, kek),
    (cipher) => {
      let ctx = $aead.gcm(cipher);
      let _pipe = $aead.open(ctx, iv, tag, encrypted_cek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("AES-GCM Key Unwrap failed"),
      );
    },
  );
}

export function unwrap_aes_gcm_kw(key, encrypted_cek, size, kw_iv, kw_tag) {
  return $result.try$(
    $option.to_result(
      kw_iv,
      new $gose.ParseError("missing iv header for AES-GCM Key Wrap"),
    ),
    (iv) => {
      return $result.try$(
        $option.to_result(
          kw_tag,
          new $gose.ParseError("missing tag header for AES-GCM Key Wrap"),
        ),
        (tag) => {
          return $result.try$(
            get_octet_key(key, $gose.aes_key_size(size)),
            (kek) => {
              return unwrap_aes_gcm(kek, encrypted_cek, iv, tag, size);
            },
          );
        },
      );
    },
  );
}

function chacha20_variant_params(variant) {
  if (variant instanceof $gose.C20PKw) {
    return [$aead.chacha20_poly1305, "ChaCha20-Poly1305"];
  } else {
    return [$aead.xchacha20_poly1305, "XChaCha20-Poly1305"];
  }
}

function wrap_chacha20_variant(kek, cek, nonce, cipher_fn, variant_name) {
  return $result.try$(
    (() => {
      let _pipe = cipher_fn(kek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError(
          ("invalid key size for " + variant_name) + " Key Wrap",
        ),
      );
    })(),
    (ctx) => {
      let _pipe = $aead.seal(ctx, nonce, cek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError(variant_name + " Key Wrap failed"),
      );
    },
  );
}

function unwrap_chacha20_variant(
  kek,
  encrypted_cek,
  nonce,
  tag,
  cipher_fn,
  variant_name
) {
  return $result.try$(
    (() => {
      let _pipe = cipher_fn(kek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError(
          ("invalid key size for " + variant_name) + " Key Unwrap",
        ),
      );
    })(),
    (ctx) => {
      let _pipe = $aead.open(ctx, nonce, tag, encrypted_cek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError(variant_name + " Key Unwrap failed"),
      );
    },
  );
}

export function wrap_chacha20_by_variant(kek, cek, nonce, variant) {
  let $ = chacha20_variant_params(variant);
  let cipher_fn = $[0];
  let variant_name = $[1];
  return wrap_chacha20_variant(kek, cek, nonce, cipher_fn, variant_name);
}

export function unwrap_chacha20_by_variant(
  kek,
  encrypted_cek,
  nonce,
  tag,
  variant
) {
  let $ = chacha20_variant_params(variant);
  let cipher_fn = $[0];
  let variant_name = $[1];
  return unwrap_chacha20_variant(
    kek,
    encrypted_cek,
    nonce,
    tag,
    cipher_fn,
    variant_name,
  );
}

export function unwrap_chacha20_kw(key, encrypted_cek, variant, kw_iv, kw_tag) {
  return $result.try$(
    $option.to_result(
      kw_iv,
      new $gose.ParseError("missing iv header for ChaCha20 Key Wrap"),
    ),
    (iv) => {
      return $result.try$(
        $option.to_result(
          kw_tag,
          new $gose.ParseError("missing tag header for ChaCha20 Key Wrap"),
        ),
        (tag) => {
          return $result.try$(
            get_octet_key(key, 32),
            (kek) => {
              return unwrap_chacha20_by_variant(
                kek,
                encrypted_cek,
                iv,
                tag,
                variant,
              );
            },
          );
        },
      );
    },
  );
}

export function derive_ecdh_key(secret, alg_id, apu, apv, length) {
  let alg_bits = $bit_array.from_string(alg_id);
  let alg_len = $bit_array.byte_size(alg_bits);
  let algorithm_id = toBitArray([sizedInt(alg_len, 32, true), alg_bits]);
  let apu_bits = $option.unwrap(apu, toBitArray([]));
  let apu_len = $bit_array.byte_size(apu_bits);
  let party_u_info = toBitArray([sizedInt(apu_len, 32, true), apu_bits]);
  let apv_bits = $option.unwrap(apv, toBitArray([]));
  let apv_len = $bit_array.byte_size(apv_bits);
  let party_v_info = toBitArray([sizedInt(apv_len, 32, true), apv_bits]);
  let supp_pub_info = toBitArray([sizedInt(length * 8, 32, true)]);
  let info = $bit_array.concat(
    toList([algorithm_id, party_u_info, party_v_info, supp_pub_info]),
  );
  let _pipe = $crypto.concat_kdf(new $hash.Sha256(), secret, info, length);
  return $result.replace_error(
    _pipe,
    new $gose.CryptoError("ECDH key derivation failed"),
  );
}

function compute_xdh_shared_secret(mat) {
  return $result.try$(
    $gose.material_xdh(mat),
    (xdh_mat) => {
      let _block;
      if (xdh_mat instanceof $gose.XdhPrivate) {
        let public$ = xdh_mat.public;
        let curve = xdh_mat.curve;
        _block = [public$, curve];
      } else {
        let public$ = xdh_mat.key;
        let curve = xdh_mat.curve;
        _block = [public$, curve];
      }
      let $ = _block;
      let peer_public = $[0];
      let curve = $[1];
      let $1 = $xdh.generate_key_pair(curve);
      let ephemeral_private = $1[0];
      let ephemeral_public = $1[1];
      return $result.try$(
        (() => {
          let _pipe = $xdh.compute_shared_secret(ephemeral_private, peer_public);
          return $result.replace_error(
            _pipe,
            new $gose.CryptoError("XDH key agreement failed"),
          );
        })(),
        (shared) => {
          let x = $xdh.public_key_to_bytes(ephemeral_public);
          return new Ok([shared, new XdhEphemeralKey(curve, x)]);
        },
      );
    },
  );
}

function compute_ec_shared_secret(mat) {
  return $result.try$(
    $gose.material_ec(mat),
    (ec_mat) => {
      let _block;
      if (ec_mat instanceof $gose.EcPrivate) {
        let public$ = ec_mat.public;
        let curve = ec_mat.curve;
        _block = [public$, curve];
      } else {
        let public$ = ec_mat.key;
        let curve = ec_mat.curve;
        _block = [public$, curve];
      }
      let $ = _block;
      let peer_public = $[0];
      let curve = $[1];
      let $1 = $ec.generate_key_pair(curve);
      let ephemeral_private = $1[0];
      let ephemeral_public = $1[1];
      return $result.try$(
        (() => {
          let _pipe = $ecdh.compute_shared_secret(
            ephemeral_private,
            peer_public,
          );
          return $result.replace_error(
            _pipe,
            new $gose.CryptoError("ECDH key agreement failed"),
          );
        })(),
        (shared) => {
          let _pipe = $gose.ec_raw_coordinates(ephemeral_public, curve);
          return $result.map(
            _pipe,
            (coords) => {
              let x = coords[0];
              let y = coords[1];
              return [shared, new EcEphemeralKey(curve, x, y)];
            },
          );
        },
      );
    },
  );
}

export function compute_ecdh_shared_secret(key) {
  let mat = $gose.material(key);
  let _pipe = compute_ec_shared_secret(mat);
  let _pipe$1 = $result.lazy_or(
    _pipe,
    () => { return compute_xdh_shared_secret(mat); },
  );
  return $result.replace_error(
    _pipe$1,
    new $gose.InvalidState("ECDH-ES requires an EC or XDH key"),
  );
}

export function wrap_ecdh_es_chacha20_kw(key, cek, variant, alg_id, apu, apv) {
  return $result.try$(
    compute_ecdh_shared_secret(key),
    (_use0) => {
      let shared_secret = _use0[0];
      let epk = _use0[1];
      return $result.try$(
        derive_ecdh_key(shared_secret, alg_id, apu, apv, 32),
        (kek) => {
          let nonce_size = $gose.chacha20_kw_nonce_size(variant);
          let nonce = $crypto.random_bytes(nonce_size);
          return $result.try$(
            wrap_chacha20_by_variant(kek, cek, nonce, variant),
            (_use0) => {
              let encrypted_cek = _use0[0];
              let kw_tag = _use0[1];
              return new Ok([encrypted_cek, epk, nonce, kw_tag]);
            },
          );
        },
      );
    },
  );
}

export function compute_ecdh_shared_secret_with_epk(key, epk) {
  let mat = $gose.material(key);
  if (epk instanceof EcEphemeralKey) {
    let epk_curve = epk.curve;
    let x = epk.x;
    let y = epk.y;
    let key_error = new $gose.InvalidState(
      "key type does not match ephemeral key type",
    );
    return $result.try$(
      (() => {
        let _pipe = $gose.material_ec(mat);
        return $result.replace_error(_pipe, key_error);
      })(),
      (ec_mat) => {
        if (ec_mat instanceof $gose.EcPrivate) {
          let private$ = ec_mat.key;
          let curve = ec_mat.curve;
          return $bool.guard(
            !isEqual(curve, epk_curve),
            new Error(new $gose.InvalidState("ephemeral key curve mismatch")),
            () => {
              return $result.try$(
                $gose.ec_public_key_from_raw_coordinates(curve, x, y),
                (epk_public) => {
                  let _pipe = $ecdh.compute_shared_secret(private$, epk_public);
                  return $result.replace_error(
                    _pipe,
                    new $gose.CryptoError("ECDH key agreement failed"),
                  );
                },
              );
            },
          );
        } else {
          return new Error(key_error);
        }
      },
    );
  } else {
    let epk_curve = epk.curve;
    let x = epk.x;
    let key_error = new $gose.InvalidState(
      "key type does not match ephemeral key type",
    );
    return $result.try$(
      (() => {
        let _pipe = $gose.material_xdh(mat);
        return $result.replace_error(_pipe, key_error);
      })(),
      (xdh_mat) => {
        if (xdh_mat instanceof $gose.XdhPrivate) {
          let private$ = xdh_mat.key;
          let curve = xdh_mat.curve;
          return $bool.guard(
            !isEqual(curve, epk_curve),
            new Error(new $gose.InvalidState("ephemeral key curve mismatch")),
            () => {
              return $result.try$(
                (() => {
                  let _pipe = $xdh.public_key_from_bytes(curve, x);
                  return $result.replace_error(
                    _pipe,
                    new $gose.ParseError("invalid ephemeral public key"),
                  );
                })(),
                (epk_public) => {
                  let _pipe = $xdh.compute_shared_secret(private$, epk_public);
                  return $result.replace_error(
                    _pipe,
                    new $gose.CryptoError("XDH key agreement failed"),
                  );
                },
              );
            },
          );
        } else {
          return new Error(key_error);
        }
      },
    );
  }
}

export function unwrap_ecdh_es_chacha20_kw(
  key,
  encrypted_key,
  variant,
  alg_id,
  epk,
  apu,
  apv,
  kw_iv,
  kw_tag
) {
  return $result.try$(
    compute_ecdh_shared_secret_with_epk(key, epk),
    (shared_secret) => {
      return $result.try$(
        derive_ecdh_key(shared_secret, alg_id, apu, apv, 32),
        (kek) => {
          return unwrap_chacha20_by_variant(
            kek,
            encrypted_key,
            kw_iv,
            kw_tag,
            variant,
          );
        },
      );
    },
  );
}

export function wrap_rsa_oaep(key, cek, hash_alg) {
  return $result.try$(
    (() => {
      let _pipe = $key_extract.rsa_public_key($gose.material(key));
      return $result.replace_error(
        _pipe,
        new $gose.InvalidState("RSA encryption requires an RSA key"),
      );
    })(),
    (public$) => {
      let padding = new $rsa.Oaep(hash_alg, toBitArray([]));
      let _pipe = $rsa.encrypt(public$, cek, padding);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("RSA-OAEP encryption failed"),
      );
    },
  );
}

export function unwrap_rsa_oaep(key, encrypted_key, hash_alg) {
  return $result.try$(
    (() => {
      let _pipe = $key_extract.rsa_private_key($gose.material(key));
      return $result.replace_error(
        _pipe,
        new $gose.InvalidState("RSA decryption requires an RSA private key"),
      );
    })(),
    (private$) => {
      let padding = new $rsa.Oaep(hash_alg, toBitArray([]));
      let _pipe = $rsa.decrypt(private$, encrypted_key, padding);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("RSA-OAEP decryption failed"),
      );
    },
  );
}

export function wrap_rsa_pkcs1v15(key, cek) {
  return $result.try$(
    (() => {
      let _pipe = $key_extract.rsa_public_key($gose.material(key));
      return $result.replace_error(
        _pipe,
        new $gose.InvalidState("RSA encryption requires an RSA key"),
      );
    })(),
    (public$) => {
      let _pipe = $rsa.encrypt(public$, cek, new $rsa.EncryptPkcs1v15());
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("RSA PKCS1v15 encryption failed"),
      );
    },
  );
}

function validate_decrypted_size(decrypted, expected_size) {
  let $ = $bit_array.byte_size(decrypted) === expected_size;
  if ($) {
    return new Ok(decrypted);
  } else {
    return new Error(undefined);
  }
}

export function unwrap_rsa_pkcs1v15_safe(key, encrypted_key, enc) {
  return $result.try$(
    (() => {
      let _pipe = $key_extract.rsa_private_key($gose.material(key));
      return $result.replace_error(
        _pipe,
        new $gose.InvalidState("RSA decryption requires an RSA private key"),
      );
    })(),
    (private$) => {
      let expected_size = $gose.content_alg_key_size(enc);
      let random_cek = $content_encryption.generate_cek(enc);
      let _block;
      let _pipe = $rsa.decrypt(
        private$,
        encrypted_key,
        new $rsa.EncryptPkcs1v15(),
      );
      let _pipe$1 = $result.try$(
        _pipe,
        (_capture) => {
          return validate_decrypted_size(_capture, expected_size);
        },
      );
      _block = $result.unwrap(_pipe$1, random_cek);
      let cek = _block;
      return new Ok(cek);
    },
  );
}

export function unwrap_direct(key, enc) {
  return $result.try$(
    (() => {
      let _pipe = $gose.material_octet_secret($gose.material(key));
      return $result.replace_error(
        _pipe,
        new $gose.InvalidState("direct encryption requires an octet key"),
      );
    })(),
    (secret) => {
      let expected_size = $gose.content_alg_key_size(enc);
      let actual_size = $bit_array.byte_size(secret);
      let $ = actual_size === expected_size;
      if ($) {
        return new Ok(secret);
      } else {
        return new Error(
          new $gose.InvalidState(
            (((("direct encryption requires " + $int.to_string(expected_size)) + "-byte key for ") + $string.inspect(
              enc,
            )) + ", got ") + $int.to_string(actual_size),
          ),
        );
      }
    },
  );
}

export function wrap_ecdh_es_direct(key, enc, alg_id, apu, apv) {
  let key_len = $gose.content_alg_key_size(enc);
  return $result.try$(
    compute_ecdh_shared_secret(key),
    (_use0) => {
      let shared_secret = _use0[0];
      let epk = _use0[1];
      let _pipe = derive_ecdh_key(shared_secret, alg_id, apu, apv, key_len);
      return $result.map(_pipe, (cek) => { return [cek, epk]; });
    },
  );
}

export function unwrap_ecdh_es_direct(key, enc, alg_id, epk, apu, apv) {
  let key_len = $gose.content_alg_key_size(enc);
  return $result.try$(
    compute_ecdh_shared_secret_with_epk(key, epk),
    (shared_secret) => {
      return derive_ecdh_key(shared_secret, alg_id, apu, apv, key_len);
    },
  );
}

export function wrap_ecdh_es_kw(key, cek, size, alg_id, apu, apv) {
  return $result.try$(
    compute_ecdh_shared_secret(key),
    (_use0) => {
      let shared_secret = _use0[0];
      let epk = _use0[1];
      let kw_key_len = $gose.aes_key_size(size);
      return $result.try$(
        derive_ecdh_key(shared_secret, alg_id, apu, apv, kw_key_len),
        (kek) => {
          return $result.try$(
            $content_encryption.aes_cipher(size, kek),
            (cipher) => {
              let _pipe = $block.wrap(cipher, cek);
              let _pipe$1 = $result.replace_error(
                _pipe,
                new $gose.CryptoError("AES Key Wrap failed"),
              );
              return $result.map(
                _pipe$1,
                (wrapped) => { return [wrapped, epk]; },
              );
            },
          );
        },
      );
    },
  );
}

export function unwrap_ecdh_es_kw(
  key,
  encrypted_key,
  size,
  alg_id,
  epk,
  apu,
  apv
) {
  return $result.try$(
    compute_ecdh_shared_secret_with_epk(key, epk),
    (shared_secret) => {
      let kw_key_len = $gose.aes_key_size(size);
      return $result.try$(
        derive_ecdh_key(shared_secret, alg_id, apu, apv, kw_key_len),
        (kek) => {
          return $result.try$(
            $content_encryption.aes_cipher(size, kek),
            (cipher) => {
              let _pipe = $block.unwrap(cipher, encrypted_key);
              return $result.replace_error(
                _pipe,
                new $gose.CryptoError("AES Key Unwrap failed"),
              );
            },
          );
        },
      );
    },
  );
}
