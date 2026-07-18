-module(gose@cose@sign1).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/sign1.gleam").
-export([new/1, serialize/1, serialize_tagged/1, payload/1, verifier/2, with_detached/1, with_aad/2, with_kid/2, with_content_type/2, with_critical/2, kid/1, content_type/1, critical/1, protected_headers/1, unprotected_headers/1, sign/3, verify_with_aad/3, verify/2, verify_detached_with_aad/4, verify_detached/3, parse/1]).
-export_type([unsigned/0, signed/0, sign1/1, verifier/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " COSE_Sign1 single-signer signing and verification\n"
    " ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html)).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/cose/sign1\n"
    " import kryptos/ec\n"
    "\n"
    " let k = gose.generate_ec(ec.P256)\n"
    " let payload = <<\"hello\":utf8>>\n"
    "\n"
    " let assert Ok(signed) =\n"
    "   sign1.new(gose.Ecdsa(gose.EcdsaP256))\n"
    "   |> sign1.sign(k, payload)\n"
    "\n"
    " let data = sign1.serialize(signed)\n"
    " let assert Ok(parsed) = sign1.parse(data)\n"
    " let assert Ok(verifier) =\n"
    "   sign1.verifier(gose.Ecdsa(gose.EcdsaP256), keys: [k])\n"
    " let assert Ok(Nil) = sign1.verify(verifier, parsed)\n"
    " ```\n"
    "\n"
    " ## Phantom Types\n"
    "\n"
    " `Sign1(state)` uses a phantom type to track signing state:\n"
    " - `Unsigned`: created via `new`, ready to sign\n"
    " - `Signed`: signed or parsed, can be serialized or verified\n"
    "\n"
    " ## Algorithm Pinning\n"
    "\n"
    " Each verifier is pinned to a single algorithm. The token's protected\n"
    " header `alg` must match the verifier's expected algorithm.\n"
).

-type unsigned() :: any().

-type signed() :: any().

-opaque sign1(OBC) :: {unsigned_sign1,
        list(gose@cose:header()),
        list(gose@cose:header()),
        boolean(),
        bitstring()} |
    {signed_sign1,
        list(gose@cose:header()),
        bitstring(),
        list(gose@cose:header()),
        gleam@option:option(bitstring()),
        bitstring()} |
    {gleam_phantom, OBC}.

-opaque verifier() :: {verifier,
        gose:digital_signature_alg(),
        list(gose:key(bitstring()))}.

-file("src/gose/cose/sign1.gleam", 75).
?DOC(" Create a new unsigned COSE_Sign1 message with the given signature algorithm in the protected header.\n").
-spec new(gose:digital_signature_alg()) -> sign1(unsigned()).
new(Alg) ->
    Alg_id = gose@cose:signature_alg_to_int(Alg),
    {unsigned_sign1, [{alg, Alg_id}], [], false, <<>>}.

-file("src/gose/cose/sign1.gleam", 130).
-spec to_cbor_value(sign1(signed())) -> gose@cbor:value().
to_cbor_value(Message) ->
    {Protected_serialized@1, Unprotected@1, Payload@1, Signature@1} = case Message of
        {signed_sign1, _, Protected_serialized, Unprotected, Payload, Signature} -> {
        Protected_serialized,
            Unprotected,
            Payload,
            Signature};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"to_cbor_value"/utf8>>,
                        line => 131,
                        value => _assert_fail,
                        start => 3958,
                        'end' => 4078,
                        pattern_start => 3969,
                        pattern_end => 4068})
    end,
    Payload_value = case Payload@1 of
        {some, P} ->
            {bytes, P};

        none ->
            null
    end,
    {array,
        [{bytes, Protected_serialized@1},
            {map, gose@cose:headers_to_cbor(Unprotected@1)},
            Payload_value,
            {bytes, Signature@1}]}.

-file("src/gose/cose/sign1.gleam", 121).
?DOC(" Encode a signed message as an untagged CBOR COSE_Sign1 array.\n").
-spec serialize(sign1(signed())) -> bitstring().
serialize(Message) ->
    gose@cbor:encode(to_cbor_value(Message)).

