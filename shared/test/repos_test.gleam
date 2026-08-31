import gen/repo.{type Repo, Repo}
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import repos

fn repo(
  did did: String,
  name name: String,
  created_at created_at: String,
) -> Repo {
  Repo(
    name: Some(name),
    description: Some(""),
    repo_did: did,
    created_at: created_at,
    topics: Some([]),
    website: None,
  )
}

pub fn select_top_empty_test() {
  repos.select_top_repos([]) |> should.equal([])
}

pub fn select_top_dedupes_by_did_test() {
  let input = [
    repo(did: "did:plc:aaa", name: "first", created_at: "2026-01-01T00:00:00Z"),
    repo(
      did: "did:plc:aaa",
      name: "duplicate",
      created_at: "2026-02-01T00:00:00Z",
    ),
  ]
  let result = repos.select_top_repos(input)
  list.length(result) |> should.equal(1)
  let assert [r] = result
  r.name |> should.equal(Some("first"))
}

pub fn select_top_sorts_newest_first_test() {
  let input = [
    repo(did: "did:plc:old", name: "old", created_at: "2024-01-01T00:00:00Z"),
    repo(did: "did:plc:new", name: "new", created_at: "2026-01-01T00:00:00Z"),
    repo(did: "did:plc:mid", name: "mid", created_at: "2025-01-01T00:00:00Z"),
  ]
  let result = repos.select_top_repos(input)
  list.map(result, fn(r) { option.unwrap(r.name, "") })
  |> should.equal(["new", "mid", "old"])
}

pub fn select_top_takes_max_repos_test() {
  let input = [
    repo(did: "did:plc:r1", name: "repo-1", created_at: "2026-01-01T00:00:00Z"),
    repo(did: "did:plc:r2", name: "repo-2", created_at: "2026-02-01T00:00:00Z"),
    repo(did: "did:plc:r3", name: "repo-3", created_at: "2026-03-01T00:00:00Z"),
    repo(did: "did:plc:r4", name: "repo-4", created_at: "2026-04-01T00:00:00Z"),
    repo(did: "did:plc:r5", name: "repo-5", created_at: "2026-05-01T00:00:00Z"),
    repo(did: "did:plc:r6", name: "repo-6", created_at: "2026-06-01T00:00:00Z"),
  ]
  let result = repos.select_top_repos(input)
  list.length(result) |> should.equal(5)
}
