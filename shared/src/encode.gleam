//// Hydration payload encoder. Mirrors `decode` — writes JSON the
//// client decodes as island flags. Escapes `<`/`>` for safe `<script>` embed.

import atproto.{type DecodedRecord}
import gen/actor/defs.{profile_view_detailed_fields}
import gen/feed/play.{feed_play_fields}
import gen/repo.{type Repo, repo_fields}
import gleam/dict.{type Dict}
import gleam/json
import gleam/list
import gleam/string
import hydration.{type HydrationModel}

/// Serialize a HydrationModel to the JSON shape embedded in the
/// page for client hydration. Uses the generated field encoders
/// so the shape matches what the generated decoders expect.
/// Pairs with `decode.decode_hydration_model`.
///
/// The payload lands in `html.script`, which inserts its argument
/// unescaped (`unsafe_raw_html`). The HTML tokenizer ends a script
/// element at the first `</script`, so raw `<`/`>` in remote data
/// (artist names, repo descriptions, profile bio) would break out of
/// the tag. `\uXXXX` escapes are lossless for JSON consumers: the
/// decoder sees the original characters.
pub fn encode_hydration_model(data: HydrationModel) -> String {
  json.object([
    #("profile", json.object(profile_view_detailed_fields(data.profile))),
    #(
      "plays",
      json.array(from: data.plays, of: fn(p) {
        json.object(feed_play_fields(p))
      }),
    ),
    #(
      "repos",
      json.array(from: data.repos, of: fn(r) { encode_decoded_repo(r) }),
    ),
    #("rewrites", encode_rewrites(data.rewrites)),
  ])
  |> json.to_string
  |> string.replace("<", "\\u003c")
  |> string.replace(">", "\\u003e")
}

fn encode_rewrites(rewrites: Dict(String, String)) -> json.Json {
  dict.to_list(rewrites)
  |> list.map(fn(pair) { #(pair.0, json.string(pair.1)) })
  |> json.object
}

fn encode_decoded_repo(record: DecodedRecord(Repo)) -> json.Json {
  json.object([
    #("uri", json.string(record.uri)),
    #("cid", json.string(record.cid)),
    #("value", json.object(repo_fields(record.value))),
  ])
}
