//// Site data assembled by the build.
////
//// `SiteData` is the gathered model passed to `render/page`. `Post`
//// is the validated article; its `slug` is an opaque `Slug` that can
//// only be constructed via `parse_slug`, so an invalid slug is
//// unrepresentable outside this module.

import atproto.{type DecodedRecord}
import gen/actor/defs.{type ProfileViewDetailed}
import gen/feed/play.{type FeedPlay}
import gen/repo.{type Repo}
import gleam/list
import gleam/option.{type Option}
import gleam/string
import stats.{type StatsData}

/// A validated post slug. Construction is via `parse_slug`; the
/// inner string is guaranteed to be `^[a-z0-9][a-z0-9-]*$` and non-empty.
pub opaque type Slug {
  Slug(String)
}

/// Why a slug failed to validate.
pub type SlugError {
  EmptySlug
  InvalidSlug(slug: String)
}

/// Parse a raw string into a `Slug`. Mirrors `frontmatter.is_valid_slug`
/// but returns a typed value so callers cannot forget the check.
pub fn parse_slug(input: String) -> Result(Slug, SlugError) {
  case input {
    "" -> Error(EmptySlug)
    _ -> {
      let first = case string.first(input) {
        Ok(c) -> c
        Error(_) -> ""
      }
      let valid_start = string.contains(slug_start_chars, first)
      let valid_chars =
        list.all(string.to_graphemes(input), fn(c) {
          string.contains(slug_chars, c)
        })
      case valid_start && valid_chars {
        True -> Ok(Slug(input))
        False -> Error(InvalidSlug(input))
      }
    }
  }
}

/// Unsafe slug for tests and fixtures where the literal is known-good.
/// Panics on invalid input — use only with string literals.
pub fn must_slug(input: String) -> Slug {
  case parse_slug(input) {
    Ok(s) -> s
    Error(_) -> panic as { "invalid slug literal: " <> input }
  }
}

/// Raw string inside a `Slug`.
pub fn slug_to_string(slug: Slug) -> String {
  let Slug(s) = slug
  s
}

const slug_chars = "abcdefghijklmnopqrstuvwxyz0123456789-"

const slug_start_chars = "abcdefghijklmnopqrstuvwxyz0123456789"

/// All site data for one build.
pub type SiteData {
  SiteData(
    profile: ProfileViewDetailed,
    recent_plays: List(FeedPlay),
    plays_stats: StatsData,
    repos: List(DecodedRecord(Repo)),
    posts: List(Post),
  )
}

/// A validated blog post. `slug` is opaque; `image` is `None` when the
/// frontmatter has no `image:` key (originally `""`).
pub type Post {
  Post(
    title: String,
    description: String,
    slug: Slug,
    date: String,
    content: String,
    tags: List(String),
    draft: Bool,
    image: Option(String),
  )
}
