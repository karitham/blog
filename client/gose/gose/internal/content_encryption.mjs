import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $aead from "../../../kryptos/kryptos/aead.mjs";
import * as $block from "../../../kryptos/kryptos/block.mjs";
import * as $crypto from "../../../kryptos/kryptos/crypto.mjs";
import * as $hash from "../../../kryptos/kryptos/hash.mjs";
import { Ok, Error, toList, toBitArray, bitArraySlice, sizedInt, stringBits } from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $utils from "../../gose/internal/utils.mjs";

export function iv_size(enc) {
  if (enc instanceof $gose.AesGcm) {
    return 12;
  } else if (enc instanceof $gose.AesCbcHmac) {
    return 16;
  } else if (enc instanceof $gose.ChaCha20Poly1305) {
    return 12;
  } else {
    return 24;
  }
}

export function tag_size(enc) {
  if (enc instanceof $gose.AesGcm) {
    return 16;
  } else if (enc instanceof $gose.AesCbcHmac) {
    let size = enc[0];
    return $gose.aes_key_size(size);
  } else if (enc instanceof $gose.ChaCha20Poly1305) {
    return 16;
  } else {
    return 16;
  }
}

export function validate_iv_tag_sizes(enc, iv, tag) {
  let expected_iv = iv_size(enc);
  let actual_iv = $bit_array.byte_size(iv);
  return $bool.guard(
    actual_iv !== expected_iv,
    new Error(
      new $gose.ParseError(
        (("invalid IV length: expected " + $int.to_string(expected_iv)) + " bytes, got ") + $int.to_string(
          actual_iv,
        ),
      ),
    ),
    () => {
      let expected_tag = tag_size(enc);
      let actual_tag = $bit_array.byte_size(tag);
      return $bool.guard(
        actual_tag !== expected_tag,
        new Error(
          new $gose.ParseError(
            (("invalid tag length: expected " + $int.to_string(expected_tag)) + " bytes, got ") + $int.to_string(
              actual_tag,
            ),
          ),
        ),
        () => { return new Ok(undefined); },
      );
    },
  );
}

export function generate_cek(enc) {
  return $crypto.random_bytes($gose.content_alg_key_size(enc));
}

export function generate_iv(enc) {
  return $crypto.random_bytes(iv_size(enc));
}

export function build_jwe_aad(protected_b64, user_aad) {
  if (user_aad instanceof $option.Some) {
    let aad = user_aad[0];
    let aad_b64 = $utils.encode_base64_url(aad);
    return $bit_array.concat(
      toList([
        $bit_array.from_string(protected_b64),
        toBitArray([stringBits(".")]),
        $bit_array.from_string(aad_b64),
      ]),
    );
  } else {
    return $bit_array.from_string(protected_b64);
  }
}

export function aes_block_for_size(size) {
  if (size instanceof $gose.Aes128) {
    return $block.aes_128;
  } else if (size instanceof $gose.Aes192) {
    return $block.aes_192;
  } else {
    return $block.aes_256;
  }
}

export function hash_for_aes_size(size) {
  if (size instanceof $gose.Aes128) {
    return new $hash.Sha256();
  } else if (size instanceof $gose.Aes192) {
    return new $hash.Sha384();
  } else {
    return new $hash.Sha512();
  }
}

function encrypt_chacha20_variant(
  cek,
  iv,
  aad,
  plaintext,
  cipher_fn,
  variant_name
) {
  return $result.try$(
    (() => {
      let _pipe = cipher_fn(cek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("invalid key size for " + variant_name),
      );
    })(),
    (ctx) => {
      let _pipe = $aead.seal_with_aad(ctx, iv, plaintext, aad);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError(variant_name + " encryption failed"),
      );
    },
  );
}

export function aes_cipher(size, key) {
  let _pipe = aes_block_for_size(size)(key);
  return $result.replace_error(
    _pipe,
    new $gose.CryptoError("failed to create AES cipher"),
  );
}

