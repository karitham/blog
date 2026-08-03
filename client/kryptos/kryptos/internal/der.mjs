import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $bytes_tree from "../../../gleam_stdlib/gleam/bytes_tree.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import * as $calendar from "../../../gleam_time/gleam/time/calendar.mjs";
import * as $timestamp from "../../../gleam_time/gleam/time/timestamp.mjs";
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
  bitArraySliceToInt,
  sizedInt,
} from "../../gleam.mjs";
import * as $utils from "../../kryptos/internal/utils.mjs";

const FILEPATH = "src/kryptos/internal/der.gleam";

const boolean_tag = 0x1;

const integer_tag = 0x2;

const sequence_tag = 0x30;

const set_tag = 0x31;

const bit_string_tag = 0x3;

const octet_string_tag = 0x4;

const utf8_string_tag = 0xc;

const printable_string_tag = 0x13;

const ia5_string_tag = 0x16;

const teletex_string_tag = 0x14;

const bmp_string_tag = 0x1e;

const universal_string_tag = 0x1c;

const generalized_time_tag = 0x18;

const utc_time_tag = 0x17;

const oid_tag = 0x6;

/**
 * Encode a length in DER format.
 *
 * Supports lengths up to 65,535 bytes (sufficient for X.509 structures).
 * Returns Error(Nil) for lengths exceeding this limit.
 */
export function encode_length(len) {
  let l = len;
  if (l < 0) {
    return new Error(undefined);
  } else {
    let l = len;
    if (l < 128) {
      return new Ok(toBitArray([l]));
    } else {
      let l = len;
      if (l < 256) {
        return new Ok(toBitArray([129, l]));
      } else {
        let l = len;
        if (l <= 65_535) {
          return new Ok(toBitArray([130, sizedInt(l, 16, true)]));
        } else {
          return new Error(undefined);
        }
      }
    }
  }
}

/**
 * Parse DER length encoding, returning (length, remaining bytes).
 *
 * Supports short form (1 byte) and long form (0x81 + 1 byte, 0x82 + 2 bytes).
 * Rejects non-canonical encodings (e.g., 0x81 for values < 128).
 */
export function parse_length(bytes) {
  if (bytes.bitSize >= 8) {
    let len = bytes.byteAt(0);
    if (len < 128) {
      let rest = bitArraySlice(bytes, 8);
      return new Ok([len, rest]);
    } else if (bytes.byteAt(0) === 129) {
      if (bytes.bitSize >= 16) {
        let len = bytes.byteAt(1);
        if (len >= 128) {
          let rest = bitArraySlice(bytes, 16);
          return new Ok([len, rest]);
        } else {
          return new Error(undefined);
        }
      } else {
        return new Error(undefined);
      }
    } else if (bytes.byteAt(0) === 130 && bytes.bitSize >= 24) {
      let len = bitArraySliceToInt(bytes, 8, 24, true, false);
      if (len >= 256) {
        let rest = bitArraySlice(bytes, 24);
        return new Ok([len, rest]);
      } else {
        return new Error(undefined);
      }
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}

/**
 * Encode a boolean as a DER BOOLEAN.
 */
export function encode_bool(value) {
  if (value) {
    return toBitArray([boolean_tag, 1, 255]);
  } else {
    return toBitArray([boolean_tag, 1, 0]);
  }
}

function require_tag(bytes, tag, next) {
  if (bytes.bitSize >= 8) {
    let t = bytes.byteAt(0);
    if (t === tag) {
      let rest = bitArraySlice(bytes, 8);
      return next(rest);
    } else {
      return new Error(undefined);
    }
  } else {
    return new Error(undefined);
  }
}

/**
 * Parse a DER BOOLEAN, returning (value, remaining bytes).
 *
 * Accepts any non-zero value as TRUE for BER interoperability,
 * as some certificates in the wild use non-0xFF values for TRUE.
 */
export function parse_bool(bytes) {
  return require_tag(
    bytes,
    boolean_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $bool.guard(
            len !== 1,
            new Error(undefined),
            () => {
              if (content.bitSize >= 8) {
                if (content.byteAt(0) === 0) {
                  let remaining = bitArraySlice(content, 8);
                  return new Ok([false, remaining]);
                } else {
                  let remaining = bitArraySlice(content, 8);
                  return new Ok([true, remaining]);
                }
              } else {
                return new Error(undefined);
              }
            },
          );
        },
      );
    },
  );
}

/**
 * Encode bytes as a DER INTEGER.
 *
 * Strips leading zeros and adds 0x00 prefix if high bit is set (to keep positive).
 */
export function encode_integer(value) {
  let stripped = $utils.strip_leading_zeros(value);
  let _block;
  if (stripped.bitSize >= 8) {
    let high = stripped.byteAt(0);
    if (high >= 128) {
      _block = $bit_array.concat(toList([toBitArray([0]), stripped]));
    } else {
      _block = stripped;
    }
  } else if (stripped.bitSize === 0) {
    _block = toBitArray([0]);
  } else {
    _block = stripped;
  }
  let int_bytes = _block;
  return $result.try$(
    encode_length($bit_array.byte_size(int_bytes)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(
          toList([toBitArray([integer_tag]), len_bytes, int_bytes]),
        ),
      );
    },
  );
}

