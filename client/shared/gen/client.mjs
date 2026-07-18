import * as $xrpc from "../../atproto_client/atproto/xrpc.mjs";
import * as $decode from "../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $int from "../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../gleam_stdlib/gleam/option.mjs";
import * as $result from "../../gleam_stdlib/gleam/result.mjs";
import * as $uri from "../../gleam_stdlib/gleam/uri.mjs";
import * as $actor_defs from "../gen/actor/defs.mjs";
import * as $repo_list_records from "../gen/repo/list_records.mjs";
import { toList, CustomType as $CustomType } from "../gleam.mjs";

export class ActorGetProfileTransport extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const ActorGetProfileError$ActorGetProfileTransport = ($0) =>
  new ActorGetProfileTransport($0);
export const ActorGetProfileError$isActorGetProfileTransport = (value) =>
  value instanceof ActorGetProfileTransport;
export const ActorGetProfileError$ActorGetProfileTransport$0 = (value) =>
  value[0];

export class ActorGetProfileUnexpected extends $CustomType {
  constructor(status, message, body) {
    super();
    this.status = status;
    this.message = message;
    this.body = body;
  }
}
export const ActorGetProfileError$ActorGetProfileUnexpected = (status, message, body) =>
  new ActorGetProfileUnexpected(status, message, body);
export const ActorGetProfileError$isActorGetProfileUnexpected = (value) =>
  value instanceof ActorGetProfileUnexpected;
export const ActorGetProfileError$ActorGetProfileUnexpected$status = (value) =>
  value.status;
export const ActorGetProfileError$ActorGetProfileUnexpected$0 = (value) =>
  value.status;
export const ActorGetProfileError$ActorGetProfileUnexpected$message = (value) =>
  value.message;
export const ActorGetProfileError$ActorGetProfileUnexpected$1 = (value) =>
  value.message;
export const ActorGetProfileError$ActorGetProfileUnexpected$body = (value) =>
  value.body;
export const ActorGetProfileError$ActorGetProfileUnexpected$2 = (value) =>
  value.body;

export class ActorGetProfileParams extends $CustomType {
  constructor(actor) {
    super();
    this.actor = actor;
  }
}
export const ActorGetProfileParams$ActorGetProfileParams = (actor) =>
  new ActorGetProfileParams(actor);
export const ActorGetProfileParams$isActorGetProfileParams = (value) =>
  value instanceof ActorGetProfileParams;
export const ActorGetProfileParams$ActorGetProfileParams$actor = (value) =>
  value.actor;
export const ActorGetProfileParams$ActorGetProfileParams$0 = (value) =>
  value.actor;

export class RepoListRecordsTransport extends $CustomType {
  constructor($0) {
    super();
    this[0] = $0;
  }
}
export const RepoListRecordsError$RepoListRecordsTransport = ($0) =>
  new RepoListRecordsTransport($0);
export const RepoListRecordsError$isRepoListRecordsTransport = (value) =>
  value instanceof RepoListRecordsTransport;
export const RepoListRecordsError$RepoListRecordsTransport$0 = (value) =>
  value[0];

export class RepoListRecordsUnexpected extends $CustomType {
  constructor(status, message, body) {
    super();
    this.status = status;
    this.message = message;
    this.body = body;
  }
}
export const RepoListRecordsError$RepoListRecordsUnexpected = (status, message, body) =>
  new RepoListRecordsUnexpected(status, message, body);
export const RepoListRecordsError$isRepoListRecordsUnexpected = (value) =>
  value instanceof RepoListRecordsUnexpected;
export const RepoListRecordsError$RepoListRecordsUnexpected$status = (value) =>
  value.status;
export const RepoListRecordsError$RepoListRecordsUnexpected$0 = (value) =>
  value.status;
export const RepoListRecordsError$RepoListRecordsUnexpected$message = (value) =>
  value.message;
export const RepoListRecordsError$RepoListRecordsUnexpected$1 = (value) =>
  value.message;
export const RepoListRecordsError$RepoListRecordsUnexpected$body = (value) =>
  value.body;
export const RepoListRecordsError$RepoListRecordsUnexpected$2 = (value) =>
  value.body;

export class RepoListRecordsParams extends $CustomType {
  constructor(collection, cursor, limit, repo, reverse) {
    super();
    this.collection = collection;
    this.cursor = cursor;
    this.limit = limit;
    this.repo = repo;
    this.reverse = reverse;
  }
}
export const RepoListRecordsParams$RepoListRecordsParams = (collection, cursor, limit, repo, reverse) =>
  new RepoListRecordsParams(collection, cursor, limit, repo, reverse);
export const RepoListRecordsParams$isRepoListRecordsParams = (value) =>
  value instanceof RepoListRecordsParams;
export const RepoListRecordsParams$RepoListRecordsParams$collection = (value) =>
  value.collection;
export const RepoListRecordsParams$RepoListRecordsParams$0 = (value) =>
  value.collection;
