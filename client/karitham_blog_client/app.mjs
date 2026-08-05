import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $atproto from "../shared/atproto.mjs";
import * as $browser from "./browser.mjs";
import * as $commit from "./commit.mjs";
import { LocalizeDates, RemoveAttr, ReplaceHtml, RewriteRemoteImages, SetAttr } from "./commit.mjs";
import { Ok, List$Empty$const as $List$Empty$const } from "./gleam.mjs";
import * as $pipeline from "./pipeline.mjs";

/**
 * Short enough that a new track shows up promptly, long enough that
 * we're not hammering the PDS.
 * 
 * @ignore
 */
const plays_poll_ms = 30_000;

function interpret(command) {
  if (command instanceof ReplaceHtml) {
    let id = command.id;
    let html = command.html;
    return $browser.set_inner_html(id, html);
  } else if (command instanceof SetAttr) {
    let id = command.id;
    let name = command.name;
    let value = command.value;
    return $browser.set_attribute(id, name, value);
  } else if (command instanceof RemoveAttr) {
    let id = command.id;
    let name = command.name;
    return $browser.remove_attribute(id, name);
  } else if (command instanceof LocalizeDates) {
    return $browser.localize_dates();
  } else {
    return $browser.rewrite_remote_images();
  }
}

function commit(commands) {
  return $list.each(commands, interpret);
}

function on_plays(text) {
  let $ = $atproto.decode_plays(text);
  if ($ instanceof Ok) {
    let plays = $[0];
    return commit($pipeline.plan_plays(plays));
  } else {
    let reason = $[0];
    $browser.log_error("decode_plays failed: " + $string.inspect(reason));
    return commit($pipeline.plan_plays($List$Empty$const));
  }
}

function refresh_plays() {
  commit($pipeline.mark_plays_stale());
  return $browser.fetch_text($atproto.plays_url(), on_plays);
}

function fetch_pinned_dids_and_repos() {
  return $browser.fetch_text(
    $atproto.pinned_dids_url(),
    (pinned_text) => {
      let $ = $atproto.decode_actor_profiles(pinned_text);
      if ($ instanceof Ok) {
        let profiles = $[0];
        let pinned_dids = $atproto.pinned_dids_from_profiles(profiles);
        return $browser.fetch_text(
          $atproto.repos_url(),
          (repos_text) => {
            let $1 = $atproto.decode_repos(repos_text);
            if ($1 instanceof Ok) {
              let records = $1[0];
              let _block;
              let _pipe = records;
              let _pipe$1 = $atproto.filter_repos_by_did(_pipe, pinned_dids);
              let _pipe$2 = $list.map(_pipe$1, $atproto.resolve_repo_name);
              _block = $list.map(_pipe$2, (record) => { return record.value; });
              let repos = _block;
              return commit($pipeline.plan_repos(repos));
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
          "decode_actor_profiles failed: " + $string.inspect(reason),
        );
      }
    },
  );
}

function fetch_profile() {
  return $browser.fetch_text(
    $atproto.profile_url(),
    (text) => {
      let $ = $atproto.decode_profile(text);
      if ($ instanceof Ok) {
        let profile = $[0];
        return commit($pipeline.plan_profile(profile));
      } else {
        let reason = $[0];
        return $browser.log_error(
          "decode_profile failed: " + $string.inspect(reason),
        );
      }
    },
  );
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
