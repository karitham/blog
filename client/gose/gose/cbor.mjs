import * as $bit_array from "../../gleam_stdlib/gleam/bit_array.mjs";
import * as $float from "../../gleam_stdlib/gleam/float.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $order from "../../gleam_stdlib/gleam/order.mjs";
import * as $pair from "../../gleam_stdlib/gleam/pair.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";
import {
  Ok,
  Error,
  toList,
  prepend as listPrepend,
  CustomType as $CustomType,
  makeError,
  toBitArray,
  bitArraySlice,
  bitArraySliceToFloat,
  bitArraySliceToInt,
  sizedInt,
  sizedFloat,
} from "../gleam.mjs";
import * as $gose from "../gose.mjs";

const FILEPATH = "src/gose/cbor.gleam";

/**
 * An integer, positive or negative.
 */
export class Int extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Value$Int = ($0) => new Int($0);
export const Value$isInt = (value) => value instanceof Int;
export const Value$Int$0 = (value) => value[0];

/**
 * A byte string.
 */
export class Bytes extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Value$Bytes = ($0) => new Bytes($0);
export const Value$isBytes = (value) => value instanceof Bytes;
export const Value$Bytes$0 = (value) => value[0];

/**
 * A UTF-8 text string.
 */
export class Text extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Value$Text = ($0) => new Text($0);
export const Value$isText = (value) => value instanceof Text;
export const Value$Text$0 = (value) => value[0];

/**
 * An ordered array of data items.
 */
export class Array extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Value$Array = ($0) => new Array($0);
export const Value$isArray = (value) => value instanceof Array;
export const Value$Array$0 = (value) => value[0];

/**
 * A map of key-value pairs. On encoding, pairs are sorted in bytewise
 * lexicographic order of their encoded keys (core deterministic encoding).
 */
export class Map extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Value$Map = ($0) => new Map($0);
export const Value$isMap = (value) => value instanceof Map;
export const Value$Map$0 = (value) => value[0];

/**
 * A tagged data item (tag number and content).
 */
export class Tag extends $CustomType {
  constructor($0, $1) {
    super();
    this[0] = $0;
    this[1] = $1;
  }
}
export const Value$Tag = ($0, $1) => new Tag($0, $1);
export const Value$isTag = (value) => value instanceof Tag;
export const Value$Tag$0 = (value) => value[0];
export const Value$Tag$1 = (value) => value[1];

/**
 * A boolean.
 */
export class Bool extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Value$Bool = ($0) => new Bool($0);
export const Value$isBool = (value) => value instanceof Bool;
export const Value$Bool$0 = (value) => value[0];

/**
 * A floating-point number.
 */
export class Float extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const Value$Float = ($0) => new Float($0);
export const Value$isFloat = (value) => value instanceof Float;
export const Value$Float$0 = (value) => value[0];

/**
 * Null.
 */
export class Null extends $CustomType {}
export const Value$Null = () => new Null();
export const Value$isNull = (value) => value instanceof Null;

function encode_major_with_argument(major, value) {
  let major_bits = $int.bitwise_shift_left(major, 5);
  let v = value;
  if (v < 24) {
    return toBitArray([(major_bits + v)]);
  } else {
    let v = value;
    if (v < 256) {
      return toBitArray([(major_bits + 24), v]);
    } else {
      let v = value;
      if (v < 65_536) {
        return toBitArray([(major_bits + 25), sizedInt(v, 16, true)]);
      } else {
        let v = value;
        if (v < 4_294_967_296) {
          return toBitArray([(major_bits + 26), sizedInt(v, 32, true)]);
        } else {
          let v = value;
          return toBitArray([(major_bits + 27), sizedInt(v, 64, true)]);
        }
      }
    }
  }
}

function compare_bit_arrays(loop$a, loop$b) {
  while (true) {
    let a = loop$a;
    let b = loop$b;
    if (a.bitSize === 0) {
      if (b.bitSize === 0) {
        return new $order.Eq();
      } else {
        return new $order.Lt();
      }
    } else if (b.bitSize === 0) {
      return new $order.Gt();
    } else if (a.bitSize >= 8 && b.bitSize >= 8) {
      let byte_a = a.byteAt(0);
      let rest_a = bitArraySlice(a, 8);
      let byte_b = b.byteAt(0);
      let rest_b = bitArraySlice(b, 8);
      let $ = $int.compare(byte_a, byte_b);
      if ($ instanceof $order.Eq) {
        loop$a = rest_a;
        loop$b = rest_b;
      } else {
        return $;
      }
    } else {
      throw makeError(
        "panic",
        FILEPATH,
        "gose/cbor",
        155,
        "compare_bit_arrays",
        "non-byte-aligned CBOR in map key sort",
        {}
      )
    }
  }
}

