import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { None, Some } from "../gleam_stdlib/gleam/option.mjs";
import * as $attribute from "../lustre/lustre/attribute.mjs";
import { class$, href, target } from "../lustre/lustre/attribute.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { none, text } from "../lustre/lustre/element.mjs";
import * as $html from "../lustre/lustre/element/html.mjs";
import { a, div, span } from "../lustre/lustre/element/html.mjs";
import { toList, Empty as $Empty } from "./gleam.mjs";

/**
 * Build a card with a titled link, a date, an optional description,
 * and optional topic tags. `title_target` lets the caller choose
 * whether the link opens in a new tab (`Some("_blank")`) or in the
 * current tab (`None`).
 */
export function card(url, title, title_target, date, description, topics) {
  let _block;
  if (title_target instanceof Some) {
    let t = title_target[0];
    _block = toList([href(url), target(t), class$("card-title")]);
  } else {
    _block = toList([href(url), class$("card-title")]);
  }
  let title_attrs = _block;
  let _block$1;
  if (description === "") {
    _block$1 = none();
  } else {
    let d = description;
    _block$1 = div(toList([class$("card-desc")]), toList([text(d)]));
  }
  let desc = _block$1;
  let _block$2;
  if (topics instanceof $Empty) {
    _block$2 = none();
  } else {
    let ts = topics;
    _block$2 = div(
      toList([class$("card-tags")]),
      $list.map(
        ts,
        (t) => { return span(toList([class$("card-tag")]), toList([text(t)])); },
      ),
    );
  }
  let topic_tags = _block$2;
  return div(
    toList([class$("card")]),
    toList([
      div(
        toList([class$("card-head")]),
        toList([
          a(title_attrs, toList([text(title)])),
          span(toList([class$("card-date")]), toList([text(date)])),
        ]),
      ),
      desc,
      topic_tags,
    ]),
  );
}
