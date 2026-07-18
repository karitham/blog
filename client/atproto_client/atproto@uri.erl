-module(atproto@uri).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/uri.gleam").
-export([rkey/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(" Helpers for at-uris (`at://<did>/<collection>/<rkey>`).\n").

-file("src/atproto/uri.gleam", 8).
?DOC(" The record key is the last `/`-separated segment of an at-uri.\n").
-spec rkey(binary()) -> binary().
rkey(At_uri) ->
    _pipe = At_uri,
    _pipe@1 = gleam@string:split(_pipe, <<"/"/utf8>>),
    _pipe@2 = gleam@list:last(_pipe@1),
    gleam@result:unwrap(_pipe@2, <<""/utf8>>).
