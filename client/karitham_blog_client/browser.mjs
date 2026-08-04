import {
  fetch_text,
  set_inner_html,
  rewrite_remote_images,
  set_attribute,
  remove_attribute,
  has_element,
  log_error,
  set_interval,
  is_visible,
  on_visibility_change,
  localize_dates,
} from "./browser_ffi.mjs";

export {
  fetch_text,
  has_element,
  is_visible,
  localize_dates,
  log_error,
  on_visibility_change,
  remove_attribute,
  rewrite_remote_images,
  set_attribute,
  set_inner_html,
  set_interval,
};
