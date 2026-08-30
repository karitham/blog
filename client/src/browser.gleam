//// Browser FFI for the client islands. Deliberately tiny: the VDOM
//// owns the DOM now, so the only operations are fetching data,
//// reading embedded JSON, timers, visibility, and one post-paint pass
//// (date localization) scoped to an island's own root.

import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

@external(javascript, "./browser_ffi.mjs", "fetch_text")
pub fn fetch_text(url: String, callback: fn(String) -> Nil) -> Nil

/// The text content of the SSG-embedded `<script>` tag by id (the
/// hydration payload). `None` means the tag itself is missing — the
/// SSG always renders it, so that is markup drift. `Some("")` is a
/// page without a hydration payload.
@external(javascript, "./browser_ffi.mjs", "script_text")
pub fn script_text(id: String) -> Option(String)

@external(javascript, "./browser_ffi.mjs", "has_element")
pub fn has_element(id: String) -> Bool

@external(javascript, "./browser_ffi.mjs", "log_error")
pub fn log_error(message: String) -> Nil

/// Recurring tick for the plays poll. Never cancelled — the page
/// lifecycle owns it.
@external(javascript, "./browser_ffi.mjs", "set_interval")
pub fn set_interval(ms: Int, callback: fn() -> Nil) -> Nil

@external(javascript, "./browser_ffi.mjs", "is_visible")
pub fn is_visible() -> Bool

@external(javascript, "./browser_ffi.mjs", "on_visibility_change")
pub fn on_visibility_change(callback: fn(Bool) -> Nil) -> Nil

/// Re-localize every `[data-iso]` play-time element under `root` from
/// its build-time UTC rendering into the visitor's timezone. Called
/// from `effect.after_paint`, which passes the island's root element.
@external(javascript, "./browser_ffi.mjs", "localize_dates_in")
pub fn localize_dates_in(root: Dynamic) -> Nil
