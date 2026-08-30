//// Client entry: decode the hydration payload and start the islands.
////
//// The SSG embeds the build-time data as `#site-model`; each island
//// takes its slice as flags so its first render matches the server
//// markup, then re-fetches fresh data through its own effects. Pages
//// without dynamic sections (articles) start nothing.

import browser
import decode
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import plays as plays_view
import plays_island
import profile as profile_view
import profile_island
import repos as repos_view
import repos_island

const site_model_id = "site-model"

pub fn start() -> Nil {
  case browser.has_element(profile_view.profile_section_id) {
    // Article pages have no dynamic sections — nothing to hydrate.
    False -> Nil
    True ->
      case browser.script_text(site_model_id) {
        // The SSG always renders #site-model next to the sections it
        // feeds; its absence means the markup drifted from here.
        None ->
          browser.log_error(
            "missing #" <> site_model_id <> " — islands not started",
          )
        // No payload on this page; nothing to hydrate.
        Some("") -> Nil
        Some(payload) ->
          case decode.decode_hydration_model(payload) {
            Error(reason) ->
              browser.log_error(
                "hydration model decode failed: " <> string.inspect(reason),
              )
            Ok(model) -> {
              profile_island.start(profile_island.Flags(
                rewrites: model.rewrites,
                profile: model.profile,
              ))
              case browser.has_element(plays_view.plays_rows_id) {
                True ->
                  plays_island.start(plays_island.Flags(plays: model.plays))
                False -> Nil
              }
              case browser.has_element(repos_view.repos_section_id) {
                True ->
                  repos_island.start(
                    repos_island.Flags(
                      repos: list.map(model.repos, fn(record) { record.value }),
                    ),
                  )
                False -> Nil
              }
            }
          }
      }
  }
}
