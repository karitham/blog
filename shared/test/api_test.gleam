import api
import gen/repo.{type Repo, Repo}
import gleam/list
import gleam/option.{Some}
import gleeunit/should

// --- filter_pinned_repos ---

fn repo(did: String, name: String) -> Repo {
  Repo(
    name: name,
    description: Some(""),
    repo_did: did,
    created_at: "",
    topics: Some([]),
  )
}

pub fn filter_pinned_repos_keeps_only_pinned_test() {
  let all = [
    repo("did:plc:aaa", "a"),
    repo("did:plc:bbb", "b"),
    repo("did:plc:ccc", "c"),
  ]
  let pinned = ["did:plc:bbb"]

  let result = api.filter_pinned_repos(all, pinned)
  result |> list.map(fn(r) { r.name }) |> should.equal(["b"])
}

pub fn filter_pinned_repos_empty_pinned_test() {
  let all = [repo("did:plc:aaa", "a")]
  api.filter_pinned_repos(all, []) |> should.equal([])
}

pub fn filter_pinned_repos_empty_repos_test() {
  api.filter_pinned_repos([], ["did:plc:aaa"]) |> should.equal([])
}

pub fn filter_pinned_repos_all_pinned_test() {
  let all = [repo("did:plc:aaa", "a"), repo("did:plc:bbb", "b")]
  let pinned = ["did:plc:aaa", "did:plc:bbb"]
  api.filter_pinned_repos(all, pinned) |> list.length |> should.equal(2)
}

pub fn filter_pinned_repos_unpinned_did_ignored_test() {
  let all = [repo("did:plc:aaa", "a")]
  api.filter_pinned_repos(all, ["did:plc:zzz"]) |> should.equal([])
}
