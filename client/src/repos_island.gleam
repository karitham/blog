//// Repos island: owns the `#repos` mount point.
////
//// Starts from the build-time repos list, then re-fetches pinned
//// actor profiles + repo records from the Tangled repo on load and
//// on tab visibility. The two-step fetch (pinned DIDs gate the repo
//// filter) stays inside one effect; the section only re-renders on a
//// successful decode.

import atproto
import browser
import gen/repo.{type Repo}
import gleam/list
import gleam/string
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import repos as repos_view
import tangled

pub type Flags {
  Flags(repos: List(Repo))
}

pub type Model {
  Model(repos: List(Repo))
}

pub type Msg {
  ReposFetched(List(Repo))
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

/// Fetch pinned repo DIDs, then the repo records they select. Both
/// decoders log failures and leave the current render untouched —
/// same fallback as the SSG build keeping a section it couldn't
/// fetch.
fn fetch_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    browser.fetch_text(atproto.pinned_dids_url(), fn(pinned_text) {
      case atproto.decode_actor_profiles(pinned_text) {
        Error(reason) ->
          browser.log_error(
            "decode_actor_profiles failed: " <> string.inspect(reason),
          )
        Ok(profiles) -> {
          let pinned_dids = tangled.pinned_dids_from_profiles(profiles)
          browser.fetch_text(atproto.repos_url(), fn(repos_text) {
            case atproto.decode_repos(repos_text) {
              Error(reason) ->
                browser.log_error(
                  "decode_repos failed: " <> string.inspect(reason),
                )
              Ok(records) -> {
                let repos =
                  records
                  |> tangled.filter_repos_by_did(pinned_dids)
                  |> list.map(tangled.resolve_repo_name)
                  |> list.map(fn(record) { record.value })
                dispatch(ReposFetched(repos))
              }
            }
          })
        }
      }
    })
  })
}

fn visibility_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    browser.on_visibility_change(fn(visible) {
      dispatch(VisibilityChanged(visible))
    })
  })
}
