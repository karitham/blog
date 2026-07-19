import * as $float from "../gleam_stdlib/gleam/float.mjs";
import * as $int from "../gleam_stdlib/gleam/int.mjs";
import * as $calendar from "../gleam_time/gleam/time/calendar.mjs";
import * as $timestamp from "../gleam_time/gleam/time/timestamp.mjs";
import { Ok } from "./gleam.mjs";

/**
 * Format a `timestamp.Timestamp` as `Month DD, YYYY` in UTC.
 */
export function format_month_day_year(ts) {
  let $ = $timestamp.to_calendar(ts, $calendar.utc_offset);
  let date = $[0];
  return ((($calendar.month_to_string(date.month) + " ") + $int.to_string(
    date.day,
  )) + ", ") + $int.to_string(date.year);
}

/**
 * Format a `YYYY-MM-DD` string as `Month DD, YYYY` via `gleam_time`.
 * Returns the original string unmodified on parse failure.
 */
export function format_ymd(date_str) {
  let $ = $timestamp.parse_rfc3339(date_str + "T00:00:00Z");
  if ($ instanceof Ok) {
    let ts = $[0];
    return format_month_day_year(ts);
  } else {
    return date_str;
  }
}

/**
 * Zero-pad an integer to two digits.
 */
export function pad2(n) {
  let $ = n < 10;
  if ($) {
    return "0" + $int.to_string(n);
  } else {
    return $int.to_string(n);
  }
}

/**
 * Three-letter month abbreviation for RFC 822.
 * 
 * @ignore
 */
function month_abbr(month) {
  if (month instanceof $calendar.January) {
    return "Jan";
  } else if (month instanceof $calendar.February) {
    return "Feb";
  } else if (month instanceof $calendar.March) {
    return "Mar";
  } else if (month instanceof $calendar.April) {
    return "Apr";
  } else if (month instanceof $calendar.May) {
    return "May";
  } else if (month instanceof $calendar.June) {
    return "Jun";
  } else if (month instanceof $calendar.July) {
    return "Jul";
  } else if (month instanceof $calendar.August) {
    return "Aug";
  } else if (month instanceof $calendar.September) {
    return "Sep";
  } else if (month instanceof $calendar.October) {
    return "Oct";
  } else if (month instanceof $calendar.November) {
    return "Nov";
  } else {
    return "Dec";
  }
}

/**
 * Derive the three-letter weekday name from Unix epoch seconds.
 * 1970-01-01 (unix epoch) is a Thursday (index 4).
 * 
 * @ignore
 */
function weekday_name(unix_seconds) {
  let w = (4 + (globalThis.Math.trunc(unix_seconds / 86_400))) % 7;
  if (w === 0) {
    return "Sun";
  } else if (w === 1) {
    return "Mon";
  } else if (w === 2) {
    return "Tue";
  } else if (w === 3) {
    return "Wed";
  } else if (w === 4) {
    return "Thu";
  } else if (w === 5) {
    return "Fri";
  } else if (w === 6) {
    return "Sat";
  } else {
    return "Thu";
  }
}

/**
 * Format a `YYYY-MM-DD` string as an RFC 822 timestamp for RSS
 * `<pubDate>`, e.g. `"Sat, 21 Sep 2024 00:00:00 +0000"`. The
 * weekday is derived from the Unix epoch seconds via `gleam_time`.
 */
export function to_rfc822(date_str) {
  let $ = $timestamp.parse_rfc3339(date_str + "T00:00:00Z");
  if ($ instanceof Ok) {
    let ts = $[0];
    let $1 = $timestamp.to_calendar(ts, $calendar.utc_offset);
    let date = $1[0];
    let _block;
    let _pipe = $timestamp.to_unix_seconds(ts);
    _block = $float.round(_pipe);
    let seconds = _block;
    let weekday = weekday_name(seconds);
    let month = month_abbr(date.month);
    return ((((((weekday + ", ") + pad2(date.day)) + " ") + month) + " ") + $int.to_string(
      date.year,
    )) + " 00:00:00 +0000";
  } else {
    return date_str;
  }
}
