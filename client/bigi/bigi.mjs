import * as $bool from "../gleam_stdlib/gleam/bool.mjs";
import * as $decode from "../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $order from "../gleam_stdlib/gleam/order.mjs";
import * as $result from "../gleam_stdlib/gleam/result.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import {
  zero,
  one,
  n_one as negative_one,
  ten,
  from as from_int,
  from_string,
  from_bytes,
  to as to_int,
  to_string,
  to_bytes,
  compare,
  absolute,
  negate,
  add,
  subtract,
  multiply,
  divide,
  remainder,
  divide_no_zero,
  remainder_no_zero,
  modulo,
  modulo_no_zero,
  power,
  decode as internal_do_decode,
  decode as do_decode,
  bitwise_and,
  bitwise_exclusive_or,
  bitwise_not,
  bitwise_or,
  bitwise_shift_left,
  bitwise_shift_right,
  from_base2 as do_from_base2,
  from_base8 as do_from_base8,
  from_base16 as do_from_base16,
  to_base2,
  to_base8,
  to_base16,
} from "./bigi_ffi.mjs";
import {
  Ok,
  Error,
  List$Empty$const as $List$Empty$const,
  prepend as listPrepend,
  CustomType as $CustomType,
  makeError,
  isEqual,
} from "./gleam.mjs";

export {
  absolute,
  add,
  bitwise_and,
  bitwise_exclusive_or,
  bitwise_not,
  bitwise_or,
  bitwise_shift_left,
  bitwise_shift_right,
  compare,
  divide,
  divide_no_zero,
  do_decode,
  from_bytes,
  from_int,
  from_string,
  modulo,
  modulo_no_zero,
  multiply,
  negate,
  negative_one,
  one,
  power,
  remainder,
  remainder_no_zero,
  subtract,
  ten,
  to_base16,
  to_base2,
  to_base8,
  to_bytes,
  to_int,
  to_string,
  zero,
};

const FILEPATH = "src/bigi.gleam";

export class LittleEndian extends $CustomType {}
export const Endianness$LittleEndian$const = new LittleEndian();
export const Endianness$LittleEndian = () => Endianness$LittleEndian$const;
export const Endianness$isLittleEndian = (value) =>
  value instanceof LittleEndian;

export class BigEndian extends $CustomType {}
export const Endianness$BigEndian$const = new BigEndian();
export const Endianness$BigEndian = () => Endianness$BigEndian$const;
export const Endianness$isBigEndian = (value) => value instanceof BigEndian;

export class Signed extends $CustomType {}
export const Signedness$Signed$const = new Signed();
export const Signedness$Signed = () => Signedness$Signed$const;
export const Signedness$isSigned = (value) => value instanceof Signed;

export class Unsigned extends $CustomType {}
export const Signedness$Unsigned$const = new Unsigned();
export const Signedness$Unsigned = () => Signedness$Unsigned$const;
export const Signedness$isUnsigned = (value) => value instanceof Unsigned;

/**
 * Performs a *floored* integer division, which means that the result will
 * always be rounded towards negative infinity.
 *
 * If you want to perform truncated integer division (rounding towards zero),
 * use `divide` or `divide_no_zero` instead.
 *
 * Returns an error if the divisor is 0.
 */
export function floor_divide(dividend, divisor) {
  let z = zero();
  let $ = isEqual(divisor, z);
  if ($) {
    return new Error(undefined);
  } else {
    let $1 = compare(multiply(dividend, divisor), z);
    if ($1 instanceof $order.Lt) {
      let $2 = !isEqual(remainder(dividend, divisor), z);
      if ($2) {
        return new Ok(subtract(divide(dividend, divisor), one()));
      } else {
        return new Ok(divide(dividend, divisor));
      }
    } else {
      return new Ok(divide(dividend, divisor));
    }
  }
}

function get_digit(loop$bigint, loop$digits, loop$divisor) {
  while (true) {
    let bigint = loop$bigint;
    let digits = loop$digits;
    let divisor = loop$divisor;
    let $ = compare(bigint, divisor);
    if ($ instanceof $order.Lt) {
      let $1 = to_int(bigint);
      let digit;
      if ($1 instanceof Ok) {
        digit = $1[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "bigi",
          342,
          "get_digit",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 11791,
            end: 11828,
            pattern_start: 11802,
            pattern_end: 11811
          }
        )
      }
      return listPrepend(digit, digits);
    } else {
      let _block;
      let _pipe = remainder(bigint, divisor);
      _block = to_int(_pipe);
      let $1 = _block;
      let digit;
      if ($1 instanceof Ok) {
        digit = $1[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "bigi",
          346,
          "get_digit",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 11876,
            end: 11953,
            pattern_start: 11887,
            pattern_end: 11896
          }
        )
      }
      let digits$1 = listPrepend(digit, digits);
      loop$bigint = divide(bigint, divisor);
      loop$digits = digits$1;
      loop$divisor = divisor;
    }
  }
}

