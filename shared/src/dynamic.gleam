import gen/actor/defs.{type ProfileViewDetailed}
import gen/alpha/feed/play.{type AlphaFeedPlay}
import gen/repo.{type Repo}
import gleam/string
import lustre/element.{type Element, fragment, to_string}
import plays
import profile
import repos
import stats.{type StatsData}

/// Renders all three dynamic sections (profile, plays, repos)
/// into a single fragment. Used by both server (SSG) and client (hydration).
pub fn dynamic_sections(
  p: ProfileViewDetailed,
  pl: List(AlphaFeedPlay),
  stats_data: StatsData,
  r: List(Repo),
) -> Element(msg) {
  fragment([
    profile.profile(p),
    plays.plays_section(pl, stats_data),
    repos.repos_section(r),
  ])
}

/// Render a dynamic-sections element to an HTML string with the lustre
/// fragment markers stripped. Used by the client to set innerHTML.
pub fn render(element: Element(msg)) -> String {
  element
  |> to_string
  |> strip_fragment_comments
}

/// Remove the `<!-- lustre:fragment -->` / `<!-- /lustre:fragment -->`
/// markers that lustre emits around `fragment([...])` content.
/// Shared by server (`to_document_string` path) and client (`to_string` path).
pub fn strip_fragment_comments(html: String) -> String {
  html
  |> string.replace("<!-- lustre:fragment -->", "")
  |> string.replace("<!-- /lustre:fragment -->", "")
}
