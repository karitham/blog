import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { Some, unwrap } from "../gleam_stdlib/gleam/option.mjs";
import * as $atproto from "./atproto.mjs";
import { DecodedRecord } from "./atproto.mjs";
import * as $profile from "./gen/actor/profile.mjs";
import * as $repo from "./gen/repo.mjs";
import { Repo } from "./gen/repo.mjs";
import { Ok, List$Empty$const as $List$Empty$const } from "./gleam.mjs";

/**
 * Fill in a Tangled repo's `name` from the URI rkey when the
 * original is missing or empty. Records without a real name usually
 * hold an auto-generated hash; the rkey is the slug Tangled uses
 * for the URL. Returns the wrapper unchanged if the URI can't be
 * parsed, so the caller can still pass it to the view.
 */
export function resolve_repo_name(record) {
  let repo = record.value;
  let $ = repo.name;
  if ($ instanceof Some) {
    let name = $[0];
    if (name !== "") {
      return record;
    } else {
      let $1 = $atproto.rkey_from_uri(record.uri);
      if ($1 instanceof Ok) {
        let rkey = $1[0];
        return new DecodedRecord(
          record.uri,
          record.cid,
          new Repo(
            repo.created_at,
            repo.description,
            new Some(rkey),
            repo.repo_did,
            repo.topics,
            repo.website,
          ),
        );
      } else {
        return record;
      }
    }
  } else {
    let $1 = $atproto.rkey_from_uri(record.uri);
    if ($1 instanceof Ok) {
      let rkey = $1[0];
      return new DecodedRecord(
        record.uri,
        record.cid,
        new Repo(
          repo.created_at,
          repo.description,
          new Some(rkey),
          repo.repo_did,
          repo.topics,
          repo.website,
        ),
      );
    } else {
      return record;
    }
  }
}

/**
 * Drop repo records whose `repo_did` isn't in the pinned list.
 */
export function filter_repos_by_did(records, pinned_dids) {
  return $list.filter(
    records,
    (record) => { return $list.contains(pinned_dids, record.value.repo_did); },
  );
}

/**
 * Extract non-empty pinned DIDs from one or more actor profile
 * records. Tangled pads the list with empty rkeys as placeholders;
 * those are dropped.
 */
export function pinned_dids_from_profiles(records) {
  let _pipe = records;
  return $list.flat_map(
    _pipe,
    (record) => {
      let _pipe$1 = record.value.pinned_repositories;
      let _pipe$2 = unwrap(_pipe$1, $List$Empty$const);
      return $list.filter(_pipe$2, (did) => { return did !== ""; });
    },
  );
}
