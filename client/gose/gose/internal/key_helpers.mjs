import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $ec from "../../../kryptos/kryptos/ec.mjs";
import { Ok, Error, toList, Empty as $Empty, CustomType as $CustomType, isEqual } from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";

/**
 * Sign a JWS or derive a CEK for JWE
 */
export class ForSigning extends $CustomType {}
export const KeyPurpose$ForSigning$const = new ForSigning();
export const KeyPurpose$ForSigning = () => KeyPurpose$ForSigning$const;
export const KeyPurpose$isForSigning = (value) => value instanceof ForSigning;

/**
 * Verify a JWS signature
 */
export class ForVerification extends $CustomType {}
export const KeyPurpose$ForVerification$const = new ForVerification();
export const KeyPurpose$ForVerification = () =>
  KeyPurpose$ForVerification$const;
export const KeyPurpose$isForVerification = (value) =>
  value instanceof ForVerification;

/**
 * Encrypt content or wrap a CEK
 */
export class ForEncryption extends $CustomType {}
export const KeyPurpose$ForEncryption$const = new ForEncryption();
export const KeyPurpose$ForEncryption = () => KeyPurpose$ForEncryption$const;
export const KeyPurpose$isForEncryption = (value) =>
  value instanceof ForEncryption;

/**
 * Decrypt content or unwrap a CEK
 */
export class ForDecryption extends $CustomType {}
export const KeyPurpose$ForDecryption$const = new ForDecryption();
export const KeyPurpose$ForDecryption = () => KeyPurpose$ForDecryption$const;
export const KeyPurpose$isForDecryption = (value) =>
  value instanceof ForDecryption;

/**
 * ECDH key agreement (deriveKey/deriveBits)
 */
export class ForKeyAgreement extends $CustomType {}
export const KeyPurpose$ForKeyAgreement$const = new ForKeyAgreement();
export const KeyPurpose$ForKeyAgreement = () =>
  KeyPurpose$ForKeyAgreement$const;
export const KeyPurpose$isForKeyAgreement = (value) =>
  value instanceof ForKeyAgreement;

/**
 * Order keys so that keys with a matching `kid` come first.
 * If no target kid is provided, keys are returned in their original order.
 */
export function order_keys_by_kid(keys, target_kid) {
  if (target_kid instanceof $option.Some) {
    let target = target_kid[0];
    let $ = $list.partition(
      keys,
      (key) => { return isEqual($gose.kid(key), new Ok(target)); },
    );
    let matching = $[0];
    let others = $[1];
    return $list.append(matching, others);
  } else {
    return keys;
  }
}

/**
 * Verify that the actual JWS algorithm matches the expected one.
 * Returns an error if there is a mismatch (algorithm pinning).
 */
export function require_matching_signing_algorithm(expected, actual) {
  let $ = isEqual(expected, actual);
  if ($) {
    return new Ok(undefined);
  } else {
    return new Error(
      new $gose.InvalidState(
        (("algorithm mismatch: expected " + $string.inspect(expected)) + ", got ") + $string.inspect(
          actual,
        ),
      ),
    );
  }
}

export function require_matching_content_algorithm(expected, actual) {
  let $ = isEqual(expected, actual);
  if ($) {
    return new Ok(undefined);
  } else {
    return new Error(
      new $gose.InvalidState(
        (("algorithm mismatch: expected " + $string.inspect(expected)) + ", got ") + $string.inspect(
          actual,
        ),
      ),
    );
  }
}

/**
 * Validate that a key list is non-empty, then continue with the provided function.
 *
 * Returns an error if the key list is empty, otherwise calls the continuation.
 */
export function require_non_empty_keys(keys, continue$) {
  if (keys instanceof $Empty) {
    return new Error(new $gose.InvalidState("at least one key required"));
  } else {
    return continue$();
  }
}

/**
 * Validate that an HMAC key meets the minimum size requirements for the algorithm.
 */
