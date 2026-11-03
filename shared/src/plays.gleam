//// Shared music views: live play rows and top-N stat grids.
//// Pure lustre elements — used by SSG (`render/page`) and client islands.

import date
import gen/feed/play.{type ArtistView, type FeedPlay}
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import lustre/attribute.{
  alt, attribute, checked, class, classes, for, href, id, loading, name, src,
  target, type_,
}
import lustre/element.{type Element, fragment, none, text}
import lustre/element/html.{a, div, h2, h3, img, input, label, li, ol, span}
import stats.{type Range, type RangeStats, type StatsData, type StatsItem}

/// The full Music section: a quiet title, one tab row where "recent"
/// sits beside the chart ranges, then the content. The live rows live
/// in their own `#plays-rows` container so the client's 30s poll only
/// replaces that subtree and the tabs keep their state.
pub fn plays_section(plays: List(FeedPlay), data: StatsData) -> Element(msg) {
  case plays {
    [] -> none()
    _ ->
      div(
        [
          id("plays"),
          class("section"),
        ],
        [
          div([class("section-header")], [h2([], [text("Music")])]),
          music_toolbar(data),
          ..music_panels(plays, data)
        ],
      )
  }
}

/// The mount point the client's plays island attaches to: the live
/// rows container inside the Music section. Kept here so the SSG
/// markup and the client selector can't drift apart.
pub const plays_rows_id = "plays-rows"

/// The rows subtree inside `#plays-rows`: a wrapper carrying
/// `data-stale` (the CSS pulse dot keys off any `[data-stale="true"]`
/// inside the section via `:has()`) and one row per play. Rendered by
/// the SSG at build time (`stale: True`) and by the client's plays
/// island on every poll.
pub fn plays_rows(plays: List(FeedPlay), stale: Bool) -> Element(msg) {
  let stale_attr = case stale {
    True -> [attribute("data-stale", "true")]
    False -> []
  }
  div(
    [class("plays-rows-inner"), ..stale_attr],
    list.map(plays, render_play_row),
  )
}

/// One tab row: "recent" plus one tab per chart range. No nested
/// view/filter controls — picking a range is picking its chart.
fn music_toolbar(data: StatsData) -> Element(msg) {
  case stats.is_empty(data) {
    True -> none()
    False -> div([class("music-toolbar")], [tabs(data)])
  }
}

fn tabs(data: StatsData) -> Element(msg) {
  div([class("music-tabs")], [
    input([
      class("music-radio"),
      type_("radio"),
      name("music-view"),
      id("music-recent"),
      checked(True),
    ]),
    label([class("music-tab"), for("music-recent")], [text("recent")]),
    span([class("music-sep"), attribute("aria-hidden", "true")], [text("/")]),
    ..range_tabs(data.ranges)
  ])
}

/// The panels below the controls. With stats, the recent view is shown
/// by default; `:has()` selectors in the CSS switch between the two
/// based on the checked radio.
fn music_panels(plays: List(FeedPlay), data: StatsData) -> List(Element(msg)) {
  case stats.is_empty(data) {
    True -> [rows_container(plays)]
    False -> [
      div([class("music-panel"), attribute("data-view", "recent")], [
        rows_container(plays),
      ]),
      div([class("music-panel"), attribute("data-view", "stats")], [
        stats_view(data),
      ]),
    ]
  }
}

fn rows_container(plays: List(FeedPlay)) -> Element(msg) {
  div([id(plays_rows_id)], [plays_rows(plays, True)])
}

fn render_play_row(play: FeedPlay) -> Element(msg) {
  let #(time, iso) = format_play_time(play.played_time)

  let artists_str =
    play.artists
    |> list.map(fn(a: ArtistView) { a.artist_name })
    |> string.join(", ")

  let origin_uri = option.unwrap(play.origin_uri, "")
  let release_name = option.unwrap(play.release_name, "")

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
            href(origin_uri),
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
pub fn format_play_time(iso: String) -> #(String, String) {
  case timestamp.parse_rfc3339(iso) {
    Ok(ts) -> {
      let #(_, time) = timestamp.to_calendar(ts, calendar.utc_offset)
      #(date.pad2(time.hours) <> ":" <> date.pad2(time.minutes), iso)
    }
    Error(_) -> #("", iso)
  }
}

// ---------------------------------------------------------------- stats view

/// The charts content: one stacked panel per range, each holding the
/// three top-N grids. The range switcher lives in the control bar.
fn stats_view(data: StatsData) -> Element(msg) {
  case stats.is_empty(data) {
    True -> none()
    False -> fragment(list.map(data.ranges, range_panel))
  }
}

