@external(javascript, "./browser_ffi.mjs", "fetch_text")
pub fn fetch_text(url: String, callback: fn(String) -> Nil) -> Nil

@external(javascript, "./browser_ffi.mjs", "set_inner_html")
pub fn set_inner_html(id: String, html: String) -> Nil

@external(javascript, "./browser_ffi.mjs", "set_attribute")
pub fn set_attribute(id: String, name: String, value: String) -> Nil

@external(javascript, "./browser_ffi.mjs", "remove_attribute")
pub fn remove_attribute(id: String, name: String) -> Nil

@external(javascript, "./browser_ffi.mjs", "log_error")
pub fn log_error(message: String) -> Nil

@external(javascript, "./browser_ffi.mjs", "set_interval")
pub fn set_interval(ms: Int, callback: fn() -> Nil) -> Nil

@external(javascript, "./browser_ffi.mjs", "is_visible")
pub fn is_visible() -> Bool

@external(javascript, "./browser_ffi.mjs", "on_visibility_change")
pub fn on_visibility_change(callback: fn(Bool) -> Nil) -> Nil
