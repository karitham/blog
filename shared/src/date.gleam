//// Shared date formatting utilities.

import gleam/float
import gleam/int
import gleam/time/calendar
import gleam/time/timestamp

/// Format a `timestamp.Timestamp` as `Month DD, YYYY` in UTC.
pub fn format_month_day_year(ts: timestamp.Timestamp) -> String {
  let #(date, _) = timestamp.to_calendar(ts, calendar.utc_offset)
  calendar.month_to_string(date.month)
  <> " "
  <> int.to_string(date.day)
  <> ", "
  <> int.to_string(date.year)
}

/// Format a `YYYY-MM-DD` string as `Month DD, YYYY` via `gleam_time`.
/// Returns the original string unmodified on parse failure.
pub fn format_ymd(date_str: String) -> String {
  case timestamp.parse_rfc3339(date_str <> "T00:00:00Z") {
    Ok(ts) -> format_month_day_year(ts)
    Error(_) -> date_str
  }
}

/// Format a `YYYY-MM-DD` string as an RFC 822 timestamp for RSS
/// `<pubDate>`, e.g. `"Sat, 21 Sep 2024 00:00:00 +0000"`. The
/// weekday is derived from the Unix epoch seconds via `gleam_time`.
pub fn to_rfc822(date_str: String) -> String {
  case timestamp.parse_rfc3339(date_str <> "T00:00:00Z") {
    Ok(ts) -> {
      let #(date, _) = timestamp.to_calendar(ts, calendar.utc_offset)
      let seconds = timestamp.to_unix_seconds(ts) |> float.round
      let weekday = weekday_name(seconds)
      let month = month_abbr(date.month)
      weekday
      <> ", "
      <> pad2(date.day)
      <> " "
      <> month
      <> " "
      <> int.to_string(date.year)
      <> " 00:00:00 +0000"
    }
    Error(_) -> date_str
  }
}

/// Derive the three-letter weekday name from Unix epoch seconds.
/// 1970-01-01 (unix epoch) is a Thursday (index 4).
fn weekday_name(unix_seconds: Int) -> String {
  let w = { 4 + unix_seconds / 86_400 } % 7
  case w {
    0 -> "Sun"
    1 -> "Mon"
    2 -> "Tue"
    3 -> "Wed"
    4 -> "Thu"
    5 -> "Fri"
    6 -> "Sat"
    _ -> "Thu"
  }
}

/// Three-letter month abbreviation for RFC 822.
fn month_abbr(month: calendar.Month) -> String {
  case month {
    calendar.January -> "Jan"
    calendar.February -> "Feb"
    calendar.March -> "Mar"
    calendar.April -> "Apr"
    calendar.May -> "May"
    calendar.June -> "Jun"
    calendar.July -> "Jul"
    calendar.August -> "Aug"
    calendar.September -> "Sep"
    calendar.October -> "Oct"
    calendar.November -> "Nov"
    calendar.December -> "Dec"
  }
}

/// Zero-pad an integer to two digits.
pub fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}