export function validate_hmac_key_size(key, min_bytes, alg_name) {
  let $ = $gose.octet_key_size(key);
  if ($ instanceof Ok) {
    let size = $[0];
    if (size < min_bytes) {
      return new Error(
        new $gose.InvalidState(
          (((alg_name + " requires key of at least ") + $int.to_string(
            min_bytes,
          )) + " bytes, got ") + $int.to_string(size),
        ),
      );
    } else {
      return new Ok(undefined);
    }
  } else {
    return $;
  }
}

function validate_eddsa_key(key) {
  let $ = $gose.eddsa_curve(key);
  if ($ instanceof Ok) {
    return new Ok(undefined);
  } else {
    return new Error(
      new $gose.InvalidState(
        "EdDSA algorithm requires an EdDSA key (Ed25519/Ed448), not XDH",
      ),
    );
  }
}

function validate_ec_curve(key, expected) {
  let $ = $gose.ec_curve(key);
  if ($ instanceof Ok) {
    let actual = $[0];
    if (isEqual(actual, expected)) {
      return new Ok(undefined);
    } else {
      return new Error(
        new $gose.InvalidState("EC key curve does not match algorithm"),
      );
    }
  } else {
    return new Error(new $gose.InvalidState("could not determine EC key curve"));
  }
}

/**
 * Validate that a key is compatible with a JWS algorithm.
 *
 * Checks:
 * - Key type matches algorithm requirements (e.g., HMAC needs octet key)
 * - HMAC keys meet minimum size requirements
 * - EC keys use the correct curve for the algorithm
 * - EdDSA keys are signing keys (Ed25519/Ed448), not key agreement (X25519/X448)
 */
export function validate_signing_key_type(alg, key) {
  let key_type = $gose.key_type(key);
  if (alg instanceof $gose.DigitalSignature) {
    if (key_type instanceof $gose.RsaKeyType) {
      let $ = alg[0];
      if ($ instanceof $gose.RsaPkcs1) {
        return new Ok(undefined);
      } else if ($ instanceof $gose.RsaPss) {
        return new Ok(undefined);
      } else {
        return new Error(
          new $gose.InvalidState(
            ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
          ),
        );
      }
    } else if (key_type instanceof $gose.EcKeyType) {
      let $ = alg[0];
      if ($ instanceof $gose.Ecdsa) {
        let $1 = $[0];
        if ($1 instanceof $gose.EcdsaP256) {
          return validate_ec_curve(key, $ec.Curve$P256$const);
        } else if ($1 instanceof $gose.EcdsaP384) {
          return validate_ec_curve(key, $ec.Curve$P384$const);
        } else if ($1 instanceof $gose.EcdsaP521) {
          return validate_ec_curve(key, $ec.Curve$P521$const);
        } else {
          return validate_ec_curve(key, $ec.Curve$Secp256k1$const);
        }
      } else {
        return new Error(
          new $gose.InvalidState(
            ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
          ),
        );
      }
    } else if (key_type instanceof $gose.OkpKeyType) {
      let $ = alg[0];
      if ($ instanceof $gose.Eddsa) {
        return validate_eddsa_key(key);
      } else {
        return new Error(
          new $gose.InvalidState(
            ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
          ),
        );
      }
    } else {
      return new Error(
        new $gose.InvalidState(
          ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
        ),
      );
    }
  } else if (key_type instanceof $gose.OctKeyType) {
    let hmac_alg = alg[0][0];
    return validate_hmac_key_size(
      key,
      $gose.hmac_alg_key_size(hmac_alg),
      $string.inspect(alg),
    );
  } else {
    return new Error(
      new $gose.InvalidState(
        ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
      ),
    );
  }
}

function validate_xdh_key(key) {
  let $ = $gose.xdh_curve(key);
  if ($ instanceof Ok) {
    return new Ok(undefined);
  } else {
    return new Error(
      new $gose.InvalidState(
        "ECDH-ES algorithm requires an EC or XDH key (X25519/X448), not EdDSA",
      ),
    );
  }
}

