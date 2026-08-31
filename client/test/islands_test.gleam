//// Tests for the islands' pure update/view logic. Effects are
//// data here: fetch effects are exercised via the messages their
//// callbacks would dispatch.

import gen/actor/defs.{type ProfileViewDetailed, ProfileViewDetailed}
import gen/feed/play.{type FeedPlay, ArtistView, FeedPlay}
import gen/repo.{type Repo, Repo}
import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element.{to_string}
import plays_island
import profile_island
import repos_island

fn sample_profile() -> ProfileViewDetailed {
  ProfileViewDetailed(
    did: "did:plc:test",
    handle: "test.bsky.social",
    display_name: Some("Test User"),
    description: Some("round-trip"),
    avatar: Some("https://cdn.bsky.app/avatar.jpeg"),
    banner: None,
    followers_count: None,
    follows_count: None,
    posts_count: None,
    pronouns: None,
  )
}

fn sample_play() -> FeedPlay {
  FeedPlay(
    track_name: "Track A",
    artists: [ArtistView(artist_name: "Artist 1", artist_mb_id: Some(""))],
    release_name: Some("Album A"),
    duration: Some(180),
    played_time: "2026-07-18T10:00:00Z",
    origin_uri: Some("https://example.com/a"),
  )
}

fn sample_repo() -> Repo {
  Repo(
    name: Some("repo-one"),
    description: Some("first"),
    repo_did: "did:plc:one",
    created_at: "2026-01-01T00:00:00Z",
    topics: Some(["gleam"]),
    website: None,
  )
}

// --- profile island ---

pub fn profile_init_takes_flags_test() {
  let flags =
    profile_island.Flags(rewrites: dict.new(), profile: sample_profile())
  let #(model, _) = profile_island.init(flags)
  model.profile |> should.equal(sample_profile())
}

pub fn profile_fetch_localizes_images_test() {
  let rewrites =
    dict.from_list([
      #("https://cdn.bsky.app/avatar.jpeg", "/img/profile/avatar.jpeg"),
    ])
  let model =
    profile_island.Model(rewrites: rewrites, profile: sample_profile())
  let fresh =
    ProfileViewDetailed(
      ..sample_profile(),
      avatar: Some("https://cdn.bsky.app/avatar.jpeg"),
    )
  let #(model, _) =
    profile_island.update(model, profile_island.ProfileFetched(Ok(fresh)))
  model.profile.avatar
  |> should.equal(Some("/img/profile/avatar.jpeg"))
}

pub fn profile_fetch_error_keeps_model_test() {
  let model =
    profile_island.Model(rewrites: dict.new(), profile: sample_profile())
  let #(model, _) =
    profile_island.update(
      model,
      profile_island.ProfileFetched(Error(json_decode_error())),
    )
  model.profile |> should.equal(sample_profile())
}

// --- plays island ---

pub fn plays_init_starts_stale_with_build_rows_test() {
  let #(model, _) = plays_island.init(plays_island.Flags(plays: []))
  model.stale |> should.be_true()
  model.plays |> should.equal([])
}

pub fn plays_poll_tick_flags_stale_test() {
  let model = plays_island.Model(plays: [sample_play()], stale: False)
  let #(model, _) = plays_island.update(model, plays_island.PollTick)
  model.stale |> should.be_true()
  // Rows are kept until the fetch lands, so nothing flashes.
  model.plays |> should.equal([sample_play()])
}

pub fn plays_fetch_replaces_rows_and_clears_stale_test() {
  let model = plays_island.Model(plays: [], stale: True)
  let #(model, _) =
    plays_island.update(model, plays_island.PlaysFetched(Ok([sample_play()])))
  model.plays |> should.equal([sample_play()])
  model.stale |> should.be_false()
}

pub fn plays_empty_fetch_keeps_rows_clears_stale_test() {
  let model = plays_island.Model(plays: [sample_play()], stale: True)
  let #(model, _) =
    plays_island.update(model, plays_island.PlaysFetched(Ok([])))
  model.plays |> should.equal([sample_play()])
  model.stale |> should.be_false()
}

pub fn plays_error_keeps_rows_clears_stale_test() {
  let model = plays_island.Model(plays: [sample_play()], stale: True)
  let #(model, _) =
    plays_island.update(
      model,
      plays_island.PlaysFetched(Error(json_decode_error())),
    )
  model.plays |> should.equal([sample_play()])
  model.stale |> should.be_false()
}

pub fn plays_visibility_triggers_refresh_test() {
  let model = plays_island.Model(plays: [sample_play()], stale: False)
  let #(model, _) =
    plays_island.update(model, plays_island.VisibilityChanged(True))
  model.stale |> should.be_true()
  // Hiding the tab changes nothing; the pulse clears when the fetch lands.
  let #(model, _) =
    plays_island.update(model, plays_island.VisibilityChanged(False))
  model.stale |> should.be_true()
}

pub fn plays_view_renders_rows_and_stale_flag_test() {
  let stale_view =
    plays_island.view(plays_island.Model(plays: [sample_play()], stale: True))
  let html = to_string(stale_view)
  string.contains(html, "Track A") |> should.be_true()
  string.contains(html, "data-stale") |> should.be_true()

  let fresh_view =
    plays_island.view(plays_island.Model(plays: [sample_play()], stale: False))
  to_string(fresh_view)
  |> string.contains("data-stale")
  |> should.be_false()
}

// --- repos island ---

pub fn repos_init_takes_flags_test() {
  let #(model, _) = repos_island.init(repos_island.Flags(repos: []))
  model.repos |> should.equal([])
}

pub fn repos_fetch_replaces_test() {
  let model = repos_island.Model(repos: [])
  let #(model, _) =
    repos_island.update(model, repos_island.ReposFetched([sample_repo()]))
  model.repos |> should.equal([sample_repo()])
}

pub fn repos_view_renders_top_items_test() {
  let html =
    repos_island.view(repos_island.Model(repos: [sample_repo()]))
    |> to_string
  string.contains(html, "repo-one") |> should.be_true()
}

// invalid JSON → parse fails before any decoder runs, so this can't panic
fn json_decode_error() -> json.DecodeError {
  let assert Error(e) = json.parse("oops", decode.string)
  e
}
