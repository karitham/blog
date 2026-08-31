import atproto
import data/sources
import gleam/list
import gleeunit/should

fn profile_body() -> String {
  "{\"did\":\"did:plc:test\",\"handle\":\"test.bsky.social\"}"
}

fn plays_body() -> String {
  "{\"records\":[{
    \"cid\": \"bafy1\",
    \"uri\": \"at://did:plc:test/fm.teal.feed.play/abc\",
    \"value\": {
      \"artists\": [{\"artistName\": \"Artist A\"}],
      \"playedTime\": \"2026-07-18T10:00:00Z\",
      \"trackName\": \"Track A\"
    }
  }]}"
}

fn empty_records_body() -> String {
  "{\"records\":[]}"
}

/// A stub http_get that returns canned bodies per endpoint.
fn good_stub(url: String) -> Result(String, String) {
  let profile = atproto.profile_url()
  let plays = atproto.plays_url()
  let pinned = atproto.pinned_dids_url()
  let repos = atproto.repos_url()
  case url {
    u if u == profile -> Ok(profile_body())
    u if u == plays -> Ok(plays_body())
    u if u == pinned -> Ok(empty_records_body())
    u if u == repos -> Ok(empty_records_body())
    _ -> Error("unexpected url: " <> url)
  }
}

/// A stub where everything except the profile fails like a dead PDS.
fn failing_stub(url: String) -> Result(String, String) {
  let profile = atproto.profile_url()
  case url {
    u if u == profile -> Ok(profile_body())
    _ -> Error("network down")
  }
}

pub fn fetch_all_decodes_all_sections_test() {
  let assert Ok(data) = sources.fetch_all(good_stub)
  data.profile.handle |> should.equal("test.bsky.social")
  data.recent_plays |> list.length |> should.equal(1)
  data.repos |> should.equal([])
}

pub fn fetch_all_falls_back_on_section_failure_test() {
  let assert Ok(data) = sources.fetch_all(failing_stub)
  data.profile.handle |> should.equal("test.bsky.social")
  data.recent_plays |> should.equal([])
  data.repos |> should.equal([])
}

pub fn plays_from_body_decodes_records_test() {
  sources.plays_from_body(plays_body()) |> list.length |> should.equal(1)
}

pub fn plays_from_body_empty_on_bad_json_test() {
  sources.plays_from_body("not json") |> should.equal([])
}

pub fn plays_from_body_empty_on_empty_records_test() {
  sources.plays_from_body(empty_records_body()) |> should.equal([])
}

fn profile_failing_stub(url: String) -> Result(String, String) {
  let profile = atproto.profile_url()
  case url {
    u if u == profile -> Error("network down")
    _ -> Ok(empty_records_body())
  }
}

pub fn fetch_all_fails_on_profile_error_test() {
  sources.fetch_all(profile_failing_stub) |> should.be_error()
}
