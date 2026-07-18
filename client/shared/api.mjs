import * as $int from "../gleam_stdlib/gleam/int.mjs";
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $repo from "./gen/repo.mjs";

export const public_api = "https://public.api.bsky.app";

/**
 * Number of recent plays to fetch. Shared by server (SSG) and client
 * (hydration) so both render the same list length.
 */
export const plays_limit = 20;

export const did = "did:plc:kcgwlowulc3rac43lregdawo";

export const pds_endpoint = "https://eurosky.social";

export function profile_url() {
  return public_api + "/xrpc/app.bsky.actor.getProfile?actor=karitham.dev";
}

export function plays_url() {
  return (((((pds_endpoint + "/xrpc/com.atproto.repo.listRecords") + "?repo=") + did) + "&collection=fm.teal.alpha.feed.play") + "&limit=") + $int.to_string(
    plays_limit,
  );
}

export function pinned_dids_url() {
  return (((pds_endpoint + "/xrpc/com.atproto.repo.listRecords") + "?repo=") + did) + "&collection=sh.tangled.actor.profile";
}

export function repos_url() {
  return (((pds_endpoint + "/xrpc/com.atproto.repo.listRecords") + "?repo=") + did) + "&collection=sh.tangled.repo";
}

/**
 * Keep only repos whose repoDid appears in the pinned list.
 */
export function filter_pinned_repos(all_repos, pinned_dids) {
  return $list.filter(
    all_repos,
    (r) => { return $list.contains(pinned_dids, r.repo_did); },
  );
}