export function validate_jwe_key_type(alg, key) {
  let key_type = $gose.key_type(key);
  if (key_type instanceof $gose.OctKeyType) {
    if (alg instanceof $gose.Direct) {
      return new Ok(undefined);
    } else if (alg instanceof $gose.AesKeyWrap) {
      return new Ok(undefined);
    } else if (alg instanceof $gose.ChaCha20KeyWrap) {
      return new Ok(undefined);
    } else if (alg instanceof $gose.Pbes2) {
      return new Error(
        new $gose.InvalidState("use password_decryptor for PBES2 algorithms"),
      );
    } else {
      return new Error(
        new $gose.InvalidState(
          ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
        ),
      );
    }
  } else if (key_type instanceof $gose.RsaKeyType) {
    if (alg instanceof $gose.RsaEncryption) {
      return new Ok(undefined);
    } else if (alg instanceof $gose.Pbes2) {
      return new Error(
        new $gose.InvalidState("use password_decryptor for PBES2 algorithms"),
      );
    } else {
      return new Error(
        new $gose.InvalidState(
          ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
        ),
      );
    }
  } else if (key_type instanceof $gose.EcKeyType) {
    if (alg instanceof $gose.EcdhEs) {
      return new Ok(undefined);
    } else if (alg instanceof $gose.Pbes2) {
      return new Error(
        new $gose.InvalidState("use password_decryptor for PBES2 algorithms"),
      );
    } else {
      return new Error(
        new $gose.InvalidState(
          ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
        ),
      );
    }
  } else if (alg instanceof $gose.EcdhEs) {
    return validate_xdh_key(key);
  } else if (alg instanceof $gose.Pbes2) {
    return new Error(
      new $gose.InvalidState("use password_decryptor for PBES2 algorithms"),
    );
  } else {
    return new Error(
      new $gose.InvalidState(
        ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
      ),
    );
  }
}

/**
 * Validate that a key's `alg` field matches the expected JWE algorithm.
 *
 * If the key has no `alg` field set, validation passes (any algorithm allowed).
 * If the key has an `alg` field, it must match the expected algorithm.
 */
export function validate_key_algorithm_jwe(key, expected) {
  let $ = $gose.alg(key);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $gose.SigningAlg) {
      return new Error(
        new $gose.InvalidState(
          "key algorithm mismatch: key has JWS algorithm, expected JWE algorithm",
        ),
      );
    } else if ($1 instanceof $gose.KeyEncryptionAlg) {
      let alg = $1[0];
      if (isEqual(alg, expected)) {
        return new Ok(undefined);
      } else {
        let alg = $1[0];
        return new Error(
          new $gose.InvalidState(
            (("key algorithm mismatch: key has " + $string.inspect(alg)) + ", expected ") + $string.inspect(
              expected,
            ),
          ),
        );
      }
    } else {
      return new Error(
        new $gose.InvalidState(
          "key algorithm mismatch: key has content algorithm, expected JWE algorithm",
        ),
      );
    }
  } else {
    return new Ok(undefined);
  }
}

/**
 * Validate that a key's `alg` field matches the expected JWS algorithm.
 *
 * If the key has no `alg` field set, validation passes (any algorithm allowed).
 * If the key has an `alg` field, it must match the expected algorithm.
 */
export function validate_key_algorithm_signing(key, expected) {
  let $ = $gose.alg(key);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $gose.SigningAlg) {
      let alg = $1[0];
      if (isEqual(alg, expected)) {
        return new Ok(undefined);
      } else {
        let alg = $1[0];
        return new Error(
          new $gose.InvalidState(
            (("key algorithm mismatch: key has " + $string.inspect(alg)) + ", expected ") + $string.inspect(
              expected,
            ),
          ),
        );
      }
    } else if ($1 instanceof $gose.KeyEncryptionAlg) {
      return new Error(
        new $gose.InvalidState(
          "key algorithm mismatch: key has JWE algorithm, expected JWS algorithm",
        ),
      );
    } else {
      return new Error(
        new $gose.InvalidState(
          "key algorithm mismatch: key has content algorithm, expected JWS algorithm",
        ),
      );
    }
  } else {
    return new Ok(undefined);
  }
}

