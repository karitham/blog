//// Pure planning for the client's refresh pass.
////
//// Given freshly fetched, decoded data, produce the DOM commands to
//// apply. No browser calls, no IO — unit-testable under Node with
//// plain values. The impure half (fetch + interpret) lives in
//// `app.gleam`.

import commit.{
  type Command, LocalizeDates, RemoveAttr, ReplaceHtml, RewriteRemoteImages,
  SetAttr,
}
import dynamic
import gen/actor/defs.{type ProfileViewDetailed}
import gen/alpha/feed/play.{type AlphaFeedPlay}
import gen/repo.{type Repo}
import plays as plays_view
import profile as profile_view
import repos as repos_view

/// The fresh profile replaces the server-rendered section, then every
/// remote image in the document is pointed at its local mirror.
pub fn plan_profile(profile: ProfileViewDetailed) -> List(Command) {
  [
    ReplaceHtml(
      "profile-section",
      dynamic.render(profile_view.profile(profile)),
    ),
    RewriteRemoteImages,
  ]
}

pub fn plan_repos(repos: List(Repo)) -> List(Command) {
  [ReplaceHtml("repos", dynamic.render(repos_view.repos_section(repos)))]
}

/// One plays poll tick: render the fresh rows, re-localize their
/// times, and clear the stale flag. An empty result (or an error
/// handled by the caller) just clears the flag so the UI stays calm.
pub fn plan_plays(plays: List(AlphaFeedPlay)) -> List(Command) {
  case plays {
    [] -> [RemoveAttr("plays", "data-stale")]
    _ -> [
      ReplaceHtml("plays-rows", dynamic.render(plays_view.plays_rows(plays))),
      LocalizeDates,
      RemoveAttr("plays", "data-stale"),
    ]
  }
}

/// The start of a poll cycle: flag the section stale so the CSS shows
/// it refreshing, then fetch.
pub fn mark_plays_stale() -> List(Command) {
  [SetAttr("plays", "data-stale", "true")]
}
