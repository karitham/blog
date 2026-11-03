//// Shared repos view: newest-first, capped project cards.
//// Pure lustre elements — SSG and client island share the same mount point.

import card
import date
import gen/repo/manifest.{type RepoManifest}
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

/// Sort newest first and take the top N. Pinned repo DIDs are unique
/// before the fetch, so records don't need a second identity rule here.
pub fn select_top_repos(repos: List(RepoManifest)) -> List(RepoManifest) {
  repos
  |> list.sort(by: compare_repos_newest_first)
  |> list.take(max_repos)
}

fn compare_repos_newest_first(a: RepoManifest, b: RepoManifest) -> order.Order {
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

pub fn repos_section(repos: List(RepoManifest)) -> Element(msg) {
  case top_items(repos) {
    [] -> none()
    items -> div([id(repos_section_id), class("section")], items)
  }
}

/// The repos section's content (heading + cards) without the outer
/// `#repos` container. The client's repos island mounts on the
/// server-rendered container and re-renders exactly this.
pub fn repos_inner(repos: List(RepoManifest)) -> Element(msg) {
  fragment(top_items(repos))
}

fn top_items(repos: List(RepoManifest)) -> List(Element(msg)) {
  case select_top_repos(repos) {
    [] -> []
    top -> [h2([], [text("Projects")]), ..list.map(top, render_repo_card)]
  }
}

fn render_repo_card(repo: RepoManifest) -> Element(msg) {
  let declaration = repo.declaration
  card.card(
    title_href: "https://tangled.org/"
      <> declaration.owner
      <> "/"
      <> string.lowercase(declaration.name),
    title_text: declaration.name,
    title_target: option.Some("_blank"),
    date: date.format_iso_day(repo.created_at),
    description: option.unwrap(repo.description, ""),
    topics: option.unwrap(repo.topics, []),
  )
}
