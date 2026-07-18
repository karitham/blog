-module(gose@jose@jws_multi).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/jws_multi.gleam").
-export([new/1, with_detached/1, assemble/1, payload/1, is_detached/1, serialize_json/1, verifier/2, sign/3, parse_json/1, verify/2, verify_detached/3]).
-export_type([building/0, signed/0, body/1, signature/0, multi_jws/0, verifier/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " JWS JSON Serialization for multi-signer signing and verification\n"
    " ([RFC 7515 Section 7.2.1](https://www.rfc-editor.org/rfc/rfc7515.html#section-7.2.1)).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gleam/json\n"
    " import gose\n"
    " import gose/jose/jws_multi\n"
    " import kryptos/ec\n"
    " import kryptos/eddsa\n"
    "\n"
    " let payload = <<\"hello\":utf8>>\n"
    " let k1 = gose.generate_ec(ec.P256)\n"
    " let k2 = gose.generate_eddsa(eddsa.Ed25519)\n"
    "\n"
    " let assert Ok(body) =\n"
    "   jws_multi.new(payload:)\n"
    "   |> jws_multi.sign(\n"
    "     gose.DigitalSignature(gose.Ecdsa(gose.EcdsaP256)),\n"
    "     key: k1,\n"
    "   )\n"
    " let assert Ok(body) =\n"
    "   body\n"
    "   |> jws_multi.sign(gose.DigitalSignature(gose.Eddsa), key: k2)\n"
    " let multi = jws_multi.assemble(body)\n"
    "\n"
    " let json_str = jws_multi.serialize_json(multi) |> json.to_string\n"
    " let assert Ok(parsed) = jws_multi.parse_json(json_str)\n"
    " let assert Ok(v) =\n"
    "   jws_multi.verifier(\n"
    "     gose.DigitalSignature(gose.Ecdsa(gose.EcdsaP256)),\n"
    "     keys: [k1],\n"
    "   )\n"
    " let assert Ok(Nil) = jws_multi.verify(v, parsed)\n"
    " ```\n"
    "\n"
    " ## Phantom States\n"
    "\n"
    " `Body(Building)` supports payload configuration (`with_detached`). Calling\n"
    " `sign` transitions the body to `Body(Signed)`, which `assemble` finalizes\n"
    " into a serializable `MultiJws`. The type system prevents modifying the\n"
    " body after any signature has been computed.\n"
    "\n"
    " ## Algorithm Pinning\n"
    "\n"
    " Each verifier is pinned to a single algorithm. The matched signer's\n"
    " protected header `alg` must match the verifier's expected algorithm.\n"
).

-type building() :: any().

-type signed() :: any().

-opaque body(ABMV) :: {body,
        bitstring(),
        binary(),
        boolean(),
        list(signature())} |
    {gleam_phantom, ABMV}.

-type signature() :: {signature, gose:signing_alg(), binary(), bitstring()}.

-opaque multi_jws() :: {multi_jws,
        bitstring(),
        binary(),
        list(signature()),
        boolean()}.

-opaque verifier() :: {verifier, gose:signing_alg(), list(gose:key(binary()))}.

-file("src/gose/jose/jws_multi.gleam", 99).
?DOC(" Create a new body pinned to the payload all signers will sign.\n").
-spec new(bitstring()) -> body(building()).
new(Payload) ->
    {body, Payload, gose@internal@utils:encode_base64_url(Payload), false, []}.

-file("src/gose/jose/jws_multi.gleam", 112).
?DOC(
    " Mark the body as using a detached payload (RFC 7515 Appendix F).\n"
    "\n"
    " The payload is still signed but omitted from the serialized JSON. Callers\n"
    " verify with `verify_detached`, supplying the payload separately.\n"
).
-spec with_detached(body(building())) -> body(building()).
with_detached(Body) ->
    {body,
        erlang:element(2, Body),
        erlang:element(3, Body),
        true,
        erlang:element(5, Body)}.

-file("src/gose/jose/jws_multi.gleam", 151).
?DOC(" Finalize a signed body into a serializable multi-signer JWS.\n").
-spec assemble(body(signed())) -> multi_jws().
assemble(Body) ->
    {multi_jws,
        erlang:element(2, Body),
        erlang:element(3, Body),
        lists:reverse(erlang:element(5, Body)),
        erlang:element(4, Body)}.

-file("src/gose/jose/jws_multi.gleam", 162).
?DOC(
    " Return the payload. Returns an empty `BitArray` for messages parsed with\n"
    " a detached payload.\n"
).
-spec payload(multi_jws()) -> bitstring().
payload(Message) ->
    erlang:element(2, Message).

-file("src/gose/jose/jws_multi.gleam", 167).
?DOC(" Check whether the message was built or parsed with a detached payload.\n").
-spec is_detached(multi_jws()) -> boolean().
is_detached(Message) ->
    erlang:element(5, Message).

-file("src/gose/jose/jws_multi.gleam", 173).
?DOC(
    " Serialize as JWS JSON General Serialization. For messages built with\n"
    " `with_detached`, the payload field is omitted.\n"
).
-spec serialize_json(multi_jws()) -> gleam@json:json().
serialize_json(Message) ->
    Sig_objects = gleam@list:map(
        erlang:element(4, Message),
        fun(Sig) ->
            gleam@json:object(
                [{<<"protected"/utf8>>,
                        gleam@json:string(erlang:element(3, Sig))},
                    {<<"signature"/utf8>>,
                        gleam@json:string(
                            gose@internal@utils:encode_base64_url(
                                erlang:element(4, Sig)
                            )
                        )}]
            )
        end
    ),
    Fields = case erlang:element(5, Message) of
        true ->
            [{<<"signatures"/utf8>>, gleam@json:preprocessed_array(Sig_objects)}];

        false ->
            [{<<"payload"/utf8>>, gleam@json:string(erlang:element(3, Message))},
                {<<"signatures"/utf8>>,
                    gleam@json:preprocessed_array(Sig_objects)}]
    end,
    gleam@json:object(Fields).

-file("src/gose/jose/jws_multi.gleam", 241).
?DOC(" Build a verifier pinned to a single algorithm and one or more keys.\n").
-spec verifier(gose:signing_alg(), list(gose:key(binary()))) -> {ok, verifier()} |
    {error, gose:gose_error()}.
verifier(Alg, Keys) ->
    gose@internal@key_helpers:require_non_empty_keys(
        Keys,
        fun() ->
            gleam@result:'try'(
                gleam@list:try_each(
                    Keys,
                    fun(_capture) ->
                        gose@internal@key_helpers:validate_key_for_signing_verification(
                            Alg,
                            _capture
                        )
                    end
                ),
                fun(_) -> {ok, {verifier, Alg, Keys}} end
            )
        end
    ).

-file("src/gose/jose/jws_multi.gleam", 311).
-spec simple_header_json(gose:signing_alg()) -> bitstring().
simple_header_json(Alg) ->
    _pipe = gleam@json:object(
        [{<<"alg"/utf8>>,
                gleam@json:string(gose@jose:signing_alg_to_string(Alg))}]
    ),
    _pipe@1 = gleam@json:to_string(_pipe),
    gleam_stdlib:identity(_pipe@1).

-file("src/gose/jose/jws_multi.gleam", 119).
?DOC(
    " Compute a per-signer JWS signature over the body's payload and append it\n"
    " to the body. Transitions the body to `Signed` state, preventing further\n"
    " `with_*` mutations at compile time.\n"
).
-spec sign(body(any()), gose:signing_alg(), gose:key(binary())) -> {ok,
        body(signed())} |
    {error, gose:gose_error()}.
sign(Body, Alg, Key) ->
    gleam@result:'try'(
        gose@internal@key_helpers:validate_signing_key_type(Alg, Key),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@key_helpers:validate_key_use(Key, for_signing),
                fun(_) ->
                    gleam@result:'try'(
                        gose@internal@key_helpers:validate_key_ops(
                            Key,
                            for_signing
                        ),
                        fun(_) ->
                            gleam@result:'try'(
                                gose@internal@key_helpers:validate_key_algorithm_signing(
                                    Key,
                                    Alg
                                ),
                                fun(_) ->
                                    Protected_json = simple_header_json(Alg),
                                    Protected_b64 = gose@internal@utils:encode_base64_url(
                                        Protected_json
                                    ),
                                    Signing_input = <<<<Protected_b64/binary,
                                            "."/utf8>>/binary,
                                        (erlang:element(3, Body))/binary>>,
                                    gleam@result:'try'(
                                        gose@internal@signing:compute_signature(
                                            Alg,
                                            Key,
                                            gleam_stdlib:identity(Signing_input)
                                        ),
                                        fun(Sig) ->
                                            Signature = {signature,
                                                Alg,
                                                Protected_b64,
                                                Sig},
                                            {ok,
                                                {body,
                                                    erlang:element(2, Body),
                                                    erlang:element(3, Body),
                                                    erlang:element(4, Body),
                                                    [Signature |
                                                        erlang:element(5, Body)]}}
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

-file("src/gose/jose/jws_multi.gleam", 333).
-spec parse_alg_from_header(bitstring()) -> {ok, gose:signing_alg()} |
    {error, gose:gose_error()}.
parse_alg_from_header(Header_bytes) ->
    Decoder = begin
        gleam@dynamic@decode:field(
            <<"alg"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Alg_str) -> gleam@dynamic@decode:success(Alg_str) end
        )
    end,
    gleam@result:'try'(
        begin
            _pipe = gleam@json:parse_bits(Header_bytes, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"missing alg in protected header"/utf8>>}
            )
        end,
        fun(Alg_str@1) -> gose@jose:signing_alg_from_string(Alg_str@1) end
    ).

-file("src/gose/jose/jws_multi.gleam", 317).
-spec parse_raw_signature({binary(), binary()}) -> {ok, signature()} |
    {error, gose:gose_error()}.
parse_raw_signature(Raw) ->
    {Protected_b64, Sig_b64} = Raw,
    gleam@result:'try'(
        gose@internal@utils:decode_base64_url(
            Protected_b64,
            <<"protected header"/utf8>>
        ),
        fun(Protected_bytes) ->
            gleam@result:'try'(
                parse_alg_from_header(Protected_bytes),
                fun(Alg) ->
                    gleam@result:'try'(
                        gose@internal@utils:decode_base64_url(
                            Sig_b64,
                            <<"signature"/utf8>>
                        ),
                        fun(Signature) ->
                            {ok, {signature, Alg, Protected_b64, Signature}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jws_multi.gleam", 194).
?DOC(
    " Parse a JWS from JSON General Serialization format. A missing `payload`\n"
    " field indicates a detached payload per RFC 7515 Appendix F.\n"
).
-spec parse_json(binary()) -> {ok, multi_jws()} | {error, gose:gose_error()}.
parse_json(Json_str) ->
    Sig_decoder = begin
        gleam@dynamic@decode:field(
            <<"protected"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Protected) ->
                gleam@dynamic@decode:field(
                    <<"signature"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Signature) ->
                        gleam@dynamic@decode:success({Protected, Signature})
                    end
                )
            end
        )
    end,
    Decoder = begin
        gleam@dynamic@decode:optional_field(
            <<"payload"/utf8>>,
            none,
            gleam@dynamic@decode:optional(
                {decoder, fun gleam@dynamic@decode:decode_string/1}
            ),
            fun(Payload) ->
                gleam@dynamic@decode:field(
                    <<"signatures"/utf8>>,
                    gleam@dynamic@decode:list(Sig_decoder),
                    fun(Signatures) ->
                        gleam@dynamic@decode:success({Payload, Signatures})
                    end
                )
            end
        )
    end,
    gleam@result:'try'(
        begin
            _pipe = gleam@json:parse(Json_str, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"invalid JWS JSON"/utf8>>}
            )
        end,
        fun(_use0) ->
            {Payload_b64_opt, Raw_sigs} = _use0,
            gleam@result:'try'(
                gleam@list:try_map(Raw_sigs, fun parse_raw_signature/1),
                fun(Signatures@1) -> case Payload_b64_opt of
                        {some, Payload_b64} ->
                            gleam@result:'try'(
                                gose@internal@utils:decode_base64_url(
                                    Payload_b64,
                                    <<"payload"/utf8>>
                                ),
                                fun(Payload@1) ->
                                    {ok,
                                        {multi_jws,
                                            Payload@1,
                                            Payload_b64,
                                            Signatures@1,
                                            false}}
                                end
                            );

                        none ->
                            {ok,
                                {multi_jws,
                                    <<>>,
                                    <<""/utf8>>,
                                    Signatures@1,
                                    true}}
                    end end
            )
        end
    ).

-file("src/gose/jose/jws_multi.gleam", 347).
-spec do_verify_keys(
    gose:signing_alg(),
    list(gose:key(binary())),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
do_verify_keys(Alg, Keys, Message, Signature) ->
    case Keys of
        [] ->
            {error, verification_failed};

        [Key | Rest] ->
            case gose@internal@signing:verify_signature(
                Alg,
                Key,
                Message,
                Signature
            ) of
                {ok, nil} ->
                    {ok, nil};

                {error, verification_failed} ->
                    do_verify_keys(Alg, Rest, Message, Signature);

                {error, Err} ->
                    {error, Err}
            end
    end.

-file("src/gose/jose/jws_multi.gleam", 287).
-spec do_verify(verifier(), multi_jws(), binary()) -> {ok, nil} |
    {error, gose:gose_error()}.
do_verify(Verifier, Message, Payload_segment) ->
    {verifier, Expected_alg, Keys} = Verifier,
    Matching = gleam@list:filter(
        erlang:element(4, Message),
        fun(Sig) -> erlang:element(2, Sig) =:= Expected_alg end
    ),
    case Matching of
        [] ->
            {error, verification_failed};

        [Sig@1 | _] ->
            Signing_input = <<<<(erlang:element(3, Sig@1))/binary, "."/utf8>>/binary,
                Payload_segment/binary>>,
            do_verify_keys(
                Expected_alg,
                Keys,
                gleam_stdlib:identity(Signing_input),
                erlang:element(4, Sig@1)
            )
    end.

-file("src/gose/jose/jws_multi.gleam", 259).
?DOC(
    " Verify the first matching signer's signature.\n"
    "\n"
    " Returns `InvalidState` if the message was parsed with a detached payload;\n"
    " use `verify_detached` instead.\n"
).
-spec verify(verifier(), multi_jws()) -> {ok, nil} | {error, gose:gose_error()}.
verify(Verifier, Message) ->
    gleam@bool:guard(
        erlang:element(5, Message),
        {error,
            {invalid_state,
                <<"JWS payload is detached; use verify_detached instead"/utf8>>}},
        fun() -> do_verify(Verifier, Message, erlang:element(3, Message)) end
    ).

-file("src/gose/jose/jws_multi.gleam", 273).
?DOC(" Verify a detached-payload JWS by supplying the payload at verify time.\n").
-spec verify_detached(verifier(), multi_jws(), bitstring()) -> {ok, nil} |
    {error, gose:gose_error()}.
verify_detached(Verifier, Message, Payload) ->
    gleam@bool:guard(
        not erlang:element(5, Message),
        {error,
            {invalid_state,
                <<"JWS payload is not detached; use verify instead"/utf8>>}},
        fun() ->
            do_verify(
                Verifier,
                Message,
                gose@internal@utils:encode_base64_url(Payload)
            )
        end
    ).
