import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $calendar from "../gleam_time/gleam/time/calendar.mjs";
import * as $timestamp from "../gleam_time/gleam/time/timestamp.mjs";
import * as $attribute from "../lustre/lustre/attribute.mjs";
import { attribute, class$, href, target } from "../lustre/lustre/attribute.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { none, text } from "../lustre/lustre/element.mjs";
import * as $html from "../lustre/lustre/element/html.mjs";
import { a, div, span } from "../lustre/lustre/element/html.mjs";
import * as $date from "./date.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import { Ok, toList, Empty as $Empty } from "./gleam.mjs";
import * as $section from "./section.mjs";

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
          return span(toList([class$("play-release")]), toList([]));
        } else {
          let name = release_name;
          return span(toList([class$("play-release")]), toList([text(name)]));
        }
      })(),
    ]),
  );
}

export function plays_section(plays) {
  if (plays instanceof $Empty) {
    return none();
  } else {
    return $section.section(
      "Now Playing",
      "plays",
      true,
      $list.map(plays, render_play_row),
    );
  }
}
