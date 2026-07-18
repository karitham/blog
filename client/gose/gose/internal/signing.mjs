import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $crypto from "../../../kryptos/kryptos/crypto.mjs";
import * as $ec from "../../../kryptos/kryptos/ec.mjs";
import * as $ecdsa from "../../../kryptos/kryptos/ecdsa.mjs";
import * as $eddsa from "../../../kryptos/kryptos/eddsa.mjs";
import * as $hash from "../../../kryptos/kryptos/hash.mjs";
import * as $hmac from "../../../kryptos/kryptos/hmac.mjs";
import * as $rsa from "../../../kryptos/kryptos/rsa.mjs";
import { Ok, Error, isEqual } from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $key_extract from "../../gose/internal/key_extract.mjs";
import * as $key_helpers from "../../gose/internal/key_helpers.mjs";
import * as $utils from "../../gose/internal/utils.mjs";

function extract_eddsa_private_key(material) {
  let error = new $gose.InvalidState("EdDSA requires an EdDSA private key");
  return $result.try$(
    (() => {
      let _pipe = $gose.material_eddsa(material);
      return $result.replace_error(_pipe, error);
    })(),
    (eddsa) => {
      if (eddsa instanceof $gose.EddsaPrivate) {
        let private$ = eddsa.key;
        return new Ok(private$);
      } else {
        return new Error(error);
      }
    },
  );
}

function extract_ec_private_key(material, expected_curve, alg_name) {
  let curve_error = new $gose.InvalidState(
    ((alg_name + " requires an EC private key with ") + $utils.ec_curve_to_string(
      expected_curve,
    )) + " curve",
  );
  return $result.try$(
    (() => {
      let _pipe = $gose.material_ec(material);
      return $result.replace_error(_pipe, curve_error);
    })(),
    (ec) => {
      if (ec instanceof $gose.EcPrivate) {
        let private$ = ec.key;
        let curve = ec.curve;
        return $bool.guard(
          !isEqual(curve, expected_curve),
          new Error(curve_error),
          () => { return new Ok(private$); },
        );
      } else {
        return new Error(curve_error);
      }
    },
  );
}

function resolve_ecdsa_params(alg) {
  if (alg instanceof $gose.EcdsaP256) {
    return [new $hash.Sha256(), new $ec.P256()];
  } else if (alg instanceof $gose.EcdsaP384) {
    return [new $hash.Sha384(), new $ec.P384()];
  } else if (alg instanceof $gose.EcdsaP521) {
    return [new $hash.Sha512(), new $ec.P521()];
  } else {
    return [new $hash.Sha256(), new $ec.Secp256k1()];
  }
}

function resolve_rsa_pss_params(alg) {
  if (alg instanceof $gose.RsaPssSha256) {
    return [new $hash.Sha256(), new $rsa.Pss(new $rsa.SaltLengthHashLen())];
  } else if (alg instanceof $gose.RsaPssSha384) {
    return [new $hash.Sha384(), new $rsa.Pss(new $rsa.SaltLengthHashLen())];
  } else {
    return [new $hash.Sha512(), new $rsa.Pss(new $rsa.SaltLengthHashLen())];
  }
}

function resolve_rsa_pkcs1_params(alg) {
  if (alg instanceof $gose.RsaPkcs1Sha256) {
    return [new $hash.Sha256(), new $rsa.Pkcs1v15()];
  } else if (alg instanceof $gose.RsaPkcs1Sha384) {
    return [new $hash.Sha384(), new $rsa.Pkcs1v15()];
  } else {
    return [new $hash.Sha512(), new $rsa.Pkcs1v15()];
  }
}

function resolve_hmac_params(alg) {
  if (alg instanceof $gose.HmacSha256) {
    return [new $hash.Sha256(), 32, "HS256"];
  } else if (alg instanceof $gose.HmacSha384) {
    return [new $hash.Sha384(), 48, "HS384"];
  } else {
    return [new $hash.Sha512(), 64, "HS512"];
  }
}

function extract_validated_hmac_secret(key, hmac_alg) {
  return $result.try$(
    (() => {
      let _pipe = $gose.material_octet_secret($gose.material(key));
      return $result.replace_error(
        _pipe,
        new $gose.InvalidState("HMAC algorithms require an octet key"),
      );
    })(),
    (secret) => {
      let $ = resolve_hmac_params(hmac_alg);
      let hash_alg = $[0];
      let min_size = $[1];
      let alg_name = $[2];
      return $result.try$(
        $key_helpers.validate_hmac_key_size(key, min_size, alg_name),
        (_) => { return new Ok([hash_alg, secret]); },
      );
    },
  );
}

