import atproto.{type DecodedRecord, DecodedRecord}
import gen/actor/profile.{type ActorProfile, ActorProfile}
import gen/repo/manifest.{type RepoManifest, Declaration, RepoManifest}
import gleam/option.{None, Some}
import gleeunit/should
import tangled

fn record(uri uri: String) -> DecodedRecord(RepoManifest) {
  DecodedRecord(
    uri: uri,
    cid: "bafy",
    value: RepoManifest(
      created_at: "2026-01-01T00:00:00Z",
      declaration: Declaration(name: "repo", owner: "did:plc:owner"),
      description: None,
      topics: None,
      website: None,
    ),
  )
}

fn profile_with_pins(dids: List(String)) -> ActorProfile {
  ActorProfile(pinned_repositories: Some(dids))
}

// --- repo_did_from_uri ---

pub fn repo_did_from_uri_extracts_authority_test() {
  tangled.repo_did_from_uri("at://did:plc:repo/org.tangled.repo.manifest/self")
  |> should.equal(Ok("did:plc:repo"))
}

pub fn repo_did_from_uri_handles_handle_authority_test() {
  tangled.repo_did_from_uri("at://karitham.dev/org.tangled.repo.manifest/self")
  |> should.equal(Ok("karitham.dev"))
}

pub fn repo_did_from_uri_rejects_malformed_uri_test() {
  tangled.repo_did_from_uri("not an at-uri") |> should.be_error()
}

// --- filter_repos_by_did ---

pub fn filter_repos_by_did_keeps_matching_test() {
  let keep = record("at://did:plc:keep/org.tangled.repo.manifest/self")
  let drop = record("at://did:plc:drop/org.tangled.repo.manifest/self")
  tangled.filter_repos_by_did([keep, drop], ["did:plc:keep"])
  |> should.equal([keep])
}

pub fn filter_repos_by_did_drops_all_when_none_match_test() {
  let rec = record("at://did:plc:nope/org.tangled.repo.manifest/self")
  tangled.filter_repos_by_did([rec], ["did:plc:other"])
  |> should.equal([])
}

pub fn filter_repos_by_did_drops_malformed_uri_test() {
  tangled.filter_repos_by_did([record("bad")], ["did:plc:other"])
  |> should.equal([])
}

// --- pinned_dids_from_profile ---

pub fn pinned_dids_from_profile_extracts_dids_test() {
  tangled.pinned_dids_from_profile(
    profile_with_pins(["did:plc:one", "did:plc:two"]),
  )
  |> should.equal(["did:plc:one", "did:plc:two"])
}

pub fn pinned_dids_from_profile_drops_legacy_at_uris_test() {
  tangled.pinned_dids_from_profile(
    profile_with_pins([
      "did:plc:keep",
      "at://did:plc:owner/sh.tangled.repo/legacy",
      "",
    ]),
  )
  |> should.equal(["did:plc:keep"])
}

pub fn pinned_dids_from_profile_dedupes_test() {
  tangled.pinned_dids_from_profile(
    profile_with_pins(["did:plc:one", "did:plc:one", "did:plc:two"]),
  )
  |> should.equal(["did:plc:one", "did:plc:two"])
}

pub fn pinned_dids_from_profile_handles_none_test() {
  tangled.pinned_dids_from_profile(ActorProfile(pinned_repositories: None))
  |> should.equal([])
}
