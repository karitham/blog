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
import gen/repo.{type Repo, repo_decoder}
import gen/repo/list_records.{type Record, record_decoder}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
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

/// Decode a plays `listRecords` body, returning the plays plus the
/// number of records that failed to decode. The wrapper is unwrapped
/// since the plays view doesn't need the URI; the drop count makes
/// schema drift visible to callers (a renamed play field would
/// otherwise shrink the list silently).
pub fn decode_plays(
  body: String,
) -> Result(#(List(FeedPlay), Int), json.DecodeError) {
  decode_records_with_drops(body, feed_play_decoder())
  |> result.map(fn(pair) {
    let #(records, drops) = pair
    #(list.map(records, fn(record) { record.value }), drops)
  })
}

/// Decode the repos `listRecords` body, keeping each record's URI so
/// the data layer can derive the display name from the rkey.
pub fn decode_repos(
  body: String,
) -> Result(List(DecodedRecord(Repo)), json.DecodeError) {
  decode_records(body, repo_decoder())
}

/// Decode the actor profile `listRecords` body. Pinned DIDs are
/// extracted separately via `tangled.pinned_dids_from_profiles`.
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
  decode_records_with_drops(body, decoder)
  |> result.map(fn(pair) {
    let #(records, _) = pair
    records
  })
}

/// Like `decode_records`, but also reports how many records were
/// dropped so callers can surface schema drift instead of watching
/// data vanish silently.
fn decode_records_with_drops(
  body: String,
  decoder: decode.Decoder(a),
) -> Result(#(List(DecodedRecord(a)), Int), json.DecodeError) {
  use records <- result.try(json.parse(body, list_of_records_decoder()))
  let decoded =
    records
    |> list.filter_map(fn(record) {
      decode.run(record.value, decoder)
      |> result.map(fn(value) {
        DecodedRecord(uri: record.uri, cid: record.cid, value:)
      })
    })
  Ok(#(decoded, list.length(records) - list.length(decoded)))
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
