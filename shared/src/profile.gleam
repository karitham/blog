import gen/actor/defs.{type ProfileViewDetailed}
import gleam/option.{None, Some, unwrap}
import lustre/attribute.{alt, class, href, id, src, target}
import lustre/element.{type Element, fragment, none, text}
import lustre/element/html.{a, div, h1, img, p, span}

/// The mount point the client's profile island attaches to. Kept here
/// so the SSG markup and the client selector can't drift apart.
pub const profile_section_id = "profile-section"

/// The full profile section: the outer `#profile-section` container
/// with the banner and profile card inside. Used by the SSG.
pub fn profile(profile: ProfileViewDetailed) -> Element(msg) {
  div([id(profile_section_id)], [profile_inner(profile)])
}

/// The profile card without the outer `#profile-section` container.
/// The client's profile island mounts on the server-rendered
/// container and re-renders exactly this, so the first client render
/// diff matches the server markup.
pub fn profile_inner(profile: ProfileViewDetailed) -> Element(msg) {
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
  ])
}
