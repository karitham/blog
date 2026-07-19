import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $repo from "./gen/repo.mjs";

export const pds_endpoint = "https://eurosky.social";

export const public_api = "https://public.api.bsky.app";

export const did = "did:plc:kcgwlowulc3rac43lregdawo";

/**
 * Shared by SSG and client so both render the same list length.
 */
export const plays_limit = 10;

export function filter_pinned_repos(all_repos, pinned_dids) {
  return $list.filter(
    all_repos,
    (r) => { return $list.contains(pinned_dids, r.repo_did); },
  );
}
