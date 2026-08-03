import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $dict from "../../../gleam_stdlib/gleam/dict.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $crypto from "../../../kryptos/kryptos/crypto.mjs";
import * as $ec from "../../../kryptos/kryptos/ec.mjs";
import * as $eddsa from "../../../kryptos/kryptos/eddsa.mjs";
import * as $hash from "../../../kryptos/kryptos/hash.mjs";
import * as $rsa from "../../../kryptos/kryptos/rsa.mjs";
import * as $xdh from "../../../kryptos/kryptos/xdh.mjs";
import {
  Ok,
  Error,
  toList,
  List$Empty$const as $List$Empty$const,
  CustomType as $CustomType,
  makeError,
  isEqual,
  toBitArray,
} from "../../gleam.mjs";
import * as $gose from "../../gose.mjs";
import * as $utils from "../../gose/internal/utils.mjs";
import * as $jose from "../../gose/jose.mjs";

const FILEPATH = "src/gose/jose/jwk.gleam";

class EcDecoded extends $CustomType {
  constructor(crv, x, y, d, kid, use_, key_ops, alg) {
    super();
    this.crv = crv;
    this.x = x;
    this.y = y;
    this.d = d;
    this.kid = kid;
    this.use_ = use_;
    this.key_ops = key_ops;
    this.alg = alg;
  }
}

class OctDecoded extends $CustomType {
  constructor(k, kid, use_, key_ops, alg) {
    super();
    this.k = k;
    this.kid = kid;
    this.use_ = use_;
    this.key_ops = key_ops;
    this.alg = alg;
  }
}

class OkpDecoded extends $CustomType {
  constructor(crv, x, d, kid, use_, key_ops, alg) {
    super();
    this.crv = crv;
    this.x = x;
    this.d = d;
    this.kid = kid;
    this.use_ = use_;
    this.key_ops = key_ops;
    this.alg = alg;
  }
}

class RsaDecoded extends $CustomType {
  constructor(n, e, d, p, q, dp, dq, qi, kid, use_, key_ops, alg, oth) {
    super();
    this.n = n;
    this.e = e;
    this.d = d;
    this.p = p;
    this.q = q;
    this.dp = dp;
    this.dq = dq;
    this.qi = qi;
    this.kid = kid;
    this.use_ = use_;
    this.key_ops = key_ops;
    this.alg = alg;
    this.oth = oth;
  }
}

/**
 * Convert an algorithm (signing, key encryption, or content encryption)
 * to its RFC string representation.
 */
export function alg_to_string(alg) {
  if (alg instanceof $gose.SigningAlg) {
    let signing_alg = alg[0];
    return $jose.signing_alg_to_string(signing_alg);
  } else if (alg instanceof $gose.KeyEncryptionAlg) {
    let ke_alg = alg[0];
    return $jose.key_encryption_alg_to_string(ke_alg);
  } else {
    let content_alg = alg[0];
    return $jose.content_alg_to_string(content_alg);
  }
}

function alg_fields(alg) {
  if (alg instanceof $option.Some) {
    let a = alg[0];
    return toList([["alg", $json.string(alg_to_string(a))]]);
  } else {
    return $List$Empty$const;
  }
}

function key_op_to_string(op) {
  if (op instanceof $gose.Sign) {
    return "sign";
  } else if (op instanceof $gose.Verify) {
    return "verify";
  } else if (op instanceof $gose.Encrypt) {
    return "encrypt";
  } else if (op instanceof $gose.Decrypt) {
    return "decrypt";
  } else if (op instanceof $gose.WrapKey) {
    return "wrapKey";
  } else if (op instanceof $gose.UnwrapKey) {
    return "unwrapKey";
  } else if (op instanceof $gose.DeriveKey) {
    return "deriveKey";
  } else {
    return "deriveBits";
  }
}

function key_ops_fields(key_ops) {
  if (key_ops instanceof $option.Some) {
    let ops = key_ops[0];
    return toList([
      [
        "key_ops",
        $json.array(ops, (op) => { return $json.string(key_op_to_string(op)); }),
      ],
    ]);
  } else {
    return $List$Empty$const;
  }
}

function key_use_to_string(key_use) {
  if (key_use instanceof $gose.Signing) {
    return "sig";
  } else {
    return "enc";
  }
}

function key_use_fields(key_use) {
  if (key_use instanceof $option.Some) {
    let u = key_use[0];
    return toList([["use", $json.string(key_use_to_string(u))]]);
  } else {
    return $List$Empty$const;
  }
}

function kid_fields(kid) {
  if (kid instanceof $option.Some) {
    let k = kid[0];
    return toList([["kid", $json.string(k)]]);
  } else {
    return $List$Empty$const;
  }
}

function metadata_fields(k) {
  return $list.flatten(
    toList([
      kid_fields($option.from_result($gose.kid(k))),
      key_use_fields($option.from_result($gose.key_use(k))),
      key_ops_fields($option.from_result($gose.key_ops(k))),
      alg_fields($option.from_result($gose.alg(k))),
    ]),
  );
}

/**
 * Serialize a key to its JSON representation.
 */
