import gen/repo.{type Repo, Repo}
import gleam/list
import gleam/option.{Some}
import gleeunit/should
import repos

fn repo(did: String, name: String, created_at: String) -> Repo {
  Repo(
    name: name,
    description: Some(""),
    repo_did: did,
    created_at: created_at,
    topics: Some([]),
  )
}

pub fn select_top_empty_test() {
  repos.select_top_repos([]) |> should.equal([])
}

pub fn select_top_dedupes_by_did_test() {
  let input = [
    repo("did:plc:aaa", "first", "2026-01-01T00:00:00Z"),
    repo("did:plc:aaa", "duplicate", "2026-02-01T00:00:00Z"),
  ]
  let result = repos.select_top_repos(input)
  list.length(result) |> should.equal(1)
  let assert [r] = result
  r.name |> should.equal("first")
}

pub fn select_top_filters_hash_names_test() {
  let input = [
    repo("did:plc:keep", "my-cool-project", "2026-01-01T00:00:00Z"),
    repo("did:plc:drop", "abcdefghijklm", "2026-02-01T00:00:00Z"),
  ]
  let result = repos.select_top_repos(input)
  list.length(result) |> should.equal(1)
  let assert [r] = result
  r.repo_did |> should.equal("did:plc:keep")
}

pub fn select_top_sorts_newest_first_test() {
  let input = [
    repo("did:plc:old", "old", "2024-01-01T00:00:00Z"),
    repo("did:plc:new", "new", "2026-01-01T00:00:00Z"),
    repo("did:plc:mid", "mid", "2025-01-01T00:00:00Z"),
  ]
  let result = repos.select_top_repos(input)
  list.map(result, fn(r) { r.name }) |> should.equal(["new", "mid", "old"])
}

pub fn select_top_takes_max_repos_test() {
  let input = [
    repo("did:plc:r1", "repo-1", "2026-01-01T00:00:00Z"),
    repo("did:plc:r2", "repo-2", "2026-02-01T00:00:00Z"),
    repo("did:plc:r3", "repo-3", "2026-03-01T00:00:00Z"),
    repo("did:plc:r4", "repo-4", "2026-04-01T00:00:00Z"),
    repo("did:plc:r5", "repo-5", "2026-05-01T00:00:00Z"),
    repo("did:plc:r6", "repo-6", "2026-06-01T00:00:00Z"),
  ]
  let result = repos.select_top_repos(input)
  list.length(result) |> should.equal(5)
}
