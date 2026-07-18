import data/frontmatter
import data/model
import gleam/list
import gleam/string
import gleeunit/should

pub fn parse_full_post_test() {
  let content =
    "---\n"
    <> "title: My Post\n"
    <> "description: short summary\n"
    <> "date: 2026-07-18\n"
    <> "tags: [gleam, atproto]\n"
    <> "---\n"
    <> "\n"
    <> "Body in **markdown**."

  let result = frontmatter.parse("my-post", content)
  let assert Ok(post) = result
  post.title |> should.equal("My Post")
  post.description |> should.equal("short summary")
  post.slug |> should.equal("my-post")
  post.date |> should.equal("2026-07-18")
  post.tags |> should.equal(["gleam", "atproto"])
  post.draft |> should.equal(False)
  string.contains(post.content, "Body in") |> should.be_true()
  string.contains(post.content, "<strong>markdown</strong>")
  |> should.be_true()
}

pub fn parse_draft_post_test() {
  // `draft: true` parses to a Post with draft=True. The build
  // pipeline filters drafts out of the output.
  let content =
    "---\n"
    <> "title: Work In Progress\n"
    <> "date: 2026-07-18\n"
    <> "draft: true\n"
    <> "---\n\n"
    <> "Not ready yet."

  let assert Ok(post) = frontmatter.parse("wip", content)
  post.draft |> should.equal(True)
}

pub fn parse_draft_various_truthy_values_test() {
  // Yes / 1 / TRUE / "  true  " all parse as draft.
  ["true", "TRUE", "  true  ", "yes", "1"]
  |> list.each(fn(v) {
    let content =
      "---\ntitle: T\ndate: 2026-07-18\ndraft: " <> v <> "\n---\n\nbody"
    let assert Ok(post) = frontmatter.parse("p", content)
    post.draft |> should.equal(True)
  })
}

pub fn parse_missing_title_fails_test() {
  let content = "---\ndate: 2026-07-18\n---\n\nBody."
  let result = frontmatter.parse("slug-only", content)
  result |> should.be_error()
  case result {
    Error(frontmatter.MissingField(slug: s, field: f)) -> {
      s |> should.equal("slug-only")
      f |> should.equal("title")
    }
    _ -> should.fail()
  }
}

pub fn parse_missing_date_fails_test() {
  let content = "---\ntitle: Undated\n---\n\nBody."
  let result = frontmatter.parse("undated", content)
  result |> should.be_error()
  case result {
    Error(frontmatter.MissingField(slug: s, field: f)) -> {
      s |> should.equal("undated")
      f |> should.equal("date")
    }
    _ -> should.fail()
  }
}

pub fn parse_malformed_date_fails_test() {
  let cases = [
    "202-01-01",
    "2024-1-01",
    "2024-01-1",
    "2024/01/01",
    "01-01-2024",
    "garbage",
  ]
  list.each(cases, fn(bad) {
    let content = "---\ntitle: T\ndate: " <> bad <> "\n---\n\nbody"
    let result = frontmatter.parse("p", content)
    result |> should.be_error()
    case result {
      Error(frontmatter.InvalidDate(slug: _, value: v)) ->
        v |> should.equal(bad)
      _ -> should.fail()
    }
  })
}

pub fn parse_valid_iso_date_test() {
  let cases = ["2024-01-01", "2024-12-31", "2024-02-29", "1999-09-09"]
  list.each(cases, fn(good) {
    frontmatter.is_iso_date(good) |> should.equal(True)
  })
}

pub fn parse_invalid_iso_date_test() {
  let cases = ["", "2024", "2024-1", "2024-01", "2024-1-1", "abcd-ef-gh"]
  list.each(cases, fn(bad) {
    frontmatter.is_iso_date(bad) |> should.equal(False)
  })
}

pub fn parse_no_frontmatter_fails_test() {
  // No `---` delimiter at all — a clear error rather than a
  // silent fallback. Build fails loudly so the user knows the
  // post is broken.
  let content = "Just body, no frontmatter."
  let result = frontmatter.parse("lonely", content)
  result |> should.be_error()
}

pub fn parse_empty_tags_test() {
  let content = "---\ntitle: T\ndate: 2026-07-18\ntags: []\n---\n\nBody."
  let assert Ok(post) = frontmatter.parse("t", content)
  post.tags |> should.equal([])
}

pub fn parse_missing_tags_test() {
  // No `tags:` line — defaults to `[]`, parsed as empty list.
  let content = "---\ntitle: T\ndate: 2026-07-18\n---\n\nBody."
  let assert Ok(post) = frontmatter.parse("t", content)
  post.tags |> should.equal([])
}

pub fn parse_single_tag_test() {
  let content = "---\ntitle: T\ndate: 2026-07-18\ntags: [gleam]\n---\n\nBody."
  let assert Ok(post) = frontmatter.parse("t", content)
  post.tags |> should.equal(["gleam"])
}

pub fn parse_multiple_tags_test() {
  let content =
    "---\ntitle: T\ndate: 2026-07-18\ntags: [gleam, testing, nix]\n---\n\nBody."
  let assert Ok(post) = frontmatter.parse("t", content)
  post.tags |> should.equal(["gleam", "testing", "nix"])
}

pub fn parse_tags_extra_spaces_test() {
  let content =
    "---\ntitle: T\ndate: 2026-07-18\ntags: [  gleam ,   testing  ]\n---\n\nBody."
  let assert Ok(post) = frontmatter.parse("t", content)
  post.tags |> should.equal(["gleam", "testing"])
}

pub fn parse_preserves_slug_test() {
  // The slug is taken from the path, never from the file. The
  // directory name is authoritative.
  let content = "---\ntitle: T\ndate: 2026-07-18\n---\n\nbody"
  let assert Ok(post) = frontmatter.parse("from-path", content)
  post.slug |> should.equal("from-path")
}

pub fn parse_returns_post_type_test() {
  // Compile-time check: parse returns a Post.
  let assert Ok(post) =
    frontmatter.parse("slug", "---\ntitle: T\ndate: 2026-07-18\n---\n\nbody")
  let _: model.Post = post
  Nil |> should.equal(Nil)
}

// --- slug validation ---

pub fn valid_slug_accepts_test() {
  let good = ["hello", "hello-world", "post-1", "a", "2024-07-18-recap"]
  list.each(good, fn(s) { frontmatter.is_valid_slug(s) |> should.equal(True) })
}

pub fn valid_slug_rejects_test() {
  let bad = [
    "",
    "Hello",
    "hello world",
    "hello_world",
    "-leading-hyphen",
    "with/slash",
    "with.dot",
    "with?query",
  ]
  list.each(bad, fn(s) { frontmatter.is_valid_slug(s) |> should.equal(False) })
}