/**
 * Encode a non-negative Int as a DER INTEGER.
 *
 * Supports values from 0 to 0xFFFFFFFF (4 bytes).
 * Returns Error(Nil) for negative values or values exceeding 32 bits.
 */
export function encode_small_int(n) {
  if (n < 0) {
    return new Error(undefined);
  } else if (n < 0x100) {
    return encode_integer(toBitArray([n]));
  } else if (n < 0x10000) {
    return encode_integer(toBitArray([sizedInt(n, 16, true)]));
  } else if (n < 0x1000000) {
    return encode_integer(toBitArray([sizedInt(n, 24, true)]));
  } else if (n < 0x1_0000_0000) {
    return encode_integer(toBitArray([sizedInt(n, 32, true)]));
  } else {
    return new Error(undefined);
  }
}

function reject_non_minimal_zeros(value, next) {
  if (value.bitSize >= 8 && value.byteAt(0) === 0 && value.bitSize >= 16) {
    let second = value.byteAt(1);
    if (second < 128) {
      return new Error(undefined);
    } else {
      return next();
    }
  } else {
    return next();
  }
}

/**
 * Parse a DER INTEGER, returning (value bytes, remaining bytes).
 *
 * The returned value bytes may have a leading 0x00 if the high bit was set.
 * Rejects zero-length integers and non-minimal leading zero padding.
 */
export function parse_integer(bytes) {
  return require_tag(
    bytes,
    integer_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $bool.guard(
            len <= 0,
            new Error(undefined),
            () => {
              let content_size = $bit_array.byte_size(content);
              return $bool.guard(
                content_size < len,
                new Error(undefined),
                () => {
                  let $ = $bit_array.slice(content, 0, len);
                  let value;
                  if ($ instanceof Ok) {
                    value = $[0];
                  } else {
                    throw makeError(
                      "let_assert",
                      FILEPATH,
                      "kryptos/internal/der",
                      137,
                      "parse_integer",
                      "Pattern match failed, no pattern matched the value.",
                      {
                        value: $,
                        start: 4080,
                        end: 4135,
                        pattern_start: 4091,
                        pattern_end: 4100
                      }
                    )
                  }
                  return reject_non_minimal_zeros(
                    value,
                    () => {
                      let $1 = $bit_array.slice(
                        content,
                        len,
                        content_size - len,
                      );
                      let remaining;
                      if ($1 instanceof Ok) {
                        remaining = $1[0];
                      } else {
                        throw makeError(
                          "let_assert",
                          FILEPATH,
                          "kryptos/internal/der",
                          141,
                          "parse_integer",
                          "Pattern match failed, no pattern matched the value.",
                          {
                            value: $1,
                            start: 4252,
                            end: 4328,
                            pattern_start: 4263,
                            pattern_end: 4276
                          }
                        )
                      }
                      return new Ok([value, remaining]);
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

/**
 * Wrap content in a DER SEQUENCE.
 */
export function encode_sequence(content) {
  return $result.try$(
    encode_length($bit_array.byte_size(content)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(
          toList([toBitArray([sequence_tag]), len_bytes, content]),
        ),
      );
    },
  );
}

/**
 * Parse the content of a DER SEQUENCE, returning (inner bytes, remaining bytes).
 */
export function parse_sequence(bytes) {
  return require_tag(
    bytes,
    sequence_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          let content_size = $bit_array.byte_size(content);
          return $bool.guard(
            content_size < len,
            new Error(undefined),
            () => {
              let $ = $bit_array.slice(content, 0, len);
              let inner;
              if ($ instanceof Ok) {
                inner = $[0];
              } else {
                throw makeError(
                  "let_assert",
                  FILEPATH,
                  "kryptos/internal/der",
                  160,
                  "parse_sequence",
                  "Pattern match failed, no pattern matched the value.",
                  {
                    value: $,
                    start: 5061,
                    end: 5116,
                    pattern_start: 5072,
                    pattern_end: 5081
                  }
                )
              }
              let $1 = $bit_array.slice(content, len, content_size - len);
              let remaining;
              if ($1 instanceof Ok) {
                remaining = $1[0];
              } else {
                throw makeError(
                  "let_assert",
                  FILEPATH,
                  "kryptos/internal/der",
                  161,
                  "parse_sequence",
                  "Pattern match failed, no pattern matched the value.",
                  {
                    value: $1,
                    start: 5119,
                    end: 5195,
                    pattern_start: 5130,
                    pattern_end: 5143
                  }
                )
              }
              return new Ok([inner, remaining]);
            },
          );
        },
      );
    },
  );
}

/**
 * Wrap content in a DER SET.
 */
export function encode_set(content) {
  return $result.try$(
    encode_length($bit_array.byte_size(content)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(toList([toBitArray([set_tag]), len_bytes, content])),
      );
    },
  );
}

/**
 * Parse content of a given length, returning (value, remaining bytes).
 */
export function parse_content(content, len) {
  let content_size = $bit_array.byte_size(content);
  return $bool.guard(
    content_size < len,
    new Error(undefined),
    () => {
      let $ = $bit_array.slice(content, 0, len);
      let inner;
      if ($ instanceof Ok) {
        inner = $[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "kryptos/internal/der",
          576,
          "parse_content",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 20465,
            end: 20520,
            pattern_start: 20476,
            pattern_end: 20485
          }
        )
      }
      let $1 = $bit_array.slice(content, len, content_size - len);
      let remaining;
      if ($1 instanceof Ok) {
        remaining = $1[0];
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "kryptos/internal/der",
          577,
          "parse_content",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $1,
            start: 20523,
            end: 20599,
            pattern_start: 20534,
            pattern_end: 20547
          }
        )
      }
      return new Ok([inner, remaining]);
    },
  );
}

