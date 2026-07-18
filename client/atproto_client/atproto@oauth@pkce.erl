-module(atproto@oauth@pkce).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/oauth/pkce.gleam").
-export([generate/0]).
-export_type([pkce/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " PKCE (RFC 7636, S256). A fresh verifier/challenge pair per authorization\n"
    " request; the caller holds the verifier until the token exchange.\n"
).

-type pkce() :: {pkce, binary(), binary()}.

-file("src/atproto/oauth/pkce.gleam", 18).
-spec b64(bitstring()) -> binary().
b64(Bits) ->
    gleam@bit_array:base64_url_encode(Bits, false).

-file("src/atproto/oauth/pkce.gleam", 11).
-spec generate() -> pkce().
generate() ->
    Verifier = b64(crypto:strong_rand_bytes(32)),
    Challenge = b64(gleam@crypto:hash(sha256, gleam_stdlib:identity(Verifier))),
    {pkce, Verifier, Challenge}.