function encode_text(s) {
  let bytes = $bit_array.from_string(s);
  let length = $bit_array.byte_size(bytes);
  return $bit_array.append(encode_major_with_argument(3, length), bytes);
}

function encode_bytes(b) {
  let length = $bit_array.byte_size(b);
  return $bit_array.append(encode_major_with_argument(2, length), b);
}

function encode_int(n) {
  let $ = n >= 0;
  if ($) {
    return encode_major_with_argument(0, n);
  } else {
    return encode_major_with_argument(1, -1 - n);
  }
}

function encode_tag(tag, content) {
  return $bit_array.append(encode_major_with_argument(6, tag), encode(content));
}

function sort_map_pairs(pairs) {
  return $list.sort(
    pairs,
    (a, b) => {
      let encoded_a = encode(a[0]);
      let encoded_b = encode(b[0]);
      return compare_bit_arrays(encoded_a, encoded_b);
    },
  );
}

function encode_map(pairs) {
  let sorted = sort_map_pairs(pairs);
  let length = $list.length(sorted);
  let header = encode_major_with_argument(5, length);
  return $list.fold(
    sorted,
    header,
    (acc, pair) => {
      let k = pair[0];
      let v = pair[1];
      let _pipe = acc;
      let _pipe$1 = $bit_array.append(_pipe, encode(k));
      return $bit_array.append(_pipe$1, encode(v));
    },
  );
}

function encode_array(items) {
  let length = $list.length(items);
  let header = encode_major_with_argument(4, length);
  let encoded_items = $list.map(items, encode);
  return $list.fold(encoded_items, header, $bit_array.append);
}

/**
 * Encode a CBOR value to bytes.
 *
 * Floats are always encoded as 64-bit doubles. Decoding handles all three
 * widths.
 * 
 * @ignore
 */
export function encode(value) {
  if (value instanceof Int) {
    let n = value[0];
    return encode_int(n);
  } else if (value instanceof Bytes) {
    let b = value[0];
    return encode_bytes(b);
  } else if (value instanceof Text) {
    let s = value[0];
    return encode_text(s);
  } else if (value instanceof Array) {
    let items = value[0];
    return encode_array(items);
  } else if (value instanceof Map) {
    let pairs = value[0];
    return encode_map(pairs);
  } else if (value instanceof Tag) {
    let tag = value[0];
    let content = value[1];
    return encode_tag(tag, content);
  } else if (value instanceof Bool) {
    let $ = value[0];
    if ($) {
      return toBitArray([245]);
    } else {
      return toBitArray([244]);
    }
  } else if (value instanceof Float) {
    let f = value[0];
    return toBitArray([251, sizedFloat(f, 64, true)]);
  } else {
    return toBitArray([246]);
  }
}

function decode_f64(rest) {
  if (rest.bitSize >= 1 && rest.bitSize >= 12) {
    if (bitArraySliceToInt(rest, 1, 12, true, false) === 2047) {
      if (rest.bitSize >= 64) {
        return new Error(
          new $gose.ParseError("NaN and Infinity are not supported"),
        );
      } else {
        return new Error(new $gose.ParseError("truncated CBOR float64"));
      }
    } else if (
      rest.bitSize >= 64 &&
      Number.isFinite(bitArraySliceToFloat(rest, 0, 64, true))
    ) {
      let f = bitArraySliceToFloat(rest, 0, 64, true);
      let remainder = bitArraySlice(rest, 64);
      return new Ok([new Float(f), remainder]);
    } else {
      return new Error(new $gose.ParseError("truncated CBOR float64"));
    }
  } else {
    return new Error(new $gose.ParseError("truncated CBOR float64"));
  }
}

function decode_f32(rest) {
  if (rest.bitSize >= 1 && rest.bitSize >= 9) {
    if (bitArraySliceToInt(rest, 1, 9, true, false) === 255) {
      if (rest.bitSize >= 32) {
        return new Error(
          new $gose.ParseError("NaN and Infinity are not supported"),
        );
      } else {
        return new Error(new $gose.ParseError("truncated CBOR float32"));
      }
    } else if (
      rest.bitSize >= 32 &&
      Number.isFinite(bitArraySliceToFloat(rest, 0, 32, true))
    ) {
      let f = bitArraySliceToFloat(rest, 0, 32, true);
      let remainder = bitArraySlice(rest, 32);
      return new Ok([new Float(f), remainder]);
    } else {
      return new Error(new $gose.ParseError("truncated CBOR float32"));
    }
  } else {
    return new Error(new $gose.ParseError("truncated CBOR float32"));
  }
}