/**
 * Parse the content of a DER SET, returning (inner bytes, remaining bytes).
 */
export function parse_set(bytes) {
  return require_tag(
    bytes,
    set_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return parse_content(content, len);
        },
      );
    },
  );
}

/**
 * Encode a BIT STRING.
 *
 * Handles non-byte-aligned bit arrays by calculating and encoding
 * the appropriate padding bits.
 */
export function encode_bit_string(value) {
  let bit_size = $bit_array.bit_size(value);
  let _block;
  let $ = bit_size % 8;
  if ($ === 0) {
    _block = $;
  } else {
    let remainder = $;
    _block = 8 - remainder;
  }
  let unused_bits = _block;
  let padded = $bit_array.pad_to_bytes(value);
  let content = toBitArray([unused_bits, padded]);
  return $result.try$(
    encode_length($bit_array.byte_size(content)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(
          toList([toBitArray([bit_string_tag]), len_bytes, content]),
        ),
      );
    },
  );
}

/**
 * Parse a DER BIT STRING, returning (value bytes, remaining bytes).
 *
 * The first byte of a BIT STRING indicates unused bits; this function
 * only accepts 0 unused bits and strips that byte from the result.
 */
export function parse_bit_string(bytes) {
  return require_tag(
    bytes,
    bit_string_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $bool.guard(
            len < 1,
            new Error(undefined),
            () => {
              let content_size = $bit_array.byte_size(content);
              return $bool.guard(
                content_size < len,
                new Error(undefined),
                () => {
                  if (
                    content.bitSize >= 8 &&
                    content.byteAt(0) === 0 &&
                    (len - 1) * 8 >= 0 &&
                    content.bitSize >= 8 + (len - 1) * 8
                  ) {
                    let value = bitArraySlice(content, 8, 8 + (len - 1) * 8);
                    let remaining = bitArraySlice(content, 8 + (len - 1) * 8);
                    return new Ok([value, remaining]);
                  } else {
                    return new Error(undefined);
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

/**
 * Encode an OCTET STRING.
 */
export function encode_octet_string(value) {
  return $result.try$(
    encode_length($bit_array.byte_size(value)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(
          toList([toBitArray([octet_string_tag]), len_bytes, value]),
        ),
      );
    },
  );
}

/**
 * Parse a DER OCTET STRING, returning (value bytes, remaining bytes).
 */
export function parse_octet_string(bytes) {
  return require_tag(
    bytes,
    octet_string_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return parse_content(content, len);
        },
      );
    },
  );
}

/**
 * Encode a UTF8String.
 */
export function encode_utf8_string(value) {
  let content = $bit_array.from_string(value);
  return $result.try$(
    encode_length($bit_array.byte_size(content)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(
          toList([toBitArray([utf8_string_tag]), len_bytes, content]),
        ),
      );
    },
  );
}

/**
 * Parse a DER UTF8String, returning (string value, remaining bytes).
 */
export function parse_utf8_string(bytes) {
  return require_tag(
    bytes,
    utf8_string_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $result.try$(
            parse_content(content, len),
            (_use0) => {
              let value_bytes = _use0[0];
              let remaining = _use0[1];
              return $result.try$(
                $bit_array.to_string(value_bytes),
                (value) => { return new Ok([value, remaining]); },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Check if a codepoint is valid for PrintableString per RFC 5280.
 * 
 * @ignore
 */
function is_printable_char(codepoint) {
  let c = codepoint;
  if ((c >= 65) && (c <= 90)) {
    return true;
  } else {
    let c = codepoint;
    if ((c >= 97) && (c <= 122)) {
      return true;
    } else {
      let c = codepoint;
      if ((c >= 48) && (c <= 57)) {
        return true;
      } else if (codepoint === 32) {
        return true;
      } else if (codepoint === 39) {
        return true;
      } else if (codepoint === 40) {
        return true;
      } else if (codepoint === 41) {
        return true;
      } else if (codepoint === 43) {
        return true;
      } else if (codepoint === 44) {
        return true;
      } else if (codepoint === 45) {
        return true;
      } else if (codepoint === 46) {
        return true;
      } else if (codepoint === 47) {
        return true;
      } else if (codepoint === 58) {
        return true;
      } else if (codepoint === 61) {
        return true;
      } else if (codepoint === 63) {
        return true;
      } else {
        return false;
      }
    }
  }
}

function is_valid_printable_string(value) {
  if (value.bitSize === 0) {
    return true;
  } else if (value.bitSize >= 8) {
    let byte = value.byteAt(0);
    let rest = bitArraySlice(value, 8);
    return is_printable_char(byte) && is_valid_printable_string(rest);
  } else {
    return false;
  }
}

/**
 * Encode a PrintableString (ASCII subset per RFC 5280).
 * Returns Error(Nil) if the string contains characters not allowed
 * in PrintableString.
 */
export function encode_printable_string(value) {
  let content = $bit_array.from_string(value);
  return $bool.guard(
    !is_valid_printable_string(content),
    new Error(undefined),
    () => {
      return $result.try$(
        encode_length($bit_array.byte_size(content)),
        (len_bytes) => {
          return new Ok(
            $bit_array.concat(
              toList([toBitArray([printable_string_tag]), len_bytes, content]),
            ),
          );
        },
      );
    },
  );
}

/**
 * Parse a DER PrintableString, returning (string value, remaining bytes).
 * Note: does not enforce the PrintableString charset (A-Z, a-z, 0-9,
 * space, '()+,-./:=?) to remain liberal in what we accept per Postel's law.
 */
export function parse_printable_string(bytes) {
  return require_tag(
    bytes,
    printable_string_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $result.try$(
            parse_content(content, len),
            (_use0) => {
              let value_bytes = _use0[0];
              let remaining = _use0[1];
              return $result.try$(
                $bit_array.to_string(value_bytes),
                (value) => { return new Ok([value, remaining]); },
              );
            },
          );
        },
      );
    },
  );
}

/**
 * Encode an IA5String (ASCII).
 */
export function encode_ia5_string(value) {
  let content = $bit_array.from_string(value);
  return $result.try$(
    encode_length($bit_array.byte_size(content)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(
          toList([toBitArray([ia5_string_tag]), len_bytes, content]),
        ),
      );
    },
  );
}

/**
 * Parse a DER IA5String, returning (string value, remaining bytes).
 * Note: does not enforce the IA5 (ASCII-only) constraint to remain
 * liberal in what we accept per Postel's law.
 */
export function parse_ia5_string(bytes) {
  return require_tag(
    bytes,
    ia5_string_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $result.try$(
            parse_content(content, len),
            (_use0) => {
              let value_bytes = _use0[0];
              let remaining = _use0[1];
              return $result.try$(
                $bit_array.to_string(value_bytes),
                (value) => { return new Ok([value, remaining]); },
              );
            },
          );
        },
      );
    },
  );
}

