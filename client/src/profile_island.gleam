//// Profile island: owns the `#profile-section` mount point.
////
//// Starts from the build-time profile (so the first render matches
//// the server markup), then re-fetches from the PDS on load and on
//// tab visibility. Fresh avatar/banner URLs are pointed at their
//// local mirrors before rendering, so the VDOM never emits remote
//// image URLs.

import atproto
import browser
import gen/actor/defs.{type ProfileViewDetailed}
import gleam/dict.{type Dict}
import gleam/json
import gleam/string
import hydration
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import profile as profile_view

pub type Flags {
  Flags(rewrites: Dict(String, String), profile: ProfileViewDetailed)
}

pub type Model {
  Model(rewrites: Dict(String, String), profile: ProfileViewDetailed)
}

pub type Msg {
  ProfileFetched(Result(ProfileViewDetailed, json.DecodeError))
  VisibilityChanged(Bool)
}

pub fn start(flags: Flags) -> Nil {
  let res =
    lustre.application(init, update, view)
    |> lustre.start("#" <> profile_view.profile_section_id, flags)
  case res {
    Ok(_) -> Nil
    Error(e) ->
      browser.log_error("profile island failed to mount: " <> string.inspect(e))
  }
}

pub fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  #(
    Model(rewrites: flags.rewrites, profile: flags.profile),
    effect.batch([fetch_effect(), visibility_effect()]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    ProfileFetched(Ok(profile)) -> #(
      Model(
        ..model,
        profile: hydration.localize_profile(profile, model.rewrites),
      ),
      effect.none(),
    )
    // A bad payload is logged at the fetch site; the server-rendered
    // profile stays up.
    ProfileFetched(Error(_)) -> #(model, effect.none())
    VisibilityChanged(True) -> #(model, fetch_effect())
    VisibilityChanged(False) -> #(model, effect.none())
  }
}

pub fn view(model: Model) -> Element(Msg) {
  profile_view.profile_inner(model.profile)
}

fn fetch_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    browser.fetch_text(atproto.profile_url(), fn(text) {
      case atproto.decode_profile(text) {
        Ok(profile) -> dispatch(ProfileFetched(Ok(profile)))
        Error(reason) -> {
          browser.log_error("decode_profile failed: " <> string.inspect(reason))
          dispatch(ProfileFetched(Error(reason)))
        }
      }
    })
  })
}

fn visibility_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    browser.on_visibility_change(fn(visible) {
      dispatch(VisibilityChanged(visible))
    })
  })
}
