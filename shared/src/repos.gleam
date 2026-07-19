import card
import date
import gen/repo.{type Repo}
import gleam/list
import gleam/option.{Some, unwrap}
import gleam/order
import gleam/string
import gleam/time/timestamp
import lustre/element.{type Element, none}
import section

const max_repos = 5

/// Dedupe by repo_did, drop auto-generated hash names, sort newest
/// first, and take the top N. Sorting uses the parsed timestamp so
/// different source offsets compare correctly.
pub fn select_top_repos(repos: List(Repo)) -> List(Repo) {
  repos
  |> dedup_by_did
  |> list.sort(by: compare_repos_newest_first)
  |> list.take(max_repos)
}

fn compare_repos_newest_first(a: Repo, b: Repo) -> order.Order {
  case
    timestamp.parse_rfc3339(a.created_at),
    timestamp.parse_rfc3339(b.created_at)
  {
    Ok(ta), Ok(tb) -> timestamp.compare(tb, ta)
    Ok(_), Error(_) -> order.Gt
    Error(_), Ok(_) -> order.Lt
    Error(_), Error(_) -> string.compare(b.created_at, a.created_at)
  }
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
  let date_str = case timestamp.parse_rfc3339(repo.created_at) {
    Ok(ts) -> date.format_month_day_year(ts)
    Error(_) -> repo.created_at
  }
  card.card(
    title_href: "https://tangled.org/" <> repo.repo_did,
    title_text: repo.name,
    title_target: Some("_blank"),
    date: date_str,
    description: unwrap(repo.description, ""),
    topics: unwrap(repo.topics, []),
  )
}
