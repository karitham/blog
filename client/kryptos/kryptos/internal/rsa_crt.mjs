import * as $bigi from "../../../bigi/bigi.mjs";
import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $order from "../../../gleam_stdlib/gleam/order.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import { Ok, Error, makeError, isEqual, toBitArray } from "../../gleam.mjs";
import * as $crypto from "../../kryptos/crypto.mjs";
import * as $utils from "../../kryptos/internal/utils.mjs";
import { modPow as mod_pow_ffi } from "../../kryptos_ffi.mjs";

const FILEPATH = "src/kryptos/internal/rsa_crt.gleam";

function to_bytes_trimmed(value, max_byte_len) {
  return $result.try$(
    $bigi.to_bytes(
      value,
      $bigi.Endianness$BigEndian$const,
      $bigi.Signedness$Unsigned$const,
      max_byte_len,
    ),
    (bytes) => { return new Ok($utils.strip_leading_zeros(bytes)); },
  );
}

function extended_gcd_loop(
  loop$old_r,
  loop$r,
  loop$old_s,
  loop$s,
  loop$old_t,
  loop$t
) {
  while (true) {
    let old_r = loop$old_r;
    let r = loop$r;
    let old_s = loop$old_s;
    let s = loop$s;
    let old_t = loop$old_t;
    let t = loop$t;
    let zero = $bigi.from_int(0);
    let $ = isEqual(r, zero);
    if ($) {
      return [old_r, old_s, old_t];
    } else {
      let $1 = $bigi.floor_divide(old_r, r);
      let q;
      if ($1 instanceof Ok) {
        q = $1[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "kryptos/internal/rsa_crt",
          263,
          "extended_gcd_loop",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 6764,
            end: 6829,
            pattern_start: 6775,
            pattern_end: 6780
          }
        )
      }
      let new_r = $bigi.subtract(old_r, $bigi.multiply(q, r));
      let new_s = $bigi.subtract(old_s, $bigi.multiply(q, s));
      let new_t = $bigi.subtract(old_t, $bigi.multiply(q, t));
      loop$old_r = r;
      loop$r = new_r;
      loop$old_s = s;
      loop$s = new_s;
      loop$old_t = t;
      loop$t = new_t;
    }
  }
}

function mod_inverse(a, mod) {
  let zero = $bigi.from_int(0);
  let one = $bigi.from_int(1);
  let $ = extended_gcd_loop(a, mod, one, zero, zero, one);
  let old_r = $[0];
  let old_s = $[1];
  let $1 = isEqual(old_r, one);
  if ($1) {
    let result = $bigi.modulo(old_s, mod);
    let $2 = $bigi.compare(result, zero) instanceof $order.Lt;
    if ($2) {
      return new Ok($bigi.add(result, mod));
    } else {
      return new Ok(result);
    }
  } else {
    return new Error(undefined);
  }
}

function gcd(loop$a, loop$b) {
  while (true) {
    let a = loop$a;
    let b = loop$b;
    let zero = $bigi.from_int(0);
    let $ = isEqual(b, zero);
    if ($) {
      return $bigi.absolute(a);
    } else {
      loop$a = b;
      loop$b = $bigi.modulo(a, b);
    }
  }
}

function compute_byte_length(loop$value, loop$len) {
  while (true) {
    let value = loop$value;
    let len = loop$len;
    let $ = $bigi.power($bigi.from_int(256), $bigi.from_int(len));
    let bound;
    if ($ instanceof Ok) {
      bound = $[0];
    } else {
      throw makeError(
        "let_assert",
        FILEPATH,
        "kryptos/internal/rsa_crt",
        117,
        "compute_byte_length",
        "Pattern match failed, no pattern matched the value.",
        {
          value: $,
          start: 3224,
          end: 3297,
          pattern_start: 3235,
          pattern_end: 3244
        }
      )
    }
    let $1 = $bigi.compare(value, bound) instanceof $order.Lt;
    if ($1) {
      return len;
    } else {
      loop$value = value;
      loop$len = len + 1;
    }
  }
}

