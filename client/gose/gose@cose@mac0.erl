-module(gose@cose@mac0).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/mac0.gleam").
-export([new/1, serialize/1, serialize_tagged/1, payload/1, verifier/2, with_detached/1, with_aad/2, with_kid/2, with_content_type/2, with_critical/2, kid/1, content_type/1, critical/1, protected_headers/1, unprotected_headers/1, tag/3, verify_with_aad/3, verify/2, verify_detached_with_aad/4, verify_detached/3, parse/1]).
-export_type([untagged/0, tagged/0, mac0/1, verifier/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " COSE_Mac0 single-recipient MAC creation and verification\n"
    " ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html)).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/cose/mac0\n"
    "\n"
    " let k = gose.generate_hmac_key(gose.HmacSha256)\n"
    " let payload = <<\"hello\":utf8>>\n"
    "\n"
    " let assert Ok(tagged) =\n"
    "   mac0.new(gose.Hmac(gose.HmacSha256))\n"
    "   |> mac0.tag(k, payload)\n"
    "\n"
    " let data = mac0.serialize(tagged)\n"
    " let assert Ok(parsed) = mac0.parse(data)\n"
    " let assert Ok(verifier) =\n"
    "   mac0.verifier(gose.Hmac(gose.HmacSha256), keys: [k])\n"
    " let assert Ok(Nil) = mac0.verify(verifier, parsed)\n"
    " ```\n"
    "\n"
    " ## Phantom Types\n"
    "\n"
    " `Mac0(state)` uses a phantom type to track MAC state:\n"
    " - `Untagged`: created via `new`, ready to tag\n"
    " - `Tagged`: tagged or parsed, can be serialized or verified\n"
    "\n"
    " ## Algorithm Pinning\n"
    "\n"
    " Each verifier is pinned to a single algorithm. The token's protected\n"
    " header `alg` must match the verifier's expected algorithm.\n"
).

-type untagged() :: any().

-type tagged() :: any().

-opaque mac0(ROE) :: {untagged_mac0,
        list(gose@cose:header()),
        list(gose@cose:header()),
        boolean(),
        bitstring()} |
    {tagged_mac0,
        list(gose@cose:header()),
        bitstring(),
        list(gose@cose:header()),
        gleam@option:option(bitstring()),
        bitstring()} |
    {gleam_phantom, ROE}.

-opaque verifier() :: {verifier, gose:mac_alg(), list(gose:key(bitstring()))}.

-file("src/gose/cose/mac0.gleam", 74).
?DOC(" Create a new untagged COSE_Mac0 message with the given MAC algorithm in the protected header.\n").
-spec new(gose:mac_alg()) -> mac0(untagged()).
new(Alg) ->
    Alg_id = gose@cose:mac_alg_to_int(Alg),
    {untagged_mac0, [{alg, Alg_id}], [], false, <<>>}.

-file("src/gose/cose/mac0.gleam", 133).
-spec to_cbor_value(mac0(tagged())) -> gose@cbor:value().
to_cbor_value(Message) ->
    {Protected_serialized@1, Unprotected@1, Payload@1, Mac_tag@1} = case Message of
        {tagged_mac0, _, Protected_serialized, Unprotected, Payload, Mac_tag} -> {
        Protected_serialized,
            Unprotected,
            Payload,
            Mac_tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"to_cbor_value"/utf8>>,
                        line => 134,
                        value => _assert_fail,
                        start => 3890,
                        'end' => 4007,
                        pattern_start => 3901,
                        pattern_end => 3997})
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
            {bytes, Mac_tag@1}]}.

-file("src/gose/cose/mac0.gleam", 124).
?DOC(" Encode a tagged message as an untagged CBOR COSE_Mac0 array.\n").
-spec serialize(mac0(tagged())) -> bitstring().
serialize(Message) ->
    gose@cbor:encode(to_cbor_value(Message)).

-file("src/gose/cose/mac0.gleam", 129).
?DOC(" Encode a tagged message as a CBOR-tagged (tag 17) COSE_Mac0 structure.\n").
-spec serialize_tagged(mac0(tagged())) -> bitstring().
serialize_tagged(Message) ->
    gose@cbor:encode({tag, 17, to_cbor_value(Message)}).

-file("src/gose/cose/mac0.gleam", 162).
?DOC(" Return the payload from a tagged message. Returns `Error(Nil)` if detached.\n").
-spec payload(mac0(tagged())) -> {ok, bitstring()} | {error, nil}.
payload(Message) ->
    Payload@1 = case Message of
        {tagged_mac0, _, _, _, Payload, _} -> Payload;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"payload"/utf8>>,
                        line => 163,
                        value => _assert_fail,
                        start => 4649,
                        'end' => 4694,
                        pattern_start => 4660,
                        pattern_end => 4684})
    end,
    gleam@option:to_result(Payload@1, nil).

