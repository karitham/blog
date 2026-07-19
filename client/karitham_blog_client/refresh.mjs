import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $api from "../shared/api.mjs";
import * as $dynamic from "../shared/dynamic.mjs";
import * as $fetch from "../shared/fetch.mjs";
import * as $play from "../shared/gen/alpha/feed/play.mjs";
import * as $repo from "../shared/gen/repo.mjs";
import * as $plays_view from "../shared/plays.mjs";
import * as $profile_view from "../shared/profile.mjs";
import * as $repos_view from "../shared/repos.mjs";
import * as $browser from "./browser.mjs";
import { Ok, Empty as $Empty } from "./gleam.mjs";

/**
 * Short enough that a new track shows up promptly, long enough that
 * we're not hammering the PDS.
 * 
 * @ignore
 */
const plays_poll_ms = 30_000;

function mark_plays_fresh() {
  return $browser.remove_attribute("plays", "data-stale");
}

function commit_plays(plays_data) {
  $browser.set_inner_html(
    "plays",
    $dynamic.render($plays_view.plays_section(plays_data)),
  );
  $browser.localize_dates();
  return mark_plays_fresh();
}

function on_plays(text) {
  let $ = $fetch.decode_plays(text);
  if ($ instanceof Ok) {
    let $1 = $[0];
    if ($1 instanceof $Empty) {
      return mark_plays_fresh();
    } else {
      let plays_data = $1;
      return commit_plays(plays_data);
    }
  } else {
    let reason = $[0];
    $browser.log_error("decode_plays failed: " + $string.inspect(reason));
    return mark_plays_fresh();
  }
}

function mark_plays_stale() {
  return $browser.set_attribute("plays", "data-stale", "true");
}

function refresh_plays() {
  mark_plays_stale();
  return $browser.fetch_text($fetch.plays_url(), on_plays);
}

function commit_repos(repos) {
  return $browser.set_inner_html(
    "repos",
    $dynamic.render($repos_view.repos_section(repos)),
  );
}

function fetch_pinned_dids_and_repos() {
  return $browser.fetch_text(
    $fetch.pinned_dids_url(),
    (pinned_text) => {
      let $ = $fetch.decode_pinned_dids(pinned_text);
      if ($ instanceof Ok) {
        let dids = $[0];
        return $browser.fetch_text(
          $fetch.repos_url(),
          (repos_text) => {
            let $1 = $fetch.decode_repos(repos_text);
            if ($1 instanceof Ok) {
              let all_repos = $1[0];
              return commit_repos($api.filter_pinned_repos(all_repos, dids));
            } else {
              let reason = $1[0];
              return $browser.log_error(
                "decode_repos failed: " + $string.inspect(reason),
              );
            }
          },
        );
      } else {
        let reason = $[0];
        return $browser.log_error(
          "decode_pinned_dids failed: " + $string.inspect(reason),
        );
      }
    },
  );
}

function on_profile(text) {
  let $ = $fetch.decode_profile(text);
  if ($ instanceof Ok) {
    let profile = $[0];
    return $browser.set_inner_html(
      "profile-section",
      $dynamic.render($profile_view.profile(profile)),
    );
  } else {
    let reason = $[0];
    return $browser.log_error(
      "decode_profile failed: " + $string.inspect(reason),
    );
  }
}

function fetch_profile() {
  return $browser.fetch_text($fetch.profile_url(), on_profile);
}

function refresh_all() {
  fetch_profile();
  fetch_pinned_dids_and_repos();
  return refresh_plays();
}

function on_visibility_change(visible) {
  if (visible) {
    return refresh_all();
  } else {
    return undefined;
  }
}

function poll_tick() {
  let $ = $browser.is_visible();
  if ($) {
    return refresh_plays();
  } else {
    return undefined;
  }
}

/**
 * Wires up initial fetches, periodic poll, and visibility listener.
 */
export function start() {
  let $ = $browser.has_element("profile-section");
  if ($) {
    refresh_all();
    $browser.localize_dates();
    $browser.set_interval(plays_poll_ms, poll_tick);
    return $browser.on_visibility_change(on_visibility_change);
  } else {
    return undefined;
  }
}
