import atproto
import data/sources
import gleam/list
import gleam/string
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

fn pinned_profile_body(dids: List(String)) -> String {
  let pins =
    dids
    |> list.map(fn(did) { "\"" <> did <> "\"" })
    |> string.join(with: ",")
  "{\"uri\": \"at://did:plc:test/org.tangled.actor.profile/self\",
    \"cid\": \"bafy1\",
    \"value\": {\"pinnedRepositories\": [" <> pins <> "]}}"
}

fn repo_items_body() -> String {
  "{\"items\":[
    {\"cid\": \"bafy1\",
     \"uri\": \"at://did:plc:one/org.tangled.repo.manifest/self\",
     \"value\": {
       \"declaration\": {\"owner\": \"did:plc:test\", \"name\": \"one\"},
       \"createdAt\": \"2026-01-01T00:00:00Z\"
     }},
    {\"cid\": \"bafy2\",
     \"uri\": \"at://did:plc:two/org.tangled.repo.manifest/self\",
     \"value\": {
       \"declaration\": {\"owner\": \"did:plc:test\", \"name\": \"two\"},
       \"createdAt\": \"2026-02-01T00:00:00Z\"
     }}
  ]}"
}

fn empty_records_body() -> String {
  "{\"records\":[]}"
}

/// A stub http_get that returns canned bodies per endpoint.
fn good_stub(url: String) -> Result(String, String) {
  let profile = atproto.profile_url()
  let plays = atproto.plays_url()
  let pinned = atproto.pinned_dids_url()
  let repos = atproto.repos_url(["did:plc:one", "did:plc:two"])
  case url {
    u if u == profile -> Ok(profile_body())
    u if u == plays -> Ok(plays_body())
    u if u == pinned -> Ok(pinned_profile_body(["did:plc:one", "did:plc:two"]))
    u if u == repos -> Ok(repo_items_body())
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
  data.repos |> list.length |> should.equal(2)
  data.repos
  |> list.map(fn(record) { record.value.declaration.name })
  |> should.equal(["one", "two"])
}

pub fn fetch_all_falls_back_on_section_failure_test() {
  let assert Ok(data) = sources.fetch_all(failing_stub)
  data.profile.handle |> should.equal("test.bsky.social")
  data.recent_plays |> should.equal([])
  data.repos |> should.equal([])
}

pub fn fetch_all_ignores_legacy_pin_uris_test() {
  let pinned = atproto.pinned_dids_url()
  let repos = atproto.repos_url(["did:plc:one"])
  let stub = fn(url: String) {
    let profile = atproto.profile_url()
    let plays = atproto.plays_url()
    case url {
      u if u == profile -> Ok(profile_body())
      u if u == plays -> Ok(empty_records_body())
      u if u == pinned ->
        Ok(
          pinned_profile_body([
            "did:plc:one",
            "at://did:plc:test/sh.tangled.repo/legacy",
          ]),
        )
      u if u == repos -> Ok(repo_items_body())
      _ -> panic as { "unexpected url: " <> url }
    }
  }
  let assert Ok(data) = sources.fetch_all(stub)
  // The appview is asked for one DID; the second record in the canned
  // body is filtered out, so the pinned-only rule holds even if the
  // response includes more than requested.
  data.repos
  |> list.map(fn(record) { record.value.declaration.name })
  |> should.equal(["one"])
}

pub fn fetch_all_without_pins_has_no_repos_test() {
  let pinned = atproto.pinned_dids_url()
  let stub = fn(url: String) {
    let profile = atproto.profile_url()
    let plays = atproto.plays_url()
    case url {
      u if u == profile -> Ok(profile_body())
      u if u == plays -> Ok(empty_records_body())
      u if u == pinned -> Ok(pinned_profile_body([]))
      // No pins must skip the appview call, not call it with an empty
      // query and degrade to an empty result.
      _ -> panic as { "unexpected url: " <> url }
    }
  }
  let assert Ok(data) = sources.fetch_all(stub)
  data.repos |> should.equal([])
}

pub fn plays_from_body_decodes_records_test() {
  sources.plays_from_body(plays_body()) |> list.length |> should.equal(1)
}

pub fn plays_from_body_empty_on_bad_json_test() {
  sources.plays_from_body("not json") |> should.equal([])
}

pub fn plays_from_body_empty_on_empty_records_test() {
  sources.plays_from_body("{\"records\":[]}") |> should.equal([])
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
