//// Pure slug and title helpers for the CLI. No I/O, no time — the
//// template's date is injected by `cli.gleam`.

import gleam/list
import gleam/string

/// Normalize free-form text into a valid slug: lowercase, every
/// non-`[a-z0-9-]` character becomes a hyphen, runs of hyphens
/// collapse to one, leading/trailing hyphens stripped. Returns
/// `""` for input that contains no usable characters.
pub fn slugify(input: String) -> String {
  input
  |> string.lowercase
  |> string.trim
  |> string.to_graphemes
  |> list.map(slugify_char)
  |> string.join("")
  |> collapse_dashes
  |> trim_dashes
}

fn slugify_char(c: String) -> String {
  case string.contains("abcdefghijklmnopqrstuvwxyz0123456789-", c) {
    True -> c
    False -> "-"
  }
}

fn collapse_dashes(s: String) -> String {
  case string.contains(s, "--") {
    True -> collapse_dashes(string.replace(s, each: "--", with: "-"))
    False -> s
  }
}

fn trim_dashes(s: String) -> String {
  case string.starts_with(s, "-") {
    True -> trim_dashes(string.drop_start(s, 1))
    False ->
      case string.ends_with(s, "-") {
        True -> trim_dashes(string.drop_end(s, 1))
        False -> s
      }
  }
}

/// Best-effort title from a slug: `"hello-world"` -> `"Hello World"`.
/// The user overwrites the title anyway once they start writing.
pub fn title_from_slug(slug: String) -> String {
  slug
  |> string.split(on: "-")
  |> list.map(capitalize)
  |> string.join(" ")
}

fn capitalize(word: String) -> String {
  case string.to_graphemes(word) {
    [] -> ""
    [first, ..rest] -> string.uppercase(first) <> string.join(rest, "")
  }
}
