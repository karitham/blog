import * as $dynamic from "../gleam_stdlib/gleam/dynamic.mjs";
import * as $decode from "../gleam_stdlib/gleam/dynamic/decode.mjs";
import * as $list from "../gleam_stdlib/gleam/list.mjs";
import * as $result from "../gleam_stdlib/gleam/result.mjs";
import {
  toList,
  List$Empty$const as $List$Empty$const,
  CustomType as $CustomType,
} from "./gleam.mjs";

export class OneMonth extends $CustomType {}
export const Range$OneMonth$const = new OneMonth();
export const Range$OneMonth = () => Range$OneMonth$const;
export const Range$isOneMonth = (value) => value instanceof OneMonth;

export class SixMonths extends $CustomType {}
export const Range$SixMonths$const = new SixMonths();
export const Range$SixMonths = () => Range$SixMonths$const;
export const Range$isSixMonths = (value) => value instanceof SixMonths;

export class OneYear extends $CustomType {}
export const Range$OneYear$const = new OneYear();
export const Range$OneYear = () => Range$OneYear$const;
export const Range$isOneYear = (value) => value instanceof OneYear;

export class AllTime extends $CustomType {}
export const Range$AllTime$const = new AllTime();
export const Range$AllTime = () => Range$AllTime$const;
export const Range$isAllTime = (value) => value instanceof AllTime;

export class StatsData extends $CustomType {
  constructor(ranges) {
    super();
    this.ranges = ranges;
  }
}
export const StatsData$StatsData = (ranges) => new StatsData(ranges);
export const StatsData$isStatsData = (value) => value instanceof StatsData;
export const StatsData$StatsData$ranges = (value) => value.ranges;
export const StatsData$StatsData$0 = (value) => value.ranges;

export class RangeStats extends $CustomType {
  constructor(artists, albums, tracks) {
    super();
    this.artists = artists;
    this.albums = albums;
    this.tracks = tracks;
  }
}
export const RangeStats$RangeStats = (artists, albums, tracks) =>
  new RangeStats(artists, albums, tracks);
export const RangeStats$isRangeStats = (value) => value instanceof RangeStats;
export const RangeStats$RangeStats$artists = (value) => value.artists;
export const RangeStats$RangeStats$0 = (value) => value.artists;
export const RangeStats$RangeStats$albums = (value) => value.albums;
export const RangeStats$RangeStats$1 = (value) => value.albums;
export const RangeStats$RangeStats$tracks = (value) => value.tracks;
export const RangeStats$RangeStats$2 = (value) => value.tracks;

export class StatsItem extends $CustomType {
  constructor(name, artist, plays, ms_played, image, url) {
    super();
    this.name = name;
    this.artist = artist;
    this.plays = plays;
    this.ms_played = ms_played;
    this.image = image;
    this.url = url;
  }
}
export const StatsItem$StatsItem = (name, artist, plays, ms_played, image, url) =>
  new StatsItem(name, artist, plays, ms_played, image, url);
export const StatsItem$isStatsItem = (value) => value instanceof StatsItem;
export const StatsItem$StatsItem$name = (value) => value.name;
export const StatsItem$StatsItem$0 = (value) => value.name;
export const StatsItem$StatsItem$artist = (value) => value.artist;
export const StatsItem$StatsItem$1 = (value) => value.artist;
export const StatsItem$StatsItem$plays = (value) => value.plays;
export const StatsItem$StatsItem$2 = (value) => value.plays;
export const StatsItem$StatsItem$ms_played = (value) => value.ms_played;
export const StatsItem$StatsItem$3 = (value) => value.ms_played;
export const StatsItem$StatsItem$image = (value) => value.image;
export const StatsItem$StatsItem$4 = (value) => value.image;
export const StatsItem$StatsItem$url = (value) => value.url;
export const StatsItem$StatsItem$5 = (value) => value.url;

export function all_ranges() {
  return toList([
    Range$OneMonth$const,
    Range$SixMonths$const,
    Range$OneYear$const,
    Range$AllTime$const,
  ]);
}

/**
 * JSON key; also the `data-range` attribute value in the view.
 */
export function range_key(range) {
  if (range instanceof OneMonth) {
    return "1m";
  } else if (range instanceof SixMonths) {
    return "6m";
  } else if (range instanceof OneYear) {
    return "1y";
  } else {
    return "all";
  }
}

export function range_label(range) {
  if (range instanceof OneMonth) {
    return "1 month";
  } else if (range instanceof SixMonths) {
    return "6 months";
  } else if (range instanceof OneYear) {
    return "1 year";
  } else {
    return "all time";
  }
}

export function empty_stats() {
  return new StatsData($List$Empty$const);
}

export function empty_range_stats() {
  return new RangeStats($List$Empty$const, $List$Empty$const, $List$Empty$const);
}

function stats_item_decoder() {
  return $decode.field(
    "name",
    $decode.string,
    (name) => {
      return $decode.optional_field(
        "artist",
        "",
        $decode.string,
        (artist) => {
          return $decode.field(
            "plays",
            $decode.int,
            (plays) => {
              return $decode.field(
                "ms_played",
                $decode.int,
                (ms_played) => {
                  return $decode.optional_field(
                    "image",
                    "",
                    $decode.string,
                    (image) => {
                      return $decode.optional_field(
                        "url",
                        "",
                        $decode.string,
                        (url) => {
                          return $decode.success(
                            new StatsItem(
                              name,
                              artist,
                              plays,
                              ms_played,
                              image,
                              url,
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

function range_stats_decoder() {
  return $decode.field(
    "artists",
    $decode.list(stats_item_decoder()),
    (artists) => {
      return $decode.field(
        "albums",
        $decode.list(stats_item_decoder()),
        (albums) => {
          return $decode.field(
            "tracks",
            $decode.list(stats_item_decoder()),
            (tracks) => {
              return $decode.success(new RangeStats(artists, albums, tracks));
            },
          );
        },
      );
    },
  );
}

/**
 * Decode each of the four range keys from the `ranges` object,
 * defaulting to empty when a key is missing.
 * 
 * @ignore
 */
function decode_ranges(ranges) {
  return $list.map(
    all_ranges(),
    (range) => {
      let decoded = $decode.run(
        ranges,
        $decode.optionally_at(
          toList([range_key(range)]),
          empty_range_stats(),
          range_stats_decoder(),
        ),
      );
      return [range, $result.unwrap(decoded, empty_range_stats())];
    },
  );
}

export function stats_data_decoder() {
  return $decode.field(
    "ranges",
    $decode.dynamic,
    (ranges) => { return $decode.success(new StatsData(decode_ranges(ranges))); },
  );
}

/**
 * Is there anything to show? The view hides the aside when false.
 */
export function is_empty(stats) {
  let _pipe = stats.ranges;
  return $list.all(
    _pipe,
    (pair) => {
      let range_stats = pair[1];
      return ($list.is_empty(range_stats.artists) && $list.is_empty(
        range_stats.albums,
      )) && $list.is_empty(range_stats.tracks);
    },
  );
}
