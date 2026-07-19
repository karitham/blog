import gen/actor/defs.{type ProfileViewDetailed}
import gleam/option.{None, Some, unwrap}
import lustre/attribute.{alt, class, href, id, src, target}
import lustre/element.{type Element, fragment, none, text}
import lustre/element/html.{a, div, h1, img, p, span}

pub fn profile(profile: ProfileViewDetailed) -> Element(msg) {
  let bsky_url = "https://bsky.app/profile/" <> profile.handle

  let avatar = case unwrap(profile.avatar, "") {
    "" -> none()
    url -> img([class("avatar"), src(url), alt("avatar")])
  }

  let banner = case unwrap(profile.banner, "") {
    "" -> none()
    url ->
      div([id("banner")], [
        img([src(url), alt("banner")]),
      ])
  }

  let pronouns_el = case profile.pronouns {
    Some(pronouns) -> span([class("pronouns")], [text("(" <> pronouns <> ")")])
    None -> none()
  }

  div([id("profile-section")], [
    fragment([
      banner,
      div([id("profile")], [
        div([class("profile-header")], [
          avatar,
          div([class("profile-info")], [
            h1([class("profile-name")], [
              text(unwrap(profile.display_name, profile.handle)),
            ]),
            p([class("handle")], [
              a([href(bsky_url), target("_blank")], [
                text("@" <> profile.handle),
              ]),
              pronouns_el,
            ]),
          ]),
        ]),
        p([class("description")], [text(unwrap(profile.description, ""))]),
      ]),
    ]),
  ])
}
