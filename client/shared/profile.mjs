import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { None, Some, unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $attribute from "../lustre/lustre/attribute.mjs";
import { alt, class$, href, id, src, target } from "../lustre/lustre/attribute.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { fragment, none, text } from "../lustre/lustre/element.mjs";
import * as $html from "../lustre/lustre/element/html.mjs";
import { a, div, h1, img, p, span } from "../lustre/lustre/element/html.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import { toList } from "./gleam.mjs";

export function profile(profile) {
  let bsky_url = "https://bsky.app/profile/" + profile.handle;
  let _block;
  let $ = unwrap(profile.avatar, "");
  if ($ === "") {
    _block = none();
  } else {
    let url = $;
    _block = img(toList([class$("avatar"), src(url), alt("avatar")]));
  }
  let avatar = _block;
  let _block$1;
  let $1 = unwrap(profile.banner, "");
  if ($1 === "") {
    _block$1 = none();
  } else {
    let url = $1;
    _block$1 = div(
      toList([id("banner")]),
      toList([img(toList([src(url), alt("banner")]))]),
    );
  }
  let banner = _block$1;
  let _block$2;
  let $2 = profile.pronouns;
  if ($2 instanceof Some) {
    let pronouns = $2[0];
    _block$2 = span(
      toList([class$("pronouns")]),
      toList([text(("(" + pronouns) + ")")]),
    );
  } else {
    _block$2 = none();
  }
  let pronouns_el = _block$2;
  return div(
    toList([id("profile-section")]),
    toList([
      fragment(
        toList([
          banner,
          div(
            toList([id("profile")]),
            toList([
              div(
                toList([class$("profile-header")]),
                toList([
                  avatar,
                  div(
                    toList([class$("profile-info")]),
                    toList([
                      h1(
                        toList([class$("profile-name")]),
                        toList([
                          text(unwrap(profile.display_name, profile.handle)),
                        ]),
                      ),
                      p(
                        toList([class$("handle")]),
                        toList([
                          a(
                            toList([href(bsky_url), target("_blank")]),
                            toList([text("@" + profile.handle)]),
                          ),
                          pronouns_el,
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              p(
                toList([class$("description")]),
                toList([text(unwrap(profile.description, ""))]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  );
}
