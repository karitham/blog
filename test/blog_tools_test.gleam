import blog_tools
import gleam/list
import gleeunit/should

pub fn slugify_simple_test() {
  blog_tools.slugify("hello") |> should.equal("hello")
}

pub fn slugify_lowercases_test() {
  blog_tools.slugify("Hello") |> should.equal("hello")
}

pub fn slugify_joins_spaces_test() {
  blog_tools.slugify("New blog ayo whos this")
  |> should.equal("new-blog-ayo-whos-this")
}

pub fn slugify_replaces_punctuation_test() {
  blog_tools.slugify("Hello, World!")
  |> should.equal("hello-world")
}

pub fn slugify_underscores_become_dashes_test() {
  blog_tools.slugify("hello_world") |> should.equal("hello-world")
}

pub fn slugify_collapses_runs_of_dashes_test() {
  blog_tools.slugify("foo---bar") |> should.equal("foo-bar")
  blog_tools.slugify("a !! b") |> should.equal("a-b")
}

pub fn slugify_trims_leading_and_trailing_dashes_test() {
  blog_tools.slugify("---hello---") |> should.equal("hello")
  blog_tools.slugify("!hello!") |> should.equal("hello")
}

pub fn slugify_preserves_existing_dashes_test() {
  blog_tools.slugify("my-post") |> should.equal("my-post")
}

pub fn slugify_empty_input_test() {
  blog_tools.slugify("") |> should.equal("")
}

pub fn slugify_only_punctuation_test() {
  blog_tools.slugify("!!!") |> should.equal("")
}

pub fn slugify_already_valid_test() {
  // Idempotency: a valid slug should be its own slugify output.
  let cases = ["hello", "hello-world", "post-1", "a", "2024-07-18"]
  list.each(cases, fn(s) { blog_tools.slugify(s) |> should.equal(s) })
}
