import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $internal from "../../gen/internal.mjs";
import { prepend as listPrepend, CustomType as $CustomType } from "../../gleam.mjs";

export class ActorProfile extends $CustomType {
  constructor(pinned_repositories) {
    super();
    this.pinned_repositories = pinned_repositories;
  }
}
export const ActorProfile$ActorProfile = (pinned_repositories) =>
  new ActorProfile(pinned_repositories);
export const ActorProfile$isActorProfile = (value) =>
  value instanceof ActorProfile;
export const ActorProfile$ActorProfile$pinned_repositories = (value) =>
  value.pinned_repositories;
export const ActorProfile$ActorProfile$0 = (value) => value.pinned_repositories;

export const collection = "sh.tangled.actor.profile";

export function actor_profile_fields(value) {
  return $internal.opt(
    "pinnedRepositories",
    value.pinned_repositories,
    (items) => { return $json.array(items, $json.string); },
  );
}

export function encode_actor_profile(value) {
  return $json.object(
    listPrepend(
      ["$type", $json.string("sh.tangled.actor.profile")],
      actor_profile_fields(value),
    ),
  );
}

export function actor_profile_decoder() {
  return $decode.optional_field(
    "pinnedRepositories",
    new $option.None(),
    $decode.optional($decode.list($decode.string)),
    (pinned_repositories) => {
      return $decode.success(new ActorProfile(pinned_repositories));
    },
  );
}
