import * as $bit_array from "../../../gleam_stdlib/gleam/bit_array.mjs";
import * as $bool from "../../../gleam_stdlib/gleam/bool.mjs";
import * as $bytes_tree from "../../../gleam_stdlib/gleam/bytes_tree.mjs";
import * as $result from "../../../gleam_stdlib/gleam/result.mjs";
import { Ok, toList, makeError, toBitArray, sizedInt } from "../../gleam.mjs";
import * as $hash from "../../kryptos/hash.mjs";

const FILEPATH = "src/kryptos/internal/concat_kdf.gleam";

export function derive_loop(algorithm, secret, info, remaining, counter, acc) {
  return $bool.guard(
    remaining <= 0,
    new Ok($bytes_tree.to_bit_array(acc)),
    () => {
      let input = $bit_array.concat(
        toList([toBitArray([sizedInt(counter, 32, true)]), secret, info]),
      );
      return $result.try$(
        $hash.new$(algorithm),
        (hasher) => {
          let _block;
          let _pipe = hasher;
          let _pipe$1 = $hash.update(_pipe, input);
          _block = $hash.final(_pipe$1);
          let block = _block;
          let length = $bit_array.byte_size(block);
          let $ = remaining <= length;
          if ($) {
            let $1 = $bit_array.slice(block, 0, remaining);
            let final_block;
            if ($1 instanceof Ok) {
              final_block = $1[0];
            } else {
              throw makeError(
                "let_assert",
                FILEPATH,
                "kryptos/internal/concat_kdf",
                37,
                "derive_loop",
                "Pattern match failed, no pattern matched the value.",
                {
                  value: $1,
                  start: 1013,
                  end: 1078,
                  pattern_start: 1024,
                  pattern_end: 1039
                }
              )
            }
            let _pipe$2 = $bytes_tree.append(acc, final_block);
            let _pipe$3 = $bytes_tree.to_bit_array(_pipe$2);
            return new Ok(_pipe$3);
          } else {
            return derive_loop(
              algorithm,
              secret,
              info,
              remaining - length,
              counter + 1,
              $bytes_tree.append(acc, block),
            );
          }
        },
      );
    },
  );
}
