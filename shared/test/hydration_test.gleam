//// Tests for build→run-time agreement helpers: profile image
//// localization so the client's fresh render matches the mirrored
//// images the SSG embedded.

import gen/actor/defs.{type ProfileViewDetailed, ProfileViewDetailed}
import gleam/dict
import gleam/option.{None, Some}
import gleeunit/should
import hydration.{localize_profile}

fn sample_profile() -> ProfileViewDetailed {
  ProfileViewDetailed(
    did: "did:plc:test",
    handle: "test.bsky.social",
    display_name: Some("Test User"),
    description: Some("round-trip"),
    avatar: Some("https://cdn.bsky.app/avatar.jpeg"),
    banner: Some("https://cdn.bsky.app/banner.jpeg"),
    followers_count: None,
    follows_count: None,
    posts_count: None,
    pronouns: None,
  )
}

fn mirror_map() {
  dict.from_list([
    #("https://cdn.bsky.app/avatar.jpeg", "/img/profile/avatar.jpeg"),
    #("https://cdn.bsky.app/banner.jpeg", "/img/profile/banner.jpeg"),
  ])
}

pub fn localize_profile_maps_avatar_and_banner_test() {
  let localized = localize_profile(sample_profile(), mirror_map())
  localized.avatar
  |> should.equal(Some("/img/profile/avatar.jpeg"))
  localized.banner
  |> should.equal(Some("/img/profile/banner.jpeg"))
}

pub fn localize_profile_keeps_unmapped_urls_test() {
  // An image changed after the last build isn't in the map: keep the
  // remote URL so the browser falls back to the origin host.
  let localized = localize_profile(sample_profile(), dict.from_list([]))
  localized.avatar
  |> should.equal(Some("https://cdn.bsky.app/avatar.jpeg"))
}

pub fn localize_profile_leaves_other_fields_untouched_test() {
  let localized = localize_profile(sample_profile(), mirror_map())
  localized.handle |> should.equal("test.bsky.social")
  localized.did |> should.equal("did:plc:test")
}
