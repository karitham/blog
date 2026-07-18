-module(gose@jose@jwe_multi).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/jwe_multi.gleam").
-export([new/1, decryptor/3, add_recipient/3, encrypt/2, serialize_json/1, parse_json/1, decrypt/2]).
-export_type([pending_recipient/0, encrypted_recipient/0, multi_jwe/1, unencrypted/0, encrypted/0, decryptor/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " JWE JSON Serialization for multi-recipient encryption and decryption\n"
    " ([RFC 7516 Section 7.2.1](https://www.rfc-editor.org/rfc/rfc7516.html#section-7.2.1)).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gleam/json\n"
    " import gose\n"
    " import gose/jose/jwe_multi\n"
    "\n"
    " let k1 = gose.generate_aes_kw_key(gose.Aes256)\n"
    " let k2 = gose.generate_aes_kw_key(gose.Aes128)\n"
    " let plaintext = <<\"hello\":utf8>>\n"
    "\n"
    " let message = jwe_multi.new(gose.AesGcm(gose.Aes256))\n"
    " let assert Ok(message) =\n"
    "   jwe_multi.add_recipient(\n"
    "     message,\n"
    "     gose.AesKeyWrap(gose.AesKw, gose.Aes256),\n"
    "     key: k1,\n"
    "   )\n"
    " let assert Ok(message) =\n"
    "   jwe_multi.add_recipient(\n"
    "     message,\n"
    "     gose.AesKeyWrap(gose.AesKw, gose.Aes128),\n"
    "     key: k2,\n"
    "   )\n"
    " let assert Ok(encrypted) = jwe_multi.encrypt(message, plaintext:)\n"
    "\n"
    " let json_str = jwe_multi.serialize_json(encrypted) |> json.to_string\n"
    " let assert Ok(parsed) = jwe_multi.parse_json(json_str)\n"
    " let assert Ok(dec) =\n"
    "   jwe_multi.decryptor(\n"
    "     gose.AesKeyWrap(gose.AesKw, gose.Aes256),\n"
    "     gose.AesGcm(gose.Aes256),\n"
    "     keys: [k1],\n"
    "   )\n"
    " let assert Ok(plaintext) = jwe_multi.decrypt(dec, parsed)\n"
    " ```\n"
    "\n"
    " ## Rejected Algorithms\n"
    "\n"
    " `Direct` and `EcdhEs(EcdhEsDirect)` are rejected because they derive\n"
    " the CEK directly rather than wrapping it, making multi-recipient\n"
    " impossible. `Pbes2` is also excluded (requires a password, not a key).\n"
    "\n"
    " ## Algorithm Pinning\n"
    "\n"
    " Each decryptor is pinned to expected key encryption and content encryption\n"
    " algorithms. Mismatches are rejected.\n"
).

-type pending_recipient() :: {pending_recipient,
        gose:key_encryption_alg(),
        gose:key(binary())}.

-type encrypted_recipient() :: {simple_recipient, binary(), bitstring()} |
    {ecdh_es_recipient,
        binary(),
        bitstring(),
        gose@internal@key_encryption:ephemeral_public_key(),
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring())} |
    {kw_with_iv_tag_recipient, binary(), bitstring(), bitstring(), bitstring()} |
    {ecdh_es_kw_with_iv_tag_recipient,
        binary(),
        bitstring(),
        gose@internal@key_encryption:ephemeral_public_key(),
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring()),
        bitstring(),
        bitstring()}.

-opaque multi_jwe(AAQE) :: {unencrypted_multi_jwe,
        gose:content_alg(),
        list(pending_recipient())} |
    {encrypted_multi_jwe,
        gose:content_alg(),
        binary(),
        list(encrypted_recipient()),
        bitstring(),
        bitstring(),
        bitstring()} |
    {gleam_phantom, AAQE}.

-type unencrypted() :: any().

-type encrypted() :: any().

-opaque decryptor() :: {decryptor,
        gose:key_encryption_alg(),
        gose:content_alg(),
        list(gose:key(binary()))}.

-file("src/gose/jose/jwe_multi.gleam", 127).
?DOC(" Create a new multi-recipient JWE with the given content encryption algorithm.\n").
-spec new(gose:content_alg()) -> multi_jwe(unencrypted()).
new(Enc) ->
    {unencrypted_multi_jwe, Enc, []}.

-file("src/gose/jose/jwe_multi.gleam", 255).
?DOC(" Build a decryptor pinned to expected algorithms and keys.\n").
-spec decryptor(
    gose:key_encryption_alg(),
    gose:content_alg(),
    list(gose:key(binary()))
) -> {ok, decryptor()} | {error, gose:gose_error()}.
decryptor(Key_alg, Content_alg, Keys) ->
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
                fun(_) -> {ok, {decryptor, Key_alg, Content_alg, Keys}} end
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 306).
-spec reject_direct_algorithms(
    gose:key_encryption_alg(),
    fun(() -> {ok, AARA} | {error, gose:gose_error()})
) -> {ok, AARA} | {error, gose:gose_error()}.
reject_direct_algorithms(Alg, Continue) ->
    Is_direct = case Alg of
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
    end,
    gleam@bool:guard(
        Is_direct,
        {error,
            {invalid_state,
                <<"Direct key agreement cannot be used with multi-recipient JWE"/utf8>>}},
        fun() -> Continue() end
    ).

-file("src/gose/jose/jwe_multi.gleam", 328).
-spec reject_pbes2_algorithms(
    gose:key_encryption_alg(),
    fun(() -> {ok, AARF} | {error, gose:gose_error()})
) -> {ok, AARF} | {error, gose:gose_error()}.
reject_pbes2_algorithms(Alg, Continue) ->
    Is_pbes2 = case Alg of
        {pbes2, _} ->
            true;

        direct ->
            false;

        {aes_key_wrap, _, _} ->
            false;

        {cha_cha20_key_wrap, _} ->
            false;

        {rsa_encryption, _} ->
            false;

        {ecdh_es, _} ->
            false
    end,
    gleam@bool:guard(
        Is_pbes2,
        {error,
            {invalid_state,
                <<"PBES2 algorithms require a password; use the single-recipient JWE API"/utf8>>}},
        fun() -> Continue() end
    ).

