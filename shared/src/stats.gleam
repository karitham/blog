//// Plays-stats contract — file shape produced by `tools/parse-plays`
//// (`tools/parse-plays/src/stats.rs`) and consumed by the SSG.
////
//// File shape:
////   {
////     "ranges": {
////       "1m":  { "artists": [...], "albums": [...], "tracks": [...] },
////       "6m":  { ... },
////       "1y":  { ... },
////       "all": { ... }
////     }
////   }
////
//// Each grid item:
////   { "name": "...", "artist": "...", "plays": 123,
////     "ms_played": 456, "image": "https://...", "url": "https://..." }
//// `artist`, `image` and `url` are omitted when empty.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}

/// Time window for the top-N grids.
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

/// All four range grids.
pub type StatsData {
  StatsData(ranges: List(#(Range, RangeStats)))
}

/// One range's three grids.
pub type RangeStats {
  RangeStats(
    artists: List(StatsItem),
    albums: List(StatsItem),
    tracks: List(StatsItem),
  )
}

/// One tile in a grid. `artist`/`image`/`url` are `Option` so
/// absence is unrepresentable as `""` — the encoder omits `None` and
/// the view treats `None` as missing.
pub type StatsItem {
  StatsItem(
    name: String,
    artist: Option(String),
    plays: Int,
    ms_played: Int,
    image: Option(String),
    url: Option(String),
  )
}

pub fn empty_stats() -> StatsData {
  StatsData(ranges: [])
}

pub fn empty_range_stats() -> RangeStats {
  RangeStats(artists: [], albums: [], tracks: [])
}

/// Decode the `plays-stats.json` file. Each range key is optional;
/// missing keys default to empty, while a present but malformed value
/// fails the whole decode so the caller can log it rather than hide it.
pub fn stats_data_decoder() -> decode.Decoder(StatsData) {
  use ranges <- decode.field("ranges", ranges_decoder())
  decode.success(StatsData(ranges: ranges))
}

fn ranges_decoder() -> decode.Decoder(List(#(Range, RangeStats))) {
  use one_month <- decode.optional_field(
    "1m",
    empty_range_stats(),
    range_stats_decoder(),
  )
  use six_months <- decode.optional_field(
    "6m",
    empty_range_stats(),
    range_stats_decoder(),
  )
  use one_year <- decode.optional_field(
    "1y",
    empty_range_stats(),
    range_stats_decoder(),
  )
  use all <- decode.optional_field(
    "all",
    empty_range_stats(),
    range_stats_decoder(),
  )
  decode.success([
    #(OneMonth, one_month),
    #(SixMonths, six_months),
    #(OneYear, one_year),
    #(AllTime, all),
  ])
}

fn range_stats_decoder() -> decode.Decoder(RangeStats) {
  use artists <- decode.field("artists", decode.list(stats_item_decoder()))
  use albums <- decode.field("albums", decode.list(stats_item_decoder()))
  use tracks <- decode.field("tracks", decode.list(stats_item_decoder()))
  decode.success(RangeStats(artists:, albums:, tracks:))
}

fn stats_item_decoder() -> decode.Decoder(StatsItem) {
  use name <- decode.field("name", decode.string)
  use artist_opt <- decode.optional_field(
    "artist",
    option.None,
    decode.optional(decode.string),
  )
  let artist = empty_to_none(artist_opt)
  use plays <- decode.field("plays", decode.int)
  use ms_played <- decode.field("ms_played", decode.int)
  use image_opt <- decode.optional_field(
    "image",
    option.None,
    decode.optional(decode.string),
  )
  let image = empty_to_none(image_opt)
  use url_opt <- decode.optional_field(
    "url",
    option.None,
    decode.optional(decode.string),
  )
  let url = empty_to_none(url_opt)
  decode.success(StatsItem(name:, artist:, plays:, ms_played:, image:, url:))
}

fn empty_to_none(opt: Option(String)) -> Option(String) {
  case opt {
    option.Some("") -> option.None
    _ -> opt
  }
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

/// Encode `StatsData` back to the plays-stats.json shape. Mirrors the
/// decoder so the cross-language contract test can round-trip the
/// golden fixture; optional fields are omitted when empty, exactly
/// like `tools/parse-plays` writes them.
pub fn encode_stats(data: StatsData) -> String {
  json.object([
    #(
      "ranges",
      json.object(
        list.map(data.ranges, fn(pair) {
          let #(range, rs) = pair
          #(
            range_key(range),
            json.object([
              #("artists", json.array(from: rs.artists, of: encode_item)),
              #("albums", json.array(from: rs.albums, of: encode_item)),
              #("tracks", json.array(from: rs.tracks, of: encode_item)),
            ]),
          )
        }),
      ),
    ),
  ])
  |> json.to_string
}

fn encode_item(item: StatsItem) -> json.Json {
  json.object(
    [
      #("name", json.string(item.name)),
      #("plays", json.int(item.plays)),
      #("ms_played", json.int(item.ms_played)),
    ]
    |> list.append(encode_optional(item)),
  )
}

fn encode_optional(item: StatsItem) -> List(#(String, json.Json)) {
  [
    case item.artist {
      option.None -> []
      option.Some("") -> []
      option.Some(a) -> [#("artist", json.string(a))]
    },
    case item.image {
      option.None -> []
      option.Some("") -> []
      option.Some(i) -> [#("image", json.string(i))]
    },
    case item.url {
      option.None -> []
      option.Some("") -> []
      option.Some(u) -> [#("url", json.string(u))]
    },
  ]
  |> list.flatten
}
