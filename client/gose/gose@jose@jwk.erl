-module(gose@jose@jwk).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/jwk.gleam").
-export([alg_to_string/1, to_json/1, alg_from_string/1, from_dynamic/1, from_json/1, from_json_bits/1, decoder/0, thumbprint/2]).
-export_type([ec_decoded/0, oct_decoded/0, okp_decoded/0, rsa_decoded/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " JSON Web Key (JWK) - [RFC 7517](https://www.rfc-editor.org/rfc/rfc7517.html)\n"
    "\n"
    " JSON serialization and deserialization for keys. Key creation,\n"
    " manipulation, and metadata are in `gose`.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gleam/json\n"
    " import gose\n"
    " import gose/jose/jwk\n"
    " import kryptos/ec\n"
    "\n"
    " // Generate an EC key and attach metadata\n"
    " let k =\n"
    "   gose.generate_ec(ec.P256)\n"
    "   |> gose.with_kid(\"my-signing-key\")\n"
    "\n"
    " // Serialize to JSON\n"
    " let json_string = jwk.to_json(k)\n"
    "   |> json.to_string()\n"
    "\n"
    " // Parse from a JSON string\n"
    " let assert Ok(parsed) = jwk.from_json(json_string)\n"
    " let assert Ok(\"my-signing-key\") = gose.kid(parsed)\n"
    " ```\n"
    "\n"
    " ## Duplicate Member Names\n"
    "\n"
    " Per RFC 7517 Section 4, JWK member names must be unique. This implementation\n"
    " relies on `gleam_json` for parsing, which uses the first value when\n"
    " duplicate member names are present. Subsequent duplicates are ignored.\n"
    "\n"
    " ## Unsupported Parameters\n"
    "\n"
    " X.509 certificate chain parameters (RFC 7517 Section 4.6-4.9) are not supported:\n"
    " - `x5u` - X.509 URL\n"
    " - `x5c` - X.509 Certificate Chain\n"
    " - `x5t` - X.509 Certificate SHA-1 Thumbprint\n"
    " - `x5t#S256` - X.509 Certificate SHA-256 Thumbprint\n"
    "\n"
    " JWKs containing any of these parameters are rejected with a `ParseError` during\n"
    " parsing. These parameters are not emitted during serialization.\n"
).

-type ec_decoded() :: {ec_decoded,
        binary(),
        binary(),
        binary(),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(list(binary())),
        gleam@option:option(binary())}.

-type oct_decoded() :: {oct_decoded,
        binary(),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(list(binary())),
        gleam@option:option(binary())}.

-type okp_decoded() :: {okp_decoded,
        binary(),
        binary(),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(list(binary())),
        gleam@option:option(binary())}.

-type rsa_decoded() :: {rsa_decoded,
        binary(),
        binary(),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(list(binary())),
        gleam@option:option(binary()),
        boolean()}.

-file("src/gose/jose/jwk.gleam", 222).
-spec key_op_to_string(gose:key_op()) -> binary().
key_op_to_string(Op) ->
    case Op of
        sign ->
            <<"sign"/utf8>>;

        verify ->
            <<"verify"/utf8>>;

        encrypt ->
            <<"encrypt"/utf8>>;

        decrypt ->
            <<"decrypt"/utf8>>;

        wrap_key ->
            <<"wrapKey"/utf8>>;

        unwrap_key ->
            <<"unwrapKey"/utf8>>;

        derive_key ->
            <<"deriveKey"/utf8>>;

        derive_bits ->
            <<"deriveBits"/utf8>>
    end.

-file("src/gose/jose/jwk.gleam", 235).
-spec key_ops_fields(gleam@option:option(list(gose:key_op()))) -> list({binary(),
    gleam@json:json()}).
key_ops_fields(Key_ops) ->
    case Key_ops of
        {some, Ops} ->
            [{<<"key_ops"/utf8>>,
                    gleam@json:array(
                        Ops,
                        fun(Op) -> gleam@json:string(key_op_to_string(Op)) end
                    )}];

        none ->
            []
    end.

-file("src/gose/jose/jwk.gleam", 256).
-spec key_use_to_string(gose:key_use()) -> binary().
key_use_to_string(Key_use) ->
    case Key_use of
        signing ->
            <<"sig"/utf8>>;

        encrypting ->
            <<"enc"/utf8>>
    end.

-file("src/gose/jose/jwk.gleam", 249).
-spec key_use_fields(gleam@option:option(gose:key_use())) -> list({binary(),
    gleam@json:json()}).
key_use_fields(Key_use) ->
    case Key_use of
        {some, U} ->
            [{<<"use"/utf8>>, gleam@json:string(key_use_to_string(U))}];

        none ->
            []
    end.

-file("src/gose/jose/jwk.gleam", 263).
-spec kid_fields(gleam@option:option(binary())) -> list({binary(),
    gleam@json:json()}).
kid_fields(Kid) ->
    case Kid of
        {some, K} ->
            [{<<"kid"/utf8>>, gleam@json:string(K)}];

        none ->
            []
    end.

-file("src/gose/jose/jwk.gleam", 279).
-spec reject_x509_params(gleam@dynamic:dynamic_()) -> {ok, nil} |
    {error, gose:gose_error()}.
reject_x509_params(Dyn) ->
    X509_fields = [<<"x5u"/utf8>>,
        <<"x5c"/utf8>>,
        <<"x5t"/utf8>>,
        <<"x5t#S256"/utf8>>],
    Dict_decoder = gleam@dynamic@decode:dict(
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
    ),
    Fields_dict = begin
        _pipe = gleam@dynamic@decode:run(Dyn, Dict_decoder),
        gleam@result:unwrap(_pipe, maps:new())
    end,
    gleam@list:try_each(
        X509_fields,
        fun(Field) -> case gleam@dict:has_key(Fields_dict, Field) of
                true ->
                    {error,
                        {parse_error,
                            <<"unsupported X.509 JWK parameter: "/utf8,
                                Field/binary>>}};

                false ->
                    {ok, nil}
            end end
    ).

-file("src/gose/jose/jwk.gleam", 359).
-spec key_op_from_string(binary()) -> {ok, gose:key_op()} |
    {error, gose:gose_error()}.
key_op_from_string(S) ->
    case S of
        <<"sign"/utf8>> ->
            {ok, sign};

        <<"verify"/utf8>> ->
            {ok, verify};

        <<"encrypt"/utf8>> ->
            {ok, encrypt};

        <<"decrypt"/utf8>> ->
            {ok, decrypt};

        <<"wrapKey"/utf8>> ->
            {ok, wrap_key};

        <<"unwrapKey"/utf8>> ->
            {ok, unwrap_key};

        <<"deriveKey"/utf8>> ->
            {ok, derive_key};

        <<"deriveBits"/utf8>> ->
            {ok, derive_bits};

        _ ->
            {error, {parse_error, <<"invalid key_ops value: "/utf8, S/binary>>}}
    end.

-file("src/gose/jose/jwk.gleam", 373).
-spec key_use_from_string(binary()) -> {ok, gose:key_use()} |
    {error, gose:gose_error()}.
key_use_from_string(S) ->
    case S of
        <<"sig"/utf8>> ->
            {ok, signing};

        <<"enc"/utf8>> ->
            {ok, encrypting};

        _ ->
            {error, {parse_error, <<"invalid use value: "/utf8, S/binary>>}}
    end.

-file("src/gose/jose/jwk.gleam", 396).
-spec parse_key_ops(list(binary())) -> {ok, list(gose:key_op())} |
    {error, gose:gose_error()}.
parse_key_ops(Ops) ->
    gleam@bool:guard(
        gleam@list:is_empty(Ops),
        {error, {parse_error, <<"key_ops must not be empty"/utf8>>}},
        fun() ->
            gleam@result:'try'(
                gleam@list:try_map(Ops, fun key_op_from_string/1),
                fun(Parsed) -> case gleam@list:unique(Parsed) /= Parsed of
                        true ->
                            {error,
                                {parse_error,
                                    <<"key_ops must not contain duplicates"/utf8>>}};

                        false ->
                            {ok, Parsed}
                    end end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 408).
-spec parse_optional(
    gleam@option:option(YJB),
    fun((YJB) -> {ok, YJD} | {error, gose:gose_error()})
) -> {ok, gleam@option:option(YJD)} | {error, gose:gose_error()}.
parse_optional(Opt, Parser) ->
    case Opt of
        none ->
            {ok, none};

        {some, Value} ->
            gleam@result:map(Parser(Value), fun(Field@0) -> {some, Field@0} end)
    end.

-file("src/gose/jose/jwk.gleam", 431).
-spec ec_decoder() -> gleam@dynamic@decode:decoder(ec_decoded()).
ec_decoder() ->
    gleam@dynamic@decode:field(
        <<"crv"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(Crv) ->
            gleam@dynamic@decode:field(
                <<"x"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(X) ->
                    gleam@dynamic@decode:field(
                        <<"y"/utf8>>,
                        {decoder, fun gleam@dynamic@decode:decode_string/1},
                        fun(Y) ->
                            gleam@dynamic@decode:optional_field(
                                <<"d"/utf8>>,
                                none,
                                gleam@dynamic@decode:optional(
                                    {decoder,
                                        fun gleam@dynamic@decode:decode_string/1}
                                ),
                                fun(D) ->
                                    gleam@dynamic@decode:optional_field(
                                        <<"kid"/utf8>>,
                                        none,
                                        gleam@dynamic@decode:optional(
                                            {decoder,
                                                fun gleam@dynamic@decode:decode_string/1}
                                        ),
                                        fun(Kid) ->
                                            gleam@dynamic@decode:optional_field(
                                                <<"use"/utf8>>,
                                                none,
                                                gleam@dynamic@decode:optional(
                                                    {decoder,
                                                        fun gleam@dynamic@decode:decode_string/1}
                                                ),
                                                fun(Use_) ->
                                                    gleam@dynamic@decode:optional_field(
                                                        <<"key_ops"/utf8>>,
                                                        none,
                                                        gleam@dynamic@decode:optional(
                                                            gleam@dynamic@decode:list(
                                                                {decoder,
                                                                    fun gleam@dynamic@decode:decode_string/1}
                                                            )
                                                        ),
                                                        fun(Key_ops) ->
                                                            gleam@dynamic@decode:optional_field(
                                                                <<"alg"/utf8>>,
                                                                none,
                                                                gleam@dynamic@decode:optional(
                                                                    {decoder,
                                                                        fun gleam@dynamic@decode:decode_string/1}
                                                                ),
                                                                fun(Alg) ->
                                                                    gleam@dynamic@decode:success(
                                                                        {ec_decoded,
                                                                            Crv,
                                                                            X,
                                                                            Y,
                                                                            D,
                                                                            Kid,
                                                                            Use_,
                                                                            Key_ops,
                                                                            Alg}
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
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 546).
-spec oct_decoder() -> gleam@dynamic@decode:decoder(oct_decoded()).
oct_decoder() ->
    gleam@dynamic@decode:field(
        <<"k"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(K) ->
            gleam@dynamic@decode:optional_field(
                <<"kid"/utf8>>,
                none,
                gleam@dynamic@decode:optional(
                    {decoder, fun gleam@dynamic@decode:decode_string/1}
                ),
                fun(Kid) ->
                    gleam@dynamic@decode:optional_field(
                        <<"use"/utf8>>,
                        none,
                        gleam@dynamic@decode:optional(
                            {decoder, fun gleam@dynamic@decode:decode_string/1}
                        ),
                        fun(Use_) ->
                            gleam@dynamic@decode:optional_field(
                                <<"key_ops"/utf8>>,
                                none,
                                gleam@dynamic@decode:optional(
                                    gleam@dynamic@decode:list(
                                        {decoder,
                                            fun gleam@dynamic@decode:decode_string/1}
                                    )
                                ),
                                fun(Key_ops) ->
                                    gleam@dynamic@decode:optional_field(
                                        <<"alg"/utf8>>,
                                        none,
                                        gleam@dynamic@decode:optional(
                                            {decoder,
                                                fun gleam@dynamic@decode:decode_string/1}
                                        ),
                                        fun(Alg) ->
                                            gleam@dynamic@decode:success(
                                                {oct_decoded,
                                                    K,
                                                    Kid,
                                                    Use_,
                                                    Key_ops,
                                                    Alg}
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

-file("src/gose/jose/jwk.gleam", 612).
-spec okp_decoder() -> gleam@dynamic@decode:decoder(okp_decoded()).
okp_decoder() ->
    gleam@dynamic@decode:field(
        <<"crv"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(Crv) ->
            gleam@dynamic@decode:field(
                <<"x"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(X) ->
                    gleam@dynamic@decode:optional_field(
                        <<"d"/utf8>>,
                        none,
                        gleam@dynamic@decode:optional(
                            {decoder, fun gleam@dynamic@decode:decode_string/1}
                        ),
                        fun(D) ->
                            gleam@dynamic@decode:optional_field(
                                <<"kid"/utf8>>,
                                none,
                                gleam@dynamic@decode:optional(
                                    {decoder,
                                        fun gleam@dynamic@decode:decode_string/1}
                                ),
                                fun(Kid) ->
                                    gleam@dynamic@decode:optional_field(
                                        <<"use"/utf8>>,
                                        none,
                                        gleam@dynamic@decode:optional(
                                            {decoder,
                                                fun gleam@dynamic@decode:decode_string/1}
                                        ),
                                        fun(Use_) ->
                                            gleam@dynamic@decode:optional_field(
                                                <<"key_ops"/utf8>>,
                                                none,
                                                gleam@dynamic@decode:optional(
                                                    gleam@dynamic@decode:list(
                                                        {decoder,
                                                            fun gleam@dynamic@decode:decode_string/1}
                                                    )
                                                ),
                                                fun(Key_ops) ->
                                                    gleam@dynamic@decode:optional_field(
                                                        <<"alg"/utf8>>,
                                                        none,
                                                        gleam@dynamic@decode:optional(
                                                            {decoder,
                                                                fun gleam@dynamic@decode:decode_string/1}
                                                        ),
                                                        fun(Alg) ->
                                                            gleam@dynamic@decode:success(
                                                                {okp_decoded,
                                                                    Crv,
                                                                    X,
                                                                    D,
                                                                    Kid,
                                                                    Use_,
                                                                    Key_ops,
                                                                    Alg}
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
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 689).
-spec build_eddsa_material(
    kryptos@eddsa:curve(),
    bitstring(),
    gleam@option:option(binary())
) -> {ok, gose:key_material()} | {error, gose:gose_error()}.
build_eddsa_material(Curve, X_bits, D_opt) ->
    case D_opt of
        {some, D_b64} ->
            gleam@result:'try'(
                gose@internal@utils:decode_base64_url(D_b64, <<"d"/utf8>>),
                fun(D_bits) ->
                    gleam@result:'try'(
                        begin
                            _pipe = kryptos_ffi:eddsa_private_key_from_bytes(
                                Curve,
                                D_bits
                            ),
                            gleam@result:replace_error(
                                _pipe,
                                {parse_error,
                                    <<"invalid private key bytes"/utf8>>}
                            )
                        end,
                        fun(_use0) ->
                            {Private, Public} = _use0,
                            Computed_x = kryptos_ffi:eddsa_public_key_to_bytes(
                                Public
                            ),
                            gleam@bool:guard(
                                not fun kryptos_ffi:constant_time_equal/2(
                                    Computed_x,
                                    X_bits
                                ),
                                {error,
                                    {parse_error,
                                        <<"x does not match computed public key"/utf8>>}},
                                fun() ->
                                    {ok,
                                        {edwards,
                                            {eddsa_private,
                                                Private,
                                                Public,
                                                Curve}}}
                                end
                            )
                        end
                    )
                end
            );

        none ->
            gleam@result:'try'(
                begin
                    _pipe@1 = kryptos_ffi:eddsa_public_key_from_bytes(
                        Curve,
                        X_bits
                    ),
                    gleam@result:replace_error(
                        _pipe@1,
                        {parse_error, <<"invalid public key bytes"/utf8>>}
                    )
                end,
                fun(Public@1) ->
                    {ok, {edwards, {eddsa_public, Public@1, Curve}}}
                end
            )
    end.

-file("src/gose/jose/jwk.gleam", 718).
-spec parse_eddsa_okp_json(
    kryptos@eddsa:curve(),
    bitstring(),
    gleam@option:option(binary()),
    gleam@option:option(binary()),
    gleam@option:option(gose:key_use()),
    gleam@option:option(list(gose:key_op())),
    gleam@option:option(gose:alg())
) -> {ok, gose:key(binary())} | {error, gose:gose_error()}.
parse_eddsa_okp_json(Curve, X_bits, D_opt, Kid, Key_use, Key_ops, Alg) ->
    gleam@result:'try'(
        build_eddsa_material(Curve, X_bits, D_opt),
        fun(Material) ->
            gleam@result:'try'(
                gose:validate_rfc8037_key_use_public(Material, Key_use),
                fun(_) ->
                    {ok, gose:build(Material, Kid, Key_use, Key_ops, Alg)}
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 732).
-spec build_xdh_material(
    kryptos@xdh:curve(),
    bitstring(),
    gleam@option:option(binary())
) -> {ok, gose:key_material()} | {error, gose:gose_error()}.
build_xdh_material(Curve, X_bits, D_opt) ->
    case D_opt of
        {some, D_b64} ->
            gleam@result:'try'(
                gose@internal@utils:decode_base64_url(D_b64, <<"d"/utf8>>),
                fun(D_bits) ->
                    gleam@result:'try'(
                        begin
                            _pipe = kryptos_ffi:xdh_private_key_from_bytes(
                                Curve,
                                D_bits
                            ),
                            gleam@result:replace_error(
                                _pipe,
                                {parse_error,
                                    <<"invalid private key bytes"/utf8>>}
                            )
                        end,
                        fun(_use0) ->
                            {Private, Public} = _use0,
                            Computed_x = kryptos_ffi:xdh_public_key_to_bytes(
                                Public
                            ),
                            gleam@bool:guard(
                                not fun kryptos_ffi:constant_time_equal/2(
                                    Computed_x,
                                    X_bits
                                ),
                                {error,
                                    {parse_error,
                                        <<"x does not match computed public key"/utf8>>}},
                                fun() ->
                                    {ok,
                                        {xdh,
                                            {xdh_private,
                                                Private,
                                                Public,
                                                Curve}}}
                                end
                            )
                        end
                    )
                end
            );

        none ->
            gleam@result:'try'(
                begin
                    _pipe@1 = kryptos_ffi:xdh_public_key_from_bytes(
                        Curve,
                        X_bits
                    ),
                    gleam@result:replace_error(
                        _pipe@1,
                        {parse_error, <<"invalid public key bytes"/utf8>>}
                    )
                end,
                fun(Public@1) -> {ok, {xdh, {xdh_public, Public@1, Curve}}} end
            )
    end.

-file("src/gose/jose/jwk.gleam", 761).
-spec parse_xdh_okp_json(
    kryptos@xdh:curve(),
    bitstring(),
    gleam@option:option(binary()),
    gleam@option:option(binary()),
    gleam@option:option(gose:key_use()),
    gleam@option:option(list(gose:key_op())),
    gleam@option:option(gose:alg())
) -> {ok, gose:key(binary())} | {error, gose:gose_error()}.
parse_xdh_okp_json(Curve, X_bits, D_opt, Kid, Key_use, Key_ops, Alg) ->
    gleam@result:'try'(
        build_xdh_material(Curve, X_bits, D_opt),
        fun(Material) ->
            gleam@result:'try'(
                gose:validate_rfc8037_key_use_public(Material, Key_use),
                fun(_) ->
                    {ok, gose:build(Material, Kid, Key_use, Key_ops, Alg)}
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 775).
-spec parse_rsa_private_key_components(
    bitstring(),
    bitstring(),
    bitstring(),
    gleam@option:option(binary()),
    gleam@option:option(binary()),
    gleam@option:option(binary()),
    gleam@option:option(binary()),
    gleam@option:option(binary())
) -> {ok, {kryptos@rsa:private_key(), kryptos@rsa:public_key()}} |
    {error, gose:gose_error()}.
parse_rsa_private_key_components(
    N_bits,
    E_bits,
    D_bits,
    P_opt,
    Q_opt,
    Dp_opt,
    Dq_opt,
    Qi_opt
) ->
    Crt_fields = [P_opt, Q_opt, Dp_opt, Dq_opt, Qi_opt],
    Crt_present = begin
        _pipe = Crt_fields,
        _pipe@1 = gleam@list:filter(_pipe, fun gleam@option:is_some/1),
        erlang:length(_pipe@1)
    end,
    gleam@bool:guard(
        (Crt_present > 0) andalso (Crt_present < 5),
        {error,
            {parse_error,
                <<"partial CRT fields: all five (p, q, dp, dq, qi) are required if any are present"/utf8>>}},
        fun() -> case {P_opt, Q_opt, Dp_opt, Dq_opt, Qi_opt} of
                {{some, P_b64},
                    {some, Q_b64},
                    {some, Dp_b64},
                    {some, Dq_b64},
                    {some, Qi_b64}} ->
                    gleam@result:'try'(
                        gose@internal@utils:decode_base64_url(
                            P_b64,
                            <<"p"/utf8>>
                        ),
                        fun(P_bits) ->
                            gleam@result:'try'(
                                gose@internal@utils:decode_base64_url(
                                    Q_b64,
                                    <<"q"/utf8>>
                                ),
                                fun(Q_bits) ->
                                    gleam@result:'try'(
                                        gose@internal@utils:decode_base64_url(
                                            Dp_b64,
                                            <<"dp"/utf8>>
                                        ),
                                        fun(Dp_bits) ->
                                            gleam@result:'try'(
                                                gose@internal@utils:decode_base64_url(
                                                    Dq_b64,
                                                    <<"dq"/utf8>>
                                                ),
                                                fun(Dq_bits) ->
                                                    gleam@result:'try'(
                                                        gose@internal@utils:decode_base64_url(
                                                            Qi_b64,
                                                            <<"qi"/utf8>>
                                                        ),
                                                        fun(Qi_bits) ->
                                                            _pipe@2 = kryptos_ffi:rsa_private_key_from_full_components(
                                                                N_bits,
                                                                E_bits,
                                                                D_bits,
                                                                P_bits,
                                                                Q_bits,
                                                                Dp_bits,
                                                                Dq_bits,
                                                                Qi_bits
                                                            ),
                                                            gleam@result:replace_error(
                                                                _pipe@2,
                                                                {parse_error,
                                                                    <<"invalid RSA private key components"/utf8>>}
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
                    );

                {_, _, _, _, _} ->
                    _pipe@3 = kryptos@rsa:from_components(
                        N_bits,
                        E_bits,
                        D_bits
                    ),
                    gleam@result:replace_error(
                        _pipe@3,
                        {parse_error,
                            <<"invalid RSA private key components"/utf8>>}
                    )
            end end
    ).

-file("src/gose/jose/jwk.gleam", 849).
-spec rsa_decoder() -> gleam@dynamic@decode:decoder(rsa_decoded()).
rsa_decoder() ->
    gleam@dynamic@decode:field(
        <<"n"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(N) ->
            gleam@dynamic@decode:field(
                <<"e"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(E) ->
                    gleam@dynamic@decode:optional_field(
                        <<"d"/utf8>>,
                        none,
                        gleam@dynamic@decode:optional(
                            {decoder, fun gleam@dynamic@decode:decode_string/1}
                        ),
                        fun(D) ->
                            gleam@dynamic@decode:optional_field(
                                <<"p"/utf8>>,
                                none,
                                gleam@dynamic@decode:optional(
                                    {decoder,
                                        fun gleam@dynamic@decode:decode_string/1}
                                ),
                                fun(P) ->
                                    gleam@dynamic@decode:optional_field(
                                        <<"q"/utf8>>,
                                        none,
                                        gleam@dynamic@decode:optional(
                                            {decoder,
                                                fun gleam@dynamic@decode:decode_string/1}
                                        ),
                                        fun(Q) ->
                                            gleam@dynamic@decode:optional_field(
                                                <<"dp"/utf8>>,
                                                none,
                                                gleam@dynamic@decode:optional(
                                                    {decoder,
                                                        fun gleam@dynamic@decode:decode_string/1}
                                                ),
                                                fun(Dp) ->
                                                    gleam@dynamic@decode:optional_field(
                                                        <<"dq"/utf8>>,
                                                        none,
                                                        gleam@dynamic@decode:optional(
                                                            {decoder,
                                                                fun gleam@dynamic@decode:decode_string/1}
                                                        ),
                                                        fun(Dq) ->
                                                            gleam@dynamic@decode:optional_field(
                                                                <<"qi"/utf8>>,
                                                                none,
                                                                gleam@dynamic@decode:optional(
                                                                    {decoder,
                                                                        fun gleam@dynamic@decode:decode_string/1}
                                                                ),
                                                                fun(Qi) ->
                                                                    gleam@dynamic@decode:optional_field(
                                                                        <<"kid"/utf8>>,
                                                                        none,
                                                                        gleam@dynamic@decode:optional(
                                                                            {decoder,
                                                                                fun gleam@dynamic@decode:decode_string/1}
                                                                        ),
                                                                        fun(Kid) ->
                                                                            gleam@dynamic@decode:optional_field(
                                                                                <<"use"/utf8>>,
                                                                                none,
                                                                                gleam@dynamic@decode:optional(
                                                                                    {decoder,
                                                                                        fun gleam@dynamic@decode:decode_string/1}
                                                                                ),
                                                                                fun(
                                                                                    Use_
                                                                                ) ->
                                                                                    gleam@dynamic@decode:optional_field(
                                                                                        <<"key_ops"/utf8>>,
                                                                                        none,
                                                                                        gleam@dynamic@decode:optional(
                                                                                            gleam@dynamic@decode:list(
                                                                                                {decoder,
                                                                                                    fun gleam@dynamic@decode:decode_string/1}
                                                                                            )
                                                                                        ),
                                                                                        fun(
                                                                                            Key_ops
                                                                                        ) ->
                                                                                            gleam@dynamic@decode:optional_field(
                                                                                                <<"alg"/utf8>>,
                                                                                                none,
                                                                                                gleam@dynamic@decode:optional(
                                                                                                    {decoder,
                                                                                                        fun gleam@dynamic@decode:decode_string/1}
                                                                                                ),
                                                                                                fun(
                                                                                                    Alg
                                                                                                ) ->
                                                                                                    gleam@dynamic@decode:optional_field(
                                                                                                        <<"oth"/utf8>>,
                                                                                                        false,
                                                                                                        gleam@dynamic@decode:success(
                                                                                                            true
                                                                                                        ),
                                                                                                        fun(
                                                                                                            Oth
                                                                                                        ) ->
                                                                                                            gleam@dynamic@decode:success(
                                                                                                                {rsa_decoded,
                                                                                                                    N,
                                                                                                                    E,
                                                                                                                    D,
                                                                                                                    P,
                                                                                                                    Q,
                                                                                                                    Dp,
                                                                                                                    Dq,
                                                                                                                    Qi,
                                                                                                                    Kid,
                                                                                                                    Use_,
                                                                                                                    Key_ops,
                                                                                                                    Alg,
                                                                                                                    Oth}
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
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 998).
?DOC(
    " Convert an algorithm (signing, key encryption, or content encryption)\n"
    " to its RFC string representation.\n"
).
-spec alg_to_string(gose:alg()) -> binary().
alg_to_string(Alg) ->
    case Alg of
        {signing_alg, Signing_alg} ->
            gose@jose:signing_alg_to_string(Signing_alg);

        {key_encryption_alg, Ke_alg} ->
            gose@jose:key_encryption_alg_to_string(Ke_alg);

        {content_alg, Content_alg} ->
            gose@jose:content_alg_to_string(Content_alg)
    end.

-file("src/gose/jose/jwk.gleam", 215).
-spec alg_fields(gleam@option:option(gose:alg())) -> list({binary(),
    gleam@json:json()}).
alg_fields(Alg) ->
    case Alg of
        {some, A} ->
            [{<<"alg"/utf8>>, gleam@json:string(alg_to_string(A))}];

        none ->
            []
    end.

-file("src/gose/jose/jwk.gleam", 270).
-spec metadata_fields(gose:key(binary())) -> list({binary(), gleam@json:json()}).
metadata_fields(K) ->
    lists:append(
        [kid_fields(gleam@option:from_result(gose:kid(K))),
            key_use_fields(gleam@option:from_result(gose:key_use(K))),
            key_ops_fields(gleam@option:from_result(gose:key_ops(K))),
            alg_fields(gleam@option:from_result(gose:alg(K)))]
    ).

-file("src/gose/jose/jwk.gleam", 69).
?DOC(" Serialize a key to its JSON representation.\n").
-spec to_json(gose:key(binary())) -> gleam@json:json().
to_json(K) ->
    Mat = gose:material(K),
    Base_fields = case Mat of
        {edwards, {eddsa_private, Private, Public, Curve}} ->
            X_bits = kryptos_ffi:eddsa_public_key_to_bytes(Public),
            D_bits = kryptos_ffi:eddsa_private_key_to_bytes(Private),
            [{<<"kty"/utf8>>, gleam@json:string(<<"OKP"/utf8>>)},
                {<<"crv"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:eddsa_curve_to_string(Curve)
                    )},
                {<<"x"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(X_bits)
                    )},
                {<<"d"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(D_bits)
                    )}];

        {edwards, {eddsa_public, Public@1, Curve@1}} ->
            X_bits@1 = kryptos_ffi:eddsa_public_key_to_bytes(Public@1),
            [{<<"kty"/utf8>>, gleam@json:string(<<"OKP"/utf8>>)},
                {<<"crv"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:eddsa_curve_to_string(Curve@1)
                    )},
                {<<"x"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(X_bits@1)
                    )}];

        {octet_key, Secret} ->
            [{<<"kty"/utf8>>, gleam@json:string(<<"oct"/utf8>>)},
                {<<"k"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(Secret)
                    )}];

        {rsa, {rsa_private, Private@1, _}} ->
            [{<<"kty"/utf8>>, gleam@json:string(<<"RSA"/utf8>>)},
                {<<"n"/utf8>>,
                    begin
                        _pipe = kryptos_ffi:rsa_private_key_modulus(Private@1),
                        _pipe@1 = gose@internal@utils:strip_leading_zeros(_pipe),
                        _pipe@2 = gose@internal@utils:encode_base64_url(_pipe@1),
                        gleam@json:string(_pipe@2)
                    end},
                {<<"e"/utf8>>,
                    begin
                        _pipe@3 = kryptos_ffi:rsa_private_key_public_exponent_bytes(
                            Private@1
                        ),
                        _pipe@4 = gose@internal@utils:strip_leading_zeros(
                            _pipe@3
                        ),
                        _pipe@5 = gose@internal@utils:encode_base64_url(_pipe@4),
                        gleam@json:string(_pipe@5)
                    end},
                {<<"d"/utf8>>,
                    begin
                        _pipe@6 = kryptos_ffi:rsa_private_key_private_exponent_bytes(
                            Private@1
                        ),
                        _pipe@7 = gose@internal@utils:strip_leading_zeros(
                            _pipe@6
                        ),
                        _pipe@8 = gose@internal@utils:encode_base64_url(_pipe@7),
                        gleam@json:string(_pipe@8)
                    end},
                {<<"p"/utf8>>,
                    begin
                        _pipe@9 = kryptos_ffi:rsa_private_key_prime1(Private@1),
                        _pipe@10 = gose@internal@utils:strip_leading_zeros(
                            _pipe@9
                        ),
                        _pipe@11 = gose@internal@utils:encode_base64_url(
                            _pipe@10
                        ),
                        gleam@json:string(_pipe@11)
                    end},
                {<<"q"/utf8>>,
                    begin
                        _pipe@12 = kryptos_ffi:rsa_private_key_prime2(Private@1),
                        _pipe@13 = gose@internal@utils:strip_leading_zeros(
                            _pipe@12
                        ),
                        _pipe@14 = gose@internal@utils:encode_base64_url(
                            _pipe@13
                        ),
                        gleam@json:string(_pipe@14)
                    end},
                {<<"dp"/utf8>>,
                    begin
                        _pipe@15 = kryptos_ffi:rsa_private_key_exponent1(
                            Private@1
                        ),
                        _pipe@16 = gose@internal@utils:strip_leading_zeros(
                            _pipe@15
                        ),
                        _pipe@17 = gose@internal@utils:encode_base64_url(
                            _pipe@16
                        ),
                        gleam@json:string(_pipe@17)
                    end},
                {<<"dq"/utf8>>,
                    begin
                        _pipe@18 = kryptos_ffi:rsa_private_key_exponent2(
                            Private@1
                        ),
                        _pipe@19 = gose@internal@utils:strip_leading_zeros(
                            _pipe@18
                        ),
                        _pipe@20 = gose@internal@utils:encode_base64_url(
                            _pipe@19
                        ),
                        gleam@json:string(_pipe@20)
                    end},
                {<<"qi"/utf8>>,
                    begin
                        _pipe@21 = kryptos_ffi:rsa_private_key_coefficient(
                            Private@1
                        ),
                        _pipe@22 = gose@internal@utils:strip_leading_zeros(
                            _pipe@21
                        ),
                        _pipe@23 = gose@internal@utils:encode_base64_url(
                            _pipe@22
                        ),
                        gleam@json:string(_pipe@23)
                    end}];

        {rsa, {rsa_public, Public@2}} ->
            [{<<"kty"/utf8>>, gleam@json:string(<<"RSA"/utf8>>)},
                {<<"n"/utf8>>,
                    begin
                        _pipe@24 = kryptos_ffi:rsa_public_key_modulus(Public@2),
                        _pipe@25 = gose@internal@utils:strip_leading_zeros(
                            _pipe@24
                        ),
                        _pipe@26 = gose@internal@utils:encode_base64_url(
                            _pipe@25
                        ),
                        gleam@json:string(_pipe@26)
                    end},
                {<<"e"/utf8>>,
                    begin
                        _pipe@27 = kryptos_ffi:rsa_public_key_exponent_bytes(
                            Public@2
                        ),
                        _pipe@28 = gose@internal@utils:strip_leading_zeros(
                            _pipe@27
                        ),
                        _pipe@29 = gose@internal@utils:encode_base64_url(
                            _pipe@28
                        ),
                        gleam@json:string(_pipe@29)
                    end}];

        {elliptic, {ec_private, Private@2, Public@3, Curve@2}} ->
            {X@1, Y@1} = case gose:ec_raw_coordinates(Public@3, Curve@2) of
                {ok, {X, Y}} -> {X, Y};
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwk"/utf8>>,
                                function => <<"to_json"/utf8>>,
                                line => 172,
                                value => _assert_fail,
                                start => 4946,
                                'end' => 5010,
                                pattern_start => 4957,
                                pattern_end => 4968})
            end,
            D_bits@1 = kryptos_ffi:ec_private_key_to_bytes(Private@2),
            [{<<"kty"/utf8>>, gleam@json:string(<<"EC"/utf8>>)},
                {<<"crv"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:ec_curve_to_string(Curve@2)
                    )},
                {<<"x"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(X@1)
                    )},
                {<<"y"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(Y@1)
                    )},
                {<<"d"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(D_bits@1)
                    )}];

        {elliptic, {ec_public, Public@4, Curve@3}} ->
            {X@3, Y@3} = case gose:ec_raw_coordinates(Public@4, Curve@3) of
                {ok, {X@2, Y@2}} -> {X@2, Y@2};
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwk"/utf8>>,
                                function => <<"to_json"/utf8>>,
                                line => 184,
                                value => _assert_fail@1,
                                start => 5489,
                                'end' => 5553,
                                pattern_start => 5500,
                                pattern_end => 5511})
            end,
            [{<<"kty"/utf8>>, gleam@json:string(<<"EC"/utf8>>)},
                {<<"crv"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:ec_curve_to_string(Curve@3)
                    )},
                {<<"x"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(X@3)
                    )},
                {<<"y"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(Y@3)
                    )}];

        {xdh, {xdh_private, Private@3, Public@5, Curve@4}} ->
            X_bits@2 = kryptos_ffi:xdh_public_key_to_bytes(Public@5),
            D_bits@2 = kryptos_ffi:xdh_private_key_to_bytes(Private@3),
            [{<<"kty"/utf8>>, gleam@json:string(<<"OKP"/utf8>>)},
                {<<"crv"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:xdh_curve_to_string(Curve@4)
                    )},
                {<<"x"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(X_bits@2)
                    )},
                {<<"d"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(D_bits@2)
                    )}];

        {xdh, {xdh_public, Public@6, Curve@5}} ->
            X_bits@3 = kryptos_ffi:xdh_public_key_to_bytes(Public@6),
            [{<<"kty"/utf8>>, gleam@json:string(<<"OKP"/utf8>>)},
                {<<"crv"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:xdh_curve_to_string(Curve@5)
                    )},
                {<<"x"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(X_bits@3)
                    )}]
    end,
    gleam@json:object(lists:append(Base_fields, metadata_fields(K))).

-file("src/gose/jose/jwk.gleam", 1007).
?DOC(" Parse an algorithm from its RFC string representation.\n").
-spec alg_from_string(binary()) -> {ok, gose:alg()} | {error, gose:gose_error()}.
alg_from_string(S) ->
    _pipe = gose@jose:signing_alg_from_string(S),
    _pipe@1 = gleam@result:map(
        _pipe,
        fun(Field@0) -> {signing_alg, Field@0} end
    ),
    _pipe@3 = gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = gose@jose:key_encryption_alg_from_string(S),
            gleam@result:map(
                _pipe@2,
                fun(Field@0) -> {key_encryption_alg, Field@0} end
            ) end
    ),
    _pipe@5 = gleam@result:lazy_or(
        _pipe@3,
        fun() -> _pipe@4 = gose@jose:content_alg_from_string(S),
            gleam@result:map(
                _pipe@4,
                fun(Field@0) -> {content_alg, Field@0} end
            ) end
    ),
    gleam@result:replace_error(
        _pipe@5,
        {parse_error, <<"unknown algorithm: "/utf8, S/binary>>}
    ).

-file("src/gose/jose/jwk.gleam", 381).
-spec parse_key_metadata(
    gleam@option:option(binary()),
    gleam@option:option(list(binary())),
    gleam@option:option(binary())
) -> {ok,
        {gleam@option:option(gose:key_use()),
            gleam@option:option(list(gose:key_op())),
            gleam@option:option(gose:alg())}} |
    {error, gose:gose_error()}.
parse_key_metadata(Use_opt, Key_ops_opt, Alg_opt) ->
    gleam@result:'try'(
        parse_optional(Use_opt, fun key_use_from_string/1),
        fun(Key_use) ->
            gleam@result:'try'(
                parse_optional(Key_ops_opt, fun parse_key_ops/1),
                fun(Key_ops) ->
                    gleam@result:'try'(
                        parse_optional(Alg_opt, fun alg_from_string/1),
                        fun(Alg) ->
                            gleam@result:'try'(
                                gose:validate_key_use_ops(Key_use, Key_ops),
                                fun(_) -> {ok, {Key_use, Key_ops, Alg}} end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 470).
-spec process_ec_decoded(ec_decoded()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
process_ec_decoded(Decoded) ->
    {ec_decoded, Crv, X_b64, Y_b64, D_opt, Kid, Use_opt, Key_ops_opt, Alg_opt} = Decoded,
    gleam@result:'try'(
        gose@internal@utils:ec_curve_from_string(Crv),
        fun(Curve) ->
            gleam@result:'try'(
                gose@internal@utils:decode_base64_url(X_b64, <<"x"/utf8>>),
                fun(X_bits) ->
                    gleam@result:'try'(
                        gose@internal@utils:decode_base64_url(
                            Y_b64,
                            <<"y"/utf8>>
                        ),
                        fun(Y_bits) ->
                            gleam@result:'try'(
                                parse_key_metadata(
                                    Use_opt,
                                    Key_ops_opt,
                                    Alg_opt
                                ),
                                fun(_use0) ->
                                    {Key_use, Key_ops, Alg} = _use0,
                                    Coord_size = kryptos@ec:coordinate_size(
                                        Curve
                                    ),
                                    gleam@bool:guard(
                                        erlang:byte_size(X_bits) /= Coord_size,
                                        {error,
                                            {parse_error,
                                                <<<<"EC x coordinate must be "/utf8,
                                                        (erlang:integer_to_binary(
                                                            Coord_size
                                                        ))/binary>>/binary,
                                                    " bytes"/utf8>>}},
                                        fun() ->
                                            gleam@bool:guard(
                                                erlang:byte_size(Y_bits) /= Coord_size,
                                                {error,
                                                    {parse_error,
                                                        <<<<"EC y coordinate must be "/utf8,
                                                                (erlang:integer_to_binary(
                                                                    Coord_size
                                                                ))/binary>>/binary,
                                                            " bytes"/utf8>>}},
                                                fun() ->
                                                    Raw_point = gleam_stdlib:bit_array_concat(
                                                        [<<16#04>>,
                                                            X_bits,
                                                            Y_bits]
                                                    ),
                                                    case D_opt of
                                                        {some, D_b64} ->
                                                            gleam@result:'try'(
                                                                gose@internal@utils:decode_base64_url(
                                                                    D_b64,
                                                                    <<"d"/utf8>>
                                                                ),
                                                                fun(D_bits) ->
                                                                    gleam@result:'try'(
                                                                        begin
                                                                            _pipe = kryptos_ffi:ec_private_key_from_bytes(
                                                                                Curve,
                                                                                D_bits
                                                                            ),
                                                                            gleam@result:replace_error(
                                                                                _pipe,
                                                                                {parse_error,
                                                                                    <<"invalid EC private key bytes"/utf8>>}
                                                                            )
                                                                        end,
                                                                        fun(
                                                                            _use0@1
                                                                        ) ->
                                                                            {Private,
                                                                                Public} = _use0@1,
                                                                            Computed_point = kryptos_ffi:ec_public_key_to_raw_point(
                                                                                Public
                                                                            ),
                                                                            gleam@bool:guard(
                                                                                not fun kryptos_ffi:constant_time_equal/2(
                                                                                    Computed_point,
                                                                                    Raw_point
                                                                                ),
                                                                                {error,
                                                                                    {parse_error,
                                                                                        <<"x/y do not match computed public key"/utf8>>}},
                                                                                fun(
                                                                                    
                                                                                ) ->
                                                                                    {ok,
                                                                                        gose:build(
                                                                                            {elliptic,
                                                                                                {ec_private,
                                                                                                    Private,
                                                                                                    Public,
                                                                                                    Curve}},
                                                                                            Kid,
                                                                                            Key_use,
                                                                                            Key_ops,
                                                                                            Alg
                                                                                        )}
                                                                                end
                                                                            )
                                                                        end
                                                                    )
                                                                end
                                                            );

                                                        none ->
                                                            gleam@result:'try'(
                                                                begin
                                                                    _pipe@1 = kryptos_ffi:ec_public_key_from_raw_point(
                                                                        Curve,
                                                                        Raw_point
                                                                    ),
                                                                    gleam@result:replace_error(
                                                                        _pipe@1,
                                                                        {parse_error,
                                                                            <<"invalid EC public key coordinates"/utf8>>}
                                                                    )
                                                                end,
                                                                fun(Public@1) ->
                                                                    {ok,
                                                                        gose:build(
                                                                            {elliptic,
                                                                                {ec_public,
                                                                                    Public@1,
                                                                                    Curve}},
                                                                            Kid,
                                                                            Key_use,
                                                                            Key_ops,
                                                                            Alg
                                                                        )}
                                                                end
                                                            )
                                                    end
                                                end
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

-file("src/gose/jose/jwk.gleam", 463).
-spec parse_ec_dynamic(gleam@dynamic:dynamic_()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
parse_ec_dynamic(Dyn) ->
    case gleam@dynamic@decode:run(Dyn, ec_decoder()) of
        {ok, Decoded} ->
            process_ec_decoded(Decoded);

        {error, _} ->
            {error, {parse_error, <<"invalid EC JSON"/utf8>>}}
    end.

-file("src/gose/jose/jwk.gleam", 578).
-spec process_oct_decoded(oct_decoded()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
process_oct_decoded(Decoded) ->
    {oct_decoded, K_b64, Kid, Use_opt, Key_ops_opt, Alg_opt} = Decoded,
    gleam@result:'try'(
        gose@internal@utils:decode_base64_url(K_b64, <<"k"/utf8>>),
        fun(Secret) ->
            gleam@result:'try'(
                parse_key_metadata(Use_opt, Key_ops_opt, Alg_opt),
                fun(_use0) ->
                    {Key_use, Key_ops, Alg} = _use0,
                    case erlang:byte_size(Secret) =:= 0 of
                        true ->
                            {error,
                                {parse_error,
                                    <<"oct key must not be empty"/utf8>>}};

                        false ->
                            {ok,
                                gose:build(
                                    {octet_key, Secret},
                                    Kid,
                                    Key_use,
                                    Key_ops,
                                    Alg
                                )}
                    end
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 571).
-spec parse_oct_dynamic(gleam@dynamic:dynamic_()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
parse_oct_dynamic(Dyn) ->
    case gleam@dynamic@decode:run(Dyn, oct_decoder()) of
        {ok, Decoded} ->
            process_oct_decoded(Decoded);

        {error, _} ->
            {error, {parse_error, <<"invalid oct JSON"/utf8>>}}
    end.

-file("src/gose/jose/jwk.gleam", 650).
-spec process_okp_decoded(okp_decoded()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
process_okp_decoded(Decoded) ->
    {okp_decoded, Crv, X_b64, D_opt, Kid, Use_opt, Key_ops_opt, Alg_opt} = Decoded,
    gleam@result:'try'(
        gose@internal@utils:decode_base64_url(X_b64, <<"x"/utf8>>),
        fun(X_bits) ->
            gleam@result:'try'(
                parse_key_metadata(Use_opt, Key_ops_opt, Alg_opt),
                fun(_use0) ->
                    {Key_use, Key_ops, Alg} = _use0,
                    case gose@internal@utils:eddsa_curve_from_string(Crv) of
                        {ok, Eddsa_curve} ->
                            parse_eddsa_okp_json(
                                Eddsa_curve,
                                X_bits,
                                D_opt,
                                Kid,
                                Key_use,
                                Key_ops,
                                Alg
                            );

                        {error, _} ->
                            case gose@internal@utils:xdh_curve_from_string(Crv) of
                                {ok, Xdh_curve} ->
                                    parse_xdh_okp_json(
                                        Xdh_curve,
                                        X_bits,
                                        D_opt,
                                        Kid,
                                        Key_use,
                                        Key_ops,
                                        Alg
                                    );

                                {error, _} ->
                                    {error,
                                        {parse_error,
                                            <<"unsupported OKP curve: "/utf8,
                                                Crv/binary>>}}
                            end
                    end
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 643).
-spec parse_okp_dynamic(gleam@dynamic:dynamic_()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
parse_okp_dynamic(Dyn) ->
    case gleam@dynamic@decode:run(Dyn, okp_decoder()) of
        {ok, Decoded} ->
            process_okp_decoded(Decoded);

        {error, _} ->
            {error, {parse_error, <<"invalid OKP JSON"/utf8>>}}
    end.

-file("src/gose/jose/jwk.gleam", 927).
-spec process_rsa_decoded(rsa_decoded()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
process_rsa_decoded(Decoded) ->
    {rsa_decoded,
        N_b64,
        E_b64,
        D_opt,
        P_opt,
        Q_opt,
        Dp_opt,
        Dq_opt,
        Qi_opt,
        Kid,
        Use_opt,
        Key_ops_opt,
        Alg_opt,
        Oth} = Decoded,
    gleam@bool:guard(
        Oth,
        {error,
            {parse_error,
                <<"multi-prime RSA keys (oth parameter) not supported"/utf8>>}},
        fun() ->
            gleam@result:'try'(
                gose@internal@utils:decode_base64_url(N_b64, <<"n"/utf8>>),
                fun(N_bits) ->
                    gleam@result:'try'(
                        gose@internal@utils:decode_base64_url(
                            E_b64,
                            <<"e"/utf8>>
                        ),
                        fun(E_bits) ->
                            gleam@result:'try'(
                                parse_key_metadata(
                                    Use_opt,
                                    Key_ops_opt,
                                    Alg_opt
                                ),
                                fun(_use0) ->
                                    {Key_use, Key_ops, Alg} = _use0,
                                    case D_opt of
                                        {some, D_b64} ->
                                            gleam@result:'try'(
                                                gose@internal@utils:decode_base64_url(
                                                    D_b64,
                                                    <<"d"/utf8>>
                                                ),
                                                fun(D_bits) ->
                                                    gleam@result:'try'(
                                                        parse_rsa_private_key_components(
                                                            N_bits,
                                                            E_bits,
                                                            D_bits,
                                                            P_opt,
                                                            Q_opt,
                                                            Dp_opt,
                                                            Dq_opt,
                                                            Qi_opt
                                                        ),
                                                        fun(_use0@1) ->
                                                            {Private, Public} = _use0@1,
                                                            {ok,
                                                                gose:build(
                                                                    {rsa,
                                                                        {rsa_private,
                                                                            Private,
                                                                            Public}},
                                                                    Kid,
                                                                    Key_use,
                                                                    Key_ops,
                                                                    Alg
                                                                )}
                                                        end
                                                    )
                                                end
                                            );

                                        none ->
                                            gleam@result:'try'(
                                                begin
                                                    _pipe = kryptos_ffi:rsa_public_key_from_components(
                                                        N_bits,
                                                        E_bits
                                                    ),
                                                    gleam@result:replace_error(
                                                        _pipe,
                                                        {parse_error,
                                                            <<"invalid RSA public key components"/utf8>>}
                                                    )
                                                end,
                                                fun(Public@1) ->
                                                    {ok,
                                                        gose:build(
                                                            {rsa,
                                                                {rsa_public,
                                                                    Public@1}},
                                                            Kid,
                                                            Key_use,
                                                            Key_ops,
                                                            Alg
                                                        )}
                                                end
                                            )
                                    end
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 920).
-spec parse_rsa_dynamic(gleam@dynamic:dynamic_()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
parse_rsa_dynamic(Dyn) ->
    case gleam@dynamic@decode:run(Dyn, rsa_decoder()) of
        {ok, Decoded} ->
            process_rsa_decoded(Decoded);

        {error, _} ->
            {error, {parse_error, <<"invalid RSA JSON"/utf8>>}}
    end.

-file("src/gose/jose/jwk.gleam", 296).
?DOC(false).
-spec from_dynamic(gleam@dynamic:dynamic_()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
from_dynamic(Dyn) ->
    gleam@result:'try'(
        reject_x509_params(Dyn),
        fun(_) ->
            Kty_decoder = gleam@dynamic@decode:at(
                [<<"kty"/utf8>>],
                {decoder, fun gleam@dynamic@decode:decode_string/1}
            ),
            gleam@result:'try'(
                begin
                    _pipe = gleam@dynamic@decode:run(Dyn, Kty_decoder),
                    gleam@result:replace_error(
                        _pipe,
                        {parse_error, <<"missing or invalid kty"/utf8>>}
                    )
                end,
                fun(Kty) -> case Kty of
                        <<"OKP"/utf8>> ->
                            parse_okp_dynamic(Dyn);

                        <<"oct"/utf8>> ->
                            parse_oct_dynamic(Dyn);

                        <<"RSA"/utf8>> ->
                            parse_rsa_dynamic(Dyn);

                        <<"EC"/utf8>> ->
                            parse_ec_dynamic(Dyn);

                        _ ->
                            {error,
                                {parse_error,
                                    <<"unsupported kty: "/utf8, Kty/binary>>}}
                    end end
            )
        end
    ).

-file("src/gose/jose/jwk.gleam", 313).
?DOC(" Parse a JWK from JSON.\n").
-spec from_json(binary()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
from_json(Json_str) ->
    gleam@result:'try'(
        begin
            _pipe = gleam@json:parse(
                Json_str,
                {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
            ),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"invalid JSON"/utf8>>}
            )
        end,
        fun(Dyn) -> from_dynamic(Dyn) end
    ).

-file("src/gose/jose/jwk.gleam", 322).
?DOC(" Parse a JWK from JSON provided as a `BitArray`.\n").
-spec from_json_bits(bitstring()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
from_json_bits(Json_bits) ->
    gleam@result:'try'(
        begin
            _pipe = gleam@json:parse_bits(
                Json_bits,
                {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
            ),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"invalid JSON"/utf8>>}
            )
        end,
        fun(Dyn) -> from_dynamic(Dyn) end
    ).

-file("src/gose/jose/jwk.gleam", 344).
?DOC(
    " Return a decoder for JWK values.\n"
    "\n"
    " This lets you compose JWK decoding inside larger decode pipelines, for\n"
    " example with `decode.field`, `decode.list`, or `json.parse`.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " // Parse a key directly from a JSON string\n"
    " let assert Ok(k) = json.parse(json_string, jwk.decoder())\n"
    "\n"
    " // Use inside a larger decoder\n"
    " use k <- decode.field(\"signing_key\", jwk.decoder())\n"
    " ```\n"
).
-spec decoder() -> gleam@dynamic@decode:decoder(gose:key(binary())).
decoder() ->
    Placeholder = gose:build({octet_key, <<>>}, none, none, none, none),
    gleam@dynamic@decode:new_primitive_decoder(
        <<"Key"/utf8>>,
        fun(Dyn) -> _pipe = from_dynamic(Dyn),
            gleam@result:replace_error(_pipe, Placeholder) end
    ).

-file("src/gose/jose/jwk.gleam", 1046).
-spec thumbprint_json(gose:key(any())) -> {ok, binary()} |
    {error, gose:gose_error()}.
thumbprint_json(K) ->
    case gose:material(K) of
        {elliptic, {ec_private, _, Public, Curve}} ->
            gleam@result:'try'(
                gose:ec_raw_coordinates(Public, Curve),
                fun(_use0) ->
                    {X, Y} = _use0,
                    Crv = gose@internal@utils:ec_curve_to_string(Curve),
                    X_b64 = gose@internal@utils:encode_base64_url(X),
                    Y_b64 = gose@internal@utils:encode_base64_url(Y),
                    {ok,
                        <<<<<<<<<<<<"{\"crv\":\""/utf8, Crv/binary>>/binary,
                                            "\",\"kty\":\"EC\",\"x\":\""/utf8>>/binary,
                                        X_b64/binary>>/binary,
                                    "\",\"y\":\""/utf8>>/binary,
                                Y_b64/binary>>/binary,
                            "\"}"/utf8>>}
                end
            );

        {elliptic, {ec_public, Public, Curve}} ->
            gleam@result:'try'(
                gose:ec_raw_coordinates(Public, Curve),
                fun(_use0) ->
                    {X, Y} = _use0,
                    Crv = gose@internal@utils:ec_curve_to_string(Curve),
                    X_b64 = gose@internal@utils:encode_base64_url(X),
                    Y_b64 = gose@internal@utils:encode_base64_url(Y),
                    {ok,
                        <<<<<<<<<<<<"{\"crv\":\""/utf8, Crv/binary>>/binary,
                                            "\",\"kty\":\"EC\",\"x\":\""/utf8>>/binary,
                                        X_b64/binary>>/binary,
                                    "\",\"y\":\""/utf8>>/binary,
                                Y_b64/binary>>/binary,
                            "\"}"/utf8>>}
                end
            );

        {rsa, {rsa_private, _, Public@1}} ->
            E = begin
                _pipe = kryptos_ffi:rsa_public_key_exponent_bytes(Public@1),
                _pipe@1 = gose@internal@utils:strip_leading_zeros(_pipe),
                gose@internal@utils:encode_base64_url(_pipe@1)
            end,
            N = begin
                _pipe@2 = kryptos_ffi:rsa_public_key_modulus(Public@1),
                _pipe@3 = gose@internal@utils:strip_leading_zeros(_pipe@2),
                gose@internal@utils:encode_base64_url(_pipe@3)
            end,
            {ok,
                <<<<<<<<"{\"e\":\""/utf8, E/binary>>/binary,
                            "\",\"kty\":\"RSA\",\"n\":\""/utf8>>/binary,
                        N/binary>>/binary,
                    "\"}"/utf8>>};

        {rsa, {rsa_public, Public@1}} ->
            E = begin
                _pipe = kryptos_ffi:rsa_public_key_exponent_bytes(Public@1),
                _pipe@1 = gose@internal@utils:strip_leading_zeros(_pipe),
                gose@internal@utils:encode_base64_url(_pipe@1)
            end,
            N = begin
                _pipe@2 = kryptos_ffi:rsa_public_key_modulus(Public@1),
                _pipe@3 = gose@internal@utils:strip_leading_zeros(_pipe@2),
                gose@internal@utils:encode_base64_url(_pipe@3)
            end,
            {ok,
                <<<<<<<<"{\"e\":\""/utf8, E/binary>>/binary,
                            "\",\"kty\":\"RSA\",\"n\":\""/utf8>>/binary,
                        N/binary>>/binary,
                    "\"}"/utf8>>};

        {edwards, {eddsa_private, _, Public@2, Curve@1}} ->
            Crv@1 = gose@internal@utils:eddsa_curve_to_string(Curve@1),
            X@1 = begin
                _pipe@4 = kryptos_ffi:eddsa_public_key_to_bytes(Public@2),
                gose@internal@utils:encode_base64_url(_pipe@4)
            end,
            {ok,
                <<<<<<<<"{\"crv\":\""/utf8, Crv@1/binary>>/binary,
                            "\",\"kty\":\"OKP\",\"x\":\""/utf8>>/binary,
                        X@1/binary>>/binary,
                    "\"}"/utf8>>};

        {edwards, {eddsa_public, Public@2, Curve@1}} ->
            Crv@1 = gose@internal@utils:eddsa_curve_to_string(Curve@1),
            X@1 = begin
                _pipe@4 = kryptos_ffi:eddsa_public_key_to_bytes(Public@2),
                gose@internal@utils:encode_base64_url(_pipe@4)
            end,
            {ok,
                <<<<<<<<"{\"crv\":\""/utf8, Crv@1/binary>>/binary,
                            "\",\"kty\":\"OKP\",\"x\":\""/utf8>>/binary,
                        X@1/binary>>/binary,
                    "\"}"/utf8>>};

        {xdh, {xdh_private, _, Public@3, Curve@2}} ->
            Crv@2 = gose@internal@utils:xdh_curve_to_string(Curve@2),
            X@2 = begin
                _pipe@5 = kryptos_ffi:xdh_public_key_to_bytes(Public@3),
                gose@internal@utils:encode_base64_url(_pipe@5)
            end,
            {ok,
                <<<<<<<<"{\"crv\":\""/utf8, Crv@2/binary>>/binary,
                            "\",\"kty\":\"OKP\",\"x\":\""/utf8>>/binary,
                        X@2/binary>>/binary,
                    "\"}"/utf8>>};

        {xdh, {xdh_public, Public@3, Curve@2}} ->
            Crv@2 = gose@internal@utils:xdh_curve_to_string(Curve@2),
            X@2 = begin
                _pipe@5 = kryptos_ffi:xdh_public_key_to_bytes(Public@3),
                gose@internal@utils:encode_base64_url(_pipe@5)
            end,
            {ok,
                <<<<<<<<"{\"crv\":\""/utf8, Crv@2/binary>>/binary,
                            "\",\"kty\":\"OKP\",\"x\":\""/utf8>>/binary,
                        X@2/binary>>/binary,
                    "\"}"/utf8>>};

        {octet_key, Secret} ->
            K@1 = gose@internal@utils:encode_base64_url(Secret),
            {ok,
                <<<<"{\"k\":\""/utf8, K@1/binary>>/binary,
                    "\",\"kty\":\"oct\"}"/utf8>>}
    end.

-file("src/gose/jose/jwk.gleam", 1035).
?DOC(
    " Compute the JWK Thumbprint ([RFC 7638](https://www.rfc-editor.org/rfc/rfc7638)).\n"
    "\n"
    " The thumbprint is a base64url-encoded hash of the canonical JSON\n"
    " representation containing only the required public key members.\n"
    " Private keys produce the same thumbprint as their corresponding public keys.\n"
    "\n"
    " RFC 7638 recommends SHA-256 as the hash, but allows other algorithms.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let k = gose.generate_ec(ec.P256)\n"
    " let assert Ok(thumbprint) = jwk.thumbprint(k, hash.Sha256)\n"
    " ```\n"
).
-spec thumbprint(gose:key(any()), kryptos@hash:hash_algorithm()) -> {ok,
        binary()} |
    {error, gose:gose_error()}.
thumbprint(Key, Algorithm) ->
    gleam@result:'try'(
        thumbprint_json(Key),
        fun(Json_str) -> _pipe = gleam_stdlib:identity(Json_str),
            _pipe@1 = kryptos@crypto:hash(Algorithm, _pipe),
            _pipe@2 = gleam@result:replace_error(
                _pipe@1,
                {crypto_error, <<"hash algorithm not supported"/utf8>>}
            ),
            gleam@result:map(
                _pipe@2,
                fun gose@internal@utils:encode_base64_url/1
            ) end
    ).
