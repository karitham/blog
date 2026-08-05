import * as $option from "../gleam_stdlib/gleam/option.mjs";
import { Some, Option$None$const } from "../gleam_stdlib/gleam/option.mjs";
import * as $string from "../gleam_stdlib/gleam/string.mjs";
import * as $should from "../gleeunit/gleeunit/should.mjs";
import * as $defs from "../shared/gen/actor/defs.mjs";
import { ProfileViewDetailed } from "../shared/gen/actor/defs.mjs";
import * as $play from "../shared/gen/alpha/feed/play.mjs";
import { AlphaFeedPlay, ArtistView } from "../shared/gen/alpha/feed/play.mjs";
import * as $repo from "../shared/gen/repo.mjs";
import { Repo } from "../shared/gen/repo.mjs";
import * as $commit from "./commit.mjs";
import {
  toList,
  Empty as $Empty,
  List$Empty$const as $List$Empty$const,
  makeError,
} from "./gleam.mjs";
import * as $pipeline from "./pipeline.mjs";

const FILEPATH = "test/pipeline_test.gleam";

function sample_profile() {
  return new ProfileViewDetailed(
    new Some("https://example.com/avatar.jpg"),
    Option$None$const,
    new Some("round-trip"),
    "did:plc:test",
    new Some("Test User"),
    Option$None$const,
    Option$None$const,
    "test.bsky.social",
    Option$None$const,
    Option$None$const,
  );
}

function sample_play() {
  return new AlphaFeedPlay(
    toList([new ArtistView(new Some(""), "Artist 1")]),
    new Some(180),
    new Some("https://example.com/a"),
    "2026-07-18T10:00:00Z",
    new Some("Album A"),
    "Track A",
  );
}

function sample_repos() {
  return toList([
    new Repo(
      "2026-01-01T00:00:00Z",
      new Some("first"),
      new Some("repo-one"),
      "did:plc:one",
      new Some(toList(["gleam"])),
      Option$None$const,
    ),
  ]);
}

export function plan_profile_replaces_section_and_rewrites_images_test() {
  let $ = $pipeline.plan_profile(sample_profile());
  let id;
  let html;
  if ($ instanceof $Empty) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "pipeline_test",
      50,
      "plan_profile_replaces_section_and_rewrites_images_test",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 1287,
        end: 1402,
        pattern_start: 1298,
        pattern_end: 1356
      }
    )
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      throw makeError(
        "let_assert",
        FILEPATH,
        "pipeline_test",
        50,
        "plan_profile_replaces_section_and_rewrites_images_test",
        "Pattern match failed, no pattern matched the value.",
        {
          value: $,
          start: 1287,
          end: 1402,
          pattern_start: 1298,
          pattern_end: 1356
        }
      )
    } else {
      let $2 = $1.tail;
      if ($2 instanceof $Empty) {
        let $3 = $.head;
        if ($3 instanceof $commit.ReplaceHtml) {
          let $4 = $1.head;
          if ($4 instanceof $commit.RewriteRemoteImages) {
            id = $3.id;
            html = $3.html;
          } else {
            throw makeError(
              "let_assert",
              FILEPATH,
              "pipeline_test",
              50,
              "plan_profile_replaces_section_and_rewrites_images_test",
              "Pattern match failed, no pattern matched the value.",
              {
                value: $,
                start: 1287,
                end: 1402,
                pattern_start: 1298,
                pattern_end: 1356
              }
            )
          }
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "pipeline_test",
            50,
            "plan_profile_replaces_section_and_rewrites_images_test",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $,
              start: 1287,
              end: 1402,
              pattern_start: 1298,
              pattern_end: 1356
            }
          )
        }
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "pipeline_test",
          50,
          "plan_profile_replaces_section_and_rewrites_images_test",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 1287,
            end: 1402,
            pattern_start: 1298,
            pattern_end: 1356
          }
        )
      }
    }
  }
  let _pipe = id;
  $should.equal(_pipe, "profile-section");
  let _pipe$1 = $string.contains(html, "Test User");
  return $should.be_true(_pipe$1);
}

export function plan_repos_replaces_section_test() {
  let $ = $pipeline.plan_repos(sample_repos());
  let id;
  let html;
  if ($ instanceof $Empty) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "pipeline_test",
      57,
      "plan_repos_replaces_section_test",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 1549,
        end: 1632,
        pattern_start: 1560,
        pattern_end: 1590
      }
    )
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      let $2 = $.head;
      if ($2 instanceof $commit.ReplaceHtml) {
        id = $2.id;
        html = $2.html;
      } else {
        throw makeError(
          "let_assert",
          FILEPATH,
          "pipeline_test",
          57,
          "plan_repos_replaces_section_test",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 1549,
            end: 1632,
            pattern_start: 1560,
            pattern_end: 1590
          }
        )
      }
    } else {
      throw makeError(
        "let_assert",
        FILEPATH,
        "pipeline_test",
        57,
        "plan_repos_replaces_section_test",
        "Pattern match failed, no pattern matched the value.",
        {
          value: $,
          start: 1549,
          end: 1632,
          pattern_start: 1560,
          pattern_end: 1590
        }
      )
    }
  }
  let _pipe = id;
  $should.equal(_pipe, "repos");
  let _pipe$1 = $string.contains(html, "repo-one");
  return $should.be_true(_pipe$1);
}

