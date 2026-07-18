-module(atproto@oauth@transport).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/oauth/transport.gleam").
-export([dpop_nonce_challenge/1, post_form_with_dpop/4]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Shared OAuth transport: a form-encoded POST carrying a DPoP proof, with the\n"
    " mandatory nonce retry (first attempt no nonce, retry with the server's\n"
    " DPoP-Nonce on `use_dpop_nonce`). The response is returned as-is.\n"
).

-file("src/atproto/oauth/transport.gleam", 46).
-spec attempt(
    atproto@xrpc:client(),
    binary(),
    list({binary(), binary()}),
    gose:key(binary()),
    gleam@option:option(binary())
) -> {ok, gleam@http@response:response(binary())} | {error, binary()}.
attempt(Client, Url, Form, Dpop_key, Nonce) ->
    gleam@result:'try'(
        atproto@oauth@dpop:proof(Dpop_key, <<"POST"/utf8>>, Url, Nonce, none),
        fun(Proof) ->
            gleam@result:'try'(
                begin
                    _pipe = gleam@http@request:to(Url),
                    gleam@result:replace_error(
                        _pipe,
                        <<"bad url: "/utf8, Url/binary>>
                    )
                end,
                fun(Base) -> _pipe@1 = Base,
                    _pipe@2 = gleam@http@request:set_method(_pipe@1, post),
                    _pipe@3 = gleam@http@request:set_header(
                        _pipe@2,
                        <<"content-type"/utf8>>,
                        <<"application/x-www-form-urlencoded"/utf8>>
                    ),
                    _pipe@4 = gleam@http@request:set_header(
                        _pipe@3,
                        <<"dpop"/utf8>>,
                        Proof
                    ),
                    _pipe@5 = gleam@http@request:set_body(
                        _pipe@4,
                        gleam@uri:query_to_string(Form)
                    ),
                    atproto@xrpc:send_text(Client, _pipe@5) end
            )
        end
    ).

-file("src/atproto/oauth/transport.gleam", 33).
?DOC(
    " The DPoP nonce a server is asking us to use, if it rejected the request with\n"
    " `use_dpop_nonce`. The authorization server (PAR/token) signals this in the\n"
    " JSON body; the PDS resource server signals it in the `WWW-Authenticate`\n"
    " header. Either way the nonce itself comes in the `DPoP-Nonce` header.\n"
).
-spec dpop_nonce_challenge(gleam@http@response:response(binary())) -> gleam@option:option(binary()).
dpop_nonce_challenge(Resp) ->
    Stale = (erlang:element(2, Resp) =:= 400) orelse (erlang:element(2, Resp)
    =:= 401),
    Www_auth = begin
        _pipe = gleam@http@response:get_header(
            Resp,
            <<"www-authenticate"/utf8>>
        ),
        gleam@result:unwrap(_pipe, <<""/utf8>>)
    end,
    Signaled = gleam_stdlib:contains_string(
        erlang:element(4, Resp),
        <<"use_dpop_nonce"/utf8>>
    )
    orelse gleam_stdlib:contains_string(Www_auth, <<"use_dpop_nonce"/utf8>>),
    case Stale andalso Signaled of
        true ->
            gleam@option:from_result(
                gleam@http@response:get_header(Resp, <<"dpop-nonce"/utf8>>)
            );

        false ->
            none
    end.

-file("src/atproto/oauth/transport.gleam", 16).
-spec post_form_with_dpop(
    atproto@xrpc:client(),
    binary(),
    list({binary(), binary()}),
    gose:key(binary())
) -> {ok, gleam@http@response:response(binary())} | {error, binary()}.
post_form_with_dpop(Client, Url, Form, Dpop_key) ->
    gleam@result:'try'(
        attempt(Client, Url, Form, Dpop_key, none),
        fun(First) -> case dpop_nonce_challenge(First) of
                {some, Nonce} ->
                    attempt(Client, Url, Form, Dpop_key, {some, Nonce});

                none ->
                    {ok, First}
            end end
    ).
