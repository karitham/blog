//// Pure post template. The date is injected so the scaffolder is
//// testable with a fixed "today".

import cli/slug
import date
import gleam/int

/// Render the post template for a given slug. `today` is the current
/// date as `#(year, month, day)` so the scaffolded post sorts to the
/// top of the timeline; the shell (`cli.gleam`) reads the clock.
pub fn template(slug: String, today: #(Int, Int, Int)) -> String {
  let #(y, m, d) = today
  let date = int.to_string(y) <> "-" <> date.pad2(m) <> "-" <> date.pad2(d)
  "---\n"
  <> "title: "
  <> slug.title_from_slug(slug)
  <> "\n"
  <> "description: \n"
  <> "date: "
  <> date
  <> "\n"
  <> "tags: []\n"
  <> "draft: true\n"
  <> "image: \n"
  <> "---\n"
  <> "\n"
  <> "Write your post here.\n"
}
