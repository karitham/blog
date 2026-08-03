import * as $json from "../../gleam_json/gleam/json.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import * as $internal from "../gen/internal.mjs";
import { toList, prepend as listPrepend, CustomType as $CustomType } from "../gleam.mjs";

export class Repo extends $CustomType {
  constructor(created_at, description, name, repo_did, topics, website) {
    super();
    this.created_at = created_at;
    this.description = description;
    this.name = name;
    this.repo_did = repo_did;
    this.topics = topics;
    this.website = website;
  }
}
export const Repo$Repo = (created_at, description, name, repo_did, topics, website) =>
  new Repo(created_at, description, name, repo_did, topics, website);
export const Repo$isRepo = (value) => value instanceof Repo;
export const Repo$Repo$created_at = (value) => value.created_at;
export const Repo$Repo$0 = (value) => value.created_at;
export const Repo$Repo$description = (value) => value.description;
export const Repo$Repo$1 = (value) => value.description;
export const Repo$Repo$name = (value) => value.name;
export const Repo$Repo$2 = (value) => value.name;
export const Repo$Repo$repo_did = (value) => value.repo_did;
export const Repo$Repo$3 = (value) => value.repo_did;
export const Repo$Repo$topics = (value) => value.topics;
export const Repo$Repo$4 = (value) => value.topics;
export const Repo$Repo$website = (value) => value.website;
export const Repo$Repo$5 = (value) => value.website;

export const collection = "sh.tangled.repo";

export function repo_fields(value) {
  return $list.flatten(
    toList([
      toList([
        ["createdAt", $json.string(value.created_at)],
        ["repoDid", $json.string(value.repo_did)],
      ]),
      $internal.opt("description", value.description, $json.string),
      $internal.opt("name", value.name, $json.string),
      $internal.opt(
        "topics",
        value.topics,
        (items) => { return $json.array(items, $json.string); },
      ),
      $internal.opt("website", value.website, $json.string),
    ]),
  );
}

export function encode_repo(value) {
  return $json.object(
    listPrepend(["$type", $json.string("sh.tangled.repo")], repo_fields(value)),
  );
}

export function repo_decoder() {
  return $decode.field(
    "createdAt",
    $decode.string,
    (created_at) => {
      return $decode.optional_field(
        "description",
        $option.Option$None$const,
        $decode.optional($decode.string),
        (description) => {
          return $decode.optional_field(
            "name",
            $option.Option$None$const,
            $decode.optional($decode.string),
            (name) => {
              return $decode.field(
                "repoDid",
                $decode.string,
                (repo_did) => {
                  return $decode.optional_field(
                    "topics",
                    $option.Option$None$const,
                    $decode.optional($decode.list($decode.string)),
                    (topics) => {
                      return $decode.optional_field(
                        "website",
                        $option.Option$None$const,
                        $decode.optional($decode.string),
                        (website) => {
                          return $decode.success(
                            new Repo(
                              created_at,
                              description,
                              name,
                              repo_did,
                              topics,
                              website,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}
