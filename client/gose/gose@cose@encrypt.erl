-module(gose@cose@encrypt).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/encrypt.gleam").
-export([new/1, new_direct_recipient/1, new_aes_kw_recipient/2, new_rsa_recipient/2, new_ecdh_es_direct_recipient/2, new_ecdh_es_aes_kw_recipient/2, with_apu/2, with_apv/2, add_recipient/2, with_aad/2, with_kid/2, with_content_type/2, with_critical/2, decryptor/3, ecdh_es_direct_decryptor/3, kid/1, content_type/1, critical/1, protected_headers/1, unprotected_headers/1, serialize/1, serialize_tagged/1, parse/1, derive_cose_ecdh_key/7, encrypt/2, decrypt_with_aad/3, decrypt/2]).
-export_type([unencrypted/0, encrypted/0, ecdh_es_direct_variant/0, pending_recipient/0, direct/0, aes_kw/0, rsa/0, ecdh_es/0, recipient/1, encrypted_recipient/0, encrypt/1, decryptor/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " COSE_Encrypt multi-recipient encryption and decryption\n"
    " ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html)).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/cose/encrypt\n"
    "\n"
    " let k = gose.generate_enc_key(gose.AesGcm(gose.Aes128))\n"
    " let plaintext = <<\"hello COSE\":utf8>>\n"
    "\n"
    " let assert Ok(message) = encrypt.new(gose.AesGcm(gose.Aes128))\n"
    " let assert Ok(r) = encrypt.new_aes_kw_recipient(gose.Aes128, key: k)\n"
    " let message = encrypt.add_recipient(message, r)\n"
    " let assert Ok(encrypted) = encrypt.encrypt(message, plaintext)\n"
    "\n"
    " let data = encrypt.serialize(encrypted)\n"
    " let assert Ok(parsed) = encrypt.parse(data)\n"
    " let assert Ok(decryptor) =\n"
    "   encrypt.decryptor(\n"
    "     gose.AesKeyWrap(gose.AesKw, gose.Aes128),\n"
    "     gose.AesGcm(gose.Aes128),\n"
    "     keys: [k],\n"
    "   )\n"
    " let assert Ok(decrypted) = encrypt.decrypt(decryptor, parsed)\n"
    " ```\n"
).

-type unencrypted() :: any().

-type encrypted() :: any().

-type ecdh_es_direct_variant() :: ecdh_es_hkdf256 | ecdh_es_hkdf512.

-type pending_recipient() :: {pending_recipient,
        gose:key_encryption_alg(),
        gose:key(bitstring()),
        gleam@option:option(ecdh_es_direct_variant()),
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring())}.

-type direct() :: any().

-type aes_kw() :: any().

-type rsa() :: any().

-type ecdh_es() :: any().

-opaque recipient(QAD) :: {recipient, pending_recipient()} |
    {gleam_phantom, QAD}.

-type encrypted_recipient() :: {encrypted_recipient,
        list(gose@cose:header()),
        bitstring(),
        list(gose@cose:header()),
        bitstring()}.

-opaque encrypt(QAE) :: {unencrypted_encrypt,
        gose:content_alg(),
        list(gose@cose:header()),
        list(gose@cose:header()),
        list(pending_recipient()),
        bitstring()} |
    {encrypted_encrypt,
        list(gose@cose:header()),
        bitstring(),
        list(gose@cose:header()),
        bitstring(),
        list(encrypted_recipient())} |
    {gleam_phantom, QAE}.

-opaque decryptor() :: {decryptor,
        gose:key_encryption_alg(),
        gose:content_alg(),
        list(gose:key(bitstring())),
        gleam@option:option(ecdh_es_direct_variant())}.

-file("src/gose/cose/encrypt.gleam", 130).
?DOC(" Create a new COSE_Encrypt message with the given content encryption algorithm.\n").
-spec new(gose:content_alg()) -> {ok, encrypt(unencrypted())} |
    {error, gose:gose_error()}.
new(Enc) ->
    gleam@result:'try'(
        gose@cose:content_alg_to_int(Enc),
        fun(Alg_id) ->
            {ok, {unencrypted_encrypt, Enc, [{alg, Alg_id}], [], [], <<>>}}
        end
    ).

-file("src/gose/cose/encrypt.gleam", 193).
-spec new_pending(
    gose:key_encryption_alg(),
    gose:key(bitstring()),
    gleam@option:option(ecdh_es_direct_variant())
) -> recipient(any()).
new_pending(Alg, Key, Ecdh_es_variant) ->
    {recipient, {pending_recipient, Alg, Key, Ecdh_es_variant, none, none}}.

-file("src/gose/cose/encrypt.gleam", 144).
?DOC(" Build a direct-shared-secret recipient.\n").
-spec new_direct_recipient(gose:key(bitstring())) -> {ok, recipient(direct())} |
    {error, gose:gose_error()}.
new_direct_recipient(Key) ->
    Alg = direct,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(Alg, Key),
        fun(_) -> {ok, new_pending(Alg, Key, none)} end
    ).

-file("src/gose/cose/encrypt.gleam", 153).
?DOC(" Build an AES Key Wrap recipient.\n").
-spec new_aes_kw_recipient(gose:aes_key_size(), gose:key(bitstring())) -> {ok,
        recipient(aes_kw())} |
    {error, gose:gose_error()}.
new_aes_kw_recipient(Size, Key) ->
    Alg = {aes_key_wrap, aes_kw, Size},
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(Alg, Key),
        fun(_) -> {ok, new_pending(Alg, Key, none)} end
    ).

-file("src/gose/cose/encrypt.gleam", 163).
?DOC(" Build an RSA-OAEP recipient.\n").
-spec new_rsa_recipient(gose:rsa_encryption_alg(), gose:key(bitstring())) -> {ok,
        recipient(rsa())} |
    {error, gose:gose_error()}.
new_rsa_recipient(Rsa_alg, Key) ->
    Alg = {rsa_encryption, Rsa_alg},
    gleam@result:'try'(
        gose@cose:key_encryption_alg_to_int(Alg),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@key_helpers:validate_key_for_jwe_encryption(
                    Alg,
                    Key
                ),
                fun(_) -> {ok, new_pending(Alg, Key, none)} end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 174).
?DOC(" Build an ECDH-ES direct recipient with a specific HKDF variant.\n").
-spec new_ecdh_es_direct_recipient(
    ecdh_es_direct_variant(),
    gose:key(bitstring())
) -> {ok, recipient(ecdh_es())} | {error, gose:gose_error()}.
new_ecdh_es_direct_recipient(Variant, Key) ->
    Alg = {ecdh_es, ecdh_es_direct},
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(Alg, Key),
        fun(_) -> {ok, new_pending(Alg, Key, {some, Variant})} end
    ).

-file("src/gose/cose/encrypt.gleam", 184).
?DOC(" Build an ECDH-ES + AES-KW recipient.\n").
-spec new_ecdh_es_aes_kw_recipient(gose:aes_key_size(), gose:key(bitstring())) -> {ok,
        recipient(ecdh_es())} |
    {error, gose:gose_error()}.
new_ecdh_es_aes_kw_recipient(Size, Key) ->
    Alg = {ecdh_es, {ecdh_es_aes_kw, Size}},
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(Alg, Key),
        fun(_) -> {ok, new_pending(Alg, Key, none)} end
    ).