-file("src/gose/cose/mac0.gleam", 168).
?DOC(" Build a verifier pinned to a single algorithm and one or more keys.\n").
-spec verifier(gose:mac_alg(), list(gose:key(bitstring()))) -> {ok, verifier()} |
    {error, gose:gose_error()}.
verifier(Alg, Keys) ->
    Signing_alg = {mac, Alg},
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

-file("src/gose/cose/mac0.gleam", 280).
?DOC(
    " Mark the message for detached payload. The payload is still provided to\n"
    " `tag` for MAC computation but not included in the serialized output.\n"
).
-spec with_detached(mac0(untagged())) -> mac0(untagged()).
with_detached(Message) ->
    case Message of
        {untagged_mac0, _, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"with_detached"/utf8>>,
                        line => 281,
                        value => _assert_fail,
                        start => 8191,
                        'end' => 8228,
                        pattern_start => 8202,
                        pattern_end => 8218})
    end,
    {untagged_mac0,
        erlang:element(2, Message),
        erlang:element(3, Message),
        true,
        erlang:element(5, Message)}.

-file("src/gose/cose/mac0.gleam", 286).
?DOC(" Set external additional authenticated data (AAD) for the MAC operation.\n").
-spec with_aad(mac0(untagged()), bitstring()) -> mac0(untagged()).
with_aad(Message, Aad) ->
    case Message of
        {untagged_mac0, _, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"with_aad"/utf8>>,
                        line => 287,
                        value => _assert_fail,
                        start => 8432,
                        'end' => 8469,
                        pattern_start => 8443,
                        pattern_end => 8459})
    end,
    {untagged_mac0,
        erlang:element(2, Message),
        erlang:element(3, Message),
        erlang:element(4, Message),
        Aad}.

-file("src/gose/cose/mac0.gleam", 292).
?DOC(" Add a key ID to the unprotected headers.\n").
-spec with_kid(mac0(untagged()), bitstring()) -> mac0(untagged()).
with_kid(Message, Kid) ->
    Unprotected@1 = case Message of
        {untagged_mac0, _, Unprotected, _, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"with_kid"/utf8>>,
                        line => 293,
                        value => _assert_fail,
                        start => 8632,
                        'end' => 8683,
                        pattern_start => 8643,
                        pattern_end => 8673})
    end,
    {untagged_mac0,
        erlang:element(2, Message),
        [{kid, Kid} | Unprotected@1],
        erlang:element(4, Message),
        erlang:element(5, Message)}.

-file("src/gose/cose/mac0.gleam", 301).
?DOC(
    " Add a content type to the unprotected headers.\n"
    "\n"
    " RFC 9052 permits either bucket. MACed messages place it in unprotected,\n"
    " consistent with `with_kid`.\n"
).
-spec with_content_type(mac0(untagged()), gose@cose:content_type()) -> mac0(untagged()).
with_content_type(Message, Ct) ->
    Unprotected@1 = case Message of
        {untagged_mac0, _, Unprotected, _, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"with_content_type"/utf8>>,
                        line => 305,
                        value => _assert_fail,
                        start => 9025,
                        'end' => 9076,
                        pattern_start => 9036,
                        pattern_end => 9066})
    end,
    {untagged_mac0,
        erlang:element(2, Message),
        [{content_type, Ct} | Unprotected@1],
        erlang:element(4, Message),
        erlang:element(5, Message)}.

-file("src/gose/cose/mac0.gleam", 310).
?DOC(" Add critical header labels to the protected headers.\n").
-spec with_critical(mac0(untagged()), list(integer())) -> mac0(untagged()).
with_critical(Message, Labels) ->
    Protected@1 = case Message of
        {untagged_mac0, Protected, _, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"with_critical"/utf8>>,
                        line => 314,
                        value => _assert_fail,
                        start => 9316,
                        'end' => 9365,
                        pattern_start => 9327,
                        pattern_end => 9355})
    end,
    {untagged_mac0,
        [{crit, Labels} | Protected@1],
        erlang:element(3, Message),
        erlang:element(4, Message),
        erlang:element(5, Message)}.

