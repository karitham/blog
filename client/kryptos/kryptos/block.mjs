import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import { Ok, Error, CustomType as $CustomType, toBitArray } from "../gleam.mjs";
import {
  blockCipherEncrypt as do_encrypt,
  blockCipherDecrypt as do_decrypt,
  blockCipherWrap as do_wrap,
  blockCipherUnwrap as do_unwrap,
} from "../kryptos_ffi.mjs";

class Aes extends $CustomType {
  constructor(key_size, key) {
    super();
    this.key_size = key_size;
    this.key = key;
  }
}

/**
 * Electronic Codebook mode.
 * 
 * @ignore
 */
class Ecb extends $CustomType {
  constructor(cipher) {
    super();
    this.cipher = cipher;
  }
}

/**
 * Cipher Block Chaining mode with PKCS7 padding.
 * 
 * @ignore
 */
class Cbc extends $CustomType {
  constructor(cipher, iv) {
    super();
    this.cipher = cipher;
    this.iv = iv;
  }
}

/**
 * Counter mode (streaming cipher).
 * 
 * @ignore
 */
class Ctr extends $CustomType {
  constructor(cipher, nonce) {
    super();
    this.cipher = cipher;
    this.nonce = nonce;
  }
}

/**
 * Returns the key size in bits for a block cipher.
 */
export function key_size(cipher) {
  let key_size$1 = cipher.key_size;
  return key_size$1;
}

/**
 * Returns the block size in bytes for a block cipher.
 */
export function block_size(cipher) {
  return 16;
}

/**
 * Creates a new AES-128 block cipher with the given key.
 *
 * The key must be exactly 16 bytes.
 */
export function aes_128(key) {
  let $ = $bit_array.byte_size(key) === 16;
  if ($) {
    return new Ok(new Aes(128, key));
  } else {
    return new Error(undefined);
  }
}

/**
 * Creates a new AES-192 block cipher with the given key.
 *
 * The key must be exactly 24 bytes.
 */
export function aes_192(key) {
  let $ = $bit_array.byte_size(key) === 24;
  if ($) {
    return new Ok(new Aes(192, key));
  } else {
    return new Error(undefined);
  }
}

/**
 * Creates a new AES-256 block cipher with the given key.
 *
 * The key must be exactly 32 bytes.
 */
export function aes_256(key) {
  let $ = $bit_array.byte_size(key) === 32;
  if ($) {
    return new Ok(new Aes(256, key));
  } else {
    return new Error(undefined);
  }
}

/**
 * Creates an ECB mode context for the given cipher.
 *
 * **SECURITY WARNING:** ECB mode is insecure for most use cases.
 * Identical plaintext blocks produce identical ciphertext blocks,
 * revealing patterns in the data.
 */
export function ecb(cipher) {
  return new Ecb(cipher);
}

/**
 * Creates a CBC mode context with the given cipher and IV.
 *
 * The IV must be exactly 16 bytes, random, and unique per encryption.
 */
export function cbc(cipher, iv) {
  let $ = $bit_array.byte_size(iv) === 16;
  if ($) {
    return new Ok(new Cbc(cipher, iv));
  } else {
    return new Error(undefined);
  }
}

/**
 * Creates a CTR mode context with the given cipher and nonce.
 *
 * **SECURITY WARNING:** Nonce reuse is catastrophic in CTR mode.
 * NEVER reuse a nonce with the same key.
 *
 * The nonce must be exactly 16 bytes.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/block
 * import kryptos/crypto
 *
 * let assert Ok(cipher) = block.aes_256(crypto.random_bytes(32))
 * let assert Ok(ctx) = block.ctr(cipher, nonce: crypto.random_bytes(16))
 * let assert Ok(ciphertext) = block.encrypt(ctx, <<"secret":utf8>>)
 * let assert Ok(plaintext) = block.decrypt(ctx, ciphertext)
 * ```
 */
export function ctr(cipher, nonce) {
  let $ = $bit_array.byte_size(nonce) === 16;
  if ($) {
    return new Ok(new Ctr(cipher, nonce));
  } else {
    return new Error(undefined);
  }
}

