-module(atproto@auth).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/auth.gleam").
-export([create_session/4, refresh_session/3]).
-export_type([session_tokens/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " atproto session auth: exchange an identifier + password for session tokens\n"
    " via `com.atproto.server.createSession`, and refresh them via\n"
    " `com.atproto.server.refreshSession`.\n"
).

-type session_tokens() :: {session_tokens,
        binary(),
        binary(),
        binary(),
        binary()}.

-file("src/atproto/auth.gleam", 56).
-spec tokens_decoder() -> gleam@dynamic@decode:decoder(session_tokens()).
tokens_decoder() ->
    gleam@dynamic@decode:field(
        <<"did"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(Did) ->
            gleam@dynamic@decode:field(
                <<"handle"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(Handle) ->
                    gleam@dynamic@decode:field(
                        <<"accessJwt"/utf8>>,
                        {decoder, fun gleam@dynamic@decode:decode_string/1},
                        fun(Access_jwt) ->
                            gleam@dynamic@decode:field(
                                <<"refreshJwt"/utf8>>,
                                {decoder,
                                    fun gleam@dynamic@decode:decode_string/1},
                                fun(Refresh_jwt) ->
                                    gleam@dynamic@decode:success(
                                        {session_tokens,
                                            Did,
                                            Handle,
                                            Access_jwt,
                                            Refresh_jwt}
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/atproto/auth.gleam", 20).
-spec create_session(atproto@xrpc:client(), binary(), binary(), binary()) -> {ok,
        session_tokens()} |
    {error, atproto@xrpc:xrpc_error()}.
create_session(Client, Pds, Identifier, Password) ->
    Body = gleam@json:object(
        [{<<"identifier"/utf8>>, gleam@json:string(Identifier)},
            {<<"password"/utf8>>, gleam@json:string(Password)}]
    ),
    gleam@result:'try'(
        atproto@xrpc:post_json(
            Client,
            <<Pds/binary, "/xrpc/com.atproto.server.createSession"/utf8>>,
            none,
            Body
        ),
        fun(Resp) ->
            atproto@xrpc:parse(erlang:element(4, Resp), tokens_decoder())
        end
    ).

-file("src/atproto/auth.gleam", 42).
?DOC(
    " Exchange a refresh JWT for a fresh session (the refresh token is sent as the\n"
    " bearer credential, per `com.atproto.server.refreshSession`).\n"
).
-spec refresh_session(atproto@xrpc:client(), binary(), binary()) -> {ok,
        session_tokens()} |
    {error, atproto@xrpc:xrpc_error()}.
refresh_session(Client, Pds, Refresh_jwt) ->
    gleam@result:'try'(
        atproto@xrpc:post_json(
            Client,
            <<Pds/binary, "/xrpc/com.atproto.server.refreshSession"/utf8>>,
            {some, Refresh_jwt},
            gleam@json:object([])
        ),
        fun(Resp) ->
            atproto@xrpc:parse(erlang:element(4, Resp), tokens_decoder())
        end
    ).
