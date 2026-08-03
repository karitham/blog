import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import {
  Ok,
  Error,
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
  prepend as listPrepend,
  makeError,
  toBitArray,
  bitArraySlice,
  sizedInt,
} from "../../gleam.mjs";

const FILEPATH = "src/kryptos/internal/utils.gleam";

function trailing_zeros_in_byte(loop$byte, loop$count) {
  while (true) {
    let byte = loop$byte;
    let count = loop$count;
    let $ = $int.bitwise_and(byte, 1);
    if ($ === 0) {
      loop$byte = $int.bitwise_shift_right(byte, 1);
      loop$count = count + 1;
    } else {
      return count;
    }
  }
}

function do_count_trailing_zeros(loop$bits, loop$byte_pos, loop$count) {
  while (true) {
    let bits = loop$bits;
    let byte_pos = loop$byte_pos;
    let count = loop$count;
    let $ = byte_pos < 0;
    if ($) {
      return count;
    } else {
      let $1 = $bit_array.slice(bits, byte_pos, 1);
      let byte;
      if ($1 instanceof Ok) {
        let $2 = $1[0];
        if ($2.bitSize === 8) {
          byte = $2.byteAt(0);
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "kryptos/internal/utils",
            18,
            "do_count_trailing_zeros",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $1,
              start: 468,
              end: 528,
              pattern_start: 479,
              pattern_end: 491
            }
          )
        }
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "kryptos/internal/utils",
          18,
          "do_count_trailing_zeros",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 468,
            end: 528,
            pattern_start: 479,
            pattern_end: 491
          }
        )
      }
      if (byte === 0) {
        loop$bits = bits;
        loop$byte_pos = byte_pos - 1;
        loop$count = count + 8;
      } else {
        return count + trailing_zeros_in_byte(byte, 0);
      }
    }
  }
}

/**
 * Count the number of trailing zero bits in a byte-aligned BitArray.
 */
export function count_trailing_zeros(bits) {
  let size = $bit_array.byte_size(bits);
  return do_count_trailing_zeros(bits, size - 1, 0);
}

/**
 * Strip leading zero bytes from a BitArray, preserving at least one byte.
 *
 * For example: `<<0, 0, 1, 2>>` becomes `<<1, 2>>`
 * But: `<<0, 0>>` becomes `<<0>>` (preserves at least one byte)
 */
export function strip_leading_zeros(loop$bytes) {
  while (true) {
    let bytes = loop$bytes;
    if (bytes.bitSize >= 8 && bytes.byteAt(0) === 0) {
      let rest = bitArraySlice(bytes, 8);
      let $ = $bit_array.byte_size(rest) > 0;
      if ($) {
        loop$bytes = rest;
      } else {
        return bytes;
      }
    } else {
      return bytes;
    }
  }
}

function strip_trailing_zeros_loop(loop$data, loop$len) {
  while (true) {
    let data = loop$data;
    let len = loop$len;
    if (len === 0) {
      return toBitArray([]);
    } else {
      let $ = $bit_array.slice(data, len - 1, 1);
      let last_byte;
      if ($ instanceof Ok) {
        let $1 = $[0];
        if ($1.bitSize === 8) {
          last_byte = $1.byteAt(0);
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "kryptos/internal/utils",
            63,
            "strip_trailing_zeros_loop",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $,
              start: 1719,
              end: 1783,
              pattern_start: 1730,
              pattern_end: 1747
            }
          )
        }
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "kryptos/internal/utils",
          63,
          "strip_trailing_zeros_loop",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 1719,
            end: 1783,
            pattern_start: 1730,
            pattern_end: 1747
          }
        )
      }
      if (last_byte === 0) {
        loop$data = data;
        loop$len = len - 1;
      } else {
        let $2 = $bit_array.slice(data, 0, len);
        let result;
        if ($2 instanceof Ok) {
          result = $2[0];
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "kryptos/internal/utils",
            67,
            "strip_trailing_zeros_loop",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $2,
              start: 1886,
              end: 1939,
              pattern_start: 1897,
              pattern_end: 1907
            }
          )
        }
        return result;
      }
    }
  }
}

/**
 * Strip trailing zero bytes from a BitArray.
 *
 * For example: `<<1, 2, 0, 0>>` becomes `<<1, 2>>`
 * An all-zeros input returns `<<>>`.
 */
export function strip_trailing_zeros(data) {
  let len = $bit_array.byte_size(data);
  return strip_trailing_zeros_loop(data, len);
}

/**
 * Left-pad a BitArray with zeros to reach the specified size.
 *
 * If the input is already at least `size` bytes, it is returned unchanged.
 */
export function pad_left(value, size) {
  let current_size = $bit_array.byte_size(value);
  let $ = current_size >= size;
  if ($) {
    return value;
  } else {
    let padding_size = size - current_size;
    let _block;
    let _pipe = $list.repeat(toBitArray([0]), padding_size);
    _block = $bit_array.concat(_pipe);
    let padding = _block;
    return $bit_array.concat(toList([padding, value]));
  }
}

/**
 * Convert an integer to a zero-padded string of the specified width.
 *
 * For example: `int_to_padded_string(42, 4)` returns `"0042"`
 */
