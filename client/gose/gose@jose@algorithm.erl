-module(gose@jose@algorithm).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/algorithm.gleam").
-export([signing_alg_to_string/1, signing_alg_from_string/1, key_encryption_alg_to_string/1, key_encryption_alg_from_string/1, content_alg_to_string/1, content_alg_from_string/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Deprecated: use the `gose/jose` module instead.\n"
    "\n"
    " This module re-exports the JOSE algorithm string-conversion functions\n"
    " from `gose/jose` for the v2.x migration window. It will be removed in\n"
    " v3.0. New code should import `gose/jose` directly.\n"
).

-file("src/gose/jose/algorithm.gleam", 11).
-spec signing_alg_to_string(gose:signing_alg()) -> binary().
signing_alg_to_string(Alg) ->
    gose@jose:signing_alg_to_string(Alg).

-file("src/gose/jose/algorithm.gleam", 16).
-spec signing_alg_from_string(binary()) -> {ok, gose:signing_alg()} |
    {error, gose:gose_error()}.
signing_alg_from_string(Alg) ->
    gose@jose:signing_alg_from_string(Alg).

-file("src/gose/jose/algorithm.gleam", 23).
-spec key_encryption_alg_to_string(gose:key_encryption_alg()) -> binary().
key_encryption_alg_to_string(Alg) ->
    gose@jose:key_encryption_alg_to_string(Alg).

-file("src/gose/jose/algorithm.gleam", 28).
-spec key_encryption_alg_from_string(binary()) -> {ok,
        gose:key_encryption_alg()} |
    {error, gose:gose_error()}.
key_encryption_alg_from_string(Alg) ->
    gose@jose:key_encryption_alg_from_string(Alg).

-file("src/gose/jose/algorithm.gleam", 35).
-spec content_alg_to_string(gose:content_alg()) -> binary().
content_alg_to_string(Alg) ->
    gose@jose:content_alg_to_string(Alg).

-file("src/gose/jose/algorithm.gleam", 40).
-spec content_alg_from_string(binary()) -> {ok, gose:content_alg()} |
    {error, gose:gose_error()}.
content_alg_from_string(Alg) ->
    gose@jose:content_alg_from_string(Alg).
