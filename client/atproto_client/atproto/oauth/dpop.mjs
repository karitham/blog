import * as $crypto from "../../../gleam_crypto/gleam/crypto.mjs";
import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $float from "../../../gleam_stdlib/gleam/float.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $timestamp from "../../../gleam_time/gleam/time/timestamp.mjs";
import * as $gose from "../../../gose/gose.mjs";
import * as $jws from "../../../gose/gose/jose/jws.mjs";
import * as $ec from "../../../kryptos/kryptos/ec.mjs";
import { toList } from "../../gleam.mjs";

const es256 = /* @__PURE__ */ new $gose.DigitalSignature(
  /* @__PURE__ */ new $gose.Ecdsa(/* @__PURE__ */ new $gose.EcdsaP256()),
);

export function generate_key() {
  return $gose.generate_ec(new $ec.P256());
}

function err(r) {
  return $result.map_error(r, $gose.error_message);
}

function push(claims, key, value) {
  if (value instanceof Some) {
    let v = value[0];
    return $list.append(claims, toList([[key, $json.string(v)]]));
  } else {
    return claims;
  }
}

function b64(bits) {
  return $bit_array.base64_url_encode(bits, false);
}

/**
 * The public key as a bare JWK (kty/crv/x/y), for embedding in a DPoP proof
 * header.
 */
export function bare_public_jwk(key) {
  return $result.try$(
    (() => {
      let _pipe = $gose.ec_public_key(key);
      return $result.replace_error(_pipe, "not an EC key");
    })(),
    (public$) => {
      return $result.map(
        (() => {
          let _pipe = $gose.ec_raw_coordinates(public$, new $ec.P256());
          return $result.replace_error(_pipe, "bad EC coordinates");
        })(),
        (_use0) => {
          let x = _use0[0];
          let y = _use0[1];
          return $json.object(
            toList([
              ["crv", $json.string("P-256")],
              ["kty", $json.string("EC")],
              ["x", $json.string(b64(x))],
              ["y", $json.string(b64(y))],
            ]),
          );
        },
      );
    },
  );
}

export function proof(key, method, url, nonce, ath) {
  return $result.try$(
    bare_public_jwk(key),
    (public_jwk) => {
      let jti = b64($crypto.strong_random_bytes(16));
      let iat = $float.truncate(
        $timestamp.to_unix_seconds($timestamp.system_time()),
      );
      let _block;
      let _pipe = toList([
        ["jti", $json.string(jti)],
        ["htm", $json.string(method)],
        ["htu", $json.string(url)],
        ["iat", $json.int(iat)],
      ]);
      let _pipe$1 = push(_pipe, "nonce", nonce);
      _block = push(_pipe$1, "ath", ath);
      let claims = _block;
      let _block$1;
      let _pipe$2 = $json.object(claims);
      let _pipe$3 = $json.to_string(_pipe$2);
      _block$1 = $bit_array.from_string(_pipe$3);
      let payload = _block$1;
      let _block$2;
      let _pipe$4 = $jws.new$(es256);
      _block$2 = $jws.with_typ(_pipe$4, "dpop+jwt");
      let unsigned = _block$2;
      return $result.try$(
        (() => {
          let _pipe$5 = $jws.with_header(unsigned, "jwk", public_jwk);
          return err(_pipe$5);
        })(),
        (unsigned) => {
          return $result.try$(
            (() => {
              let _pipe$5 = $jws.sign(unsigned, key, payload);
              return err(_pipe$5);
            })(),
            (signed) => {
              let _pipe$5 = $jws.serialize_compact(signed);
              return err(_pipe$5);
            },
          );
        },
      );
    },
  );
}
