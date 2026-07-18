import card
import gen/repo.{type Repo}
import gleam/list
import gleam/option.{Some, unwrap}
import gleam/string
import lustre/element.{type Element, none}
import section

const max_repos = 5

/// Dedupe by repo_did, drop auto-generated hash names, sort newest
/// first, and take the top N. Pure — testable in isolation from
/// `repos_section`'s rendering.
pub fn select_top_repos(repos: List(Repo)) -> List(Repo) {
  repos
  |> dedup_by_did
  |> list.sort(by: fn(a: Repo, b: Repo) {
    string.compare(b.created_at, a.created_at)
  })
  |> list.take(max_repos)
}

pub fn repos_section(repos: List(Repo)) -> Element(msg) {
  case select_top_repos(repos) {
    [] -> none()
    top ->
      section.section(
        "Projects",
        "repos",
        False,
        list.map(top, render_repo_card),
      )
  }
}

fn dedup_by_did(repos: List(Repo)) -> List(Repo) {
  repos
  |> list.fold([], fn(acc: List(Repo), repo: Repo) {
    case list.any(acc, fn(r: Repo) { r.repo_did == repo.repo_did }) {
      True -> acc
      False -> list.append(acc, [repo])
    }
  })
  |> list.filter(fn(r: Repo) { !is_hash_name(r.name) })
}

fn is_hash_name(name: String) -> Bool {
  string.length(name) > 12
  && !string.contains(name, "-")
  && !string.contains(name, "_")
}

fn render_repo_card(repo: Repo) -> Element(msg) {
  card.card(
    title_href: "https://tangled.org/" <> repo.repo_did,
    title_text: repo.name,
    title_target: Some("_blank"),
    date: repo.created_at,
    description: unwrap(repo.description, ""),
    topics: unwrap(repo.topics, []),
  )
}