function do_exp2(loop$n, loop$acc) {
  while (true) {
    let n = loop$n;
    let acc = loop$acc;
    if (n === 0) {
      return acc;
    } else if (n > 0) {
      loop$n = n - 1;
      loop$acc = acc * 2.0;
    } else {
      loop$n = n + 1;
      loop$acc = acc / 2.0;
    }
  }
}

function exp2(n) {
  return do_exp2(n, 1.0);
}

function convert_f16_to_f64(sign, exponent, mantissa) {
  let _block;
  if (sign === 0) {
    _block = 1.0;
  } else {
    _block = -1.0;
  }
  let sign_factor = _block;
  if (exponent === 0) {
    if (mantissa === 0) {
      return new Ok(sign_factor * 0.0);
    } else {
      let m = $int.to_float(mantissa) / 1024.0;
      return new Ok((sign_factor * m) * exp2(-14));
    }
  } else if (exponent === 31) {
    return new Error(new $gose.ParseError("NaN and Infinity are not supported"));
  } else {
    let m = 1.0 + ($int.to_float(mantissa) / 1024.0);
    return new Ok((sign_factor * m) * exp2(exponent - 15));
  }
}

function decode_f16(rest) {
  if (rest.bitSize >= 1 && rest.bitSize >= 6 && rest.bitSize >= 16) {
    let sign = bitArraySliceToInt(rest, 0, 1, true, false);
    let exponent = bitArraySliceToInt(rest, 1, 6, true, false);
    let mantissa = bitArraySliceToInt(rest, 6, 16, true, false);
    let remainder = bitArraySlice(rest, 16);
    return $result.try$(
      convert_f16_to_f64(sign, exponent, mantissa),
      (f) => { return new Ok([new Float(f), remainder]); },
    );
  } else {
    return new Error(new $gose.ParseError("truncated CBOR float16"));
  }
}

function decode_simple(info, rest) {
  if (info === 20) {
    return new Ok([new Bool(false), rest]);
  } else if (info === 21) {
    return new Ok([new Bool(true), rest]);
  } else if (info === 22) {
    return new Ok([new Null(), rest]);
  } else if (info === 25) {
    return decode_f16(rest);
  } else if (info === 26) {
    return decode_f32(rest);
  } else if (info === 27) {
    return decode_f64(rest);
  } else {
    return new Error(
      new $gose.ParseError(
        "unsupported CBOR simple value: " + $int.to_string(info),
      ),
    );
  }
}

function decode_argument(info, rest) {
  let n = info;
  if (n < 24) {
    return new Ok([n, rest]);
  } else if (info === 24) {
    if (rest.bitSize >= 8) {
      let value = rest.byteAt(0);
      let remainder = bitArraySlice(rest, 8);
      return new Ok([value, remainder]);
    } else {
      return new Error(new $gose.ParseError("truncated CBOR argument"));
    }
  } else if (info === 25) {
    if (rest.bitSize >= 16) {
      let value = bitArraySliceToInt(rest, 0, 16, true, false);
      let remainder = bitArraySlice(rest, 16);
      return new Ok([value, remainder]);
    } else {
      return new Error(new $gose.ParseError("truncated CBOR argument"));
    }
  } else if (info === 26) {
    if (rest.bitSize >= 32) {
      let value = bitArraySliceToInt(rest, 0, 32, true, false);
      let remainder = bitArraySlice(rest, 32);
      return new Ok([value, remainder]);
    } else {
      return new Error(new $gose.ParseError("truncated CBOR argument"));
    }
  } else if (info === 27) {
    if (rest.bitSize >= 64) {
      let value = bitArraySliceToInt(rest, 0, 64, true, false);
      let remainder = bitArraySlice(rest, 64);
      return new Ok([value, remainder]);
    } else {
      return new Error(new $gose.ParseError("truncated CBOR argument"));
    }
  } else {
    return new Error(
      new $gose.ParseError(
        "invalid CBOR additional info: " + $int.to_string(info),
      ),
    );
  }
}

