import * as $json from "../../../gleam_json/gleam/json.mjs";
import * as $decode from "../../../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $option from "../../../gleam_stdlib/gleam/option.mjs";
import * as $internal from "../../gen/internal.mjs";
import { toList, prepend as listPrepend, CustomType as $CustomType } from "../../gleam.mjs";

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

export class FeedPlay extends $CustomType {
  constructor(artists, duration, origin_uri, played_time, release_name, track_name) {
    super();
    this.artists = artists;
    this.duration = duration;
    this.origin_uri = origin_uri;
    this.played_time = played_time;
    this.release_name = release_name;
    this.track_name = track_name;
  }
}
export const FeedPlay$FeedPlay = (artists, duration, origin_uri, played_time, release_name, track_name) =>
  new FeedPlay(artists,
  duration,
  origin_uri,
  played_time,
  release_name,
  track_name);
export const FeedPlay$isFeedPlay = (value) => value instanceof FeedPlay;
export const FeedPlay$FeedPlay$artists = (value) => value.artists;
export const FeedPlay$FeedPlay$0 = (value) => value.artists;
export const FeedPlay$FeedPlay$duration = (value) => value.duration;
export const FeedPlay$FeedPlay$1 = (value) => value.duration;
export const FeedPlay$FeedPlay$origin_uri = (value) => value.origin_uri;
export const FeedPlay$FeedPlay$2 = (value) => value.origin_uri;
export const FeedPlay$FeedPlay$played_time = (value) => value.played_time;
export const FeedPlay$FeedPlay$3 = (value) => value.played_time;
export const FeedPlay$FeedPlay$release_name = (value) => value.release_name;
export const FeedPlay$FeedPlay$4 = (value) => value.release_name;
export const FeedPlay$FeedPlay$track_name = (value) => value.track_name;
export const FeedPlay$FeedPlay$5 = (value) => value.track_name;

export const collection = "fm.teal.feed.play";

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

export function feed_play_fields(value) {
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
      $internal.opt("originUri", value.origin_uri, $json.string),
      $internal.opt("releaseName", value.release_name, $json.string),
    ]),
  );
}

export function encode_feed_play(value) {
  return $json.object(
    listPrepend(
      ["$type", $json.string("fm.teal.feed.play")],
      feed_play_fields(value),
    ),
  );
}

export function feed_play_decoder() {
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
            "originUri",
            $option.Option$None$const,
            $decode.optional($decode.string),
            (origin_uri) => {
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
                            new FeedPlay(
                              artists,
                              duration,
                              origin_uri,
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
