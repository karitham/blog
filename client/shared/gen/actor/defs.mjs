import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $internal from "../../gen/internal.mjs";
import { toList, CustomType as $CustomType } from "../../gleam.mjs";

export class ProfileViewDetailed extends $CustomType {
  constructor(avatar, banner, description, did, display_name, followers_count, follows_count, handle, posts_count, pronouns) {
    super();
    this.avatar = avatar;
    this.banner = banner;
    this.description = description;
    this.did = did;
    this.display_name = display_name;
    this.followers_count = followers_count;
    this.follows_count = follows_count;
    this.handle = handle;
    this.posts_count = posts_count;
    this.pronouns = pronouns;
  }
}
export const ProfileViewDetailed$ProfileViewDetailed = (avatar, banner, description, did, display_name, followers_count, follows_count, handle, posts_count, pronouns) =>
  new ProfileViewDetailed(avatar,
  banner,
  description,
  did,
  display_name,
  followers_count,
  follows_count,
  handle,
  posts_count,
  pronouns);
export const ProfileViewDetailed$isProfileViewDetailed = (value) =>
  value instanceof ProfileViewDetailed;
export const ProfileViewDetailed$ProfileViewDetailed$avatar = (value) =>
  value.avatar;
export const ProfileViewDetailed$ProfileViewDetailed$0 = (value) =>
  value.avatar;
export const ProfileViewDetailed$ProfileViewDetailed$banner = (value) =>
  value.banner;
export const ProfileViewDetailed$ProfileViewDetailed$1 = (value) =>
  value.banner;
export const ProfileViewDetailed$ProfileViewDetailed$description = (value) =>
  value.description;
export const ProfileViewDetailed$ProfileViewDetailed$2 = (value) =>
  value.description;
export const ProfileViewDetailed$ProfileViewDetailed$did = (value) => value.did;
export const ProfileViewDetailed$ProfileViewDetailed$3 = (value) => value.did;
export const ProfileViewDetailed$ProfileViewDetailed$display_name = (value) =>
  value.display_name;
export const ProfileViewDetailed$ProfileViewDetailed$4 = (value) =>
  value.display_name;
export const ProfileViewDetailed$ProfileViewDetailed$followers_count = (value) =>
  value.followers_count;
export const ProfileViewDetailed$ProfileViewDetailed$5 = (value) =>
  value.followers_count;
export const ProfileViewDetailed$ProfileViewDetailed$follows_count = (value) =>
  value.follows_count;
export const ProfileViewDetailed$ProfileViewDetailed$6 = (value) =>
  value.follows_count;
export const ProfileViewDetailed$ProfileViewDetailed$handle = (value) =>
  value.handle;
export const ProfileViewDetailed$ProfileViewDetailed$7 = (value) =>
  value.handle;
export const ProfileViewDetailed$ProfileViewDetailed$posts_count = (value) =>
  value.posts_count;
export const ProfileViewDetailed$ProfileViewDetailed$8 = (value) =>
  value.posts_count;
export const ProfileViewDetailed$ProfileViewDetailed$pronouns = (value) =>
  value.pronouns;
export const ProfileViewDetailed$ProfileViewDetailed$9 = (value) =>
  value.pronouns;

export function profile_view_detailed_fields(value) {
  return $list.flatten(
    toList([
      toList([
        ["did", $json.string(value.did)],
        ["handle", $json.string(value.handle)],
      ]),
      $internal.opt("avatar", value.avatar, $json.string),
      $internal.opt("banner", value.banner, $json.string),
      $internal.opt("description", value.description, $json.string),
      $internal.opt("displayName", value.display_name, $json.string),
      $internal.opt("followersCount", value.followers_count, $json.int),
      $internal.opt("followsCount", value.follows_count, $json.int),
      $internal.opt("postsCount", value.posts_count, $json.int),
      $internal.opt("pronouns", value.pronouns, $json.string),
    ]),
  );
}

export function encode_profile_view_detailed(value) {
  return $json.object(profile_view_detailed_fields(value));
}

export function profile_view_detailed_decoder() {
  return $decode.optional_field(
    "avatar",
    $option.Option$None$const,
    $decode.optional($decode.string),
    (avatar) => {
      return $decode.optional_field(
        "banner",
        $option.Option$None$const,
        $decode.optional($decode.string),
        (banner) => {
          return $decode.optional_field(
            "description",
            $option.Option$None$const,
            $decode.optional($decode.string),
            (description) => {
              return $decode.field(
                "did",
                $decode.string,
                (did) => {
                  return $decode.optional_field(
                    "displayName",
                    $option.Option$None$const,
                    $decode.optional($decode.string),
                    (display_name) => {
                      return $decode.optional_field(
                        "followersCount",
                        $option.Option$None$const,
                        $decode.optional($decode.int),
                        (followers_count) => {
                          return $decode.optional_field(
                            "followsCount",
                            $option.Option$None$const,
                            $decode.optional($decode.int),
                            (follows_count) => {
                              return $decode.field(
                                "handle",
                                $decode.string,
                                (handle) => {
                                  return $decode.optional_field(
                                    "postsCount",
                                    $option.Option$None$const,
                                    $decode.optional($decode.int),
                                    (posts_count) => {
                                      return $decode.optional_field(
                                        "pronouns",
                                        $option.Option$None$const,
                                        $decode.optional($decode.string),
                                        (pronouns) => {
                                          return $decode.success(
                                            new ProfileViewDetailed(
                                              avatar,
                                              banner,
                                              description,
                                              did,
                                              display_name,
                                              followers_count,
                                              follows_count,
                                              handle,
                                              posts_count,
                                              pronouns,
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
                },
              );
            },
          );
        },
      );
    },
  );
}
