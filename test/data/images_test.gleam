import data/images
import gen/actor/defs.{type ProfileViewDetailed, ProfileViewDetailed}
import gleam/option.{type Option, None, Some}
import gleeunit/should
import simplifile

fn profile(
  avatar: Option(String),
  banner: Option(String),
) -> ProfileViewDetailed {
  ProfileViewDetailed(
    did: "did:plc:test",
    handle: "test.bsky.social",
    avatar: avatar,
    banner: banner,
    display_name: None,
    description: None,
    followers_count: None,
    follows_count: None,
    posts_count: None,
    pronouns: None,
  )
}

fn ok_write(
  _path: String,
  _bits: BitArray,
) -> Result(Nil, simplifile.FileError) {
  Ok(Nil)
}

fn failing_write(
  _path: String,
  _bits: BitArray,
) -> Result(Nil, simplifile.FileError) {
  Error(simplifile.Eio)
}

fn good_fetch(url: String) -> Result(#(BitArray, String), String) {
  case url {
    "https://example.com/avatar" -> Ok(#(<<"avatar-bits">>, "image/png"))
    "https://example.com/banner" -> Ok(#(<<"banner-bits">>, "image/webp"))
    _ -> Error("unexpected url: " <> url)
  }
}

pub fn mirror_downloads_and_rewrites_both_images_test() {
  let result =
    images.mirror_profile_images(
      profile(
        Some("https://example.com/avatar"),
        Some("https://example.com/banner"),
      ),
      good_fetch,
      ok_write,
    )
  result.profile.avatar |> should.equal(Some("/img/profile/avatar.png"))
  result.profile.banner |> should.equal(Some("/img/profile/banner.webp"))
  result.rewrites
  |> should.equal([
    #("https://example.com/avatar", "/img/profile/avatar.png"),
    #("https://example.com/banner", "/img/profile/banner.webp"),
  ])
}

pub fn mirror_keeps_remote_url_when_fetch_fails_test() {
  let fetch = fn(_url: String) { Error("network down") }
  let result =
    images.mirror_profile_images(
      profile(Some("https://example.com/avatar"), None),
      fetch,
      ok_write,
    )
  result.profile.avatar |> should.equal(Some("https://example.com/avatar"))
  result.rewrites |> should.equal([])
}

pub fn mirror_keeps_remote_url_when_write_fails_test() {
  let result =
    images.mirror_profile_images(
      profile(Some("https://example.com/avatar"), None),
      good_fetch,
      failing_write,
    )
  result.profile.avatar |> should.equal(Some("https://example.com/avatar"))
  result.rewrites |> should.equal([])
}

pub fn mirror_with_no_images_has_no_rewrites_test() {
  let result =
    images.mirror_profile_images(profile(None, None), good_fetch, ok_write)
  result.profile.avatar |> should.equal(None)
  result.profile.banner |> should.equal(None)
  result.rewrites |> should.equal([])
}
