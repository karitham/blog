import * as $dynamic from "../shared/dynamic.mjs";
import * as $defs from "../shared/gen/actor/defs.mjs";
import * as $play from "../shared/gen/feed/play.mjs";
import * as $repo from "../shared/gen/repo.mjs";
import * as $plays_view from "../shared/plays.mjs";
import * as $profile_view from "../shared/profile.mjs";
import * as $repos_view from "../shared/repos.mjs";
import * as $commit from "./commit.mjs";
import {
  RemoveAttr,
  ReplaceHtml,
  SetAttr,
  Command$RewriteRemoteImages$const,
  Command$LocalizeDates$const,
} from "./commit.mjs";
import { toList, Empty as $Empty } from "./gleam.mjs";

/**
 * The fresh profile replaces the server-rendered section, then every
 * remote image in the document is pointed at its local mirror.
 */
export function plan_profile(profile) {
  return toList([
    new ReplaceHtml(
      "profile-section",
      $dynamic.render($profile_view.profile(profile)),
    ),
    Command$RewriteRemoteImages$const,
  ]);
}

export function plan_repos(repos) {
  return toList([
    new ReplaceHtml("repos", $dynamic.render($repos_view.repos_section(repos))),
  ]);
}

/**
 * One plays poll tick: render the fresh rows, re-localize their
 * times, and clear the stale flag. An empty result (or an error
 * handled by the caller) just clears the flag so the UI stays calm.
 */
export function plan_plays(plays) {
  if (plays instanceof $Empty) {
    return toList([new RemoveAttr("plays", "data-stale")]);
  } else {
    return toList([
      new ReplaceHtml(
        "plays-rows",
        $dynamic.render($plays_view.plays_rows(plays)),
      ),
      Command$LocalizeDates$const,
      new RemoveAttr("plays", "data-stale"),
    ]);
  }
}

/**
 * The start of a poll cycle: flag the section stale so the CSS shows
 * it refreshing, then fetch.
 */
export function mark_plays_stale() {
  return toList([new SetAttr("plays", "data-stale", "true")]);
}
