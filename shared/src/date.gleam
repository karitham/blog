//// Pure formatters shared between the SSG and the client.

import gleam/option.{type Option, None, Some}
import gleam/string

/// Format a `YYYY-MM-DD` date string as `Month DD, YYYY` (e.g.
/// `"2024-09-21"` → `"September 21, 2024"`). Returns the input
/// unchanged when it can't be parsed so a malformed date surfaces
/// in the page rather than silently becoming a wrong-looking but
/// plausible string.
pub fn format_date(date_str: String) -> String {
  case string.split(date_str, "-") {
    [year, month, day] ->
      case month_name(month) {
        Some(name) -> name <> " " <> day <> ", " <> year
        None -> date_str
      }
    _ -> date_str
  }
}

fn month_name(month: String) -> Option(String) {
  case month {
    "01" | "1" -> Some("January")
    "02" | "2" -> Some("February")
    "03" | "3" -> Some("March")
    "04" | "4" -> Some("April")
    "05" | "5" -> Some("May")
    "06" | "6" -> Some("June")
    "07" | "7" -> Some("July")
    "08" | "8" -> Some("August")
    "09" | "9" -> Some("September")
    "10" -> Some("October")
    "11" -> Some("November")
    "12" -> Some("December")
    _ -> None
  }
}
