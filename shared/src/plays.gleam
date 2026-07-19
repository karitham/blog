import date
import gen/alpha/feed/play.{type AlphaFeedPlay, type ArtistView}
import gleam/list
import gleam/option.{unwrap}
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import lustre/attribute.{attribute, class, href, target}
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
  let #(time, iso) = format_play_time(play.played_time)

  let artists_str =
    play.artists
    |> list.map(fn(a: ArtistView) { a.artist_name })
    |> string.join(", ")

  let origin_url = unwrap(play.origin_url, "")
  let release_name = unwrap(play.release_name, "")

  div([class("play-row")], [
    span(
      [
        class("play-time"),
        attribute("data-iso", iso),
      ],
      [text(time)],
    ),
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

/// Render a play's `played_time` as `HH:MM` in UTC, and return the
/// original ISO string for client-side re-localization.
fn format_play_time(iso: String) -> #(String, String) {
  case timestamp.parse_rfc3339(iso) {
    Ok(ts) -> {
      let #(_, time) = timestamp.to_calendar(ts, calendar.utc_offset)
      #(date.pad2(time.hours) <> ":" <> date.pad2(time.minutes), iso)
    }
    Error(_) -> #("", iso)
  }
}