-file("src/gose/cose/sign1.gleam", 126).
?DOC(" Encode a signed message as a CBOR-tagged (tag 18) COSE_Sign1 structure.\n").
-spec serialize_tagged(sign1(signed())) -> bitstring().
serialize_tagged(Message) ->
    gose@cbor:encode({tag, 18, to_cbor_value(Message)}).

-file("src/gose/cose/sign1.gleam", 159).
?DOC(" Return the payload from a signed message. Returns `Error(Nil)` if detached.\n").
-spec payload(sign1(signed())) -> {ok, bitstring()} | {error, nil}.
payload(Message) ->
    Payload@1 = case Message of
        {signed_sign1, _, _, _, Payload, _} -> Payload;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"payload"/utf8>>,
                        line => 160,
                        value => _assert_fail,
                        start => 4725,
                        'end' => 4771,
                        pattern_start => 4736,
                        pattern_end => 4761})
    end,
    gleam@option:to_result(Payload@1, nil).

-file("src/gose/cose/sign1.gleam", 165).
?DOC(" Build a verifier pinned to a single algorithm and one or more keys.\n").
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

-file("src/gose/cose/sign1.gleam", 277).
?DOC(
    " Mark the message for detached payload. The payload is still provided to\n"
    " `sign` for signature computation but not included in the serialized output.\n"
).
-spec with_detached(sign1(unsigned())) -> sign1(unsigned()).
with_detached(Message) ->
    case Message of
        {unsigned_sign1, _, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"with_detached"/utf8>>,
                        line => 278,
                        value => _assert_fail,
                        start => 8343,
                        'end' => 8381,
                        pattern_start => 8354,
                        pattern_end => 8371})
    end,
    {unsigned_sign1,
        erlang:element(2, Message),
        erlang:element(3, Message),
        true,
        erlang:element(5, Message)}.

-file("src/gose/cose/sign1.gleam", 283).
?DOC(" Set external additional authenticated data (AAD) for the signing operation.\n").
-spec with_aad(sign1(unsigned()), bitstring()) -> sign1(unsigned()).
with_aad(Message, Aad) ->
    case Message of
        {unsigned_sign1, _, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"with_aad"/utf8>>,
                        line => 284,
                        value => _assert_fail,
                        start => 8592,
                        'end' => 8630,
                        pattern_start => 8603,
                        pattern_end => 8620})
    end,
    {unsigned_sign1,
        erlang:element(2, Message),
        erlang:element(3, Message),
        erlang:element(4, Message),
        Aad}.

-file("src/gose/cose/sign1.gleam", 289).
?DOC(" Add a key ID to the unprotected headers.\n").
-spec with_kid(sign1(unsigned()), bitstring()) -> sign1(unsigned()).
with_kid(Message, Kid) ->
    Unprotected@1 = case Message of
        {unsigned_sign1, _, Unprotected, _, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"with_kid"/utf8>>,
                        line => 290,
                        value => _assert_fail,
                        start => 8796,
                        'end' => 8848,
                        pattern_start => 8807,
                        pattern_end => 8838})
    end,
    {unsigned_sign1,
        erlang:element(2, Message),
        [{kid, Kid} | Unprotected@1],
        erlang:element(4, Message),
        erlang:element(5, Message)}.

-file("src/gose/cose/sign1.gleam", 298).
?DOC(
    " Add a content type to the unprotected headers.\n"
    "\n"
    " RFC 9052 permits either bucket. Signed messages place it in unprotected,\n"
    " consistent with `with_kid`.\n"
).
-spec with_content_type(sign1(unsigned()), gose@cose:content_type()) -> sign1(unsigned()).
with_content_type(Message, Ct) ->
    Unprotected@1 = case Message of
        {unsigned_sign1, _, Unprotected, _, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"with_content_type"/utf8>>,
                        line => 302,
                        value => _assert_fail,
                        start => 9194,
                        'end' => 9246,
                        pattern_start => 9205,
                        pattern_end => 9236})
    end,
    {unsigned_sign1,
        erlang:element(2, Message),
        [{content_type, Ct} | Unprotected@1],
        erlang:element(4, Message),
        erlang:element(5, Message)}.

