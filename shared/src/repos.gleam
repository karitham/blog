import card
import date
import gen/repo.{type Repo}
import gleam/list
import gleam/option.{Some, unwrap}
import gleam/order
import gleam/string
import gleam/time/timestamp
import lustre/attribute.{class, id}
import lustre/element.{type Element, none, text}
import lustre/element/html.{div, h2}

const max_repos = 5

/// Dedupe by repo_did, sort newest first, take the top N. Sorting
/// uses the parsed timestamp so different source offsets compare
/// correctly.
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
    top -> section("Projects", "repos", list.map(top, render_repo_card))
  }
}

/// The section frame used by the repos list: a titled container with
/// `data-stale` support for the client's refresh cycle (the CSS keys
/// off `.section[data-stale="true"]` for a pulsing dot in the header).
fn section(
  title: String,
  id_str: String,
  items: List(Element(msg)),
) -> Element(msg) {
  div([id(id_str), class("section")], [h2([], [text(title)]), ..items])
}

fn dedup_by_did(repos: List(Repo)) -> List(Repo) {
  use acc, repo <- list.fold(repos, [])

  case list.any(acc, fn(r: Repo) { r.repo_did == repo.repo_did }) {
    True -> acc
    False -> list.append(acc, [repo])
  }
}

fn render_repo_card(repo: Repo) -> Element(msg) {
  card.card(
    title_href: "https://tangled.org/" <> repo.repo_did,
    title_text: unwrap(repo.name, ""),
    title_target: Some("_blank"),
    date: case timestamp.parse_rfc3339(repo.created_at) {
      Ok(ts) -> date.format_month_day_year(ts)
      Error(_) -> repo.created_at
    },
    description: unwrap(repo.description, ""),
    topics: unwrap(repo.topics, []),
  )
}
