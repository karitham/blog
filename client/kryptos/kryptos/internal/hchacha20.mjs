import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import { CustomType as $CustomType } from "../../gleam.mjs";
import { subkey } from "./hchacha20_ffi.mjs";

export { subkey };

class State extends $CustomType {
  constructor(s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15) {
    super();
    this.s0 = s0;
    this.s1 = s1;
    this.s2 = s2;
    this.s3 = s3;
    this.s4 = s4;
    this.s5 = s5;
    this.s6 = s6;
    this.s7 = s7;
    this.s8 = s8;
    this.s9 = s9;
    this.s10 = s10;
    this.s11 = s11;
    this.s12 = s12;
    this.s13 = s13;
    this.s14 = s14;
    this.s15 = s15;
  }
}

function rotate_left_32(x, n) {
  let shifted_left = $int.bitwise_shift_left(x, n);
  let shifted_right = $int.bitwise_shift_right(x, 32 - n);
  return $int.bitwise_and(
    $int.bitwise_or(shifted_left, shifted_right),
    0xFFFFFFFF,
  );
}

function add_modulo_32(a, b) {
  return $int.bitwise_and(a + b, 0xFFFFFFFF);
}

/**
 * The ChaCha20 quarter-round function.
 * Operates on 4 32-bit words in the state.
 * 
 * @ignore
 */
function quarter_round(a, b, c, d) {
  let a$1 = add_modulo_32(a, b);
  let d$1 = rotate_left_32($int.bitwise_exclusive_or(d, a$1), 16);
  let c$1 = add_modulo_32(c, d$1);
  let b$1 = rotate_left_32($int.bitwise_exclusive_or(b, c$1), 12);
  let a$2 = add_modulo_32(a$1, b$1);
  let d$2 = rotate_left_32($int.bitwise_exclusive_or(d$1, a$2), 8);
  let c$2 = add_modulo_32(c$1, d$2);
  let b$2 = rotate_left_32($int.bitwise_exclusive_or(b$1, c$2), 7);
  return [a$2, b$2, c$2, d$2];
}

function perform_rounds(loop$state, loop$remaining) {
  while (true) {
    let state = loop$state;
    let remaining = loop$remaining;
    let $ = remaining <= 0;
    if ($) {
      return state;
    } else {
      let $1 = quarter_round(state.s0, state.s4, state.s8, state.s12);
      let s0 = $1[0];
      let s4 = $1[1];
      let s8 = $1[2];
      let s12 = $1[3];
      let $2 = quarter_round(state.s1, state.s5, state.s9, state.s13);
      let s1 = $2[0];
      let s5 = $2[1];
      let s9 = $2[2];
      let s13 = $2[3];
      let $3 = quarter_round(state.s2, state.s6, state.s10, state.s14);
      let s2 = $3[0];
      let s6 = $3[1];
      let s10 = $3[2];
      let s14 = $3[3];
      let $4 = quarter_round(state.s3, state.s7, state.s11, state.s15);
      let s3 = $4[0];
      let s7 = $4[1];
      let s11 = $4[2];
      let s15 = $4[3];
      let $5 = quarter_round(s0, s5, s10, s15);
      let s0$1 = $5[0];
      let s5$1 = $5[1];
      let s10$1 = $5[2];
      let s15$1 = $5[3];
      let $6 = quarter_round(s1, s6, s11, s12);
      let s1$1 = $6[0];
      let s6$1 = $6[1];
      let s11$1 = $6[2];
      let s12$1 = $6[3];
      let $7 = quarter_round(s2, s7, s8, s13);
      let s2$1 = $7[0];
      let s7$1 = $7[1];
      let s8$1 = $7[2];
      let s13$1 = $7[3];
      let $8 = quarter_round(s3, s4, s9, s14);
      let s3$1 = $8[0];
      let s4$1 = $8[1];
      let s9$1 = $8[2];
      let s14$1 = $8[3];
      let state$1 = new State(
        s0$1,
        s1$1,
        s2$1,
        s3$1,
        s4$1,
        s5$1,
        s6$1,
        s7$1,
        s8$1,
        s9$1,
        s10$1,
        s11$1,
        s12$1,
        s13$1,
        s14$1,
        s15$1,
      );
      loop$state = state$1;
      loop$remaining = remaining - 1;
    }
  }
}
