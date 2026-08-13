import date
import gen/feed/play.{type ArtistView, type FeedPlay}
import gleam/int
import gleam/list
import gleam/option.{unwrap}
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

/// The full Music section: title and view tabs on one header line,
/// with the live rows and the top-N grids beneath them. The live
/// rows live in their own `#plays-rows` container so the client's
/// 30s poll only replaces that subtree and the view tabs keep their
/// state. Built manually (not via `section.section`) so the tabs can
/// sit beside the h2 in a `.section-header` row.
pub fn plays_section(plays: List(FeedPlay), data: StatsData) -> Element(msg) {
  case plays {
    [] -> none()
    _ ->
      div(
        [
          id("plays"),
          class("section"),
          attribute("data-stale", "true"),
        ],
        [
          div([class("section-header")], [
            h2([], [text("Music")]),
            ..music_tabs(data)
          ]),
          ..music_panels(plays, data)
        ],
      )
  }
}

/// Just the live rows container, re-rendered by the client on poll.
pub fn plays_rows(plays: List(FeedPlay)) -> Element(msg) {
  rows_container(plays)
}

/// The `now playing` / `stats` pills for the header line. Hidden
/// entirely when there are no stats to show.
fn music_tabs(data: StatsData) -> List(Element(msg)) {
  case stats.is_empty(data) {
    True -> []
    False -> [
      div([class("music-tabs")], [
        input([
          class("music-radio"),
          type_("radio"),
          name("music-view"),
          id("music-now"),
          checked(True),
        ]),
        label([class("music-tab"), for("music-now")], [text("now playing")]),
        input([
          class("music-radio"),
          type_("radio"),
          name("music-view"),
          id("music-stats"),
        ]),
        label([class("music-tab"), for("music-stats")], [text("stats")]),
      ]),
    ]
  }
}

/// The panels below the header. With stats, the `now playing` view is
/// shown by default; `:has()` selectors in the CSS switch between the
/// two based on the checked radio.
fn music_panels(plays: List(FeedPlay), data: StatsData) -> List(Element(msg)) {
  case stats.is_empty(data) {
    True -> [rows_container(plays)]
    False -> [
      div([class("music-panel"), attribute("data-view", "now")], [
        rows_container(plays),
      ]),
      div([class("music-panel"), attribute("data-view", "stats")], [
        stats_view(data),
      ]),
    ]
  }
}

fn rows_container(plays: List(FeedPlay)) -> Element(msg) {
  div([id("plays-rows")], list.map(plays, render_play_row))
}

fn render_play_row(play: FeedPlay) -> Element(msg) {
  let #(time, iso) = format_play_time(play.played_time)

  let artists_str =
    play.artists
    |> list.map(fn(a: ArtistView) { a.artist_name })
    |> string.join(", ")

  let origin_url = unwrap(play.origin_uri, "")
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

/// The stats tab content: a radio-driven range switcher (CSS-only
/// pills) and one stacked panel per range holding the three 3x3 grids.
fn stats_view(data: StatsData) -> Element(msg) {
  case stats.is_empty(data) {
    True -> none()
    False ->
      fragment(list.append(
        range_tabs(data.ranges),
        list.map(data.ranges, range_panel),
      ))
  }
}

/// `input + label` pairs, one per range. The first range is checked by
/// default; `input:checked ~ .stats-panel[data-range=...]` in the CSS
/// picks the matching panel.
fn range_tabs(ranges: List(#(Range, RangeStats))) -> List(Element(msg)) {
  ranges
  |> list.index_map(fn(pair, i) {
    let #(range, _) = pair
    let range_id = "stats-" <> stats.range_key(range)
    [
      input([
        class("stats-radio"),
        type_("radio"),
        name("stats-range"),
        id(range_id),
        checked(i == 0),
      ]),
      label([class("stats-tab"), for(range_id)], [
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
        ol([class("tiles")], list.map(items, fn(item) { tile(item, title) })),
      ])
  }
}

/// A pure-image tile: the cover (or a flat placeholder with the item's
/// initial when there is none), with the name/artist/plays in a hover
/// popup. Links to the entity's MusicBrainz page when one resolved;
/// otherwise it's a plain tile. No rank badge — a proper 3x3 mosaic.
fn tile(item: StatsItem, category: String) -> Element(msg) {
  let cover = case item.image {
    "" ->
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
    url ->
      img([
        class("tile-cover"),
        src(url),
        alt(""),
        loading("lazy"),
      ])
  }
  let popup =
    div([class("tile-tooltip")], [
      span([class("tile-name")], [text(item.name)]),
      case item.artist {
        "" -> none()
        artist -> span([class("tile-artist")], [text(artist)])
      },
      span([class("tile-plays")], [text(plays_label(item.plays))]),
    ])
  let tile_body = [div([class("tile-cover-wrap")], [cover]), popup]
  case item.url {
    "" -> li([class("tile")], tile_body)
    url ->
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
    "" -> ""
    artist -> " — " <> artist
  }
  item.name <> artist_part <> ", " <> plays_label(item.plays)
}

fn plays_label(plays: Int) -> String {
  int.to_string(plays) <> " plays"
}
