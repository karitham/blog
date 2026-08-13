import atproto
import gleam/string
import gleeunit/should
import lustre/element.{to_string}
import plays
import stats.{type StatsData, type StatsItem, RangeStats, StatsData, StatsItem}

// --- format_play_time ---

pub fn format_play_time_parses_utc_test() {
  plays.format_play_time("2026-07-18T10:05:00Z")
  |> should.equal(#("10:05", "2026-07-18T10:05:00Z"))
}

pub fn format_play_time_invalid_returns_empty_test() {
  plays.format_play_time("not a time") |> should.equal(#("", "not a time"))
}

// --- plays_rows ---

fn sample_play_body() -> String {
  // The minimal set of fields the play decoder requires.
  "{\"records\":[{
    \"cid\": \"bafy1\",
    \"uri\": \"at://did:plc:test/fm.teal.feed.play/abc\",
    \"value\": {
      \"artists\": [{\"artistName\": \"Artist A\"}],
      \"playedTime\": \"2026-07-18T10:00:00Z\",
      \"trackName\": \"Track A\"
    }
  }]}"
}

pub fn plays_rows_renders_rows_test() {
  let assert Ok(decoded) = atproto.decode_plays(sample_play_body())
  let html = plays.plays_rows(decoded) |> to_string
  string.contains(html, "plays-rows") |> should.be_true()
  string.contains(html, "Track A") |> should.be_true()
  string.contains(html, "Artist A") |> should.be_true()
}

// --- stats view tiles ---

fn stats_with_tile(item: StatsItem) -> StatsData {
  StatsData(ranges: [
    #(stats.OneMonth, RangeStats(artists: [item], albums: [], tracks: [])),
    #(stats.SixMonths, RangeStats(artists: [], albums: [], tracks: [])),
    #(stats.OneYear, RangeStats(artists: [], albums: [], tracks: [])),
    #(stats.AllTime, RangeStats(artists: [], albums: [], tracks: [])),
  ])
}

pub fn plays_section_tile_without_image_uses_placeholder_test() {
  let assert Ok(decoded) = atproto.decode_plays(sample_play_body())
  let data =
    stats_with_tile(StatsItem(
      name: "Alpha",
      artist: "",
      plays: 5,
      ms_played: 0,
      image: "",
      url: "",
    ))
  let html = plays.plays_section(decoded, data) |> to_string
  string.contains(html, "tile-cover--none") |> should.be_true()
  string.contains(html, "tile-initial") |> should.be_true()
}

pub fn plays_section_tile_with_image_and_url_links_test() {
  let assert Ok(decoded) = atproto.decode_plays(sample_play_body())
  let data =
    stats_with_tile(StatsItem(
      name: "Alpha",
      artist: "Artist A",
      plays: 5,
      ms_played: 0,
      image: "/img/alpha.jpg",
      url: "https://musicbrainz.org/artist/a",
    ))
  let html = plays.plays_section(decoded, data) |> to_string
  string.contains(html, "/img/alpha.jpg") |> should.be_true()
  string.contains(html, "tile-link") |> should.be_true()
  string.contains(html, "https://musicbrainz.org/artist/a") |> should.be_true()
}

pub fn plays_section_hidden_when_no_plays_test() {
  plays.plays_section([], stats.empty_stats()) |> to_string |> should.equal("")
}