export const RepoListRecordsParams$RepoListRecordsParams$cursor = (value) =>
  value.cursor;
export const RepoListRecordsParams$RepoListRecordsParams$1 = (value) =>
  value.cursor;
export const RepoListRecordsParams$RepoListRecordsParams$limit = (value) =>
  value.limit;
export const RepoListRecordsParams$RepoListRecordsParams$2 = (value) =>
  value.limit;
export const RepoListRecordsParams$RepoListRecordsParams$repo = (value) =>
  value.repo;
export const RepoListRecordsParams$RepoListRecordsParams$3 = (value) =>
  value.repo;
export const RepoListRecordsParams$RepoListRecordsParams$reverse = (value) =>
  value.reverse;
export const RepoListRecordsParams$RepoListRecordsParams$4 = (value) =>
  value.reverse;

export class RepoListRecordsOutput extends $CustomType {
  constructor(cursor, records) {
    super();
    this.cursor = cursor;
    this.records = records;
  }
}
export const RepoListRecordsOutput$RepoListRecordsOutput = (cursor, records) =>
  new RepoListRecordsOutput(cursor, records);
export const RepoListRecordsOutput$isRepoListRecordsOutput = (value) =>
  value instanceof RepoListRecordsOutput;
export const RepoListRecordsOutput$RepoListRecordsOutput$cursor = (value) =>
  value.cursor;
export const RepoListRecordsOutput$RepoListRecordsOutput$0 = (value) =>
  value.cursor;
export const RepoListRecordsOutput$RepoListRecordsOutput$records = (value) =>
  value.records;
export const RepoListRecordsOutput$RepoListRecordsOutput$1 = (value) =>
  value.records;

function map_actor_get_profile_error(err) {
  if (err instanceof $xrpc.RequestFailed) {
    return new ActorGetProfileTransport(err);
  } else if (err instanceof $xrpc.BadStatus) {
    let status = err.status;
    let message = err.message;
    let body = err.body;
    return new ActorGetProfileUnexpected(status, message, body);
  } else {
    return new ActorGetProfileTransport(err);
  }
}

export function actor_get_profile(client, service, params, token) {
  let query = $uri.query_to_string(
    $list.flatten(toList([toList([["actor", params.actor]])])),
  );
  let url = (service + "/xrpc/app.bsky.actor.getProfile?") + query;
  let _pipe = $xrpc.get(client, url, token);
  let _pipe$1 = $result.map_error(_pipe, map_actor_get_profile_error);
  return $result.try$(
    _pipe$1,
    (resp) => {
      let _pipe$2 = $xrpc.parse(
        resp.body,
        $actor_defs.profile_view_detailed_decoder(),
      );
      return $result.map_error(_pipe$2, map_actor_get_profile_error);
    },
  );
}

function map_repo_list_records_error(err) {
  if (err instanceof $xrpc.RequestFailed) {
    return new RepoListRecordsTransport(err);
  } else if (err instanceof $xrpc.BadStatus) {
    let status = err.status;
    let message = err.message;
    let body = err.body;
    return new RepoListRecordsUnexpected(status, message, body);
  } else {
    return new RepoListRecordsTransport(err);
  }
}

export function repo_list_records(client, service, params, token) {
  let query = $uri.query_to_string(
    $list.flatten(
      toList([
        toList([["collection", params.collection]]),
        (() => {
          let $ = params.cursor;
          if ($ instanceof $option.Some) {
            let v = $[0];
            return toList([["cursor", v]]);
          } else {
            return toList([]);
          }
        })(),
        (() => {
          let $ = params.limit;
          if ($ instanceof $option.Some) {
            let v = $[0];
            return toList([["limit", $int.to_string(v)]]);
          } else {
            return toList([]);
          }
        })(),
        toList([["repo", params.repo]]),
        (() => {
          let $ = params.reverse;
          if ($ instanceof $option.Some) {
            let v = $[0];
            return toList([
              [
                "reverse",
                (() => {
                  if (v) {
                    return "true";
                  } else {
                    return "false";
                  }
                })(),
              ],
            ]);
          } else {
            return toList([]);
          }
        })(),
      ]),
    ),
  );
  let url = (service + "/xrpc/com.atproto.repo.listRecords?") + query;
  let _pipe = $xrpc.get(client, url, token);
  let _pipe$1 = $result.map_error(_pipe, map_repo_list_records_error);
  return $result.try$(
    _pipe$1,
    (resp) => {
      let _pipe$2 = $xrpc.parse(resp.body, repo_list_records_output_decoder());
      return $result.map_error(_pipe$2, map_repo_list_records_error);
    },
  );
}

export function repo_list_records_output_decoder() {
  return $decode.optional_field(
    "cursor",
    new $option.None(),
    $decode.optional($decode.string),
    (cursor) => {
      return $decode.field(
        "records",
        $decode.list($repo_list_records.record_decoder()),
        (records) => {
          return $decode.success(new RepoListRecordsOutput(cursor, records));
        },
      );
    },
  );
}