function decode_text_string(info, rest) {
  return $result.try$(
    decode_argument(info, rest),
    (_use0) => {
      let length = _use0[0];
      let after_length = _use0[1];
      let remaining_size = $bit_array.byte_size(after_length);
      let $ = length > remaining_size;
      if ($) {
        return new Error(new $gose.ParseError("truncated CBOR text string"));
      } else {
        let $1 = $bit_array.slice(after_length, 0, length);
        let bytes;
        if ($1 instanceof Ok) {
          bytes = $1[0];
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "gose/cbor",
            255,
            "decode_text_string",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $1,
              start: 7490,
              end: 7553,
              pattern_start: 7501,
              pattern_end: 7510
            }
          )
        }
        let $2 = $bit_array.slice(after_length, length, remaining_size - length);
        let remainder;
        if ($2 instanceof Ok) {
          remainder = $2[0];
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "gose/cbor",
            256,
            "decode_text_string",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $2,
              start: 7560,
              end: 7657,
              pattern_start: 7571,
              pattern_end: 7584
            }
          )
        }
        let $3 = $bit_array.to_string(bytes);
        if ($3 instanceof Ok) {
          let text = $3[0];
          return new Ok([new Text(text), remainder]);
        } else {
          return new Error(
            new $gose.ParseError("invalid UTF-8 in CBOR text string"),
          );
        }
      }
    },
  );
}

function decode_byte_string(info, rest) {
  return $result.try$(
    decode_argument(info, rest),
    (_use0) => {
      let length = _use0[0];
      let after_length = _use0[1];
      let remaining_size = $bit_array.byte_size(after_length);
      let $ = length > remaining_size;
      if ($) {
        return new Error(new $gose.ParseError("truncated CBOR byte string"));
      } else {
        let $1 = $bit_array.slice(after_length, 0, length);
        let bytes;
        if ($1 instanceof Ok) {
          bytes = $1[0];
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "gose/cbor",
            238,
            "decode_byte_string",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $1,
              start: 6919,
              end: 6982,
              pattern_start: 6930,
              pattern_end: 6939
            }
          )
        }
        let $2 = $bit_array.slice(after_length, length, remaining_size - length);
        let remainder;
        if ($2 instanceof Ok) {
          remainder = $2[0];
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "gose/cbor",
            239,
            "decode_byte_string",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $2,
              start: 6989,
              end: 7086,
              pattern_start: 7000,
              pattern_end: 7013
            }
          )
        }
        return new Ok([new Bytes(bytes), remainder]);
      }
    },
  );
}

function decode_negative_int(info, rest) {
  return $result.try$(
    decode_argument(info, rest),
    (_use0) => {
      let value = _use0[0];
      let remainder = _use0[1];
      return new Ok([new Int(-1 - value), remainder]);
    },
  );
}

function decode_unsigned_int(info, rest) {
  return $result.try$(
    decode_argument(info, rest),
    (_use0) => {
      let value = _use0[0];
      let remainder = _use0[1];
      return new Ok([new Int(value), remainder]);
    },
  );
}

function decode_tag(info, rest) {
  return $result.try$(
    decode_argument(info, rest),
    (_use0) => {
      let tag_number = _use0[0];
      let after_tag = _use0[1];
      return $result.try$(
        decode_with_remainder(after_tag),
        (_use0) => {
          let content = _use0[0];
          let remainder = _use0[1];
          return new Ok([new Tag(tag_number, content), remainder]);
        },
      );
    },
  );
}

function decode_n_pairs_loop(remaining, data, acc) {
  if (remaining === 0) {
    return new Ok([$list.reverse(acc), data]);
  } else {
    return $result.try$(
      decode_with_remainder(data),
      (_use0) => {
        let key = _use0[0];
        let after_key = _use0[1];
        return $result.try$(
          decode_with_remainder(after_key),
          (_use0) => {
            let value = _use0[0];
            let after_value = _use0[1];
            return decode_n_pairs_loop(
              remaining - 1,
              after_value,
              listPrepend([key, value], acc),
            );
          },
        );
      },
    );
  }
}

function decode_n_pairs(count, data) {
  return decode_n_pairs_loop(count, data, toList([]));
}

function decode_map(info, rest) {
  return $result.try$(
    decode_argument(info, rest),
    (_use0) => {
      let length = _use0[0];
      let after_length = _use0[1];
      return $result.try$(
        decode_n_pairs(length, after_length),
        (_use0) => {
          let pairs = _use0[0];
          let remainder = _use0[1];
          let keys = $list.map(pairs, $pair.first);
          let $ = $list.length($list.unique(keys)) === $list.length(keys);
          if ($) {
            return new Ok([new Map(pairs), remainder]);
          } else {
            return new Error(
              new $gose.ParseError("CBOR map contains duplicate keys"),
            );
          }
        },
      );
    },
  );
}

