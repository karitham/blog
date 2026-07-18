-module(atproto@oauth@resource).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/oauth/resource.gleam").
-export([client/3]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " DPoP-authenticated resource requests: wraps a transport so every request\n"
    " carries `Authorization: DPoP <token>` and a proof bound to its method, URL,\n"
    " and access-token hash, with the server-nonce retry. Token refresh is the\n"
    " caller's job (it owns session persistence); this module only signs.\n"
).

-file("src/atproto/oauth/resource.gleam", 79).
-spec send_once(
    atproto@xrpc:client(),
    binary(),
    gose:key(binary()),
    gleam@http@request:request(bitstring()),
    binary(),
    binary(),
    binary(),
    gleam@option:option(binary())
) -> {ok, gleam@http@response:response(bitstring())} | {error, binary()}.
send_once(Base, Access_token, Dpop_key, Req, Method, Target, Ath, Nonce) ->
    gleam@result:'try'(
        atproto@oauth@dpop:proof(Dpop_key, Method, Target, Nonce, {some, Ath}),
        fun(Proof) -> _pipe = Req,
            _pipe@1 = gleam@http@request:set_header(
                _pipe,
                <<"authorization"/utf8>>,
                <<"DPoP "/utf8, Access_token/binary>>
            ),
            _pipe@2 = gleam@http@request:set_header(
                _pipe@1,
                <<"dpop"/utf8>>,
                Proof
            ),
            (erlang:element(2, Base))(_pipe@2) end
    ).

-file("src/atproto/oauth/resource.gleam", 66).
-spec as_text(gleam@http@response:response(bitstring())) -> gleam@http@response:response(binary()).
as_text(Resp) ->
    Json_body = case gleam@http@response:get_header(
        Resp,
        <<"content-type"/utf8>>
    ) of
        {ok, Content_type} ->
            gleam_stdlib:string_starts_with(
                Content_type,
                <<"application/json"/utf8>>
            );

        {error, nil} ->
            false
    end,
    gleam@http@response:map(Resp, fun(Body) -> case Json_body of
                true ->
                    _pipe = gleam@bit_array:to_string(Body),
                    gleam@result:unwrap(_pipe, <<""/utf8>>);

                false ->
                    <<""/utf8>>
            end end).

-file("src/atproto/oauth/resource.gleam", 108).
-spec b64(bitstring()) -> binary().
b64(Bits) ->
    gleam@bit_array:base64_url_encode(Bits, false).

-file("src/atproto/oauth/resource.gleam", 103).
?DOC(" The DPoP `htu`: the request URI without query or fragment.\n").
-spec htu(gleam@http@request:request(any())) -> binary().
htu(Req) ->
    U = gleam@http@request:to_uri(Req),
    gleam@uri:to_string(
        {uri,
            erlang:element(2, U),
            erlang:element(3, U),
            erlang:element(4, U),
            erlang:element(5, U),
            erlang:element(6, U),
            none,
            none}
    ).

-file("src/atproto/oauth/resource.gleam", 29).
-spec dpop_send(
    atproto@xrpc:client(),
    binary(),
    gose:key(binary()),
    gleam@http@request:request(bitstring())
) -> {ok, gleam@http@response:response(bitstring())} | {error, binary()}.
dpop_send(Base, Access_token, Dpop_key, Req) ->
    Method = begin
        _pipe = gleam@http:method_to_string(erlang:element(2, Req)),
        string:uppercase(_pipe)
    end,
    Target = htu(Req),
    Ath = b64(gleam@crypto:hash(sha256, gleam_stdlib:identity(Access_token))),
    gleam@result:'try'(
        send_once(Base, Access_token, Dpop_key, Req, Method, Target, Ath, none),
        fun(First) ->
            case atproto@oauth@transport:dpop_nonce_challenge(as_text(First)) of
                {some, Nonce} ->
                    send_once(
                        Base,
                        Access_token,
                        Dpop_key,
                        Req,
                        Method,
                        Target,
                        Ath,
                        {some, Nonce}
                    );

                none ->
                    {ok, First}
            end
        end
    ).

-file("src/atproto/oauth/resource.gleam", 21).
?DOC(" A client that signs every request against the given DPoP-bound access token.\n").
-spec client(atproto@xrpc:client(), binary(), gose:key(binary())) -> atproto@xrpc:client().
client(Base, Access_token, Dpop_key) ->
    {client, fun(Req) -> dpop_send(Base, Access_token, Dpop_key, Req) end}.
