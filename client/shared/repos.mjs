import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { Some, unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $order from "../gleam_stdlib/gleam/order.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $timestamp from "../gleam_time/gleam/time/timestamp.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { none } from "../lustre/lustre/element.mjs";
import * as $card from "./card.mjs";
import * as $date from "./date.mjs";
import * as $repo from "./gen/repo.mjs";
import { Ok, toList, Empty as $Empty, List$Empty$const as $List$Empty$const } from "./gleam.mjs";
import * as $section from "./section.mjs";

const max_repos = 5;

function compare_repos_newest_first(a, b) {
  let $ = $timestamp.parse_rfc3339(a.created_at);
  let $1 = $timestamp.parse_rfc3339(b.created_at);
  if ($ instanceof Ok) {
    if ($1 instanceof Ok) {
      let ta = $[0];
      let tb = $1[0];
      return $timestamp.compare(tb, ta);
    } else {
      return $order.Order$Gt$const;
    }
  } else if ($1 instanceof Ok) {
    return $order.Order$Lt$const;
  } else {
    return $string.compare(b.created_at, a.created_at);
  }
}

function dedup_by_did(repos) {
  return $list.fold(
    repos,
    $List$Empty$const,
    (acc, repo) => {
      let $ = $list.any(acc, (r) => { return r.repo_did === repo.repo_did; });
      if ($) {
        return acc;
      } else {
        return $list.append(acc, toList([repo]));
      }
    },
  );
}

/**
 * Dedupe by repo_did, sort newest first, take the top N. Sorting
 * uses the parsed timestamp so different source offsets compare
 * correctly.
 */
export function select_top_repos(repos) {
  let _pipe = repos;
  let _pipe$1 = dedup_by_did(_pipe);
  let _pipe$2 = $list.sort(_pipe$1, compare_repos_newest_first);
  return $list.take(_pipe$2, max_repos);
}

function render_repo_card(repo) {
  return $card.card(
    "https://tangled.org/" + repo.repo_did,
    unwrap(repo.name, ""),
    new Some("_blank"),
    (() => {
      let $ = $timestamp.parse_rfc3339(repo.created_at);
      if ($ instanceof Ok) {
        let ts = $[0];
        return $date.format_month_day_year(ts);
      } else {
        return repo.created_at;
      }
    })(),
    unwrap(repo.description, ""),
    unwrap(repo.topics, $List$Empty$const),
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
