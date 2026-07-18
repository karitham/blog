import fetch
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should

// --- URL builders ---

pub fn profile_url_uses_public_api_test() {
  string.starts_with(fetch.profile_url(), "https://public.api.bsky.app")
  |> should.equal(True)
  string.contains(fetch.profile_url(), "karitham.dev")
  |> should.equal(True)
}

pub fn plays_url_includes_shared_limit_test() {
  let url = fetch.plays_url()
  string.contains(url, "fm.teal.alpha.feed.play") |> should.equal(True)
  string.contains(url, "limit=") |> should.equal(True)
  string.contains(url, "eurosky.social") |> should.equal(True)
}

pub fn pinned_dids_url_test() {
  let url = fetch.pinned_dids_url()
  string.contains(url, "sh.tangled.actor.profile") |> should.equal(True)
  string.contains(url, "eurosky.social") |> should.equal(True)
}

pub fn repos_url_test() {
  let url = fetch.repos_url()
  string.contains(url, "sh.tangled.repo") |> should.equal(True)
  string.contains(url, "eurosky.social") |> should.equal(True)
}

// --- Profile ---

pub fn decode_profile_test() {
  let json =
    "{
    \"did\": \"did:plc:test\",
    \"handle\": \"test.bsky.social\",
    \"displayName\": \"Test User\",
    \"description\": \"A test profile\",
    \"avatar\": \"https://example.com/avatar.jpg\",
    \"banner\": \"https://example.com/banner.jpg\",
    \"followersCount\": 100,
    \"followsCount\": 50,
    \"postsCount\": 25
  }"

  let result = fetch.decode_profile(json)
  let assert Ok(profile) = result
  profile.did |> should.equal("did:plc:test")
  profile.handle |> should.equal("test.bsky.social")
  profile.display_name |> should.equal(Some("Test User"))
  profile.description |> should.equal(Some("A test profile"))
  profile.avatar |> should.equal(Some("https://example.com/avatar.jpg"))
  profile.banner |> should.equal(Some("https://example.com/banner.jpg"))
  profile.followers_count |> should.equal(Some(100))
  profile.follows_count |> should.equal(Some(50))
  profile.posts_count |> should.equal(Some(25))
}

pub fn decode_profile_minimal_test() {
  let json =
    "{
    \"did\": \"did:plc:test\",
    \"handle\": \"test.bsky.social\",
    \"displayName\": \"\",
    \"description\": \"\",
    \"avatar\": \"\",
    \"banner\": \"\",
    \"followersCount\": 0,
    \"followsCount\": 0,
    \"postsCount\": 0
  }"

  let result = fetch.decode_profile(json)
  let assert Ok(profile) = result
  profile.did |> should.equal("did:plc:test")
  profile.handle |> should.equal("test.bsky.social")
  profile.display_name |> should.equal(Some(""))
}

// --- Plays ---

pub fn decode_plays_test() {
  let json =
    "{
    \"records\": [
      {
        \"cid\": \"bafy1\",
        \"uri\": \"at://did:plc:test/fm.teal.alpha.feed.play/1\",
        \"value\": {
          \"trackName\": \"Test Song\",
          \"artists\": [{ \"artistName\": \"Test Artist\", \"artistMbId\": \"mbid-1\" }],
          \"releaseName\": \"Test Album\",
          \"duration\": 180,
          \"playedTime\": \"2026-07-18T10:00:00Z\",
          \"originUrl\": \"https://example.com/track\"
        }
      }
    ]
  }"

  let result = fetch.decode_plays(json)
  let assert Ok(plays) = result
  list.length(plays) |> should.equal(1)

  let assert [play] = plays
  play.track_name |> should.equal("Test Song")
  list.length(play.artists) |> should.equal(1)
  play.release_name |> should.equal(Some("Test Album"))
  play.duration |> should.equal(Some(180))
  play.played_time |> should.equal("2026-07-18T10:00:00Z")
  play.origin_url |> should.equal(Some("https://example.com/track"))
}

pub fn decode_plays_minimal_test() {
  let json =
    "{
    \"records\": [
      {
        \"cid\": \"bafy2\",
        \"uri\": \"at://did:plc:test/fm.teal.alpha.feed.play/1\",
        \"value\": {
          \"trackName\": \"Minimal\",
          \"artists\": [{ \"artistName\": \"Solo\" }],
          \"playedTime\": \"2026-07-18T11:00:00Z\"
        }
      }
    ]
  }"

  let result = fetch.decode_plays(json)
  let assert Ok(plays) = result
  let assert [play] = plays
  play.track_name |> should.equal("Minimal")
  let assert [artist] = play.artists
  artist.artist_name |> should.equal("Solo")
  artist.artist_mb_id |> should.equal(option.None)
  play.release_name |> should.equal(option.None)
  play.origin_url |> should.equal(option.None)
  play.duration |> should.equal(option.None)
}

// --- Pinned DIDs ---

pub fn decode_pinned_dids_test() {
  let json =
    "{
    \"records\": [
      {
        \"cid\": \"bafy1\",
        \"uri\": \"at://did:plc:foo/sh.tangled.actor.profile/self\",
        \"value\": {
          \"$type\": \"sh.tangled.actor.profile\",
          \"pinnedRepositories\": [
            \"did:plc:4b3gxcvelmxan674wojtufdt\",
            \"\",
            \"\",
            \"\",
            \"\",
            \"\"
          ]
        }
      }
    ]
  }"

  let assert Ok(dids) = fetch.decode_pinned_dids(json)
  dids |> should.equal(["did:plc:4b3gxcvelmxan674wojtufdt"])
}

pub fn decode_pinned_dids_empty_test() {
  let json = "{\"records\":[]}"
  let assert Ok(dids) = fetch.decode_pinned_dids(json)
  dids |> should.equal([])
}

// --- Repos ---

pub fn decode_repos_test() {
  let json =
    "{
    \"records\": [
      {
        \"cid\": \"bafy1\",
        \"uri\": \"at://did:plc:test/sh.tangled.repo/abc\",
        \"value\": {
          \"name\": \"my-project\",
          \"description\": \"A test repo\",
          \"repoDid\": \"did:plc:repotest\",
          \"createdAt\": \"2026-01-15T10:00:00Z\",
          \"topics\": [\"gleam\", \"testing\"]
        }
      }
    ]
  }"

  let result = fetch.decode_repos(json)
  let assert Ok(repos) = result
  list.length(repos) |> should.equal(1)

  let assert [repo] = repos
  repo.name |> should.equal("my-project")
  repo.description |> should.equal(Some("A test repo"))
  repo.repo_did |> should.equal("did:plc:repotest")
  repo.created_at |> should.equal("2026-01-15T10:00:00Z")
  repo.topics |> should.equal(Some(["gleam", "testing"]))
}

pub fn decode_repos_no_topics_test() {
  let json =
    "{
    \"records\": [
      {
        \"cid\": \"bafy2\",
        \"uri\": \"at://did:plc:test/sh.tangled.repo/def\",
        \"value\": {
          \"name\": \"unnamed\",
          \"description\": \"\",
          \"repoDid\": \"did:plc:repotest2\",
          \"createdAt\": \"2026-02-20T00:00:00Z\"
        }
      }
    ]
  }"

  let result = fetch.decode_repos(json)
  let assert Ok(repos) = result
  list.length(repos) |> should.equal(1)

  let assert [repo] = repos
  repo.description |> should.equal(Some(""))
  repo.topics |> should.equal(option.None)
}
