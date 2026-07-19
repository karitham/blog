import * as $json from "../gleam_json/gleam/json.mjs";
import * as $decode from "../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $fetch from "./fetch.mjs";
import { DecodedRecord } from "./fetch.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import { profile_view_detailed_decoder } from "./gen/actor/defs.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import { alpha_feed_play_decoder } from "./gen/alpha/feed/play.mjs";
import * as $repo from "./gen/repo.mjs";
import { repo_decoder } from "./gen/repo.mjs";
import * as $hydration from "./hydration.mjs";
import { HydrationModel } from "./hydration.mjs";

function decoded_repo_decoder() {
  return $decode.field(
    "uri",
    $decode.string,
    (uri) => {
      return $decode.field(
        "cid",
        $decode.string,
        (cid) => {
          return $decode.field(
            "value",
            repo_decoder(),
            (value) => {
              return $decode.success(new DecodedRecord(uri, cid, value));
            },
          );
        },
      );
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
            $decode.list(decoded_repo_decoder()),
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
