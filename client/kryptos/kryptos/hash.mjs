import { Ok, Error, CustomType as $CustomType } from "../gleam.mjs";
import { hashNew as do_new, hashUpdate as update, hashFinal as final } from "../kryptos_ffi.mjs";

export { final, update };

/**
 * BLAKE2b (512-bit output)
 */
export class Blake2b extends $CustomType {}
export const HashAlgorithm$Blake2b$const = new Blake2b();
export const HashAlgorithm$Blake2b = () => HashAlgorithm$Blake2b$const;
export const HashAlgorithm$isBlake2b = (value) => value instanceof Blake2b;

/**
 * BLAKE2s (256-bit output)
 */
export class Blake2s extends $CustomType {}
export const HashAlgorithm$Blake2s$const = new Blake2s();
export const HashAlgorithm$Blake2s = () => HashAlgorithm$Blake2s$const;
export const HashAlgorithm$isBlake2s = (value) => value instanceof Blake2s;

/**
 * MD5 (128-bit output), cryptographically broken - use only for legacy compatibility.
 */
export class Md5 extends $CustomType {}
export const HashAlgorithm$Md5$const = new Md5();
export const HashAlgorithm$Md5 = () => HashAlgorithm$Md5$const;
export const HashAlgorithm$isMd5 = (value) => value instanceof Md5;

/**
 * SHA-1 (160-bit output)
 */
export class Sha1 extends $CustomType {}
export const HashAlgorithm$Sha1$const = new Sha1();
export const HashAlgorithm$Sha1 = () => HashAlgorithm$Sha1$const;
export const HashAlgorithm$isSha1 = (value) => value instanceof Sha1;

/**
 * SHA-256 (256-bit output)
 */
export class Sha256 extends $CustomType {}
export const HashAlgorithm$Sha256$const = new Sha256();
export const HashAlgorithm$Sha256 = () => HashAlgorithm$Sha256$const;
export const HashAlgorithm$isSha256 = (value) => value instanceof Sha256;

/**
 * SHA-384 (384-bit output)
 */
export class Sha384 extends $CustomType {}
export const HashAlgorithm$Sha384$const = new Sha384();
export const HashAlgorithm$Sha384 = () => HashAlgorithm$Sha384$const;
export const HashAlgorithm$isSha384 = (value) => value instanceof Sha384;

/**
 * SHA-512 (512-bit output)
 */
export class Sha512 extends $CustomType {}
export const HashAlgorithm$Sha512$const = new Sha512();
export const HashAlgorithm$Sha512 = () => HashAlgorithm$Sha512$const;
export const HashAlgorithm$isSha512 = (value) => value instanceof Sha512;

/**
 * SHA-512/224 (224-bit output), truncated SHA-512.
 */
export class Sha512x224 extends $CustomType {}
export const HashAlgorithm$Sha512x224$const = new Sha512x224();
export const HashAlgorithm$Sha512x224 = () => HashAlgorithm$Sha512x224$const;
export const HashAlgorithm$isSha512x224 = (value) =>
  value instanceof Sha512x224;

/**
 * SHA-512/256 (256-bit output), truncated SHA-512.
 */
export class Sha512x256 extends $CustomType {}
export const HashAlgorithm$Sha512x256$const = new Sha512x256();
export const HashAlgorithm$Sha512x256 = () => HashAlgorithm$Sha512x256$const;
export const HashAlgorithm$isSha512x256 = (value) =>
  value instanceof Sha512x256;

/**
 * SHA3-224 (224-bit output)
 */
export class Sha3x224 extends $CustomType {}
export const HashAlgorithm$Sha3x224$const = new Sha3x224();
export const HashAlgorithm$Sha3x224 = () => HashAlgorithm$Sha3x224$const;
export const HashAlgorithm$isSha3x224 = (value) => value instanceof Sha3x224;

/**
 * SHA3-256 (256-bit output)
 */
export class Sha3x256 extends $CustomType {}
export const HashAlgorithm$Sha3x256$const = new Sha3x256();
export const HashAlgorithm$Sha3x256 = () => HashAlgorithm$Sha3x256$const;
export const HashAlgorithm$isSha3x256 = (value) => value instanceof Sha3x256;

/**
 * SHA3-384 (384-bit output)
 */
export class Sha3x384 extends $CustomType {}
export const HashAlgorithm$Sha3x384$const = new Sha3x384();
export const HashAlgorithm$Sha3x384 = () => HashAlgorithm$Sha3x384$const;
export const HashAlgorithm$isSha3x384 = (value) => value instanceof Sha3x384;

/**
 * SHA3-512 (512-bit output)
 */
export class Sha3x512 extends $CustomType {}
export const HashAlgorithm$Sha3x512$const = new Sha3x512();
export const HashAlgorithm$Sha3x512 = () => HashAlgorithm$Sha3x512$const;
export const HashAlgorithm$isSha3x512 = (value) => value instanceof Sha3x512;

/**
 * SHAKE128 extendable-output function (128-bit security).
 * The output_length parameter specifies the desired digest length in bytes.
 * Prefer using the `shake_128` smart constructor to validate the output length.
 */