-file("src/gose/cose/encrypt.gleam", 208).
?DOC(" Set the PartyU identity (apu) for an ECDH-ES recipient.\n").
-spec with_apu(recipient(ecdh_es()), bitstring()) -> recipient(ecdh_es()).
with_apu(R, Apu) ->
    {recipient,
        begin
            _record = erlang:element(2, R),
            {pending_recipient,
                erlang:element(2, _record),
                erlang:element(3, _record),
                erlang:element(4, _record),
                {some, Apu},
                erlang:element(6, _record)}
        end}.

-file("src/gose/cose/encrypt.gleam", 213).
?DOC(" Set the PartyV identity (apv) for an ECDH-ES recipient.\n").
-spec with_apv(recipient(ecdh_es()), bitstring()) -> recipient(ecdh_es()).
with_apv(R, Apv) ->
    {recipient,
        begin
            _record = erlang:element(2, R),
            {pending_recipient,
                erlang:element(2, _record),
                erlang:element(3, _record),
                erlang:element(4, _record),
                erlang:element(5, _record),
                {some, Apv}}
        end}.

-file("src/gose/cose/encrypt.gleam", 218).
?DOC(" Add a built recipient to the message.\n").
-spec add_recipient(encrypt(unencrypted()), recipient(any())) -> encrypt(unencrypted()).
add_recipient(Message, Recipient) ->
    Recipients@1 = case Message of
        {unencrypted_encrypt, _, _, _, Recipients, _} -> Recipients;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"add_recipient"/utf8>>,
                        line => 222,
                        value => _assert_fail,
                        start => 6735,
                        'end' => 6791,
                        pattern_start => 6746,
                        pattern_end => 6781})
    end,
    {unencrypted_encrypt,
        erlang:element(2, Message),
        erlang:element(3, Message),
        erlang:element(4, Message),
        lists:append(Recipients@1, [erlang:element(2, Recipient)]),
        erlang:element(6, Message)}.

-file("src/gose/cose/encrypt.gleam", 230).
?DOC(" Set external additional authenticated data (AAD) for the encryption operation.\n").
-spec with_aad(encrypt(unencrypted()), bitstring()) -> encrypt(unencrypted()).
with_aad(Message, Aad) ->
    case Message of
        {unencrypted_encrypt, _, _, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"with_aad"/utf8>>,
                        line => 234,
                        value => _assert_fail,
                        start => 7082,
                        'end' => 7125,
                        pattern_start => 7093,
                        pattern_end => 7115})
    end,
    {unencrypted_encrypt,
        erlang:element(2, Message),
        erlang:element(3, Message),
        erlang:element(4, Message),
        erlang:element(5, Message),
        Aad}.

-file("src/gose/cose/encrypt.gleam", 239).
?DOC(" Add a key ID to the unprotected headers.\n").
-spec with_kid(encrypt(unencrypted()), bitstring()) -> encrypt(unencrypted()).
with_kid(Message, Kid) ->
    Unprotected@1 = case Message of
        {unencrypted_encrypt, _, _, Unprotected, _, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"with_kid"/utf8>>,
                        line => 243,
                        value => _assert_fail,
                        start => 7309,
                        'end' => 7366,
                        pattern_start => 7320,
                        pattern_end => 7356})
    end,
    {unencrypted_encrypt,
        erlang:element(2, Message),
        erlang:element(3, Message),
        [{kid, Kid} | Unprotected@1],
        erlang:element(5, Message),
        erlang:element(6, Message)}.

-file("src/gose/cose/encrypt.gleam", 251).
?DOC(
    " Add a content type to the protected headers.\n"
    "\n"
    " RFC 9052 permits either bucket. Encrypted messages place it in protected\n"
    " so it is covered by the AEAD authentication.\n"
).
-spec with_content_type(encrypt(unencrypted()), gose@cose:content_type()) -> encrypt(unencrypted()).
with_content_type(Message, Ct) ->
    Protected@1 = case Message of
        {unencrypted_encrypt, _, Protected, _, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"with_content_type"/utf8>>,
                        line => 255,
                        value => _assert_fail,
                        start => 7742,
                        'end' => 7797,
                        pattern_start => 7753,
                        pattern_end => 7787})
    end,
    {unencrypted_encrypt,
        erlang:element(2, Message),
        [{content_type, Ct} | Protected@1],
        erlang:element(4, Message),
        erlang:element(5, Message),
        erlang:element(6, Message)}.

-file("src/gose/cose/encrypt.gleam", 260).
?DOC(" Add critical header labels to the protected headers.\n").
-spec with_critical(encrypt(unencrypted()), list(integer())) -> encrypt(unencrypted()).
with_critical(Message, Labels) ->
    Protected@1 = case Message of
        {unencrypted_encrypt, _, Protected, _, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"with_critical"/utf8>>,
                        line => 264,
                        value => _assert_fail,
                        start => 8044,
                        'end' => 8099,
                        pattern_start => 8055,
                        pattern_end => 8089})
    end,
    {unencrypted_encrypt,
        erlang:element(2, Message),
        [{crit, Labels} | Protected@1],
        erlang:element(4, Message),
        erlang:element(5, Message),
        erlang:element(6, Message)}.

