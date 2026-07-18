-module(gose@cose@key).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/key.gleam").
-export([to_cbor/1, from_cbor/1, to_cbor_map/1, from_cbor_map/1]).

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
    " This module is a shim that forwards the COSE_Key serialization\n"
    " surface to `gose/cose`. It will be removed in v3.0.\n"
).

-file("src/gose/cose/key.gleam", 15).
-spec to_cbor(gose:key(bitstring())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
to_cbor(K) ->
    gose@cose:key_to_cbor(K).

-file("src/gose/cose/key.gleam", 20).
-spec from_cbor(bitstring()) -> {ok, gose:key(bitstring())} |
    {error, gose:gose_error()}.
from_cbor(Data) ->
    gose@cose:key_from_cbor(Data).

-file("src/gose/cose/key.gleam", 25).
-spec to_cbor_map(gose:key(bitstring())) -> {ok,
        list({gose@cbor:value(), gose@cbor:value()})} |
    {error, gose:gose_error()}.
to_cbor_map(K) ->
    gose@cose:key_to_cbor_map(K).

-file("src/gose/cose/key.gleam", 32).
-spec from_cbor_map(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose:key(bitstring())} |
    {error, gose:gose_error()}.
from_cbor_map(Map) ->
    gose@cose:key_from_cbor_map(Map).
