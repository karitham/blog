-module(atproto@oauth@metadata).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/oauth/metadata.gleam").
-export([fetch_protected_resource/2, fetch_authorization_server/2, discover/2]).
-export_type([auth_server_metadata/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " atproto OAuth discovery: from a user's PDS, find the authorization server\n"
    " and its endpoints. Two hops of well-known metadata:\n"
    "   PDS /.well-known/oauth-protected-resource -> authorization_servers[]\n"
    "   issuer /.well-known/oauth-authorization-server -> endpoints\n"
).

-type auth_server_metadata() :: {auth_server_metadata,
        binary(),
        binary(),
        binary(),
        binary(),
        gleam@option:option(binary())}.

-file("src/atproto/oauth/metadata.gleam", 22).
-spec protected_resource_decoder() -> gleam@dynamic@decode:decoder(list(binary())).
protected_resource_decoder() ->
    gleam@dynamic@decode:at(
        [<<"authorization_servers"/utf8>>],
        gleam@dynamic@decode:list(
            {decoder, fun gleam@dynamic@decode:decode_string/1}
        )
    ).

-file("src/atproto/oauth/metadata.gleam", 26).
-spec auth_server_decoder() -> gleam@dynamic@decode:decoder(auth_server_metadata()).
auth_server_decoder() ->
    gleam@dynamic@decode:field(
        <<"issuer"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(Issuer) ->
            gleam@dynamic@decode:field(
                <<"authorization_endpoint"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(Authorization_endpoint) ->
                    gleam@dynamic@decode:field(
                        <<"token_endpoint"/utf8>>,
                        {decoder, fun gleam@dynamic@decode:decode_string/1},
                        fun(Token_endpoint) ->
                            gleam@dynamic@decode:field(
                                <<"pushed_authorization_request_endpoint"/utf8>>,
                                {decoder,
                                    fun gleam@dynamic@decode:decode_string/1},
                                fun(Par) ->
                                    gleam@dynamic@decode:optional_field(
                                        <<"revocation_endpoint"/utf8>>,
                                        none,
                                        gleam@dynamic@decode:optional(
                                            {decoder,
                                                fun gleam@dynamic@decode:decode_string/1}
                                        ),
                                        fun(Revocation_endpoint) ->
                                            gleam@dynamic@decode:success(
                                                {auth_server_metadata,
                                                    Issuer,
                                                    Authorization_endpoint,
                                                    Token_endpoint,
                                                    Par,
                                                    Revocation_endpoint}
                                            )
                                        end
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/atproto/oauth/metadata.gleam", 51).
-spec fetch_protected_resource(atproto@xrpc:client(), binary()) -> {ok,
        list(binary())} |
    {error, atproto@xrpc:xrpc_error()}.
fetch_protected_resource(Client, Pds) ->
    Url = <<Pds/binary, "/.well-known/oauth-protected-resource"/utf8>>,
    gleam@result:'try'(
        atproto@xrpc:get(Client, Url, none),
        fun(Resp) ->
            atproto@xrpc:parse(
                erlang:element(4, Resp),
                protected_resource_decoder()
            )
        end
    ).

-file("src/atproto/oauth/metadata.gleam", 60).
-spec fetch_authorization_server(atproto@xrpc:client(), binary()) -> {ok,
        auth_server_metadata()} |
    {error, atproto@xrpc:xrpc_error()}.
fetch_authorization_server(Client, Issuer) ->
    Url = <<Issuer/binary, "/.well-known/oauth-authorization-server"/utf8>>,
    gleam@result:'try'(
        atproto@xrpc:get(Client, Url, none),
        fun(Resp) ->
            atproto@xrpc:parse(erlang:element(4, Resp), auth_server_decoder())
        end
    ).

-file("src/atproto/oauth/metadata.gleam", 70).
?DOC(" Resolve a PDS to its authorization server's endpoints in one call.\n").
-spec discover(atproto@xrpc:client(), binary()) -> {ok, auth_server_metadata()} |
    {error, atproto@xrpc:xrpc_error()}.
discover(Client, Pds) ->
    gleam@result:'try'(
        fetch_protected_resource(Client, Pds),
        fun(Servers) ->
            gleam@result:'try'(
                gleam@result:replace_error(
                    gleam@list:first(Servers),
                    {decode_failed,
                        <<"no authorization_servers in protected-resource metadata"/utf8>>}
                ),
                fun(Issuer) -> fetch_authorization_server(Client, Issuer) end
            )
        end
    ).
