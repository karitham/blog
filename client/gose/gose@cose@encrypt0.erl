-module(gose@cose@encrypt0).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/encrypt0.gleam").
-export([new/1, decryptor/2, serialize/1, serialize_tagged/1, with_aad/2, with_kid/2, with_content_type/2, with_critical/2, kid/1, content_type/1, critical/1, protected_headers/1, unprotected_headers/1, encrypt/3, decrypt_with_aad/3, decrypt/2, parse/1]).
-export_type([unencrypted/0, encrypted/0, decryptor/0, encrypt0/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " COSE_Encrypt0 single-recipient encryption and decryption\n"
    " ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html)).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/cose/encrypt0\n"
    "\n"
    " let k = gose.generate_enc_key(gose.AesGcm(gose.Aes128))\n"
    " let plaintext = <<\"hello COSE\":utf8>>\n"
    "\n"
    " let assert Ok(message) = encrypt0.new(gose.AesGcm(gose.Aes128))\n"
    " let assert Ok(encrypted) = encrypt0.encrypt(message, k, plaintext)\n"
    "\n"
    " let data = encrypt0.serialize(encrypted)\n"
    " let assert Ok(parsed) = encrypt0.parse(data)\n"
    " let assert Ok(decryptor) = encrypt0.decryptor(gose.AesGcm(gose.Aes128), key: k)\n"
    " let assert Ok(decrypted) = encrypt0.decrypt(decryptor, parsed)\n"
    " ```\n"
    "\n"
    " ## Phantom Types\n"
    "\n"
    " `Encrypt0(state)` uses a phantom type to track encryption state:\n"
    " - `Unencrypted`: created via `new`, ready to encrypt\n"
    " - `Encrypted`: encrypted or parsed, can be serialized or decrypted\n"
).

-type unencrypted() :: any().

-type encrypted() :: any().

-opaque decryptor() :: {decryptor, gose:content_alg(), gose:key(bitstring())}.

-opaque encrypt0(RFA) :: {unencrypted_encrypt0,
        list(gose@cose:header()),
        list(gose@cose:header()),
        bitstring()} |
    {encrypted_encrypt0,
        list(gose@cose:header()),
        bitstring(),
        list(gose@cose:header()),
        bitstring()} |
    {gleam_phantom, RFA}.

-file("src/gose/cose/encrypt0.gleam", 65).
?DOC(" Create a new unencrypted COSE_Encrypt0 message with the given content encryption algorithm.\n").
-spec new(gose:content_alg()) -> {ok, encrypt0(unencrypted())} |
    {error, gose:gose_error()}.
new(Alg) ->
    gleam@result:'try'(
        gose@cose:content_alg_to_int(Alg),
        fun(Alg_id) ->
            {ok, {unencrypted_encrypt0, [{alg, Alg_id}], [], <<>>}}
        end
    ).

-file("src/gose/cose/encrypt0.gleam", 121).
?DOC(" Build a decryptor pinned to a single algorithm and key.\n").
-spec decryptor(gose:content_alg(), gose:key(bitstring())) -> {ok, decryptor()} |
    {error, gose:gose_error()}.
decryptor(Alg, Key) ->
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_content_decryption(Alg, Key),
        fun(_) -> {ok, {decryptor, Alg, Key}} end
    ).

-file("src/gose/cose/encrypt0.gleam", 192).
-spec to_cbor_value(encrypt0(encrypted())) -> gose@cbor:value().
to_cbor_value(Message) ->
    {Protected_serialized@1, Unprotected@1, Ciphertext@1} = case Message of
        {encrypted_encrypt0, _, Protected_serialized, Unprotected, Ciphertext} -> {
        Protected_serialized,
            Unprotected,
            Ciphertext};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"to_cbor_value"/utf8>>,
                        line => 193,
                        value => _assert_fail,
                        start => 5612,
                        'end' => 5725,
                        pattern_start => 5623,
                        pattern_end => 5715})
    end,
    {array,
        [{bytes, Protected_serialized@1},
            {map, gose@cose:headers_to_cbor(Unprotected@1)},
            {bytes, Ciphertext@1}]}.