-file("src/gose/cose/mac0.gleam", 319).
?DOC(" Extract the key ID from the message headers.\n").
-spec kid(mac0(tagged())) -> {ok, bitstring()} | {error, gose:gose_error()}.
kid(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {tagged_mac0, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"kid"/utf8>>,
                        line => 320,
                        value => _assert_fail,
                        start => 9563,
                        'end' => 9624,
                        pattern_start => 9574,
                        pattern_end => 9614})
    end,
    gose@cose:kid(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/mac0.gleam", 325).
?DOC(" Extract the content type from the message headers.\n").
-spec content_type(mac0(tagged())) -> {ok, gose@cose:content_type()} |
    {error, gose:gose_error()}.
content_type(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {tagged_mac0, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"content_type"/utf8>>,
                        line => 328,
                        value => _assert_fail,
                        start => 9827,
                        'end' => 9888,
                        pattern_start => 9838,
                        pattern_end => 9878})
    end,
    gose@cose:content_type(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/mac0.gleam", 333).
?DOC(" Extract the critical header labels from the message headers.\n").
-spec critical(mac0(tagged())) -> {ok, list(integer())} |
    {error, gose:gose_error()}.
critical(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {tagged_mac0, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"critical"/utf8>>,
                        line => 334,
                        value => _assert_fail,
                        start => 10094,
                        'end' => 10155,
                        pattern_start => 10105,
                        pattern_end => 10145})
    end,
    gose@cose:critical(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/mac0.gleam", 339).
?DOC(" Return the raw protected headers.\n").
-spec protected_headers(mac0(tagged())) -> list(gose@cose:header()).
protected_headers(Message) ->
    Protected@1 = case Message of
        {tagged_mac0, Protected, _, _, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"protected_headers"/utf8>>,
                        line => 340,
                        value => _assert_fail,
                        start => 10323,
                        'end' => 10370,
                        pattern_start => 10334,
                        pattern_end => 10360})
    end,
    Protected@1.

-file("src/gose/cose/mac0.gleam", 345).
?DOC(" Return the raw unprotected headers.\n").
-spec unprotected_headers(mac0(tagged())) -> list(gose@cose:header()).
unprotected_headers(Message) ->
    Unprotected@1 = case Message of
        {tagged_mac0, _, _, Unprotected, _, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"unprotected_headers"/utf8>>,
                        line => 346,
                        value => _assert_fail,
                        start => 10501,
                        'end' => 10550,
                        pattern_start => 10512,
                        pattern_end => 10540})
    end,
    Unprotected@1.

-file("src/gose/cose/mac0.gleam", 350).
-spec build_mac_structure(bitstring(), bitstring(), bitstring()) -> bitstring().
build_mac_structure(Protected_serialized, Aad, Payload) ->
    gose@cbor:encode(
        {array,
            [{text, <<"MAC0"/utf8>>},
                {bytes, Protected_serialized},
                {bytes, Aad},
                {bytes, Payload}]}
    ).

-file("src/gose/cose/mac0.gleam", 85).
?DOC(" Compute the MAC tag over the payload with the given key.\n").
-spec tag(mac0(untagged()), gose:key(bitstring()), bitstring()) -> {ok,
        mac0(tagged())} |
    {error, gose:gose_error()}.
tag(Message, Key, Payload) ->
    {Protected@1, Unprotected@1, Detached@1, Aad@1} = case Message of
        {untagged_mac0, Protected, Unprotected, Detached, Aad} -> {
        Protected,
            Unprotected,
            Detached,
            Aad};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"tag"/utf8>>,
                        line => 90,
                        value => _assert_fail,
                        start => 2503,
                        'end' => 2579,
                        pattern_start => 2514,
                        pattern_end => 2569})
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
                                            To_mac = build_mac_structure(
                                                Protected_serialized,
                                                Aad@1,
                                                Payload
                                            ),
                                            gleam@result:'try'(
                                                gose@internal@signing:compute_signature(
                                                    Alg,
                                                    Key,
                                                    To_mac
                                                ),
                                                fun(Computed_tag) ->
                                                    Stored_payload = case Detached@1 of
                                                        true ->
                                                            none;

                                                        false ->
                                                            {some, Payload}
                                                    end,
                                                    {ok,
                                                        {tagged_mac0,
                                                            Protected@1,
                                                            Protected_serialized,
                                                            Unprotected@1,
                                                            Stored_payload,
                                                            Computed_tag}}
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

-file("src/gose/cose/mac0.gleam", 192).
?DOC(" Verify the MAC tag with additional externally-supplied authenticated data (AAD).\n").
-spec verify_with_aad(verifier(), mac0(tagged()), bitstring()) -> {ok, nil} |
    {error, gose:gose_error()}.
verify_with_aad(Verifier, Message, Aad) ->
    {verifier, Expected_alg, Keys} = Verifier,
    Expected_signing_alg = {mac, Expected_alg},
    {
    Protected@1,
        Protected_serialized@1,
        Unprotected@1,
        Payload@1,
        Mac_tag@1} = case Message of
        {tagged_mac0,
            Protected,
            Protected_serialized,
            Unprotected,
            Payload,
            Mac_tag} -> {
        Protected,
            Protected_serialized,
            Unprotected,
            Payload,
            Mac_tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"verify_with_aad"/utf8>>,
                        line => 199,
                        value => _assert_fail,
                        start => 5747,
                        'end' => 5872,
                        pattern_start => 5758,
                        pattern_end => 5862})
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
                                    To_mac = build_mac_structure(
                                        Protected_serialized@1,
                                        Aad,
                                        Payload_bytes
                                    ),
                                    gose@internal@cose_structure:try_verify_keys(
                                        Expected_signing_alg,
                                        Keys,
                                        To_mac,
                                        Mac_tag@1
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/mac0.gleam", 184).
?DOC(" Verify the MAC tag of a COSE_Mac0 message against the verifier's expected algorithm and keys.\n").
-spec verify(verifier(), mac0(tagged())) -> {ok, nil} |
    {error, gose:gose_error()}.
verify(Verifier, Message) ->
    verify_with_aad(Verifier, Message, <<>>).

-file("src/gose/cose/mac0.gleam", 242).
?DOC(" Verify a detached-payload COSE_Mac0 message with external AAD.\n").
-spec verify_detached_with_aad(
    verifier(),
    mac0(tagged()),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
verify_detached_with_aad(Verifier, Message, Payload, Aad) ->
    {verifier, Expected_alg, Keys} = Verifier,
    Expected_signing_alg = {mac, Expected_alg},
    {
    Protected@1,
        Protected_serialized@1,
        Unprotected@1,
        Existing_payload@1,
        Mac_tag@1} = case Message of
        {tagged_mac0,
            Protected,
            Protected_serialized,
            Unprotected,
            Existing_payload,
            Mac_tag} -> {
        Protected,
            Protected_serialized,
            Unprotected,
            Existing_payload,
            Mac_tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/mac0"/utf8>>,
                        function => <<"verify_detached_with_aad"/utf8>>,
                        line => 250,
                        value => _assert_fail,
                        start => 7246,
                        'end' => 7388,
                        pattern_start => 7257,
                        pattern_end => 7378})
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
                                    To_mac = build_mac_structure(
                                        Protected_serialized@1,
                                        Aad,
                                        Payload
                                    ),
                                    gose@internal@cose_structure:try_verify_keys(
                                        Expected_signing_alg,
                                        Keys,
                                        To_mac,
                                        Mac_tag@1
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/mac0.gleam", 233).
?DOC(
    " Verify the MAC tag of a detached-payload COSE_Mac0 message.\n"
    "\n"
    " The caller must supply the payload that was detached from the message.\n"
    " Returns an error if the message already contains an embedded payload.\n"
).
-spec verify_detached(verifier(), mac0(tagged()), bitstring()) -> {ok, nil} |
    {error, gose:gose_error()}.
verify_detached(Verifier, Message, Payload) ->
    verify_detached_with_aad(Verifier, Message, Payload, <<>>).

-file("src/gose/cose/mac0.gleam", 365).
-spec parse_cbor_value(gose@cbor:value()) -> {ok, mac0(tagged())} |
    {error, gose:gose_error()}.
parse_cbor_value(Value) ->
    gleam@result:'try'(
        gose@internal@cose_structure:parse_cose_array_value(Value, 17, 4),
        fun(Items) -> case Items of
                [{bytes, Protected_serialized},
                    {map, Unprotected_cbor},
                    Payload_value,
                    {bytes, Mac_tag}] ->
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
                                                                {tagged_mac0,
                                                                    Protected,
                                                                    Protected_serialized,
                                                                    Unprotected,
                                                                    Payload,
                                                                    Mac_tag}}
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
                        {parse_error, <<"invalid COSE_Mac0 structure"/utf8>>}}
            end end
    ).

-file("src/gose/cose/mac0.gleam", 156).
?DOC(" Decode a CBOR-encoded COSE_Mac0 message, accepting both tagged and untagged forms.\n").
-spec parse(bitstring()) -> {ok, mac0(tagged())} | {error, gose:gose_error()}.
parse(Data) ->
    gleam@result:'try'(
        gose@cbor:decode(Data),
        fun(Value) -> parse_cbor_value(Value) end
    ).
