import commit
import gen/actor/defs.{type ProfileViewDetailed, ProfileViewDetailed}
import gen/feed/play.{type FeedPlay, FeedPlay, ArtistView}
import gen/repo.{type Repo, Repo}
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import pipeline

fn sample_profile() -> ProfileViewDetailed {
  ProfileViewDetailed(
    did: "did:plc:test",
    handle: "test.bsky.social",
    display_name: Some("Test User"),
    description: Some("round-trip"),
    avatar: Some("https://example.com/avatar.jpg"),
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

fn sample_repos() -> List(Repo) {
  [
    Repo(
      name: Some("repo-one"),
      description: Some("first"),
      repo_did: "did:plc:one",
      created_at: "2026-01-01T00:00:00Z",
      topics: Some(["gleam"]),
      website: None,
    ),
  ]
}

pub fn plan_profile_replaces_section_and_rewrites_images_test() {
  let assert [commit.ReplaceHtml(id, html), commit.RewriteRemoteImages] =
    pipeline.plan_profile(sample_profile())
  id |> should.equal("profile-section")
  string.contains(html, "Test User") |> should.be_true()
}

pub fn plan_repos_replaces_section_test() {
  let assert [commit.ReplaceHtml(id, html)] =
    pipeline.plan_repos(sample_repos())
  id |> should.equal("repos")
  string.contains(html, "repo-one") |> should.be_true()
}

pub fn plan_plays_renders_rows_then_localizes_and_clears_stale_test() {
  let assert [
    commit.ReplaceHtml(id, html),
    commit.LocalizeDates,
    commit.RemoveAttr(rid, name),
  ] = pipeline.plan_plays([sample_play()])
  id |> should.equal("plays-rows")
  string.contains(html, "Track A") |> should.be_true()
  rid |> should.equal("plays")
  name |> should.equal("data-stale")
}

pub fn plan_plays_empty_clears_stale_without_rendering_test() {
  pipeline.plan_plays([])
  |> should.equal([commit.RemoveAttr("plays", "data-stale")])
}

pub fn mark_plays_stale_sets_the_flag_test() {
  pipeline.mark_plays_stale()
  |> should.equal([commit.SetAttr("plays", "data-stale", "true")])
}
