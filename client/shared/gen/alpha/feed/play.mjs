import * as $json from "../../../../gleam_json/gleam/json.mjs";
import * as $decode from "../../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../../gleam_stdlib/gleam/option.mjs";
import * as $internal from "../../../gen/internal.mjs";
import { toList, prepend as listPrepend, CustomType as $CustomType } from "../../../gleam.mjs";

export class ArtistView extends $CustomType {
  constructor(artist_mb_id, artist_name) {
    super();
    this.artist_mb_id = artist_mb_id;
    this.artist_name = artist_name;
  }
}
export const ArtistView$ArtistView = (artist_mb_id, artist_name) =>
  new ArtistView(artist_mb_id, artist_name);
export const ArtistView$isArtistView = (value) => value instanceof ArtistView;
export const ArtistView$ArtistView$artist_mb_id = (value) => value.artist_mb_id;
export const ArtistView$ArtistView$0 = (value) => value.artist_mb_id;
export const ArtistView$ArtistView$artist_name = (value) => value.artist_name;
export const ArtistView$ArtistView$1 = (value) => value.artist_name;

export class AlphaFeedPlay extends $CustomType {
  constructor(artists, duration, origin_url, played_time, release_name, track_name) {
    super();
    this.artists = artists;
    this.duration = duration;
    this.origin_url = origin_url;
    this.played_time = played_time;
    this.release_name = release_name;
    this.track_name = track_name;
  }
}
export const AlphaFeedPlay$AlphaFeedPlay = (artists, duration, origin_url, played_time, release_name, track_name) =>
  new AlphaFeedPlay(artists,
  duration,
  origin_url,
  played_time,
  release_name,
  track_name);
export const AlphaFeedPlay$isAlphaFeedPlay = (value) =>
  value instanceof AlphaFeedPlay;
export const AlphaFeedPlay$AlphaFeedPlay$artists = (value) => value.artists;
export const AlphaFeedPlay$AlphaFeedPlay$0 = (value) => value.artists;
export const AlphaFeedPlay$AlphaFeedPlay$duration = (value) => value.duration;
export const AlphaFeedPlay$AlphaFeedPlay$1 = (value) => value.duration;
export const AlphaFeedPlay$AlphaFeedPlay$origin_url = (value) =>
  value.origin_url;
export const AlphaFeedPlay$AlphaFeedPlay$2 = (value) => value.origin_url;
export const AlphaFeedPlay$AlphaFeedPlay$played_time = (value) =>
  value.played_time;
export const AlphaFeedPlay$AlphaFeedPlay$3 = (value) => value.played_time;
export const AlphaFeedPlay$AlphaFeedPlay$release_name = (value) =>
  value.release_name;
export const AlphaFeedPlay$AlphaFeedPlay$4 = (value) => value.release_name;
export const AlphaFeedPlay$AlphaFeedPlay$track_name = (value) =>
  value.track_name;
export const AlphaFeedPlay$AlphaFeedPlay$5 = (value) => value.track_name;

export const collection = "fm.teal.alpha.feed.play";

export function artist_view_fields(value) {
  return $list.flatten(
    toList([
      toList([["artistName", $json.string(value.artist_name)]]),
      $internal.opt("artistMbId", value.artist_mb_id, $json.string),
    ]),
  );
}

export function encode_artist_view(value) {
  return $json.object(artist_view_fields(value));
}

export function artist_view_decoder() {
  return $decode.optional_field(
    "artistMbId",
    $option.Option$None$const,
    $decode.optional($decode.string),
    (artist_mb_id) => {
      return $decode.field(
        "artistName",
        $decode.string,
        (artist_name) => {
          return $decode.success(new ArtistView(artist_mb_id, artist_name));
        },
      );
    },
  );
}

export function alpha_feed_play_fields(value) {
  return $list.flatten(
    toList([
      toList([
        [
          "artists",
          ((items) => { return $json.array(items, encode_artist_view); })(
            value.artists,
          ),
        ],
        ["playedTime", $json.string(value.played_time)],
        ["trackName", $json.string(value.track_name)],
      ]),
      $internal.opt("duration", value.duration, $json.int),
      $internal.opt("originUrl", value.origin_url, $json.string),
      $internal.opt("releaseName", value.release_name, $json.string),
    ]),
  );
}

export function encode_alpha_feed_play(value) {
  return $json.object(
    listPrepend(
      ["$type", $json.string("fm.teal.alpha.feed.play")],
      alpha_feed_play_fields(value),
    ),
  );
}

export function alpha_feed_play_decoder() {
  return $decode.field(
    "artists",
    $decode.list(artist_view_decoder()),
    (artists) => {
      return $decode.optional_field(
        "duration",
        $option.Option$None$const,
        $decode.optional($decode.int),
        (duration) => {
          return $decode.optional_field(
            "originUrl",
            $option.Option$None$const,
            $decode.optional($decode.string),
            (origin_url) => {
              return $decode.field(
                "playedTime",
                $decode.string,
                (played_time) => {
                  return $decode.optional_field(
                    "releaseName",
                    $option.Option$None$const,
                    $decode.optional($decode.string),
                    (release_name) => {
                      return $decode.field(
                        "trackName",
                        $decode.string,
                        (track_name) => {
                          return $decode.success(
                            new AlphaFeedPlay(
                              artists,
                              duration,
                              origin_url,
                              played_time,
                              release_name,
                              track_name,
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
