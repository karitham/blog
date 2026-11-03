//// Reads the profile image rewrite map produced by `just refresh`.
////
//// The Rust pipeline mirrors the avatar/banner through the same image
//// store as the music artwork and writes
//// `priv/cache/profile-images.json` (remote URL -> /img/...). The SSG
//// only applies that map; it never downloads profile images itself.

import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/string
import simplifile

pub const path = "priv/cache/profile-images.json"

pub fn load_rewrites() -> Dict(String, String) {
  case simplifile.read(path) {
    Error(_) -> dict.new()
    Ok(body) ->
      case parse_rewrites(body) {
        Ok(rewrites) -> rewrites
        Error(e) -> {
          io.println("Failed to read profile image map: " <> string.inspect(e))
          dict.new()
        }
      }
  }
}

pub fn parse_rewrites(
  body: String,
) -> Result(Dict(String, String), json.DecodeError) {
  json.parse(body, decode.dict(decode.string, decode.string))
}
