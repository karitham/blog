-module(gose@cose@algorithm).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/algorithm.gleam").
-export([signature_alg_to_int/1, signature_alg_from_int/1, mac_alg_to_int/1, mac_alg_from_int/1, signing_alg_to_int/1, signing_alg_from_int/1, key_encryption_alg_to_int/1, key_encryption_alg_from_int/1, content_alg_to_int/1, content_alg_from_int/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Deprecated: use the `gose/cose` module instead.\n"
    "\n"
    " This module re-exports the COSE algorithm integer-conversion functions\n"
    " from `gose/cose` for the v2.x migration window. It will be removed in\n"
    " v3.0. New code should import `gose/cose` directly.\n"
).

-file("src/gose/cose/algorithm.gleam", 11).
-spec signature_alg_to_int(gose:digital_signature_alg()) -> integer().
signature_alg_to_int(Alg) ->
    gose@cose:signature_alg_to_int(Alg).

-file("src/gose/cose/algorithm.gleam", 16).
-spec signature_alg_from_int(integer()) -> {ok, gose:digital_signature_alg()} |
    {error, gose:gose_error()}.
signature_alg_from_int(Id) ->
    gose@cose:signature_alg_from_int(Id).

-file("src/gose/cose/algorithm.gleam", 23).
-spec mac_alg_to_int(gose:mac_alg()) -> integer().
mac_alg_to_int(Alg) ->
    gose@cose:mac_alg_to_int(Alg).

-file("src/gose/cose/algorithm.gleam", 28).
-spec mac_alg_from_int(integer()) -> {ok, gose:mac_alg()} |
    {error, gose:gose_error()}.
mac_alg_from_int(Id) ->
    gose@cose:mac_alg_from_int(Id).

-file("src/gose/cose/algorithm.gleam", 33).
-spec signing_alg_to_int(gose:signing_alg()) -> integer().
signing_alg_to_int(Alg) ->
    gose@cose:signing_alg_to_int(Alg).

-file("src/gose/cose/algorithm.gleam", 38).
-spec signing_alg_from_int(integer()) -> {ok, gose:signing_alg()} |
    {error, gose:gose_error()}.
signing_alg_from_int(Id) ->
    gose@cose:signing_alg_from_int(Id).

-file("src/gose/cose/algorithm.gleam", 43).
-spec key_encryption_alg_to_int(gose:key_encryption_alg()) -> {ok, integer()} |
    {error, gose:gose_error()}.
key_encryption_alg_to_int(Alg) ->
    gose@cose:key_encryption_alg_to_int(Alg).

-file("src/gose/cose/algorithm.gleam", 50).
-spec key_encryption_alg_from_int(integer()) -> {ok, gose:key_encryption_alg()} |
    {error, gose:gose_error()}.
key_encryption_alg_from_int(Id) ->
    gose@cose:key_encryption_alg_from_int(Id).

-file("src/gose/cose/algorithm.gleam", 57).
-spec content_alg_to_int(gose:content_alg()) -> {ok, integer()} |
    {error, gose:gose_error()}.
content_alg_to_int(Alg) ->
    gose@cose:content_alg_to_int(Alg).

-file("src/gose/cose/algorithm.gleam", 62).
-spec content_alg_from_int(integer()) -> {ok, gose:content_alg()} |
    {error, gose:gose_error()}.
content_alg_from_int(Id) ->
    gose@cose:content_alg_from_int(Id).
