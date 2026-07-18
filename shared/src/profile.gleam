import gen/actor/defs.{type ProfileViewDetailed}
import gleam/option.{unwrap}
import lustre/attribute.{alt, class, href, id, src, target}
import lustre/element.{type Element, fragment, none, text}
import lustre/element/html.{a, div, h1, img, p}

pub fn profile(profile: ProfileViewDetailed) -> Element(msg) {
  let bsky_url = "https://bsky.app/profile/" <> profile.handle

  let avatar = case unwrap(profile.avatar, "") {
    "" -> none()
    url ->
      a([href(bsky_url), target("_blank")], [
        img([class("avatar"), src(url), alt("avatar")]),
      ])
  }

  let banner = case unwrap(profile.banner, "") {
    "" -> none()
    url ->
      div([id("banner")], [
        img([src(url), alt("banner")]),
      ])
  }

  div([id("profile-section")], [
    fragment([
      banner,
      div([id("profile")], [
        avatar,
        h1([], [
          a([href(bsky_url), target("_blank"), class("profile-name")], [
            text(unwrap(profile.display_name, profile.handle)),
          ]),
        ]),
        p([class("handle")], [
          a([href(bsky_url), target("_blank")], [
            text("@" <> profile.handle),
          ]),
        ]),
        p([class("description")], [text(unwrap(profile.description, ""))]),
      ]),
    ]),
  ])
}
