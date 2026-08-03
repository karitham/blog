//// Client-side runtime orchestration.
////
//// Fetches fresh data and re-renders all dynamic sections on page load.
//// Plays are then polled every 30s while the tab is visible.

import browser
import dynamic
import fetch
import gen/alpha/feed/play.{type AlphaFeedPlay}
import gen/repo.{type Repo}
import gleam/list
import gleam/string
import plays as plays_view
import profile as profile_view
import repos as repos_view

/// Short enough that a new track shows up promptly, long enough that
/// we're not hammering the PDS.
const plays_poll_ms = 30_000

/// Wires up initial fetches, periodic poll, and visibility listener.
pub fn start() -> Nil {
  // Guard: only run refresh logic on pages with dynamic sections.
  case browser.has_element("profile-section") {
    False -> Nil
    True -> {
      refresh_all()
      browser.localize_dates()
      browser.set_interval(plays_poll_ms, poll_tick)
      browser.on_visibility_change(on_visibility_change)
    }
  }
}

fn refresh_all() -> Nil {
  fetch_profile()
  fetch_pinned_dids_and_repos()
  refresh_plays()
}

fn fetch_profile() -> Nil {
  browser.fetch_text(fetch.profile_url(), on_profile)
}

fn on_profile(text: String) -> Nil {
  case fetch.decode_profile(text) {
    Ok(profile) ->
      browser.set_inner_html(
        "profile-section",
        dynamic.render(profile_view.profile(profile)),
      )
    Error(reason) ->
      browser.log_error("decode_profile failed: " <> string.inspect(reason))
  }
}

fn fetch_pinned_dids_and_repos() -> Nil {
  browser.fetch_text(fetch.pinned_dids_url(), fn(pinned_text) {
    case fetch.decode_actor_profiles(pinned_text) {
      Ok(profiles) -> {
        let pinned_dids = fetch.pinned_dids_from_profiles(profiles)
        browser.fetch_text(fetch.repos_url(), fn(repos_text) {
          case fetch.decode_repos(repos_text) {
            Ok(records) -> {
              let repos =
                records
                |> fetch.filter_repos_by_did(pinned_dids)
                |> list.map(fetch.resolve_repo_name)
                |> list.map(fn(record) { record.value })
              commit_repos(repos)
            }
            Error(reason) ->
              browser.log_error(
                "decode_repos failed: " <> string.inspect(reason),
              )
          }
        })
      }
      Error(reason) ->
        browser.log_error(
          "decode_actor_profiles failed: " <> string.inspect(reason),
        )
    }
  })
}

fn commit_repos(repos: List(Repo)) -> Nil {
  browser.set_inner_html(
    "repos",
    dynamic.render(repos_view.repos_section(repos)),
  )
}

fn refresh_plays() -> Nil {
  mark_plays_stale()
  browser.fetch_text(fetch.plays_url(), on_plays)
}

fn on_plays(text: String) -> Nil {
  case fetch.decode_plays(text) {
    Ok([]) -> mark_plays_fresh()
    Ok(plays_data) -> commit_plays(plays_data)
    Error(reason) -> {
      browser.log_error("decode_plays failed: " <> string.inspect(reason))
      mark_plays_fresh()
    }
  }
}

fn commit_plays(plays_data: List(AlphaFeedPlay)) -> Nil {
  browser.set_inner_html(
    "plays-rows",
    dynamic.render(plays_view.plays_rows(plays_data)),
  )
  browser.localize_dates()
  mark_plays_fresh()
}

fn mark_plays_stale() -> Nil {
  browser.set_attribute("plays", "data-stale", "true")
}

fn mark_plays_fresh() -> Nil {
  browser.remove_attribute("plays", "data-stale")
}

fn poll_tick() -> Nil {
  case browser.is_visible() {
    True -> refresh_plays()
    False -> Nil
  }
}

fn on_visibility_change(visible: Bool) -> Nil {
  case visible {
    True -> refresh_all()
    False -> Nil
  }
}
