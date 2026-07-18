import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $string from "../../gleam_stdlib/gleam/string.mjs";

/**
 * The record key is the last `/`-separated segment of an at-uri.
 */
export function rkey(at_uri) {
  let _pipe = at_uri;
  let _pipe$1 = $string.split(_pipe, "/");
  let _pipe$2 = $list.last(_pipe$1);
  return $result.unwrap(_pipe$2, "");
}
