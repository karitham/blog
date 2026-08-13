//// URL builders and response decoders for AT Protocol data.
////
//// URL builders use `uri.query_to_string`; response decoders accept
//// raw JSON from either the SSG's httpc transport or the browser's
//// `fetch_text`, so the same module serves both targets.
////
//// `DecodedRecord` preserves a listRecords record's URI alongside
//// its decoded value, so callers can derive info (e.g. a repo's
//// name from its URI rkey) that isn't in the record body.

import api
import gen/actor/defs.{type ProfileViewDetailed, profile_view_detailed_decoder}
import gen/actor/profile.{type ActorProfile, actor_profile_decoder}
import gen/feed/play.{type FeedPlay, feed_play_decoder}
import gen/repo.{type Repo, Repo, repo_decoder}
import gen/repo/list_records.{type Record, record_decoder}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/string
import gleam/uri

/// A listRecords record paired with its decoded value.
pub type DecodedRecord(a) {
  DecodedRecord(uri: String, cid: String, value: a)
}

pub fn profile_url() -> String {
  let params = [#("actor", "karitham.dev")]
  api.public_api
  <> "/xrpc/app.bsky.actor.getProfile?"
  <> uri.query_to_string(params)
}

/// `listRecords` URL for the current play collection. Teal's lexicons
/// dropped the `alpha` namespace; the live list only reads the current
/// one. Historical alpha plays still count toward stats (see
/// tools/parse-plays), but aren't shown live.
pub fn plays_url() -> String {
  let params = [
    #("repo", api.did),
    #("collection", "fm.teal.feed.play"),
    #("limit", int.to_string(api.plays_limit)),
  ]
  api.pds_endpoint
  <> "/xrpc/com.atproto.repo.listRecords?"
  <> uri.query_to_string(params)
}

pub fn pinned_dids_url() -> String {
  let params = [
    #("repo", api.did),
    #("collection", "sh.tangled.actor.profile"),
  ]
  api.pds_endpoint
  <> "/xrpc/com.atproto.repo.listRecords?"
  <> uri.query_to_string(params)
}

pub fn repos_url() -> String {
  let params = [
    #("repo", api.did),
    #("collection", "sh.tangled.repo"),
  ]
  api.pds_endpoint
  <> "/xrpc/com.atproto.repo.listRecords?"
  <> uri.query_to_string(params)
}

/// Decode a `getProfile` JSON body into a typed profile.
pub fn decode_profile(
  body: String,
) -> Result(ProfileViewDetailed, json.DecodeError) {
  json.parse(body, profile_view_detailed_decoder())
}

/// Decode a plays `listRecords` body. The wrapper is unwrapped
/// since the plays view doesn't need the URI.
pub fn decode_plays(
  body: String,
) -> Result(List(FeedPlay), json.DecodeError) {
  decode_records(body, feed_play_decoder())
  |> result.map(list.map(_, fn(record) { record.value }))
}

/// Decode the repos `listRecords` body, keeping each record's URI so
/// the data layer can derive the display name from the rkey.
pub fn decode_repos(
  body: String,
) -> Result(List(DecodedRecord(Repo)), json.DecodeError) {
  decode_records(body, repo_decoder())
}

/// Decode the actor profile `listRecords` body. Pinned DIDs are
/// extracted separately via `pinned_dids_from_profiles`.
pub fn decode_actor_profiles(
  body: String,
) -> Result(List(DecodedRecord(ActorProfile)), json.DecodeError) {
  decode_records(body, actor_profile_decoder())
}

/// Parse a listRecords JSON body and decode each record's value.
/// Records whose value fails to decode are silently dropped — keeps
/// us robust against schema drift in individual records.
pub fn decode_records(
  body: String,
  decoder: decode.Decoder(a),
) -> Result(List(DecodedRecord(a)), json.DecodeError) {
  use records <- result.try(json.parse(body, list_of_records_decoder()))
  records
  |> list.filter_map(fn(record) {
    decode.run(record.value, decoder)
    |> result.map(fn(value) {
      DecodedRecord(uri: record.uri, cid: record.cid, value:)
    })
  })
  |> Ok
}

fn list_of_records_decoder() -> decode.Decoder(List(Record)) {
  use records <- decode.field("records", decode.list(record_decoder()))
  decode.success(records)
}

/// Return the last path segment of an `at://` URI — the rkey. For
/// `at://did:plc:abc/sh.tangled.repo/blog` this returns
/// `Ok("blog")`, the repo's human-readable slug.
pub fn rkey_from_uri(uri: String) -> Result(String, Nil) {
  list.last(string.split(uri, on: "/"))
}

/// Fill in a Tangled repo's `name` from the URI rkey when the
/// original is missing or empty. Records without a real name usually
/// hold an auto-generated hash; the rkey is the slug Tangled uses
/// for the URL. Returns the wrapper unchanged if the URI can't be
/// parsed, so the caller can still pass it to hydration.
pub fn resolve_repo_name(record: DecodedRecord(Repo)) -> DecodedRecord(Repo) {
  let repo = record.value
  case repo.name {
    Some(name) if name != "" -> record
    _ ->
      case rkey_from_uri(record.uri) {
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
    |> option.unwrap(or: [])
    |> list.filter(fn(did) { did != "" })
  })
}
