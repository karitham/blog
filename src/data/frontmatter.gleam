//// Frontmatter parser for blog posts.
////
//// Posts in `priv/posts/<slug>/index.md` start with a YAML-ish block:
////
////     ---
////     title: My Post
////     description: short summary
////     date: 2026-07-18
////     tags: [gleam, atproto]
////     draft: true
////     ---
////
//// followed by markdown body. `parse` produces a `Post` (or a
//// `ParseError` if anything is wrong). Pure — does no I/O.

import data/model.{type Post, Post}
import data/util
import gleam/list
import gleam/string
import mork

pub type ParseError {
  MissingField(slug: String, field: String)
  InvalidDate(slug: String, value: String)
}

/// Parse raw markdown content (frontmatter + body) into a Post.
/// Returns an error if a required field is missing or the date is
/// malformed — the build fails loudly on those rather than
/// silently producing a broken post.
pub fn parse(slug: String, content: String) -> Result(Post, ParseError) {
  case string.split(content, on: "\n---\n") {
    [frontmatter, body] -> parse_with_frontmatter(slug, frontmatter, body)
    _ -> Error(MissingField(slug, "frontmatter delimiter (---)"))
  }
}

fn parse_with_frontmatter(
  slug: String,
  frontmatter: String,
  body: String,
) -> Result(Post, ParseError) {
  let lines = string.split(frontmatter, "\n")
  let title = util.extract_field(lines, "title:", "")
  let description = util.extract_field(lines, "description:", "")
  let date = util.extract_field(lines, "date:", "")
  let tags_str = util.extract_field(lines, "tags:", "[]")
  let draft_str = util.extract_field(lines, "draft:", "false")
  let image = util.extract_field(lines, "image:", "")

  case title == "", date == "", is_iso_date(date) {
    True, _, _ -> Error(MissingField(slug, "title"))
    _, True, _ -> Error(MissingField(slug, "date"))
    _, _, False -> Error(InvalidDate(slug, date))
    False, False, True ->
      Ok(build_post(
        slug,
        title,
        description,
        date,
        tags_str,
        draft_str,
        body,
        image,
      ))
  }
}

fn build_post(
  slug slug: String,
  title title: String,
  description description: String,
  date date: String,
  tags_str tags_str: String,
  draft_str draft_str: String,
  body body: String,
  image image: String,
) -> Post {
  let html_body =
    body
    |> string.trim
    |> mork.parse
    |> mork.to_html

  Post(
    title: title,
    description: description,
    slug: slug,
    date: date,
    content: html_body,
    tags: parse_tags_field(tags_str),
    draft: parse_bool(draft_str),
    image: image,
  )
}

fn parse_tags_field(tags_str: String) -> List(String) {
  tags_str
  |> string.trim
  |> strip_brackets
  |> split_tags
}

fn strip_brackets(s: String) -> String {
  s
  |> string.drop_start(1)
  |> string.drop_end(1)
}

fn split_tags(s: String) -> List(String) {
  case s {
    "" -> []
    _ -> s |> string.split(",") |> list.map(string.trim)
  }
}

fn parse_bool(s: String) -> Bool {
  case string.lowercase(string.trim(s)) {
    "true" | "yes" | "1" -> True
    _ -> False
  }
}

/// Check that a string matches the `YYYY-MM-DD` shape. Does not
/// validate calendar correctness (e.g. "2024-02-31" passes).
pub fn is_iso_date(s: String) -> Bool {
  case string.split(s, on: "-") {
    [y, m, d] ->
      string.length(y) == 4
      && string.length(m) == 2
      && string.length(d) == 2
      && is_all_digits(y)
      && is_all_digits(m)
      && is_all_digits(d)
    _ -> False
  }
}

fn is_all_digits(s: String) -> Bool {
  case s {
    "" -> False
    _ -> s |> string.to_graphemes |> list.all(is_digit_char)
  }
}

fn is_digit_char(c: String) -> Bool {
  case c {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

/// Validates that a string is a usable post slug: starts with a
/// lowercase letter or digit, contains only lowercase letters,
/// digits, and hyphens. Must not be empty.
pub fn is_valid_slug(slug: String) -> Bool {
  case slug {
    "" -> False
    _ ->
      slug
      |> string.to_graphemes
      |> list.all(is_slug_char)
      && is_slug_start(slug |> string.first |> result_unwrap(""))
  }
}

fn is_slug_char(c: String) -> Bool {
  case c {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9"
    | "-" -> True
    _ -> False
  }
}

fn is_slug_start(c: String) -> Bool {
  case c {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9" -> True
    _ -> False
  }
}

// Silly wrapper to make the type checker happy when string.first
// returns Error — the empty string default makes is_slug_start
// return False, which is what we want.
fn result_unwrap(r: Result(a, b), default: a) -> a {
  case r {
    Ok(v) -> v
    Error(_) -> default
  }
}
