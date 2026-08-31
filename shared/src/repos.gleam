//// Shared repos view: deduped, newest-first, capped project cards.
//// Pure lustre elements — SSG and client island share the same mount point.

import card
import date
import gen/repo.{type Repo}
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import gleam/time/timestamp
import lustre/attribute.{class, id}
import lustre/element.{type Element, fragment, none, text}
import lustre/element/html.{div, h2}

const max_repos = 5

/// The mount point the client's repos island attaches to. Kept here
/// so the SSG markup and the client selector can't drift apart.
pub const repos_section_id = "repos"

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
  case top_items(repos) {
    [] -> none()
    items -> div([id(repos_section_id), class("section")], items)
  }
}

/// The repos section's content (heading + cards) without the outer
/// `#repos` container. The client's repos island mounts on the
/// server-rendered container and re-renders exactly this.
pub fn repos_inner(repos: List(Repo)) -> Element(msg) {
  fragment(top_items(repos))
}

fn top_items(repos: List(Repo)) -> List(Element(msg)) {
  case select_top_repos(repos) {
    [] -> []
    top -> [h2([], [text("Projects")]), ..list.map(top, render_repo_card)]
  }
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
    title_text: option.unwrap(repo.name, ""),
    title_target: option.Some("_blank"),
    date: case timestamp.parse_rfc3339(repo.created_at) {
      Ok(ts) -> date.format_month_day_year(ts)
      Error(_) -> repo.created_at
    },
    description: option.unwrap(repo.description, ""),
    topics: option.unwrap(repo.topics, []),
  )
}
