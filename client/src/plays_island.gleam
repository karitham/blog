//// Plays island: owns the `#plays-rows` mount point.
////
//// Polls the PDS every 30s while the tab is visible. The poll
//// interval is registered once in `init` and dispatches `PollTick`
//// forever; each tick re-flags the section stale and fetches. The
//// CSS-only view tabs live outside this mount point, so re-renders
//// never reset them.
////
//// Failure semantics: an empty or undecodable response keeps the
//// current rows and only clears the stale flag; a network failure is
//// logged by the FFI and dispatches nothing, so the stale pulse
//// persists until the next tick succeeds.

import atproto
import browser
import gen/feed/play.{type FeedPlay}
import gleam/int
import gleam/json
import gleam/string
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import plays as plays_view

/// Short enough that a new track shows up promptly, long enough that
/// we're not hammering the PDS.
const poll_ms = 30_000

pub type Flags {
  Flags(plays: List(FeedPlay))
}

pub type Model {
  Model(plays: List(FeedPlay), stale: Bool)
}

pub type Msg {
  PlaysFetched(Result(List(FeedPlay), json.DecodeError))
  PollTick
  VisibilityChanged(Bool)
}

pub fn start(flags: Flags) -> Nil {
  let res =
    lustre.application(init, update, view)
    |> lustre.start("#" <> plays_view.plays_rows_id, flags)
  case res {
    Ok(_) -> Nil
    Error(e) ->
      browser.log_error("plays island failed to mount: " <> string.inspect(e))
  }
}

pub fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  #(
    Model(plays: flags.plays, stale: True),
    effect.batch([
      poll_effect(),
      visibility_effect(),
      fetch_effect(),
      localize_effect(),
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    PollTick ->
      // The poll effect only dispatches while the tab is visible.
      #(Model(..model, stale: True), fetch_effect())
    PlaysFetched(Ok([])) ->
      // No new plays: keep the rows, just stop the stale pulse.
      #(Model(..model, stale: False), localize_effect())
    PlaysFetched(Ok(plays)) -> #(
      Model(plays: plays, stale: False),
      localize_effect(),
    )
    // Undecodable payload (logged at the fetch site): keep the rows.
    PlaysFetched(Error(_)) -> #(Model(..model, stale: False), effect.none())
    VisibilityChanged(True) -> #(Model(..model, stale: True), fetch_effect())
    VisibilityChanged(False) -> #(model, effect.none())
  }
}

pub fn view(model: Model) -> Element(Msg) {
  plays_view.plays_rows(model.plays, model.stale)
}

/// The tick checks visibility itself (in the effect, keeping `update`
/// pure); an obscured tab fetches nothing until it's looked at again.
fn poll_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    browser.set_interval(poll_ms, fn() {
      case browser.is_visible() {
        True -> dispatch(PollTick)
        False -> Nil
      }
    })
  })
}

fn fetch_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    browser.fetch_text(atproto.plays_url(), fn(text) {
      case atproto.decode_plays(text) {
        Ok(#(plays, drops)) -> {
          case drops > 0 {
            True ->
              browser.log_error(
                "decode_plays: dropped "
                <> int.to_string(drops)
                <> " undecodable play record(s)",
              )
            False -> Nil
          }
          dispatch(PlaysFetched(Ok(plays)))
        }
        Error(reason) -> {
          browser.log_error("decode_plays failed: " <> string.inspect(reason))
          dispatch(PlaysFetched(Error(reason)))
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

/// Re-localize the freshly rendered rows' play times to the visitor's
/// timezone, after paint so the DOM exists.
fn localize_effect() -> Effect(Msg) {
  effect.after_paint(fn(_dispatch, root) { browser.localize_dates_in(root) })
}
