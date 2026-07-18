-module(atproto@oauth@dpop).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/oauth/dpop.gleam").
-export([generate_key/0, bare_public_jwk/1, proof/5]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " DPoP proof JWTs (RFC 9449). A proof is bound to one HTTP method+URL, carries\n"
    " the public key in its header, and optionally a server nonce and the access\n"
    " token hash (`ath`). Signed ES256 with the per-flow DPoP key.\n"
).

-file("src/atproto/oauth/dpop.gleam", 19).
-spec generate_key() -> gose:key(binary()).
generate_key() ->
    gose:generate_ec(p256).

-file("src/atproto/oauth/dpop.gleam", 82).
-spec err({ok, AEAL} | {error, gose:gose_error()}) -> {ok, AEAL} |
    {error, binary()}.
err(R) ->
    gleam@result:map_error(R, fun gose:error_message/1).

-file("src/atproto/oauth/dpop.gleam", 71).
-spec push(
    list({binary(), gleam@json:json()}),
    binary(),
    gleam@option:option(binary())
) -> list({binary(), gleam@json:json()}).
push(Claims, Key, Value) ->
    case Value of
        {some, V} ->
            lists:append(Claims, [{Key, gleam@json:string(V)}]);

        none ->
            Claims
    end.

-file("src/atproto/oauth/dpop.gleam", 86).
-spec b64(bitstring()) -> binary().
b64(Bits) ->
    gleam@bit_array:base64_url_encode(Bits, false).

-file("src/atproto/oauth/dpop.gleam", 55).
?DOC(
    " The public key as a bare JWK (kty/crv/x/y), for embedding in a DPoP proof\n"
    " header.\n"
).
-spec bare_public_jwk(gose:key(binary())) -> {ok, gleam@json:json()} |
    {error, binary()}.
bare_public_jwk(Key) ->
    gleam@result:'try'(
        begin
            _pipe = gose:ec_public_key(Key),
            gleam@result:replace_error(_pipe, <<"not an EC key"/utf8>>)
        end,
        fun(Public) ->
            gleam@result:map(
                begin
                    _pipe@1 = gose:ec_raw_coordinates(Public, p256),
                    gleam@result:replace_error(
                        _pipe@1,
                        <<"bad EC coordinates"/utf8>>
                    )
                end,
                fun(_use0) ->
                    {X, Y} = _use0,
                    gleam@json:object(
                        [{<<"crv"/utf8>>, gleam@json:string(<<"P-256"/utf8>>)},
                            {<<"kty"/utf8>>, gleam@json:string(<<"EC"/utf8>>)},
                            {<<"x"/utf8>>, gleam@json:string(b64(X))},
                            {<<"y"/utf8>>, gleam@json:string(b64(Y))}]
                    )
                end
            )
        end
    ).

-file("src/atproto/oauth/dpop.gleam", 23).
-spec proof(
    gose:key(binary()),
    binary(),
    binary(),
    gleam@option:option(binary()),
    gleam@option:option(binary())
) -> {ok, binary()} | {error, binary()}.
proof(Key, Method, Url, Nonce, Ath) ->
    gleam@result:'try'(
        bare_public_jwk(Key),
        fun(Public_jwk) ->
            Jti = b64(crypto:strong_rand_bytes(16)),
            Iat = erlang:trunc(
                gleam@time@timestamp:to_unix_seconds(
                    gleam@time@timestamp:system_time()
                )
            ),
            Claims = begin
                _pipe = [{<<"jti"/utf8>>, gleam@json:string(Jti)},
                    {<<"htm"/utf8>>, gleam@json:string(Method)},
                    {<<"htu"/utf8>>, gleam@json:string(Url)},
                    {<<"iat"/utf8>>, gleam@json:int(Iat)}],
                _pipe@1 = push(_pipe, <<"nonce"/utf8>>, Nonce),
                push(_pipe@1, <<"ath"/utf8>>, Ath)
            end,
            Payload = begin
                _pipe@2 = gleam@json:object(Claims),
                _pipe@3 = gleam@json:to_string(_pipe@2),
                gleam_stdlib:identity(_pipe@3)
            end,
            Unsigned = begin
                _pipe@4 = gose@jose@jws:new(
                    {digital_signature, {ecdsa, ecdsa_p256}}
                ),
                gose@jose@jws:with_typ(_pipe@4, <<"dpop+jwt"/utf8>>)
            end,
            gleam@result:'try'(
                begin
                    _pipe@5 = gose@jose@jws:with_header(
                        Unsigned,
                        <<"jwk"/utf8>>,
                        Public_jwk
                    ),
                    err(_pipe@5)
                end,
                fun(Unsigned@1) ->
                    gleam@result:'try'(
                        begin
                            _pipe@6 = gose@jose@jws:sign(
                                Unsigned@1,
                                Key,
                                Payload
                            ),
                            err(_pipe@6)
                        end,
                        fun(Signed) ->
                            _pipe@7 = gose@jose@jws:serialize_compact(Signed),
                            err(_pipe@7)
                        end
                    )
                end
            )
        end
    ).
