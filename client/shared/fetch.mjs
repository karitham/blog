import * as $json from "../gleam_json/gleam/json.mjs";
import * as $decode from "../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../gleam_stdlib/gleam/int.mjs";
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { Some } from "../gleam_stdlib/gleam/option.mjs";
import * as $result from "../gleam_stdlib/gleam/result.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $uri from "../gleam_stdlib/gleam/uri.mjs";
import * as $api from "./api.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import { profile_view_detailed_decoder } from "./gen/actor/defs.mjs";
import * as $profile from "./gen/actor/profile.mjs";
import { actor_profile_decoder } from "./gen/actor/profile.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import { alpha_feed_play_decoder } from "./gen/alpha/feed/play.mjs";
import * as $repo from "./gen/repo.mjs";
import { Repo, repo_decoder } from "./gen/repo.mjs";
import * as $list_records from "./gen/repo/list_records.mjs";
import { record_decoder } from "./gen/repo/list_records.mjs";
import { Ok, toList, CustomType as $CustomType } from "./gleam.mjs";

export class DecodedRecord extends $CustomType {
  constructor(uri, cid, value) {
    super();
    this.uri = uri;
    this.cid = cid;
    this.value = value;
  }
}
export const DecodedRecord$DecodedRecord = (uri, cid, value) =>
  new DecodedRecord(uri, cid, value);
export const DecodedRecord$isDecodedRecord = (value) =>
  value instanceof DecodedRecord;
export const DecodedRecord$DecodedRecord$uri = (value) => value.uri;
export const DecodedRecord$DecodedRecord$0 = (value) => value.uri;
export const DecodedRecord$DecodedRecord$cid = (value) => value.cid;
export const DecodedRecord$DecodedRecord$1 = (value) => value.cid;
export const DecodedRecord$DecodedRecord$value = (value) => value.value;
export const DecodedRecord$DecodedRecord$2 = (value) => value.value;

export function profile_url() {
  let params = toList([["actor", "karitham.dev"]]);
  return ($api.public_api + "/xrpc/app.bsky.actor.getProfile?") + $uri.query_to_string(
    params,
  );
}

export function plays_url() {
  let params = toList([
    ["repo", $api.did],
    ["collection", "fm.teal.alpha.feed.play"],
    ["limit", $int.to_string($api.plays_limit)],
  ]);
  return ($api.pds_endpoint + "/xrpc/com.atproto.repo.listRecords?") + $uri.query_to_string(
    params,
  );
}

export function pinned_dids_url() {
  let params = toList([
    ["repo", $api.did],
    ["collection", "sh.tangled.actor.profile"],
  ]);
  return ($api.pds_endpoint + "/xrpc/com.atproto.repo.listRecords?") + $uri.query_to_string(
    params,
  );
}

export function repos_url() {
  let params = toList([["repo", $api.did], ["collection", "sh.tangled.repo"]]);
  return ($api.pds_endpoint + "/xrpc/com.atproto.repo.listRecords?") + $uri.query_to_string(
    params,
  );
}

/**
 * Decode a `getProfile` JSON body into a typed profile.
 */
export function decode_profile(body) {
  return $json.parse(body, profile_view_detailed_decoder());
}

function list_of_records_decoder() {
  return $decode.field(
    "records",
    $decode.list(record_decoder()),
    (records) => { return $decode.success(records); },
  );
}

/**
 * Parse a listRecords JSON body and decode each record's value.
 * Records whose value fails to decode are silently dropped — keeps
 * us robust against schema drift in individual records.
 */
export function decode_records(body, decoder) {
  return $result.try$(
    $json.parse(body, list_of_records_decoder()),
    (records) => {
      let _pipe = records;
      let _pipe$1 = $list.filter_map(
        _pipe,
        (record) => {
          let _pipe$1 = $decode.run(record.value, decoder);
          return $result.map(
            _pipe$1,
            (value) => {
              return new DecodedRecord(record.uri, record.cid, value);
            },
          );
        },
      );
      return new Ok(_pipe$1);
    },
  );
}

/**
 * Decode the plays `listRecords` body. The wrapper is unwrapped
 * since the plays view doesn't need the URI.
 */
export function decode_plays(body) {
  let _pipe = decode_records(body, alpha_feed_play_decoder());
  return $result.map(
    _pipe,
    (_capture) => {
      return $list.map(_capture, (record) => { return record.value; });
    },
  );
}

/**
 * Decode the repos `listRecords` body, keeping each record's URI so
 * the data layer can derive the display name from the rkey.
 */
export function decode_repos(body) {
  return decode_records(body, repo_decoder());
}

/**
 * Decode the actor profile `listRecords` body. Pinned DIDs are
 * extracted separately via `pinned_dids_from_profiles`.
 */
export function decode_actor_profiles(body) {
  return decode_records(body, actor_profile_decoder());
}

/**
 * Return the last path segment of an `at://` URI — the rkey. For
 * `at://did:plc:abc/sh.tangled.repo/blog` this returns
 * `Ok("blog")`, the repo's human-readable slug.
 */
export function rkey_from_uri(uri) {
  return $list.last($string.split(uri, "/"));
}

/**
 * Fill in a Tangled repo's `name` from the URI rkey when the
 * original is missing or empty. Records without a real name usually
 * hold an auto-generated hash; the rkey is the slug Tangled uses
 * for the URL. Returns the wrapper unchanged if the URI can't be
 * parsed, so the caller can still pass it to hydration.
 */
export function resolve_repo_name(record) {
  let repo = record.value;
  let $ = repo.name;
  if ($ instanceof Some) {
    let name = $[0];
    if (name !== "") {
      return record;
    } else {
      let $1 = rkey_from_uri(record.uri);
      if ($1 instanceof Ok) {
        let rkey = $1[0];
        return new DecodedRecord(
          record.uri,
          record.cid,
          new Repo(
            repo.created_at,
            repo.description,
            new Some(rkey),
            repo.repo_did,
            repo.topics,
            repo.website,
          ),
        );
      } else {
        return record;
      }
    }
  } else {
    let $1 = rkey_from_uri(record.uri);
    if ($1 instanceof Ok) {
      let rkey = $1[0];
      return new DecodedRecord(
        record.uri,
        record.cid,
        new Repo(
          repo.created_at,
          repo.description,
          new Some(rkey),
          repo.repo_did,
          repo.topics,
          repo.website,
        ),
      );
    } else {
      return record;
    }
  }
}

/**
 * Drop repo records whose `repo_did` isn't in the pinned list.
 */
export function filter_repos_by_did(records, pinned_dids) {
  return $list.filter(
    records,
    (record) => { return $list.contains(pinned_dids, record.value.repo_did); },
  );
}

/**
 * Extract non-empty pinned DIDs from one or more actor profile
 * records. Tangled pads the list with empty rkeys as placeholders;
 * those are dropped.
 */
export function pinned_dids_from_profiles(records) {
  let _pipe = records;
  return $list.flat_map(
    _pipe,
    (record) => {
      let _pipe$1 = record.value.pinned_repositories;
      let _pipe$2 = $option.unwrap(_pipe$1, toList([]));
      return $list.filter(_pipe$2, (did) => { return did !== ""; });
    },
  );
}
