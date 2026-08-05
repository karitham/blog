import cli/slug
import gleam/list
import gleeunit/should

pub fn slugify_simple_test() {
  slug.slugify("hello") |> should.equal("hello")
}

pub fn slugify_lowercases_test() {
  slug.slugify("Hello") |> should.equal("hello")
}

pub fn slugify_joins_spaces_test() {
  slug.slugify("New blog ayo whos this")
  |> should.equal("new-blog-ayo-whos-this")
}

pub fn slugify_replaces_punctuation_test() {
  slug.slugify("Hello, World!") |> should.equal("hello-world")
}

pub fn slugify_underscores_become_dashes_test() {
  slug.slugify("hello_world") |> should.equal("hello-world")
}

pub fn slugify_collapses_runs_of_dashes_test() {
  slug.slugify("foo---bar") |> should.equal("foo-bar")
  slug.slugify("a !! b") |> should.equal("a-b")
}

pub fn slugify_trims_leading_and_trailing_dashes_test() {
  slug.slugify("---hello---") |> should.equal("hello")
  slug.slugify("!hello!") |> should.equal("hello")
}

pub fn slugify_preserves_existing_dashes_test() {
  slug.slugify("my-post") |> should.equal("my-post")
}

pub fn slugify_empty_input_test() {
  slug.slugify("") |> should.equal("")
}

pub fn slugify_only_punctuation_test() {
  slug.slugify("!!!") |> should.equal("")
}

pub fn slugify_already_valid_test() {
  // Idempotency: a valid slug should be its own slugify output.
  let cases = ["hello", "hello-world", "post-1", "a", "2024-07-18"]
  list.each(cases, fn(s) { slug.slugify(s) |> should.equal(s) })
}

pub fn title_from_slug_capitalizes_words_test() {
  slug.title_from_slug("hello-world") |> should.equal("Hello World")
}

pub fn title_from_slug_empty_test() {
  slug.title_from_slug("") |> should.equal("")
}
