//// URLs and response decoders for AT Protocol data.
////
//// URL builders use `uri.query_to_string` (same as the generated XRPC client)
//// rather than string concatenation. Response decoders accept raw JSON from
//// either `xrpc.Client` (Erlang) or `fetch_text` (browser).

import api
import gen/actor/defs.{type ProfileViewDetailed, profile_view_detailed_decoder}
import gen/actor/profile.{actor_profile_decoder}
import gen/alpha/feed/play.{type AlphaFeedPlay, alpha_feed_play_decoder}
import gen/repo.{type Repo, repo_decoder}
import gen/repo/list_records.{type Record, record_decoder}
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/uri

pub fn profile_url() -> String {
  let params = [#("actor", "karitham.dev")]
  let query = uri.query_to_string(params)
  api.public_api <> "/xrpc/app.bsky.actor.getProfile?" <> query
}

pub fn plays_url() -> String {
  let params = [
    #("repo", api.did),
    #("collection", "fm.teal.alpha.feed.play"),
    #("limit", int.to_string(api.plays_limit)),
  ]
  let query = uri.query_to_string(params)
  api.pds_endpoint <> "/xrpc/com.atproto.repo.listRecords?" <> query
}

pub fn pinned_dids_url() -> String {
  let params = [
    #("repo", api.did),
    #("collection", "sh.tangled.actor.profile"),
  ]
  let query = uri.query_to_string(params)
  api.pds_endpoint <> "/xrpc/com.atproto.repo.listRecords?" <> query
}

pub fn repos_url() -> String {
  let params = [
    #("repo", api.did),
    #("collection", "sh.tangled.repo"),
  ]
  let query = uri.query_to_string(params)
  api.pds_endpoint <> "/xrpc/com.atproto.repo.listRecords?" <> query
}

pub fn decode_profile(
  body: String,
) -> Result(ProfileViewDetailed, json.DecodeError) {
  json.parse(body, profile_view_detailed_decoder())
}

pub fn decode_plays(
  body: String,
) -> Result(List(AlphaFeedPlay), json.DecodeError) {
  use records <- result.try(json.parse(body, records_list_decoder()))
  Ok(decode_record_values(records, alpha_feed_play_decoder()))
}

pub fn decode_repos(body: String) -> Result(List(Repo), json.DecodeError) {
  use records <- result.try(json.parse(body, records_list_decoder()))
  Ok(decode_record_values(records, repo_decoder()))
}

pub fn decode_pinned_dids(
  body: String,
) -> Result(List(String), json.DecodeError) {
  use records <- result.try(json.parse(body, records_list_decoder()))
  Ok(extract_pinned_dids(records))
}

/// Records whose values fail to decode are silently dropped — this keeps
/// us robust against schema drift in individual records.
pub fn decode_record_values(
  records: List(Record),
  decoder: decode.Decoder(a),
) -> List(a) {
  records
  |> list.map(fn(record) { decode.run(record.value, decoder) })
  |> result.values
}

fn records_list_decoder() -> decode.Decoder(List(Record)) {
  use records <- decode.field("records", decode.list(record_decoder()))
  decode.success(records)
}

fn extract_pinned_dids(records: List(Record)) -> List(String) {
  records
  |> list.map(fn(record) {
    case decode.run(record.value, actor_profile_decoder()) {
      Ok(profile) ->
        profile.pinned_repositories
        |> option.unwrap(or: [])
        |> list.filter(fn(d) { d != "" })
      Error(_) -> []
    }
  })
  |> list.flatten
}
