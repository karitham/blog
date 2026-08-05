//// Pure content-type → file extension mapping, extracted from the
//// image mirroring logic so it's unit-testable.

import gleam/string

/// Pick a file extension for a mirrored image from its Content-Type
/// header. Falls back to `jpg` for anything unrecognized.
pub fn ext_for_content_type(content_type: String) -> String {
  let content_type = string.lowercase(content_type)
  ext_for(content_type, [#("png", "png"), #("webp", "webp"), #("gif", "gif")])
}

fn ext_for(content_type: String, pairs: List(#(String, String))) -> String {
  case pairs {
    [] -> "jpg"
    [#(needle, ext), ..rest] ->
      case string.contains(content_type, needle) {
        True -> ext
        False -> ext_for(content_type, rest)
      }
  }
}
