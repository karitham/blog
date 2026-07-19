import date
import gleam/time/timestamp
import gleeunit/should

// --- pad2 ---

pub fn pad2_single_digit_test() {
  date.pad2(0) |> should.equal("00")
  date.pad2(5) |> should.equal("05")
  date.pad2(9) |> should.equal("09")
}

pub fn pad2_double_digit_test() {
  date.pad2(10) |> should.equal("10")
  date.pad2(23) |> should.equal("23")
  date.pad2(59) |> should.equal("59")
}

pub fn pad2_large_numbers_test() {
  date.pad2(100) |> should.equal("100")
  date.pad2(999) |> should.equal("999")
}

// --- format_month_day_year ---

fn ts(iso: String) -> timestamp.Timestamp {
  let assert Ok(t) = timestamp.parse_rfc3339(iso)
  t
}

pub fn format_month_day_year_january_test() {
  ts("2026-01-15T00:00:00Z")
  |> date.format_month_day_year
  |> should.equal("January 15, 2026")
}

pub fn format_month_day_year_december_test() {
  ts("2026-12-31T23:59:59Z")
  |> date.format_month_day_year
  |> should.equal("December 31, 2026")
}

pub fn format_month_day_year_midnight_test() {
  // Midnight is still the same day in UTC
  ts("2026-07-04T00:00:00Z")
  |> date.format_month_day_year
  |> should.equal("July 4, 2026")
}

pub fn format_month_day_year_non_utc_offset_test() {
  // An RFC 3339 timestamp with +03:00 offset — to_calendar with
  // utc_offset converts it to UTC first, so July 4 03:00+03 is
  // still July 4 00:00 UTC.
  ts("2026-07-04T03:00:00+03:00")
  |> date.format_month_day_year
  |> should.equal("July 4, 2026")
}

pub fn format_month_day_year_utc_minus_offset_test() {
  // 2026-07-03T22:00:00-02:00 is 2026-07-04T00:00:00Z
  ts("2026-07-03T22:00:00-02:00")
  |> date.format_month_day_year
  |> should.equal("July 4, 2026")
}

pub fn format_month_day_year_leap_year_test() {
  ts("2028-02-29T12:00:00Z")
  |> date.format_month_day_year
  |> should.equal("February 29, 2028")
}

// --- format_ymd ---

pub fn format_ymd_basic_test() {
  date.format_ymd("2026-07-18") |> should.equal("July 18, 2026")
}

pub fn format_ymd_january_first_test() {
  date.format_ymd("2024-01-01") |> should.equal("January 1, 2024")
}

pub fn format_ymd_december_test() {
  date.format_ymd("2026-12-31") |> should.equal("December 31, 2026")
}

pub fn format_ymd_invalid_returns_original_test() {
  date.format_ymd("garbage") |> should.equal("garbage")
  date.format_ymd("") |> should.equal("")
  date.format_ymd("2024/01/01") |> should.equal("2024/01/01")
}

// --- to_rfc822 ---

pub fn to_rfc822_basic_test() {
  // 2024-09-21 is a Saturday
  date.to_rfc822("2024-09-21")
  |> should.equal("Sat, 21 Sep 2024 00:00:00 +0000")
}

pub fn to_rfc822_weekday_varies_test() {
  // 2024-09-23 is a Monday
  date.to_rfc822("2024-09-23")
  |> should.equal("Mon, 23 Sep 2024 00:00:00 +0000")
}

pub fn to_rfc822_january_first_1970_test() {
  // 1970-01-01 is a Thursday
  date.to_rfc822("1970-01-01")
  |> should.equal("Thu, 01 Jan 1970 00:00:00 +0000")
}

pub fn to_rfc822_leap_day_test() {
  // 2028-02-29 is a Tuesday
  date.to_rfc822("2028-02-29")
  |> should.equal("Tue, 29 Feb 2028 00:00:00 +0000")
}

pub fn to_rfc822_invalid_returns_original_test() {
  date.to_rfc822("not-a-date") |> should.equal("not-a-date")
}