-file("src/gose/cose/encrypt.gleam", 323).
?DOC(
    " Build a decryptor pinned to expected algorithms and keys.\n"
    "\n"
    " For `EcdhEs(EcdhEsDirect)`, use `ecdh_es_direct_decryptor` instead so the\n"
    " HKDF variant (HKDF-256 or HKDF-512) is chosen explicitly.\n"
).
-spec decryptor(
    gose:key_encryption_alg(),
    gose:content_alg(),
    list(gose:key(bitstring()))
) -> {ok, decryptor()} | {error, gose:gose_error()}.
decryptor(Key_alg, Content_alg, Keys) ->
    gleam@bool:guard(
        Key_alg =:= {ecdh_es, ecdh_es_direct},
        {error,
            {invalid_state,
                <<"use ecdh_es_direct_decryptor to choose HKDF variant"/utf8>>}},
        fun() ->
            gleam@result:'try'(
                gose@cose:key_encryption_alg_to_int(Key_alg),
                fun(_) ->
                    gose@internal@key_helpers:require_non_empty_keys(
                        Keys,
                        fun() ->
                            gleam@result:'try'(
                                gleam@list:try_each(
                                    Keys,
                                    fun(_capture) ->
                                        gose@internal@key_helpers:validate_key_for_jwe_decryption(
                                            Key_alg,
                                            _capture
                                        )
                                    end
                                ),
                                fun(_) ->
                                    {ok,
                                        {decryptor,
                                            Key_alg,
                                            Content_alg,
                                            Keys,
                                            none}}
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 346).
?DOC(
    " Build a decryptor for ECDH-ES direct with a specific HKDF variant.\n"
    "\n"
    " Use this instead of `decryptor` when you need to decrypt messages\n"
    " encrypted with ECDH-ES+HKDF-512 (COSE algorithm -26).\n"
).
-spec ecdh_es_direct_decryptor(
    ecdh_es_direct_variant(),
    gose:content_alg(),
    list(gose:key(bitstring()))
) -> {ok, decryptor()} | {error, gose:gose_error()}.
ecdh_es_direct_decryptor(Variant, Content_alg, Keys) ->
    Key_alg = {ecdh_es, ecdh_es_direct},
    gose@internal@key_helpers:require_non_empty_keys(
        Keys,
        fun() ->
            gleam@result:'try'(
                gleam@list:try_each(
                    Keys,
                    fun(_capture) ->
                        gose@internal@key_helpers:validate_key_for_jwe_decryption(
                            Key_alg,
                            _capture
                        )
                    end
                ),
                fun(_) ->
                    {ok,
                        {decryptor, Key_alg, Content_alg, Keys, {some, Variant}}}
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 465).
?DOC(" Extract the key ID from the message headers.\n").
-spec kid(encrypt(encrypted())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
kid(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {encrypted_encrypt, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"kid"/utf8>>,
                        line => 466,
                        value => _assert_fail,
                        start => 13896,
                        'end' => 13963,
                        pattern_start => 13907,
                        pattern_end => 13953})
    end,
    gose@cose:kid(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/encrypt.gleam", 471).
?DOC(" Extract the content type from the message headers.\n").
-spec content_type(encrypt(encrypted())) -> {ok, gose@cose:content_type()} |
    {error, gose:gose_error()}.
content_type(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {encrypted_encrypt, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"content_type"/utf8>>,
                        line => 474,
                        value => _assert_fail,
                        start => 14172,
                        'end' => 14239,
                        pattern_start => 14183,
                        pattern_end => 14229})
    end,
    gose@cose:content_type(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/encrypt.gleam", 479).
?DOC(" Extract the critical header labels from the message headers.\n").
-spec critical(encrypt(encrypted())) -> {ok, list(integer())} |
    {error, gose:gose_error()}.
critical(Message) ->
    {Protected@1, Unprotected@1} = case Message of
        {encrypted_encrypt, Protected, _, Unprotected, _, _} -> {
        Protected,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"critical"/utf8>>,
                        line => 482,
                        value => _assert_fail,
                        start => 14456,
                        'end' => 14523,
                        pattern_start => 14467,
                        pattern_end => 14513})
    end,
    gose@cose:critical(lists:append(Protected@1, Unprotected@1)).

-file("src/gose/cose/encrypt.gleam", 487).
?DOC(" Return the raw protected headers.\n").
-spec protected_headers(encrypt(encrypted())) -> list(gose@cose:header()).
protected_headers(Message) ->
    Protected@1 = case Message of
        {encrypted_encrypt, Protected, _, _, _, _} -> Protected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"protected_headers"/utf8>>,
                        line => 488,
                        value => _assert_fail,
                        start => 14697,
                        'end' => 14750,
                        pattern_start => 14708,
                        pattern_end => 14740})
    end,
    Protected@1.

-file("src/gose/cose/encrypt.gleam", 493).
?DOC(" Return the raw unprotected headers.\n").
-spec unprotected_headers(encrypt(encrypted())) -> list(gose@cose:header()).
unprotected_headers(Message) ->
    Unprotected@1 = case Message of
        {encrypted_encrypt, _, _, Unprotected, _, _} -> Unprotected;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"unprotected_headers"/utf8>>,
                        line => 494,
                        value => _assert_fail,
                        start => 14887,
                        'end' => 14942,
                        pattern_start => 14898,
                        pattern_end => 14932})
    end,
    Unprotected@1.

-file("src/gose/cose/encrypt.gleam", 498).
-spec require_non_empty_recipients(
    list(pending_recipient()),
    fun(() -> {ok, QDK} | {error, gose:gose_error()})
) -> {ok, QDK} | {error, gose:gose_error()}.
require_non_empty_recipients(Recipients, Continue) ->
    gleam@bool:guard(
        gleam@list:is_empty(Recipients),
        {error, {invalid_state, <<"at least one recipient required"/utf8>>}},
        fun() -> Continue() end
    ).

-file("src/gose/cose/encrypt.gleam", 509).
-spec validate_single_recipient_constraint(
    list(pending_recipient()),
    fun(() -> {ok, QDQ} | {error, gose:gose_error()})
) -> {ok, QDQ} | {error, gose:gose_error()}.
validate_single_recipient_constraint(Recipients, Continue) ->
    Has_direct = gleam@list:any(
        Recipients,
        fun(R) -> case erlang:element(2, R) of
                direct ->
                    true;

                {ecdh_es, ecdh_es_direct} ->
                    true;

                {aes_key_wrap, _, _} ->
                    false;

                {cha_cha20_key_wrap, _} ->
                    false;

                {rsa_encryption, _} ->
                    false;

                {ecdh_es, {ecdh_es_aes_kw, _}} ->
                    false;

                {ecdh_es, {ecdh_es_cha_cha20_kw, _}} ->
                    false;

                {pbes2, _} ->
                    false
            end end
    ),
    gleam@bool:guard(
        Has_direct andalso (erlang:length(Recipients) > 1),
        {error,
            {invalid_state,
                <<"Direct and ECDH-ES Direct key agreement require exactly one recipient"/utf8>>}},
        fun() -> Continue() end
    ).

-file("src/gose/cose/encrypt.gleam", 597).
-spec append_party_headers(
    list(gose@cose:header()),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> list(gose@cose:header()).
append_party_headers(Headers, Apu, Apv) ->
    Headers@1 = case Apu of
        {some, Bytes} ->
            [{unknown, {int, -21}, {bytes, Bytes}} | Headers];

        none ->
            Headers
    end,
    case Apv of
        {some, Bytes@1} ->
            [{unknown, {int, -24}, {bytes, Bytes@1}} | Headers@1];

        none ->
            Headers@1
    end.

-file("src/gose/cose/encrypt.gleam", 626).
-spec find_unknown_bytes(list(gose@cose:header()), integer()) -> gleam@option:option(bitstring()).
find_unknown_bytes(Headers, Label) ->
    case Headers of
        [] ->
            none;

        [{unknown, {int, Found}, {bytes, B}} | _] when Found =:= Label ->
            {some, B};

        [_ | Rest] ->
            find_unknown_bytes(Rest, Label)
    end.

-file("src/gose/cose/encrypt.gleam", 618).
-spec extract_party_u(list(gose@cose:header())) -> gleam@option:option(bitstring()).
extract_party_u(Headers) ->
    find_unknown_bytes(Headers, -21).

-file("src/gose/cose/encrypt.gleam", 622).
-spec extract_party_v(list(gose@cose:header())) -> gleam@option:option(bitstring()).
extract_party_v(Headers) ->
    find_unknown_bytes(Headers, -24).

-file("src/gose/cose/encrypt.gleam", 667).
-spec ecdh_variant_to_cose_id(ecdh_es_direct_variant()) -> integer().
ecdh_variant_to_cose_id(Variant) ->
    case Variant of
        ecdh_es_hkdf256 ->
            -25;

        ecdh_es_hkdf512 ->
            -26
    end.

-file("src/gose/cose/encrypt.gleam", 674).
-spec ecdh_variant_hash_algorithm(ecdh_es_direct_variant()) -> kryptos@hash:hash_algorithm().
ecdh_variant_hash_algorithm(Variant) ->
    case Variant of
        ecdh_es_hkdf256 ->
            sha256;

        ecdh_es_hkdf512 ->
            sha512
    end.

-file("src/gose/cose/encrypt.gleam", 683).
-spec encrypt_direct_recipient() -> {ok, encrypted_recipient()} |
    {error, gose:gose_error()}.
encrypt_direct_recipient() ->
    {ok, {encrypted_recipient, [], <<>>, [{alg, -6}], <<>>}}.

-file("src/gose/cose/encrypt.gleam", 694).
-spec encrypt_aes_kw_recipient(
    gose:key(bitstring()),
    bitstring(),
    gose:aes_key_size()
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
encrypt_aes_kw_recipient(Key, Cek, Size) ->
    gleam@result:'try'(
        gose@cose:key_encryption_alg_to_int({aes_key_wrap, aes_kw, Size}),
        fun(Alg_id) ->
            gleam@result:'try'(
                gose@internal@key_encryption:wrap_aes_kw(Key, Cek, Size),
                fun(Encrypted_cek) ->
                    {ok,
                        {encrypted_recipient,
                            [],
                            <<>>,
                            [{alg, Alg_id}],
                            Encrypted_cek}}
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 774).
-spec aes_kw_cose_id(gose:aes_key_size()) -> integer().
aes_kw_cose_id(Size) ->
    case Size of
        aes128 ->
            -3;

        aes192 ->
            -4;

        aes256 ->
            -5
    end.

-file("src/gose/cose/encrypt.gleam", 782).
-spec recipient_alg(encrypted_recipient()) -> {ok, gose:key_encryption_alg()} |
    {error, gose:gose_error()}.
recipient_alg(Recipient) ->
    _pipe = gose@internal@cose_structure:extract_key_encryption_alg_from_headers(
        erlang:element(2, Recipient)
    ),
    gleam@result:lazy_or(
        _pipe,
        fun() ->
            gose@internal@cose_structure:extract_key_encryption_alg_from_headers(
                erlang:element(4, Recipient)
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 1033).
-spec rsa_hash_for_alg(gose:rsa_encryption_alg()) -> {ok,
        kryptos@hash:hash_algorithm()} |
    {error, gose:gose_error()}.
rsa_hash_for_alg(Rsa_alg) ->
    case Rsa_alg of
        rsa_oaep_sha1 ->
            {ok, sha1};

        rsa_oaep_sha256 ->
            {ok, sha256};

        rsa_pkcs1v15 ->
            {error,
                {invalid_state,
                    <<"RSA-PKCS1v15 is not supported in COSE"/utf8>>}}
    end.

-file("src/gose/cose/encrypt.gleam", 711).
-spec encrypt_rsa_oaep_recipient(
    gose:key(bitstring()),
    bitstring(),
    gose:rsa_encryption_alg()
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
encrypt_rsa_oaep_recipient(Key, Cek, Rsa_alg) ->
    gleam@result:'try'(
        gose@cose:key_encryption_alg_to_int({rsa_encryption, Rsa_alg}),
        fun(Alg_id) ->
            gleam@result:'try'(
                rsa_hash_for_alg(Rsa_alg),
                fun(Hash_alg) ->
                    gleam@result:'try'(
                        gose@internal@key_encryption:wrap_rsa_oaep(
                            Key,
                            Cek,
                            Hash_alg
                        ),
                        fun(Encrypted_cek) ->
                            {ok,
                                {encrypted_recipient,
                                    [],
                                    <<>>,
                                    [{alg, Alg_id}],
                                    Encrypted_cek}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 1044).
-spec serialize_recipient(encrypted_recipient()) -> gose@cbor:value().
serialize_recipient(Recipient) ->
    {array,
        [{bytes, erlang:element(3, Recipient)},
            {map, gose@cose:headers_to_cbor(erlang:element(4, Recipient))},
            {bytes, erlang:element(5, Recipient)}]}.

-file("src/gose/cose/encrypt.gleam", 441).
-spec to_cbor_value(encrypt(encrypted())) -> gose@cbor:value().
to_cbor_value(Message) ->
    {Protected_serialized@1, Unprotected@1, Ciphertext@1, Recipients@1} = case Message of
        {encrypted_encrypt,
            _,
            Protected_serialized,
            Unprotected,
            Ciphertext,
            Recipients} -> {
        Protected_serialized,
            Unprotected,
            Ciphertext,
            Recipients};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"to_cbor_value"/utf8>>,
                        line => 442,
                        value => _assert_fail,
                        start => 13198,
                        'end' => 13327,
                        pattern_start => 13209,
                        pattern_end => 13317})
    end,
    {array,
        [{bytes, Protected_serialized@1},
            {map, gose@cose:headers_to_cbor(Unprotected@1)},
            {bytes, Ciphertext@1},
            {array, gleam@list:map(Recipients@1, fun serialize_recipient/1)}]}.

-file("src/gose/cose/encrypt.gleam", 432).
?DOC(" Encode an encrypted message as an untagged CBOR COSE_Encrypt array.\n").
-spec serialize(encrypt(encrypted())) -> bitstring().
serialize(Message) ->
    gose@cbor:encode(to_cbor_value(Message)).

-file("src/gose/cose/encrypt.gleam", 437).
?DOC(" Encode an encrypted message as a CBOR-tagged (tag 96) COSE_Encrypt structure.\n").
-spec serialize_tagged(encrypt(encrypted())) -> bitstring().
serialize_tagged(Message) ->
    gose@cbor:encode({tag, 96, to_cbor_value(Message)}).

-file("src/gose/cose/encrypt.gleam", 1160).
-spec epk_to_cbor(gose@internal@key_encryption:ephemeral_public_key()) -> gose@cbor:value().
epk_to_cbor(Epk) ->
    case Epk of
        {ec_ephemeral_key, Curve, X, Y} ->
            Crv_id = gose@cose:ec_curve_to_cose(Curve),
            {map,
                [{{int, 1}, {int, 2}},
                    {{int, -1}, {int, Crv_id}},
                    {{int, -2}, {bytes, X}},
                    {{int, -3}, {bytes, Y}}]};

        {xdh_ephemeral_key, Curve@1, X@1} ->
            Crv_id@1 = gose@cose:xdh_curve_to_cose(Curve@1),
            {map,
                [{{int, 1}, {int, 1}},
                    {{int, -1}, {int, Crv_id@1}},
                    {{int, -2}, {bytes, X@1}}]}
    end.

-file("src/gose/cose/encrypt.gleam", 1194).
-spec find_unknown_header(list(gose@cose:header()), gose@cbor:value()) -> {ok,
        gose@cbor:value()} |
    {error, nil}.
find_unknown_header(Headers, Key) ->
    gleam@list:find_map(Headers, fun(Header) -> case Header of
                {unknown, K, V} when K =:= Key ->
                    {ok, V};

                _ ->
                    {error, nil}
            end end).

-file("src/gose/cose/encrypt.gleam", 1141).
-spec validate_no_private_epk(
    list(gose@cose:header()),
    fun(() -> {ok, QGZ} | {error, gose:gose_error()})
) -> {ok, QGZ} | {error, gose:gose_error()}.
validate_no_private_epk(Unprotected, Continue) ->
    case find_unknown_header(Unprotected, {int, -1}) of
        {ok, {map, Epk_pairs}} ->
            Has_private = gleam@list:any(
                Epk_pairs,
                fun(Pair) -> erlang:element(1, Pair) =:= {int, -4} end
            ),
            gleam@bool:guard(
                Has_private,
                {error,
                    {parse_error,
                        <<"ephemeral public key must not contain private material"/utf8>>}},
                fun() -> Continue() end
            );

        _ ->
            Continue()
    end.

-file("src/gose/cose/encrypt.gleam", 1113).
-spec parse_recipient_fields(
    bitstring(),
    list({gose@cbor:value(), gose@cbor:value()}),
    bitstring()
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
parse_recipient_fields(Protected_serialized, Unprotected_cbor, Ciphertext) ->
    gleam@result:'try'(
        gose@internal@cose_structure:decode_protected(Protected_serialized),
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
                                    validate_no_private_epk(
                                        Unprotected,
                                        fun() ->
                                            {ok,
                                                {encrypted_recipient,
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
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 1097).
-spec parse_recipient(gose@cbor:value()) -> {ok, encrypted_recipient()} |
    {error, gose:gose_error()}.
parse_recipient(Value) ->
    case Value of
        {array,
            [{bytes, Protected_serialized},
                {map, Unprotected_cbor},
                {bytes, Ciphertext}]} ->
            parse_recipient_fields(
                Protected_serialized,
                Unprotected_cbor,
                Ciphertext
            );

        {array, [{bytes, _}, {map, _}, {bytes, _}, {array, _}]} ->
            {error,
                {parse_error,
                    <<"nested COSE recipients are not supported"/utf8>>}};

        _ ->
            {error, {parse_error, <<"invalid COSE_recipient structure"/utf8>>}}
    end.

-file("src/gose/cose/encrypt.gleam", 1052).
-spec parse_cbor_value(gose@cbor:value()) -> {ok, encrypt(encrypted())} |
    {error, gose:gose_error()}.
parse_cbor_value(Value) ->
    gleam@result:'try'(
        gose@internal@cose_structure:parse_cose_array_value(Value, 96, 4),
        fun(Items) -> case Items of
                [{bytes, Protected_serialized},
                    {map, Unprotected_cbor},
                    {bytes, Ciphertext},
                    {array, Recipient_values}] ->
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
                                                        gleam@list:try_map(
                                                            Recipient_values,
                                                            fun parse_recipient/1
                                                        ),
                                                        fun(Recipients) ->
                                                            {ok,
                                                                {encrypted_encrypt,
                                                                    Protected,
                                                                    Protected_serialized,
                                                                    Unprotected,
                                                                    Ciphertext,
                                                                    Recipients}}
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
                        {parse_error, <<"invalid COSE_Encrypt structure"/utf8>>}}
            end end
    ).

-file("src/gose/cose/encrypt.gleam", 459).
?DOC(" Decode a CBOR-encoded COSE_Encrypt message, accepting both tagged and untagged forms.\n").
-spec parse(bitstring()) -> {ok, encrypt(encrypted())} |
    {error, gose:gose_error()}.
parse(Data) ->
    gleam@result:'try'(
        gose@cbor:decode(Data),
        fun(Value) -> parse_cbor_value(Value) end
    ).

-file("src/gose/cose/encrypt.gleam", 1235).
-spec lookup_int(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer(),
    binary()
) -> {ok, integer()} | {error, gose:gose_error()}.
lookup_int(Pairs, Label, Error_msg) ->
    case gleam@list:key_find(Pairs, {int, Label}) of
        {ok, {int, V}} ->
            {ok, V};

        _ ->
            {error, {parse_error, Error_msg}}
    end.

-file("src/gose/cose/encrypt.gleam", 1246).
-spec lookup_bytes(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer(),
    binary()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
lookup_bytes(Pairs, Label, Error_msg) ->
    case gleam@list:key_find(Pairs, {int, Label}) of
        {ok, {bytes, V}} ->
            {ok, V};

        _ ->
            {error, {parse_error, Error_msg}}
    end.

-file("src/gose/cose/encrypt.gleam", 1216).
-spec parse_ec_epk(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose@internal@key_encryption:ephemeral_public_key()} |
    {error, gose:gose_error()}.
parse_ec_epk(Pairs) ->
    gleam@result:'try'(
        lookup_int(Pairs, -1, <<"missing EC curve in EPK"/utf8>>),
        fun(Crv_id) ->
            gleam@result:'try'(
                gose@cose:ec_curve_from_cose(Crv_id),
                fun(Curve) ->
                    gleam@result:'try'(
                        lookup_bytes(Pairs, -2, <<"missing EC x in EPK"/utf8>>),
                        fun(X) ->
                            gleam@result:'try'(
                                lookup_bytes(
                                    Pairs,
                                    -3,
                                    <<"missing EC y in EPK"/utf8>>
                                ),
                                fun(Y) ->
                                    {ok, {ec_ephemeral_key, Curve, X, Y}}
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 1226).
-spec parse_okp_epk(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose@internal@key_encryption:ephemeral_public_key()} |
    {error, gose:gose_error()}.
parse_okp_epk(Pairs) ->
    gleam@result:'try'(
        lookup_int(Pairs, -1, <<"missing OKP curve in EPK"/utf8>>),
        fun(Crv_id) ->
            gleam@result:'try'(
                gose@cose:xdh_curve_from_cose(Crv_id),
                fun(Curve) ->
                    gleam@result:'try'(
                        lookup_bytes(Pairs, -2, <<"missing OKP x in EPK"/utf8>>),
                        fun(X) -> {ok, {xdh_ephemeral_key, Curve, X}} end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 1206).
-spec parse_epk(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose@internal@key_encryption:ephemeral_public_key()} |
    {error, gose:gose_error()}.
parse_epk(Pairs) ->
    case gleam@list:key_find(Pairs, {int, 1}) of
        {ok, {int, 2}} ->
            parse_ec_epk(Pairs);

        {ok, {int, 1}} ->
            parse_okp_epk(Pairs);

        _ ->
            {error, {parse_error, <<"unsupported EPK key type"/utf8>>}}
    end.

-file("src/gose/cose/encrypt.gleam", 1182).
-spec extract_epk(list(gose@cose:header())) -> {ok,
        gose@internal@key_encryption:ephemeral_public_key()} |
    {error, gose:gose_error()}.
extract_epk(Unprotected) ->
    case find_unknown_header(Unprotected, {int, -1}) of
        {ok, {map, Pairs}} ->
            parse_epk(Pairs);

        _ ->
            {error,
                {parse_error,
                    <<"missing ephemeral public key (label -1) in recipient"/utf8>>}}
    end.

-file("src/gose/cose/encrypt.gleam", 1290).
-spec encode_party_info(gleam@option:option(bitstring())) -> gose@cbor:value().
encode_party_info(Identity) ->
    Identity_value = case Identity of
        {some, Bytes} ->
            {bytes, Bytes};

        none ->
            null
    end,
    {array, [Identity_value, null, null]}.

-file("src/gose/cose/encrypt.gleam", 1258).
?DOC(false).
-spec derive_cose_ecdh_key(
    bitstring(),
    kryptos@hash:hash_algorithm(),
    integer(),
    integer(),
    bitstring(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, bitstring()} | {error, gose:gose_error()}.
derive_cose_ecdh_key(
    Shared_secret,
    Hash_algorithm,
    Algorithm_id,
    Key_data_length,
    Recipient_protected,
    Party_u_identity,
    Party_v_identity
) ->
    Context = gose@cbor:encode(
        {array,
            [{int, Algorithm_id},
                encode_party_info(Party_u_identity),
                encode_party_info(Party_v_identity),
                {array,
                    [{int, Key_data_length * 8}, {bytes, Recipient_protected}]}]}
    ),
    _pipe = kryptos@crypto:hkdf(
        Hash_algorithm,
        Shared_secret,
        none,
        Context,
        Key_data_length
    ),
    gleam@result:replace_error(_pipe, {crypto_error, <<"HKDF failed"/utf8>>}).

-file("src/gose/cose/encrypt.gleam", 563).
-spec encrypt_ecdh_es_direct(
    gose:key(bitstring()),
    gose:content_alg(),
    ecdh_es_direct_variant(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, {bitstring(), list(encrypted_recipient())}} |
    {error, gose:gose_error()}.
encrypt_ecdh_es_direct(Key, Content_alg, Variant, Apu, Apv) ->
    gleam@result:'try'(
        gose@internal@key_encryption:compute_ecdh_shared_secret(Key),
        fun(_use0) ->
            {Shared_secret, Epk} = _use0,
            gleam@result:'try'(
                gose@cose:content_alg_to_int(Content_alg),
                fun(Content_alg_id) ->
                    Alg_id = ecdh_variant_to_cose_id(Variant),
                    Key_len = gose:content_alg_key_size(Content_alg),
                    Protected = append_party_headers([{alg, Alg_id}], Apu, Apv),
                    Recipient_protected = gose@internal@cose_structure:serialize_protected(
                        Protected
                    ),
                    gleam@result:'try'(
                        derive_cose_ecdh_key(
                            Shared_secret,
                            ecdh_variant_hash_algorithm(Variant),
                            Content_alg_id,
                            Key_len,
                            Recipient_protected,
                            Apu,
                            Apv
                        ),
                        fun(Cek) ->
                            Recipient = {encrypted_recipient,
                                Protected,
                                Recipient_protected,
                                [{unknown, {int, -1}, epk_to_cbor(Epk)}],
                                <<>>},
                            {ok, {Cek, [Recipient]}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 733).
-spec encrypt_ecdh_es_aes_kw_recipient(
    gose:key(bitstring()),
    bitstring(),
    gose:aes_key_size(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
encrypt_ecdh_es_aes_kw_recipient(Key, Cek, Size, Apu, Apv) ->
    gleam@result:'try'(
        gose@cose:key_encryption_alg_to_int({ecdh_es, {ecdh_es_aes_kw, Size}}),
        fun(Alg_id) ->
            gleam@result:'try'(
                gose@internal@key_encryption:compute_ecdh_shared_secret(Key),
                fun(_use0) ->
                    {Shared_secret, Epk} = _use0,
                    Protected = append_party_headers([], Apu, Apv),
                    Protected_serialized = gose@internal@cose_structure:serialize_protected(
                        Protected
                    ),
                    Kw_key_len = gose:aes_key_size(Size),
                    gleam@result:'try'(
                        derive_cose_ecdh_key(
                            Shared_secret,
                            sha256,
                            aes_kw_cose_id(Size),
                            Kw_key_len,
                            Protected_serialized,
                            Apu,
                            Apv
                        ),
                        fun(Kek) ->
                            gleam@result:'try'(
                                gose@internal@content_encryption:aes_cipher(
                                    Size,
                                    Kek
                                ),
                                fun(Cipher) ->
                                    gleam@result:'try'(
                                        begin
                                            _pipe = kryptos@block:wrap(
                                                Cipher,
                                                Cek
                                            ),
                                            gleam@result:replace_error(
                                                _pipe,
                                                {crypto_error,
                                                    <<"AES Key Wrap failed"/utf8>>}
                                            )
                                        end,
                                        fun(Wrapped) ->
                                            {ok,
                                                {encrypted_recipient,
                                                    Protected,
                                                    Protected_serialized,
                                                    [{alg, Alg_id},
                                                        {unknown,
                                                            {int, -1},
                                                            epk_to_cbor(Epk)}],
                                                    Wrapped}}
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

-file("src/gose/cose/encrypt.gleam", 638).
-spec wrap_recipient(pending_recipient(), bitstring()) -> {ok,
        encrypted_recipient()} |
    {error, gose:gose_error()}.
wrap_recipient(Recipient, Cek) ->
    case erlang:element(2, Recipient) of
        {aes_key_wrap, aes_kw, Size} ->
            encrypt_aes_kw_recipient(erlang:element(3, Recipient), Cek, Size);

        {rsa_encryption, Rsa_alg} ->
            encrypt_rsa_oaep_recipient(
                erlang:element(3, Recipient),
                Cek,
                Rsa_alg
            );

        {ecdh_es, {ecdh_es_aes_kw, Size@1}} ->
            encrypt_ecdh_es_aes_kw_recipient(
                erlang:element(3, Recipient),
                Cek,
                Size@1,
                erlang:element(5, Recipient),
                erlang:element(6, Recipient)
            );

        direct ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}};

        {aes_key_wrap, aes_gcm_kw, _} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}};

        {cha_cha20_key_wrap, _} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}};

        {ecdh_es, ecdh_es_direct} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}};

        {ecdh_es, {ecdh_es_cha_cha20_kw, _}} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}};

        {pbes2, _} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}}
    end.

-file("src/gose/cose/encrypt.gleam", 534).
-spec generate_cek_and_wrap_recipients(
    gose:content_alg(),
    list(pending_recipient())
) -> {ok, {bitstring(), list(encrypted_recipient())}} |
    {error, gose:gose_error()}.
generate_cek_and_wrap_recipients(Content_alg, Recipients) ->
    case Recipients of
        [{pending_recipient, direct, Key, _, _, _}] ->
            gleam@result:'try'(
                gose@internal@key_encryption:unwrap_direct(Key, Content_alg),
                fun(Cek) ->
                    gleam@result:'try'(
                        encrypt_direct_recipient(),
                        fun(Recipient) -> {ok, {Cek, [Recipient]}} end
                    )
                end
            );

        [{pending_recipient,
                {ecdh_es, ecdh_es_direct},
                Key@1,
                {some, Variant},
                Apu,
                Apv}] ->
            encrypt_ecdh_es_direct(Key@1, Content_alg, Variant, Apu, Apv);

        _ ->
            Cek@1 = gose@internal@content_encryption:generate_cek(Content_alg),
            gleam@result:'try'(
                gleam@list:try_map(
                    Recipients,
                    fun(_capture) -> wrap_recipient(_capture, Cek@1) end
                ),
                fun(Encrypted_recipients) ->
                    {ok, {Cek@1, Encrypted_recipients}}
                end
            )
    end.

-file("src/gose/cose/encrypt.gleam", 271).
?DOC(
    " Encrypt the plaintext for all added recipients.\n"
    "\n"
    " Reads `aad` from the builder state set via `with_aad`.\n"
).
-spec encrypt(encrypt(unencrypted()), bitstring()) -> {ok, encrypt(encrypted())} |
    {error, gose:gose_error()}.
encrypt(Message, Plaintext) ->
    {Content_alg@1, Protected@1, Unprotected@1, Recipients@1, Aad@1} = case Message of
        {unencrypted_encrypt,
            Content_alg,
            Protected,
            Unprotected,
            Recipients,
            Aad} -> {Content_alg, Protected, Unprotected, Recipients, Aad};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"encrypt"/utf8>>,
                        line => 275,
                        value => _assert_fail,
                        start => 8429,
                        'end' => 8552,
                        pattern_start => 8440,
                        pattern_end => 8542})
    end,
    require_non_empty_recipients(
        Recipients@1,
        fun() ->
            validate_single_recipient_constraint(
                Recipients@1,
                fun() ->
                    Protected_serialized = gose@internal@cose_structure:serialize_protected(
                        Protected@1
                    ),
                    gleam@result:'try'(
                        generate_cek_and_wrap_recipients(
                            Content_alg@1,
                            Recipients@1
                        ),
                        fun(_use0) ->
                            {Cek, Encrypted_recipients} = _use0,
                            Iv = gose@internal@content_encryption:generate_iv(
                                Content_alg@1
                            ),
                            Enc_structure = gose@internal@cose_structure:build_enc_structure(
                                <<"Encrypt"/utf8>>,
                                Protected_serialized,
                                Aad@1
                            ),
                            gleam@result:'try'(
                                gose@internal@content_encryption:encrypt_content(
                                    Content_alg@1,
                                    Cek,
                                    Iv,
                                    Enc_structure,
                                    Plaintext
                                ),
                                fun(_use0@1) ->
                                    {Ciphertext, Tag} = _use0@1,
                                    Ciphertext_with_tag = gleam_stdlib:bit_array_concat(
                                        [Ciphertext, Tag]
                                    ),
                                    Unprotected@2 = [{iv, Iv} | Unprotected@1],
                                    {ok,
                                        {encrypted_encrypt,
                                            Protected@1,
                                            Protected_serialized,
                                            Unprotected@2,
                                            Ciphertext_with_tag,
                                            Encrypted_recipients}}
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 986).
-spec unwrap_ecdh_es_direct(
    encrypted_recipient(),
    gose:key(bitstring()),
    gose:content_alg(),
    ecdh_es_direct_variant()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_ecdh_es_direct(Recipient, Key, Content_alg, Variant) ->
    gleam@result:'try'(
        extract_epk(erlang:element(4, Recipient)),
        fun(Epk) ->
            gleam@result:'try'(
                gose@internal@key_encryption:compute_ecdh_shared_secret_with_epk(
                    Key,
                    Epk
                ),
                fun(Shared_secret) ->
                    gleam@result:'try'(
                        gose@cose:content_alg_to_int(Content_alg),
                        fun(Content_alg_id) ->
                            Key_len = gose:content_alg_key_size(Content_alg),
                            derive_cose_ecdh_key(
                                Shared_secret,
                                ecdh_variant_hash_algorithm(Variant),
                                Content_alg_id,
                                Key_len,
                                erlang:element(3, Recipient),
                                extract_party_u(erlang:element(2, Recipient)),
                                extract_party_v(erlang:element(2, Recipient))
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 1009).
-spec unwrap_ecdh_es_aes_kw(
    encrypted_recipient(),
    gose:key(bitstring()),
    gose:aes_key_size()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_ecdh_es_aes_kw(Recipient, Key, Size) ->
    gleam@result:'try'(
        extract_epk(erlang:element(4, Recipient)),
        fun(Epk) ->
            gleam@result:'try'(
                gose@internal@key_encryption:compute_ecdh_shared_secret_with_epk(
                    Key,
                    Epk
                ),
                fun(Shared_secret) ->
                    Kw_key_len = gose:aes_key_size(Size),
                    gleam@result:'try'(
                        derive_cose_ecdh_key(
                            Shared_secret,
                            sha256,
                            aes_kw_cose_id(Size),
                            Kw_key_len,
                            erlang:element(3, Recipient),
                            extract_party_u(erlang:element(2, Recipient)),
                            extract_party_v(erlang:element(2, Recipient))
                        ),
                        fun(Kek) ->
                            gleam@result:'try'(
                                gose@internal@content_encryption:aes_cipher(
                                    Size,
                                    Kek
                                ),
                                fun(Cipher) ->
                                    _pipe = kryptos@block:unwrap(
                                        Cipher,
                                        erlang:element(5, Recipient)
                                    ),
                                    gleam@result:replace_error(
                                        _pipe,
                                        {crypto_error,
                                            <<"AES Key Unwrap failed"/utf8>>}
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 946).
-spec unwrap_cek(
    encrypted_recipient(),
    gose:key(bitstring()),
    gose:key_encryption_alg(),
    gose:content_alg(),
    gleam@option:option(ecdh_es_direct_variant())
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_cek(Recipient, Key, Key_alg, Content_alg, Ecdh_es_variant) ->
    case Key_alg of
        direct ->
            gose@internal@key_encryption:unwrap_direct(Key, Content_alg);

        {aes_key_wrap, aes_kw, Size} ->
            gose@internal@key_encryption:unwrap_aes_kw(
                Key,
                erlang:element(5, Recipient),
                Size
            );

        {rsa_encryption, Rsa_alg} ->
            gleam@result:'try'(
                rsa_hash_for_alg(Rsa_alg),
                fun(Hash_alg) ->
                    gose@internal@key_encryption:unwrap_rsa_oaep(
                        Key,
                        erlang:element(5, Recipient),
                        Hash_alg
                    )
                end
            );

        {ecdh_es, ecdh_es_direct} ->
            Variant@1 = case Ecdh_es_variant of
                {some, Variant} -> Variant;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/cose/encrypt"/utf8>>,
                                function => <<"unwrap_cek"/utf8>>,
                                line => 971,
                                value => _assert_fail,
                                start => 27501,
                                'end' => 27550,
                                pattern_start => 27512,
                                pattern_end => 27532})
            end,
            unwrap_ecdh_es_direct(Recipient, Key, Content_alg, Variant@1);

        {ecdh_es, {ecdh_es_aes_kw, Size@1}} ->
            unwrap_ecdh_es_aes_kw(Recipient, Key, Size@1);

        {aes_key_wrap, aes_gcm_kw, _} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}};

        {cha_cha20_key_wrap, _} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}};

        {ecdh_es, {ecdh_es_cha_cha20_kw, _}} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}};

        {pbes2, _} ->
            {error,
                {invalid_state,
                    <<"unsupported key encryption algorithm for COSE_Encrypt"/utf8>>}}
    end.

-file("src/gose/cose/encrypt.gleam", 918).
-spec unwrap_and_decrypt(
    encrypted_recipient(),
    gose:key(bitstring()),
    gose:key_encryption_alg(),
    gose:content_alg(),
    gleam@option:option(ecdh_es_direct_variant()),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_and_decrypt(
    Recipient,
    Key,
    Key_alg,
    Content_alg,
    Ecdh_es_variant,
    Iv,
    Enc_structure,
    Ciphertext,
    Tag
) ->
    gleam@result:'try'(
        unwrap_cek(Recipient, Key, Key_alg, Content_alg, Ecdh_es_variant),
        fun(Cek) ->
            gose@internal@content_encryption:decrypt_content(
                Content_alg,
                Cek,
                Iv,
                Enc_structure,
                Ciphertext,
                Tag
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 870).
-spec try_keys(
    list(gose:key(bitstring())),
    encrypted_recipient(),
    gose:key_encryption_alg(),
    gose:content_alg(),
    gleam@option:option(ecdh_es_direct_variant()),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    {ok, bitstring()} | {error, gose:gose_error()}
) -> {ok, bitstring()} | {error, gose:gose_error()}.
try_keys(
    Keys,
    Recipient,
    Key_alg,
    Content_alg,
    Ecdh_es_variant,
    Iv,
    Enc_structure,
    Ciphertext,
    Tag,
    Last_error
) ->
    case Keys of
        [] ->
            Last_error;

        [Key | Rest] ->
            Result = unwrap_and_decrypt(
                Recipient,
                Key,
                Key_alg,
                Content_alg,
                Ecdh_es_variant,
                Iv,
                Enc_structure,
                Ciphertext,
                Tag
            ),
            case Result of
                {ok, Plaintext} ->
                    {ok, Plaintext};

                {error, {crypto_error, _} = E} ->
                    try_keys(
                        Rest,
                        Recipient,
                        Key_alg,
                        Content_alg,
                        Ecdh_es_variant,
                        Iv,
                        Enc_structure,
                        Ciphertext,
                        Tag,
                        {error, E}
                    );

                {error, E@1} ->
                    {error, E@1}
            end
    end.

-file("src/gose/cose/encrypt.gleam", 841).
-spec try_keys_for_recipient(
    encrypted_recipient(),
    list(gose:key(bitstring())),
    gose:key_encryption_alg(),
    gose:content_alg(),
    gleam@option:option(ecdh_es_direct_variant()),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
try_keys_for_recipient(
    Recipient,
    Keys,
    Key_alg,
    Content_alg,
    Ecdh_es_variant,
    Iv,
    Enc_structure,
    Ciphertext,
    Tag
) ->
    gleam@result:'try'(
        gose@internal@cose_structure:validate_crit(
            erlang:element(2, Recipient),
            erlang:element(4, Recipient)
        ),
        fun(_) ->
            try_keys(
                Keys,
                Recipient,
                Key_alg,
                Content_alg,
                Ecdh_es_variant,
                Iv,
                Enc_structure,
                Ciphertext,
                Tag,
                {error, {crypto_error, <<"no key could decrypt"/utf8>>}}
            )
        end
    ).

-file("src/gose/cose/encrypt.gleam", 793).
-spec try_decrypt_recipients(
    list(encrypted_recipient()),
    list(gose:key(bitstring())),
    gose:key_encryption_alg(),
    gose:content_alg(),
    gleam@option:option(ecdh_es_direct_variant()),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    {ok, bitstring()} | {error, gose:gose_error()}
) -> {ok, bitstring()} | {error, gose:gose_error()}.
try_decrypt_recipients(
    Recipients,
    Keys,
    Key_alg,
    Content_alg,
    Ecdh_es_variant,
    Iv,
    Enc_structure,
    Ciphertext,
    Tag,
    Last_error
) ->
    case Recipients of
        [] ->
            Last_error;

        [Recipient | Rest] ->
            Result = try_keys_for_recipient(
                Recipient,
                Keys,
                Key_alg,
                Content_alg,
                Ecdh_es_variant,
                Iv,
                Enc_structure,
                Ciphertext,
                Tag
            ),
            case Result of
                {ok, Plaintext} ->
                    {ok, Plaintext};

                {error, {crypto_error, _} = E} ->
                    try_decrypt_recipients(
                        Rest,
                        Keys,
                        Key_alg,
                        Content_alg,
                        Ecdh_es_variant,
                        Iv,
                        Enc_structure,
                        Ciphertext,
                        Tag,
                        {error, E}
                    );

                {error, E@1} ->
                    {error, E@1}
            end
    end.

-file("src/gose/cose/encrypt.gleam", 373).
?DOC(" Decrypt with externally-supplied AAD.\n").
-spec decrypt_with_aad(decryptor(), encrypt(encrypted()), bitstring()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
decrypt_with_aad(Decryptor, Message, Aad) ->
    {decryptor, Expected_key_alg, Expected_content_alg, Keys, Ecdh_es_variant} = Decryptor,
    {
    Protected@1,
        Protected_serialized@1,
        Unprotected@1,
        Ciphertext_with_tag@1,
        Recipients@1} = case Message of
        {encrypted_encrypt,
            Protected,
            Protected_serialized,
            Unprotected,
            Ciphertext_with_tag,
            Recipients} -> {
        Protected,
            Protected_serialized,
            Unprotected,
            Ciphertext_with_tag,
            Recipients};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose/encrypt"/utf8>>,
                        function => <<"decrypt_with_aad"/utf8>>,
                        line => 384,
                        value => _assert_fail,
                        start => 11567,
                        'end' => 11724,
                        pattern_start => 11578,
                        pattern_end => 11714})
    end,
    gleam@result:'try'(
        gose@internal@cose_structure:extract_content_alg_from_serialized(
            Protected_serialized@1
        ),
        fun(Actual_content_alg) ->
            gleam@result:'try'(
                gose@internal@key_helpers:require_matching_content_algorithm(
                    Expected_content_alg,
                    Actual_content_alg
                ),
                fun(_) ->
                    gleam@result:'try'(
                        gose@internal@cose_structure:validate_crit(
                            Protected@1,
                            Unprotected@1
                        ),
                        fun(_) ->
                            Matching_recipients = gleam@list:filter(
                                Recipients@1,
                                fun(R) ->
                                    recipient_alg(R) =:= {ok, Expected_key_alg}
                                end
                            ),
                            gleam@result:'try'(
                                gose@cose:iv(Unprotected@1),
                                fun(Iv) ->
                                    gleam@result:'try'(
                                        gose@internal@cose_structure:split_ciphertext_tag(
                                            Ciphertext_with_tag@1,
                                            gose@internal@content_encryption:tag_size(
                                                Actual_content_alg
                                            )
                                        ),
                                        fun(_use0) ->
                                            {Ciphertext, Tag} = _use0,
                                            Enc_structure = gose@internal@cose_structure:build_enc_structure(
                                                <<"Encrypt"/utf8>>,
                                                Protected_serialized@1,
                                                Aad
                                            ),
                                            try_decrypt_recipients(
                                                Matching_recipients,
                                                Keys,
                                                Expected_key_alg,
                                                Actual_content_alg,
                                                Ecdh_es_variant,
                                                Iv,
                                                Enc_structure,
                                                Ciphertext,
                                                Tag,
                                                {error,
                                                    {crypto_error,
                                                        <<"no matching recipient found"/utf8>>}}
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

-file("src/gose/cose/encrypt.gleam", 365).
?DOC(" Decrypt a COSE_Encrypt message.\n").
-spec decrypt(decryptor(), encrypt(encrypted())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
decrypt(Decryptor, Message) ->
    decrypt_with_aad(Decryptor, Message, <<>>).
