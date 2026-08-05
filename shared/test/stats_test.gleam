import gleam/json
import gleam/list
import gleeunit/should
import stats

fn full_stats_body() -> String {
  "{
    \"ranges\": {
      \"1m\": {
        \"artists\": [
          {\"name\": \"Alpha\", \"plays\": 5, \"ms_played\": 1000,
           \"image\": \"/img/alpha.jpg\", \"url\": \"https://musicbrainz.org/artist/a\"}
        ],
        \"albums\": [
          {\"name\": \"Album A\", \"artist\": \"Alpha\", \"plays\": 3, \"ms_played\": 500}
        ],
        \"tracks\": []
      },
      \"6m\": {\"artists\": [], \"albums\": [], \"tracks\": []},
      \"1y\": {\"artists\": [], \"albums\": [], \"tracks\": []},
      \"all\": {\"artists\": [], \"albums\": [], \"tracks\": []}
    }
  }"
}

pub fn decoder_reads_all_four_ranges_test() {
  let assert Ok(data) =
    json.parse(full_stats_body(), stats.stats_data_decoder())
  data.ranges |> list.length |> should.equal(4)
  let assert [first, ..] = data.ranges
  let #(range, range_stats) = first
  range |> should.equal(stats.OneMonth)
  range_stats.artists |> list.length |> should.equal(1)
}

pub fn decoder_omits_optional_fields_test() {
  let assert Ok(data) =
    json.parse(full_stats_body(), stats.stats_data_decoder())
  let assert [first, ..] = data.ranges
  let #(_, range_stats) = first
  let assert [artist] = range_stats.artists
  artist.artist |> should.equal("")
  artist.url |> should.equal("https://musicbrainz.org/artist/a")
  let assert [album] = range_stats.albums
  album.artist |> should.equal("Alpha")
  album.image |> should.equal("")
}

pub fn decoder_defaults_missing_ranges_to_empty_test() {
  let body =
    "{\"ranges\": {\"1m\": {\"artists\": [], \"albums\": [], \"tracks\": []}}}"
  let assert Ok(data) = json.parse(body, stats.stats_data_decoder())
  data.ranges |> list.length |> should.equal(4)
  stats.is_empty(data) |> should.be_true()
}

pub fn decoder_rejects_missing_ranges_test() {
  json.parse("{}", stats.stats_data_decoder())
  |> should.be_error()
}

pub fn empty_stats_is_empty_test() {
  stats.is_empty(stats.empty_stats()) |> should.be_true()
}

pub fn encode_round_trips_through_decoder_test() {
  let assert Ok(original) =
    json.parse(full_stats_body(), stats.stats_data_decoder())
  let json_string = stats.encode_stats(original)
  let assert Ok(decoded) = json.parse(json_string, stats.stats_data_decoder())
  decoded |> should.equal(original)
}

pub fn encode_empty_stats_test() {
  // `empty_stats` has no ranges while the decoder always yields four
  // (all empty) — the round trip preserves emptiness, not structure.
  let json_string = stats.encode_stats(stats.empty_stats())
  let assert Ok(decoded) = json.parse(json_string, stats.stats_data_decoder())
  stats.is_empty(decoded) |> should.be_true()
}