function validate_ops_for_purpose(ops, purpose) {
  let _block;
  if (purpose instanceof ForSigning) {
    _block = [
      toList([$gose.KeyOp$Sign$const]),
      "key_ops does not include 'sign' operation",
    ];
  } else if (purpose instanceof ForVerification) {
    _block = [
      toList([$gose.KeyOp$Verify$const]),
      "key_ops does not include 'verify' operation",
    ];
  } else if (purpose instanceof ForEncryption) {
    _block = [
      toList([$gose.KeyOp$Encrypt$const, $gose.KeyOp$WrapKey$const]),
      "key_ops does not include 'encrypt' or 'wrapKey' operation",
    ];
  } else if (purpose instanceof ForDecryption) {
    _block = [
      toList([$gose.KeyOp$Decrypt$const, $gose.KeyOp$UnwrapKey$const]),
      "key_ops does not include 'decrypt' or 'unwrapKey' operation",
    ];
  } else {
    _block = [
      toList([$gose.KeyOp$DeriveKey$const, $gose.KeyOp$DeriveBits$const]),
      "key_ops does not include 'deriveKey' or 'deriveBits' operation",
    ];
  }
  let $ = _block;
  let required_ops = $[0];
  let error_msg = $[1];
  let $1 = $list.any(
    required_ops,
    (_capture) => { return $list.contains(ops, _capture); },
  );
  if ($1) {
    return new Ok(undefined);
  } else {
    return new Error(new $gose.InvalidState(error_msg));
  }
}

/**
 * Validate that a key's `key_ops` field permits the intended purpose.
 * Returns Ok(Nil) if validation passes, or an error if the key cannot be used.
 */
export function validate_key_ops(key, purpose) {
  let $ = $gose.key_ops(key);
  if ($ instanceof Ok) {
    let ops = $[0];
    return validate_ops_for_purpose(ops, purpose);
  } else {
    return new Ok(undefined);
  }
}

function validate_use_value(use_value, purpose) {
  if (use_value instanceof $gose.Signing) {
    if (purpose instanceof ForSigning) {
      return new Ok(undefined);
    } else if (purpose instanceof ForVerification) {
      return new Ok(undefined);
    } else if (purpose instanceof ForEncryption) {
      return new Error(
        new $gose.InvalidState(
          "key use is 'sig', cannot be used for encryption",
        ),
      );
    } else if (purpose instanceof ForDecryption) {
      return new Error(
        new $gose.InvalidState(
          "key use is 'sig', cannot be used for decryption",
        ),
      );
    } else {
      return new Error(
        new $gose.InvalidState(
          "key use is 'sig', cannot be used for key agreement",
        ),
      );
    }
  } else if (purpose instanceof ForSigning) {
    return new Error(
      new $gose.InvalidState("key use is 'enc', cannot be used for signing"),
    );
  } else if (purpose instanceof ForVerification) {
    return new Error(
      new $gose.InvalidState(
        "key use is 'enc', cannot be used for verification",
      ),
    );
  } else if (purpose instanceof ForEncryption) {
    return new Ok(undefined);
  } else if (purpose instanceof ForDecryption) {
    return new Ok(undefined);
  } else {
    return new Ok(undefined);
  }
}

/**
 * Validate that a key's `use` field permits the intended purpose.
 * Returns Ok(Nil) if validation passes, or an error if the key cannot be used.
 */
export function validate_key_use(key, purpose) {
  let $ = $gose.key_use(key);
  if ($ instanceof Ok) {
    let use_value = $[0];
    return validate_use_value(use_value, purpose);
  } else {
    return new Ok(undefined);
  }
}

/**
 * Validate that a key is suitable for JWS verification.
 *
 * Checks key type compatibility, key use, key ops, and algorithm matching.
 */
export function validate_key_for_signing_verification(alg, key) {
  return $result.try$(
    validate_signing_key_type(alg, key),
    (_) => {
      return $result.try$(
        validate_key_use(key, KeyPurpose$ForVerification$const),
        (_) => {
          return $result.try$(
            validate_key_ops(key, KeyPurpose$ForVerification$const),
            (_) => { return validate_key_algorithm_signing(key, alg); },
          );
        },
      );
    },
  );
}

function jwe_key_ops_purpose(alg, base_purpose) {
  if (alg instanceof $gose.EcdhEs) {
    return KeyPurpose$ForKeyAgreement$const;
  } else {
    return base_purpose;
  }
}

