import gen/repo.{type Repo}
import gleam/list

pub const pds_endpoint = "https://eurosky.social"

pub const public_api = "https://public.api.bsky.app"

pub const did = "did:plc:kcgwlowulc3rac43lregdawo"

/// Shared by SSG and client so both render the same list length.
pub const plays_limit = 10

pub fn filter_pinned_repos(
  all_repos: List(Repo),
  pinned_dids: List(String),
) -> List(Repo) {
  list.filter(all_repos, fn(r) { list.contains(pinned_dids, r.repo_did) })
}
