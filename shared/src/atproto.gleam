//// URL builders and response decoders for AT Protocol data.
////
//// URL builders use `uri.query_to_string`; response decoders accept
//// raw JSON from either the SSG's httpc transport or the browser's
//// `fetch_text`, so the same module serves both targets.
////
//// `DecodedRecord` preserves a record's URI alongside its decoded
//// value. Tangled v1 puts repo manifests in the repo DID's account,
//// so the URI authority identifies the repo; the owner's PDS only
//// holds the profile record with the pinned repo DIDs.

import api
import gen/actor/defs.{type ProfileViewDetailed, profile_view_detailed_decoder}
import gen/actor/profile.{type ActorProfile, actor_profile_decoder}
import gen/feed/play.{type FeedPlay, feed_play_decoder}
import gen/repo/list_records.{type Record, record_decoder}
import gen/repo/manifest.{type RepoManifest, repo_manifest_decoder}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/uri

/// A record paired with its decoded value.
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

/// The owner's Tangled profile record. Its `pinnedRepositories` list
/// holds the repo DIDs that gate the repo query. Keyed `self`, so a
/// single `getRecord` is exhaustive.
pub fn pinned_dids_url() -> String {
  let params = [
    #("repo", api.did),
    #("collection", "org.tangled.actor.profile"),
    #("rkey", "self"),
  ]
  api.pds_endpoint
  <> "/xrpc/com.atproto.repo.getRecord?"
  <> uri.query_to_string(params)
}

/// Manifests for the pinned repos, fetched from Tangled's appview in
/// one call. Manifests live in each repo DID's account, so the owner's
/// PDS cannot list them; the appview resolves the DIDs and returns the
/// `{uri, cid, value}` items this module decodes.
pub fn repos_url(pinned_dids: List(String)) -> String {
  let params = list.map(pinned_dids, fn(did) { #("dids", did) })
  api.tangled_api
  <> "/xrpc/org.tangled.repo.getReposByRepoDids?"
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
  decode_list_records(body, feed_play_decoder())
  |> result.map(fn(pair) {
    let #(records, drops) = pair
    #(list.map(records, fn(record) { record.value }), drops)
  })
}

/// Decode the appview's `getReposByRepoDids` body into manifests,
/// keeping each repo's URI so the data layer can recover its DID. As
/// with plays, the drop count keeps vendored-schema drift visible: an
/// empty Projects section with a warning is distinguishable from no
/// pins at all.
pub fn decode_repos(
  body: String,
) -> Result(#(List(DecodedRecord(RepoManifest)), Int), json.DecodeError) {
  use items <- result.try(json.parse(body, repo_items_decoder()))
  Ok(decode_record_values(items, repo_manifest_decoder()))
}

/// Decode a Tangled profile `getRecord` body. Pinned DIDs are
/// extracted separately via `tangled.pinned_dids_from_profile`.
pub fn decode_actor_profile(
  body: String,
) -> Result(ActorProfile, json.DecodeError) {
  json.parse(body, actor_profile_value_decoder())
}

fn decode_list_records(
  body: String,
  decoder: decode.Decoder(a),
) -> Result(#(List(DecodedRecord(a)), Int), json.DecodeError) {
  use records <- result.try(json.parse(body, list_of_records_decoder()))
  Ok(decode_record_values(records, decoder))
}

/// Decode each record's value, dropping the ones that fail. The drop
/// count is the difference between the envelope and decoded lengths.
fn decode_record_values(
  records: List(Record),
  decoder: decode.Decoder(a),
) -> #(List(DecodedRecord(a)), Int) {
  let decoded =
    records
    |> list.filter_map(fn(record) {
      decode.run(record.value, decoder)
      |> result.map(fn(value) {
        DecodedRecord(uri: record.uri, cid: record.cid, value:)
      })
    })
  #(decoded, list.length(records) - list.length(decoded))
}

fn list_of_records_decoder() -> decode.Decoder(List(Record)) {
  use records <- decode.field("records", decode.list(record_decoder()))
  decode.success(records)
}

fn repo_items_decoder() -> decode.Decoder(List(Record)) {
  use items <- decode.field("items", decode.list(record_decoder()))
  decode.success(items)
}

fn actor_profile_value_decoder() -> decode.Decoder(ActorProfile) {
  use value <- decode.field("value", actor_profile_decoder())
  decode.success(value)
}
