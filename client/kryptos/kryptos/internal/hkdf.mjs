import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bytes_tree from "../../../gleam_stdlib/gleam/bytes_tree.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import { Ok, toList, makeError, toBitArray } from "../../gleam.mjs";
import * as $hash from "../../kryptos/hash.mjs";
import * as $hmac from "../../kryptos/hmac.mjs";
import { hkdfDerive as do_derive } from "../../kryptos_ffi.mjs";

export { do_derive };

const FILEPATH = "src/kryptos/internal/hkdf.gleam";

function expand_loop(algorithm, prk, info, remaining, prev, counter, acc) {
  let $ = remaining <= 0;
  if ($) {
    return new Ok($bytes_tree.to_bit_array(acc));
  } else {
    let input = $bit_array.concat(toList([prev, info, toBitArray([counter])]));
    return $result.try$(
      $hmac.new$(algorithm, prk),
      (hmac_state) => {
        let _block;
        let _pipe = hmac_state;
        let _pipe$1 = $hmac.update(_pipe, input);
        _block = $hmac.final(_pipe$1);
        let t = _block;
        let t_len = $bit_array.byte_size(t);
        let $1 = remaining <= t_len;
        if ($1) {
          let $2 = $bit_array.slice(t, 0, remaining);
          let final_block;
          if ($2 instanceof Ok) {
            final_block = $2[0];
          } else {
            throw makeError(
              "let_assert",
              FILEPATH,
              "kryptos/internal/hkdf",
              69,
              "expand_loop",
              "Pattern match failed, no pattern matched the value.",
              {
                value: $2,
                start: 1843,
                end: 1904,
                pattern_start: 1854,
                pattern_end: 1869
              }
            )
          }
          let _pipe$2 = $bytes_tree.append(acc, final_block);
          let _pipe$3 = $bytes_tree.to_bit_array(_pipe$2);
          return new Ok(_pipe$3);
        } else {
          return expand_loop(
            algorithm,
            prk,
            info,
            remaining - t_len,
            t,
            counter + 1,
            $bytes_tree.append(acc, t),
          );
        }
      },
    );
  }
}

function expand(algorithm, prk, info, length) {
  return expand_loop(
    algorithm,
    prk,
    info,
    length,
    toBitArray([]),
    1,
    $bytes_tree.new$(),
  );
}
