import { Ok, Error } from "./gleam.mjs";

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

export function set_inner_html(id, html) {
  var el = document.getElementById(id);
  if (el) {
    el.innerHTML = html;
    console.log("updated #" + id);
  } else {
    console.warn("set_inner_html: element #" + id + " not found");
  }
}

// Point every <img src> in the document at its local mirror. The map
// is the `#image-rewrites` JSON script tag the SSG embeds (remote URL
// -> local /img path); URLs not in the map (e.g. a freshly-changed
// avatar the build hasn't mirrored yet) keep their remote src and
// fall back to loading from the original host.
export function rewrite_remote_images() {
  var script = document.getElementById("image-rewrites");
  if (!script) return;
  var map;
  try {
    map = JSON.parse(script.textContent);
  } catch (_) {
    console.warn("rewrite_remote_images: bad #image-rewrites JSON");
    return;
  }
  var imgs = document.querySelectorAll("img[src]");
  for (var i = 0; i < imgs.length; i++) {
    var src = imgs[i].getAttribute("src");
    if (src && Object.prototype.hasOwnProperty.call(map, src)) {
      imgs[i].setAttribute("src", map[src]);
    }
  }
}

export function set_attribute(id, name, value) {
  var el = document.getElementById(id);
  if (el) {
    el.setAttribute(name, value);
  } else {
    console.warn("set_attribute: element #" + id + " not found");
  }
}

export function remove_attribute(id, name) {
  var el = document.getElementById(id);
  if (el) {
    el.removeAttribute(name);
  } else {
    // Common during page teardown / reload — not interesting.
  }
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

// Re-localize every `[data-iso]` play-time element from its build-time UTC
// rendering into the visitor's local timezone. The element already shows
// correct UTC text; we only swap the text content to local HH:MM.
export function localize_dates() {
  var els = document.querySelectorAll("[data-iso]");
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
