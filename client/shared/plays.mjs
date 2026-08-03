import * as $int from "../gleam_stdlib/gleam/int.mjs";
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $calendar from "../gleam_time/gleam/time/calendar.mjs";
import * as $timestamp from "../gleam_time/gleam/time/timestamp.mjs";
import * as $attribute from "../lustre/lustre/attribute.mjs";
import {
  alt,
  attribute,
  checked,
  class$,
  classes,
  for$,
  href,
  id,
  loading,
  name,
  src,
  target,
  type_,
} from "../lustre/lustre/attribute.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { fragment, none, text } from "../lustre/lustre/element.mjs";
import * as $html from "../lustre/lustre/element/html.mjs";
import { a, div, h2, h3, img, input, label, li, ol, span } from "../lustre/lustre/element/html.mjs";
import * as $date from "./date.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import {
  Ok,
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
  prepend as listPrepend,
} from "./gleam.mjs";
import * as $stats from "./stats.mjs";

function plays_label(plays) {
  return $int.to_string(plays) + " plays";
}

function tile(rank, item) {
  return li(
    toList([class$("tile")]),
    toList([
      div(
        toList([class$("tile-cover-wrap")]),
        toList([
          (() => {
            let $ = item.image;
            if ($ === "") {
              return div(
                toList([
                  classes(
                    toList([["tile-cover", true], ["tile-cover--none", true]]),
                  ),
                ]),
                $List$Empty$const,
              );
            } else {
              let url = $;
              return img(
                toList([
                  class$("tile-cover"),
                  src(url),
                  alt(item.name),
                  loading("lazy"),
                ]),
              );
            }
          })(),
          span(
            toList([class$("tile-rank")]),
            toList([text($int.to_string(rank))]),
          ),
        ]),
      ),
      div(
        toList([class$("tile-meta")]),
        toList([
          span(toList([class$("tile-name")]), toList([text(item.name)])),
          (() => {
            let $ = item.artist;
            if ($ === "") {
              return none();
            } else {
              let artist = $;
              return span(
                toList([class$("tile-artist")]),
                toList([text(artist)]),
              );
            }
          })(),
          span(
            toList([class$("tile-plays")]),
            toList([text(plays_label(item.plays))]),
          ),
        ]),
      ),
    ]),
  );
}

function grid(title, items) {
  let $ = $list.is_empty(items);
  if ($) {
    return none();
  } else {
    return div(
      toList([class$("stats-grid")]),
      toList([
        h3($List$Empty$const, toList([text(title)])),
        ol(
          toList([class$("tiles")]),
          $list.index_map(items, (item, i) => { return tile(i + 1, item); }),
        ),
      ]),
    );
  }
}

function range_panel(pair) {
  let range = pair[0];
  let range_stats = pair[1];
  return div(
    toList([
      class$("stats-panel"),
      attribute("data-range", $stats.range_key(range)),
    ]),
    toList([
      grid("artists", range_stats.artists),
      grid("albums", range_stats.albums),
      grid("tracks", range_stats.tracks),
    ]),
  );
}

/**
 * `input + label` pairs, one per range. The first range is checked by
 * default; `input:checked ~ .stats-panel[data-range=...]` in the CSS
 * picks the matching panel.
 * 
 * @ignore
 */
function range_tabs(ranges) {
  let _pipe = ranges;
  let _pipe$1 = $list.index_map(
    _pipe,
    (pair, i) => {
      let range = pair[0];
      let range_id = "stats-" + $stats.range_key(range);
      return toList([
        input(
          toList([
            class$("stats-radio"),
            type_("radio"),
            name("stats-range"),
            id(range_id),
            checked(i === 0),
          ]),
        ),
        label(
          toList([class$("stats-tab"), for$(range_id)]),
          toList([text($stats.range_label(range))]),
        ),
      ]);
    },
  );
  return $list.flatten(_pipe$1);
}

/**
 * The stats tab content: a radio-driven range switcher (CSS-only
 * pills) and one stacked panel per range holding the three 3x3 grids.
 * 
 * @ignore
 */
function stats_view(data) {
  let $ = $stats.is_empty(data);
  if ($) {
    return none();
  } else {
    return fragment(
      $list.append(range_tabs(data.ranges), $list.map(data.ranges, range_panel)),
    );
  }
}