/**
 * Validate that a key is suitable for JWE decryption.
 *
 * Checks key use, key ops, and algorithm matching.
 */
export function validate_key_for_jwe_decryption(alg, key) {
  let ops_purpose = jwe_key_ops_purpose(alg, KeyPurpose$ForDecryption$const);
  return $result.try$(
    validate_jwe_key_type(alg, key),
    (_) => {
      return $result.try$(
        validate_key_use(key, ops_purpose),
        (_) => {
          return $result.try$(
            validate_key_ops(key, ops_purpose),
            (_) => { return validate_key_algorithm_jwe(key, alg); },
          );
        },
      );
    },
  );
}

/**
 * Validate that a key is suitable for JWE encryption.
 *
 * Checks key use, key ops, and algorithm matching.
 */
export function validate_key_for_jwe_encryption(alg, key) {
  let ops_purpose = jwe_key_ops_purpose(alg, KeyPurpose$ForEncryption$const);
  return $result.try$(
    validate_jwe_key_type(alg, key),
    (_) => {
      return $result.try$(
        validate_key_use(key, ops_purpose),
        (_) => {
          return $result.try$(
            validate_key_ops(key, ops_purpose),
            (_) => { return validate_key_algorithm_jwe(key, alg); },
          );
        },
      );
    },
  );
}

/**
 * Validate that a key is compatible with a content encryption algorithm.
 *
 * All content encryption algorithms require symmetric (octet) keys.
 */
export function validate_content_key_type(alg, key) {
  let $ = $gose.key_type(key);
  if ($ instanceof $gose.OctKeyType) {
    return new Ok(undefined);
  } else {
    return new Error(
      new $gose.InvalidState(
        ("algorithm " + $string.inspect(alg)) + " incompatible with key type",
      ),
    );
  }
}

/**
 * Validate that a key's `alg` field matches the expected content encryption algorithm.
 *
 * If the key has no `alg` field set, validation passes (any algorithm allowed).
 * If the key has an `alg` field, it must match the expected algorithm.
 */
export function validate_key_algorithm_content(key, expected) {
  let $ = $gose.alg(key);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $gose.SigningAlg) {
      return new Error(
        new $gose.InvalidState(
          "key algorithm mismatch: key has signing algorithm, expected content algorithm",
        ),
      );
    } else if ($1 instanceof $gose.KeyEncryptionAlg) {
      return new Error(
        new $gose.InvalidState(
          "key algorithm mismatch: key has key encryption algorithm, expected content algorithm",
        ),
      );
    } else {
      let alg = $1[0];
      if (isEqual(alg, expected)) {
        return new Ok(undefined);
      } else {
        let alg = $1[0];
        return new Error(
          new $gose.InvalidState(
            (("key algorithm mismatch: key has " + $string.inspect(alg)) + ", expected ") + $string.inspect(
              expected,
            ),
          ),
        );
      }
    }
  } else {
    return new Ok(undefined);
  }
}

/**
 * Validate that a key is suitable for content encryption.
 *
 * Checks key type compatibility, key use, key ops, and algorithm matching.
 */
export function validate_key_for_content_encryption(alg, key) {
  return $result.try$(
    validate_content_key_type(alg, key),
    (_) => {
      return $result.try$(
        validate_key_use(key, KeyPurpose$ForEncryption$const),
        (_) => {
          return $result.try$(
            validate_key_ops(key, KeyPurpose$ForEncryption$const),
            (_) => { return validate_key_algorithm_content(key, alg); },
          );
        },
      );
    },
  );
}

/**
 * Validate that a key is suitable for content decryption.
 *
 * Checks key type compatibility, key use, key ops, and algorithm matching.
 */
export function validate_key_for_content_decryption(alg, key) {
  return $result.try$(
    validate_content_key_type(alg, key),
    (_) => {
      return $result.try$(
        validate_key_use(key, KeyPurpose$ForDecryption$const),
        (_) => {
          return $result.try$(
            validate_key_ops(key, KeyPurpose$ForDecryption$const),
            (_) => { return validate_key_algorithm_content(key, alg); },
          );
        },
      );
    },
  );
}
