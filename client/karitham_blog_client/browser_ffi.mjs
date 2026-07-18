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
