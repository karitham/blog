-module(atproto@identity).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/identity.gleam").
-export([resolve_mini_doc/3, resolve_pds/3]).
-export_type([mini_doc/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Resolve a handle or DID to its PDS endpoint via an injected\n"
    " Slingshot-compatible `resolveMiniDoc` resolver. This is not native atproto\n"
    " identity resolution (DID doc / PLC / did:web / DNS); consumers depend on the\n"
    " resolver service being available.\n"
).

-type mini_doc() :: {mini_doc, binary(), binary()}.

-file("src/atproto/identity.gleam", 27).
-spec resolve_mini_doc(atproto@xrpc:client(), binary(), binary()) -> {ok,
        mini_doc()} |
    {error, atproto@xrpc:xrpc_error()}.
resolve_mini_doc(Client, Resolver, Identifier) ->
    Query = gleam@uri:query_to_string([{<<"identifier"/utf8>>, Identifier}]),
    Url = <<<<Resolver/binary,
            "/xrpc/com.bad-example.identity.resolveMiniDoc?"/utf8>>/binary,
        Query/binary>>,
    gleam@result:'try'(
        atproto@xrpc:get(Client, Url, none),
        fun(Resp) ->
            Decoder = begin
                gleam@dynamic@decode:field(
                    <<"did"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Did) ->
                        gleam@dynamic@decode:field(
                            <<"pds"/utf8>>,
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            fun(Pds) ->
                                gleam@dynamic@decode:success(
                                    {mini_doc, Did, Pds}
                                )
                            end
                        )
                    end
                )
            end,
            atproto@xrpc:parse(erlang:element(4, Resp), Decoder)
        end
    ).

-file("src/atproto/identity.gleam", 18).
-spec resolve_pds(atproto@xrpc:client(), binary(), binary()) -> {ok, binary()} |
    {error, atproto@xrpc:xrpc_error()}.
resolve_pds(Client, Resolver, Identifier) ->
    _pipe = resolve_mini_doc(Client, Resolver, Identifier),
    gleam@result:map(_pipe, fun(Doc) -> erlang:element(3, Doc) end).