function to_bytes_minimal(value) {
  let zero = $bigi.from_int(0);
  let $ = isEqual(value, zero);
  if ($) {
    return new Ok(toBitArray([0]));
  } else {
    let byte_len = compute_byte_length(value, 1);
    return $result.try$(
      $bigi.to_bytes(
        value,
        $bigi.Endianness$BigEndian$const,
        $bigi.Signedness$Unsigned$const,
        byte_len,
      ),
      (bytes) => { return new Ok($utils.strip_leading_zeros(bytes)); },
    );
  }
}

function mod_pow(base, exp, mod, byte_len) {
  return $result.try$(
    $bigi.to_bytes(
      base,
      $bigi.Endianness$BigEndian$const,
      $bigi.Signedness$Unsigned$const,
      byte_len,
    ),
    (base_bytes) => {
      return $result.try$(
        to_bytes_minimal(exp),
        (exp_bytes) => {
          return $result.try$(
            $bigi.to_bytes(
              mod,
              $bigi.Endianness$BigEndian$const,
              $bigi.Signedness$Unsigned$const,
              byte_len,
            ),
            (mod_bytes) => {
              let result_bytes = mod_pow_ffi(base_bytes, exp_bytes, mod_bytes);
              return $bigi.from_bytes(
                result_bytes,
                $bigi.Endianness$BigEndian$const,
                $bigi.Signedness$Unsigned$const,
              );
            },
          );
        },
      );
    },
  );
}

function try_factor_loop(n, t, x, i, byte_len) {
  let $ = i > t;
  if ($) {
    return new Error(undefined);
  } else {
    let one = $bigi.from_int(1);
    let two = $bigi.from_int(2);
    let n_minus_1 = $bigi.subtract(n, one);
    return $result.try$(
      mod_pow(x, two, n, byte_len),
      (y) => {
        let $1 = isEqual(y, one);
        if ($1) {
          let p = gcd($bigi.subtract(x, one), n);
          let $2 = ($bigi.compare(p, one) instanceof $order.Gt) && ($bigi.compare(
            p,
            n,
          ) instanceof $order.Lt);
          if ($2) {
            let $3 = $bigi.floor_divide(n, p);
            let q;
            if ($3 instanceof Ok) {
              q = $3[0];
            } else {
              throw makeError(
                "let_assert",
                FILEPATH,
                "kryptos/internal/rsa_crt",
                206,
                "try_factor_loop",
                "Pattern match failed, no pattern matched the value.",
                {
                  value: $3,
                  start: 5456,
                  end: 5517,
                  pattern_start: 5467,
                  pattern_end: 5472
                }
              )
            }
            let $4 = $bigi.compare(p, q) instanceof $order.Lt;
            if ($4) {
              return new Ok([p, q]);
            } else {
              return new Ok([q, p]);
            }
          } else {
            return new Error(undefined);
          }
        } else {
          let $2 = isEqual(y, n_minus_1);
          if ($2) {
            return new Error(undefined);
          } else {
            return try_factor_loop(n, t, y, i + 1, byte_len);
          }
        }
      },
    );
  }
}

function try_factor(n, t, x, byte_len) {
  let one = $bigi.from_int(1);
  let n_minus_1 = $bigi.subtract(n, one);
  let $ = (isEqual(x, one)) || (isEqual(x, n_minus_1));
  if ($) {
    return new Error(undefined);
  } else {
    return try_factor_loop(n, t, x, 1, byte_len);
  }
}

function factor_out_twos(loop$k, loop$two, loop$count) {
  while (true) {
    let k = loop$k;
    let two = loop$two;
    let count = loop$count;
    let $ = isEqual($bigi.modulo(k, two), $bigi.from_int(0));
    if ($) {
      let $1 = $bigi.floor_divide(k, two);
      let next;
      if ($1 instanceof Ok) {
        next = $1[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "kryptos/internal/rsa_crt",
          161,
          "factor_out_twos",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 4442,
            end: 4508,
            pattern_start: 4453,
            pattern_end: 4461
          }
        )
      }
      loop$k = next;
      loop$two = two;
      loop$count = count + 1;
    } else {
      return [count, k];
    }
  }
}