export class Shake128 extends $CustomType {
  constructor(output_length) {
    super();
    this.output_length = output_length;
  }
}
export const HashAlgorithm$Shake128 = (output_length) =>
  new Shake128(output_length);
export const HashAlgorithm$isShake128 = (value) => value instanceof Shake128;
export const HashAlgorithm$Shake128$output_length = (value) =>
  value.output_length;
export const HashAlgorithm$Shake128$0 = (value) => value.output_length;

/**
 * SHAKE256 extendable-output function (256-bit security).
 * The output_length parameter specifies the desired digest length in bytes.
 * Prefer using the `shake_256` smart constructor to validate the output length.
 */
export class Shake256 extends $CustomType {
  constructor(output_length) {
    super();
    this.output_length = output_length;
  }
}
export const HashAlgorithm$Shake256 = (output_length) =>
  new Shake256(output_length);
export const HashAlgorithm$isShake256 = (value) => value instanceof Shake256;
export const HashAlgorithm$Shake256$output_length = (value) =>
  value.output_length;
export const HashAlgorithm$Shake256$0 = (value) => value.output_length;

/**
 * Creates a SHAKE128 hash algorithm with the given output length in bytes.
 *
 * The output length must be greater than zero.
 */
export function shake_128(length) {
  let $ = length > 0;
  if ($) {
    return new Ok(new Shake128(length));
  } else {
    return new Error(undefined);
  }
}

/**
 * Creates a SHAKE256 hash algorithm with the given output length in bytes.
 *
 * The output length must be greater than zero.
 */
export function shake_256(length) {
  let $ = length > 0;
  if ($) {
    return new Ok(new Shake256(length));
  } else {
    return new Error(undefined);
  }
}

export function algorithm_name(algorithm) {
  if (algorithm instanceof Blake2b) {
    return "blake2b512";
  } else if (algorithm instanceof Blake2s) {
    return "blake2s256";
  } else if (algorithm instanceof Md5) {
    return "md5";
  } else if (algorithm instanceof Sha1) {
    return "sha1";
  } else if (algorithm instanceof Sha256) {
    return "sha256";
  } else if (algorithm instanceof Sha384) {
    return "sha384";
  } else if (algorithm instanceof Sha512) {
    return "sha512";
  } else if (algorithm instanceof Sha512x224) {
    return "sha512-224";
  } else if (algorithm instanceof Sha512x256) {
    return "sha512-256";
  } else if (algorithm instanceof Sha3x224) {
    return "sha3-224";
  } else if (algorithm instanceof Sha3x256) {
    return "sha3-256";
  } else if (algorithm instanceof Sha3x384) {
    return "sha3-384";
  } else if (algorithm instanceof Sha3x512) {
    return "sha3-512";
  } else if (algorithm instanceof Shake128) {
    return "shake128";
  } else {
    return "shake256";
  }
}

/**
 * Returns the output size in bytes for a hash algorithm.
 */
export function byte_size(algorithm) {
  if (algorithm instanceof Blake2b) {
    return 64;
  } else if (algorithm instanceof Blake2s) {
    return 32;
  } else if (algorithm instanceof Md5) {
    return 16;
  } else if (algorithm instanceof Sha1) {
    return 20;
  } else if (algorithm instanceof Sha256) {
    return 32;
  } else if (algorithm instanceof Sha384) {
    return 48;
  } else if (algorithm instanceof Sha512) {
    return 64;
  } else if (algorithm instanceof Sha512x224) {
    return 28;
  } else if (algorithm instanceof Sha512x256) {
    return 32;
  } else if (algorithm instanceof Sha3x224) {
    return 28;
  } else if (algorithm instanceof Sha3x256) {
    return 32;
  } else if (algorithm instanceof Sha3x384) {
    return 48;
  } else if (algorithm instanceof Sha3x512) {
    return 64;
  } else if (algorithm instanceof Shake128) {
    let output_length = algorithm.output_length;
    return output_length;
  } else {
    let output_length = algorithm.output_length;
    return output_length;
  }
}

/**
 * Creates a new hasher for incremental hashing.
 *
 * Use this when you need to hash data in chunks, such as when streaming
 * or when the full input isn't available at once.
 */
export function new$(algorithm) {
  if (algorithm instanceof Shake128) {
    let output_length = algorithm.output_length;
    if (output_length <= 0) {
      return new Error(undefined);
    } else {
      return do_new(algorithm);
    }
  } else if (algorithm instanceof Shake256) {
    let output_length = algorithm.output_length;
    if (output_length <= 0) {
      return new Error(undefined);
    } else {
      return do_new(algorithm);
    }
  } else {
    return do_new(algorithm);
  }
}

/**
 * Checks if a hash algorithm is supported by the current runtime.
 *
 * Some algorithms may not be available depending on the platform or
 * OpenSSL/crypto library version.
 */
export function is_supported(algorithm) {
  let $ = new$(algorithm);
  if ($ instanceof Ok) {
    return true;
  } else {
    return false;
  }
}
