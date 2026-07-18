import date
import gleeunit/should

pub fn format_date_standard_test() {
  date.format_date("2024-09-21")
  |> should.equal("September 21, 2024")
}

pub fn format_date_january_test() {
  date.format_date("2024-01-01")
  |> should.equal("January 01, 2024")
}

pub fn format_date_december_test() {
  date.format_date("2024-12-31")
  |> should.equal("December 31, 2024")
}

pub fn format_date_different_year_test() {
  date.format_date("2023-07-04")
  |> should.equal("July 04, 2023")
}

pub fn format_date_unparseable_month_test() {
  // Out-of-range month — surface the input rather than silently
  // emitting a wrong-looking but plausible string. (Previous
  // implementation used the raw "13" as the month name, which
  // produced "13 01, 2024" — almost-right enough to miss in review.)
  date.format_date("2024-13-01")
  |> should.equal("2024-13-01")
}

pub fn format_date_malformed_test() {
  date.format_date("garbage")
  |> should.equal("garbage")
}

pub fn format_date_short_test() {
  date.format_date("2024-09")
  |> should.equal("2024-09")
}