function latin1_to_utf8_loop(loop$bytes, loop$acc) {
  while (true) {
    let bytes = loop$bytes;
    let acc = loop$acc;
    if (bytes.bitSize === 0) {
      return new Ok(acc);
    } else if (bytes.bitSize >= 8) {
      let byte = bytes.byteAt(0);
      let rest = bitArraySlice(bytes, 8);
      let $ = $string.utf_codepoint(byte);
      if ($ instanceof Ok) {
        let cp = $[0];
        loop$bytes = rest;
        loop$acc = listPrepend(cp, acc);
      } else {
        return new Error(undefined);
      }
    } else {
      return new Error(undefined);
    }
  }
}

/**
 * Convert ISO 8859-1 (Latin-1) bytes to a UTF-8 string.
 *
 * Each byte in Latin-1 represents a single Unicode codepoint (0x00-0xFF),
 * which maps directly to Unicode.
 * 
 * @ignore
 */
function latin1_to_utf8(bytes) {
  let _pipe = latin1_to_utf8_loop(bytes, $List$Empty$const);
  return $result.map(
    _pipe,
    (codepoints) => {
      let _pipe$1 = codepoints;
      let _pipe$2 = $list.reverse(_pipe$1);
      return $string.from_utf_codepoints(_pipe$2);
    },
  );
}

/**
 * Parse a DER TeletexString (T61String), returning (string value, remaining bytes).
 *
 * TeletexString uses ISO 8859-1 (Latin-1) encoding, where each byte represents
 * one character. This is a decode-only function for legacy certificate compatibility.
 */
