import * as $fetch from "./fetch.mjs";
import * as $defs from "./gen/actor/defs.mjs";
import * as $play from "./gen/alpha/feed/play.mjs";
import * as $repo from "./gen/repo.mjs";
import { CustomType as $CustomType } from "./gleam.mjs";

export class HydrationModel extends $CustomType {
  constructor(profile, plays, repos) {
    super();
    this.profile = profile;
    this.plays = plays;
    this.repos = repos;
  }
}
export const HydrationModel$HydrationModel = (profile, plays, repos) =>
  new HydrationModel(profile, plays, repos);
export const HydrationModel$isHydrationModel = (value) =>
  value instanceof HydrationModel;
export const HydrationModel$HydrationModel$profile = (value) => value.profile;
export const HydrationModel$HydrationModel$0 = (value) => value.profile;
export const HydrationModel$HydrationModel$plays = (value) => value.plays;
export const HydrationModel$HydrationModel$1 = (value) => value.plays;
export const HydrationModel$HydrationModel$repos = (value) => value.repos;
export const HydrationModel$HydrationModel$2 = (value) => value.repos;
