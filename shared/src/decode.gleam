import gen/actor/defs.{profile_view_detailed_decoder}
import gen/alpha/feed/play.{alpha_feed_play_decoder}
import gen/repo.{repo_decoder}
import gleam/dynamic/decode
import gleam/json
import hydration.{type HydrationModel, HydrationModel}

pub fn decode_hydration_model(
  json_string: String,
) -> Result(HydrationModel, json.DecodeError) {
  json.parse(json_string, hydration_model_decoder())
}

fn hydration_model_decoder() -> decode.Decoder(HydrationModel) {
  use profile <- decode.field("profile", profile_view_detailed_decoder())
  use plays <- decode.field("plays", decode.list(alpha_feed_play_decoder()))
  use repos <- decode.field("repos", decode.list(repo_decoder()))
  decode.success(HydrationModel(profile:, plays:, repos:))
}