/**
 * Get the digits in a given bigint as a list of integers in base 10.
 *
 * The list is ordered starting from the most significant digit.
 */
export function digits(bigint) {
  return get_digit(bigint, $List$Empty$const, ten());
}

/**
 * Returns a decoder that decodes a Dynamic value into a big integer, if
 * possible.
 */
export function decoder() {
  return $decode.new_primitive_decoder("BigInt", internal_do_decode);
}

/**
 * Compares two big integers, returning the larger of the two.
 */
export function max(a, b) {
  let $ = compare(a, b);
  if ($ instanceof $order.Lt) {
    return b;
  } else {
    return a;
  }
}

/**
 * Compares two big integers, returning the smaller of the two.
 */
export function min(a, b) {
  let $ = compare(a, b);
  if ($ instanceof $order.Lt) {
    return a;
  } else {
    return b;
  }
}

/**
 * Restricts a big integer between a lower and upper bound.
 */
export function clamp(bigint, min_bound, max_bound) {
  let _pipe = bigint;
  let _pipe$1 = min(_pipe, max_bound);
  return max(_pipe$1, min_bound);
}

/**
 * Returns whether the big integer provided is odd.
 */
export function is_odd(bigint) {
  return !isEqual(remainder(bigint, from_int(2)), zero());
}

/**
 * Sums a list of big integers.
 *
 * Returns 0 if the list was empty.
 */
export function sum(bigints) {
  return $list.fold(bigints, zero(), add);
}

/**
 * Multiplies a list of big integers.
 *
 * Returns 1 if the list was empty.
 */
export function product(bigints) {
  return $list.fold(bigints, one(), multiply);
}

/**
 * Joins a list of digits into a single value. Returns an error if the base is
 * less than 2 or if the list contains a digit greater than or equal to the
 * specified base.
 */
export function undigits(digits, base) {
  let $ = base < 2;
  if ($) {
    return new Error(undefined);
  } else {
    let base$1 = from_int(base);
    return $list.try_fold(
      digits,
      zero(),
      (acc, digit) => {
        let digit$1 = from_int(digit);
        let $1 = compare(digit$1, base$1);
        if ($1 instanceof $order.Eq) {
          return new Error(undefined);
        } else if ($1 instanceof $order.Gt) {
          return new Error(undefined);
        } else {
          return new Ok(add(multiply(acc, base$1), digit$1));
        }
      },
    );
  }
}

/**
 * Parse a binary string into a big integer.
 *
 * The string may contain an optional dash at the start to denote a negative
 * number, followed by an optional `0b` prefix. Following those, only 0 and 1
 * are allowed. The string is NOT trimmed for whitespace.
 *
 * Note that no conversion is done for the number. This means that it is always
 * treated as unsigned, and will only be negative if it is preceded by a dash.
 * As an example, `"0b100"` returns 4, and `"-0b100"` returns -4.
 */
export function from_base2(base2) {
  let _block;
  if (base2.charCodeAt(0) === 45) {
    let rest = base2.slice(1);
    _block = [negative_one(), rest];
  } else {
    _block = [one(), base2];
  }
  let $ = _block;
  let sign = $[0];
  let rest = $[1];
  let _block$1;
  if (rest.startsWith("0b")) {
    let rest$1 = rest.slice(2);
    _block$1 = do_from_base2(rest$1);
  } else {
    _block$1 = do_from_base2(rest);
  }
  let maybe_parsed = _block$1;
  return $result.try$(
    maybe_parsed,
    (parsed) => { return new Ok(multiply(sign, parsed)); },
  );
}

/**
 * Parse an octal string into a big integer.
 *
 * The string may contain an optional dash at the start to denote a negative
 * number, followed by an optional `0o` prefix. Following those, only numbers 0
 * through 7 are allowed. The string is NOT trimmed for whitespace.
 */
export function from_base8(base8) {
  let _block;
  if (base8.charCodeAt(0) === 45) {
    let rest = base8.slice(1);
    _block = [negative_one(), rest];
  } else {
    _block = [one(), base8];
  }
  let $ = _block;
  let sign = $[0];
  let rest = $[1];
  let _block$1;
  if (rest.startsWith("0o")) {
    let rest$1 = rest.slice(2);
    _block$1 = do_from_base8(rest$1);
  } else {
    _block$1 = do_from_base8(rest);
  }
  let maybe_parsed = _block$1;
  return $result.try$(
    maybe_parsed,
    (parsed) => { return new Ok(multiply(sign, parsed)); },
  );
}

/**
 * Parse a hexadecimal string into a big integer.
 *
 * The string may contain an optional dash at the start to denote a negative
 * number, followed by an optional `0x` prefix. Following those, only numbers 0
 * through 9 and letters _a_ through _f_ are allowed. The string is NOT trimmed
 * for whitespace. The string may be upper, lower, or mixed case, but the
 * prefix `0x` must always be lower case.
 */
