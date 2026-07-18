-module(atproto@oauth@tokens).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/oauth/tokens.gleam").
-export([exchange_code/5, refresh/6, revoke/6]).
-export_type([tokens/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Token endpoint calls: exchange an authorization code for DPoP-bound tokens,\n"
    " refresh them with the rotating refresh token, and best-effort revocation.\n"
    " Confidential clients pass client-assertion fields via `extra_form`.\n"
).

-type tokens() :: {tokens, binary(), binary(), binary(), integer()}.

-file("src/atproto/oauth/tokens.gleam", 135).
-spec describe(atproto@xrpc:xrpc_error()) -> binary().
describe(E) ->
    case E of
        {decode_failed, M} ->
            <<"decode token response: "/utf8, M/binary>>;

        {request_failed, M@1} ->
            M@1;

        {bad_status, Status, _, _, Body} ->
            <<<<(erlang:integer_to_binary(Status))/binary, ": "/utf8>>/binary,
                Body/binary>>
    end.

-file("src/atproto/oauth/tokens.gleam", 127).
-spec decoder() -> gleam@dynamic@decode:decoder(tokens()).
decoder() ->
    gleam@dynamic@decode:field(
        <<"access_token"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(Access_token) ->
            gleam@dynamic@decode:field(
                <<"refresh_token"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(Refresh_token) ->
                    gleam@dynamic@decode:field(
                        <<"sub"/utf8>>,
                        {decoder, fun gleam@dynamic@decode:decode_string/1},
                        fun(Sub) ->
                            gleam@dynamic@decode:optional_field(
                                <<"expires_in"/utf8>>,
                                3600,
                                {decoder, fun gleam@dynamic@decode:decode_int/1},
                                fun(Expires_in) ->
                                    gleam@dynamic@decode:success(
                                        {tokens,
                                            Access_token,
                                            Refresh_token,
                                            Sub,
                                            Expires_in}
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/atproto/oauth/tokens.gleam", 109).
-spec submit(
    atproto@xrpc:client(),
    binary(),
    gose:key(binary()),
    list({binary(), binary()})
) -> {ok, tokens()} | {error, binary()}.
submit(Client, Token_endpoint, Dpop_key, Form) ->
    gleam@result:'try'(
        atproto@oauth@transport:post_form_with_dpop(
            Client,
            Token_endpoint,
            Form,
            Dpop_key
        ),
        fun(Resp) ->
            case (erlang:element(2, Resp) >= 200) andalso (erlang:element(
                2,
                Resp
            )
            < 300) of
                true ->
                    _pipe = atproto@xrpc:parse(
                        erlang:element(4, Resp),
                        decoder()
                    ),
                    gleam@result:map_error(_pipe, fun describe/1);

                false ->
                    {error,
                        <<<<<<"token "/utf8,
                                    (erlang:integer_to_binary(
                                        erlang:element(2, Resp)
                                    ))/binary>>/binary,
                                ": "/utf8>>/binary,
                            (erlang:element(4, Resp))/binary>>}
            end
        end
    ).

-file("src/atproto/oauth/tokens.gleam", 25).
-spec exchange_code(
    atproto@xrpc:client(),
    atproto@oauth@flow:flow(),
    binary(),
    binary(),
    list({binary(), binary()})
) -> {ok, tokens()} | {error, binary()}.
exchange_code(Client, Flow, Code, Redirect_uri, Extra_form) ->
    submit(
        Client,
        erlang:element(5, Flow),
        erlang:element(6, Flow),
        lists:append(
            [{<<"grant_type"/utf8>>, <<"authorization_code"/utf8>>},
                {<<"code"/utf8>>, Code},
                {<<"code_verifier"/utf8>>, erlang:element(7, Flow)},
                {<<"redirect_uri"/utf8>>, Redirect_uri},
                {<<"client_id"/utf8>>, erlang:element(8, Flow)}],
            Extra_form
        )
    ).

-file("src/atproto/oauth/tokens.gleam", 49).
-spec refresh(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    gose:key(binary()),
    list({binary(), binary()})
) -> {ok, tokens()} | {error, binary()}.
refresh(Client, Token_endpoint, Refresh_token, Client_id, Dpop_key, Extra_form) ->
    submit(
        Client,
        Token_endpoint,
        Dpop_key,
        lists:append(
            [{<<"grant_type"/utf8>>, <<"refresh_token"/utf8>>},
                {<<"refresh_token"/utf8>>, Refresh_token},
                {<<"client_id"/utf8>>, Client_id}],
            Extra_form
        )
    ).

-file("src/atproto/oauth/tokens.gleam", 75).
?DOC(
    " Best-effort refresh-token revocation at logout: discover the AS revocation\n"
    " endpoint from the issuer and revoke. Failures are ignored (the caller\n"
    " clears its local session regardless).\n"
).
-spec revoke(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    gose:key(binary()),
    list({binary(), binary()})
) -> nil.
revoke(Client, Issuer, Refresh_token, Client_id, Dpop_key, Extra_form) ->
    case atproto@oauth@metadata:fetch_authorization_server(Client, Issuer) of
        {ok, Meta} ->
            case erlang:element(6, Meta) of
                {some, Endpoint} ->
                    _ = atproto@oauth@transport:post_form_with_dpop(
                        Client,
                        Endpoint,
                        lists:append(
                            [{<<"token"/utf8>>, Refresh_token},
                                {<<"token_type_hint"/utf8>>,
                                    <<"refresh_token"/utf8>>},
                                {<<"client_id"/utf8>>, Client_id}],
                            Extra_form
                        ),
                        Dpop_key
                    ),
                    nil;

                _ ->
                    nil
            end;

        {error, _} ->
            nil
    end.
