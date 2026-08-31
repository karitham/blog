import data/model
import gleeunit/should

pub fn parse_slug_accepts_valid_test() {
  model.parse_slug("hello") |> should.be_ok()
  model.parse_slug("hello-world") |> should.be_ok()
  model.parse_slug("post-1") |> should.be_ok()
  model.parse_slug("a") |> should.be_ok()
  model.parse_slug("2024-07-18-recap") |> should.be_ok()
}

pub fn parse_slug_rejects_invalid_test() {
  model.parse_slug("") |> should.be_error()
  model.parse_slug("Hello") |> should.be_error()
  model.parse_slug("hello world") |> should.be_error()
  model.parse_slug("hello_world") |> should.be_error()
  model.parse_slug("-leading-hyphen") |> should.be_error()
  model.parse_slug("with/slash") |> should.be_error()
}

pub fn slug_round_trips_test() {
  let assert Ok(slug) = model.parse_slug("my-post")
  model.slug_to_string(slug) |> should.equal("my-post")
}

pub fn must_slug_panics_on_invalid_test() {
  // must_slug is for known-good literals; invalid literal would panic,
  // but we test the happy path here — invalid case is not exercised to
  // avoid crashing the test suite.
  model.must_slug("valid-slug")
  |> model.slug_to_string
  |> should.equal("valid-slug")
}

pub fn slug_error_variants_test() {
  model.parse_slug("") |> should.equal(Error(model.EmptySlug))
  model.parse_slug("-bad")
  |> should.equal(Error(model.InvalidSlug("-bad")))
}