-file("src/gose/cose/sign1.gleam", 307).
?DOC(" Add critical header labels to the protected headers.\n").
-spec with_critical(sign1(unsigned()), list(integer())) -> sign1(unsigned()).
with_critical(Message, Labels) ->
    Protected@1 = case Message of
        {unsigned_sign1, Protected, _, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"with_critical"/utf8>>,
                        line => 311,
                        value => _assert_fail,
                        start => 9489,
                        'end' => 9539,
                        pattern_start => 9500,
                        pattern_end => 9529})
    end,
    {unsigned_sign1,
        [{crit, Labels} | Protected@1],
        erlang:element(3, Message),
        erlang:element(4, Message),
        erlang:element(5, Message)}.

-file("src/gose/cose/sign1.gleam", 316).
?DOC(" Extract the key ID from the message headers.\n").
-spec kid(sign1(signed())) -> {ok, bitstring()} | {error, gose:gose_error()}.
kid(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {signed_sign1, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"kid"/utf8>>,
                        line => 317,
                        value => _assert_fail,
                        start => 9739,
                        'end' => 9801,
                        pattern_start => 9750,
                        pattern_end => 9791})
    end,
    gose@cose:kid(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/sign1.gleam", 322).
?DOC(" Extract the content type from the message headers.\n").
-spec content_type(sign1(signed())) -> {ok, gose@cose:content_type()} |
    {error, gose:gose_error()}.
content_type(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {signed_sign1, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"content_type"/utf8>>,
                        line => 325,
                        value => _assert_fail,
                        start => 10005,
                        'end' => 10067,
                        pattern_start => 10016,
                        pattern_end => 10057})
    end,
    gose@cose:content_type(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/sign1.gleam", 330).
?DOC(" Extract the critical header labels from the message headers.\n").
-spec critical(sign1(signed())) -> {ok, list(integer())} |
    {error, gose:gose_error()}.
critical(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {signed_sign1, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"critical"/utf8>>,
                        line => 331,
                        value => _assert_fail,
                        start => 10274,
                        'end' => 10336,
                        pattern_start => 10285,
                        pattern_end => 10326})
    end,
    gose@cose:critical(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/sign1.gleam", 336).
?DOC(" Return the raw protected headers.\n").
-spec protected_headers(sign1(signed())) -> list(gose@cose:header()).
protected_headers(Message) ->
    Protected@1 = case Message of
        {signed_sign1, Protected, _, _, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"protected_headers"/utf8>>,
                        line => 337,
                        value => _assert_fail,
                        start => 10505,
                        'end' => 10553,
                        pattern_start => 10516,
                        pattern_end => 10543})
    end,
    Protected@1.

-file("src/gose/cose/sign1.gleam", 342).
?DOC(" Return the raw unprotected headers.\n").
-spec unprotected_headers(sign1(signed())) -> list(gose@cose:header()).
unprotected_headers(Message) ->
    Unprotected@1 = case Message of
        {signed_sign1, _, _, Unprotected, _, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"unprotected_headers"/utf8>>,
                        line => 343,
                        value => _assert_fail,
                        start => 10685,
                        'end' => 10735,
                        pattern_start => 10696,
                        pattern_end => 10725})
    end,
    Unprotected@1.

-file("src/gose/cose/sign1.gleam", 347).
-spec build_sig_structure(bitstring(), bitstring(), bitstring()) -> bitstring().
build_sig_structure(Protected_serialized, Aad, Payload) ->
    gose@cbor:encode(
        {array,
            [{text, <<"Signature1"/utf8>>},
                {bytes, Protected_serialized},
                {bytes, Aad},
                {bytes, Payload}]}
    ).

-file("src/gose/cose/sign1.gleam", 86).
?DOC(" Sign the payload with the given key, producing a signed COSE_Sign1 message.\n").
-spec sign(sign1(unsigned()), gose:key(bitstring()), bitstring()) -> {ok,
        sign1(signed())} |
    {error, gose:gose_error()}.
sign(Message, Key, Payload) ->
    {Protected@1, Unprotected@1, Detached@1, Aad@1} = case Message of
        {unsigned_sign1, Protected, Unprotected, Detached, Aad} -> {
        Protected,
            Unprotected,
            Detached,
            Aad};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"sign"/utf8>>,
                        line => 91,
                        value => _assert_fail,
                        start => 2595,
                        'end' => 2672,
                        pattern_start => 2606,
                        pattern_end => 2662})
    end,
    gleam@result:'try'(
        gose@internal@cose_structure:extract_signing_alg_from_headers(
            Protected@1
        ),
        fun(Alg) ->
            gleam@result:'try'(
                gose@internal@key_helpers:validate_signing_key_type(Alg, Key),
                fun(_) ->
                    gleam@result:'try'(
                        gose@internal@key_helpers:validate_key_use(
                            Key,
                            for_signing
                        ),
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
                                            Protected_serialized = gose@internal@cose_structure:serialize_protected(
                                                Protected@1
                                            ),
                                            To_sign = build_sig_structure(
                                                Protected_serialized,
                                                Aad@1,
                                                Payload
                                            ),
                                            gleam@result:'try'(
                                                gose@internal@signing:compute_signature(
                                                    Alg,
                                                    Key,
                                                    To_sign
                                                ),
                                                fun(Sig) ->
                                                    Stored_payload = case Detached@1 of
                                                        true ->
                                                            none;

                                                        false ->
                                                            {some, Payload}
                                                    end,
                                                    {ok,
                                                        {signed_sign1,
                                                            Protected@1,
                                                            Protected_serialized,
                                                            Unprotected@1,
                                                            Stored_payload,
                                                            Sig}}
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

-file("src/gose/cose/sign1.gleam", 189).
?DOC(" Verify the signature with additional externally-supplied authenticated data (AAD).\n").
-spec verify_with_aad(verifier(), sign1(signed()), bitstring()) -> {ok, nil} |
    {error, gose:gose_error()}.
verify_with_aad(Verifier, Message, Aad) ->
    {verifier, Expected_alg, Keys} = Verifier,
    Expected_signing_alg = {digital_signature, Expected_alg},
    {
    Protected@1,
        Protected_serialized@1,
        Unprotected@1,
        Payload@1,
        Signature@1} = case Message of
        {signed_sign1,
            Protected,
            Protected_serialized,
            Unprotected,
            Payload,
            Signature} -> {
        Protected,
            Protected_serialized,
            Unprotected,
            Payload,
            Signature};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"verify_with_aad"/utf8>>,
                        line => 196,
                        value => _assert_fail,
                        start => 5877,
                        'end' => 6005,
                        pattern_start => 5888,
                        pattern_end => 5995})
    end,
    gleam@result:'try'(
        gose@internal@cose_structure:extract_signing_alg_from_serialized(
            Protected_serialized@1
        ),
        fun(Actual_alg) ->
            gleam@result:'try'(
                gose@internal@key_helpers:require_matching_signing_algorithm(
                    Expected_signing_alg,
                    Actual_alg
                ),
                fun(_) ->
                    gleam@result:'try'(
                        gose@internal@cose_structure:validate_crit(
                            Protected@1,
                            Unprotected@1
                        ),
                        fun(_) ->
                            gleam@result:'try'(
                                gose@internal@cose_structure:require_embedded_payload(
                                    Payload@1
                                ),
                                fun(Payload_bytes) ->
                                    To_sign = build_sig_structure(
                                        Protected_serialized@1,
                                        Aad,
                                        Payload_bytes
                                    ),
                                    gose@internal@cose_structure:try_verify_keys(
                                        Expected_signing_alg,
                                        Keys,
                                        To_sign,
                                        Signature@1
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/sign1.gleam", 181).
?DOC(" Verify the signature of a signed COSE_Sign1 message against the verifier's expected algorithm and keys.\n").
-spec verify(verifier(), sign1(signed())) -> {ok, nil} |
    {error, gose:gose_error()}.
verify(Verifier, Message) ->
    verify_with_aad(Verifier, Message, <<>>).

-file("src/gose/cose/sign1.gleam", 239).
?DOC(" Verify a detached-payload COSE_Sign1 message with external AAD.\n").
-spec verify_detached_with_aad(
    verifier(),
    sign1(signed()),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
verify_detached_with_aad(Verifier, Message, Payload, Aad) ->
    {verifier, Expected_alg, Keys} = Verifier,
    Expected_signing_alg = {digital_signature, Expected_alg},
    {
    Protected@1,
        Protected_serialized@1,
        Unprotected@1,
        Existing_payload@1,
        Signature@1} = case Message of
        {signed_sign1,
            Protected,
            Protected_serialized,
            Unprotected,
            Existing_payload,
            Signature} -> {
        Protected,
            Protected_serialized,
            Unprotected,
            Existing_payload,
            Signature};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/sign1"/utf8>>,
                        function => <<"verify_detached_with_aad"/utf8>>,
                        line => 247,
                        value => _assert_fail,
                        start => 7392,
                        'end' => 7537,
                        pattern_start => 7403,
                        pattern_end => 7527})
    end,
    gleam@result:'try'(
        gose@internal@cose_structure:require_detached_payload(
            Existing_payload@1
        ),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@cose_structure:extract_signing_alg_from_serialized(
                    Protected_serialized@1
                ),
                fun(Actual_alg) ->
                    gleam@result:'try'(
                        gose@internal@key_helpers:require_matching_signing_algorithm(
                            Expected_signing_alg,
                            Actual_alg
                        ),
                        fun(_) ->
                            gleam@result:'try'(
                                gose@internal@cose_structure:validate_crit(
                                    Protected@1,
                                    Unprotected@1
                                ),
                                fun(_) ->
                                    To_sign = build_sig_structure(
                                        Protected_serialized@1,
                                        Aad,
                                        Payload
                                    ),
                                    gose@internal@cose_structure:try_verify_keys(
                                        Expected_signing_alg,
                                        Keys,
                                        To_sign,
                                        Signature@1
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/sign1.gleam", 230).
?DOC(
    " Verify the signature of a detached-payload COSE_Sign1 message.\n"
    "\n"
    " The caller must supply the payload that was detached from the message.\n"
    " Returns an error if the message already contains an embedded payload.\n"
).
-spec verify_detached(verifier(), sign1(signed()), bitstring()) -> {ok, nil} |
    {error, gose:gose_error()}.
verify_detached(Verifier, Message, Payload) ->
    verify_detached_with_aad(Verifier, Message, Payload, <<>>).

-file("src/gose/cose/sign1.gleam", 362).
-spec parse_cbor_value(gose@cbor:value()) -> {ok, sign1(signed())} |
    {error, gose:gose_error()}.
parse_cbor_value(Value) ->
    gleam@result:'try'(
        gose@internal@cose_structure:parse_cose_array_value(Value, 18, 4),
        fun(Items) -> case Items of
                [{bytes, Protected_serialized},
                    {map, Unprotected_cbor},
                    Payload_value,
                    {bytes, Signature}] ->
                    gleam@result:'try'(
                        gose@internal@cose_structure:decode_protected(
                            Protected_serialized
                        ),
                        fun(Protected) ->
                            gleam@result:'try'(
                                gose@internal@cose_structure:decode_unprotected(
                                    Unprotected_cbor
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
                                                            {ok,
                                                                {signed_sign1,
                                                                    Protected,
                                                                    Protected_serialized,
                                                                    Unprotected,
                                                                    Payload,
                                                                    Signature}}
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
                        {parse_error, <<"invalid COSE_Sign1 structure"/utf8>>}}
            end end
    ).

-file("src/gose/cose/sign1.gleam", 153).
?DOC(" Decode a CBOR-encoded COSE_Sign1 message, accepting both tagged and untagged forms.\n").
-spec parse(bitstring()) -> {ok, sign1(signed())} | {error, gose:gose_error()}.
parse(Data) ->
    gleam@result:'try'(
        gose@cbor:decode(Data),
        fun(Value) -> parse_cbor_value(Value) end
    ).
