-module(gose@internal@key_extract).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/internal/key_extract.gleam").
-export([rsa_private_key/1, rsa_public_key/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(false).

-file("src/gose/internal/key_extract.gleam", 7).
?DOC(false).
-spec rsa_private_key(gose:key_material()) -> {ok, kryptos@rsa:private_key()} |
    {error, nil}.
rsa_private_key(Material) ->
    case Material of
        {rsa, {rsa_private, Private, _}} ->
            {ok, Private};

        _ ->
            {error, nil}
    end.

-file("src/gose/internal/key_extract.gleam", 16).
?DOC(false).
-spec rsa_public_key(gose:key_material()) -> {ok, kryptos@rsa:public_key()} |
    {error, nil}.
rsa_public_key(Material) ->
    case Material of
        {rsa, {rsa_private, _, Public}} ->
            {ok, Public};

        {rsa, {rsa_public, Public@1}} ->
            {ok, Public@1};

        _ ->
            {error, nil}
    end.
