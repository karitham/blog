import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import {
  Ok,
  Error,
  toList,
  CustomType as $CustomType,
  toBitArray,
  bitArraySlice,
} from "../gleam.mjs";
import * as $block from "../kryptos/block.mjs";
import * as $hchacha20 from "../kryptos/internal/hchacha20.mjs";
import { aeadSeal as do_seal, aeadOpen as do_open } from "../kryptos_ffi.mjs";

/**
 * AES-GCM with the specified cipher and nonce size.
 * 
 * @ignore
 */
class Gcm extends $CustomType {
  constructor(cipher, nonce_size) {
    super();
    this.cipher = cipher;
    this.nonce_size = nonce_size;
  }
}

/**
 * AES-CCM with configurable nonce and tag sizes (RFC 3610).
 * 
 * @ignore
 */
class Ccm extends $CustomType {
  constructor(cipher, nonce_size, tag_size) {
    super();
    this.cipher = cipher;
    this.nonce_size = nonce_size;
    this.tag_size = tag_size;
  }
}

/**
 * ChaCha20-Poly1305 with a 256-bit key (RFC 8439).
 * 
 * @ignore
 */
class ChaCha20Poly1305 extends $CustomType {
  constructor(key) {
    super();
    this.key = key;
  }
}

/**
 * XChaCha20-Poly1305 with a 256-bit key and 24-byte nonce.
 * 
 * @ignore
 */
class XChaCha20Poly1305 extends $CustomType {
  constructor(key) {
    super();
    this.key = key;
  }
}

/**
 * Creates an AES-GCM context with the given block cipher.
 *
 * Uses standard parameters: 16-byte (128-bit) authentication tag and
 * 12-byte (96-bit) nonce.
 *
 * **Note:** This library only supports the full 16-byte authentication tag.
 * Truncated tags (as permitted by NIST SP 800-38D) are not supported due to
 * their reduced security guarantees.
 */
export function gcm(cipher) {
  return new Gcm(cipher, 12);
}

/**
 * Creates an AES-GCM context with a custom nonce size.
 *
 * GCM supports variable nonce sizes, though 12 bytes is strongly recommended.
 * This function is primarily useful for compatibility testing with test vectors.
 */
export function gcm_with_nonce_size(cipher, nonce_size) {
  let $ = (nonce_size >= 1) && (nonce_size <= 64);
  if ($) {
    return new Ok(new Gcm(cipher, nonce_size));
  } else {
    return new Error(undefined);
  }
}

/**
 * Creates an AES-CCM context with the given block cipher.
 *
 * Uses standard parameters: 16-byte (128-bit) authentication tag and
 * 13-byte (104-bit) nonce, which allows messages up to 64KB.
 */
export function ccm(cipher) {
  return new Ccm(cipher, 13, 16);
}

/**
 * Creates an AES-CCM context with custom nonce and tag sizes.
 *
 * CCM allows flexible nonce and tag sizes per RFC 3610:
 * - Nonce size affects maximum message length (larger nonce = smaller max message)
 * - Tag size affects authentication strength (larger tag = stronger)
 *
 * Nonce must be 7-13 bytes. Tag must be 4, 6, 8, 10, 12, 14, or 16 bytes.
 */
export function ccm_with_sizes(cipher, nonce_size, tag_size) {
  let valid_nonce = (nonce_size >= 7) && (nonce_size <= 13);
  let valid_tag = $list.contains(toList([4, 6, 8, 10, 12, 14, 16]), tag_size);
  let $ = valid_nonce && valid_tag;
  if ($) {
    return new Ok(new Ccm(cipher, nonce_size, tag_size));
  } else {
    return new Error(undefined);
  }
}

/**
 * Creates a ChaCha20-Poly1305 AEAD context with the given key.
 *
 * Uses standard parameters per RFC 8439: 12-byte (96-bit) nonce and
 * 16-byte (128-bit) authentication tag. The key must be exactly 32 bytes.
 */
