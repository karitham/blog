import gen/actor/defs.{profile_view_detailed_fields}
import gen/alpha/feed/play.{alpha_feed_play_fields}
import gen/repo.{repo_fields}
import gleam/json
import hydration.{type HydrationModel}

/// Serialize a HydrationModel to the JSON shape embedded in the
/// page for client hydration. Uses the generated field encoders
/// so the shape matches what the generated decoders expect.
/// Pairs with `decode.decode_hydration_model`.
pub fn encode_hydration_model(data: HydrationModel) -> String {
  json.object([
    #("profile", json.object(profile_view_detailed_fields(data.profile))),
    #(
      "plays",
      json.array(from: data.plays, of: fn(p) {
        json.object(alpha_feed_play_fields(p))
      }),
    ),
    #(
      "repos",
      json.array(from: data.repos, of: fn(r) { json.object(repo_fields(r)) }),
    ),
  ])
  |> json.to_string
}
