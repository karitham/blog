import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $attribute from "../lustre/lustre/attribute.mjs";
import { class$, href, target } from "../lustre/lustre/attribute.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { none, text } from "../lustre/lustre/element.mjs";
import * as $html from "../lustre/lustre/element/html.mjs";
import { a, div, span } from "../lustre/lustre/element/html.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import { toList, Empty as $Empty } from "./gleam.mjs";
import * as $section from "./section.mjs";

function extract_time(iso) {
  let $ = $string.split(iso, "T");
  if ($ instanceof $Empty) {
    return "";
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      return "";
    } else {
      let $2 = $1.tail;
      if ($2 instanceof $Empty) {
        let rest = $1.head;
        return $string.slice(rest, 0, 5);
      } else {
        return "";
      }
    }
  }
}

function render_play_row(play) {
  let time = extract_time(play.played_time);
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
      span(toList([class$("play-time")]), toList([text(time)])),
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
