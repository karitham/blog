import * as $attribute from "../lustre/lustre/attribute.mjs";
import { attribute, class$, id } from "../lustre/lustre/attribute.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { text } from "../lustre/lustre/element.mjs";
import * as $html from "../lustre/lustre/element/html.mjs";
import { div, h2 } from "../lustre/lustre/element/html.mjs";
import { toList, prepend as listPrepend } from "./gleam.mjs";

/**
 * Wrap a titled list of items in the section frame used by plays/repos.
 *
 * When `stale` is `True` the section root gets `data-stale="true"`. The
 * client toggles this off once its fetch resolves, and back on for the
 * next poll cycle. The CSS in `priv/static/style.css` keys off
 * `.section[data-stale="true"]` to render a pulsing dot in the header.
 */
export function section(title, id_str, stale, items) {
  let _block;
  if (stale) {
    _block = toList([
      id(id_str),
      class$("section"),
      attribute("data-stale", "true"),
    ]);
  } else {
    _block = toList([id(id_str), class$("section")]);
  }
  let attrs = _block;
  return div(attrs, listPrepend(h2(toList([]), toList([text(title)])), items));
}
