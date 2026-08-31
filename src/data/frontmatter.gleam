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
import gleam/option
import gleam/string
import gleam/time/timestamp
import mork
import yamleam
import yamleam/error

pub type ParseError {
  MissingField(slug: String, field: String)
  InvalidDate(slug: String, value: String)
  InvalidYaml(slug: String, error: String)
  InvalidSlug(slug: String, reason: String)
}

/// Parse raw markdown content (frontmatter + body) into a Post.
/// Returns an error if a required field is missing, the date is
/// malformed, the slug is invalid, or the YAML is invalid.
/// Labels disambiguate the two `String` params at the call site.
pub fn parse(
  slug slug: String,
  content content: String,
) -> Result(Post, ParseError) {
  case model.parse_slug(slug) {
    Error(reason) -> Error(InvalidSlug(slug, string.inspect(reason)))
    Ok(valid_slug) -> {
      // Normalize CRLF to LF so Windows-authored files work, then
      // accept both "\n---\n" and bare trailing "\n---".
      let normalized = string.replace(content, "\r\n", "\n")
      case string.split_once(normalized, on: "\n---\n") {
        Ok(#(frontmatter, body)) ->
          parse_with_frontmatter(
            slug: valid_slug,
            frontmatter: frontmatter,
            body: body,
          )
        Error(_) ->
          case string.split_once(normalized, on: "\n---") {
            Ok(#(frontmatter, body)) ->
              parse_with_frontmatter(
                slug: valid_slug,
                frontmatter: frontmatter,
                body: body,
              )
            Error(_) -> Error(MissingField(slug, "frontmatter delimiter (---)"))
          }
      }
    }
  }
}

fn parse_with_frontmatter(
  slug slug: model.Slug,
  frontmatter frontmatter: String,
  body body: String,
) -> Result(Post, ParseError) {
  let decoder = {
    use title <- decode.field("title", decode.string)
    use description <- decode.optional_field("description", "", decode.string)
    use date <- decode.field("date", decode.string)
    use tags <- decode.optional_field("tags", [], decode.list(decode.string))
    use draft <- decode.optional_field("draft", False, decode.bool)
    use image_opt <- decode.optional_field(
      "image",
      option.None,
      decode.optional(decode.string),
    )
    // Normalize explicit `image: ""` to `None` — same contract as
    // stats' `empty_to_none`; an empty string is not a valid image.
    let image = case image_opt {
      option.Some("") -> option.None
      _ -> image_opt
    }
    decode.success(Post(
      title:,
      description:,
      slug: slug,
      date:,
      content: "",
      tags:,
      draft:,
      image: image,
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
        Error(_) -> Error(InvalidDate(model.slug_to_string(slug), post.date))
      }
    }
    Error(err) ->
      Error(InvalidYaml(model.slug_to_string(slug), error.to_string(err)))
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

/// Validates that a string is a usable post slug: starts with a
/// lowercase letter or digit, contains only lowercase letters,
/// digits, and hyphens. Must not be empty.
/// Delegates to `model.parse_slug` so the two checks cannot drift.
pub fn is_valid_slug(slug: String) -> Bool {
  case model.parse_slug(slug) {
    Ok(_) -> True
    Error(_) -> False
  }
}
