import { Some, None } from "../gleam_stdlib/gleam/option.mjs";

export function fetch_text(url, callback) {
  return fetch(url)
    .then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status + ": " + url);
      return r.text();
    })
    .then(function (text) {
      callback(text);
    })
    .catch(function (err) {
      console.error("fetch_text failed:", url, err);
    });
}

// The text content of the SSG-embedded `<script>` tag by id.
// `None` means the tag itself is missing (markup drift — the SSG
// always renders it); `Some("")` is a page without a payload.
export function script_text(id) {
  var el = document.getElementById(id);
  return el ? new Some(el.textContent) : new None();
}

export function has_element(id) {
  return document.getElementById(id) !== null;
}

export function log_error(message) {
  console.error(message);
}

// Browser setInterval — we never cancel this, the page lifecycle owns it.
// Returns the handle but the Gleam side ignores it.
export function set_interval(ms, callback) {
  setInterval(callback, ms);
}

export function is_visible() {
  return !document.hidden;
}

export function on_visibility_change(callback) {
  document.addEventListener("visibilitychange", function () {
    callback(!document.hidden);
  });
}

// Re-localize every `[data-iso]` play-time element under `root` from its
// build-time UTC rendering into the visitor's local timezone. The element
// already shows correct UTC text; we only swap the text content to local
// HH:MM. Scoped to `root` (an island's mount element) instead of the
// whole document.
export function localize_dates_in(root) {
  var els = root.querySelectorAll("[data-iso]");
  for (var i = 0; i < els.length; i++) {
    var el = els[i];
    var iso = el.getAttribute("data-iso");
    if (!iso) continue;
    try {
      var d = new Date(iso);
      if (isNaN(d.getTime())) continue;
      var h = d.getHours();
      var m = d.getMinutes();
      el.textContent = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    } catch (_) {
      // Keep the build-time UTC text on any failure.
    }
  }
}
