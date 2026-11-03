//// Repos island: owns the `#repos` mount point.
////
//// Starts from the build-time repos list, then re-fetches the Tangled
//// profile and repo manifests on load and on tab visibility. Pinned
//// DIDs gate the appview query, so the two-step fetch stays inside one
//// effect; the section only re-renders on a successful decode.

import atproto
import browser
import gen/repo/manifest.{type RepoManifest}
import gleam/int
import gleam/list
import gleam/string
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import repos as repos_view
import tangled

pub type Flags {
  Flags(repos: List(RepoManifest))
}

pub type Model {
  Model(repos: List(RepoManifest))
}

pub type Msg {
  ReposFetched(List(RepoManifest))
  VisibilityChanged(Bool)
}

pub fn start(flags: Flags) -> Nil {
  let res =
    lustre.application(init, update, view)
    |> lustre.start("#" <> repos_view.repos_section_id, flags)
  case res {
    Ok(_) -> Nil
    Error(e) ->
      browser.log_error("repos island failed to mount: " <> string.inspect(e))
  }
}

pub fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  #(
    Model(repos: flags.repos),
    effect.batch([fetch_effect(), visibility_effect()]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ReposFetched(repos) -> #(Model(repos), effect.none())
    VisibilityChanged(True) -> #(model, fetch_effect())
    VisibilityChanged(False) -> #(model, effect.none())
  }
}

pub fn view(model: Model) -> Element(Msg) {
  repos_view.repos_inner(model.repos)
}

/// Fetch the owner's pinned DIDs, then the manifest records they
/// select. Failures log and leave the current render untouched — same
/// fallback as the SSG keeping a section it couldn't fetch.
fn fetch_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    browser.fetch_text(atproto.pinned_dids_url(), fn(pinned_text) {
      case atproto.decode_actor_profile(pinned_text) {
        Error(reason) ->
          browser.log_error(
            "decode_actor_profile failed: " <> string.inspect(reason),
          )
        Ok(profile) ->
          fetch_repos(dispatch, tangled.pinned_dids_from_profile(profile))
      }
    })
  })
}

fn fetch_repos(dispatch: fn(Msg) -> Nil, pinned_dids: List(String)) -> Nil {
  case pinned_dids {
    // No pins means no appview call and an intentionally empty list;
    // a stale build-time render would otherwise show unpinned repos.
    [] -> dispatch(ReposFetched([]))
    _ ->
      browser.fetch_text(atproto.repos_url(pinned_dids), fn(repos_text) {
        case atproto.decode_repos(repos_text) {
          Error(reason) ->
            browser.log_error("decode_repos failed: " <> string.inspect(reason))
          Ok(#(records, drops)) -> {
            log_drops(drops)
            let repos =
              records
              |> tangled.filter_repos_by_did(pinned_dids)
              |> list.map(fn(record) { record.value })
            dispatch(ReposFetched(repos))
          }
        }
      })
  }
}

fn log_drops(drops: Int) -> Nil {
  case drops > 0 {
    True ->
      browser.log_error(
        "dropped "
        <> int.to_string(drops)
        <> " repo record(s) that failed to decode",
      )
    False -> Nil
  }
}

fn visibility_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    browser.on_visibility_change(fn(visible) {
      dispatch(VisibilityChanged(visible))
    })
  })
}
