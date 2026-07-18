import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $element from "../lustre/lustre/element.mjs";
import { fragment, to_string } from "../lustre/lustre/element.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import * as $repo from "./gen/repo.mjs";
import { toList } from "./gleam.mjs";
import * as $plays from "./plays.mjs";
import * as $profile from "./profile.mjs";
import * as $repos from "./repos.mjs";

/**
 * Renders all three dynamic sections (profile, plays, repos)
 * into a single fragment. Used by both server (SSG) and client (hydration).
 */
export function dynamic_sections(p, pl, r) {
  return fragment(
    toList([
      $profile.profile(p),
      $plays.plays_section(pl),
      $repos.repos_section(r),
    ]),
  );
}

/**
 * Remove the `<!-- lustre:fragment -->` / `<!-- /lustre:fragment -->`
 * markers that lustre emits around `fragment([...])` content.
 * Shared by server (`to_document_string` path) and client (`to_string` path).
 */
export function strip_fragment_comments(html) {
  let _pipe = html;
  let _pipe$1 = $string.replace(_pipe, "<!-- lustre:fragment -->", "");
  return $string.replace(_pipe$1, "<!-- /lustre:fragment -->", "");
}

/**
 * Render a dynamic-sections element to an HTML string with the lustre
 * fragment markers stripped. Used by the client to set innerHTML.
 */
export function render(element) {
  let _pipe = element;
  let _pipe$1 = to_string(_pipe);
  return strip_fragment_comments(_pipe$1);
}
