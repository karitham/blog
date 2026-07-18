import data/util
import gleeunit/should

pub fn extract_field_found_test() {
  let lines = ["title: Hello World", "date: 2024-01-01", "description: A post"]
  let result = util.extract_field(lines, "title:", "")
  result |> should.equal("Hello World")
}

pub fn extract_field_found_with_extra_spaces_test() {
  let lines = ["tags:   [gleam, testing]"]
  let result = util.extract_field(lines, "tags:", "[]")
  result |> should.equal("[gleam, testing]")
}

pub fn extract_field_not_found_test() {
  let lines = ["title: Hello"]
  let result = util.extract_field(lines, "author:", "default-author")
  result |> should.equal("default-author")
}

pub fn extract_field_empty_lines_test() {
  let lines: List(String) = []
  let result = util.extract_field(lines, "key:", "fallback")
  result |> should.equal("fallback")
}

pub fn extract_field_partial_match_test() {
  let lines = ["bread: not this", "breadth: wide"]
  let result = util.extract_field(lines, "bread:", "")
  result |> should.equal("not this")
}
