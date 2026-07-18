import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import { toList, CustomType as $CustomType } from "../../gleam.mjs";

export class RepoStrongRef extends $CustomType {
  constructor(cid, uri) {
    super();
    this.cid = cid;
    this.uri = uri;
  }
}
export const RepoStrongRef$RepoStrongRef = (cid, uri) =>
  new RepoStrongRef(cid, uri);
export const RepoStrongRef$isRepoStrongRef = (value) =>
  value instanceof RepoStrongRef;
export const RepoStrongRef$RepoStrongRef$cid = (value) => value.cid;
export const RepoStrongRef$RepoStrongRef$0 = (value) => value.cid;
export const RepoStrongRef$RepoStrongRef$uri = (value) => value.uri;
export const RepoStrongRef$RepoStrongRef$1 = (value) => value.uri;

export function repo_strong_ref_fields(value) {
  return toList([
    ["cid", $json.string(value.cid)],
    ["uri", $json.string(value.uri)],
  ]);
}

export function encode_repo_strong_ref(value) {
  return $json.object(repo_strong_ref_fields(value));
}

export function repo_strong_ref_decoder() {
  return $decode.field(
    "cid",
    $decode.string,
    (cid) => {
      return $decode.field(
        "uri",
        $decode.string,
        (uri) => { return $decode.success(new RepoStrongRef(cid, uri)); },
      );
    },
  );
}
