import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $timestamp from "../../../gleam_time/gleam/time/timestamp.mjs";
import * as $gose from "../../gose.mjs";
import * as $cwt from "../../gose/cose/cwt.mjs";
import * as $encrypt0 from "../../gose/cose/encrypt0.mjs";

function map_gose_error(err) {
  return new $cwt.CoseError(err);
}

/**
 * Encrypt a signed CWT with COSE_Encrypt0.
 */
export function encrypt(signed_cwt, content_alg, encryption_key) {
  return $result.try$(
    (() => {
      let _pipe = $encrypt0.new$(content_alg);
      return $result.map_error(_pipe, map_gose_error);
    })(),
    (message) => {
      let _pipe = $encrypt0.encrypt(message, encryption_key, signed_cwt);
      let _pipe$1 = $result.map(_pipe, $encrypt0.serialize);
      return $result.map_error(_pipe$1, map_gose_error);
    },
  );
}

/**
 * Decrypt an encrypted CWT and validate its claims.
 */
export function decrypt_and_validate(token, decryptor, verifier, now) {
  return $result.try$(
    (() => {
      let _pipe = $encrypt0.parse(token);
      return $result.map_error(_pipe, map_gose_error);
    })(),
    (parsed) => {
      return $result.try$(
        (() => {
          let _pipe = $encrypt0.decrypt(decryptor, parsed);
          return $result.map_error(
            _pipe,
            (err) => {
              return new $cwt.DecryptionFailed($gose.error_message(err));
            },
          );
        })(),
        (inner_bytes) => {
          return $cwt.verify_and_validate(verifier, inner_bytes, now);
        },
      );
    },
  );
}
