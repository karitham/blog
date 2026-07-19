//// Frontmatter parser for blog posts.
////
//// Posts in `priv/posts/<slug>/index.md` start with a YAML block:
////
////     ---
////     title: My Post
////     description: >-
////       A short summary
////       that can span lines.
////     date: 2026-07-18
////     tags: [gleam, atproto]
////     draft: true
////     ---
////
//// followed by markdown body. `parse` produces a `Post` (or a
//// `ParseError` if anything is wrong). Pure — does no I/O.

import data/model.{type Post, Post}
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp
import mork
import yamleam
import yamleam/error

pub type ParseError {
  MissingField(slug: String, field: String)
  InvalidDate(slug: String, value: String)
  InvalidYaml(slug: String, error: String)
}

/// Parse raw markdown content (frontmatter + body) into a Post.
/// Returns an error if a required field is missing, the date is
/// malformed, or the YAML is invalid.
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
  let decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use date <- decode.field("date", decode.string)
    use tags <- decode.optional_field("tags", [], decode.list(decode.string))
    use draft <- decode.optional_field("draft", False, decode.bool)
    use image <- decode.optional_field("image", "", decode.string)
    decode.success(Post(
      title:,
      description:,
      slug:,
      date:,
      content: "",
      tags:,
      draft:,
      image:,
    ))
  }

  case yamleam.parse(frontmatter, decoder) {
    Ok(post) -> {
      case parse_article_date(post.date) {
        Ok(_) -> {
          let options = mork.configure() |> mork.heading_ids(True)

          let html_body =
            body
            |> string.trim
            |> mork.parse_with_options(options, _)
            |> mork.to_html
            |> inject_heading_anchors
          Ok(Post(..post, content: html_body))
        }
        Error(_) -> Error(InvalidDate(slug, post.date))
      }
    }
    Error(err) -> Error(InvalidYaml(slug, error.to_string(err)))
  }
}

/// Validate a `YYYY-MM-DD` or RFC 3339 frontmatter date via `gleam_time`.
/// The raw string is still stored on `Post` for RSS/OG output; this is
/// only used to fail the build loudly on a malformed date.
fn parse_article_date(s: String) -> Result(timestamp.Timestamp, Nil) {
  timestamp.parse_rfc3339(s <> "T00:00:00Z")
}

/// Post-process mork HTML to inject anchor links inside headings
/// that have an `id` attribute, so section headings become
/// clickable permalinks.
fn inject_heading_anchors(html: String) -> String {
  ["2", "3", "4"]
  |> list.fold(html, fn(acc, level) { inject_for_level(acc, level) })
}

fn inject_for_level(html: String, level: String) -> String {
  let tag = "<h" <> level <> " id=\""
  inject_rec(html, tag, level)
}

fn inject_rec(html: String, tag: String, level: String) -> String {
  case string.split_once(html, on: tag) {
    Error(_) -> html
    Ok(#(before, after)) -> {
      // `after` starts with the id value (right after `id="`)
      case string.split_once(after, on: "\"") {
        Error(_) -> html
        Ok(#(id, after_id)) -> {
          // `after_id` starts with `>...` (the closing `>` of the tag)
          case string.split_once(after_id, on: ">") {
            Error(_) -> html
            Ok(#(_, content)) -> {
              let closing = "</h" <> level <> ">"
              case string.split_once(content, on: closing) {
                Error(_) -> html
                Ok(#(inner, rest)) -> {
                  let a = "<a href=\"#" <> id <> "\" class=\"anchor\">"
                  before
                  <> tag
                  <> id
                  <> "\">"
                  <> a
                  <> inner
                  <> "</a>"
                  <> closing
                  <> inject_rec(rest, tag, level)
                }
              }
            }
          }
        }
      }
    }
  }
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
