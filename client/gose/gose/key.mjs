import * as $ec from "../../kryptos/kryptos/ec.mjs";
import * as $eddsa from "../../kryptos/kryptos/eddsa.mjs";
import * as $rsa from "../../kryptos/kryptos/rsa.mjs";
import * as $xdh from "../../kryptos/kryptos/xdh.mjs";
import * as $gose from "../gose.mjs";

export function from_der(der) {
  return $gose.from_der(der);
}

export function from_pem(pem) {
  return $gose.from_pem(pem);
}

export function from_octet_bits(secret) {
  return $gose.from_octet_bits(secret);
}

export function from_eddsa_bits(curve, private_bits) {
  return $gose.from_eddsa_bits(curve, private_bits);
}

export function from_eddsa_public_bits(curve, public_bits) {
  return $gose.from_eddsa_public_bits(curve, public_bits);
}

export function from_xdh_bits(curve, private_bits) {
  return $gose.from_xdh_bits(curve, private_bits);
}

export function from_xdh_public_bits(curve, public_bits) {
  return $gose.from_xdh_public_bits(curve, public_bits);
}

export function ec_public_key_from_coordinates(curve, x, y) {
  return $gose.ec_public_key_from_coordinates(curve, x, y);
}

export function generate_ec(curve) {
  return $gose.generate_ec(curve);
}

export function generate_eddsa(curve) {
  return $gose.generate_eddsa(curve);
}

export function generate_hmac_key(alg) {
  return $gose.generate_hmac_key(alg);
}

export function generate_enc_key(enc) {
  return $gose.generate_enc_key(enc);
}

export function generate_aes_kw_key(size) {
  return $gose.generate_aes_kw_key(size);
}

export function generate_chacha20_kw_key() {
  return $gose.generate_chacha20_kw_key();
}

export function generate_rsa(bits) {
  return $gose.generate_rsa(bits);
}

export function generate_xdh(curve) {
  return $gose.generate_xdh(curve);
}

export function with_alg(key, alg) {
  return $gose.with_alg(key, alg);
}

export function with_key_ops(key, ops) {
  return $gose.with_key_ops(key, ops);
}

export function with_key_use(key, use_) {
  return $gose.with_key_use(key, use_);
}

export function with_kid(key, kid) {
  return $gose.with_kid(key, kid);
}

export function with_kid_bits(key, kid) {
  return $gose.with_kid_bits(key, kid);
}

export function alg(key) {
  return $gose.alg(key);
}

export function ec_curve(key) {
  return $gose.ec_curve(key);
}

export function ec_public_key(key) {
  return $gose.ec_public_key(key);
}

export function ec_public_key_coordinates(key) {
  return $gose.ec_public_key_coordinates(key);
}

export function eddsa_curve(key) {
  return $gose.eddsa_curve(key);
}

export function eddsa_public_key(key) {
  return $gose.eddsa_public_key(key);
}

export function key_ops(key) {
  return $gose.key_ops(key);
}

export function key_type(key) {
  return $gose.key_type(key);
}

export function key_use(key) {
  return $gose.key_use(key);
}

export function kid(key) {
  return $gose.kid(key);
}

export function octet_key_size(key) {
  return $gose.octet_key_size(key);
}

export function rsa_public_key(key) {
  return $gose.rsa_public_key(key);
}

export function xdh_curve(key) {
  return $gose.xdh_curve(key);
}

export function xdh_public_key(key) {
  return $gose.xdh_public_key(key);
}

export function public_key(key) {
  return $gose.public_key(key);
}

export function to_der(key) {
  return $gose.to_der(key);
}

export function to_octet_bits(key) {
  return $gose.to_octet_bits(key);
}

export function to_pem(key) {
  return $gose.to_pem(key);
}