export function parse_teletex_string(bytes) {
  return require_tag(
    bytes,
    teletex_string_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $result.try$(
            parse_content(content, len),
            (_use0) => {
              let value_bytes = _use0[0];
              let remaining = _use0[1];
              return $result.try$(
                latin1_to_utf8(value_bytes),
                (value) => { return new Ok([value, remaining]); },
              );
            },
          );
        },
      );
    },
  );
}

function ucs2_to_utf8_loop(loop$bytes, loop$acc) {
  while (true) {
    let bytes = loop$bytes;
    let acc = loop$acc;
    if (bytes.bitSize === 0) {
      return new Ok(acc);
    } else if (bytes.bitSize >= 16) {
      let codepoint = bitArraySliceToInt(bytes, 0, 16, true, false);
      let rest = bitArraySlice(bytes, 16);
      let $ = $string.utf_codepoint(codepoint);
      if ($ instanceof Ok) {
        let cp = $[0];
        loop$bytes = rest;
        loop$acc = listPrepend(cp, acc);
      } else {
        return new Error(undefined);
      }
    } else {
      return new Error(undefined);
    }
  }
}

/**
 * Convert UCS-2 big-endian bytes to a UTF-8 string.
 *
 * Each 2-byte unit represents a Unicode codepoint in the Basic Multilingual Plane.
 * 
 * @ignore
 */
function ucs2_to_utf8(bytes) {
  let _pipe = ucs2_to_utf8_loop(bytes, $List$Empty$const);
  return $result.map(
    _pipe,
    (codepoints) => {
      let _pipe$1 = codepoints;
      let _pipe$2 = $list.reverse(_pipe$1);
      return $string.from_utf_codepoints(_pipe$2);
    },
  );
}

/**
 * Parse a DER BMPString, returning (string value, remaining bytes).
 *
 * BMPString uses UCS-2 big-endian encoding (2 bytes per character).
 * This is a decode-only function for legacy certificate compatibility.
 */
