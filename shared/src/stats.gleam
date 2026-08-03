// The plays-stats.json contract — the file shape produced by the
// `parse-plays stats` tool (tools/parse-plays/src/stats.rs) and
// consumed by the SSG at build time.
//
// File shape:
//   {
//     "ranges": {
//       "1m":  { "artists": [...], "albums": [...], "tracks": [...] },
//       "6m":  { ... },
//       "1y":  { ... },
//       "all": { ... }
//     }
//   }
//
// Each grid item:
//   { "name": "...", "artist": "...", "plays": 123,
//     "ms_played": 456, "image": "https://...", "url": "https://..." }
// `artist`, `image` and `url` are omitted when empty.

import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result

pub type Range {
  OneMonth
  SixMonths
  OneYear
  AllTime
}

pub fn all_ranges() -> List(Range) {
  [OneMonth, SixMonths, OneYear, AllTime]
}

/// JSON key; also the `data-range` attribute value in the view.
pub fn range_key(range: Range) -> String {
  case range {
    OneMonth -> "1m"
    SixMonths -> "6m"
    OneYear -> "1y"
    AllTime -> "all"
  }
}

pub fn range_label(range: Range) -> String {
  case range {
    OneMonth -> "1 month"
    SixMonths -> "6 months"
    OneYear -> "1 year"
    AllTime -> "all time"
  }
}

pub type StatsData {
  StatsData(ranges: List(#(Range, RangeStats)))
}

pub type RangeStats {
  RangeStats(
    artists: List(StatsItem),
    albums: List(StatsItem),
    tracks: List(StatsItem),
  )
}

pub type StatsItem {
  StatsItem(
    name: String,
    artist: String,
    plays: Int,
    ms_played: Int,
    image: String,
    url: String,
  )
}

pub fn empty_stats() -> StatsData {
  StatsData(ranges: [])
}

pub fn empty_range_stats() -> RangeStats {
  RangeStats(artists: [], albums: [], tracks: [])
}

pub fn stats_data_decoder() -> decode.Decoder(StatsData) {
  use ranges <- decode.field("ranges", decode.dynamic)
  decode.success(StatsData(ranges: decode_ranges(ranges)))
}

/// Decode each of the four range keys from the `ranges` object,
/// defaulting to empty when a key is missing.
fn decode_ranges(ranges: dynamic.Dynamic) -> List(#(Range, RangeStats)) {
  list.map(all_ranges(), fn(range) {
    let decoded =
      decode.run(
        ranges,
        decode.optionally_at(
          [range_key(range)],
          empty_range_stats(),
          range_stats_decoder(),
        ),
      )
    #(range, result.unwrap(decoded, empty_range_stats()))
  })
}

fn range_stats_decoder() -> decode.Decoder(RangeStats) {
  use artists <- decode.field("artists", decode.list(stats_item_decoder()))
  use albums <- decode.field("albums", decode.list(stats_item_decoder()))
  use tracks <- decode.field("tracks", decode.list(stats_item_decoder()))
  decode.success(RangeStats(artists:, albums:, tracks:))
}

fn stats_item_decoder() -> decode.Decoder(StatsItem) {
  use name <- decode.field("name", decode.string)
  use artist <- decode.optional_field("artist", "", decode.string)
  use plays <- decode.field("plays", decode.int)
  use ms_played <- decode.field("ms_played", decode.int)
  use image <- decode.optional_field("image", "", decode.string)
  use url <- decode.optional_field("url", "", decode.string)
  decode.success(StatsItem(name:, artist:, plays:, ms_played:, image:, url:))
}

/// Is there anything to show? The view hides the aside when false.
pub fn is_empty(stats: StatsData) -> Bool {
  stats.ranges
  |> list.all(fn(pair) {
    let #(_, range_stats) = pair
    list.is_empty(range_stats.artists)
    && list.is_empty(range_stats.albums)
    && list.is_empty(range_stats.tracks)
  })
}