export function plan_plays_renders_rows_then_localizes_and_clears_stale_test() {
  let $ = $pipeline.plan_plays(toList([sample_play()]));
  let id;
  let html;
  let rid;
  let name;
  if ($ instanceof $Empty) {
    throw makeError(
      "let_assert",
      FILEPATH,
      "pipeline_test",
      64,
      "plan_plays_renders_rows_then_localizes_and_clears_stale_test",
      "Pattern match failed, no pattern matched the value.",
      {
        value: $,
        start: 1796,
        end: 1945,
        pattern_start: 1807,
        pattern_end: 1906
      }
    )
  } else {
    let $1 = $.tail;
    if ($1 instanceof $Empty) {
      throw makeError(
        "let_assert",
        FILEPATH,
        "pipeline_test",
        64,
        "plan_plays_renders_rows_then_localizes_and_clears_stale_test",
        "Pattern match failed, no pattern matched the value.",
        {
          value: $,
          start: 1796,
          end: 1945,
          pattern_start: 1807,
          pattern_end: 1906
        }
      )
    } else {
      let $2 = $1.tail;
      if ($2 instanceof $Empty) {
        throw makeError(
          "let_assert",
          FILEPATH,
          "pipeline_test",
          64,
          "plan_plays_renders_rows_then_localizes_and_clears_stale_test",
          "Pattern match failed, no pattern matched the value.",
          {
            value: $,
            start: 1796,
            end: 1945,
            pattern_start: 1807,
            pattern_end: 1906
          }
        )
      } else {
        let $3 = $2.tail;
        if ($3 instanceof $Empty) {
          let $4 = $.head;
          if ($4 instanceof $commit.ReplaceHtml) {
            let $5 = $1.head;
            if ($5 instanceof $commit.LocalizeDates) {
              let $6 = $2.head;
              if ($6 instanceof $commit.RemoveAttr) {
                id = $4.id;
                html = $4.html;
                rid = $6.id;
                name = $6.name;
              } else {
                throw makeError(
                  "let_assert",
                  FILEPATH,
                  "pipeline_test",
                  64,
                  "plan_plays_renders_rows_then_localizes_and_clears_stale_test",
                  "Pattern match failed, no pattern matched the value.",
                  {
                    value: $,
                    start: 1796,
                    end: 1945,
                    pattern_start: 1807,
                    pattern_end: 1906
                  }
                )
              }
            } else {
              throw makeError(
                "let_assert",
                FILEPATH,
                "pipeline_test",
                64,
                "plan_plays_renders_rows_then_localizes_and_clears_stale_test",
                "Pattern match failed, no pattern matched the value.",
                {
                  value: $,
                  start: 1796,
                  end: 1945,
                  pattern_start: 1807,
                  pattern_end: 1906
                }
              )
            }
          } else {
            throw makeError(
              "let_assert",
              FILEPATH,
              "pipeline_test",
              64,
              "plan_plays_renders_rows_then_localizes_and_clears_stale_test",
              "Pattern match failed, no pattern matched the value.",
              {
                value: $,
                start: 1796,
                end: 1945,
                pattern_start: 1807,
                pattern_end: 1906
              }
            )
          }
        } else {
          throw makeError(
            "let_assert",
            FILEPATH,
            "pipeline_test",
            64,
            "plan_plays_renders_rows_then_localizes_and_clears_stale_test",
            "Pattern match failed, no pattern matched the value.",
            {
              value: $,
              start: 1796,
              end: 1945,
              pattern_start: 1807,
              pattern_end: 1906
            }
          )
        }
      }
    }
  }
  let _pipe = id;
  $should.equal(_pipe, "plays-rows");
  let _pipe$1 = $string.contains(html, "Track A");
  $should.be_true(_pipe$1);
  let _pipe$2 = rid;
  $should.equal(_pipe$2, "plays");
  let _pipe$3 = name;
  return $should.equal(_pipe$3, "data-stale");
}

export function plan_plays_empty_clears_stale_without_rendering_test() {
  let _pipe = $pipeline.plan_plays($List$Empty$const);
  return $should.equal(
    _pipe,
    toList([new $commit.RemoveAttr("plays", "data-stale")]),
  );
}

export function mark_plays_stale_sets_the_flag_test() {
  let _pipe = $pipeline.mark_plays_stale();
  return $should.equal(
    _pipe,
    toList([new $commit.SetAttr("plays", "data-stale", "true")]),
  );
}