function validate_iv(ctx) {
  if (ctx instanceof Ecb) {
    return true;
  } else if (ctx instanceof Cbc) {
    let iv = ctx.iv;
    return $bit_array.byte_size(iv) === 16;
  } else {
    let nonce = ctx.nonce;
    return $bit_array.byte_size(nonce) === 16;
  }
}

/**
 * Encrypts plaintext using the cipher mode.
 *
 * ## Notes
 * - ECB: No IV required
 * - CBC: Automatically applies PKCS7 padding; ciphertext may be larger than plaintext
 * - CTR: No padding needed; ciphertext is same size as plaintext
 */
export function encrypt(ctx, plaintext) {
  let $ = validate_iv(ctx);
  if ($) {
    return do_encrypt(ctx, plaintext);
  } else {
    return new Error(undefined);
  }
}

/**
 * Decrypts ciphertext using the cipher mode.
 *
 * ## Notes
 * - ECB: No IV required
 * - CBC: Automatically removes PKCS7 padding; returns error if padding is invalid
 * - CTR: No padding; ciphertext size equals plaintext size
 */
export function decrypt(ctx, ciphertext) {
  let $ = validate_iv(ctx);
  if ($) {
    return do_decrypt(ctx, ciphertext);
  } else {
    return new Error(undefined);
  }
}

export function cipher_name(ctx) {
  if (ctx instanceof Ecb) {
    let key_size$1 = ctx.cipher.key_size;
    return ("aes-" + $int.to_string(key_size$1)) + "-ecb";
  } else if (ctx instanceof Cbc) {
    let key_size$1 = ctx.cipher.key_size;
    return ("aes-" + $int.to_string(key_size$1)) + "-cbc";
  } else {
    let key_size$1 = ctx.cipher.key_size;
    return ("aes-" + $int.to_string(key_size$1)) + "-ctr";
  }
}

export function cipher_key(ctx) {
  if (ctx instanceof Ecb) {
    let key = ctx.cipher.key;
    return key;
  } else if (ctx instanceof Cbc) {
    let key = ctx.cipher.key;
    return key;
  } else {
    let key = ctx.cipher.key;
    return key;
  }
}

export function cipher_iv(ctx) {
  if (ctx instanceof Ecb) {
    return toBitArray([]);
  } else if (ctx instanceof Cbc) {
    let iv = ctx.iv;
    return iv;
  } else {
    let nonce = ctx.nonce;
    return nonce;
  }
}

/**
 * Wraps key material using AES Key Wrap (RFC 3394).
 *
 * Key wrapping is used to protect cryptographic keys when they need to be
 * transported or stored. Unlike general encryption, key wrapping:
 * - Does not require an IV (uses a default IV internally)
 * - Provides integrity protection
 * - Output is always 8 bytes larger than input
 *
 * The plaintext must be a multiple of 8 bytes, minimum 16 bytes.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/block
 * import kryptos/crypto
 *
 * let assert Ok(kek) = block.aes_256(crypto.random_bytes(32))
 * let key_to_wrap = crypto.random_bytes(32)
 * let assert Ok(wrapped) = block.wrap(kek, key_to_wrap)
 * ```
 */
export function wrap(cipher, plaintext) {
  let size = $bit_array.byte_size(plaintext);
  let $ = (size >= 16) && ((size % 8) === 0);
  if ($) {
    return do_wrap(cipher, plaintext);
  } else {
    return new Error(undefined);
  }
}

/**
 * Unwraps key material using AES Key Wrap (RFC 3394).
 *
 * The ciphertext must be a multiple of 8 bytes, minimum 24 bytes.
 *
 * ## Example
 *
 * ```gleam
 * import kryptos/block
 *
 * let assert Ok(kek) = block.aes_256(kek_bytes)
 * let assert Ok(unwrapped) = block.unwrap(kek, wrapped_key)
 * ```
 */
export function unwrap(cipher, ciphertext) {
  let size = $bit_array.byte_size(ciphertext);
  let $ = (size >= 24) && ((size % 8) === 0);
  if ($) {
    return do_unwrap(cipher, ciphertext);
  } else {
    return new Error(undefined);
  }
}

export function aes_key(cipher) {
  let key = cipher.key;
  return key;
}

export function is_ctr(ctx) {
  if (ctx instanceof Ctr) {
    return true;
  } else {
    return false;
  }
}
