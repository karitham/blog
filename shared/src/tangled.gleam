//// Tangled domain semantics: rules about Tangled records that the
//// generic AT Protocol layer (`atproto.gleam`) shouldn't know.
////
//// atproto knows how to fetch and decode records; this module knows
//// what Tangled *means* by them — repo names come from the URI rkey
//// when missing, pinned DIDs are padded with empty placeholders, and
//// only pinned repos are shown on the site.

import atproto.{type DecodedRecord, DecodedRecord}
import gen/actor/profile.{type ActorProfile}
import gen/repo.{type Repo, Repo}
import gleam/list
import gleam/option.{Some, unwrap}

/// Fill in a Tangled repo's `name` from the URI rkey when the
/// original is missing or empty. Records without a real name usually
/// hold an auto-generated hash; the rkey is the slug Tangled uses
/// for the URL. Returns the wrapper unchanged if the URI can't be
/// parsed, so the caller can still pass it to the view.
pub fn resolve_repo_name(record: DecodedRecord(Repo)) -> DecodedRecord(Repo) {
  let repo = record.value
  case repo.name {
    Some(name) if name != "" -> record
    _ ->
      case atproto.rkey_from_uri(record.uri) {
        Ok(rkey) ->
          DecodedRecord(..record, value: Repo(..repo, name: Some(rkey)))
        Error(_) -> record
      }
  }
}

/// Drop repo records whose `repo_did` isn't in the pinned list.
pub fn filter_repos_by_did(
  records: List(DecodedRecord(Repo)),
  pinned_dids: List(String),
) -> List(DecodedRecord(Repo)) {
  list.filter(records, fn(record) {
    list.contains(pinned_dids, record.value.repo_did)
  })
}

/// Extract non-empty pinned DIDs from one or more actor profile
/// records. Tangled pads the list with empty rkeys as placeholders;
/// those are dropped.
pub fn pinned_dids_from_profiles(
  records: List(DecodedRecord(ActorProfile)),
) -> List(String) {
  records
  |> list.flat_map(fn(record) {
    record.value.pinned_repositories
    |> unwrap(or: [])
    |> list.filter(fn(did) { did != "" })
  })
}