export function from_base16(base16) {
  let _block;
  if (base16.charCodeAt(0) === 45) {
    let rest = base16.slice(1);
    _block = [negative_one(), rest];
  } else {
    _block = [one(), base16];
  }
  let $ = _block;
  let sign = $[0];
  let rest = $[1];
  let _block$1;
  if (rest.startsWith("0x")) {
    let rest$1 = rest.slice(2);
    _block$1 = do_from_base16(rest$1);
  } else {
    _block$1 = do_from_base16(rest);
  }
  let maybe_parsed = _block$1;
  return $result.try$(
    maybe_parsed,
    (parsed) => { return new Ok(multiply(sign, parsed)); },
  );
}

/**
 * Parse a big integer from an arbitrary base.
 *
 * The passed alphabet function must return `Ok(n)` for a given character,
 * where _n_ is the base-10 numerical value of that character. This allows
 * using any kind of alphabet. The alphabet must contain enough characters to
 * cover the entire value range of the chosen base.
 *
 * The base must be positive and larger than 1.
 */
export function from_base(input, base, alphabet) {
  return $bool.guard(
    base <= 1,
    new Error(undefined),
    () => {
      let base_b = from_int(base);
      let _block;
      let _pipe = input;
      let _pipe$1 = $string.to_graphemes(_pipe);
      let _pipe$2 = $list.reverse(_pipe$1);
      _block = $list.try_fold(
        _pipe$2,
        [zero(), zero()],
        (acc, char) => {
          let value = acc[0];
          let i = acc[1];
          let $ = alphabet(char);
          if ($ instanceof Ok) {
            let int = $[0];
            if (int >= base) {
              return new Error(undefined);
            } else {
              let int = $[0];
              let $1 = power(base_b, i);
              let p;
              if ($1 instanceof Ok) {
                p = $1[0];
              } else {
                throw makeError(
                  "let_assert",
                  FILEPATH,
                  "bigi",
                  460,
                  "from_base",
                  "Pattern match failed, no pattern matched the value.",
                  {
                    value: $1,
                    start: 15697,
                    end: 15732,
                    pattern_start: 15708,
                    pattern_end: 15713
                  }
                )
              }
              let _block$1;
              let _pipe$3 = int;
              let _pipe$4 = from_int(_pipe$3);
              let _pipe$5 = multiply(_pipe$4, p);
              _block$1 = add(_pipe$5, value);
              let value$1 = _block$1;
              return new Ok([value$1, add(i, one())]);
            }
          } else {
            return $;
          }
        },
      );
      let res = _block;
      if (res instanceof Ok) {
        let res$1 = res[0][0];
        return new Ok(res$1);
      } else {
        return res;
      }
    },
  );
}

function do_to_base(loop$acc, loop$value, loop$base, loop$alphabet) {
  while (true) {
    let acc = loop$acc;
    let value = loop$value;
    let base = loop$base;
    let alphabet = loop$alphabet;
    let $ = compare(value, base);
    if ($ instanceof $order.Lt) {
      let $1 = to_int(value);
      let i;
      if ($1 instanceof Ok) {
        i = $1[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "bigi",
          534,
          "do_to_base",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 17930,
            end: 17962,
            pattern_start: 17941,
            pattern_end: 17946
          }
        )
      }
      let $2 = alphabet(i);
      if ($2 instanceof Ok) {
        let c = $2[0];
        return new Ok(c + acc);
      } else {
        return $2;
      }
    } else {
      let rem = remainder(value, base);
      let $1 = to_int(rem);
      let mod_i;
      if ($1 instanceof Ok) {
        mod_i = $1[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "bigi",
          545,
          "do_to_base",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 18217,
            end: 18251,
            pattern_start: 18228,
            pattern_end: 18237
          }
        )
      }
      let $2 = alphabet(mod_i);
      if ($2 instanceof Ok) {
        let c = $2[0];
        let acc$1 = c + acc;
        let new_value = divide(subtract(value, rem), base);
        loop$acc = acc$1;
        loop$value = new_value;
        loop$base = base;
        loop$alphabet = alphabet;
      } else {
        return $2;
      }
    }
  }
}

/**
 * Stringify a big integer into a number of arbitrary base.
 *
 * The passed alphabet function must return `Ok(c)` for a given base-10
 * integer, where _c_ is the symbol of that integer in the given base. This
 * allows using any kind of alphabet. The alphabet must contain enough symbols
 * to cover the entire value range of the chosen base.
 *
 * The base must be positive and larger than 1.
 */
export function to_base(input, base, alphabet) {
  return $bool.guard(
    base <= 1,
    new Error(undefined),
    () => {
      return $result.try$(
        do_to_base("", input, from_int(base), alphabet),
        (res) => {
          let _block;
          let $ = compare(input, zero());
          if ($ instanceof $order.Lt) {
            _block = "-";
          } else {
            _block = "";
          }
          let sign = _block;
          return new Ok(sign + res);
        },
      );
    },
  );
}
