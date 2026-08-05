//// Build-time mirroring of the profile's avatar/banner blobs.
////
//// The browser re-fetches the profile on page load (client/app.gleam)
//// and would otherwise pull the avatar/banner straight from the PDS on
//// every visit. Instead the SSG downloads them once per build into
//// `dist/img/profile/` and rewrites the profile data to point at the
//// local copies; the remote→local rewrite map is embedded in the page
//// (`#image-rewrites`) so the client can do the same for its fresh
//// render. A failed download keeps the remote URL — the page still
//// works, just with the extra PDS request.
////
//// `fetch_image` and `write_bits` are injected so the mirroring logic
//// is testable with stubs (no network, no real files).

import data/image_ext
import gen/actor/defs.{type ProfileViewDetailed, ProfileViewDetailed}
import gleam/list
import gleam/option.{type Option, None, Some}
import simplifile

pub type FetchImage =
  fn(String) -> Result(#(BitArray, String), String)

pub type WriteBits =
  fn(String, BitArray) -> Result(Nil, simplifile.FileError)

pub type ProfileImages {
  ProfileImages(profile: ProfileViewDetailed, rewrites: List(#(String, String)))
}

const img_dir = "dist/img/profile"

/// Download the avatar/banner blobs (if any) and return a profile whose
/// image fields point at the local copies, plus the rewrite map.
pub fn mirror_profile_images(
  profile: ProfileViewDetailed,
  fetch_image: FetchImage,
  write_bits: WriteBits,
) -> ProfileImages {
  let _ = simplifile.create_directory_all(img_dir)
  let avatar = mirror_one("avatar", profile.avatar, fetch_image, write_bits)
  let banner = mirror_one("banner", profile.banner, fetch_image, write_bits)
  ProfileImages(
    profile: ProfileViewDetailed(
      ..profile,
      avatar: avatar.local_url,
      banner: banner.local_url,
    ),
    rewrites: list.append(avatar.rewrites, banner.rewrites),
  )
}

type MirrorResult {
  MirrorResult(local_url: Option(String), rewrites: List(#(String, String)))
}

fn mirror_one(
  name: String,
  remote: Option(String),
  fetch_image: FetchImage,
  write_bits: WriteBits,
) -> MirrorResult {
  case remote {
    None -> MirrorResult(local_url: None, rewrites: [])
    Some(url) -> {
      let fallback = MirrorResult(local_url: remote, rewrites: [])
      case fetch_image(url) {
        Error(_) -> fallback
        Ok(#(bits, content_type)) -> {
          let filename =
            name <> "." <> image_ext.ext_for_content_type(content_type)
          let path = "/img/profile/" <> filename
          case write_bits(img_dir <> "/" <> filename, bits) {
            Ok(Nil) ->
              MirrorResult(local_url: Some(path), rewrites: [#(url, path)])
            Error(_) -> fallback
          }
        }
      }
    }
  }
}