export function compute_signature(alg, key, message) {
  let mat = $gose.material(key);
  if (alg instanceof $gose.DigitalSignature) {
    let $ = alg[0];
    if ($ instanceof $gose.RsaPkcs1) {
      let pkcs1_alg = $[0];
      return $result.try$(
        (() => {
          let _pipe = $key_extract.rsa_private_key(mat);
          return $result.replace_error(
            _pipe,
            new $gose.InvalidState("RSA algorithms require an RSA private key"),
          );
        })(),
        (private$) => {
          let $1 = resolve_rsa_pkcs1_params(pkcs1_alg);
          let hash_alg = $1[0];
          let padding = $1[1];
          return new Ok($rsa.sign(private$, message, hash_alg, padding));
        },
      );
    } else if ($ instanceof $gose.RsaPss) {
      let pss_alg = $[0];
      return $result.try$(
        (() => {
          let _pipe = $key_extract.rsa_private_key(mat);
          return $result.replace_error(
            _pipe,
            new $gose.InvalidState("RSA algorithms require an RSA private key"),
          );
        })(),
        (private$) => {
          let $1 = resolve_rsa_pss_params(pss_alg);
          let hash_alg = $1[0];
          let padding = $1[1];
          return new Ok($rsa.sign(private$, message, hash_alg, padding));
        },
      );
    } else if ($ instanceof $gose.Ecdsa) {
      let ecdsa_alg = $[0];
      let $1 = resolve_ecdsa_params(ecdsa_alg);
      let hash_alg = $1[0];
      let expected_curve = $1[1];
      return $result.try$(
        extract_ec_private_key(mat, expected_curve, $string.inspect(alg)),
        (private$) => {
          return new Ok($ecdsa.sign_rs(private$, message, hash_alg));
        },
      );
    } else {
      return $result.try$(
        extract_eddsa_private_key(mat),
        (private$) => { return new Ok($eddsa.sign(private$, message)); },
      );
    }
  } else {
    let hmac_alg = alg[0][0];
    return $result.try$(
      extract_validated_hmac_secret(key, hmac_alg),
      (_use0) => {
        let hash_alg = _use0[0];
        let secret = _use0[1];
        let _pipe = $crypto.hmac(hash_alg, secret, message);
        return $result.replace_error(
          _pipe,
          new $gose.CryptoError("HMAC computation failed"),
        );
      },
    );
  }
}

function require_valid(valid) {
  return $bool.guard(
    !valid,
    new Error(new $gose.VerificationFailed()),
    () => { return new Ok(undefined); },
  );
}

function extract_eddsa_public_key(material) {
  return $result.try$(
    (() => {
      let _pipe = $gose.material_eddsa(material);
      return $result.replace_error(
        _pipe,
        new $gose.InvalidState("EdDSA requires an EdDSA key"),
      );
    })(),
    (eddsa) => {
      if (eddsa instanceof $gose.EddsaPrivate) {
        let public$ = eddsa.public;
        return new Ok(public$);
      } else {
        let public$ = eddsa.key;
        return new Ok(public$);
      }
    },
  );
}

function extract_ec_public_key(material, expected_curve, alg_name) {
  let curve_error = new $gose.InvalidState(
    ((alg_name + " requires an EC key with ") + $utils.ec_curve_to_string(
      expected_curve,
    )) + " curve",
  );
  return $result.try$(
    (() => {
      let _pipe = $gose.material_ec(material);
      return $result.replace_error(_pipe, curve_error);
    })(),
    (ec) => {
      let _block;
      if (ec instanceof $gose.EcPrivate) {
        let public$ = ec.public;
        let curve = ec.curve;
        _block = [public$, curve];
      } else {
        let public$ = ec.key;
        let curve = ec.curve;
        _block = [public$, curve];
      }
      let $ = _block;
      let public$ = $[0];
      let curve = $[1];
      return $bool.guard(
        !isEqual(curve, expected_curve),
        new Error(curve_error),
        () => { return new Ok(public$); },
      );
    },
  );
}

function hmac_verify(algorithm, key, message, expected) {
  let $ = $hmac.verify(algorithm, key, message, expected);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1) {
      return new Ok(undefined);
    } else {
      return new Error(new $gose.VerificationFailed());
    }
  } else {
    return new Error(new $gose.CryptoError("HMAC verification failed"));
  }
}

export function verify_signature(alg, key, message, signature) {
  let mat = $gose.material(key);
  if (alg instanceof $gose.DigitalSignature) {
    let $ = alg[0];
    if ($ instanceof $gose.RsaPkcs1) {
      let pkcs1_alg = $[0];
      return $result.try$(
        (() => {
          let _pipe = $key_extract.rsa_public_key(mat);
          return $result.replace_error(
            _pipe,
            new $gose.InvalidState("RSA algorithms require an RSA key"),
          );
        })(),
        (public$) => {
          let $1 = resolve_rsa_pkcs1_params(pkcs1_alg);
          let hash_alg = $1[0];
          let padding = $1[1];
          return require_valid(
            $rsa.verify(public$, message, signature, hash_alg, padding),
          );
        },
      );
    } else if ($ instanceof $gose.RsaPss) {
      let pss_alg = $[0];
      return $result.try$(
        (() => {
          let _pipe = $key_extract.rsa_public_key(mat);
          return $result.replace_error(
            _pipe,
            new $gose.InvalidState("RSA algorithms require an RSA key"),
          );
        })(),
        (public$) => {
          let $1 = resolve_rsa_pss_params(pss_alg);
          let hash_alg = $1[0];
          let padding = $1[1];
          return require_valid(
            $rsa.verify(public$, message, signature, hash_alg, padding),
          );
        },
      );
    } else if ($ instanceof $gose.Ecdsa) {
      let ecdsa_alg = $[0];
      let $1 = resolve_ecdsa_params(ecdsa_alg);
      let hash_alg = $1[0];
      let expected_curve = $1[1];
      return $result.try$(
        extract_ec_public_key(mat, expected_curve, $string.inspect(alg)),
        (public$) => {
          return require_valid(
            $ecdsa.verify_rs(public$, message, signature, hash_alg),
          );
        },
      );
    } else {
      return $result.try$(
        extract_eddsa_public_key(mat),
        (public$) => {
          return require_valid($eddsa.verify(public$, message, signature));
        },
      );
    }
  } else {
    let hmac_alg = alg[0][0];
    return $result.try$(
      extract_validated_hmac_secret(key, hmac_alg),
      (_use0) => {
        let hash_alg = _use0[0];
        let secret = _use0[1];
        return hmac_verify(hash_alg, secret, message, signature);
      },
    );
  }
}
