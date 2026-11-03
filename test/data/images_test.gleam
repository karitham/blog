import data/images
import gleam/dict
import gleeunit/should

pub fn parse_rewrites_decodes_map_test() {
  let assert Ok(rewrites) =
    images.parse_rewrites(
      "{\"https://cdn.bsky.app/avatar.jpg\":\"/img/profile/a.jpg\"}",
    )
  rewrites
  |> dict.get("https://cdn.bsky.app/avatar.jpg")
  |> should.equal(Ok("/img/profile/a.jpg"))
}

pub fn parse_rewrites_empty_map_test() {
  let assert Ok(rewrites) = images.parse_rewrites("{}")
  rewrites |> should.equal(dict.new())
}

pub fn parse_rewrites_rejects_invalid_json_test() {
  images.parse_rewrites("not json") |> should.be_error()
}
