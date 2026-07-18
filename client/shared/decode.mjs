import * as $json from "../gleam_json/gleam/json.mjs";
import * as $decode from "../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import { profile_view_detailed_decoder } from "./gen/actor/defs.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import { alpha_feed_play_decoder } from "./gen/alpha/feed/play.mjs";
import * as $repo from "./gen/repo.mjs";
import { repo_decoder } from "./gen/repo.mjs";
import * as $hydration from "./hydration.mjs";
import { HydrationModel } from "./hydration.mjs";

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
