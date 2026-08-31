//// Build→run-time agreement for the dynamic sections.
////
//// The SSG renders everything with build-time data and embeds the
//// same data as JSON (`#site-model`); the client decodes it as the
//// islands' initial state so their first render matches the server
//// markup, then re-fetches fresh data. `localize_profile` points a
//// freshly fetched profile's images at their build-time mirrors.

import atproto.{type DecodedRecord}
import gen/actor/defs.{type ProfileViewDetailed, ProfileViewDetailed}
import gen/feed/play.{type FeedPlay}
import gen/repo.{type Repo}
import gleam/dict.{type Dict}
import gleam/option

/// The hydration payload: build-time data for the dynamic sections,
/// plus the remote→local image mirror map. Embedded by the SSG in
/// `#site-model`, decoded by the client as island flags.
pub type HydrationModel {
  HydrationModel(
    profile: ProfileViewDetailed,
    plays: List(FeedPlay),
    repos: List(DecodedRecord(Repo)),
    rewrites: Dict(String, String),
  )
}

/// Point a freshly-fetched profile's avatar/banner at their local
/// mirrors. `rewrites` is the remote→local map the SSG embeds at
/// build time; a URL missing from the map (e.g. the image changed
/// after the last build) keeps its remote URL and loads from the
/// origin host — same fallback as a failed mirror download.
pub fn localize_profile(
  profile: ProfileViewDetailed,
  rewrites: Dict(String, String),
) -> ProfileViewDetailed {
  ProfileViewDetailed(
    ..profile,
    avatar: option.map(profile.avatar, localize_url(_, rewrites)),
    banner: option.map(profile.banner, localize_url(_, rewrites)),
  )
}

fn localize_url(url: String, rewrites: Dict(String, String)) -> String {
  case dict.get(rewrites, url) {
    Ok(local) -> local
    Error(_) -> url
  }
}
