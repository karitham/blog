import * as $json from "../gleam_json/gleam/json.mjs";
import * as $atproto from "./atproto.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import { profile_view_detailed_fields } from "./gen/actor/defs.mjs";
import * as $play from "./gen/feed/play.mjs";
import { feed_play_fields } from "./gen/feed/play.mjs";
import * as $repo from "./gen/repo.mjs";
import { repo_fields } from "./gen/repo.mjs";
import { toList } from "./gleam.mjs";
import * as $hydration from "./hydration.mjs";

function encode_decoded_repo(record) {
  return $json.object(
    toList([
      ["uri", $json.string(record.uri)],
      ["cid", $json.string(record.cid)],
      ["value", $json.object(repo_fields(record.value))],
    ]),
  );
}

/**
 * Serialize a HydrationModel to the JSON shape embedded in the
 * page for client hydration. Uses the generated field encoders
 * so the shape matches what the generated decoders expect.
 * Pairs with `decode.decode_hydration_model`.
 */
export function encode_hydration_model(data) {
  let _pipe = $json.object(
    toList([
      ["profile", $json.object(profile_view_detailed_fields(data.profile))],
      [
        "plays",
        $json.array(
          data.plays,
          (p) => { return $json.object(feed_play_fields(p)); },
        ),
      ],
      [
        "repos",
        $json.array(data.repos, (r) => { return encode_decoded_repo(r); }),
      ],
    ]),
  );
  return $json.to_string(_pipe);
}