/**
 * Render a play's `played_time` as `HH:MM` in UTC, and return the
 * original ISO string for client-side re-localization.
 * 
 * @ignore
 */
function format_play_time(iso) {
  let $ = $timestamp.parse_rfc3339(iso);
  if ($ instanceof Ok) {
    let ts = $[0];
    let $1 = $timestamp.to_calendar(ts, $calendar.utc_offset);
    let time = $1[1];
    return [($date.pad2(time.hours) + ":") + $date.pad2(time.minutes), iso];
  } else {
    return ["", iso];
  }
}

function render_play_row(play) {
  let $ = format_play_time(play.played_time);
  let time = $[0];
  let iso = $[1];
  let _block;
  let _pipe = play.artists;
  let _pipe$1 = $list.map(_pipe, (a) => { return a.artist_name; });
  _block = $string.join(_pipe$1, ", ");
  let artists_str = _block;
  let origin_url = unwrap(play.origin_url, "");
  let release_name = unwrap(play.release_name, "");
  return div(
    toList([class$("play-row")]),
    toList([
      span(
        toList([class$("play-time"), attribute("data-iso", iso)]),
        toList([text(time)]),
      ),
      span(
        toList([class$("play-track")]),
        toList([
          a(
            toList([href(origin_url), target("_blank")]),
            toList([text(play.track_name)]),
          ),
        ]),
      ),
      span(toList([class$("play-artist")]), toList([text(artists_str)])),
      (() => {
        if (release_name === "") {
          return span(toList([class$("play-release")]), $List$Empty$const);
        } else {
          let name$1 = release_name;
          return span(toList([class$("play-release")]), toList([text(name$1)]));
        }
      })(),
    ]),
  );
}

function rows_container(plays) {
  return div(toList([id("plays-rows")]), $list.map(plays, render_play_row));
}

/**
 * The panels below the header. With stats, the `now playing` view is
 * shown by default; `:has()` selectors in the CSS switch between the
 * two based on the checked radio.
 * 
 * @ignore
 */
function music_panels(plays, data) {
  let $ = $stats.is_empty(data);
  if ($) {
    return toList([rows_container(plays)]);
  } else {
    return toList([
      div(
        toList([class$("music-panel"), attribute("data-view", "now")]),
        toList([rows_container(plays)]),
      ),
      div(
        toList([class$("music-panel"), attribute("data-view", "stats")]),
        toList([stats_view(data)]),
      ),
    ]);
  }
}

/**
 * The `now playing` / `stats` pills for the header line. Hidden
 * entirely when there are no stats to show.
 * 
 * @ignore
 */
function music_tabs(data) {
  let $ = $stats.is_empty(data);
  if ($) {
    return $List$Empty$const;
  } else {
    return toList([
      div(
        toList([class$("music-tabs")]),
        toList([
          input(
            toList([
              class$("music-radio"),
              type_("radio"),
              name("music-view"),
              id("music-now"),
              checked(true),
            ]),
          ),
          label(
            toList([class$("music-tab"), for$("music-now")]),
            toList([text("now playing")]),
          ),
          input(
            toList([
              class$("music-radio"),
              type_("radio"),
              name("music-view"),
              id("music-stats"),
            ]),
          ),
          label(
            toList([class$("music-tab"), for$("music-stats")]),
            toList([text("stats")]),
          ),
        ]),
      ),
    ]);
  }
}

/**
 * The full Music section: title and view tabs on one header line,
 * with the live rows and the top-N grids beneath them. The live
 * rows live in their own `#plays-rows` container so the client's
 * 30s poll only replaces that subtree and the view tabs keep their
 * state. Built manually (not via `section.section`) so the tabs can
 * sit beside the h2 in a `.section-header` row.
 */
export function plays_section(plays, data) {
  if (plays instanceof $Empty) {
    return none();
  } else {
    return div(
      toList([id("plays"), class$("section"), attribute("data-stale", "true")]),
      listPrepend(
        div(
          toList([class$("section-header")]),
          listPrepend(
            h2($List$Empty$const, toList([text("Music")])),
            music_tabs(data),
          ),
        ),
        music_panels(plays, data),
      ),
    );
  }
}

/**
 * Just the live rows container, re-rendered by the client on poll.
 */
export function plays_rows(plays) {
  return rows_container(plays);
}
