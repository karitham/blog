//// Client-side orchestration — the impure interpreter.
////
//// Fetches fresh data via the browser FFI, decodes via shared,
//// plans via `pipeline.gleam`, and applies the resulting commands
//// with `browser.*` calls. Thin by design: every decision lives in
//// the pure pipeline. Kept imperative (not Lustre MVU) on purpose —
//// async `effect.from` dispatch is unreliable on the JS target.

import atproto
import browser
import commit.{
  type Command, LocalizeDates, RemoveAttr, ReplaceHtml, RewriteRemoteImages,
  SetAttr,
}
import gleam/list
import gleam/string
import pipeline

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
  browser.fetch_text(atproto.profile_url(), fn(text) {
    case atproto.decode_profile(text) {
      Ok(profile) -> commit(pipeline.plan_profile(profile))
      Error(reason) ->
        browser.log_error("decode_profile failed: " <> string.inspect(reason))
    }
  })
}

fn fetch_pinned_dids_and_repos() -> Nil {
  browser.fetch_text(atproto.pinned_dids_url(), fn(pinned_text) {
    case atproto.decode_actor_profiles(pinned_text) {
      Ok(profiles) -> {
        let pinned_dids = atproto.pinned_dids_from_profiles(profiles)
        browser.fetch_text(atproto.repos_url(), fn(repos_text) {
          case atproto.decode_repos(repos_text) {
            Ok(records) -> {
              let repos =
                records
                |> atproto.filter_repos_by_did(pinned_dids)
                |> list.map(atproto.resolve_repo_name)
                |> list.map(fn(record) { record.value })
              commit(pipeline.plan_repos(repos))
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

fn refresh_plays() -> Nil {
  commit(pipeline.mark_plays_stale())
  browser.fetch_text(atproto.plays_url(), on_plays)
}

fn on_plays(text: String) -> Nil {
  case atproto.decode_plays(text) {
    Ok(plays) -> commit(pipeline.plan_plays(plays))
    Error(reason) -> {
      browser.log_error("decode_plays failed: " <> string.inspect(reason))
      // Keep the previous rows, just stop showing the stale pulse.
      commit(pipeline.plan_plays([]))
    }
  }
}

fn commit(commands: List(Command)) -> Nil {
  list.each(commands, interpret)
}

fn interpret(command: Command) -> Nil {
  case command {
    ReplaceHtml(id, html) -> browser.set_inner_html(id, html)
    SetAttr(id, name, value) -> browser.set_attribute(id, name, value)
    RemoveAttr(id, name) -> browser.remove_attribute(id, name)
    LocalizeDates -> browser.localize_dates()
    RewriteRemoteImages -> browser.rewrite_remote_images()
  }
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