function factor_rsa_modulus(n, e, d, byte_len, attempts_left) {
  if (attempts_left === 0) {
    return new Error(undefined);
  } else {
    let one = $bigi.from_int(1);
    let two = $bigi.from_int(2);
    let three = $bigi.from_int(3);
    let k = $bigi.subtract($bigi.multiply(e, d), one);
    let $ = factor_out_twos(k, two, 0);
    let t = $[0];
    let r = $[1];
    let g_bytes = $crypto.random_bytes(byte_len);
    let $1 = $bigi.from_bytes(
      g_bytes,
      $bigi.Endianness$BigEndian$const,
      $bigi.Signedness$Unsigned$const,
    );
    let g_raw;
    if ($1 instanceof Ok) {
      g_raw = $1[0];
    } else {
      throw makeError(
        "let_assert",
        FILEPATH,
        "kryptos/internal/rsa_crt",
        142,
        "factor_rsa_modulus",
        "Pattern match failed, no pattern matched the value.",
        {
          value: $1,
          start: 3871,
          end: 3957,
          pattern_start: 3882,
          pattern_end: 3891
        }
      )
    }
    let n_minus_3 = $bigi.subtract(n, three);
    let g = $bigi.add($bigi.modulo(g_raw, n_minus_3), two);
    return $result.try$(
      mod_pow(g, r, n, byte_len),
      (x) => {
        let $2 = try_factor(n, t, x, byte_len);
        if ($2 instanceof Ok) {
          return $2;
        } else {
          return factor_rsa_modulus(n, e, d, byte_len, attempts_left - 1);
        }
      },
    );
  }
}

function validate_components(n, e, d, next) {
  let zero = $bigi.from_int(0);
  let one = $bigi.from_int(1);
  let $ = (($bigi.compare(n, one) instanceof $order.Gt) && ($bigi.compare(
    e,
    one,
  ) instanceof $order.Gt)) && ($bigi.compare(d, zero) instanceof $order.Gt);
  if ($) {
    return next();
  } else {
    return new Error(undefined);
  }
}

/**
 * Compute CRT parameters from minimal RSA components. This is used for
 * loading RSA keys where only the modulus, public exponent, and private
 * exponent are known. The JS implementation requires the precomputed
 * parameters to be provided as well.
 */
export function compute_crt_params(n_bytes, e_bytes, d_bytes) {
  return $result.try$(
    $bigi.from_bytes(
      n_bytes,
      $bigi.Endianness$BigEndian$const,
      $bigi.Signedness$Unsigned$const,
    ),
    (n) => {
      return $result.try$(
        $bigi.from_bytes(
          e_bytes,
          $bigi.Endianness$BigEndian$const,
          $bigi.Signedness$Unsigned$const,
        ),
        (e) => {
          return $result.try$(
            $bigi.from_bytes(
              d_bytes,
              $bigi.Endianness$BigEndian$const,
              $bigi.Signedness$Unsigned$const,
            ),
            (d) => {
              return validate_components(
                n,
                e,
                d,
                () => {
                  let byte_len = $bit_array.byte_size(n_bytes);
                  return $result.try$(
                    factor_rsa_modulus(n, e, d, byte_len, 500),
                    (_use0) => {
                      let p = _use0[0];
                      let q = _use0[1];
                      let one = $bigi.from_int(1);
                      let dp = $bigi.modulo(d, $bigi.subtract(p, one));
                      let dq = $bigi.modulo(d, $bigi.subtract(q, one));
                      return $result.try$(
                        mod_inverse(q, p),
                        (qi) => {
                          return $result.try$(
                            to_bytes_trimmed(p, byte_len),
                            (p_bytes) => {
                              return $result.try$(
                                to_bytes_trimmed(q, byte_len),
                                (q_bytes) => {
                                  return $result.try$(
                                    to_bytes_trimmed(dp, byte_len),
                                    (dp_bytes) => {
                                      return $result.try$(
                                        to_bytes_trimmed(dq, byte_len),
                                        (dq_bytes) => {
                                          return $result.try$(
                                            to_bytes_trimmed(qi, byte_len),
                                            (qi_bytes) => {
                                              return new Ok(
                                                [
                                                  p_bytes,
                                                  q_bytes,
                                                  dp_bytes,
                                                  dq_bytes,
                                                  qi_bytes,
                                                ],
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