/// One radio/label pair per range, appended to the primary tab row.
/// All radios share the `music-view` name, so a range selection
/// replaces the recent selection and `:has()` picks the panel.
fn range_tabs(ranges: List(#(Range, RangeStats))) -> List(Element(msg)) {
  ranges
  |> list.map(fn(pair) {
    let #(range, _) = pair
    let range_id = "stats-" <> stats.range_key(range)
    [
      input([
        class("music-radio"),
        type_("radio"),
        name("music-view"),
        id(range_id),
      ]),
      label([class("music-tab"), for(range_id)], [
        text(stats.range_label(range)),
      ]),
    ]
  })
  |> list.flatten
}

fn range_panel(pair: #(Range, RangeStats)) -> Element(msg) {
  let #(range, range_stats) = pair
  div(
    [
      class("stats-panel"),
      attribute("data-range", stats.range_key(range)),
    ],
    [
      grid("artists", range_stats.artists),
      grid("albums", range_stats.albums),
      grid("tracks", range_stats.tracks),
    ],
  )
}

fn grid(title: String, items: List(StatsItem)) -> Element(msg) {
  case list.is_empty(items) {
    True -> none()
    False ->
      div([class("stats-grid")], [
        h3([], [text(title)]),
        ol(
          [class("tiles")],
          list.index_map(items, fn(item, i) { tile(item, title, i + 1) }),
        ),
      ])
  }
}

/// A chart row: rank, cover (or a monogram placeholder), then name,
/// artist, and plays/listened time. Metadata is visible at rest rather
/// than hidden in a hover popup, so touch devices and keyboard users
/// get the same labels. Links to the entity's MusicBrainz page when one
/// resolved; otherwise it's a plain row.
fn tile(item: StatsItem, category: String, rank: Int) -> Element(msg) {
  let cover = case item.image {
    option.None ->
      div(
        [
          classes([
            #("tile-cover", True),
            #("tile-cover--none", True),
            #("tile-cover--" <> category, True),
          ]),
        ],
        [span([class("tile-initial")], [text(initial(item.name))])],
      )
    option.Some(url) ->
      img([
        class("tile-cover"),
        src(url),
        alt(""),
        loading("lazy"),
      ])
  }
  let tile_body = [
    span([class("tile-rank")], [text(date.pad2(rank))]),
    div([class("tile-cover-wrap")], [cover]),
    div([class("tile-text")], [
      span([class("tile-name")], [text(item.name)]),
      case item.artist {
        option.None -> none()
        option.Some(artist) -> span([class("tile-artist")], [text(artist)])
      },
      span([class("tile-plays")], [text(plays_label(item))]),
    ]),
  ]
  case item.url {
    option.None -> li([class("tile")], [div([class("tile-body")], tile_body)])
    option.Some(url) ->
      li([class("tile")], [
        a(
          [
            class("tile-link"),
            href(url),
            target("_blank"),
            attribute("rel", "noopener"),
            attribute("aria-label", tile_label(item)),
          ],
          tile_body,
        ),
      ])
  }
}

/// Monogram for image-less tiles: the item's first grapheme, upper-cased.
fn initial(name: String) -> String {
  case string.first(name) {
    Ok(first) -> string.uppercase(first)
    Error(_) -> ""
  }
}

fn tile_label(item: StatsItem) -> String {
  let artist_part = case item.artist {
    option.None -> ""
    option.Some(artist) -> " — " <> artist
  }
  item.name <> artist_part <> ", " <> plays_label(item)
}

/// "27 plays" or "27 plays · 1h 21m" when the play records carry a
/// duration. Alpha used milliseconds; current records use seconds, but
/// the Rust boundary normalizes both to milliseconds before this view.
fn plays_label(item: StatsItem) -> String {
  case item.listened_ms {
    option.Some(ms) if ms > 0 ->
      int.to_string(item.plays) <> " plays · " <> listened_label(ms)
    _ -> int.to_string(item.plays) <> " plays"
  }
}

fn listened_label(ms: Int) -> String {
  let minutes = ms / 60_000
  case minutes {
    0 -> "<1m"
    _ -> {
      let hours = minutes / 60
      let rest = minutes % 60
      case hours {
        0 -> int.to_string(minutes) <> "m"
        _ ->
          case rest {
            0 -> int.to_string(hours) <> "h"
            _ -> int.to_string(hours) <> "h " <> int.to_string(rest) <> "m"
          }
      }
    }
  }
}