export function to_json(k) {
  let mat = $gose.material(k);
  let _block;
  if (mat instanceof $gose.OctetKey) {
    let secret = mat.secret;
    _block = toList([
      ["kty", $json.string("oct")],
      ["k", $json.string($utils.encode_base64_url(secret))],
    ]);
  } else if (mat instanceof $gose.Rsa) {
    let $ = mat[0];
    if ($ instanceof $gose.RsaPrivate) {
      let private$ = $.key;
      _block = toList([
        ["kty", $json.string("RSA")],
        [
          "n",
          (() => {
            let _pipe = $rsa.modulus(private$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
        [
          "e",
          (() => {
            let _pipe = $rsa.public_exponent_bytes(private$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
        [
          "d",
          (() => {
            let _pipe = $rsa.private_exponent_bytes(private$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
        [
          "p",
          (() => {
            let _pipe = $rsa.prime1(private$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
        [
          "q",
          (() => {
            let _pipe = $rsa.prime2(private$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
        [
          "dp",
          (() => {
            let _pipe = $rsa.exponent1(private$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
        [
          "dq",
          (() => {
            let _pipe = $rsa.exponent2(private$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
        [
          "qi",
          (() => {
            let _pipe = $rsa.coefficient(private$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
      ]);
    } else {
      let public$ = $.key;
      _block = toList([
        ["kty", $json.string("RSA")],
        [
          "n",
          (() => {
            let _pipe = $rsa.public_key_modulus(public$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
        [
          "e",
          (() => {
            let _pipe = $rsa.public_key_exponent_bytes(public$);
            let _pipe$1 = $utils.strip_leading_zeros(_pipe);
            let _pipe$2 = $utils.encode_base64_url(_pipe$1);
            return $json.string(_pipe$2);
          })(),
        ],
      ]);
    }
  } else if (mat instanceof $gose.Elliptic) {
    let $ = mat[0];
    if ($ instanceof $gose.EcPrivate) {
      let private$ = $.key;
      let public$ = $.public;
      let curve = $.curve;
      let $1 = $gose.ec_raw_coordinates(public$, curve);
      let x;
      let y;
      if ($1 instanceof Ok) {
        x = $1[0][0];
        y = $1[0][1];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwk",
          172,
          "to_json",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 4946,
            end: 5010,
            pattern_start: 4957,
            pattern_end: 4968
          }
        )
      }
      let d_bits = $ec.to_bytes(private$);
      _block = toList([
        ["kty", $json.string("EC")],
        ["crv", $json.string($utils.ec_curve_to_string(curve))],
        ["x", $json.string($utils.encode_base64_url(x))],
        ["y", $json.string($utils.encode_base64_url(y))],
        ["d", $json.string($utils.encode_base64_url(d_bits))],
      ]);
    } else {
      let public$ = $.key;
      let curve = $.curve;
      let $1 = $gose.ec_raw_coordinates(public$, curve);
      let x;
      let y;
      if ($1 instanceof Ok) {
        x = $1[0][0];
        y = $1[0][1];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "gose/jose/jwk",
          184,
          "to_json",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 5489,
            end: 5553,
            pattern_start: 5500,
            pattern_end: 5511
          }
        )
      }
      _block = toList([
        ["kty", $json.string("EC")],
        ["crv", $json.string($utils.ec_curve_to_string(curve))],
        ["x", $json.string($utils.encode_base64_url(x))],
        ["y", $json.string($utils.encode_base64_url(y))],
      ]);
    }
  } else if (mat instanceof $gose.Edwards) {
    let $ = mat[0];
    if ($ instanceof $gose.EddsaPrivate) {
      let private$ = $.key;
      let public$ = $.public;
      let curve = $.curve;
      let x_bits = $eddsa.public_key_to_bytes(public$);
      let d_bits = $eddsa.to_bytes(private$);
      _block = toList([
        ["kty", $json.string("OKP")],
        ["crv", $json.string($utils.eddsa_curve_to_string(curve))],
        ["x", $json.string($utils.encode_base64_url(x_bits))],
        ["d", $json.string($utils.encode_base64_url(d_bits))],
      ]);
    } else {
      let public$ = $.key;
      let curve = $.curve;
      let x_bits = $eddsa.public_key_to_bytes(public$);
      _block = toList([
        ["kty", $json.string("OKP")],
        ["crv", $json.string($utils.eddsa_curve_to_string(curve))],
        ["x", $json.string($utils.encode_base64_url(x_bits))],
      ]);
    }
  } else {
    let $ = mat[0];
    if ($ instanceof $gose.XdhPrivate) {
      let private$ = $.key;
      let public$ = $.public;
      let curve = $.curve;
      let x_bits = $xdh.public_key_to_bytes(public$);
      let d_bits = $xdh.to_bytes(private$);
      _block = toList([
        ["kty", $json.string("OKP")],
        ["crv", $json.string($utils.xdh_curve_to_string(curve))],
        ["x", $json.string($utils.encode_base64_url(x_bits))],
        ["d", $json.string($utils.encode_base64_url(d_bits))],
      ]);
    } else {
      let public$ = $.key;
      let curve = $.curve;
      let x_bits = $xdh.public_key_to_bytes(public$);
      _block = toList([
        ["kty", $json.string("OKP")],
        ["crv", $json.string($utils.xdh_curve_to_string(curve))],
        ["x", $json.string($utils.encode_base64_url(x_bits))],
      ]);
    }
  }
  let base_fields = _block;
  return $json.object($list.append(base_fields, metadata_fields(k)));
}

function reject_x509_params(dyn) {
  let x509_fields = toList(["x5u", "x5c", "x5t", "x5t#S256"]);
  let dict_decoder = $decode.dict($decode.string, $decode.dynamic);
  let _block;
  let _pipe = $decode.run(dyn, dict_decoder);
  _block = $result.unwrap(_pipe, $dict.new$());
  let fields_dict = _block;
  return $list.try_each(
    x509_fields,
    (field) => {
      let $ = $dict.has_key(fields_dict, field);
      if ($) {
        return new Error(
          new $gose.ParseError("unsupported X.509 JWK parameter: " + field),
        );
      } else {
        return new Ok(undefined);
      }
    },
  );
}

/**
 * Parse an algorithm from its RFC string representation.
 */
export function alg_from_string(s) {
  let _pipe = $jose.signing_alg_from_string(s);
  let _pipe$1 = $result.map(
    _pipe,
    (var0) => { return new $gose.SigningAlg(var0); },
  );
  let _pipe$2 = $result.lazy_or(
    _pipe$1,
    () => {
      let _pipe$2 = $jose.key_encryption_alg_from_string(s);
      return $result.map(
        _pipe$2,
        (var0) => { return new $gose.KeyEncryptionAlg(var0); },
      );
    },
  );
  let _pipe$3 = $result.lazy_or(
    _pipe$2,
    () => {
      let _pipe$3 = $jose.content_alg_from_string(s);
      return $result.map(
        _pipe$3,
        (var0) => { return new $gose.ContentAlg(var0); },
      );
    },
  );
  return $result.replace_error(
    _pipe$3,
    new $gose.ParseError("unknown algorithm: " + s),
  );
}

function parse_optional(opt, parser) {
  if (opt instanceof $option.Some) {
    let value = opt[0];
    return $result.map(
      parser(value),
      (var0) => { return new $option.Some(var0); },
    );
  } else {
    return new Ok($option.Option$None$const);
  }
}

function key_op_from_string(s) {
  if (s === "sign") {
    return new Ok($gose.KeyOp$Sign$const);
  } else if (s === "verify") {
    return new Ok($gose.KeyOp$Verify$const);
  } else if (s === "encrypt") {
    return new Ok($gose.KeyOp$Encrypt$const);
  } else if (s === "decrypt") {
    return new Ok($gose.KeyOp$Decrypt$const);
  } else if (s === "wrapKey") {
    return new Ok($gose.KeyOp$WrapKey$const);
  } else if (s === "unwrapKey") {
    return new Ok($gose.KeyOp$UnwrapKey$const);
  } else if (s === "deriveKey") {
    return new Ok($gose.KeyOp$DeriveKey$const);
  } else if (s === "deriveBits") {
    return new Ok($gose.KeyOp$DeriveBits$const);
  } else {
    return new Error(new $gose.ParseError("invalid key_ops value: " + s));
  }
}

function parse_key_ops(ops) {
  return $bool.guard(
    $list.is_empty(ops),
    new Error(new $gose.ParseError("key_ops must not be empty")),
    () => {
      return $result.try$(
        $list.try_map(ops, key_op_from_string),
        (parsed) => {
          let $ = !isEqual($list.unique(parsed), parsed);
          if ($) {
            return new Error(
              new $gose.ParseError("key_ops must not contain duplicates"),
            );
          } else {
            return new Ok(parsed);
          }
        },
      );
    },
  );
}

function key_use_from_string(s) {
  if (s === "sig") {
    return new Ok($gose.KeyUse$Signing$const);
  } else if (s === "enc") {
    return new Ok($gose.KeyUse$Encrypting$const);
  } else {
    return new Error(new $gose.ParseError("invalid use value: " + s));
  }
}

function parse_key_metadata(use_opt, key_ops_opt, alg_opt) {
  return $result.try$(
    parse_optional(use_opt, key_use_from_string),
    (key_use) => {
      return $result.try$(
        parse_optional(key_ops_opt, parse_key_ops),
        (key_ops) => {
          return $result.try$(
            parse_optional(alg_opt, alg_from_string),
            (alg) => {
              return $result.try$(
                $gose.validate_key_use_ops(key_use, key_ops),
                (_) => { return new Ok([key_use, key_ops, alg]); },
              );
            },
          );
        },
      );
    },
  );
}

function process_ec_decoded(decoded) {
  let crv = decoded.crv;
  let x_b64 = decoded.x;
  let y_b64 = decoded.y;
  let d_opt = decoded.d;
  let kid = decoded.kid;
  let use_opt = decoded.use_;
  let key_ops_opt = decoded.key_ops;
  let alg_opt = decoded.alg;
  return $result.try$(
    $utils.ec_curve_from_string(crv),
    (curve) => {
      return $result.try$(
        $utils.decode_base64_url(x_b64, "x"),
        (x_bits) => {
          return $result.try$(
            $utils.decode_base64_url(y_b64, "y"),
            (y_bits) => {
              return $result.try$(
                parse_key_metadata(use_opt, key_ops_opt, alg_opt),
                (_use0) => {
                  let key_use = _use0[0];
                  let key_ops = _use0[1];
                  let alg = _use0[2];
                  let coord_size = $ec.coordinate_size(curve);
                  return $bool.guard(
                    $bit_array.byte_size(x_bits) !== coord_size,
                    new Error(
                      new $gose.ParseError(
                        ("EC x coordinate must be " + $int.to_string(coord_size)) + " bytes",
                      ),
                    ),
                    () => {
                      return $bool.guard(
                        $bit_array.byte_size(y_bits) !== coord_size,
                        new Error(
                          new $gose.ParseError(
                            ("EC y coordinate must be " + $int.to_string(
                              coord_size,
                            )) + " bytes",
                          ),
                        ),
                        () => {
                          let raw_point = $bit_array.concat(
                            toList([toBitArray([4]), x_bits, y_bits]),
                          );
                          if (d_opt instanceof $option.Some) {
                            let d_b64 = d_opt[0];
                            return $result.try$(
                              $utils.decode_base64_url(d_b64, "d"),
                              (d_bits) => {
                                return $result.try$(
                                  (() => {
                                    let _pipe = $ec.from_bytes(curve, d_bits);
                                    return $result.replace_error(
                                      _pipe,
                                      new $gose.ParseError(
                                        "invalid EC private key bytes",
                                      ),
                                    );
                                  })(),
                                  (_use0) => {
                                    let private$ = _use0[0];
                                    let public$ = _use0[1];
                                    let computed_point = $ec.public_key_to_raw_point(
                                      public$,
                                    );
                                    return $bool.guard(
                                      !$crypto.constant_time_equal(
                                        computed_point,
                                        raw_point,
                                      ),
                                      new Error(
                                        new $gose.ParseError(
                                          "x/y do not match computed public key",
                                        ),
                                      ),
                                      () => {
                                        return new Ok(
                                          $gose.build(
                                            new $gose.Elliptic(
                                              new $gose.EcPrivate(
                                                private$,
                                                public$,
                                                curve,
                                              ),
                                            ),
                                            kid,
                                            key_use,
                                            key_ops,
                                            alg,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          } else {
                            return $result.try$(
                              (() => {
                                let _pipe = $ec.public_key_from_raw_point(
                                  curve,
                                  raw_point,
                                );
                                return $result.replace_error(
                                  _pipe,
                                  new $gose.ParseError(
                                    "invalid EC public key coordinates",
                                  ),
                                );
                              })(),
                              (public$) => {
                                return new Ok(
                                  $gose.build(
                                    new $gose.Elliptic(
                                      new $gose.EcPublic(public$, curve),
                                    ),
                                    kid,
                                    key_use,
                                    key_ops,
                                    alg,
                                  ),
                                );
                              },
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
    },
  );
}

function ec_decoder() {
  return $decode.field(
    "crv",
    $decode.string,
    (crv) => {
      return $decode.field(
        "x",
        $decode.string,
        (x) => {
          return $decode.field(
            "y",
            $decode.string,
            (y) => {
              return $decode.optional_field(
                "d",
                $option.Option$None$const,
                $decode.optional($decode.string),
                (d) => {
                  return $decode.optional_field(
                    "kid",
                    $option.Option$None$const,
                    $decode.optional($decode.string),
                    (kid) => {
                      return $decode.optional_field(
                        "use",
                        $option.Option$None$const,
                        $decode.optional($decode.string),
                        (use_) => {
                          return $decode.optional_field(
                            "key_ops",
                            $option.Option$None$const,
                            $decode.optional($decode.list($decode.string)),
                            (key_ops) => {
                              return $decode.optional_field(
                                "alg",
                                $option.Option$None$const,
                                $decode.optional($decode.string),
                                (alg) => {
                                  return $decode.success(
                                    new EcDecoded(
                                      crv,
                                      x,
                                      y,
                                      d,
                                      kid,
                                      use_,
                                      key_ops,
                                      alg,
                                    ),
                                  );
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
            },
          );
        },
      );
    },
  );
}

function parse_ec_dynamic(dyn) {
  let $ = $decode.run(dyn, ec_decoder());
  if ($ instanceof Ok) {
    let decoded = $[0];
    return process_ec_decoded(decoded);
  } else {
    return new Error(new $gose.ParseError("invalid EC JSON"));
  }
}

function parse_rsa_private_key_components(
  n_bits,
  e_bits,
  d_bits,
  p_opt,
  q_opt,
  dp_opt,
  dq_opt,
  qi_opt
) {
  let crt_fields = toList([p_opt, q_opt, dp_opt, dq_opt, qi_opt]);
  let _block;
  let _pipe = crt_fields;
  let _pipe$1 = $list.filter(_pipe, $option.is_some);
  _block = $list.length(_pipe$1);
  let crt_present = _block;
  return $bool.guard(
    (crt_present > 0) && (crt_present < 5),
    new Error(
      new $gose.ParseError(
        "partial CRT fields: all five (p, q, dp, dq, qi) are required if any are present",
      ),
    ),
    () => {
      if (
        p_opt instanceof $option.Some &&
        q_opt instanceof $option.Some &&
        dp_opt instanceof $option.Some &&
        dq_opt instanceof $option.Some &&
        qi_opt instanceof $option.Some
      ) {
        let p_b64 = p_opt[0];
        let q_b64 = q_opt[0];
        let dp_b64 = dp_opt[0];
        let dq_b64 = dq_opt[0];
        let qi_b64 = qi_opt[0];
        return $result.try$(
          $utils.decode_base64_url(p_b64, "p"),
          (p_bits) => {
            return $result.try$(
              $utils.decode_base64_url(q_b64, "q"),
              (q_bits) => {
                return $result.try$(
                  $utils.decode_base64_url(dp_b64, "dp"),
                  (dp_bits) => {
                    return $result.try$(
                      $utils.decode_base64_url(dq_b64, "dq"),
                      (dq_bits) => {
                        return $result.try$(
                          $utils.decode_base64_url(qi_b64, "qi"),
                          (qi_bits) => {
                            let _pipe$2 = $rsa.from_full_components(
                              n_bits,
                              e_bits,
                              d_bits,
                              p_bits,
                              q_bits,
                              dp_bits,
                              dq_bits,
                              qi_bits,
                            );
                            return $result.replace_error(
                              _pipe$2,
                              new $gose.ParseError(
                                "invalid RSA private key components",
                              ),
                            );
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
      } else {
        let _pipe$2 = $rsa.from_components(n_bits, e_bits, d_bits);
        return $result.replace_error(
          _pipe$2,
          new $gose.ParseError("invalid RSA private key components"),
        );
      }
    },
  );
}

function process_rsa_decoded(decoded) {
  let n_b64 = decoded.n;
  let e_b64 = decoded.e;
  let d_opt = decoded.d;
  let p_opt = decoded.p;
  let q_opt = decoded.q;
  let dp_opt = decoded.dp;
  let dq_opt = decoded.dq;
  let qi_opt = decoded.qi;
  let kid = decoded.kid;
  let use_opt = decoded.use_;
  let key_ops_opt = decoded.key_ops;
  let alg_opt = decoded.alg;
  let oth = decoded.oth;
  return $bool.guard(
    oth,
    new Error(
      new $gose.ParseError("multi-prime RSA keys (oth parameter) not supported"),
    ),
    () => {
      return $result.try$(
        $utils.decode_base64_url(n_b64, "n"),
        (n_bits) => {
          return $result.try$(
            $utils.decode_base64_url(e_b64, "e"),
            (e_bits) => {
              return $result.try$(
                parse_key_metadata(use_opt, key_ops_opt, alg_opt),
                (_use0) => {
                  let key_use = _use0[0];
                  let key_ops = _use0[1];
                  let alg = _use0[2];
                  if (d_opt instanceof $option.Some) {
                    let d_b64 = d_opt[0];
                    return $result.try$(
                      $utils.decode_base64_url(d_b64, "d"),
                      (d_bits) => {
                        return $result.try$(
                          parse_rsa_private_key_components(
                            n_bits,
                            e_bits,
                            d_bits,
                            p_opt,
                            q_opt,
                            dp_opt,
                            dq_opt,
                            qi_opt,
                          ),
                          (_use0) => {
                            let private$ = _use0[0];
                            let public$ = _use0[1];
                            return new Ok(
                              $gose.build(
                                new $gose.Rsa(
                                  new $gose.RsaPrivate(private$, public$),
                                ),
                                kid,
                                key_use,
                                key_ops,
                                alg,
                              ),
                            );
                          },
                        );
                      },
                    );
                  } else {
                    return $result.try$(
                      (() => {
                        let _pipe = $rsa.public_key_from_components(
                          n_bits,
                          e_bits,
                        );
                        return $result.replace_error(
                          _pipe,
                          new $gose.ParseError(
                            "invalid RSA public key components",
                          ),
                        );
                      })(),
                      (public$) => {
                        return new Ok(
                          $gose.build(
                            new $gose.Rsa(new $gose.RsaPublic(public$)),
                            kid,
                            key_use,
                            key_ops,
                            alg,
                          ),
                        );
                      },
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
}

function rsa_decoder() {
  return $decode.field(
    "n",
    $decode.string,
    (n) => {
      return $decode.field(
        "e",
        $decode.string,
        (e) => {
          return $decode.optional_field(
            "d",
            $option.Option$None$const,
            $decode.optional($decode.string),
            (d) => {
              return $decode.optional_field(
                "p",
                $option.Option$None$const,
                $decode.optional($decode.string),
                (p) => {
                  return $decode.optional_field(
                    "q",
                    $option.Option$None$const,
                    $decode.optional($decode.string),
                    (q) => {
                      return $decode.optional_field(
                        "dp",
                        $option.Option$None$const,
                        $decode.optional($decode.string),
                        (dp) => {
                          return $decode.optional_field(
                            "dq",
                            $option.Option$None$const,
                            $decode.optional($decode.string),
                            (dq) => {
                              return $decode.optional_field(
                                "qi",
                                $option.Option$None$const,
                                $decode.optional($decode.string),
                                (qi) => {
                                  return $decode.optional_field(
                                    "kid",
                                    $option.Option$None$const,
                                    $decode.optional($decode.string),
                                    (kid) => {
                                      return $decode.optional_field(
                                        "use",
                                        $option.Option$None$const,
                                        $decode.optional($decode.string),
                                        (use_) => {
                                          return $decode.optional_field(
                                            "key_ops",
                                            $option.Option$None$const,
                                            $decode.optional(
                                              $decode.list($decode.string),
                                            ),
                                            (key_ops) => {
                                              return $decode.optional_field(
                                                "alg",
                                                $option.Option$None$const,
                                                $decode.optional($decode.string),
                                                (alg) => {
                                                  return $decode.optional_field(
                                                    "oth",
                                                    false,
                                                    $decode.success(true),
                                                    (oth) => {
                                                      return $decode.success(
                                                        new RsaDecoded(
                                                          n,
                                                          e,
                                                          d,
                                                          p,
                                                          q,
                                                          dp,
                                                          dq,
                                                          qi,
                                                          kid,
                                                          use_,
                                                          key_ops,
                                                          alg,
                                                          oth,
                                                        ),
                                                      );
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
            },
          );
        },
      );
    },
  );
}

function parse_rsa_dynamic(dyn) {
  let $ = $decode.run(dyn, rsa_decoder());
  if ($ instanceof Ok) {
    let decoded = $[0];
    return process_rsa_decoded(decoded);
  } else {
    return new Error(new $gose.ParseError("invalid RSA JSON"));
  }
}

function process_oct_decoded(decoded) {
  let k_b64 = decoded.k;
  let kid = decoded.kid;
  let use_opt = decoded.use_;
  let key_ops_opt = decoded.key_ops;
  let alg_opt = decoded.alg;
  return $result.try$(
    $utils.decode_base64_url(k_b64, "k"),
    (secret) => {
      return $result.try$(
        parse_key_metadata(use_opt, key_ops_opt, alg_opt),
        (_use0) => {
          let key_use = _use0[0];
          let key_ops = _use0[1];
          let alg = _use0[2];
          let $ = $bit_array.byte_size(secret) === 0;
          if ($) {
            return new Error(new $gose.ParseError("oct key must not be empty"));
          } else {
            return new Ok(
              $gose.build(
                new $gose.OctetKey(secret),
                kid,
                key_use,
                key_ops,
                alg,
              ),
            );
          }
        },
      );
    },
  );
}

function oct_decoder() {
  return $decode.field(
    "k",
    $decode.string,
    (k) => {
      return $decode.optional_field(
        "kid",
        $option.Option$None$const,
        $decode.optional($decode.string),
        (kid) => {
          return $decode.optional_field(
            "use",
            $option.Option$None$const,
            $decode.optional($decode.string),
            (use_) => {
              return $decode.optional_field(
                "key_ops",
                $option.Option$None$const,
                $decode.optional($decode.list($decode.string)),
                (key_ops) => {
                  return $decode.optional_field(
                    "alg",
                    $option.Option$None$const,
                    $decode.optional($decode.string),
                    (alg) => {
                      return $decode.success(
                        new OctDecoded(k, kid, use_, key_ops, alg),
                      );
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

function parse_oct_dynamic(dyn) {
  let $ = $decode.run(dyn, oct_decoder());
  if ($ instanceof Ok) {
    let decoded = $[0];
    return process_oct_decoded(decoded);
  } else {
    return new Error(new $gose.ParseError("invalid oct JSON"));
  }
}

function build_xdh_material(curve, x_bits, d_opt) {
  if (d_opt instanceof $option.Some) {
    let d_b64 = d_opt[0];
    return $result.try$(
      $utils.decode_base64_url(d_b64, "d"),
      (d_bits) => {
        return $result.try$(
          (() => {
            let _pipe = $xdh.from_bytes(curve, d_bits);
            return $result.replace_error(
              _pipe,
              new $gose.ParseError("invalid private key bytes"),
            );
          })(),
          (_use0) => {
            let private$ = _use0[0];
            let public$ = _use0[1];
            let computed_x = $xdh.public_key_to_bytes(public$);
            return $bool.guard(
              !$crypto.constant_time_equal(computed_x, x_bits),
              new Error(
                new $gose.ParseError("x does not match computed public key"),
              ),
              () => {
                return new Ok(
                  new $gose.Xdh(new $gose.XdhPrivate(private$, public$, curve)),
                );
              },
            );
          },
        );
      },
    );
  } else {
    return $result.try$(
      (() => {
        let _pipe = $xdh.public_key_from_bytes(curve, x_bits);
        return $result.replace_error(
          _pipe,
          new $gose.ParseError("invalid public key bytes"),
        );
      })(),
      (public$) => {
        return new Ok(new $gose.Xdh(new $gose.XdhPublic(public$, curve)));
      },
    );
  }
}

function parse_xdh_okp_json(curve, x_bits, d_opt, kid, key_use, key_ops, alg) {
  return $result.try$(
    build_xdh_material(curve, x_bits, d_opt),
    (material) => {
      return $result.try$(
        $gose.validate_rfc8037_key_use_public(material, key_use),
        (_) => {
          return new Ok($gose.build(material, kid, key_use, key_ops, alg));
        },
      );
    },
  );
}

function build_eddsa_material(curve, x_bits, d_opt) {
  if (d_opt instanceof $option.Some) {
    let d_b64 = d_opt[0];
    return $result.try$(
      $utils.decode_base64_url(d_b64, "d"),
      (d_bits) => {
        return $result.try$(
          (() => {
            let _pipe = $eddsa.from_bytes(curve, d_bits);
            return $result.replace_error(
              _pipe,
              new $gose.ParseError("invalid private key bytes"),
            );
          })(),
          (_use0) => {
            let private$ = _use0[0];
            let public$ = _use0[1];
            let computed_x = $eddsa.public_key_to_bytes(public$);
            return $bool.guard(
              !$crypto.constant_time_equal(computed_x, x_bits),
              new Error(
                new $gose.ParseError("x does not match computed public key"),
              ),
              () => {
                return new Ok(
                  new $gose.Edwards(
                    new $gose.EddsaPrivate(private$, public$, curve),
                  ),
                );
              },
            );
          },
        );
      },
    );
  } else {
    return $result.try$(
      (() => {
        let _pipe = $eddsa.public_key_from_bytes(curve, x_bits);
        return $result.replace_error(
          _pipe,
          new $gose.ParseError("invalid public key bytes"),
        );
      })(),
      (public$) => {
        return new Ok(new $gose.Edwards(new $gose.EddsaPublic(public$, curve)));
      },
    );
  }
}

function parse_eddsa_okp_json(curve, x_bits, d_opt, kid, key_use, key_ops, alg) {
  return $result.try$(
    build_eddsa_material(curve, x_bits, d_opt),
    (material) => {
      return $result.try$(
        $gose.validate_rfc8037_key_use_public(material, key_use),
        (_) => {
          return new Ok($gose.build(material, kid, key_use, key_ops, alg));
        },
      );
    },
  );
}

function process_okp_decoded(decoded) {
  let crv = decoded.crv;
  let x_b64 = decoded.x;
  let d_opt = decoded.d;
  let kid = decoded.kid;
  let use_opt = decoded.use_;
  let key_ops_opt = decoded.key_ops;
  let alg_opt = decoded.alg;
  return $result.try$(
    $utils.decode_base64_url(x_b64, "x"),
    (x_bits) => {
      return $result.try$(
        parse_key_metadata(use_opt, key_ops_opt, alg_opt),
        (_use0) => {
          let key_use = _use0[0];
          let key_ops = _use0[1];
          let alg = _use0[2];
          let $ = $utils.eddsa_curve_from_string(crv);
          if ($ instanceof Ok) {
            let eddsa_curve = $[0];
            return parse_eddsa_okp_json(
              eddsa_curve,
              x_bits,
              d_opt,
              kid,
              key_use,
              key_ops,
              alg,
            );
          } else {
            let $1 = $utils.xdh_curve_from_string(crv);
            if ($1 instanceof Ok) {
              let xdh_curve = $1[0];
              return parse_xdh_okp_json(
                xdh_curve,
                x_bits,
                d_opt,
                kid,
                key_use,
                key_ops,
                alg,
              );
            } else {
              return new Error(
                new $gose.ParseError("unsupported OKP curve: " + crv),
              );
            }
          }
        },
      );
    },
  );
}

function okp_decoder() {
  return $decode.field(
    "crv",
    $decode.string,
    (crv) => {
      return $decode.field(
        "x",
        $decode.string,
        (x) => {
          return $decode.optional_field(
            "d",
            $option.Option$None$const,
            $decode.optional($decode.string),
            (d) => {
              return $decode.optional_field(
                "kid",
                $option.Option$None$const,
                $decode.optional($decode.string),
                (kid) => {
                  return $decode.optional_field(
                    "use",
                    $option.Option$None$const,
                    $decode.optional($decode.string),
                    (use_) => {
                      return $decode.optional_field(
                        "key_ops",
                        $option.Option$None$const,
                        $decode.optional($decode.list($decode.string)),
                        (key_ops) => {
                          return $decode.optional_field(
                            "alg",
                            $option.Option$None$const,
                            $decode.optional($decode.string),
                            (alg) => {
                              return $decode.success(
                                new OkpDecoded(
                                  crv,
                                  x,
                                  d,
                                  kid,
                                  use_,
                                  key_ops,
                                  alg,
                                ),
                              );
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
        },
      );
    },
  );
}

function parse_okp_dynamic(dyn) {
  let $ = $decode.run(dyn, okp_decoder());
  if ($ instanceof Ok) {
    let decoded = $[0];
    return process_okp_decoded(decoded);
  } else {
    return new Error(new $gose.ParseError("invalid OKP JSON"));
  }
}

/**
 * Parse a JWK from a Dynamic value (decoded JSON).
 * 
 * @ignore
 */
export function from_dynamic(dyn) {
  return $result.try$(
    reject_x509_params(dyn),
    (_) => {
      let kty_decoder = $decode.at(toList(["kty"]), $decode.string);
      return $result.try$(
        (() => {
          let _pipe = $decode.run(dyn, kty_decoder);
          return $result.replace_error(
            _pipe,
            new $gose.ParseError("missing or invalid kty"),
          );
        })(),
        (kty) => {
          if (kty === "OKP") {
            return parse_okp_dynamic(dyn);
          } else if (kty === "oct") {
            return parse_oct_dynamic(dyn);
          } else if (kty === "RSA") {
            return parse_rsa_dynamic(dyn);
          } else if (kty === "EC") {
            return parse_ec_dynamic(dyn);
          } else {
            return new Error(new $gose.ParseError("unsupported kty: " + kty));
          }
        },
      );
    },
  );
}

/**
 * Parse a JWK from JSON.
 */
export function from_json(json_str) {
  return $result.try$(
    (() => {
      let _pipe = $json.parse(json_str, $decode.dynamic);
      return $result.replace_error(_pipe, new $gose.ParseError("invalid JSON"));
    })(),
    (dyn) => { return from_dynamic(dyn); },
  );
}

/**
 * Parse a JWK from JSON provided as a `BitArray`.
 */
export function from_json_bits(json_bits) {
  return $result.try$(
    (() => {
      let _pipe = $json.parse_bits(json_bits, $decode.dynamic);
      return $result.replace_error(_pipe, new $gose.ParseError("invalid JSON"));
    })(),
    (dyn) => { return from_dynamic(dyn); },
  );
}

/**
 * Return a decoder for JWK values.
 *
 * This lets you compose JWK decoding inside larger decode pipelines, for
 * example with `decode.field`, `decode.list`, or `json.parse`.
 *
 * ## Example
 *
 * ```gleam
 * // Parse a key directly from a JSON string
 * let assert Ok(k) = json.parse(json_string, jwk.decoder())
 *
 * // Use inside a larger decoder
 * use k <- decode.field("signing_key", jwk.decoder())
 * ```
 */
export function decoder() {
  let placeholder = $gose.build(
    new $gose.OctetKey(toBitArray([])),
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
    $option.Option$None$const,
  );
  return $decode.new_primitive_decoder(
    "Key",
    (dyn) => {
      let _pipe = from_dynamic(dyn);
      return $result.replace_error(_pipe, placeholder);
    },
  );
}

function thumbprint_json(k) {
  let $ = $gose.material(k);
  if ($ instanceof $gose.OctetKey) {
    let secret = $.secret;
    let k$1 = $utils.encode_base64_url(secret);
    return new Ok(("{\"k\":\"" + k$1) + "\",\"kty\":\"oct\"}");
  } else if ($ instanceof $gose.Rsa) {
    let $1 = $[0];
    if ($1 instanceof $gose.RsaPrivate) {
      let public$ = $1.public;
      let _block;
      let _pipe = $rsa.public_key_exponent_bytes(public$);
      let _pipe$1 = $utils.strip_leading_zeros(_pipe);
      _block = $utils.encode_base64_url(_pipe$1);
      let e = _block;
      let _block$1;
      let _pipe$2 = $rsa.public_key_modulus(public$);
      let _pipe$3 = $utils.strip_leading_zeros(_pipe$2);
      _block$1 = $utils.encode_base64_url(_pipe$3);
      let n = _block$1;
      return new Ok(
        ((("{\"e\":\"" + e) + "\",\"kty\":\"RSA\",\"n\":\"") + n) + "\"}",
      );
    } else {
      let public$ = $1.key;
      let _block;
      let _pipe = $rsa.public_key_exponent_bytes(public$);
      let _pipe$1 = $utils.strip_leading_zeros(_pipe);
      _block = $utils.encode_base64_url(_pipe$1);
      let e = _block;
      let _block$1;
      let _pipe$2 = $rsa.public_key_modulus(public$);
      let _pipe$3 = $utils.strip_leading_zeros(_pipe$2);
      _block$1 = $utils.encode_base64_url(_pipe$3);
      let n = _block$1;
      return new Ok(
        ((("{\"e\":\"" + e) + "\",\"kty\":\"RSA\",\"n\":\"") + n) + "\"}",
      );
    }
  } else if ($ instanceof $gose.Elliptic) {
    let $1 = $[0];
    if ($1 instanceof $gose.EcPrivate) {
      let public$ = $1.public;
      let curve = $1.curve;
      return $result.try$(
        $gose.ec_raw_coordinates(public$, curve),
        (_use0) => {
          let x = _use0[0];
          let y = _use0[1];
          let crv = $utils.ec_curve_to_string(curve);
          let x_b64 = $utils.encode_base64_url(x);
          let y_b64 = $utils.encode_base64_url(y);
          return new Ok(
            ((((("{\"crv\":\"" + crv) + "\",\"kty\":\"EC\",\"x\":\"") + x_b64) + "\",\"y\":\"") + y_b64) + "\"}",
          );
        },
      );
    } else {
      let public$ = $1.key;
      let curve = $1.curve;
      return $result.try$(
        $gose.ec_raw_coordinates(public$, curve),
        (_use0) => {
          let x = _use0[0];
          let y = _use0[1];
          let crv = $utils.ec_curve_to_string(curve);
          let x_b64 = $utils.encode_base64_url(x);
          let y_b64 = $utils.encode_base64_url(y);
          return new Ok(
            ((((("{\"crv\":\"" + crv) + "\",\"kty\":\"EC\",\"x\":\"") + x_b64) + "\",\"y\":\"") + y_b64) + "\"}",
          );
        },
      );
    }
  } else if ($ instanceof $gose.Edwards) {
    let $1 = $[0];
    if ($1 instanceof $gose.EddsaPrivate) {
      let public$ = $1.public;
      let curve = $1.curve;
      let crv = $utils.eddsa_curve_to_string(curve);
      let _block;
      let _pipe = $eddsa.public_key_to_bytes(public$);
      _block = $utils.encode_base64_url(_pipe);
      let x = _block;
      return new Ok(
        ((("{\"crv\":\"" + crv) + "\",\"kty\":\"OKP\",\"x\":\"") + x) + "\"}",
      );
    } else {
      let public$ = $1.key;
      let curve = $1.curve;
      let crv = $utils.eddsa_curve_to_string(curve);
      let _block;
      let _pipe = $eddsa.public_key_to_bytes(public$);
      _block = $utils.encode_base64_url(_pipe);
      let x = _block;
      return new Ok(
        ((("{\"crv\":\"" + crv) + "\",\"kty\":\"OKP\",\"x\":\"") + x) + "\"}",
      );
    }
  } else {
    let $1 = $[0];
    if ($1 instanceof $gose.XdhPrivate) {
      let public$ = $1.public;
      let curve = $1.curve;
      let crv = $utils.xdh_curve_to_string(curve);
      let _block;
      let _pipe = $xdh.public_key_to_bytes(public$);
      _block = $utils.encode_base64_url(_pipe);
      let x = _block;
      return new Ok(
        ((("{\"crv\":\"" + crv) + "\",\"kty\":\"OKP\",\"x\":\"") + x) + "\"}",
      );
    } else {
      let public$ = $1.key;
      let curve = $1.curve;
      let crv = $utils.xdh_curve_to_string(curve);
      let _block;
      let _pipe = $xdh.public_key_to_bytes(public$);
      _block = $utils.encode_base64_url(_pipe);
      let x = _block;
      return new Ok(
        ((("{\"crv\":\"" + crv) + "\",\"kty\":\"OKP\",\"x\":\"") + x) + "\"}",
      );
    }
  }
}

/**
 * Compute the JWK Thumbprint ([RFC 7638](https://www.rfc-editor.org/rfc/rfc7638)).
 *
 * The thumbprint is a base64url-encoded hash of the canonical JSON
 * representation containing only the required public key members.
 * Private keys produce the same thumbprint as their corresponding public keys.
 *
 * RFC 7638 recommends SHA-256 as the hash, but allows other algorithms.
 *
 * ## Example
 *
 * ```gleam
 * let k = gose.generate_ec(ec.P256)
 * let assert Ok(thumbprint) = jwk.thumbprint(k, hash.Sha256)
 * ```
 */
export function thumbprint(key, algorithm) {
  return $result.try$(
    thumbprint_json(key),
    (json_str) => {
      let _pipe = $bit_array.from_string(json_str);
      let _pipe$1 = ((_capture) => { return $crypto.hash(algorithm, _capture); })(
        _pipe,
      );
      let _pipe$2 = $result.replace_error(
        _pipe$1,
        new $gose.CryptoError("hash algorithm not supported"),
      );
      return $result.map(_pipe$2, $utils.encode_base64_url);
    },
  );
}
