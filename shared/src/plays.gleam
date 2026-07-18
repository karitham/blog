import gen/alpha/feed/play.{type AlphaFeedPlay, type ArtistView}
import gleam/list
import gleam/option.{unwrap}
import gleam/string
import lustre/attribute.{class, href, target}
import lustre/element.{type Element, none, text}
import lustre/element/html.{a, div, span}
import section

pub fn plays_section(plays: List(AlphaFeedPlay)) -> Element(msg) {
  case plays {
    [] -> none()
    _ ->
      section.section(
        "Now Playing",
        "plays",
        True,
        list.map(plays, render_play_row),
      )
  }
}

fn render_play_row(play: AlphaFeedPlay) -> Element(msg) {
  let time = extract_time(play.played_time)

  let artists_str =
    play.artists
    |> list.map(fn(a: ArtistView) { a.artist_name })
    |> string.join(", ")

  let origin_url = unwrap(play.origin_url, "")
  let release_name = unwrap(play.release_name, "")

  div([class("play-row")], [
    span([class("play-time")], [text(time)]),
    span(
      [
        class("play-track"),
      ],
      [
        a(
          [
            href(origin_url),
            target("_blank"),
          ],
          [text(play.track_name)],
        ),
      ],
    ),
    span([class("play-artist")], [text(artists_str)]),
    case release_name {
      "" -> span([class("play-release")], [])
      name -> span([class("play-release")], [text(name)])
    },
  ])
}

fn extract_time(iso: String) -> String {
  // "2026-07-18T15:33:46Z" → "15:33"
  case string.split(iso, "T") {
    [_, rest] -> string.slice(rest, 0, 5)
    _ -> ""
  }
}
