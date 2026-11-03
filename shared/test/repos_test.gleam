import gen/repo/manifest.{type RepoManifest, Declaration, RepoManifest}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element.{to_string}
import repos

fn repo(
  owner owner: String,
  name name: String,
  created_at created_at: String,
) -> RepoManifest {
  RepoManifest(
    created_at: created_at,
    declaration: Declaration(name: name, owner: owner),
    description: Some("description"),
    topics: Some(["gleam"]),
    website: None,
  )
}

pub fn select_top_empty_test() {
  repos.select_top_repos([]) |> should.equal([])
}

pub fn select_top_sorts_newest_first_test() {
  let input = [
    repo(owner: "did:plc:o", name: "old", created_at: "2024-01-01T00:00:00Z"),
    repo(owner: "did:plc:o", name: "new", created_at: "2026-01-01T00:00:00Z"),
    repo(owner: "did:plc:o", name: "mid", created_at: "2025-01-01T00:00:00Z"),
  ]
  let result = repos.select_top_repos(input)
  list.map(result, fn(r) { r.declaration.name })
  |> should.equal(["new", "mid", "old"])
}

pub fn select_top_takes_max_repos_test() {
  let input = [
    repo(owner: "did:plc:o", name: "repo-1", created_at: "2026-01-01T00:00:00Z"),
    repo(owner: "did:plc:o", name: "repo-2", created_at: "2026-02-01T00:00:00Z"),
    repo(owner: "did:plc:o", name: "repo-3", created_at: "2026-03-01T00:00:00Z"),
    repo(owner: "did:plc:o", name: "repo-4", created_at: "2026-04-01T00:00:00Z"),
    repo(owner: "did:plc:o", name: "repo-5", created_at: "2026-05-01T00:00:00Z"),
    repo(owner: "did:plc:o", name: "repo-6", created_at: "2026-06-01T00:00:00Z"),
  ]
  repos.select_top_repos(input) |> list.length |> should.equal(5)
}

pub fn repos_section_formats_appview_timestamps_test() {
  // The appview returns microsecond precision; the card date comes
  // from the parsed timestamp, not the raw string.
  let html =
    repos.repos_section([
      repo(
        owner: "did:plc:owner",
        name: "repo",
        created_at: "2026-08-08T00:21:30.000000Z",
      ),
    ])
    |> to_string
  html |> string.contains("August 8, 2026") |> should.be_true()
}

pub fn repos_section_links_to_owner_and_lowercase_slug_test() {
  let html =
    repos.repos_section([
      repo(
        owner: "did:plc:owner",
        name: "MyRepo",
        created_at: "2026-01-01T00:00:00Z",
      ),
    ])
    |> to_string
  html
  |> string.contains("https://tangled.org/did:plc:owner/myrepo")
  |> should.be_true()
  html |> string.contains("MyRepo") |> should.be_true()
  html |> string.contains("description") |> should.be_true()
  html |> string.contains("gleam") |> should.be_true()
}
