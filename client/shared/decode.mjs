import * as $json from "../gleam_json/gleam/json.mjs";
import * as $dynamic from "../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $result from "../gleam_stdlib/gleam/result.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import { profile_view_detailed_decoder } from "./gen/actor/defs.mjs";
import * as $profile from "./gen/actor/profile.mjs";
import { actor_profile_decoder } from "./gen/actor/profile.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import { alpha_feed_play_decoder } from "./gen/alpha/feed/play.mjs";
import * as $repo from "./gen/repo.mjs";
import { repo_decoder } from "./gen/repo.mjs";
import { Ok, toList } from "./gleam.mjs";
import * as $hydration from "./hydration.mjs";
import { HydrationModel } from "./hydration.mjs";

/**
 * Decode a getProfile response into a Profile.
 */
export function decode_profile(json_string) {
  return $json.parse(json_string, profile_view_detailed_decoder());
}

function pinned_value_decoder() {
  return $decode.field(
    "value",
    actor_profile_decoder(),
    (value) => {
      return $decode.success(
        (() => {
          let _pipe = unwrap(value.pinned_repositories, toList([]));
          return $list.filter(_pipe, (d) => { return d !== ""; });
        })(),
      );
    },
  );
}

function extract_pinned_dids(records) {
  let _pipe = records;
  let _pipe$1 = $list.map(
    _pipe,
    (record) => {
      let _pipe$1 = $decode.run(record, pinned_value_decoder());
      return $result.unwrap(_pipe$1, toList([]));
    },
  );
  return $list.flatten(_pipe$1);
}

function records_list_decoder() {
  return $decode.field(
    "records",
    $decode.list($decode.dynamic),
    (records) => { return $decode.success(records); },
  );
}

/**
 * Decode a listRecords response for sh.tangled.actor.profile
 * and extract the pinned DIDs.
 */
export function decode_pinned_dids(json_string) {
  return $result.try$(
    $json.parse(json_string, records_list_decoder()),
    (records) => { return new Ok(extract_pinned_dids(records)); },
  );
}

function value_decoder(inner) {
  return $decode.field(
    "value",
    inner,
    (value) => { return $decode.success(value); },
  );
}

function decode_record_values(records, inner) {
  let _pipe = records;
  let _pipe$1 = $list.map(
    _pipe,
    (record) => { return $decode.run(record, value_decoder(inner)); },
  );
  return $result.values(_pipe$1);
}

/**
 * Decode a listRecords response for sh.tangled.repo into a list of Repo values.
 */
export function decode_repos(json_string) {
  return $result.try$(
    $json.parse(json_string, records_list_decoder()),
    (records) => {
      return new Ok(decode_record_values(records, repo_decoder()));
    },
  );
}

/**
 * Decode a listRecords response for fm.teal.alpha.feed.play into a list
 * of Play values.
 */
export function decode_plays(json_string) {
  return $result.try$(
    $json.parse(json_string, records_list_decoder()),
    (records) => {
      return new Ok(decode_record_values(records, alpha_feed_play_decoder()));
    },
  );
}

function hydration_model_decoder() {
  return $decode.field(
    "profile",
    profile_view_detailed_decoder(),
    (profile) => {
      return $decode.field(
        "plays",
        $decode.list(alpha_feed_play_decoder()),
        (plays) => {
          return $decode.field(
            "repos",
            $decode.list(repo_decoder()),
            (repos) => {
              return $decode.success(new HydrationModel(profile, plays, repos));
            },
          );
        },
      );
    },
  );
}

export function decode_hydration_model(json_string) {
  return $json.parse(json_string, hydration_model_decoder());
}
