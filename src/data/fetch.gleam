//// Gather all site data for the SSG.
////
//// Each section fetches its own URL through the shared decoders in
//// `shared/src/fetch.gleam`. Failure on a section logs a warning
//// and returns an empty value, so one slow PDS doesn't take the
//// whole build down.

import data/frontmatter
import data/model.{type Post, type SiteData, SiteData}
import data/transport
import fetch.{type DecodedRecord}
import gen/alpha/feed/play.{type AlphaFeedPlay}
import gen/repo.{type Repo}
import gleam/io
import gleam/list
import gleam/order
import gleam/string
import simplifile

pub fn fetch_all() -> SiteData {
  let pinned_dids = fetch_pinned_dids()
  let profile = fetch_profile()
  let recent_plays = fetch_plays()
  let repos = fetch_repos(pinned_dids)

  SiteData(profile:, recent_plays:, repos:, posts: read_posts())
}

// --- profile ---

fn fetch_profile() {
  case transport.fetch_body(fetch.profile_url()) {
    Ok(body) ->
      case fetch.decode_profile(body) {
        Ok(profile) -> profile
        Error(e) -> log_fail_and_panic("profile", string.inspect(e))
      }
    Error(e) -> log_fail_and_panic("profile", e)
  }
}

// --- plays ---

fn fetch_plays() -> List(AlphaFeedPlay) {
  case transport.fetch_body(fetch.plays_url()) {
    Ok(body) ->
      case fetch.decode_plays(body) {
        Ok(plays) -> plays
        Error(e) -> log_fail("plays", string.inspect(e), [])
      }
    Error(e) -> log_fail("plays", e, [])
  }
}

// --- repos ---

fn fetch_repos(pinned_dids: List(String)) -> List(DecodedRecord(Repo)) {
  case transport.fetch_body(fetch.repos_url()) {
    Ok(body) ->
      case fetch.decode_repos(body) {
        Ok(records) ->
          records
          |> fetch.filter_repos_by_did(pinned_dids)
          |> list.map(fetch.resolve_repo_name)
        Error(e) -> log_fail("repos", string.inspect(e), [])
      }
    Error(e) -> log_fail("repos", e, [])
  }
}

// --- pinned DIDs ---

fn fetch_pinned_dids() -> List(String) {
  case transport.fetch_body(fetch.pinned_dids_url()) {
    Ok(body) ->
      case fetch.decode_actor_profiles(body) {
        Ok(profiles) -> fetch.pinned_dids_from_profiles(profiles)
        Error(_) -> []
      }
    Error(_) -> []
  }
}

// --- posts (filesystem, not HTTP) ---

/// Read every post under `priv/posts/<slug>/index.md`. Includes
/// drafts (caller filters them). Fails the build if any post has
/// an invalid slug or frontmatter — see `data/frontmatter.gleam`
/// for what counts as invalid.
pub fn read_posts() -> List(Post) {
  case simplifile.read_directory("priv/posts") {
    Ok(entries) ->
      entries
      |> list.filter(fn(entry) {
        case simplifile.is_directory("priv/posts/" <> entry) {
          Ok(True) -> True
          _ -> False
        }
      })
      |> list.map(read_post)
      |> list.sort(by: compare_posts_desc)
    Error(_) -> []
  }
}

fn read_post(slug: String) -> Post {
  case frontmatter.is_valid_slug(slug) {
    False -> {
      io.println(
        "Error: post directory \""
        <> slug
        <> "\" is not a valid slug (lowercase letters, digits, and hyphens only).",
      )
      panic as "invalid slug"
    }
    True -> {
      let path = "priv/posts/" <> slug <> "/index.md"
      case simplifile.read(path) {
        Ok(content) ->
          case frontmatter.parse(slug, content) {
            Ok(post) -> post
            Error(e) -> {
              io.println("Error: " <> format_parse_error(slug, e))
              panic as "post parse failed"
            }
          }
        Error(e) -> {
          io.println(
            "Failed to read post " <> slug <> ": " <> string.inspect(e),
          )
          panic as "post read failed"
        }
      }
    }
  }
}

fn format_parse_error(slug: String, e: frontmatter.ParseError) -> String {
  case e {
    frontmatter.MissingField(_, field) ->
      "post \"" <> slug <> "\" is missing required field \"" <> field <> "\""
    frontmatter.InvalidDate(_, value) ->
      "post \""
      <> slug
      <> "\" has invalid date \""
      <> value
      <> "\" (expected YYYY-MM-DD)"
    frontmatter.InvalidYaml(_, error) ->
      "post \"" <> slug <> "\" has invalid frontmatter: " <> error
  }
}

fn compare_posts_desc(a: Post, b: Post) -> order.Order {
  string.compare(b.date, a.date)
}

// --- logging ---

fn log_fail_and_panic(what: String, reason: String) -> a {
  io.println("Failed to fetch " <> what <> ": " <> reason)
  panic as "required fetch failed"
}

fn log_fail(what: String, reason: String, fallback: a) -> a {
  io.println("Failed to fetch " <> what <> ": " <> reason)
  fallback
}