export function int_to_padded_string(n, width) {
  let s = $int.to_string(n);
  let padding = $string.repeat("0", $int.max(0, width - $string.length(s)));
  return padding + s;
}

/**
 * Check if a string contains only ASCII characters (codepoints 0-127).
 */
export function is_ascii(s) {
  let _pipe = s;
  let _pipe$1 = $string.to_utf_codepoints(_pipe);
  return $list.all(
    _pipe$1,
    (cp) => { return $string.utf_codepoint_to_int(cp) <= 127; },
  );
}

/**
 * Split a string into chunks of the specified size.
 * Returns an empty list if size <= 0.
 */
export function chunk_string(s, size) {
  let $ = size > 0;
  if ($) {
    let $1 = $string.length(s) <= size;
    if ($1) {
      return toList([s]);
    } else {
      let chunk = $string.slice(s, 0, size);
      let rest = $string.slice(s, size, $string.length(s) - size);
      return listPrepend(chunk, chunk_string(rest, size));
    }
  } else {
    return $List$Empty$const;
  }
}

function parse_ipv4_octet(s) {
  return $result.try$(
    $int.parse(s),
    (n) => {
      return $bool.guard(
        (n < 0) || (n > 255),
        new Error(undefined),
        () => { return new Ok(n); },
      );
    },
  );
}

function parse_ipv4(ip) {
  let parts = $string.split(ip, ".");
  return $bool.guard(
    $list.length(parts) !== 4,
    new Error(undefined),
    () => {
      return $result.try$(
        $list.try_map(parts, parse_ipv4_octet),
        (bytes) => {
          return new Ok(
            $bit_array.concat(
              $list.map(bytes, (b) => { return toBitArray([b]); }),
            ),
          );
        },
      );
    },
  );
}

function parse_ipv6_word(s) {
  return $result.try$(
    $int.base_parse(s, 16),
    (n) => {
      return $bool.guard(
        (n < 0) || (n > 0xffff),
        new Error(undefined),
        () => { return new Ok(n); },
      );
    },
  );
}

function parse_ipv6_full(ip) {
  let parts = $string.split(ip, ":");
  return $bool.guard(
    $list.length(parts) !== 8,
    new Error(undefined),
    () => {
      return $result.try$(
        $list.try_map(parts, parse_ipv6_word),
        (words) => {
          return new Ok(
            $bit_array.concat(
              $list.map(
                words,
                (w) => { return toBitArray([sizedInt(w, 16, true)]); },
              ),
            ),
          );
        },
      );
    },
  );
}

function parse_ipv6_compressed(ip) {
  return $result.try$(
    (() => {
      let $ = $string.split(ip, "::");
      if ($ instanceof $Empty) {
        return new Error(undefined);
      } else {
        let $1 = $.tail;
        if ($1 instanceof $Empty) {
          return new Error(undefined);
        } else {
          let $2 = $1.tail;
          if ($2 instanceof $Empty) {
            let l = $.head;
            let r = $1.head;
            return new Ok([l, r]);
          } else {
            return new Error(undefined);
          }
        }
      }
    })(),
    (_use0) => {
      let left = _use0[0];
      let right = _use0[1];
      let _block;
      if (left === "") {
        _block = $List$Empty$const;
      } else {
        _block = $string.split(left, ":");
      }
      let left_parts = _block;
      let _block$1;
      if (right === "") {
        _block$1 = $List$Empty$const;
      } else {
        _block$1 = $string.split(right, ":");
      }
      let right_parts = _block$1;
      let total = $list.length(left_parts) + $list.length(right_parts);
      return $bool.guard(
        total > 7,
        new Error(undefined),
        () => {
          let zeros = $list.repeat(0, 8 - total);
          return $result.try$(
            $list.try_map(left_parts, parse_ipv6_word),
            (left_words) => {
              return $result.try$(
                $list.try_map(right_parts, parse_ipv6_word),
                (right_words) => {
                  let all_words = $list.flatten(
                    toList([left_words, zeros, right_words]),
                  );
                  return new Ok(
                    $bit_array.concat(
                      $list.map(
                        all_words,
                        (w) => { return toBitArray([sizedInt(w, 16, true)]); },
                      ),
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
}

function parse_ipv6(ip) {
  let _block;
  let $ = $string.starts_with(ip, "::");
  if ($) {
    _block = "0" + ip;
  } else {
    _block = ip;
  }
  let ip$1 = _block;
  let _block$1;
  let $1 = $string.ends_with(ip$1, "::");
  if ($1) {
    _block$1 = ip$1 + "0";
  } else {
    _block$1 = ip$1;
  }
  let ip$2 = _block$1;
  let $2 = $string.contains(ip$2, "::");
  if ($2) {
    return parse_ipv6_compressed(ip$2);
  } else {
    return parse_ipv6_full(ip$2);
  }
}

/**
 * Parses an IP address string into bytes (4 for IPv4, 16 for IPv6).
 */
export function parse_ip(ip) {
  let $ = $string.contains(ip, ":");
  if ($) {
    return parse_ipv6(ip);
  } else {
    return parse_ipv4(ip);
  }
}
