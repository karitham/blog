//// Tangled domain semantics: rules about Tangled records that the
//// generic AT Protocol layer (`atproto.gleam`) shouldn't know.
////
//// atproto knows how to fetch and decode records; this module knows
//// what Tangled *means* by them — a repo's DID is its record URI
//// authority, only pinned repos are shown, and legacy AT-URI pins are
//// ignored.

import atproto.{type DecodedRecord}
import gen/actor/profile.{type ActorProfile}
import gen/repo/manifest.{type RepoManifest}
import gleam/list
import gleam/option
import gleam/string

/// The repo DID carried by a manifest record URI:
/// `at://did:plc:abc/org.tangled.repo.manifest/self` -> `did:plc:abc`.
pub fn repo_did_from_uri(uri: String) -> Result(String, Nil) {
  case string.split(uri, on: "/") {
    ["at:", "", did, ..] -> Ok(did)
    _ -> Error(Nil)
  }
}

/// Drop repo records whose URI authority isn't in the pinned list.
/// The appview is asked for exactly the pinned DIDs; this keeps the
/// pinned-only invariant if it returns anything else.
pub fn filter_repos_by_did(
  records: List(DecodedRecord(RepoManifest)),
  pinned_dids: List(String),
) -> List(DecodedRecord(RepoManifest)) {
  list.filter(records, fn(record) {
    case repo_did_from_uri(record.uri) {
      Ok(did) -> list.contains(pinned_dids, did)
      Error(_) -> False
    }
  })
}

/// Extract the pinned repo DIDs from the owner's profile record.
/// Values are repo DIDs in v1; legacy AT-URI pins and empty
/// placeholders are dropped, and duplicates collapse before the
/// appview URL is built.
pub fn pinned_dids_from_profile(profile: ActorProfile) -> List(String) {
  profile.pinned_repositories
  |> option.unwrap(or: [])
  |> list.filter(fn(value) { string.starts_with(value, "did:") })
  |> list.unique
}
