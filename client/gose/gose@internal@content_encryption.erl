-module(gose@internal@content_encryption).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/internal/content_encryption.gleam").
-export([iv_size/1, tag_size/1, validate_iv_tag_sizes/3, generate_cek/1, generate_iv/1, build_jwe_aad/2, aes_block_for_size/1, hash_for_aes_size/1, aes_cipher/2, encrypt_content/5, decrypt_content/6]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(false).

-file("src/gose/internal/content_encryption.gleam", 16).
?DOC(false).
-spec iv_size(gose:content_alg()) -> integer().
iv_size(Enc) ->
    case Enc of
        {aes_gcm, _} ->
            12;

        {aes_cbc_hmac, _} ->
            16;

        cha_cha20_poly1305 ->
            12;

        x_cha_cha20_poly1305 ->
            24
    end.

-file("src/gose/internal/content_encryption.gleam", 25).
?DOC(false).
-spec tag_size(gose:content_alg()) -> integer().
tag_size(Enc) ->
    case Enc of
        {aes_gcm, _} ->
            16;

        {aes_cbc_hmac, Size} ->
            gose:aes_key_size(Size);

        cha_cha20_poly1305 ->
            16;

        x_cha_cha20_poly1305 ->
            16
    end.

-file("src/gose/internal/content_encryption.gleam", 33).
?DOC(false).
-spec validate_iv_tag_sizes(gose:content_alg(), bitstring(), bitstring()) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_iv_tag_sizes(Enc, Iv, Tag) ->
    Expected_iv = iv_size(Enc),
    Actual_iv = erlang:byte_size(Iv),
    gleam@bool:guard(
        Actual_iv /= Expected_iv,
        {error,
            {parse_error,
                <<<<<<"invalid IV length: expected "/utf8,
                            (erlang:integer_to_binary(Expected_iv))/binary>>/binary,
                        " bytes, got "/utf8>>/binary,
                    (erlang:integer_to_binary(Actual_iv))/binary>>}},
        fun() ->
            Expected_tag = tag_size(Enc),
            Actual_tag = erlang:byte_size(Tag),
            gleam@bool:guard(
                Actual_tag /= Expected_tag,
                {error,
                    {parse_error,
                        <<<<<<"invalid tag length: expected "/utf8,
                                    (erlang:integer_to_binary(Expected_tag))/binary>>/binary,
                                " bytes, got "/utf8>>/binary,
                            (erlang:integer_to_binary(Actual_tag))/binary>>}},
                fun() -> {ok, nil} end
            )
        end
    ).

-file("src/gose/internal/content_encryption.gleam", 65).
?DOC(false).
-spec generate_cek(gose:content_alg()) -> bitstring().
generate_cek(Enc) ->
    kryptos_ffi:random_bytes(gose:content_alg_key_size(Enc)).

-file("src/gose/internal/content_encryption.gleam", 69).
?DOC(false).
-spec generate_iv(gose:content_alg()) -> bitstring().
generate_iv(Enc) ->
    kryptos_ffi:random_bytes(iv_size(Enc)).

-file("src/gose/internal/content_encryption.gleam", 73).
?DOC(false).
-spec build_jwe_aad(binary(), gleam@option:option(bitstring())) -> bitstring().
build_jwe_aad(Protected_b64, User_aad) ->
    case User_aad of
        none ->
            gleam_stdlib:identity(Protected_b64);

        {some, Aad} ->
            Aad_b64 = gose@internal@utils:encode_base64_url(Aad),
            gleam_stdlib:bit_array_concat(
                [gleam_stdlib:identity(Protected_b64),
                    <<"."/utf8>>,
                    gleam_stdlib:identity(Aad_b64)]
            )
    end.

-file("src/gose/internal/content_encryption.gleam", 90).
?DOC(false).
-spec aes_block_for_size(gose:aes_key_size()) -> fun((bitstring()) -> {ok,
        kryptos@block:block_cipher()} |
    {error, nil}).
aes_block_for_size(Size) ->
    case Size of
        aes128 ->
            fun kryptos@block:aes_128/1;

        aes192 ->
            fun kryptos@block:aes_192/1;

        aes256 ->
            fun kryptos@block:aes_256/1
    end.

-file("src/gose/internal/content_encryption.gleam", 100).
?DOC(false).
-spec hash_for_aes_size(gose:aes_key_size()) -> kryptos@hash:hash_algorithm().
hash_for_aes_size(Size) ->
    case Size of
        aes128 ->
            sha256;

        aes192 ->
            sha384;

        aes256 ->
            sha512
    end.

-file("src/gose/internal/content_encryption.gleam", 192).
?DOC(false).
-spec encrypt_aes_gcm(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    fun((bitstring()) -> {ok, kryptos@block:block_cipher()} | {error, nil})
) -> {ok, {bitstring(), bitstring()}} | {error, gose:gose_error()}.
encrypt_aes_gcm(Cek, Iv, Aad, Plaintext, Cipher_fn) ->
    gleam@result:'try'(
        begin
            _pipe = Cipher_fn(Cek),
            gleam@result:replace_error(
                _pipe,
                {crypto_error, <<"invalid CEK size for AES-GCM"/utf8>>}
            )
        end,
        fun(Cipher) ->
            Ctx = kryptos@aead:gcm(Cipher),
            _pipe@1 = kryptos@aead:seal_with_aad(Ctx, Iv, Plaintext, Aad),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error, <<"AES-GCM encryption failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/content_encryption.gleam", 208).
?DOC(false).
-spec decrypt_aes_gcm(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    fun((bitstring()) -> {ok, kryptos@block:block_cipher()} | {error, nil})
) -> {ok, bitstring()} | {error, gose:gose_error()}.
decrypt_aes_gcm(Cek, Iv, Aad, Ciphertext, Tag, Cipher_fn) ->
    gleam@result:'try'(
        begin
            _pipe = Cipher_fn(Cek),
            gleam@result:replace_error(
                _pipe,
                {crypto_error, <<"invalid CEK size for AES-GCM"/utf8>>}
            )
        end,
        fun(Cipher) ->
            Ctx = kryptos@aead:gcm(Cipher),
            _pipe@1 = kryptos@aead:open_with_aad(Ctx, Iv, Tag, Ciphertext, Aad),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error, <<"AES-GCM decryption failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/content_encryption.gleam", 225).
?DOC(false).
-spec encrypt_chacha20_variant(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    fun((bitstring()) -> {ok, kryptos@aead:aead_context()} | {error, nil}),
    binary()
) -> {ok, {bitstring(), bitstring()}} | {error, gose:gose_error()}.
encrypt_chacha20_variant(Cek, Iv, Aad, Plaintext, Cipher_fn, Variant_name) ->
    gleam@result:'try'(
        begin
            _pipe = Cipher_fn(Cek),
            gleam@result:replace_error(
                _pipe,
                {crypto_error,
                    <<"invalid key size for "/utf8, Variant_name/binary>>}
            )
        end,
        fun(Ctx) ->
            _pipe@1 = kryptos@aead:seal_with_aad(Ctx, Iv, Plaintext, Aad),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error,
                    <<Variant_name/binary, " encryption failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/content_encryption.gleam", 243).
?DOC(false).
-spec decrypt_chacha20_variant(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    fun((bitstring()) -> {ok, kryptos@aead:aead_context()} | {error, nil}),
    binary()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
decrypt_chacha20_variant(Cek, Iv, Aad, Ciphertext, Tag, Cipher_fn, Variant_name) ->
    gleam@result:'try'(
        begin
            _pipe = Cipher_fn(Cek),
            gleam@result:replace_error(
                _pipe,
                {crypto_error,
                    <<"invalid key size for "/utf8, Variant_name/binary>>}
            )
        end,
        fun(Ctx) ->
            _pipe@1 = kryptos@aead:open_with_aad(Ctx, Iv, Tag, Ciphertext, Aad),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error,
                    <<Variant_name/binary, " decryption failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/content_encryption.gleam", 262).
?DOC(false).
-spec aes_cipher(gose:aes_key_size(), bitstring()) -> {ok,
        kryptos@block:block_cipher()} |
    {error, gose:gose_error()}.
aes_cipher(Size, Key) ->
    _pipe = (aes_block_for_size(Size))(Key),
    gleam@result:replace_error(
        _pipe,
        {crypto_error, <<"failed to create AES cipher"/utf8>>}
    ).

-file("src/gose/internal/content_encryption.gleam", 270).
?DOC(false).
-spec split_cek(bitstring(), integer()) -> {ok, {bitstring(), bitstring()}} |
    {error, gose:gose_error()}.
split_cek(Cek, Key_size) ->
    case Cek of
        <<Mk:Key_size/binary, Ek:Key_size/binary>> ->
            {ok, {Mk, Ek}};

        _ ->
            {error,
                {crypto_error,
                    <<<<<<"invalid CEK size for AES-CBC-HMAC: expected "/utf8,
                                (erlang:integer_to_binary(Key_size * 2))/binary>>/binary,
                            " bytes, got "/utf8>>/binary,
                        (erlang:integer_to_binary(erlang:byte_size(Cek)))/binary>>}}
    end.

-file("src/gose/internal/content_encryption.gleam", 286).
?DOC(false).
-spec encrypt_aes_cbc_hmac(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    kryptos@hash:hash_algorithm(),
    gose:aes_key_size()
) -> {ok, {bitstring(), bitstring()}} | {error, gose:gose_error()}.
encrypt_aes_cbc_hmac(Cek, Iv, Aad, Plaintext, Hash_alg, Size) ->
    Half = gose:aes_key_size(Size),
    gleam@result:'try'(
        split_cek(Cek, Half),
        fun(_use0) ->
            {Mac_key, Enc_key} = _use0,
            gleam@result:'try'(
                aes_cipher(Size, Enc_key),
                fun(Cipher) ->
                    gleam@result:'try'(
                        begin
                            _pipe = kryptos@block:cbc(Cipher, Iv),
                            gleam@result:replace_error(
                                _pipe,
                                {crypto_error,
                                    <<"invalid IV for AES-CBC"/utf8>>}
                            )
                        end,
                        fun(Ctx) ->
                            gleam@result:'try'(
                                begin
                                    _pipe@1 = kryptos@block:encrypt(
                                        Ctx,
                                        Plaintext
                                    ),
                                    gleam@result:replace_error(
                                        _pipe@1,
                                        {crypto_error,
                                            <<"AES-CBC encryption failed"/utf8>>}
                                    )
                                end,
                                fun(Ciphertext) ->
                                    Aad_len = erlang:byte_size(Aad),
                                    Al = <<((Aad_len * 8)):64>>,
                                    Mac_input = gleam_stdlib:bit_array_concat(
                                        [Aad, Iv, Ciphertext, Al]
                                    ),
                                    gleam@result:'try'(
                                        begin
                                            _pipe@2 = kryptos@crypto:hmac(
                                                Hash_alg,
                                                Mac_key,
                                                Mac_input
                                            ),
                                            gleam@result:replace_error(
                                                _pipe@2,
                                                {crypto_error,
                                                    <<"HMAC computation failed"/utf8>>}
                                            )
                                        end,
                                        fun(Full_mac) ->
                                            Tag_size = erlang:byte_size(
                                                Full_mac
                                            )
                                            div 2,
                                            case gleam_stdlib:bit_array_slice(
                                                Full_mac,
                                                0,
                                                Tag_size
                                            ) of
                                                {ok, Tag} ->
                                                    {ok, {Ciphertext, Tag}};

                                                {error, _} ->
                                                    {error,
                                                        {crypto_error,
                                                            <<"tag extraction failed"/utf8>>}}
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
    ).

-file("src/gose/internal/content_encryption.gleam", 108).
?DOC(false).
-spec encrypt_content(
    gose:content_alg(),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, {bitstring(), bitstring()}} | {error, gose:gose_error()}.
encrypt_content(Enc, Cek, Iv, Aad, Plaintext) ->
    case Enc of
        {aes_gcm, Size} ->
            encrypt_aes_gcm(Cek, Iv, Aad, Plaintext, aes_block_for_size(Size));

        {aes_cbc_hmac, Size@1} ->
            encrypt_aes_cbc_hmac(
                Cek,
                Iv,
                Aad,
                Plaintext,
                hash_for_aes_size(Size@1),
                Size@1
            );

        cha_cha20_poly1305 ->
            encrypt_chacha20_variant(
                Cek,
                Iv,
                Aad,
                Plaintext,
                fun kryptos@aead:chacha20_poly1305/1,
                <<"ChaCha20-Poly1305"/utf8>>
            );

        x_cha_cha20_poly1305 ->
            encrypt_chacha20_variant(
                Cek,
                Iv,
                Aad,
                Plaintext,
                fun kryptos@aead:xchacha20_poly1305/1,
                <<"XChaCha20-Poly1305"/utf8>>
            )
    end.

-file("src/gose/internal/content_encryption.gleam", 323).
?DOC(false).
-spec decrypt_aes_cbc_hmac(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    kryptos@hash:hash_algorithm(),
    gose:aes_key_size()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
decrypt_aes_cbc_hmac(Cek, Iv, Aad, Ciphertext, Tag, Hash_alg, Size) ->
    Half = gose:aes_key_size(Size),
    gleam@result:'try'(
        split_cek(Cek, Half),
        fun(_use0) ->
            {Mac_key, Enc_key} = _use0,
            Aad_len = erlang:byte_size(Aad),
            Al = <<((Aad_len * 8)):64>>,
            Mac_input = gleam_stdlib:bit_array_concat([Aad, Iv, Ciphertext, Al]),
            gleam@result:'try'(
                begin
                    _pipe = kryptos@crypto:hmac(Hash_alg, Mac_key, Mac_input),
                    gleam@result:replace_error(
                        _pipe,
                        {crypto_error, <<"HMAC computation failed"/utf8>>}
                    )
                end,
                fun(Full_mac) ->
                    Tag_size = erlang:byte_size(Full_mac) div 2,
                    gleam@result:'try'(
                        begin
                            _pipe@1 = gleam_stdlib:bit_array_slice(
                                Full_mac,
                                0,
                                Tag_size
                            ),
                            gleam@result:replace_error(
                                _pipe@1,
                                {crypto_error, <<"tag extraction failed"/utf8>>}
                            )
                        end,
                        fun(Expected_tag) ->
                            gleam@bool:guard(
                                not fun kryptos_ffi:constant_time_equal/2(
                                    Tag,
                                    Expected_tag
                                ),
                                {error,
                                    {crypto_error,
                                        <<"authentication tag mismatch"/utf8>>}},
                                fun() ->
                                    gleam@result:'try'(
                                        aes_cipher(Size, Enc_key),
                                        fun(Cipher) ->
                                            case kryptos@block:cbc(Cipher, Iv) of
                                                {ok, Ctx} ->
                                                    _pipe@2 = kryptos@block:decrypt(
                                                        Ctx,
                                                        Ciphertext
                                                    ),
                                                    gleam@result:replace_error(
                                                        _pipe@2,
                                                        {crypto_error,
                                                            <<"AES-CBC decryption failed"/utf8>>}
                                                    );

                                                {error, _} ->
                                                    {error,
                                                        {crypto_error,
                                                            <<"invalid IV for AES-CBC"/utf8>>}}
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
    ).

-file("src/gose/internal/content_encryption.gleam", 148).
?DOC(false).
-spec decrypt_content(
    gose:content_alg(),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
decrypt_content(Enc, Cek, Iv, Aad, Ciphertext, Tag) ->
    case Enc of
        {aes_gcm, Size} ->
            decrypt_aes_gcm(
                Cek,
                Iv,
                Aad,
                Ciphertext,
                Tag,
                aes_block_for_size(Size)
            );

        {aes_cbc_hmac, Size@1} ->
            decrypt_aes_cbc_hmac(
                Cek,
                Iv,
                Aad,
                Ciphertext,
                Tag,
                hash_for_aes_size(Size@1),
                Size@1
            );

        cha_cha20_poly1305 ->
            decrypt_chacha20_variant(
                Cek,
                Iv,
                Aad,
                Ciphertext,
                Tag,
                fun kryptos@aead:chacha20_poly1305/1,
                <<"ChaCha20-Poly1305"/utf8>>
            );

        x_cha_cha20_poly1305 ->
            decrypt_chacha20_variant(
                Cek,
                Iv,
                Aad,
                Ciphertext,
                Tag,
                fun kryptos@aead:xchacha20_poly1305/1,
                <<"XChaCha20-Poly1305"/utf8>>
            )
    end.