-file("src/gose/cose/encrypt0.gleam", 183).
?DOC(" Encode an encrypted message as an untagged CBOR COSE_Encrypt0 array.\n").
-spec serialize(encrypt0(encrypted())) -> bitstring().
serialize(Message) ->
    gose@cbor:encode(to_cbor_value(Message)).

-file("src/gose/cose/encrypt0.gleam", 188).
?DOC(" Encode an encrypted message as a CBOR-tagged (tag 16) COSE_Encrypt0 structure.\n").
-spec serialize_tagged(encrypt0(encrypted())) -> bitstring().
serialize_tagged(Message) ->
    gose@cbor:encode({tag, 16, to_cbor_value(Message)}).

-file("src/gose/cose/encrypt0.gleam", 214).
?DOC(" Set external additional authenticated data (AAD) for the encryption operation.\n").
-spec with_aad(encrypt0(unencrypted()), bitstring()) -> encrypt0(unencrypted()).
with_aad(Message, Aad) ->
    case Message of
        {unencrypted_encrypt0, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"with_aad"/utf8>>,
                        line => 218,
                        value => _assert_fail,
                        start => 6294,
                        'end' => 6338,
                        pattern_start => 6305,
                        pattern_end => 6328})
    end,
    {unencrypted_encrypt0,
        erlang:element(2, Message),
        erlang:element(3, Message),
        Aad}.

-file("src/gose/cose/encrypt0.gleam", 223).
?DOC(" Add a key ID to the unprotected headers.\n").
-spec with_kid(encrypt0(unencrypted()), bitstring()) -> encrypt0(unencrypted()).
with_kid(Message, Kid) ->
    Unprotected@1 = case Message of
        {unencrypted_encrypt0, _, Unprotected, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"with_kid"/utf8>>,
                        line => 227,
                        value => _assert_fail,
                        start => 6525,
                        'end' => 6583,
                        pattern_start => 6536,
                        pattern_end => 6573})
    end,
    {unencrypted_encrypt0,
        erlang:element(2, Message),
        [{kid, Kid} | Unprotected@1],
        erlang:element(4, Message)}.

-file("src/gose/cose/encrypt0.gleam", 235).
?DOC(
    " Add a content type to the protected headers.\n"
    "\n"
    " RFC 9052 permits either bucket. Encrypted messages place it in protected\n"
    " so it is covered by the AEAD authentication.\n"
).
-spec with_content_type(encrypt0(unencrypted()), gose@cose:content_type()) -> encrypt0(unencrypted()).
with_content_type(Message, Ct) ->
    Protected@1 = case Message of
        {unencrypted_encrypt0, Protected, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"with_content_type"/utf8>>,
                        line => 239,
                        value => _assert_fail,
                        start => 6962,
                        'end' => 7018,
                        pattern_start => 6973,
                        pattern_end => 7008})
    end,
    {unencrypted_encrypt0,
        [{content_type, Ct} | Protected@1],
        erlang:element(3, Message),
        erlang:element(4, Message)}.

-file("src/gose/cose/encrypt0.gleam", 244).
?DOC(" Add critical header labels to the protected headers.\n").
-spec with_critical(encrypt0(unencrypted()), list(integer())) -> encrypt0(unencrypted()).
with_critical(Message, Labels) ->
    Protected@1 = case Message of
        {unencrypted_encrypt0, Protected, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"with_critical"/utf8>>,
                        line => 248,
                        value => _assert_fail,
                        start => 7268,
                        'end' => 7324,
                        pattern_start => 7279,
                        pattern_end => 7314})
    end,
    {unencrypted_encrypt0,
        [{crit, Labels} | Protected@1],
        erlang:element(3, Message),
        erlang:element(4, Message)}.