export function chacha20_poly1305(key) {
  let $ = $bit_array.byte_size(key) === 32;
  if ($) {
    return new Ok(new ChaCha20Poly1305(key));
  } else {
    return new Error(undefined);
  }
}

/**
 * Creates an XChaCha20-Poly1305 AEAD context with the given key.
 *
 * Uses extended parameters: 24-byte (192-bit) nonce and 16-byte (128-bit)
 * authentication tag. The extended nonce provides better collision resistance
 * when generating random nonces. The key must be exactly 32 bytes.
 */
export function xchacha20_poly1305(key) {
  let $ = $bit_array.byte_size(key) === 32;
  if ($) {
    return new Ok(new XChaCha20Poly1305(key));
  } else {
    return new Error(undefined);
  }
}

/**
 * Returns the required nonce size in bytes for an AEAD context.
 */
export function nonce_size(ctx) {
  if (ctx instanceof Gcm) {
    let nonce_size$1 = ctx.nonce_size;
    return nonce_size$1;
  } else if (ctx instanceof Ccm) {
    let nonce_size$1 = ctx.nonce_size;
    return nonce_size$1;
  } else if (ctx instanceof ChaCha20Poly1305) {
    return 12;
  } else {
    return 24;
  }
}

/**
 * Returns the authentication tag size in bytes for an AEAD context.
 */
export function tag_size(ctx) {
  if (ctx instanceof Gcm) {
    return 16;
  } else if (ctx instanceof Ccm) {
    let tag_size$1 = ctx.tag_size;
    return tag_size$1;
  } else if (ctx instanceof ChaCha20Poly1305) {
    return 16;
  } else {
    return 16;
  }
}

/**
 * Derives the subkey and ChaCha20 nonce for XChaCha20-Poly1305.
 * 
 * @ignore
 */
function xchacha20_derive(key, nonce) {
  if (nonce.bitSize >= 128 && nonce.bitSize === 192) {
    let hchacha_input = bitArraySlice(nonce, 0, 128);
    let nonce_suffix = bitArraySlice(nonce, 128, 192);
    let subkey = $hchacha20.subkey(key, hchacha_input);
    let chacha_nonce = toBitArray([0, 0, 0, 0, nonce_suffix]);
    return new Ok([subkey, chacha_nonce]);
  } else {
    return new Error(undefined);
  }
}

/**
 * Encrypts and authenticates plaintext with additional authenticated data.
 *
 * The AAD is authenticated but not encrypted. It can be used for headers,
 * metadata, or context that should be tamper-proof but remain readable.
 */
export function seal_with_aad(ctx, nonce, plaintext, aad) {
  let nonce_len = $bit_array.byte_size(nonce);
  let $ = (nonce_len > 0) && (nonce_len === nonce_size(ctx));
  if ($) {
    if (ctx instanceof Gcm) {
      return do_seal(ctx, nonce, plaintext, aad);
    } else if (ctx instanceof Ccm) {
      return do_seal(ctx, nonce, plaintext, aad);
    } else if (ctx instanceof ChaCha20Poly1305) {
      return do_seal(ctx, nonce, plaintext, aad);
    } else {
      let key = ctx.key;
      return $result.try$(
        xchacha20_derive(key, nonce),
        (_use0) => {
          let subkey = _use0[0];
          let chacha_nonce = _use0[1];
          return do_seal(
            new ChaCha20Poly1305(subkey),
            chacha_nonce,
            plaintext,
            aad,
          );
        },
      );
    }
  } else {
    return new Error(undefined);
  }
}

/**
 * Encrypts and authenticates plaintext using AEAD.
 *
 * The nonce must be exactly `nonce_size` bytes. Never reuse a nonce with
 * the same key.
 */
export function seal(ctx, nonce, plaintext) {
  return seal_with_aad(ctx, nonce, plaintext, toBitArray([]));
}

