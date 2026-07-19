import decode
import encode
import gen/actor/defs.{type ProfileViewDetailed, ProfileViewDetailed}
import gen/alpha/feed/play.{type AlphaFeedPlay, AlphaFeedPlay, ArtistView}
import gen/repo.{type Repo, Repo}
import gleam/option.{None, Some}
import gleeunit/should
import hydration.{HydrationModel}

fn sample_profile() -> ProfileViewDetailed {
  ProfileViewDetailed(
    did: "did:plc:test",
    handle: "test.bsky.social",
    display_name: Some("Test User"),
    description: Some("round-trip"),
    avatar: Some("https://example.com/avatar.jpg"),
    banner: Some("https://example.com/banner.jpg"),
    followers_count: Some(100),
    follows_count: Some(50),
    posts_count: Some(25),
    pronouns: Some("they/them"),
  )
}

fn sample_plays() -> List(AlphaFeedPlay) {
  [
    AlphaFeedPlay(
      track_name: "Track A",
      artists: [
        ArtistView(artist_name: "Artist 1", artist_mb_id: Some("mbid-1")),
        ArtistView(artist_name: "Artist 2", artist_mb_id: Some("")),
      ],
      release_name: Some("Album A"),
      duration: Some(180),
      played_time: "2026-07-18T10:00:00Z",
      origin_url: Some("https://example.com/a"),
    ),
    AlphaFeedPlay(
      track_name: "Track B",
      artists: [
        ArtistView(artist_name: "Solo", artist_mb_id: Some("mbid-solo")),
      ],
      release_name: None,
      duration: None,
      played_time: "2026-07-18T11:00:00Z",
      origin_url: None,
    ),
  ]
}

fn sample_repos() -> List(Repo) {
  [
    Repo(
      name: "repo-one",
      description: Some("first"),
      repo_did: "did:plc:one",
      created_at: "2026-01-01T00:00:00Z",
      topics: Some(["gleam", "atproto"]),
    ),
    Repo(
      name: "repo-two",
      description: Some(""),
      repo_did: "did:plc:two",
      created_at: "2026-02-01T00:00:00Z",
      topics: Some([]),
    ),
  ]
}

pub fn round_trip_full_model_test() {
  let original =
    HydrationModel(
      profile: sample_profile(),
      plays: sample_plays(),
      repos: sample_repos(),
    )

  let json = encode.encode_hydration_model(original)
  let result = decode.decode_hydration_model(json)
  let assert Ok(decoded) = result
  decoded.profile |> should.equal(original.profile)
  decoded.plays |> should.equal(original.plays)
  decoded.repos |> should.equal(original.repos)
}

pub fn round_trip_empty_lists_test() {
  let original = HydrationModel(profile: sample_profile(), plays: [], repos: [])
  let json = encode.encode_hydration_model(original)
  let assert Ok(decoded) = decode.decode_hydration_model(json)
  decoded.plays |> should.equal([])
  decoded.repos |> should.equal([])
}

pub fn round_trip_zero_counts_test() {
  let profile =
    ProfileViewDetailed(
      did: "did:plc:zero",
      handle: "zero.test",
      display_name: Some(""),
      description: Some(""),
      avatar: Some(""),
      banner: Some(""),
      followers_count: Some(0),
      follows_count: Some(0),
      posts_count: Some(0),
      pronouns: None,
    )
  let original = HydrationModel(profile: profile, plays: [], repos: [])
  let json = encode.encode_hydration_model(original)
  let assert Ok(decoded) = decode.decode_hydration_model(json)
  decoded.profile |> should.equal(profile)
}