function split_cek(cek, key_size) {
  if (
    key_size * 8 >= 0 &&
    cek.bitSize >= key_size * 8 &&
    cek.bitSize === key_size * 16
  ) {
    let mk = bitArraySlice(cek, 0, key_size * 8);
    let ek = bitArraySlice(cek, key_size * 8, key_size * 8 + key_size * 8);
    return new Ok([mk, ek]);
  } else {
    return new Error(
      new $gose.CryptoError(
        (("invalid CEK size for AES-CBC-HMAC: expected " + $int.to_string(
          key_size * 2,
        )) + " bytes, got ") + $int.to_string($bit_array.byte_size(cek)),
      ),
    );
  }
}

function encrypt_aes_cbc_hmac(cek, iv, aad, plaintext, hash_alg, size) {
  let half = $gose.aes_key_size(size);
  return $result.try$(
    split_cek(cek, half),
    (_use0) => {
      let mac_key = _use0[0];
      let enc_key = _use0[1];
      return $result.try$(
        aes_cipher(size, enc_key),
        (cipher) => {
          return $result.try$(
            (() => {
              let _pipe = $block.cbc(cipher, iv);
              return $result.replace_error(
                _pipe,
                new $gose.CryptoError("invalid IV for AES-CBC"),
              );
            })(),
            (ctx) => {
              return $result.try$(
                (() => {
                  let _pipe = $block.encrypt(ctx, plaintext);
                  return $result.replace_error(
                    _pipe,
                    new $gose.CryptoError("AES-CBC encryption failed"),
                  );
                })(),
                (ciphertext) => {
                  let aad_len = $bit_array.byte_size(aad);
                  let al = toBitArray([sizedInt(aad_len * 8, 64, true)]);
                  let mac_input = $bit_array.concat(
                    toList([aad, iv, ciphertext, al]),
                  );
                  return $result.try$(
                    (() => {
                      let _pipe = $crypto.hmac(hash_alg, mac_key, mac_input);
                      return $result.replace_error(
                        _pipe,
                        new $gose.CryptoError("HMAC computation failed"),
                      );
                    })(),
                    (full_mac) => {
                      let tag_size$1 = globalThis.Math.trunc(
                        $bit_array.byte_size(full_mac) / 2
                      );
                      let $ = $bit_array.slice(full_mac, 0, tag_size$1);
                      if ($ instanceof Ok) {
                        let tag = $[0];
                        return new Ok([ciphertext, tag]);
                      } else {
                        return new Error(
                          new $gose.CryptoError("tag extraction failed"),
                        );
                      }
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

function encrypt_aes_gcm(cek, iv, aad, plaintext, cipher_fn) {
  return $result.try$(
    (() => {
      let _pipe = cipher_fn(cek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("invalid CEK size for AES-GCM"),
      );
    })(),
    (cipher) => {
      let ctx = $aead.gcm(cipher);
      let _pipe = $aead.seal_with_aad(ctx, iv, plaintext, aad);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("AES-GCM encryption failed"),
      );
    },
  );
}

export function encrypt_content(enc, cek, iv, aad, plaintext) {
  if (enc instanceof $gose.AesGcm) {
    let size = enc[0];
    return encrypt_aes_gcm(cek, iv, aad, plaintext, aes_block_for_size(size));
  } else if (enc instanceof $gose.AesCbcHmac) {
    let size = enc[0];
    return encrypt_aes_cbc_hmac(
      cek,
      iv,
      aad,
      plaintext,
      hash_for_aes_size(size),
      size,
    );
  } else if (enc instanceof $gose.ChaCha20Poly1305) {
    return encrypt_chacha20_variant(
      cek,
      iv,
      aad,
      plaintext,
      $aead.chacha20_poly1305,
      "ChaCha20-Poly1305",
    );
  } else {
    return encrypt_chacha20_variant(
      cek,
      iv,
      aad,
      plaintext,
      $aead.xchacha20_poly1305,
      "XChaCha20-Poly1305",
    );
  }
}

function decrypt_chacha20_variant(
  cek,
  iv,
  aad,
  ciphertext,
  tag,
  cipher_fn,
  variant_name
) {
  return $result.try$(
    (() => {
      let _pipe = cipher_fn(cek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("invalid key size for " + variant_name),
      );
    })(),
    (ctx) => {
      let _pipe = $aead.open_with_aad(ctx, iv, tag, ciphertext, aad);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError(variant_name + " decryption failed"),
      );
    },
  );
}

function decrypt_aes_cbc_hmac(cek, iv, aad, ciphertext, tag, hash_alg, size) {
  let half = $gose.aes_key_size(size);
  return $result.try$(
    split_cek(cek, half),
    (_use0) => {
      let mac_key = _use0[0];
      let enc_key = _use0[1];
      let aad_len = $bit_array.byte_size(aad);
      let al = toBitArray([sizedInt(aad_len * 8, 64, true)]);
      let mac_input = $bit_array.concat(toList([aad, iv, ciphertext, al]));
      return $result.try$(
        (() => {
          let _pipe = $crypto.hmac(hash_alg, mac_key, mac_input);
          return $result.replace_error(
            _pipe,
            new $gose.CryptoError("HMAC computation failed"),
          );
        })(),
        (full_mac) => {
          let tag_size$1 = globalThis.Math.trunc(
            $bit_array.byte_size(full_mac) / 2
          );
          return $result.try$(
            (() => {
              let _pipe = $bit_array.slice(full_mac, 0, tag_size$1);
              return $result.replace_error(
                _pipe,
                new $gose.CryptoError("tag extraction failed"),
              );
            })(),
            (expected_tag) => {
              return $bool.guard(
                !$crypto.constant_time_equal(tag, expected_tag),
                new Error(new $gose.CryptoError("authentication tag mismatch")),
                () => {
                  return $result.try$(
                    aes_cipher(size, enc_key),
                    (cipher) => {
                      let $ = $block.cbc(cipher, iv);
                      if ($ instanceof Ok) {
                        let ctx = $[0];
                        let _pipe = $block.decrypt(ctx, ciphertext);
                        return $result.replace_error(
                          _pipe,
                          new $gose.CryptoError("AES-CBC decryption failed"),
                        );
                      } else {
                        return new Error(
                          new $gose.CryptoError("invalid IV for AES-CBC"),
                        );
                      }
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

function decrypt_aes_gcm(cek, iv, aad, ciphertext, tag, cipher_fn) {
  return $result.try$(
    (() => {
      let _pipe = cipher_fn(cek);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("invalid CEK size for AES-GCM"),
      );
    })(),
    (cipher) => {
      let ctx = $aead.gcm(cipher);
      let _pipe = $aead.open_with_aad(ctx, iv, tag, ciphertext, aad);
      return $result.replace_error(
        _pipe,
        new $gose.CryptoError("AES-GCM decryption failed"),
      );
    },
  );
}

export function decrypt_content(enc, cek, iv, aad, ciphertext, tag) {
  if (enc instanceof $gose.AesGcm) {
    let size = enc[0];
    return decrypt_aes_gcm(
      cek,
      iv,
      aad,
      ciphertext,
      tag,
      aes_block_for_size(size),
    );
  } else if (enc instanceof $gose.AesCbcHmac) {
    let size = enc[0];
    return decrypt_aes_cbc_hmac(
      cek,
      iv,
      aad,
      ciphertext,
      tag,
      hash_for_aes_size(size),
      size,
    );
  } else if (enc instanceof $gose.ChaCha20Poly1305) {
    return decrypt_chacha20_variant(
      cek,
      iv,
      aad,
      ciphertext,
      tag,
      $aead.chacha20_poly1305,
      "ChaCha20-Poly1305",
    );
  } else {
    return decrypt_chacha20_variant(
      cek,
      iv,
      aad,
      ciphertext,
      tag,
      $aead.xchacha20_poly1305,
      "XChaCha20-Poly1305",
    );
  }
}
