import * as $json from "../gleam_json/gleam/json.mjs";
import * as $decode from "../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../gleam_stdlib/gleam/int.mjs";
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import * as $result from "../gleam_stdlib/gleam/result.mjs";
import * as $uri from "../gleam_stdlib/gleam/uri.mjs";
import * as $api from "./api.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import { profile_view_detailed_decoder } from "./gen/actor/defs.mjs";
import * as $profile from "./gen/actor/profile.mjs";
import { actor_profile_decoder } from "./gen/actor/profile.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import { alpha_feed_play_decoder } from "./gen/alpha/feed/play.mjs";
import * as $repo from "./gen/repo.mjs";
import { repo_decoder } from "./gen/repo.mjs";
import * as $list_records from "./gen/repo/list_records.mjs";
import { record_decoder } from "./gen/repo/list_records.mjs";
import { Ok, toList } from "./gleam.mjs";

export function profile_url() {
  let params = toList([["actor", "karitham.dev"]]);
  let query = $uri.query_to_string(params);
  return ($api.public_api + "/xrpc/app.bsky.actor.getProfile?") + query;
}

export function plays_url() {
  let params = toList([
    ["repo", $api.did],
    ["collection", "fm.teal.alpha.feed.play"],
    ["limit", $int.to_string($api.plays_limit)],
  ]);
  let query = $uri.query_to_string(params);
  return ($api.pds_endpoint + "/xrpc/com.atproto.repo.listRecords?") + query;
}

export function pinned_dids_url() {
  let params = toList([
    ["repo", $api.did],
    ["collection", "sh.tangled.actor.profile"],
  ]);
  let query = $uri.query_to_string(params);
  return ($api.pds_endpoint + "/xrpc/com.atproto.repo.listRecords?") + query;
}

export function repos_url() {
  let params = toList([["repo", $api.did], ["collection", "sh.tangled.repo"]]);
  let query = $uri.query_to_string(params);
  return ($api.pds_endpoint + "/xrpc/com.atproto.repo.listRecords?") + query;
}

export function decode_profile(body) {
  return $json.parse(body, profile_view_detailed_decoder());
}

/**
 * Records whose values fail to decode are silently dropped — this keeps
 * us robust against schema drift in individual records.
 */
export function decode_record_values(records, decoder) {
  let _pipe = records;
  let _pipe$1 = $list.map(
    _pipe,
    (record) => { return $decode.run(record.value, decoder); },
  );
  return $result.values(_pipe$1);
}

function records_list_decoder() {
  return $decode.field(
    "records",
    $decode.list(record_decoder()),
    (records) => { return $decode.success(records); },
  );
}

export function decode_plays(body) {
  return $result.try$(
    $json.parse(body, records_list_decoder()),
    (records) => {
      return new Ok(decode_record_values(records, alpha_feed_play_decoder()));
    },
  );
}

export function decode_repos(body) {
  return $result.try$(
    $json.parse(body, records_list_decoder()),
    (records) => {
      return new Ok(decode_record_values(records, repo_decoder()));
    },
  );
}

function extract_pinned_dids(records) {
  let _pipe = records;
  let _pipe$1 = $list.map(
    _pipe,
    (record) => {
      let $ = $decode.run(record.value, actor_profile_decoder());
      if ($ instanceof Ok) {
        let profile = $[0];
        let _pipe$1 = profile.pinned_repositories;
        let _pipe$2 = $option.unwrap(_pipe$1, toList([]));
        return $list.filter(_pipe$2, (d) => { return d !== ""; });
      } else {
        return toList([]);
      }
    },
  );
  return $list.flatten(_pipe$1);
}

export function decode_pinned_dids(body) {
  return $result.try$(
    $json.parse(body, records_list_decoder()),
    (records) => { return new Ok(extract_pinned_dids(records)); },
  );
}
