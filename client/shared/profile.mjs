import * as $int from "../gleam_stdlib/gleam/int.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $attribute from "../lustre/lustre/attribute.mjs";
import { alt, class$, href, id, src, target } from "../lustre/lustre/attribute.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { fragment, none, text } from "../lustre/lustre/element.mjs";
import * as $html from "../lustre/lustre/element/html.mjs";
import { a, div, h1, img, p, span, strong } from "../lustre/lustre/element/html.mjs";
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
    _block = a(
      toList([href(bsky_url), target("_blank")]),
      toList([img(toList([class$("avatar"), src(url), alt("avatar")]))]),
    );
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
  let display_name = unwrap(profile.display_name, profile.handle);
  let description = unwrap(profile.description, "");
  let followers = unwrap(profile.followers_count, 0);
  let follows = unwrap(profile.follows_count, 0);
  let posts = unwrap(profile.posts_count, 0);
  return div(
    toList([id("profile-section")]),
    toList([
      fragment(
        toList([
          banner,
          div(
            toList([id("profile")]),
            toList([
              avatar,
              h1(
                toList([]),
                toList([
                  a(
                    toList([
                      href(bsky_url),
                      target("_blank"),
                      class$("profile-name"),
                    ]),
                    toList([text(display_name)]),
                  ),
                ]),
              ),
              p(
                toList([class$("handle")]),
                toList([
                  a(
                    toList([href(bsky_url), target("_blank")]),
                    toList([text("@" + profile.handle)]),
                  ),
                ]),
              ),
              p(toList([class$("description")]), toList([text(description)])),
              div(
                toList([class$("profile-stats")]),
                toList([
                  span(
                    toList([]),
                    toList([
                      strong(
                        toList([]),
                        toList([text($int.to_string(followers))]),
                      ),
                      text(" followers"),
                    ]),
                  ),
                  span(
                    toList([]),
                    toList([
                      strong(
                        toList([]),
                        toList([text($int.to_string(follows))]),
                      ),
                      text(" following"),
                    ]),
                  ),
                  span(
                    toList([]),
                    toList([
                      strong(toList([]), toList([text($int.to_string(posts))])),
                      text(" posts"),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]),
  );
}
