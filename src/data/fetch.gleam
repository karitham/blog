import api
import data/frontmatter
import data/model.{type Post, type SiteData, SiteData}
import data/transport
import fetch
import gen/actor/defs.{type ProfileViewDetailed}
import gen/actor/profile.{actor_profile_decoder}
import gen/alpha/feed/play.{type AlphaFeedPlay, alpha_feed_play_decoder}
import gen/client.{
  ActorGetProfileParams, RepoListRecordsParams, actor_get_profile,
  repo_list_records,
}
import gen/repo.{type Repo, repo_decoder}
import gleam/dynamic/decode
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import gleam/string
import simplifile

pub fn fetch_all() -> SiteData {
  let client = transport.http_client()

  let profile = fetch_profile(client)
  let recent_plays = fetch_plays(client)
  let repos = fetch_repos(client)
  let posts = read_posts()

  SiteData(profile:, recent_plays:, repos:, posts:)
}

fn fetch_profile(client) -> ProfileViewDetailed {
  let params = ActorGetProfileParams(actor: "karitham.dev")
  case actor_get_profile(client, api.public_api, params, None) {
    Ok(profile) -> profile
    Error(e) -> {
      io.println("Failed to fetch profile: " <> string.inspect(e))
      panic as "profile fetch failed"
    }
  }
}

fn fetch_plays(client) -> List(AlphaFeedPlay) {
  let params =
    RepoListRecordsParams(
      repo: api.did,
      collection: "fm.teal.alpha.feed.play",
      limit: Some(api.plays_limit),
      cursor: None,
      reverse: None,
    )
  case repo_list_records(client, api.pds_endpoint, params, None) {
    Ok(output) ->
      fetch.decode_record_values(output.records, alpha_feed_play_decoder())
    Error(e) -> {
      io.println("Failed to fetch plays: " <> string.inspect(e))
      []
    }
  }
}

fn fetch_repos(client) -> List(Repo) {
  let pinned_dids = fetch_pinned_dids(client)

  let repos = fetch_all_repos(client)

  api.filter_pinned_repos(repos, pinned_dids)
}

fn fetch_pinned_dids(client) -> List(String) {
  let params =
    RepoListRecordsParams(
      repo: api.did,
      collection: "sh.tangled.actor.profile",
      limit: None,
      cursor: None,
      reverse: None,
    )
  case repo_list_records(client, api.pds_endpoint, params, None) {
    Ok(output) ->
      output.records
      |> list.map(fn(record) {
        decode.run(record.value, actor_profile_decoder())
      })
      |> result.values
      |> list.map(fn(profile) {
        case profile.pinned_repositories {
          Some(dids) -> dids
          None -> []
        }
      })
      |> list.flatten
      |> list.filter(fn(d) { d != "" })
    Error(e) -> {
      io.println("Failed to fetch pinned DIDs: " <> string.inspect(e))
      []
    }
  }
}

fn fetch_all_repos(client) -> List(Repo) {
  let params =
    RepoListRecordsParams(
      repo: api.did,
      collection: "sh.tangled.repo",
      limit: None,
      cursor: None,
      reverse: None,
    )
  case repo_list_records(client, api.pds_endpoint, params, None) {
    Ok(output) -> fetch.decode_record_values(output.records, repo_decoder())
    Error(e) -> {
      io.println("Failed to fetch repos: " <> string.inspect(e))
      []
    }
  }
}

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
