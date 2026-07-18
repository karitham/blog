-module(gose@cose@sign).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/sign.gleam").
-export([new/1, with_detached/1, with_aad/2, with_kid/2, with_content_type/2, with_critical/2, assemble/1, payload/1, kid/1, content_type/1, critical/1, protected_headers/1, unprotected_headers/1, verifier/2, sign/3, verify_with_aad/3, verify/2, verify_detached_with_aad/4, verify_detached/3, serialize/1, serialize_tagged/1, parse/1]).
-export_type([building/0, signed/0, body/1, signature/0, sign/1, verifier/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " COSE_Sign multi-signer signing and verification\n"
    " ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html)).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/cose/sign\n"
    " import kryptos/ec\n"
    "\n"
    " let payload = <<\"hello\":utf8>>\n"
    " let k1 = gose.generate_ec(ec.P256)\n"
    " let k2 = gose.generate_ec(ec.P384)\n"
    "\n"
    " let assert Ok(body) =\n"
    "   sign.new(payload:)\n"
    "   |> sign.sign(gose.Ecdsa(gose.EcdsaP256), key: k1)\n"
    " let assert Ok(body) =\n"
    "   sign.sign(body, gose.Ecdsa(gose.EcdsaP384), key: k2)\n"
    " let signed = sign.assemble(body)\n"
    "\n"
    " let data = sign.serialize(signed)\n"
    " let assert Ok(parsed) = sign.parse(data)\n"
    " let assert Ok(verifier) =\n"
    "   sign.verifier(gose.Ecdsa(gose.EcdsaP256), keys: [k1])\n"
    " let assert Ok(Nil) = sign.verify(verifier, parsed)\n"
    " ```\n"
    "\n"
    " ## Building, signing, assembling\n"
    "\n"
    " `Body(state)` uses a phantom to enforce ordering:\n"
    " 1. `new(payload:)` returns `Body(Building)`.\n"
    " 2. `with_*` builders only accept `Body(Building)`, so configuration\n"
    "    happens before any signature is computed.\n"
    " 3. `sign(body, alg, key)` computes a signature over the body and returns\n"
    "    `Body(Signed)`. Calling `sign` from either state yields `Signed`, so\n"
    "    subsequent signers just chain: `|> sign(_, alg2, key2)`.\n"
    " 4. `assemble(body)` finalizes a `Body(Signed)` into `Sign(Signed)`.\n"
    "\n"
    " Because builders require `Body(Building)`, mutating the body after any\n"
    " `sign` call is a compile error. The body each signer signed over matches\n"
    " the body that gets serialized on the wire.\n"
    "\n"
    " ## Algorithm Pinning\n"
    "\n"
    " Each verifier is pinned to a single signature algorithm. The matched\n"
    " signer's protected header `alg` must match the verifier's expected algorithm.\n"
).

-type building() :: any().

-type signed() :: any().

-opaque body(RXK) :: {body,
        list(gose@cose:header()),
        list(gose@cose:header()),
        boolean(),
        bitstring(),
        bitstring(),
        list(signature())} |
    {gleam_phantom, RXK}.

-type signature() :: {signature,
        list(gose@cose:header()),
        bitstring(),
        list(gose@cose:header()),
        bitstring()}.

-opaque sign(RXL) :: {signed_sign,
        list(gose@cose:header()),
        bitstring(),
        list(gose@cose:header()),
        gleam@option:option(bitstring()),
        list(signature())} |
    {gleam_phantom, RXL}.

-opaque verifier() :: {verifier,
        gose:digital_signature_alg(),
        list(gose:key(bitstring()))}.

-file("src/gose/cose/sign.gleam", 104).
?DOC(" Create a new body pinned to the payload all signers will sign.\n").
-spec new(bitstring()) -> body(building()).
new(Payload) ->
    {body, [], [], false, <<>>, Payload, []}.

-file("src/gose/cose/sign.gleam", 118).
?DOC(
    " Mark the message for detached payload. The payload captured on\n"
    " `new(payload:)` is still covered by each signature, but `assemble`\n"
    " omits it from the serialized output.\n"
).
-spec with_detached(body(building())) -> body(building()).
with_detached(Body) ->
    {body,
        erlang:element(2, Body),
        erlang:element(3, Body),
        true,
        erlang:element(5, Body),
        erlang:element(6, Body),
        erlang:element(7, Body)}.

-file("src/gose/cose/sign.gleam", 123).
?DOC(" Set external additional authenticated data (AAD) for the signing operation.\n").
-spec with_aad(body(building()), bitstring()) -> body(building()).
with_aad(Body, Aad) ->
    {body,
        erlang:element(2, Body),
        erlang:element(3, Body),
        erlang:element(4, Body),
        Aad,
        erlang:element(6, Body),
        erlang:element(7, Body)}.

-file("src/gose/cose/sign.gleam", 128).
?DOC(" Add a key ID to the body's unprotected headers.\n").
-spec with_kid(body(building()), bitstring()) -> body(building()).
with_kid(Body, Kid) ->
    {body,
        erlang:element(2, Body),
        [{kid, Kid} | erlang:element(3, Body)],
        erlang:element(4, Body),
        erlang:element(5, Body),
        erlang:element(6, Body),
        erlang:element(7, Body)}.

-file("src/gose/cose/sign.gleam", 136).
?DOC(
    " Add a content type to the body's unprotected headers.\n"
    "\n"
    " RFC 9052 permits either bucket. Signed messages place it in unprotected,\n"
    " consistent with `with_kid`.\n"
).
-spec with_content_type(body(building()), gose@cose:content_type()) -> body(building()).
with_content_type(Body, Ct) ->
    {body,
        erlang:element(2, Body),
        [{content_type, Ct} | erlang:element(3, Body)],
        erlang:element(4, Body),
        erlang:element(5, Body),
        erlang:element(6, Body),
        erlang:element(7, Body)}.

-file("src/gose/cose/sign.gleam", 144).
?DOC(" Add critical header labels to the body's protected headers.\n").
-spec with_critical(body(building()), list(integer())) -> body(building()).
with_critical(Body, Labels) ->
    {body,
        [{crit, Labels} | erlang:element(2, Body)],
        erlang:element(3, Body),
        erlang:element(4, Body),
        erlang:element(5, Body),
        erlang:element(6, Body),
        erlang:element(7, Body)}.

-file("src/gose/cose/sign.gleam", 210).
?DOC(" Finalize a signed body into a serializable COSE_Sign message.\n").
-spec assemble(body(signed())) -> sign(signed()).
assemble(Body) ->
    Protected_serialized = gose@internal@cose_structure:serialize_protected(
        erlang:element(2, Body)
    ),
    Stored_payload = case erlang:element(4, Body) of
        true ->
            none;

        false ->
            {some, erlang:element(6, Body)}
    end,
    {signed_sign,
        erlang:element(2, Body),
        Protected_serialized,
        erlang:element(3, Body),
        Stored_payload,
        lists:reverse(erlang:element(7, Body))}.

-file("src/gose/cose/sign.gleam", 228).
?DOC(" Return the payload from a signed message. Returns `Error(Nil)` if detached.\n").
-spec payload(sign(signed())) -> {ok, bitstring()} | {error, nil}.
payload(Message) ->
    {signed_sign, _, _, _, Payload, _} = Message,
    gleam@option:to_result(Payload, nil).

-file("src/gose/cose/sign.gleam", 234).
?DOC(" Extract the key ID from the body-level headers.\n").
-spec kid(sign(signed())) -> {ok, bitstring()} | {error, gose:gose_error()}.
kid(Message) ->
    {signed_sign, Protected, _, Unprotected, _, _} = Message,
    gose@cose:kid(lists:append(Protected, Unprotected)).

-file("src/gose/cose/sign.gleam", 240).
?DOC(" Extract the content type from the body-level headers.\n").
-spec content_type(sign(signed())) -> {ok, gose@cose:content_type()} |
    {error, gose:gose_error()}.
content_type(Message) ->
    {signed_sign, Protected, _, Unprotected, _, _} = Message,
    gose@cose:content_type(lists:append(Protected, Unprotected)).

-file("src/gose/cose/sign.gleam", 248).
?DOC(" Extract the critical header labels from the body-level headers.\n").
-spec critical(sign(signed())) -> {ok, list(integer())} |
    {error, gose:gose_error()}.
critical(Message) ->
    {signed_sign, Protected, _, Unprotected, _, _} = Message,
    gose@cose:critical(lists:append(Protected, Unprotected)).

-file("src/gose/cose/sign.gleam", 254).
?DOC(" Return the raw body-level protected headers.\n").
-spec protected_headers(sign(signed())) -> list(gose@cose:header()).
protected_headers(Message) ->
    {signed_sign, Protected, _, _, _, _} = Message,
    Protected.

-file("src/gose/cose/sign.gleam", 260).
?DOC(" Return the raw body-level unprotected headers.\n").
-spec unprotected_headers(sign(signed())) -> list(gose@cose:header()).
unprotected_headers(Message) ->
    {signed_sign, _, _, Unprotected, _, _} = Message,
    Unprotected.

-file("src/gose/cose/sign.gleam", 299).
?DOC(" Build a verifier pinned to a single signature algorithm and one or more keys.\n").
-spec verifier(gose:digital_signature_alg(), list(gose:key(bitstring()))) -> {ok,
        verifier()} |
    {error, gose:gose_error()}.
verifier(Alg, Keys) ->
    Signing_alg = {digital_signature, Alg},
    gose@internal@key_helpers:require_non_empty_keys(
        Keys,
        fun() ->
            gleam@result:'try'(
                gleam@list:try_each(
                    Keys,
                    fun(_capture) ->
                        gose@internal@key_helpers:validate_key_for_signing_verification(
                            Signing_alg,
                            _capture
                        )
                    end
                ),
                fun(_) -> {ok, {verifier, Alg, Keys}} end
            )
        end
    ).

-file("src/gose/cose/sign.gleam", 463).
-spec build_sig_structure(bitstring(), bitstring(), bitstring(), bitstring()) -> bitstring().
build_sig_structure(Body_protected, Sign_protected, Aad, Payload) ->
    gose@cbor:encode(
        {array,
            [{text, <<"Signature"/utf8>>},
                {bytes, Body_protected},
                {bytes, Sign_protected},
                {bytes, Aad},
                {bytes, Payload}]}
    ).

-file("src/gose/cose/sign.gleam", 154).
?DOC(
    " Compute a per-signer signature over the body's payload and append it to\n"
    " the body. Transitions the body to `Signed` state, preventing further\n"
    " `with_*` mutations at compile time.\n"
).
-spec sign(body(any()), gose:digital_signature_alg(), gose:key(bitstring())) -> {ok,
        body(signed())} |
    {error, gose:gose_error()}.
sign(Body, Alg, Key) ->
    Signing_alg = {digital_signature, Alg},
    gleam@result:'try'(
        gose@internal@key_helpers:validate_signing_key_type(Signing_alg, Key),
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
                                    Signing_alg
                                ),
                                fun(_) ->
                                    Alg_id = gose@cose:signature_alg_to_int(Alg),
                                    Sign_protected = [{alg, Alg_id}],
                                    Sign_protected_serialized = gose@internal@cose_structure:serialize_protected(
                                        Sign_protected
                                    ),
                                    Body_protected_serialized = gose@internal@cose_structure:serialize_protected(
                                        erlang:element(2, Body)
                                    ),
                                    To_sign = build_sig_structure(
                                        Body_protected_serialized,
                                        Sign_protected_serialized,
                                        erlang:element(5, Body),
                                        erlang:element(6, Body)
                                    ),
                                    gleam@result:'try'(
                                        gose@internal@signing:compute_signature(
                                            Signing_alg,
                                            Key,
                                            To_sign
                                        ),
                                        fun(Sig_bytes) ->
                                            Signature = {signature,
                                                Sign_protected,
                                                Sign_protected_serialized,
                                                [],
                                                Sig_bytes},
                                            {ok,
                                                {body,
                                                    erlang:element(2, Body),
                                                    erlang:element(3, Body),
                                                    erlang:element(4, Body),
                                                    erlang:element(5, Body),
                                                    erlang:element(6, Body),
                                                    [Signature |
                                                        erlang:element(7, Body)]}}
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

-file("src/gose/cose/sign.gleam", 441).
-spec try_verify_one_signature(
    signature(),
    gose:signing_alg(),
    list(gose:key(bitstring())),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
try_verify_one_signature(Sig, Signing_alg, Keys, Body_protected, Aad, Payload) ->
    gleam@result:'try'(
        gose@internal@cose_structure:validate_crit(
            erlang:element(2, Sig),
            erlang:element(4, Sig)
        ),
        fun(_) ->
            To_verify = build_sig_structure(
                Body_protected,
                erlang:element(3, Sig),
                Aad,
                Payload
            ),
            gose@internal@cose_structure:try_verify_keys(
                Signing_alg,
                Keys,
                To_verify,
                erlang:element(5, Sig)
            )
        end
    ).

-file("src/gose/cose/sign.gleam", 403).
-spec do_verify_signers(
    list(signature()),
    gose:signing_alg(),
    list(gose:key(bitstring())),
    bitstring(),
    bitstring(),
    bitstring(),
    {ok, nil} | {error, gose:gose_error()}
) -> {ok, nil} | {error, gose:gose_error()}.
do_verify_signers(
    Signatures,
    Signing_alg,
    Keys,
    Body_protected,
    Aad,
    Payload,
    Last_error
) ->
    case Signatures of
        [] ->
            Last_error;

        [Sig | Rest] ->
            case try_verify_one_signature(
                Sig,
                Signing_alg,
                Keys,
                Body_protected,
                Aad,
                Payload
            ) of
                {ok, nil} ->
                    {ok, nil};

                {error, verification_failed = E} ->
                    do_verify_signers(
                        Rest,
                        Signing_alg,
                        Keys,
                        Body_protected,
                        Aad,
                        Payload,
                        {error, E}
                    );

                {error, {crypto_error, _} = E} ->
                    do_verify_signers(
                        Rest,
                        Signing_alg,
                        Keys,
                        Body_protected,
                        Aad,
                        Payload,
                        {error, E}
                    );

                {error, E@1} ->
                    {error, E@1}
            end
    end.

-file("src/gose/cose/sign.gleam", 376).
-spec try_verify_signers(
    verifier(),
    list(signature()),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
try_verify_signers(Verifier, Signatures, Body_protected, Aad, Payload) ->
    {verifier, Expected_alg, Keys} = Verifier,
    Signing_alg = {digital_signature, Expected_alg},
    Matching = gleam@list:filter(
        Signatures,
        fun(Sig) ->
            gose@internal@cose_structure:extract_signature_alg_from_headers(
                erlang:element(2, Sig)
            )
            =:= {ok, Expected_alg}
        end
    ),
    do_verify_signers(
        Matching,
        Signing_alg,
        Keys,
        Body_protected,
        Aad,
        Payload,
        {error, verification_failed}
    ).

-file("src/gose/cose/sign.gleam", 323).
?DOC(" Verify with externally-supplied AAD.\n").
-spec verify_with_aad(verifier(), sign(signed()), bitstring()) -> {ok, nil} |
    {error, gose:gose_error()}.
verify_with_aad(Verifier, Message, Aad) ->
    {signed_sign,
        Protected,
        Protected_serialized,
        Unprotected,
        Payload,
        Signatures} = Message,
    gleam@result:'try'(
        gose@internal@cose_structure:validate_crit(Protected, Unprotected),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@cose_structure:require_embedded_payload(Payload),
                fun(Payload_bytes) ->
                    try_verify_signers(
                        Verifier,
                        Signatures,
                        Protected_serialized,
                        Aad,
                        Payload_bytes
                    )
                end
            )
        end
    ).

-file("src/gose/cose/sign.gleam", 315).
?DOC(" Verify the first matching signer's signature.\n").
-spec verify(verifier(), sign(signed())) -> {ok, nil} |
    {error, gose:gose_error()}.
verify(Verifier, Message) ->
    verify_with_aad(Verifier, Message, <<>>).

-file("src/gose/cose/sign.gleam", 358).
?DOC(" Verify a detached-payload message with external AAD.\n").
-spec verify_detached_with_aad(
    verifier(),
    sign(signed()),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
verify_detached_with_aad(Verifier, Message, Payload, Aad) ->
    {signed_sign,
        Protected,
        Protected_serialized,
        Unprotected,
        Existing_payload,
        Signatures} = Message,
    gleam@result:'try'(
        gose@internal@cose_structure:validate_crit(Protected, Unprotected),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@cose_structure:require_detached_payload(
                    Existing_payload
                ),
                fun(_) ->
                    try_verify_signers(
                        Verifier,
                        Signatures,
                        Protected_serialized,
                        Aad,
                        Payload
                    )
                end
            )
        end
    ).

-file("src/gose/cose/sign.gleam", 349).
?DOC(" Verify a detached-payload message.\n").
-spec verify_detached(verifier(), sign(signed()), bitstring()) -> {ok, nil} |
    {error, gose:gose_error()}.
verify_detached(Verifier, Message, Payload) ->
    verify_detached_with_aad(Verifier, Message, Payload, <<>>).

-file("src/gose/cose/sign.gleam", 480).
-spec serialize_signature(signature()) -> gose@cbor:value().
serialize_signature(Sig) ->
    {array,
        [{bytes, erlang:element(3, Sig)},
            {map, gose@cose:headers_to_cbor(erlang:element(4, Sig))},
            {bytes, erlang:element(5, Sig)}]}.

-file("src/gose/cose/sign.gleam", 275).
-spec to_cbor_value(sign(signed())) -> gose@cbor:value().
to_cbor_value(Message) ->
    {signed_sign, _, Protected_serialized, Unprotected, Payload, Signatures} = Message,
    Payload_value = case Payload of
        {some, P} ->
            {bytes, P};

        none ->
            null
    end,
    {array,
        [{bytes, Protected_serialized},
            {map, gose@cose:headers_to_cbor(Unprotected)},
            Payload_value,
            {array, gleam@list:map(Signatures, fun serialize_signature/1)}]}.

-file("src/gose/cose/sign.gleam", 266).
?DOC(" Encode a signed message as an untagged CBOR COSE_Sign array.\n").
-spec serialize(sign(signed())) -> bitstring().
serialize(Message) ->
    gose@cbor:encode(to_cbor_value(Message)).

-file("src/gose/cose/sign.gleam", 271).
?DOC(" Encode a signed message as a CBOR-tagged (tag 98) COSE_Sign structure.\n").
-spec serialize_tagged(sign(signed())) -> bitstring().
serialize_tagged(Message) ->
    gose@cbor:encode({tag, 98, to_cbor_value(Message)}).

-file("src/gose/cose/sign.gleam", 532).
-spec parse_signature(gose@cbor:value()) -> {ok, signature()} |
    {error, gose:gose_error()}.
parse_signature(Value) ->
    case Value of
        {array,
            [{bytes, Protected_serialized},
                {map, Unprotected_pairs},
                {bytes, Signature}]} ->
            gleam@result:'try'(
                gose@internal@cose_structure:decode_protected(
                    Protected_serialized
                ),
                fun(Protected) ->
                    gleam@result:'try'(
                        gose@internal@cose_structure:decode_unprotected(
                            Unprotected_pairs
                        ),
                        fun(Unprotected) ->
                            gleam@result:'try'(
                                gose@internal@cose_structure:validate_no_header_overlap(
                                    Protected,
                                    Unprotected
                                ),
                                fun(_) ->
                                    gleam@result:'try'(
                                        gose@internal@cose_structure:validate_iv_partial_iv_exclusion(
                                            Protected,
                                            Unprotected
                                        ),
                                        fun(_) ->
                                            {ok,
                                                {signature,
                                                    Protected,
                                                    Protected_serialized,
                                                    Unprotected,
                                                    Signature}}
                                        end
                                    )
                                end
                            )
                        end
                    )
                end
            );

        _ ->
            {error, {parse_error, <<"invalid COSE_Signature structure"/utf8>>}}
    end.

-file("src/gose/cose/sign.gleam", 488).
-spec parse_cbor_value(gose@cbor:value()) -> {ok, sign(signed())} |
    {error, gose:gose_error()}.
parse_cbor_value(Value) ->
    gleam@result:'try'(
        gose@internal@cose_structure:parse_cose_array_value(Value, 98, 4),
        fun(Items) -> case Items of
                [{bytes, Protected_serialized},
                    {map, Unprotected_pairs},
                    Payload_value,
                    {array, Signature_values}] ->
                    gleam@result:'try'(
                        gose@internal@cose_structure:decode_protected(
                            Protected_serialized
                        ),
                        fun(Protected) ->
                            gleam@result:'try'(
                                gose@internal@cose_structure:decode_unprotected(
                                    Unprotected_pairs
                                ),
                                fun(Unprotected) ->
                                    gleam@result:'try'(
                                        gose@internal@cose_structure:validate_no_header_overlap(
                                            Protected,
                                            Unprotected
                                        ),
                                        fun(_) ->
                                            gleam@result:'try'(
                                                gose@internal@cose_structure:validate_iv_partial_iv_exclusion(
                                                    Protected,
                                                    Unprotected
                                                ),
                                                fun(_) ->
                                                    gleam@result:'try'(
                                                        gose@internal@cose_structure:decode_payload(
                                                            Payload_value
                                                        ),
                                                        fun(Payload) ->
                                                            gleam@result:'try'(
                                                                gleam@list:try_map(
                                                                    Signature_values,
                                                                    fun parse_signature/1
                                                                ),
                                                                fun(Signatures) ->
                                                                    {ok,
                                                                        {signed_sign,
                                                                            Protected,
                                                                            Protected_serialized,
                                                                            Unprotected,
                                                                            Payload,
                                                                            Signatures}}
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
                    );

                _ ->
                    {error,
                        {parse_error, <<"invalid COSE_Sign structure"/utf8>>}}
            end end
    ).

-file("src/gose/cose/sign.gleam", 293).
?DOC(" Decode a CBOR-encoded COSE_Sign message, accepting both tagged and untagged forms.\n").
-spec parse(bitstring()) -> {ok, sign(signed())} | {error, gose:gose_error()}.
parse(Data) ->
    gleam@result:'try'(
        gose@cbor:decode(Data),
        fun(Value) -> parse_cbor_value(Value) end
    ).
