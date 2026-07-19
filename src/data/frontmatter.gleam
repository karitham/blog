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
import gleam/result
import gleam/string
import gleam/time/timestamp
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

  case title == "", date == "", parse_article_date(date) {
    True, _, _ -> Error(MissingField(slug, "title"))
    _, True, _ -> Error(MissingField(slug, "date"))
    _, _, Error(_) -> Error(InvalidDate(slug, date))
    False, False, Ok(_) ->
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

/// Validate a `YYYY-MM-DD` or RFC 3339 frontmatter date via `gleam_time`.
/// The raw string is still stored on `Post` for RSS/OG output; this is
/// only used to fail the build loudly on a malformed date.
fn parse_article_date(s: String) -> Result(timestamp.Timestamp, Nil) {
  timestamp.parse_rfc3339(s <> "T00:00:00Z")
}

const slug_chars = "abcdefghijklmnopqrstuvwxyz0123456789-"

const slug_start_chars = "abcdefghijklmnopqrstuvwxyz0123456789"

/// Validates that a string is a usable post slug: starts with a
/// lowercase letter or digit, contains only lowercase letters,
/// digits, and hyphens. Must not be empty.
pub fn is_valid_slug(slug: String) -> Bool {
  case slug {
    "" -> False
    _ -> {
      let first = string.first(slug) |> result.unwrap("")
      string.contains(slug_start_chars, first)
      && list.all(string.to_graphemes(slug), fn(c) {
        string.contains(slug_chars, c)
      })
    }
  }
}