export function parse_bmp_string(bytes) {
  return require_tag(
    bytes,
    bmp_string_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $bool.guard(
            (len % 2) !== 0,
            new Error(undefined),
            () => {
              return $result.try$(
                parse_content(content, len),
                (_use0) => {
                  let value_bytes = _use0[0];
                  let remaining = _use0[1];
                  return $result.try$(
                    ucs2_to_utf8(value_bytes),
                    (value) => { return new Ok([value, remaining]); },
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

function ucs4_to_utf8_loop(loop$bytes, loop$acc) {
  while (true) {
    let bytes = loop$bytes;
    let acc = loop$acc;
    if (bytes.bitSize === 0) {
      return new Ok(acc);
    } else if (bytes.bitSize >= 32) {
      let codepoint = bitArraySliceToInt(bytes, 0, 32, true, false);
      let rest = bitArraySlice(bytes, 32);
      let $ = $string.utf_codepoint(codepoint);
      if ($ instanceof Ok) {
        let cp = $[0];
        loop$bytes = rest;
        loop$acc = listPrepend(cp, acc);
      } else {
        return new Error(undefined);
      }
    } else {
      return new Error(undefined);
    }
  }
}

/**
 * Convert UCS-4 big-endian bytes to a UTF-8 string.
 *
 * Each 4-byte unit represents a Unicode codepoint.
 * 
 * @ignore
 */
function ucs4_to_utf8(bytes) {
  let _pipe = ucs4_to_utf8_loop(bytes, $List$Empty$const);
  return $result.map(
    _pipe,
    (codepoints) => {
      let _pipe$1 = codepoints;
      let _pipe$2 = $list.reverse(_pipe$1);
      return $string.from_utf_codepoints(_pipe$2);
    },
  );
}

/**
 * Parse a DER UniversalString, returning (string value, remaining bytes).
 *
 * UniversalString uses UCS-4 big-endian encoding (4 bytes per character).
 * This is a decode-only function for legacy certificate compatibility.
 */
export function parse_universal_string(bytes) {
  return require_tag(
    bytes,
    universal_string_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $bool.guard(
            (len % 4) !== 0,
            new Error(undefined),
            () => {
              return $result.try$(
                parse_content(content, len),
                (_use0) => {
                  let value_bytes = _use0[0];
                  let remaining = _use0[1];
                  return $result.try$(
                    ucs4_to_utf8(value_bytes),
                    (value) => { return new Ok([value, remaining]); },
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

/**
 * Format: YYYYMMDDHHMMSSZ
 */
export function encode_generalized_time(timestamp) {
  let $ = $timestamp.to_calendar(timestamp, $calendar.utc_offset);
  let date = $[0];
  let time = $[1];
  let pad2 = (_capture) => { return $utils.int_to_padded_string(_capture, 2); };
  let pad4 = (_capture) => { return $utils.int_to_padded_string(_capture, 4); };
  let content = (((((pad4(date.year) + pad2($calendar.month_to_int(date.month))) + pad2(
    date.day,
  )) + pad2(time.hours)) + pad2(time.minutes)) + pad2(time.seconds)) + "Z";
  let bytes = $bit_array.from_string(content);
  return $result.try$(
    encode_length($bit_array.byte_size(bytes)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(
          toList([toBitArray([generalized_time_tag]), len_bytes, bytes]),
        ),
      );
    },
  );
}

/**
 * Format: YYMMDDHHMMSSZ
 * 
 * @ignore
 */
function encode_utc_time(timestamp) {
  let $ = $timestamp.to_calendar(timestamp, $calendar.utc_offset);
  let date = $[0];
  let time = $[1];
  let yy = date.year % 100;
  let pad2 = (_capture) => { return $utils.int_to_padded_string(_capture, 2); };
  let content = (((((pad2(yy) + pad2($calendar.month_to_int(date.month))) + pad2(
    date.day,
  )) + pad2(time.hours)) + pad2(time.minutes)) + pad2(time.seconds)) + "Z";
  let bytes = $bit_array.from_string(content);
  return $result.try$(
    encode_length($bit_array.byte_size(bytes)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(
          toList([toBitArray([utc_time_tag]), len_bytes, bytes]),
        ),
      );
    },
  );
}

/**
 * Encode a DER Timestamp, returning a BitArray.
 */
export function encode_timestamp(timestamp) {
  let $ = $timestamp.to_calendar(timestamp, $calendar.utc_offset);
  let date = $[0];
  let $1 = (date.year >= 1950) && (date.year < 2050);
  if ($1) {
    return encode_utc_time(timestamp);
  } else {
    return encode_generalized_time(timestamp);
  }
}

/**
 * Parse a UTCTime, returning (Timestamp, remaining).
 * UTCTime uses 2-digit years: 00-49 = 2000-2049, 50-99 = 1950-1999.
 */
export function parse_utc_time(bytes) {
  return require_tag(
    bytes,
    utc_time_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $bool.guard(
            len !== 13,
            new Error(undefined),
            () => {
              return $result.try$(
                parse_content(content, len),
                (_use0) => {
                  let time_bytes = _use0[0];
                  let remaining = _use0[1];
                  return $result.try$(
                    $bit_array.to_string(time_bytes),
                    (time_str) => {
                      return $bool.guard(
                        !$string.ends_with(time_str, "Z"),
                        new Error(undefined),
                        () => {
                          return $result.try$(
                            $int.parse($string.slice(time_str, 0, 2)),
                            (yy) => {
                              return $result.try$(
                                $int.parse($string.slice(time_str, 2, 2)),
                                (month_int) => {
                                  return $result.try$(
                                    $calendar.month_from_int(month_int),
                                    (month) => {
                                      return $result.try$(
                                        $int.parse(
                                          $string.slice(time_str, 4, 2),
                                        ),
                                        (day) => {
                                          return $result.try$(
                                            $int.parse(
                                              $string.slice(time_str, 6, 2),
                                            ),
                                            (hour) => {
                                              return $result.try$(
                                                $int.parse(
                                                  $string.slice(time_str, 8, 2),
                                                ),
                                                (minute) => {
                                                  return $result.try$(
                                                    $int.parse(
                                                      $string.slice(
                                                        time_str,
                                                        10,
                                                        2,
                                                      ),
                                                    ),
                                                    (second) => {
                                                      let _block;
                                                      let $ = yy >= 50;
                                                      if ($) {
                                                        _block = 1900 + yy;
                                                      } else {
                                                        _block = 2000 + yy;
                                                      }
                                                      let year = _block;
                                                      let ts = $timestamp.from_calendar(
                                                        new $calendar.Date(
                                                          year,
                                                          month,
                                                          day,
                                                        ),
                                                        new $calendar.TimeOfDay(
                                                          hour,
                                                          minute,
                                                          second,
                                                          0,
                                                        ),
                                                        $calendar.utc_offset,
                                                      );
                                                      return new Ok(
                                                        [ts, remaining],
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

/**
 * Parse a GeneralizedTime, returning (Timestamp, remaining).
 */
export function parse_generalized_time(bytes) {
  return require_tag(
    bytes,
    generalized_time_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $bool.guard(
            len !== 15,
            new Error(undefined),
            () => {
              return $result.try$(
                parse_content(content, len),
                (_use0) => {
                  let time_bytes = _use0[0];
                  let remaining = _use0[1];
                  return $result.try$(
                    $bit_array.to_string(time_bytes),
                    (time_str) => {
                      return $bool.guard(
                        !$string.ends_with(time_str, "Z"),
                        new Error(undefined),
                        () => {
                          return $result.try$(
                            $int.parse($string.slice(time_str, 0, 4)),
                            (year) => {
                              return $result.try$(
                                $int.parse($string.slice(time_str, 4, 2)),
                                (month_int) => {
                                  return $result.try$(
                                    $calendar.month_from_int(month_int),
                                    (month) => {
                                      return $result.try$(
                                        $int.parse(
                                          $string.slice(time_str, 6, 2),
                                        ),
                                        (day) => {
                                          return $result.try$(
                                            $int.parse(
                                              $string.slice(time_str, 8, 2),
                                            ),
                                            (hour) => {
                                              return $result.try$(
                                                $int.parse(
                                                  $string.slice(time_str, 10, 2),
                                                ),
                                                (minute) => {
                                                  return $result.try$(
                                                    $int.parse(
                                                      $string.slice(
                                                        time_str,
                                                        12,
                                                        2,
                                                      ),
                                                    ),
                                                    (second) => {
                                                      let timestamp = $timestamp.from_calendar(
                                                        new $calendar.Date(
                                                          year,
                                                          month,
                                                          day,
                                                        ),
                                                        new $calendar.TimeOfDay(
                                                          hour,
                                                          minute,
                                                          second,
                                                          0,
                                                        ),
                                                        $calendar.utc_offset,
                                                      );
                                                      return new Ok(
                                                        [timestamp, remaining],
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

function bytes_from_list(bytes) {
  let _pipe = bytes;
  let _pipe$1 = $list.fold(
    _pipe,
    $bytes_tree.new$(),
    (tree, byte) => { return $bytes_tree.append(tree, toBitArray([byte])); },
  );
  return $bytes_tree.to_bit_array(_pipe$1);
}

function encode_oid_component_base128(loop$value, loop$acc) {
  while (true) {
    let value = loop$value;
    let acc = loop$acc;
    if (value === 0) {
      return acc;
    } else {
      let byte = $int.bitwise_and(value, 0x7f);
      let next_value = $int.bitwise_shift_right(value, 7);
      let _block;
      if (acc instanceof $Empty) {
        _block = byte;
      } else {
        _block = $int.bitwise_or(byte, 0x80);
      }
      let new_byte = _block;
      loop$value = next_value;
      loop$acc = listPrepend(new_byte, acc);
    }
  }
}

function encode_oid_component(value) {
  let $ = value < 128;
  if ($) {
    return toList([value]);
  } else {
    return encode_oid_component_base128(value, $List$Empty$const);
  }
}

/**
 * Encode an OID (Object Identifier).
 *
 * OID components are encoded per ITU-T X.690 Section 8.19.4: first*40 + second
 * for the first subidentifier, then base-128 with continuation bits for the rest.
 * Returns Error(Nil) for invalid OIDs (fewer than 2 components, or root arc
 * values violating ITU-T X.660: first must be 0-2, second must be 0-39 when
 * first is 0 or 1).
 */
export function encode_oid(components) {
  if (components instanceof $Empty) {
    return new Error(undefined);
  } else {
    let $ = components.tail;
    if ($ instanceof $Empty) {
      return new Error(undefined);
    } else {
      let first = components.head;
      let second = $.head;
      if (
        (((first >= 0) && (first <= 2)) && (second >= 0)) && ((first === 2) || (second <= 39))
      ) {
        let rest = $.tail;
        let first_value = first * 40 + second;
        let first_bytes = encode_oid_component(first_value);
        let rest_bytes = $list.flat_map(rest, encode_oid_component);
        let content = $bit_array.concat(
          toList([bytes_from_list(first_bytes), bytes_from_list(rest_bytes)]),
        );
        return $result.try$(
          encode_length($bit_array.byte_size(content)),
          (len_bytes) => {
            return new Ok(
              $bit_array.concat(
                toList([toBitArray([oid_tag]), len_bytes, content]),
              ),
            );
          },
        );
      } else {
        return new Error(undefined);
      }
    }
  }
}

function decode_oid_rest(loop$bytes, loop$acc, loop$components) {
  while (true) {
    let bytes = loop$bytes;
    let acc = loop$acc;
    let components = loop$components;
    if (bytes.bitSize === 0) {
      if (acc === 0) {
        return new Ok($list.reverse(components));
      } else {
        return new Error(undefined);
      }
    } else if (bytes.bitSize >= 8) {
      let byte = bytes.byteAt(0);
      let rest = bitArraySlice(bytes, 8);
      let value = $int.bitwise_or(
        $int.bitwise_shift_left(acc, 7),
        $int.bitwise_and(byte, 0x7f),
      );
      let is_continuation = $int.bitwise_and(byte, 0x80) !== 0;
      if (is_continuation) {
        loop$bytes = rest;
        loop$acc = value;
        loop$components = components;
      } else {
        loop$bytes = rest;
        loop$acc = 0;
        loop$components = listPrepend(value, components);
      }
    } else {
      return new Error(undefined);
    }
  }
}

function decode_first_oid_component(loop$bytes, loop$acc) {
  while (true) {
    let bytes = loop$bytes;
    let acc = loop$acc;
    if (bytes.bitSize === 0) {
      return new Error(undefined);
    } else if (bytes.bitSize >= 8) {
      let byte = bytes.byteAt(0);
      let rest = bitArraySlice(bytes, 8);
      let value = $int.bitwise_or(
        $int.bitwise_shift_left(acc, 7),
        $int.bitwise_and(byte, 0x7f),
      );
      let is_continuation = $int.bitwise_and(byte, 0x80) !== 0;
      if (is_continuation) {
        loop$bytes = rest;
        loop$acc = value;
      } else {
        return new Ok([value, rest]);
      }
    } else {
      return new Error(undefined);
    }
  }
}

/**
 * Decode raw OID content bytes (without tag/length prefix) into components.
 *
 * Used for implicitly tagged OIDs where the tag/length have already been stripped.
 */
export function decode_oid_components(bytes) {
  return $result.try$(
    decode_first_oid_component(bytes, 0),
    (_use0) => {
      let first_value = _use0[0];
      let rest = _use0[1];
      let _block;
      {
        let v = first_value;
        if (v < 40) {
          _block = 0;
        } else {
          let v = first_value;
          if (v < 80) {
            _block = 1;
          } else {
            _block = 2;
          }
        }
      }
      let first = _block;
      let second = first_value - first * 40;
      return $result.try$(
        decode_oid_rest(rest, 0, $List$Empty$const),
        (rest_components) => {
          return new Ok(
            listPrepend(first, listPrepend(second, rest_components)),
          );
        },
      );
    },
  );
}

/**
 * Parse a DER OID, returning (components list, remaining bytes).
 */
export function parse_oid(bytes) {
  return require_tag(
    bytes,
    oid_tag,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return $bool.guard(
            len < 1,
            new Error(undefined),
            () => {
              let content_size = $bit_array.byte_size(content);
              return $bool.guard(
                content_size < len,
                new Error(undefined),
                () => {
                  let $ = $bit_array.slice(content, 0, len);
                  let oid_bytes;
                  if ($ instanceof Ok) {
                    oid_bytes = $[0];
                  } else {
                    throw makeError(
                      "let_assert",
                      FILEPATH,
                      "kryptos/internal/der",
                      527,
                      "parse_oid",
                      "Pattern match failed, no pattern matched the value.",
                      {
                        value: $,
                        start: 18708,
                        end: 18767,
                        pattern_start: 18719,
                        pattern_end: 18732
                      }
                    )
                  }
                  let $1 = $bit_array.slice(content, len, content_size - len);
                  let remaining;
                  if ($1 instanceof Ok) {
                    remaining = $1[0];
                  } else {
                    throw makeError(
                      "let_assert",
                      FILEPATH,
                      "kryptos/internal/der",
                      528,
                      "parse_oid",
                      "Pattern match failed, no pattern matched the value.",
                      {
                        value: $1,
                        start: 18770,
                        end: 18846,
                        pattern_start: 18781,
                        pattern_end: 18794
                      }
                    )
                  }
                  return $result.try$(
                    decode_oid_components(oid_bytes),
                    (components) => { return new Ok([components, remaining]); },
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

/**
 * Encode a context-specific tag (e.g., [0], [1]).
 *
 * Uses constructed form (tag | 0xA0).
 */
export function encode_context_tag(tag, content) {
  let tag_byte = $int.bitwise_or(0xa0, tag);
  return $result.try$(
    encode_length($bit_array.byte_size(content)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(toList([toBitArray([tag_byte]), len_bytes, content])),
      );
    },
  );
}

/**
 * Parse a context-specific constructed tag (e.g., [0], [1]).
 *
 * Returns (inner bytes, remaining bytes) if the tag matches.
 */
export function parse_context_tag(bytes, tag) {
  let tag_byte = $int.bitwise_or(0xa0, tag);
  return require_tag(
    bytes,
    tag_byte,
    (rest) => {
      return $result.try$(
        parse_length(rest),
        (_use0) => {
          let len = _use0[0];
          let content = _use0[1];
          return parse_content(content, len);
        },
      );
    },
  );
}

/**
 * Encode a context-specific primitive tag (e.g., [0], [2] for SANs).
 *
 * Uses primitive form (tag | 0x80).
 */
export function encode_context_primitive_tag(tag, content) {
  let tag_byte = $int.bitwise_or(0x80, tag);
  return $result.try$(
    encode_length($bit_array.byte_size(content)),
    (len_bytes) => {
      return new Ok(
        $bit_array.concat(toList([toBitArray([tag_byte]), len_bytes, content])),
      );
    },
  );
}

/**
 * Parse a TLV element, returning (tag, value, remaining bytes).
 */
export function parse_tlv(bytes) {
  if (bytes.bitSize >= 8) {
    let tag = bytes.byteAt(0);
    let rest = bitArraySlice(bytes, 8);
    return $result.try$(
      parse_length(rest),
      (_use0) => {
        let len = _use0[0];
        let content = _use0[1];
        return $result.try$(
          parse_content(content, len),
          (_use0) => {
            let value = _use0[0];
            let remaining = _use0[1];
            return new Ok([tag, value, remaining]);
          },
        );
      },
    );
  } else {
    return new Error(undefined);
  }
}
