import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { Some, unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { none } from "../lustre/lustre/element.mjs";
import * as $card from "./card.mjs";
import * as $repo from "./gen/repo.mjs";
import { toList, Empty as $Empty } from "./gleam.mjs";
import * as $section from "./section.mjs";

const max_repos = 5;

function is_hash_name(name) {
  return (($string.length(name) > 12) && !$string.contains(name, "-")) && !$string.contains(
    name,
    "_",
  );
}

function dedup_by_did(repos) {
  let _pipe = repos;
  let _pipe$1 = $list.fold(
    _pipe,
    toList([]),
    (acc, repo) => {
      let $ = $list.any(acc, (r) => { return r.repo_did === repo.repo_did; });
      if ($) {
        return acc;
      } else {
        return $list.append(acc, toList([repo]));
      }
    },
  );
  return $list.filter(_pipe$1, (r) => { return !is_hash_name(r.name); });
}

/**
 * Dedupe by repo_did, drop auto-generated hash names, sort newest
 * first, and take the top N. Pure — testable in isolation from
 * `repos_section`'s rendering.
 */
export function select_top_repos(repos) {
  let _pipe = repos;
  let _pipe$1 = dedup_by_did(_pipe);
  let _pipe$2 = $list.sort(
    _pipe$1,
    (a, b) => { return $string.compare(b.created_at, a.created_at); },
  );
  return $list.take(_pipe$2, max_repos);
}

function render_repo_card(repo) {
  return $card.card(
    "https://tangled.org/" + repo.repo_did,
    repo.name,
    new Some("_blank"),
    repo.created_at,
    unwrap(repo.description, ""),
    unwrap(repo.topics, toList([])),
  );
}

export function repos_section(repos) {
  let $ = select_top_repos(repos);
  if ($ instanceof $Empty) {
    return none();
  } else {
    let top = $;
    return $section.section(
      "Projects",
      "repos",
      false,
      $list.map(top, render_repo_card),
    );
  }
}
