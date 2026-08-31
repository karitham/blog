import atproto.{type DecodedRecord, DecodedRecord}
import gen/actor/profile.{type ActorProfile, ActorProfile}
import gen/repo.{type Repo, Repo}
import gleam/option.{type Option, None, Some}
import gleeunit/should
import tangled

fn record(
  uri uri: String,
  did did: String,
  name name: Option(String),
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

fn named(
  uri uri: String,
  did did: String,
  name name: String,
) -> DecodedRecord(Repo) {
  record(uri: uri, did: did, name: Some(name))
}

fn profile_with_pins(dids: List(String)) -> DecodedRecord(ActorProfile) {
  DecodedRecord(
    uri: "at://did:plc:self/sh.tangled.actor.profile/self",
    cid: "bafy",
    value: ActorProfile(pinned_repositories: Some(dids)),
  )
}

// --- resolve_repo_name ---

pub fn resolve_repo_name_keeps_existing_name_test() {
  let rec =
    named(
      uri: "at://did:plc:abc/sh.tangled.repo/whatever",
      did: "did:plc:abc",
      name: "real-name",
    )
  let resolved = tangled.resolve_repo_name(rec)
  resolved.value.name |> should.equal(Some("real-name"))
}

pub fn resolve_repo_name_fills_missing_name_from_rkey_test() {
  let rec =
    record(
      uri: "at://did:plc:abc/sh.tangled.repo/my-cool-repo",
      did: "did:plc:abc",
      name: None,
    )
  let resolved = tangled.resolve_repo_name(rec)
  resolved.value.name |> should.equal(Some("my-cool-repo"))
}

pub fn resolve_repo_name_fills_empty_name_from_rkey_test() {
  let rec =
    record(
      uri: "at://did:plc:abc/sh.tangled.repo/auto-slug",
      did: "did:plc:abc",
      name: Some(""),
    )
  let resolved = tangled.resolve_repo_name(rec)
  resolved.value.name |> should.equal(Some("auto-slug"))
}

// --- filter_repos_by_did ---

pub fn filter_repos_by_did_keeps_matching_test() {
  let keep = named(uri: "at://x/y/a", did: "did:plc:keep", name: "a")
  let drop = named(uri: "at://x/y/b", did: "did:plc:drop", name: "b")
  tangled.filter_repos_by_did([keep, drop], ["did:plc:keep"])
  |> should.equal([keep])
}

pub fn filter_repos_by_did_drops_all_when_none_match_test() {
  let rec = named(uri: "at://x/y/a", did: "did:plc:nope", name: "a")
  tangled.filter_repos_by_did([rec], ["did:plc:other"])
  |> should.equal([])
}

// --- pinned_dids_from_profiles ---

pub fn pinned_dids_from_profiles_extracts_test() {
  tangled.pinned_dids_from_profiles([
    profile_with_pins(["did:plc:one", "did:plc:two"]),
  ])
  |> should.equal(["did:plc:one", "did:plc:two"])
}

pub fn pinned_dids_from_profiles_drops_empty_rkeys_test() {
  // Tangled pads the list with empty rkeys as placeholders.
  tangled.pinned_dids_from_profiles([
    profile_with_pins(["did:plc:keep", "", "", "", "", ""]),
  ])
  |> should.equal(["did:plc:keep"])
}

pub fn pinned_dids_from_profiles_flattens_multiple_test() {
  tangled.pinned_dids_from_profiles([
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
  tangled.pinned_dids_from_profiles([none_profile])
  |> should.equal([])
}