function decode_n_items_loop(remaining, data, acc) {
  if (remaining === 0) {
    return new Ok([$list.reverse(acc), data]);
  } else {
    return $result.try$(
      decode_with_remainder(data),
      (_use0) => {
        let item = _use0[0];
        let rest = _use0[1];
        return decode_n_items_loop(remaining - 1, rest, listPrepend(item, acc));
      },
    );
  }
}

function decode_n_items(count, data) {
  return decode_n_items_loop(count, data, toList([]));
}

function decode_array(info, rest) {
  return $result.try$(
    decode_argument(info, rest),
    (_use0) => {
      let length = _use0[0];
      let after_length = _use0[1];
      return $result.try$(
        decode_n_items(length, after_length),
        (_use0) => {
          let items = _use0[0];
          let remainder = _use0[1];
          return new Ok([new Array(items), remainder]);
        },
      );
    },
  );
}

function decode_major(major, info, rest) {
  if (major === 0) {
    return decode_unsigned_int(info, rest);
  } else if (major === 1) {
    return decode_negative_int(info, rest);
  } else if (major === 2) {
    return decode_byte_string(info, rest);
  } else if (major === 3) {
    return decode_text_string(info, rest);
  } else if (major === 4) {
    return decode_array(info, rest);
  } else if (major === 5) {
    return decode_map(info, rest);
  } else if (major === 6) {
    return decode_tag(info, rest);
  } else if (major === 7) {
    return decode_simple(info, rest);
  } else {
    return new Error(
      new $gose.ParseError(
        "unsupported CBOR major type: " + $int.to_string(major),
      ),
    );
  }
}

/**
 * Decode one CBOR value and return it along with any remaining bytes.
 * 
 * @ignore
 */
export function decode_with_remainder(data) {
  if (data.bitSize === 0) {
    return new Error(new $gose.ParseError("unexpected end of CBOR input"));
  } else if (data.bitSize >= 3 && data.bitSize >= 8) {
    let major = bitArraySliceToInt(data, 0, 3, true, false);
    let info = bitArraySliceToInt(data, 3, 8, true, false);
    let rest = bitArraySlice(data, 8);
    return decode_major(major, info, rest);
  } else {
    return new Error(new $gose.ParseError("truncated CBOR input"));
  }
}

/**
 * Decode a single CBOR value from bytes. Returns an error if there are
 * trailing bytes after the value.
 * 
 * @ignore
 */
export function decode(data) {
  return $result.try$(
    decode_with_remainder(data),
    (_use0) => {
      let value = _use0[0];
      let remainder = _use0[1];
      let $ = $bit_array.byte_size(remainder);
      if ($ === 0) {
        return new Ok(value);
      } else {
        return new Error(
          new $gose.ParseError("trailing bytes after CBOR value"),
        );
      }
    },
  );
}

/**
 * Format a value as CBOR diagnostic notation ([RFC 8949 Section 8](https://www.rfc-editor.org/rfc/rfc8949.html#section-8)).
 * 
 * @ignore
 */
export function to_diagnostic(value) {
  if (value instanceof Int) {
    let n = value[0];
    return $int.to_string(n);
  } else if (value instanceof Bytes) {
    let b = value[0];
    return ("h'" + (() => {
      let _pipe = $bit_array.base16_encode(b);
      return $string.lowercase(_pipe);
    })()) + "'";
  } else if (value instanceof Text) {
    let s = value[0];
    return ("\"" + s) + "\"";
  } else if (value instanceof Array) {
    let items = value[0];
    return ("[" + $string.join($list.map(items, to_diagnostic), ", ")) + "]";
  } else if (value instanceof Map) {
    let pairs = value[0];
    return ("{" + $string.join(
      $list.map(
        pairs,
        (pair) => {
          return (to_diagnostic(pair[0]) + ": ") + to_diagnostic(pair[1]);
        },
      ),
      ", ",
    )) + "}";
  } else if (value instanceof Tag) {
    let tag = value[0];
    let content = value[1];
    return (($int.to_string(tag) + "(") + to_diagnostic(content)) + ")";
  } else if (value instanceof Bool) {
    let $ = value[0];
    if ($) {
      return "true";
    } else {
      return "false";
    }
  } else if (value instanceof Float) {
    let f = value[0];
    return $float.to_string(f);
  } else {
    return "null";
  }
}
