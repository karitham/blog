import atproto.{type DecodedRecord, DecodedRecord}
import gen/actor/profile.{type ActorProfile, ActorProfile}
import gen/repo.{type Repo, Repo}
import gleam/option.{type Option, None, Some}
import gleeunit/should

fn record(
  uri: String,
  did: String,
  name: Option(String),
) -> DecodedRecord(Repo) {
  DecodedRecord(
    uri: uri,
    cid: "bafy",
    value: Repo(
      name: name,
      description: Some(""),
      repo_did: did,
      created_at: "2026-01-01T00:00:00Z",
      topics: Some([]),
      website: None,
    ),
  )
}

fn named(uri: String, did: String, name: String) -> DecodedRecord(Repo) {
  record(uri, did, Some(name))
}

fn profile_with_pins(dids: List(String)) -> DecodedRecord(ActorProfile) {
  DecodedRecord(
    uri: "at://did:plc:self/sh.tangled.actor.profile/self",
    cid: "bafy",
    value: ActorProfile(pinned_repositories: Some(dids)),
  )
}

// --- rkey_from_uri ---

pub fn rkey_from_uri_extracts_rkey_test() {
  atproto.rkey_from_uri("at://did:plc:abc/sh.tangled.repo/blog")
  |> should.equal(Ok("blog"))
}

pub fn rkey_from_uri_handles_handle_authority_test() {
  atproto.rkey_from_uri("at://karitham.dev/sh.tangled.repo/karitham_blog")
  |> should.equal(Ok("karitham_blog"))
}

// --- resolve_repo_name ---

pub fn resolve_repo_name_keeps_existing_name_test() {
  let rec =
    named(
      "at://did:plc:abc/sh.tangled.repo/whatever",
      "did:plc:abc",
      "real-name",
    )
  let resolved = atproto.resolve_repo_name(rec)
  resolved.value.name |> should.equal(Some("real-name"))
}

pub fn resolve_repo_name_fills_missing_name_from_rkey_test() {
  let rec =
    record("at://did:plc:abc/sh.tangled.repo/my-cool-repo", "did:plc:abc", None)
  let resolved = atproto.resolve_repo_name(rec)
  resolved.value.name |> should.equal(Some("my-cool-repo"))
}

pub fn resolve_repo_name_fills_empty_name_from_rkey_test() {
  let rec =
    record(
      "at://did:plc:abc/sh.tangled.repo/auto-slug",
      "did:plc:abc",
      Some(""),
    )
  let resolved = atproto.resolve_repo_name(rec)
  resolved.value.name |> should.equal(Some("auto-slug"))
}

// --- filter_repos_by_did ---

pub fn filter_repos_by_did_keeps_matching_test() {
  let keep = named("at://x/y/a", "did:plc:keep", "a")
  let drop = named("at://x/y/b", "did:plc:drop", "b")
  atproto.filter_repos_by_did([keep, drop], ["did:plc:keep"])
  |> should.equal([keep])
}

pub fn filter_repos_by_did_drops_all_when_none_match_test() {
  let rec = named("at://x/y/a", "did:plc:nope", "a")
  atproto.filter_repos_by_did([rec], ["did:plc:other"])
  |> should.equal([])
}

// --- pinned_dids_from_profiles ---

pub fn pinned_dids_from_profiles_extracts_test() {
  atproto.pinned_dids_from_profiles([
    profile_with_pins(["did:plc:one", "did:plc:two"]),
  ])
  |> should.equal(["did:plc:one", "did:plc:two"])
}

pub fn pinned_dids_from_profiles_drops_empty_rkeys_test() {
  // Tangled pads the list with empty rkeys as placeholders.
  atproto.pinned_dids_from_profiles([
    profile_with_pins(["did:plc:keep", "", "", "", "", ""]),
  ])
  |> should.equal(["did:plc:keep"])
}

pub fn pinned_dids_from_profiles_flattens_multiple_test() {
  atproto.pinned_dids_from_profiles([
    profile_with_pins(["did:plc:one"]),
    profile_with_pins(["did:plc:two", "did:plc:three"]),
  ])
  |> should.equal(["did:plc:one", "did:plc:two", "did:plc:three"])
}

pub fn pinned_dids_from_profiles_handles_none_test() {
  let none_profile =
    DecodedRecord(
      uri: "at://x/y/z",
      cid: "bafy",
      value: ActorProfile(pinned_repositories: None),
    )
  atproto.pinned_dids_from_profiles([none_profile])
  |> should.equal([])
}

// --- decode_repos ---

pub fn decode_repos_preserves_uri_test() {
  let body =
    "{\"records\":[{
      \"cid\": \"bafy1\",
      \"uri\": \"at://did:plc:abc/sh.tangled.repo/blog\",
      \"value\": {
        \"name\": \"\",
        \"repoDid\": \"did:plc:abc\",
        \"createdAt\": \"2026-01-15T10:00:00Z\"
      }
    }]}"
  let assert Ok(records) = atproto.decode_repos(body)
  let assert [rec] = records
  rec.uri |> should.equal("at://did:plc:abc/sh.tangled.repo/blog")
  rec.value.repo_did |> should.equal("did:plc:abc")
}

pub fn decode_repos_drops_records_with_invalid_value_test() {
  let body =
    "{\"records\":[
      {\"cid\": \"bafy1\", \"uri\": \"at://x/y/a\", \"value\": {
        \"name\": \"good\", \"repoDid\": \"did:plc:a\", \"createdAt\": \"2026-01-01T00:00:00Z\"
      }},
      {\"cid\": \"bafy2\", \"uri\": \"at://x/y/b\", \"value\": \"not an object\"}
    ]}"
  let assert Ok(records) = atproto.decode_repos(body)
  let assert [kept] = records
  kept.uri |> should.equal("at://x/y/a")
  kept.value.name |> should.equal(Some("good"))
}
