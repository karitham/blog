-module(atproto@oauth@flow).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/oauth/flow.gleam").
-export([start/7]).
-export_type([flow/0, flow_error/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Start an authorization flow: resolve the PDS, discover the authorization\n"
    " server, push the request (PAR) with PKCE + DPoP, return the authorization\n"
    " URL and the pending `Flow` the caller must hold (server-side by state, or\n"
    " in-process for a CLI) until the callback returns with the code.\n"
    "\n"
    " Confidential clients pass their client-assertion fields via `extra_form`;\n"
    " public and loopback clients pass an empty list.\n"
).

-type flow() :: {flow,
        binary(),
        binary(),
        binary(),
        binary(),
        gose:key(binary()),
        binary(),
        binary(),
        binary()}.

-type flow_error() :: {resolve_failed, binary()} |
    {discover_failed, binary()} |
    {par_failed, binary()} |
    {dpop_failed, binary()}.

-file("src/atproto/oauth/flow.gleam", 107).
-spec push_par(
    atproto@xrpc:client(),
    atproto@oauth@metadata:auth_server_metadata(),
    list({binary(), binary()}),
    gose:key(binary())
) -> {ok, binary()} | {error, flow_error()}.
push_par(Client, Meta, Form, Dpop_key) ->
    gleam@result:'try'(
        begin
            _pipe = atproto@oauth@transport:post_form_with_dpop(
                Client,
                erlang:element(5, Meta),
                Form,
                Dpop_key
            ),
            gleam@result:map_error(
                _pipe,
                fun(Field@0) -> {par_failed, Field@0} end
            )
        end,
        fun(Resp) ->
            case (erlang:element(2, Resp) >= 200) andalso (erlang:element(
                2,
                Resp
            )
            < 300) of
                true ->
                    _pipe@1 = atproto@xrpc:parse(
                        erlang:element(4, Resp),
                        gleam@dynamic@decode:at(
                            [<<"request_uri"/utf8>>],
                            {decoder, fun gleam@dynamic@decode:decode_string/1}
                        )
                    ),
                    gleam@result:map_error(
                        _pipe@1,
                        fun(E) -> {par_failed, gleam@string:inspect(E)} end
                    );

                false ->
                    {error,
                        {par_failed,
                            <<<<<<"PAR "/utf8,
                                        (erlang:integer_to_binary(
                                            erlang:element(2, Resp)
                                        ))/binary>>/binary,
                                    ": "/utf8>>/binary,
                                (erlang:element(4, Resp))/binary>>}}
            end
        end
    ).

-file("src/atproto/oauth/flow.gleam", 131).
-spec b64(bitstring()) -> binary().
b64(Bits) ->
    gleam@bit_array:base64_url_encode(Bits, false).

-file("src/atproto/oauth/flow.gleam", 48).
?DOC(
    " Returns the authorization-server URL to send the user to, and the pending\n"
    " flow. The caller must verify the callback's `state` against `flow.state`\n"
    " before exchanging the code.\n"
).
-spec start(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    binary(),
    binary(),
    list({binary(), binary()})
) -> {ok, {binary(), flow()}} | {error, flow_error()}.
start(Client, Resolver, Identifier, Client_id, Redirect_uri, Scope, Extra_form) ->
    gleam@result:'try'(
        begin
            _pipe = atproto@identity:resolve_pds(Client, Resolver, Identifier),
            gleam@result:map_error(
                _pipe,
                fun(E) -> {resolve_failed, gleam@string:inspect(E)} end
            )
        end,
        fun(Pds) ->
            gleam@result:'try'(
                begin
                    _pipe@1 = atproto@oauth@metadata:discover(Client, Pds),
                    gleam@result:map_error(
                        _pipe@1,
                        fun(E@1) ->
                            {discover_failed, gleam@string:inspect(E@1)}
                        end
                    )
                end,
                fun(Meta) ->
                    Pk = atproto@oauth@pkce:generate(),
                    Dpop_key = atproto@oauth@dpop:generate_key(),
                    State = b64(crypto:strong_rand_bytes(16)),
                    Form = lists:append(
                        [{<<"client_id"/utf8>>, Client_id},
                            {<<"response_type"/utf8>>, <<"code"/utf8>>},
                            {<<"code_challenge"/utf8>>, erlang:element(3, Pk)},
                            {<<"code_challenge_method"/utf8>>, <<"S256"/utf8>>},
                            {<<"redirect_uri"/utf8>>, Redirect_uri},
                            {<<"scope"/utf8>>, Scope},
                            {<<"state"/utf8>>, State},
                            {<<"login_hint"/utf8>>, Identifier}],
                        Extra_form
                    ),
                    gleam@result:'try'(
                        push_par(Client, Meta, Form, Dpop_key),
                        fun(Request_uri) ->
                            Flow = {flow,
                                Identifier,
                                Pds,
                                erlang:element(2, Meta),
                                erlang:element(4, Meta),
                                Dpop_key,
                                erlang:element(2, Pk),
                                Client_id,
                                State},
                            Redirect_url = <<<<(erlang:element(3, Meta))/binary,
                                    "?"/utf8>>/binary,
                                (gleam@uri:query_to_string(
                                    [{<<"client_id"/utf8>>, Client_id},
                                        {<<"request_uri"/utf8>>, Request_uri}]
                                ))/binary>>,
                            {ok, {Redirect_url, Flow}}
                        end
                    )
                end
            )
        end
    ).