-file("src/gose/cose/encrypt0.gleam", 253).
?DOC(" Extract the key ID from the message headers.\n").
-spec kid(encrypt0(encrypted())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
kid(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {encrypted_encrypt0, Protected, _, Unprotected, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"kid"/utf8>>,
                        line => 254,
                        value => _assert_fail,
                        start => 7536,
                        'end' => 7604,
                        pattern_start => 7547,
                        pattern_end => 7594})
    end,
    gose@cose:kid(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/encrypt0.gleam", 259).
?DOC(" Extract the content type from the message headers.\n").
-spec content_type(encrypt0(encrypted())) -> {ok, gose@cose:content_type()} |
    {error, gose:gose_error()}.
content_type(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {encrypted_encrypt0, Protected, _, Unprotected, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"content_type"/utf8>>,
                        line => 262,
                        value => _assert_fail,
                        start => 7814,
                        'end' => 7882,
                        pattern_start => 7825,
                        pattern_end => 7872})
    end,
    gose@cose:content_type(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/encrypt0.gleam", 267).
?DOC(" Extract the critical header labels from the message headers.\n").
-spec critical(encrypt0(encrypted())) -> {ok, list(integer())} |
    {error, gose:gose_error()}.
critical(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {encrypted_encrypt0, Protected, _, Unprotected, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"critical"/utf8>>,
                        line => 270,
                        value => _assert_fail,
                        start => 8100,
                        'end' => 8168,
                        pattern_start => 8111,
                        pattern_end => 8158})
    end,
    gose@cose:critical(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/encrypt0.gleam", 275).
?DOC(" Return the raw protected headers.\n").
-spec protected_headers(encrypt0(encrypted())) -> list(gose@cose:header()).
protected_headers(Message) ->
    Protected@1 = case Message of
        {encrypted_encrypt0, Protected, _, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"protected_headers"/utf8>>,
                        line => 276,
                        value => _assert_fail,
                        start => 8343,
                        'end' => 8397,
                        pattern_start => 8354,
                        pattern_end => 8387})
    end,
    Protected@1.

-file("src/gose/cose/encrypt0.gleam", 281).
?DOC(" Return the raw unprotected headers.\n").
-spec unprotected_headers(encrypt0(encrypted())) -> list(gose@cose:header()).
unprotected_headers(Message) ->
    Unprotected@1 = case Message of
        {encrypted_encrypt0, _, _, Unprotected, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"unprotected_headers"/utf8>>,
                        line => 282,
                        value => _assert_fail,
                        start => 8535,
                        'end' => 8591,
                        pattern_start => 8546,
                        pattern_end => 8581})
    end,
    Unprotected@1.

-file("src/gose/cose/encrypt0.gleam", 286).
-spec extract_cek(gose:key(bitstring())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
extract_cek(Key) ->
    gose:material_octet_secret(gose:material(Key)).

-file("src/gose/cose/encrypt0.gleam", 79).
?DOC(" Encrypt the plaintext with the given symmetric key.\n").
-spec encrypt(encrypt0(unencrypted()), gose:key(bitstring()), bitstring()) -> {ok,
        encrypt0(encrypted())} |
    {error, gose:gose_error()}.
encrypt(Message, Key, Plaintext) ->
    {Protected@1, Unprotected@1, Aad@1} = case Message of
        {unencrypted_encrypt0, Protected, Unprotected, Aad} -> {
        Protected,
            Unprotected,
            Aad};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"encrypt"/utf8>>,
                        line => 84,
                        value => _assert_fail,
                        start => 2517,
                        'end' => 2589,
                        pattern_start => 2528,
                        pattern_end => 2579})
    end,
    gleam@result:'try'(
        gose@internal@cose_structure:extract_content_alg_from_headers(
            Protected@1
        ),
        fun(Alg) ->
            gleam@result:'try'(
                gose@internal@key_helpers:validate_key_for_content_encryption(
                    Alg,
                    Key
                ),
                fun(_) ->
                    gleam@result:'try'(
                        extract_cek(Key),
                        fun(Cek) ->
                            Protected_serialized = gose@internal@cose_structure:serialize_protected(
                                Protected@1
                            ),
                            Iv = gose@internal@content_encryption:generate_iv(
                                Alg
                            ),
                            Aad@2 = gose@internal@cose_structure:build_enc_structure(
                                <<"Encrypt0"/utf8>>,
                                Protected_serialized,
                                Aad@1
                            ),
                            gleam@result:'try'(
                                gose@internal@content_encryption:encrypt_content(
                                    Alg,
                                    Cek,
                                    Iv,
                                    Aad@2,
                                    Plaintext
                                ),
                                fun(_use0) ->
                                    {Ciphertext, Tag} = _use0,
                                    Ciphertext_with_tag = gleam_stdlib:bit_array_concat(
                                        [Ciphertext, Tag]
                                    ),
                                    Unprotected@2 = [{iv, Iv} | Unprotected@1],
                                    {ok,
                                        {encrypted_encrypt0,
                                            Protected@1,
                                            Protected_serialized,
                                            Unprotected@2,
                                            Ciphertext_with_tag}}
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt0.gleam", 138).
?DOC(" Decrypt with additional externally-supplied authenticated data (AAD).\n").
-spec decrypt_with_aad(decryptor(), encrypt0(encrypted()), bitstring()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
decrypt_with_aad(Decryptor, Message, Aad) ->
    {decryptor, Expected_alg, Key} = Decryptor,
    {
    Protected@1,
        Protected_serialized@1,
        Unprotected@1,
        Ciphertext_with_tag@1} = case Message of
        {encrypted_encrypt0,
            Protected,
            Protected_serialized,
            Unprotected,
            Ciphertext_with_tag} -> {
        Protected,
            Protected_serialized,
            Unprotected,
            Ciphertext_with_tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt0"/utf8>>,
                        function => <<"decrypt_with_aad"/utf8>>,
                        line => 144,
                        value => _assert_fail,
                        start => 4228,
                        'end' => 4369,
                        pattern_start => 4239,
                        pattern_end => 4359})
    end,
    gleam@result:'try'(
        gose@internal@cose_structure:extract_content_alg_from_serialized(
            Protected_serialized@1
        ),
        fun(Actual_alg) ->
            gleam@result:'try'(
                gose@internal@key_helpers:require_matching_content_algorithm(
                    Expected_alg,
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
                                extract_cek(Key),
                                fun(Cek) ->
                                    gleam@result:'try'(
                                        gose@cose:iv(Unprotected@1),
                                        fun(Iv) ->
                                            gleam@result:'try'(
                                                gose@internal@cose_structure:split_ciphertext_tag(
                                                    Ciphertext_with_tag@1,
                                                    gose@internal@content_encryption:tag_size(
                                                        Expected_alg
                                                    )
                                                ),
                                                fun(_use0) ->
                                                    {Ciphertext, Tag} = _use0,
                                                    Aad@1 = gose@internal@cose_structure:build_enc_structure(
                                                        <<"Encrypt0"/utf8>>,
                                                        Protected_serialized@1,
                                                        Aad
                                                    ),
                                                    gose@internal@content_encryption:decrypt_content(
                                                        Expected_alg,
                                                        Cek,
                                                        Iv,
                                                        Aad@1,
                                                        Ciphertext,
                                                        Tag
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

-file("src/gose/cose/encrypt0.gleam", 130).
?DOC(" Decrypt a COSE_Encrypt0 message, returning the plaintext.\n").
-spec decrypt(decryptor(), encrypt0(encrypted())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
decrypt(Decryptor, Message) ->
    decrypt_with_aad(Decryptor, Message, <<>>).

-file("src/gose/cose/encrypt0.gleam", 290).
-spec parse_cbor_value(gose@cbor:value()) -> {ok, encrypt0(encrypted())} |
    {error, gose:gose_error()}.
parse_cbor_value(Value) ->
    gleam@result:'try'(
        gose@internal@cose_structure:parse_cose_array_value(Value, 16, 3),
        fun(Items) -> case Items of
                [{bytes, Protected_serialized},
                    {map, Unprotected_cbor},
                    {bytes, Ciphertext}] ->
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
                                                    {ok,
                                                        {encrypted_encrypt0,
                                                            Protected,
                                                            Protected_serialized,
                                                            Unprotected,
                                                            Ciphertext}}
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
                        {parse_error,
                            <<"invalid COSE_Encrypt0 structure"/utf8>>}}
            end end
    ).

-file("src/gose/cose/encrypt0.gleam", 208).
?DOC(" Decode a CBOR-encoded COSE_Encrypt0 message, accepting both tagged and untagged forms.\n").
-spec parse(bitstring()) -> {ok, encrypt0(encrypted())} |
    {error, gose:gose_error()}.
parse(Data) ->
    gleam@result:'try'(
        gose@cbor:decode(Data),
        fun(Value) -> parse_cbor_value(Value) end
    ).
