import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../gleam_stdlib/gleam/option.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import { Empty as $Empty } from "./gleam.mjs";

function month_name(month) {
  if (month === "01") {
    return new Some("January");
  } else if (month === "1") {
    return new Some("January");
  } else if (month === "02") {
    return new Some("February");
  } else if (month === "2") {
    return new Some("February");
  } else if (month === "03") {
    return new Some("March");
  } else if (month === "3") {
    return new Some("March");
  } else if (month === "04") {
    return new Some("April");
  } else if (month === "4") {
    return new Some("April");
  } else if (month === "05") {
    return new Some("May");
  } else if (month === "5") {
    return new Some("May");
  } else if (month === "06") {
    return new Some("June");
  } else if (month === "6") {
    return new Some("June");
  } else if (month === "07") {
    return new Some("July");
  } else if (month === "7") {
    return new Some("July");
  } else if (month === "08") {
    return new Some("August");
  } else if (month === "8") {
    return new Some("August");
  } else if (month === "09") {
    return new Some("September");
  } else if (month === "9") {
    return new Some("September");
  } else if (month === "10") {
    return new Some("October");
  } else if (month === "11") {
    return new Some("November");
  } else if (month === "12") {
    return new Some("December");
  } else {
    return new None();
  }
}

/**
 * Format a `YYYY-MM-DD` date string as `Month DD, YYYY` (e.g.
 * `"2024-09-21"` → `"September 21, 2024"`). Returns the input
 * unchanged when it can't be parsed so a malformed date surfaces
 * in the page rather than silently becoming a wrong-looking but
 * plausible string.
 */
export function format_date(date_str) {
  let $ = $string.split(date_str, "-");
  if ($ instanceof $Empty) {
    return date_str;
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      return date_str;
    } else {
      let $2 = $1.tail;
      if ($2 instanceof $Empty) {
        return date_str;
      } else {
        let $3 = $2.tail;
        if ($3 instanceof $Empty) {
          let year = $.head;
          let month = $1.head;
          let day = $2.head;
          let $4 = month_name(month);
          if ($4 instanceof Some) {
            let name = $4[0];
            return (((name + " ") + day) + ", ") + year;
          } else {
            return date_str;
          }
        } else {
          return date_str;
        }
      }
    }
  }
}