/**
 * Decrypts and verifies AEAD-encrypted data with additional authenticated data.
 *
 * The AAD must match exactly what was provided during encryption.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/aead
 * import kryptos/block
 * import kryptos/crypto
 *
 * let assert Ok(cipher) = block.aes_256(crypto.random_bytes(32))
 * let ctx = aead.gcm(cipher)
 * let nonce = crypto.random_bytes(aead.nonce_size(ctx))
 * let aad = <<"header":utf8>>
 * let assert Ok(#(ciphertext, tag)) =
 *   aead.seal_with_aad(ctx, nonce:, plaintext: <<"secret":utf8>>, additional_data: aad)
 * let assert Ok(plaintext) =
 *   aead.open_with_aad(ctx, nonce:, tag:, ciphertext:, additional_data: aad)
 * ```
 */
export function open_with_aad(ctx, nonce, tag, ciphertext, aad) {
  let nonce_len = $bit_array.byte_size(nonce);
  let tag_len = $bit_array.byte_size(tag);
  let $ = ((nonce_len > 0) && (nonce_len === nonce_size(ctx))) && (tag_len === tag_size(
    ctx,
  ));
  if ($) {
    if (ctx instanceof Gcm) {
      return do_open(ctx, nonce, tag, ciphertext, aad);
    } else if (ctx instanceof Ccm) {
      return do_open(ctx, nonce, tag, ciphertext, aad);
    } else if (ctx instanceof ChaCha20Poly1305) {
      return do_open(ctx, nonce, tag, ciphertext, aad);
    } else {
      let key = ctx.key;
      return $result.try$(
        xchacha20_derive(key, nonce),
        (_use0) => {
          let subkey = _use0[0];
          let chacha_nonce = _use0[1];
          return do_open(
            new ChaCha20Poly1305(subkey),
            chacha_nonce,
            tag,
            ciphertext,
            aad,
          );
        },
      );
    }
  } else {
    return new Error(undefined);
  }
}

/**
 * Decrypts and verifies AEAD-encrypted data.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/aead
 * import kryptos/block
 * import kryptos/crypto
 *
 * let assert Ok(cipher) = block.aes_256(crypto.random_bytes(32))
 * let ctx = aead.gcm(cipher)
 * let nonce = crypto.random_bytes(aead.nonce_size(ctx))
 * let assert Ok(#(ciphertext, tag)) = aead.seal(ctx, nonce:, plaintext: <<"secret":utf8>>)
 * let assert Ok(plaintext) = aead.open(ctx, nonce:, tag:, ciphertext:)
 * ```
 */
export function open(ctx, nonce, tag, ciphertext) {
  return open_with_aad(ctx, nonce, tag, ciphertext, toBitArray([]));
}

export function cipher_name(ctx) {
  if (ctx instanceof Gcm) {
    let cipher = ctx.cipher;
    return ("aes-" + $int.to_string($block.key_size(cipher))) + "-gcm";
  } else if (ctx instanceof Ccm) {
    let cipher = ctx.cipher;
    return ("aes-" + $int.to_string($block.key_size(cipher))) + "-ccm";
  } else if (ctx instanceof ChaCha20Poly1305) {
    return "chacha20-poly1305";
  } else {
    return "chacha20-poly1305";
  }
}

export function cipher_key(ctx) {
  if (ctx instanceof Gcm) {
    let cipher = ctx.cipher;
    return $block.aes_key(cipher);
  } else if (ctx instanceof Ccm) {
    let cipher = ctx.cipher;
    return $block.aes_key(cipher);
  } else if (ctx instanceof ChaCha20Poly1305) {
    let key = ctx.key;
    return key;
  } else {
    let key = ctx.key;
    return key;
  }
}

export function is_ccm(ctx) {
  if (ctx instanceof Ccm) {
    return true;
  } else {
    return false;
  }
}

export function is_gcm(ctx) {
  if (ctx instanceof Gcm) {
    return true;
  } else {
    return false;
  }
}

export function is_chacha20_poly1305(ctx) {
  if (ctx instanceof ChaCha20Poly1305) {
    return true;
  } else {
    return false;
  }
}