-file("src/gose/jose/jwe_multi.gleam", 132).
?DOC(" Add a recipient with the given key encryption algorithm and key.\n").
-spec add_recipient(
    multi_jwe(unencrypted()),
    gose:key_encryption_alg(),
    gose:key(binary())
) -> {ok, multi_jwe(unencrypted())} | {error, gose:gose_error()}.
add_recipient(Message, Alg, Key) ->
    {Enc@1, Recipients@1} = case Message of
        {unencrypted_multi_jwe, Enc, Recipients} -> {Enc, Recipients};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe_multi"/utf8>>,
                        function => <<"add_recipient"/utf8>>,
                        line => 137,
                        value => _assert_fail,
                        start => 3865,
                        'end' => 3924,
                        pattern_start => 3876,
                        pattern_end => 3914})
    end,
    reject_direct_algorithms(
        Alg,
        fun() ->
            reject_pbes2_algorithms(
                Alg,
                fun() ->
                    gleam@result:'try'(
                        gose@internal@key_helpers:validate_key_for_jwe_encryption(
                            Alg,
                            Key
                        ),
                        fun(_) ->
                            Recipient = {pending_recipient, Alg, Key},
                            {ok,
                                {unencrypted_multi_jwe,
                                    Enc@1,
                                    [Recipient | Recipients@1]}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 349).
-spec enc_header_json(gose:content_alg()) -> bitstring().
enc_header_json(Enc) ->
    _pipe = gleam@json:object(
        [{<<"enc"/utf8>>,
                gleam@json:string(gose@jose:content_alg_to_string(Enc))}]
    ),
    _pipe@1 = gleam@json:to_string(_pipe),
    gleam_stdlib:identity(_pipe@1).

-file("src/gose/jose/jwe_multi.gleam", 380).
-spec wrap_ecdh_es_aes_kw(
    binary(),
    gose:key(binary()),
    bitstring(),
    gose:aes_key_size()
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
wrap_ecdh_es_aes_kw(Alg_str, Key, Cek, Size) ->
    gleam@result:'try'(
        gose@internal@key_encryption:wrap_ecdh_es_kw(
            Key,
            Cek,
            Size,
            Alg_str,
            none,
            none
        ),
        fun(_use0) ->
            {Wrapped, Epk} = _use0,
            {ok, {ecdh_es_recipient, Alg_str, Wrapped, Epk, none, none}}
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 403).
-spec wrap_ecdh_es_chacha20_kw(
    binary(),
    gose:key(binary()),
    bitstring(),
    gose:cha_cha20_kw()
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
wrap_ecdh_es_chacha20_kw(Alg_str, Key, Cek, Variant) ->
    gleam@result:'try'(
        gose@internal@key_encryption:wrap_ecdh_es_chacha20_kw(
            Key,
            Cek,
            Variant,
            Alg_str,
            none,
            none
        ),
        fun(_use0) ->
            {Encrypted_cek, Epk, Kw_iv, Kw_tag} = _use0,
            {ok,
                {ecdh_es_kw_with_iv_tag_recipient,
                    Alg_str,
                    Encrypted_cek,
                    Epk,
                    none,
                    none,
                    Kw_iv,
                    Kw_tag}}
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 430).
-spec wrap_aes_gcm_kw(
    binary(),
    gose:key(binary()),
    bitstring(),
    gose:aes_key_size()
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
wrap_aes_gcm_kw(Alg_str, Key, Cek, Size) ->
    gleam@result:'try'(
        gose@internal@key_encryption:get_octet_key(Key, gose:aes_key_size(Size)),
        fun(Kek) ->
            Kw_iv = kryptos_ffi:random_bytes(12),
            gleam@result:'try'(
                gose@internal@key_encryption:wrap_aes_gcm(Kek, Cek, Kw_iv, Size),
                fun(_use0) ->
                    {Encrypted_cek, Kw_tag} = _use0,
                    {ok,
                        {kw_with_iv_tag_recipient,
                            Alg_str,
                            Encrypted_cek,
                            Kw_iv,
                            Kw_tag}}
                end
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 455).
-spec wrap_chacha20_kw(
    binary(),
    gose:key(binary()),
    bitstring(),
    gose:cha_cha20_kw()
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
wrap_chacha20_kw(Alg_str, Key, Cek, Variant) ->
    gleam@result:'try'(
        gose@internal@key_encryption:get_octet_key(Key, 32),
        fun(Kek) ->
            Nonce_size = gose:chacha20_kw_nonce_size(Variant),
            Kw_iv = kryptos_ffi:random_bytes(Nonce_size),
            gleam@result:'try'(
                gose@internal@key_encryption:wrap_chacha20_by_variant(
                    Kek,
                    Cek,
                    Kw_iv,
                    Variant
                ),
                fun(_use0) ->
                    {Encrypted_cek, Kw_tag} = _use0,
                    {ok,
                        {kw_with_iv_tag_recipient,
                            Alg_str,
                            Encrypted_cek,
                            Kw_iv,
                            Kw_tag}}
                end
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 496).
-spec wrap_rsa(gose:rsa_encryption_alg(), gose:key(binary()), bitstring()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
wrap_rsa(Alg, Key, Cek) ->
    case Alg of
        rsa_pkcs1v15 ->
            gose@internal@key_encryption:wrap_rsa_pkcs1v15(Key, Cek);

        rsa_oaep_sha1 ->
            gose@internal@key_encryption:wrap_rsa_oaep(Key, Cek, sha1);

        rsa_oaep_sha256 ->
            gose@internal@key_encryption:wrap_rsa_oaep(Key, Cek, sha256)
    end.

-file("src/gose/jose/jwe_multi.gleam", 475).
-spec wrap_cek(gose:key_encryption_alg(), gose:key(binary()), bitstring()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
wrap_cek(Alg, Key, Cek) ->
    case Alg of
        {aes_key_wrap, aes_kw, Size} ->
            gose@internal@key_encryption:wrap_aes_kw(Key, Cek, Size);

        {rsa_encryption, Rsa_alg} ->
            wrap_rsa(Rsa_alg, Key, Cek);

        {aes_key_wrap, aes_gcm_kw, _} ->
            {error,
                {invalid_state,
                    <<"unsupported algorithm for multi-recipient JWE: "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}};

        {cha_cha20_key_wrap, _} ->
            {error,
                {invalid_state,
                    <<"unsupported algorithm for multi-recipient JWE: "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}};

        {ecdh_es, _} ->
            {error,
                {invalid_state,
                    <<"unsupported algorithm for multi-recipient JWE: "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}};

        direct ->
            {error,
                {invalid_state,
                    <<"unsupported algorithm for multi-recipient JWE: "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}};

        {pbes2, _} ->
            {error,
                {invalid_state,
                    <<"unsupported algorithm for multi-recipient JWE: "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}}
    end.

-file("src/gose/jose/jwe_multi.gleam", 355).
-spec wrap_cek_for_recipient(pending_recipient(), bitstring()) -> {ok,
        encrypted_recipient()} |
    {error, gose:gose_error()}.
wrap_cek_for_recipient(Recipient, Cek) ->
    Alg_str = gose@jose:key_encryption_alg_to_string(
        erlang:element(2, Recipient)
    ),
    case erlang:element(2, Recipient) of
        {ecdh_es, {ecdh_es_aes_kw, Size}} ->
            wrap_ecdh_es_aes_kw(
                Alg_str,
                erlang:element(3, Recipient),
                Cek,
                Size
            );

        {ecdh_es, {ecdh_es_cha_cha20_kw, Variant}} ->
            wrap_ecdh_es_chacha20_kw(
                Alg_str,
                erlang:element(3, Recipient),
                Cek,
                Variant
            );

        {aes_key_wrap, aes_gcm_kw, Size@1} ->
            wrap_aes_gcm_kw(Alg_str, erlang:element(3, Recipient), Cek, Size@1);

        {cha_cha20_key_wrap, Variant@1} ->
            wrap_chacha20_kw(
                Alg_str,
                erlang:element(3, Recipient),
                Cek,
                Variant@1
            );

        _ ->
            gleam@result:'try'(
                wrap_cek(
                    erlang:element(2, Recipient),
                    erlang:element(3, Recipient),
                    Cek
                ),
                fun(Encrypted_key) ->
                    {ok, {simple_recipient, Alg_str, Encrypted_key}}
                end
            )
    end.

-file("src/gose/jose/jwe_multi.gleam", 146).
?DOC(" Encrypt the plaintext for all recipients.\n").
-spec encrypt(multi_jwe(unencrypted()), bitstring()) -> {ok,
        multi_jwe(encrypted())} |
    {error, gose:gose_error()}.
encrypt(Message, Plaintext) ->
    {Enc@1, Recipients@1} = case Message of
        {unencrypted_multi_jwe, Enc, Recipients} -> {Enc, Recipients};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe_multi"/utf8>>,
                        function => <<"encrypt"/utf8>>,
                        line => 150,
                        value => _assert_fail,
                        start => 4382,
                        'end' => 4441,
                        pattern_start => 4393,
                        pattern_end => 4431})
    end,
    gleam@bool:guard(
        gleam@list:is_empty(Recipients@1),
        {error, {invalid_state, <<"at least one recipient required"/utf8>>}},
        fun() ->
            Recipients@2 = lists:reverse(Recipients@1),
            Cek = gose@internal@content_encryption:generate_cek(Enc@1),
            gleam@result:'try'(
                gleam@list:try_map(
                    Recipients@2,
                    fun(_capture) -> wrap_cek_for_recipient(_capture, Cek) end
                ),
                fun(Encrypted_recipients) ->
                    Protected_json = enc_header_json(Enc@1),
                    Protected_b64 = gose@internal@utils:encode_base64_url(
                        Protected_json
                    ),
                    Iv = gose@internal@content_encryption:generate_iv(Enc@1),
                    Aead_aad = gose@internal@content_encryption:build_jwe_aad(
                        Protected_b64,
                        none
                    ),
                    gleam@result:'try'(
                        gose@internal@content_encryption:encrypt_content(
                            Enc@1,
                            Cek,
                            Iv,
                            Aead_aad,
                            Plaintext
                        ),
                        fun(_use0) ->
                            {Ciphertext, Tag} = _use0,
                            {ok,
                                {encrypted_multi_jwe,
                                    Enc@1,
                                    Protected_b64,
                                    Encrypted_recipients,
                                    Iv,
                                    Ciphertext,
                                    Tag}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 556).
-spec unwrap_aes_gcm_kw(
    gose:key(binary()),
    encrypted_recipient(),
    gose:aes_key_size()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_aes_gcm_kw(Key, Recipient, Size) ->
    {Encrypted_key@1, Kw_iv@1, Kw_tag@1} = case Recipient of
        {kw_with_iv_tag_recipient, _, Encrypted_key, Kw_iv, Kw_tag} -> {
        Encrypted_key,
            Kw_iv,
            Kw_tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe_multi"/utf8>>,
                        function => <<"unwrap_aes_gcm_kw"/utf8>>,
                        line => 561,
                        value => _assert_fail,
                        start => 15651,
                        'end' => 15735,
                        pattern_start => 15662,
                        pattern_end => 15719})
    end,
    gleam@result:'try'(
        gose@internal@key_encryption:get_octet_key(Key, gose:aes_key_size(Size)),
        fun(Kek) ->
            gose@internal@key_encryption:unwrap_aes_gcm(
                Kek,
                Encrypted_key@1,
                Kw_iv@1,
                Kw_tag@1,
                Size
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 576).
-spec unwrap_chacha20_kw(
    gose:key(binary()),
    encrypted_recipient(),
    gose:cha_cha20_kw()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_chacha20_kw(Key, Recipient, Variant) ->
    {Encrypted_key@1, Kw_iv@1, Kw_tag@1} = case Recipient of
        {kw_with_iv_tag_recipient, _, Encrypted_key, Kw_iv, Kw_tag} -> {
        Encrypted_key,
            Kw_iv,
            Kw_tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe_multi"/utf8>>,
                        function => <<"unwrap_chacha20_kw"/utf8>>,
                        line => 581,
                        value => _assert_fail,
                        start => 16110,
                        'end' => 16194,
                        pattern_start => 16121,
                        pattern_end => 16178})
    end,
    gleam@result:'try'(
        gose@internal@key_encryption:get_octet_key(Key, 32),
        fun(Kek) ->
            gose@internal@key_encryption:unwrap_chacha20_by_variant(
                Kek,
                Encrypted_key@1,
                Kw_iv@1,
                Kw_tag@1,
                Variant
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 593).
-spec unwrap_ecdh_es_aes_kw(
    gose:key(binary()),
    encrypted_recipient(),
    gose:aes_key_size()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_ecdh_es_aes_kw(Key, Recipient, Size) ->
    {Encrypted_key@1, Epk@1, Apu@1, Apv@1} = case Recipient of
        {ecdh_es_recipient, _, Encrypted_key, Epk, Apu, Apv} -> {
        Encrypted_key,
            Epk,
            Apu,
            Apv};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe_multi"/utf8>>,
                        function => <<"unwrap_ecdh_es_aes_kw"/utf8>>,
                        line => 598,
                        value => _assert_fail,
                        start => 16553,
                        'end' => 16629,
                        pattern_start => 16564,
                        pattern_end => 16617})
    end,
    Alg_id = gose@jose:key_encryption_alg_to_string(
        {ecdh_es, {ecdh_es_aes_kw, Size}}
    ),
    gose@internal@key_encryption:unwrap_ecdh_es_kw(
        Key,
        Encrypted_key@1,
        Size,
        Alg_id,
        Epk@1,
        Apu@1,
        Apv@1
    ).

-file("src/gose/jose/jwe_multi.gleam", 612).
-spec unwrap_ecdh_es_chacha20_kw(
    gose:key(binary()),
    encrypted_recipient(),
    gose:cha_cha20_kw()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_ecdh_es_chacha20_kw(Key, Recipient, Variant) ->
    {Encrypted_key@1, Epk@1, Apu@1, Apv@1, Kw_iv@1, Kw_tag@1} = case Recipient of
        {ecdh_es_kw_with_iv_tag_recipient,
            _,
            Encrypted_key,
            Epk,
            Apu,
            Apv,
            Kw_iv,
            Kw_tag} -> {Encrypted_key, Epk, Apu, Apv, Kw_iv, Kw_tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe_multi"/utf8>>,
                        function => <<"unwrap_ecdh_es_chacha20_kw"/utf8>>,
                        line => 617,
                        value => _assert_fail,
                        start => 17005,
                        'end' => 17142,
                        pattern_start => 17016,
                        pattern_end => 17130})
    end,
    Alg_id = gose@jose:key_encryption_alg_to_string(
        {ecdh_es, {ecdh_es_cha_cha20_kw, Variant}}
    ),
    gose@internal@key_encryption:unwrap_ecdh_es_chacha20_kw(
        Key,
        Encrypted_key@1,
        Variant,
        Alg_id,
        Epk@1,
        Apu@1,
        Apv@1,
        Kw_iv@1,
        Kw_tag@1
    ).

-file("src/gose/jose/jwe_multi.gleam", 510).
-spec unwrap_cek(
    gose:key_encryption_alg(),
    gose:key(binary()),
    encrypted_recipient(),
    gose:content_alg()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_cek(Alg, Key, Recipient, Enc) ->
    case Alg of
        {aes_key_wrap, aes_kw, Size} ->
            gose@internal@key_encryption:unwrap_aes_kw(
                Key,
                erlang:element(3, Recipient),
                Size
            );

        {aes_key_wrap, aes_gcm_kw, Size@1} ->
            unwrap_aes_gcm_kw(Key, Recipient, Size@1);

        {cha_cha20_key_wrap, Variant} ->
            unwrap_chacha20_kw(Key, Recipient, Variant);

        {rsa_encryption, rsa_pkcs1v15} ->
            gose@internal@key_encryption:unwrap_rsa_pkcs1v15_safe(
                Key,
                erlang:element(3, Recipient),
                Enc
            );

        {rsa_encryption, rsa_oaep_sha1} ->
            gose@internal@key_encryption:unwrap_rsa_oaep(
                Key,
                erlang:element(3, Recipient),
                sha1
            );

        {rsa_encryption, rsa_oaep_sha256} ->
            gose@internal@key_encryption:unwrap_rsa_oaep(
                Key,
                erlang:element(3, Recipient),
                sha256
            );

        {ecdh_es, {ecdh_es_aes_kw, Size@2}} ->
            unwrap_ecdh_es_aes_kw(Key, Recipient, Size@2);

        {ecdh_es, {ecdh_es_cha_cha20_kw, Variant@1}} ->
            unwrap_ecdh_es_chacha20_kw(Key, Recipient, Variant@1);

        direct ->
            {error,
                {invalid_state,
                    <<"unsupported algorithm for multi-recipient JWE decryption: "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}};

        {ecdh_es, ecdh_es_direct} ->
            {error,
                {invalid_state,
                    <<"unsupported algorithm for multi-recipient JWE decryption: "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}};

        {pbes2, _} ->
            {error,
                {invalid_state,
                    <<"unsupported algorithm for multi-recipient JWE decryption: "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}}
    end.

-file("src/gose/jose/jwe_multi.gleam", 686).
-spec build_epk_fields(
    gose@internal@key_encryption:ephemeral_public_key(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> list({binary(), gleam@json:json()}).
build_epk_fields(Epk, Apu, Apv) ->
    Fields = case Epk of
        {ec_ephemeral_key, Curve, X, Y} ->
            [{<<"epk"/utf8>>,
                    gleam@json:object(
                        [{<<"kty"/utf8>>, gleam@json:string(<<"EC"/utf8>>)},
                            {<<"crv"/utf8>>,
                                gleam@json:string(
                                    gose@internal@utils:ec_curve_to_string(
                                        Curve
                                    )
                                )},
                            {<<"x"/utf8>>,
                                gleam@json:string(
                                    gose@internal@utils:encode_base64_url(X)
                                )},
                            {<<"y"/utf8>>,
                                gleam@json:string(
                                    gose@internal@utils:encode_base64_url(Y)
                                )}]
                    )}];

        {xdh_ephemeral_key, Curve@1, X@1} ->
            [{<<"epk"/utf8>>,
                    gleam@json:object(
                        [{<<"kty"/utf8>>, gleam@json:string(<<"OKP"/utf8>>)},
                            {<<"crv"/utf8>>,
                                gleam@json:string(
                                    gose@internal@utils:xdh_curve_to_string(
                                        Curve@1
                                    )
                                )},
                            {<<"x"/utf8>>,
                                gleam@json:string(
                                    gose@internal@utils:encode_base64_url(X@1)
                                )}]
                    )}]
    end,
    Fields@1 = case Apu of
        {some, A} ->
            [{<<"apu"/utf8>>,
                    gleam@json:string(gose@internal@utils:encode_base64_url(A))} |
                Fields];

        none ->
            Fields
    end,
    case Apv of
        {some, A@1} ->
            [{<<"apv"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(A@1)
                    )} |
                Fields@1];

        none ->
            Fields@1
    end.

-file("src/gose/jose/jwe_multi.gleam", 730).
-spec build_kw_fields(bitstring(), bitstring()) -> list({binary(),
    gleam@json:json()}).
build_kw_fields(Kw_iv, Kw_tag) ->
    [{<<"iv"/utf8>>,
            gleam@json:string(gose@internal@utils:encode_base64_url(Kw_iv))},
        {<<"tag"/utf8>>,
            gleam@json:string(gose@internal@utils:encode_base64_url(Kw_tag))}].

-file("src/gose/jose/jwe_multi.gleam", 643).
-spec recipient_to_json(encrypted_recipient()) -> gleam@json:json().
recipient_to_json(Recipient) ->
    {Alg_str@4, Encrypted_key@4, Header_fields} = case Recipient of
        {simple_recipient, Alg_str, Encrypted_key} ->
            {Alg_str, Encrypted_key, []};

        {ecdh_es_recipient, Alg_str@1, Encrypted_key@1, Epk, Apu, Apv} ->
            {Alg_str@1, Encrypted_key@1, build_epk_fields(Epk, Apu, Apv)};

        {kw_with_iv_tag_recipient, Alg_str@2, Encrypted_key@2, Kw_iv, Kw_tag} ->
            {Alg_str@2, Encrypted_key@2, build_kw_fields(Kw_iv, Kw_tag)};

        {ecdh_es_kw_with_iv_tag_recipient,
            Alg_str@3,
            Encrypted_key@3,
            Epk@1,
            Apu@1,
            Apv@1,
            Kw_iv@1,
            Kw_tag@1} ->
            {Alg_str@3,
                Encrypted_key@3,
                lists:append(
                    build_epk_fields(Epk@1, Apu@1, Apv@1),
                    build_kw_fields(Kw_iv@1, Kw_tag@1)
                )}
    end,
    All_header_fields = [{<<"alg"/utf8>>, gleam@json:string(Alg_str@4)} |
        Header_fields],
    Fields = [{<<"header"/utf8>>, gleam@json:object(All_header_fields)}],
    Fields@1 = case erlang:byte_size(Encrypted_key@4) of
        0 ->
            Fields;

        _ ->
            [{<<"encrypted_key"/utf8>>,
                    gleam@json:string(
                        gose@internal@utils:encode_base64_url(Encrypted_key@4)
                    )} |
                Fields]
    end,
    gleam@json:object(Fields@1).

-file("src/gose/jose/jwe_multi.gleam", 186).
?DOC(" Serialize as JWE JSON General Serialization.\n").
-spec serialize_json(multi_jwe(encrypted())) -> gleam@json:json().
serialize_json(Message) ->
    {Protected_b64@1, Recipients@1, Iv@1, Ciphertext@1, Tag@1} = case Message of
        {encrypted_multi_jwe, _, Protected_b64, Recipients, Iv, Ciphertext, Tag} -> {
        Protected_b64,
            Recipients,
            Iv,
            Ciphertext,
            Tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe_multi"/utf8>>,
                        function => <<"serialize_json"/utf8>>,
                        line => 187,
                        value => _assert_fail,
                        start => 5410,
                        'end' => 5534,
                        pattern_start => 5421,
                        pattern_end => 5524})
    end,
    Recipient_objects = gleam@list:map(Recipients@1, fun recipient_to_json/1),
    gleam@json:object(
        [{<<"protected"/utf8>>, gleam@json:string(Protected_b64@1)},
            {<<"recipients"/utf8>>,
                gleam@json:preprocessed_array(Recipient_objects)},
            {<<"iv"/utf8>>,
                gleam@json:string(gose@internal@utils:encode_base64_url(Iv@1))},
            {<<"ciphertext"/utf8>>,
                gleam@json:string(
                    gose@internal@utils:encode_base64_url(Ciphertext@1)
                )},
            {<<"tag"/utf8>>,
                gleam@json:string(gose@internal@utils:encode_base64_url(Tag@1))}]
    ).

-file("src/gose/jose/jwe_multi.gleam", 740).
-spec parse_enc_from_protected(binary()) -> {ok, gose:content_alg()} |
    {error, gose:gose_error()}.
parse_enc_from_protected(Protected_b64) ->
    gleam@result:'try'(
        gose@internal@utils:decode_base64_url(
            Protected_b64,
            <<"protected header"/utf8>>
        ),
        fun(Protected_bytes) ->
            Decoder = begin
                gleam@dynamic@decode:field(
                    <<"enc"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Enc_str) -> gleam@dynamic@decode:success(Enc_str) end
                )
            end,
            gleam@result:'try'(
                begin
                    _pipe = gleam@json:parse_bits(Protected_bytes, Decoder),
                    gleam@result:replace_error(
                        _pipe,
                        {parse_error,
                            <<"missing enc in protected header"/utf8>>}
                    )
                end,
                fun(Enc_str@1) ->
                    gose@jose:content_alg_from_string(Enc_str@1)
                end
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 812).
-spec build_encrypted_recipient(
    binary(),
    bitstring(),
    gleam@option:option(gose@internal@key_encryption:ephemeral_public_key()),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
build_encrypted_recipient(Alg_str, Encrypted_key, Epk, Apu, Apv, Kw_iv, Kw_tag) ->
    case {Epk, Kw_iv, Kw_tag} of
        {{some, Epk@1}, {some, Kw_iv@1}, {some, Kw_tag@1}} ->
            {ok,
                {ecdh_es_kw_with_iv_tag_recipient,
                    Alg_str,
                    Encrypted_key,
                    Epk@1,
                    Apu,
                    Apv,
                    Kw_iv@1,
                    Kw_tag@1}};

        {{some, Epk@2}, none, none} ->
            {ok, {ecdh_es_recipient, Alg_str, Encrypted_key, Epk@2, Apu, Apv}};

        {none, {some, Kw_iv@2}, {some, Kw_tag@2}} ->
            {ok,
                {kw_with_iv_tag_recipient,
                    Alg_str,
                    Encrypted_key,
                    Kw_iv@2,
                    Kw_tag@2}};

        {none, none, none} ->
            {ok, {simple_recipient, Alg_str, Encrypted_key}};

        {_, _, _} ->
            {error,
                {parse_error,
                    <<"invalid recipient header field combination for "/utf8,
                        Alg_str/binary>>}}
    end.

-file("src/gose/jose/jwe_multi.gleam", 845).
-spec epk_decoder() -> gleam@dynamic@decode:decoder({binary(),
    binary(),
    binary(),
    gleam@option:option(binary())}).
epk_decoder() ->
    gleam@dynamic@decode:field(
        <<"kty"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(Kty) ->
            gleam@dynamic@decode:field(
                <<"crv"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(Crv) ->
                    gleam@dynamic@decode:field(
                        <<"x"/utf8>>,
                        {decoder, fun gleam@dynamic@decode:decode_string/1},
                        fun(X) ->
                            gleam@dynamic@decode:optional_field(
                                <<"y"/utf8>>,
                                none,
                                gleam@dynamic@decode:optional(
                                    {decoder,
                                        fun gleam@dynamic@decode:decode_string/1}
                                ),
                                fun(Y) ->
                                    gleam@dynamic@decode:success(
                                        {Kty, Crv, X, Y}
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 857).
-spec parse_optional_epk(
    gleam@option:option({binary(),
        binary(),
        binary(),
        gleam@option:option(binary())})
) -> {ok,
        gleam@option:option(gose@internal@key_encryption:ephemeral_public_key())} |
    {error, gose:gose_error()}.
parse_optional_epk(Raw) ->
    case Raw of
        none ->
            {ok, none};

        {some, {Kty, Crv, X_b64, Y_opt}} ->
            gleam@result:'try'(
                begin
                    _pipe = gleam@bit_array:base64_url_decode(X_b64),
                    gleam@result:replace_error(
                        _pipe,
                        {parse_error, <<"invalid epk x base64"/utf8>>}
                    )
                end,
                fun(X) -> case Kty of
                        <<"EC"/utf8>> ->
                            gleam@result:'try'(
                                gleam@option:to_result(
                                    Y_opt,
                                    {parse_error,
                                        <<"EC epk requires y coordinate"/utf8>>}
                                ),
                                fun(Y_b64) ->
                                    gleam@result:'try'(
                                        begin
                                            _pipe@1 = gleam@bit_array:base64_url_decode(
                                                Y_b64
                                            ),
                                            gleam@result:replace_error(
                                                _pipe@1,
                                                {parse_error,
                                                    <<"invalid epk y base64"/utf8>>}
                                            )
                                        end,
                                        fun(Y) ->
                                            gleam@result:'try'(
                                                gose@internal@utils:ec_curve_from_string(
                                                    Crv
                                                ),
                                                fun(Curve) ->
                                                    {ok,
                                                        {some,
                                                            {ec_ephemeral_key,
                                                                Curve,
                                                                X,
                                                                Y}}}
                                                end
                                            )
                                        end
                                    )
                                end
                            );

                        <<"OKP"/utf8>> ->
                            gleam@result:'try'(
                                gose@internal@utils:xdh_curve_from_string(Crv),
                                fun(Curve@1) ->
                                    {ok,
                                        {some, {xdh_ephemeral_key, Curve@1, X}}}
                                end
                            );

                        _ ->
                            {error,
                                {parse_error,
                                    <<"unsupported epk kty: "/utf8, Kty/binary>>}}
                    end end
            )
    end.

-file("src/gose/jose/jwe_multi.gleam", 890).
-spec decode_optional_b64(gleam@option:option(binary()), binary()) -> {ok,
        gleam@option:option(bitstring())} |
    {error, gose:gose_error()}.
decode_optional_b64(Raw, Label) ->
    case Raw of
        none ->
            {ok, none};

        {some, B64} ->
            _pipe = gose@internal@utils:decode_base64_url(B64, Label),
            gleam@result:map(_pipe, fun(Field@0) -> {some, Field@0} end)
    end.

-file("src/gose/jose/jwe_multi.gleam", 902).
-spec decode_optional_encrypted_key(gleam@option:option(binary())) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
decode_optional_encrypted_key(Raw) ->
    case Raw of
        {some, B64} ->
            gose@internal@utils:decode_base64_url(B64, <<"encrypted_key"/utf8>>);

        none ->
            {ok, <<>>}
    end.

-file("src/gose/jose/jwe_multi.gleam", 758).
-spec parse_raw_recipient(
    {gleam@dynamic:dynamic_(), gleam@option:option(binary())}
) -> {ok, encrypted_recipient()} | {error, gose:gose_error()}.
parse_raw_recipient(Raw) ->
    {Header_raw, Ek_opt} = Raw,
    Header_decoder = begin
        gleam@dynamic@decode:field(
            <<"alg"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Alg) ->
                gleam@dynamic@decode:optional_field(
                    <<"epk"/utf8>>,
                    none,
                    gleam@dynamic@decode:optional(epk_decoder()),
                    fun(Epk) ->
                        gleam@dynamic@decode:optional_field(
                            <<"apu"/utf8>>,
                            none,
                            gleam@dynamic@decode:optional(
                                {decoder,
                                    fun gleam@dynamic@decode:decode_string/1}
                            ),
                            fun(Apu) ->
                                gleam@dynamic@decode:optional_field(
                                    <<"apv"/utf8>>,
                                    none,
                                    gleam@dynamic@decode:optional(
                                        {decoder,
                                            fun gleam@dynamic@decode:decode_string/1}
                                    ),
                                    fun(Apv) ->
                                        gleam@dynamic@decode:optional_field(
                                            <<"iv"/utf8>>,
                                            none,
                                            gleam@dynamic@decode:optional(
                                                {decoder,
                                                    fun gleam@dynamic@decode:decode_string/1}
                                            ),
                                            fun(Iv) ->
                                                gleam@dynamic@decode:optional_field(
                                                    <<"tag"/utf8>>,
                                                    none,
                                                    gleam@dynamic@decode:optional(
                                                        {decoder,
                                                            fun gleam@dynamic@decode:decode_string/1}
                                                    ),
                                                    fun(Tag) ->
                                                        gleam@dynamic@decode:success(
                                                            {Alg,
                                                                Epk,
                                                                Apu,
                                                                Apv,
                                                                Iv,
                                                                Tag}
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
    end,
    gleam@result:'try'(
        begin
            _pipe = gleam@dynamic@decode:run(Header_raw, Header_decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"missing alg in recipient header"/utf8>>}
            )
        end,
        fun(_use0) ->
            {Alg_str, Epk_raw, Apu_b64, Apv_b64, Iv_b64, Tag_b64} = _use0,
            gleam@result:'try'(
                decode_optional_encrypted_key(Ek_opt),
                fun(Encrypted_key) ->
                    gleam@result:'try'(
                        parse_optional_epk(Epk_raw),
                        fun(Epk@1) ->
                            gleam@result:'try'(
                                decode_optional_b64(Apu_b64, <<"apu"/utf8>>),
                                fun(Apu@1) ->
                                    gleam@result:'try'(
                                        decode_optional_b64(
                                            Apv_b64,
                                            <<"apv"/utf8>>
                                        ),
                                        fun(Apv@1) ->
                                            gleam@result:'try'(
                                                decode_optional_b64(
                                                    Iv_b64,
                                                    <<"iv"/utf8>>
                                                ),
                                                fun(Kw_iv) ->
                                                    gleam@result:'try'(
                                                        decode_optional_b64(
                                                            Tag_b64,
                                                            <<"tag"/utf8>>
                                                        ),
                                                        fun(Kw_tag) ->
                                                            build_encrypted_recipient(
                                                                Alg_str,
                                                                Encrypted_key,
                                                                Epk@1,
                                                                Apu@1,
                                                                Apv@1,
                                                                Kw_iv,
                                                                Kw_tag
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

-file("src/gose/jose/jwe_multi.gleam", 208).
?DOC(" Parse a JWE from JSON General Serialization format.\n").
-spec parse_json(binary()) -> {ok, multi_jwe(encrypted())} |
    {error, gose:gose_error()}.
parse_json(Json_str) ->
    Recipient_decoder = begin
        gleam@dynamic@decode:field(
            <<"header"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_dynamic/1},
            fun(Header) ->
                gleam@dynamic@decode:optional_field(
                    <<"encrypted_key"/utf8>>,
                    none,
                    gleam@dynamic@decode:optional(
                        {decoder, fun gleam@dynamic@decode:decode_string/1}
                    ),
                    fun(Encrypted_key) ->
                        gleam@dynamic@decode:success({Header, Encrypted_key})
                    end
                )
            end
        )
    end,
    Decoder = begin
        gleam@dynamic@decode:field(
            <<"protected"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Protected) ->
                gleam@dynamic@decode:field(
                    <<"recipients"/utf8>>,
                    gleam@dynamic@decode:list(Recipient_decoder),
                    fun(Recipients) ->
                        gleam@dynamic@decode:field(
                            <<"iv"/utf8>>,
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            fun(Iv) ->
                                gleam@dynamic@decode:field(
                                    <<"ciphertext"/utf8>>,
                                    {decoder,
                                        fun gleam@dynamic@decode:decode_string/1},
                                    fun(Ciphertext) ->
                                        gleam@dynamic@decode:field(
                                            <<"tag"/utf8>>,
                                            {decoder,
                                                fun gleam@dynamic@decode:decode_string/1},
                                            fun(Tag) ->
                                                gleam@dynamic@decode:success(
                                                    {Protected,
                                                        Recipients,
                                                        Iv,
                                                        Ciphertext,
                                                        Tag}
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
    end,
    gleam@result:'try'(
        begin
            _pipe = gleam@json:parse(Json_str, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"invalid JWE JSON"/utf8>>}
            )
        end,
        fun(_use0) ->
            {Protected_b64, Raw_recipients, Iv_b64, Ct_b64, Tag_b64} = _use0,
            gleam@result:'try'(
                parse_enc_from_protected(Protected_b64),
                fun(Enc) ->
                    gleam@result:'try'(
                        gleam@list:try_map(
                            Raw_recipients,
                            fun parse_raw_recipient/1
                        ),
                        fun(Recipients@1) ->
                            gleam@result:'try'(
                                gose@internal@utils:decode_base64_url(
                                    Iv_b64,
                                    <<"iv"/utf8>>
                                ),
                                fun(Iv@1) ->
                                    gleam@result:'try'(
                                        gose@internal@utils:decode_base64_url(
                                            Ct_b64,
                                            <<"ciphertext"/utf8>>
                                        ),
                                        fun(Ciphertext@1) ->
                                            gleam@result:'try'(
                                                gose@internal@utils:decode_base64_url(
                                                    Tag_b64,
                                                    <<"tag"/utf8>>
                                                ),
                                                fun(Tag@1) ->
                                                    gleam@result:'try'(
                                                        gose@internal@content_encryption:validate_iv_tag_sizes(
                                                            Enc,
                                                            Iv@1,
                                                            Tag@1
                                                        ),
                                                        fun(_) ->
                                                            {ok,
                                                                {encrypted_multi_jwe,
                                                                    Enc,
                                                                    Protected_b64,
                                                                    Recipients@1,
                                                                    Iv@1,
                                                                    Ciphertext@1,
                                                                    Tag@1}}
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

-file("src/gose/jose/jwe_multi.gleam", 1035).
-spec unwrap_and_decrypt(
    encrypted_recipient(),
    gose:key(binary()),
    gose:key_encryption_alg(),
    gose:content_alg(),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_and_decrypt(Recipient, Key, Key_alg, Enc, Iv, Aead_aad, Ciphertext, Tag) ->
    gleam@result:'try'(
        unwrap_cek(Key_alg, Key, Recipient, Enc),
        fun(Cek) ->
            gose@internal@content_encryption:decrypt_content(
                Enc,
                Cek,
                Iv,
                Aead_aad,
                Ciphertext,
                Tag
            )
        end
    ).

-file("src/gose/jose/jwe_multi.gleam", 978).
-spec try_keys(
    list(gose:key(binary())),
    encrypted_recipient(),
    gose:key_encryption_alg(),
    gose:content_alg(),
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
    Enc,
    Iv,
    Aead_aad,
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
                Enc,
                Iv,
                Aead_aad,
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
                        Enc,
                        Iv,
                        Aead_aad,
                        Ciphertext,
                        Tag,
                        {error, E}
                    );

                {error, verification_failed = E@1} ->
                    try_keys(
                        Rest,
                        Recipient,
                        Key_alg,
                        Enc,
                        Iv,
                        Aead_aad,
                        Ciphertext,
                        Tag,
                        {error, E@1}
                    );

                {error, E@2} ->
                    {error, E@2}
            end
    end.

-file("src/gose/jose/jwe_multi.gleam", 955).
-spec try_keys_for_recipient(
    encrypted_recipient(),
    list(gose:key(binary())),
    gose:key_encryption_alg(),
    gose:content_alg(),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
try_keys_for_recipient(
    Recipient,
    Keys,
    Key_alg,
    Enc,
    Iv,
    Aead_aad,
    Ciphertext,
    Tag
) ->
    try_keys(
        Keys,
        Recipient,
        Key_alg,
        Enc,
        Iv,
        Aead_aad,
        Ciphertext,
        Tag,
        {error, {crypto_error, <<"no key could decrypt"/utf8>>}}
    ).

-file("src/gose/jose/jwe_multi.gleam", 911).
-spec try_decrypt_recipients(
    list(encrypted_recipient()),
    list(gose:key(binary())),
    gose:key_encryption_alg(),
    gose:content_alg(),
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
    Enc,
    Iv,
    Aead_aad,
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
                Enc,
                Iv,
                Aead_aad,
                Ciphertext,
                Tag
            ),
            case Result of
                {ok, Plaintext} ->
                    {ok, Plaintext};

                {error, E} ->
                    try_decrypt_recipients(
                        Rest,
                        Keys,
                        Key_alg,
                        Enc,
                        Iv,
                        Aead_aad,
                        Ciphertext,
                        Tag,
                        {error, E}
                    )
            end
    end.

-file("src/gose/jose/jwe_multi.gleam", 268).
?DOC(" Decrypt a multi-recipient JWE.\n").
-spec decrypt(decryptor(), multi_jwe(encrypted())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
decrypt(Decryptor, Message) ->
    {decryptor, Key_alg, Expected_enc, Keys} = Decryptor,
    {Actual_enc@1, Protected_b64@1, Recipients@1, Iv@1, Ciphertext@1, Tag@1} = case Message of
        {encrypted_multi_jwe,
            Actual_enc,
            Protected_b64,
            Recipients,
            Iv,
            Ciphertext,
            Tag} -> {Actual_enc, Protected_b64, Recipients, Iv, Ciphertext, Tag};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe_multi"/utf8>>,
                        function => <<"decrypt"/utf8>>,
                        line => 273,
                        value => _assert_fail,
                        start => 8148,
                        'end' => 8285,
                        pattern_start => 8159,
                        pattern_end => 8275})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:require_matching_content_algorithm(
            Expected_enc,
            Actual_enc@1
        ),
        fun(_) ->
            Expected_alg_str = gose@jose:key_encryption_alg_to_string(Key_alg),
            Matching = gleam@list:filter(
                Recipients@1,
                fun(R) -> erlang:element(2, R) =:= Expected_alg_str end
            ),
            Aead_aad = gose@internal@content_encryption:build_jwe_aad(
                Protected_b64@1,
                none
            ),
            try_decrypt_recipients(
                Matching,
                Keys,
                Key_alg,
                Actual_enc@1,
                Iv@1,
                Aead_aad,
                Ciphertext@1,
                Tag@1,
                {error, {crypto_error, <<"no matching recipient found"/utf8>>}}
            )
        end
    ).
