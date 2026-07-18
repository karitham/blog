-module(gose@internal@key_encryption).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/internal/key_encryption.gleam").
-export([get_octet_key/2, wrap_aes_kw/3, unwrap_aes_kw/3, wrap_aes_gcm/4, unwrap_aes_gcm/5, unwrap_aes_gcm_kw/5, wrap_chacha20_by_variant/4, unwrap_chacha20_by_variant/5, unwrap_chacha20_kw/5, wrap_rsa_oaep/3, unwrap_rsa_oaep/3, wrap_rsa_pkcs1v15/2, unwrap_rsa_pkcs1v15_safe/3, unwrap_direct/2, compute_ecdh_shared_secret/1, compute_ecdh_shared_secret_with_epk/2, derive_ecdh_key/5, wrap_ecdh_es_chacha20_kw/6, unwrap_ecdh_es_chacha20_kw/9, wrap_ecdh_es_direct/5, unwrap_ecdh_es_direct/6, wrap_ecdh_es_kw/6, unwrap_ecdh_es_kw/7]).
-export_type([ephemeral_public_key/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(false).

-type ephemeral_public_key() :: {ec_ephemeral_key,
        kryptos@ec:curve(),
        bitstring(),
        bitstring()} |
    {xdh_ephemeral_key, kryptos@xdh:curve(), bitstring()}.

-file("src/gose/internal/key_encryption.gleam", 49).
?DOC(false).
-spec get_octet_key(gose:key(any()), integer()) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
get_octet_key(Key, Expected_size) ->
    gleam@result:'try'(
        begin
            _pipe = gose:material_octet_secret(gose:material(Key)),
            gleam@result:replace_error(
                _pipe,
                {invalid_state, <<"expected octet key"/utf8>>}
            )
        end,
        fun(Secret) ->
            Actual_size = erlang:byte_size(Secret),
            gleam@bool:guard(
                Actual_size /= Expected_size,
                {error,
                    {invalid_state,
                        <<<<<<"expected "/utf8,
                                    (erlang:integer_to_binary(Expected_size))/binary>>/binary,
                                "-byte key, got "/utf8>>/binary,
                            (erlang:integer_to_binary(Actual_size))/binary>>}},
                fun() -> {ok, Secret} end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 27).
?DOC(false).
-spec wrap_aes_kw(gose:key(any()), bitstring(), gose:aes_key_size()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
wrap_aes_kw(Key, Cek, Size) ->
    gleam@result:'try'(
        get_octet_key(Key, gose:aes_key_size(Size)),
        fun(Secret) ->
            gleam@result:'try'(
                gose@internal@content_encryption:aes_cipher(Size, Secret),
                fun(Cipher) -> _pipe = kryptos@block:wrap(Cipher, Cek),
                    gleam@result:replace_error(
                        _pipe,
                        {crypto_error, <<"AES Key Wrap failed"/utf8>>}
                    ) end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 38).
?DOC(false).
-spec unwrap_aes_kw(gose:key(any()), bitstring(), gose:aes_key_size()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
unwrap_aes_kw(Key, Encrypted_key, Size) ->
    gleam@result:'try'(
        get_octet_key(Key, gose:aes_key_size(Size)),
        fun(Secret) ->
            gleam@result:'try'(
                gose@internal@content_encryption:aes_cipher(Size, Secret),
                fun(Cipher) ->
                    _pipe = kryptos@block:unwrap(Cipher, Encrypted_key),
                    gleam@result:replace_error(
                        _pipe,
                        {crypto_error, <<"AES Key Unwrap failed"/utf8>>}
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 72).
?DOC(false).
-spec wrap_aes_gcm(bitstring(), bitstring(), bitstring(), gose:aes_key_size()) -> {ok,
        {bitstring(), bitstring()}} |
    {error, gose:gose_error()}.
wrap_aes_gcm(Kek, Cek, Iv, Size) ->
    gleam@result:'try'(
        gose@internal@content_encryption:aes_cipher(Size, Kek),
        fun(Cipher) ->
            Ctx = kryptos@aead:gcm(Cipher),
            _pipe = kryptos@aead:seal(Ctx, Iv, Cek),
            gleam@result:replace_error(
                _pipe,
                {crypto_error, <<"AES-GCM Key Wrap failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 84).
?DOC(false).
-spec unwrap_aes_gcm(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    gose:aes_key_size()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_aes_gcm(Kek, Encrypted_cek, Iv, Tag, Size) ->
    gleam@result:'try'(
        gose@internal@content_encryption:aes_cipher(Size, Kek),
        fun(Cipher) ->
            Ctx = kryptos@aead:gcm(Cipher),
            _pipe = kryptos@aead:open(Ctx, Iv, Tag, Encrypted_cek),
            gleam@result:replace_error(
                _pipe,
                {crypto_error, <<"AES-GCM Key Unwrap failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 97).
?DOC(false).
-spec unwrap_aes_gcm_kw(
    gose:key(any()),
    bitstring(),
    gose:aes_key_size(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_aes_gcm_kw(Key, Encrypted_cek, Size, Kw_iv, Kw_tag) ->
    gleam@result:'try'(
        gleam@option:to_result(
            Kw_iv,
            {parse_error, <<"missing iv header for AES-GCM Key Wrap"/utf8>>}
        ),
        fun(Iv) ->
            gleam@result:'try'(
                gleam@option:to_result(
                    Kw_tag,
                    {parse_error,
                        <<"missing tag header for AES-GCM Key Wrap"/utf8>>}
                ),
                fun(Tag) ->
                    gleam@result:'try'(
                        get_octet_key(Key, gose:aes_key_size(Size)),
                        fun(Kek) ->
                            unwrap_aes_gcm(Kek, Encrypted_cek, Iv, Tag, Size)
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 117).
?DOC(false).
-spec chacha20_variant_params(gose:cha_cha20_kw()) -> {fun((bitstring()) -> {ok,
            kryptos@aead:aead_context()} |
        {error, nil}),
    binary()}.
chacha20_variant_params(Variant) ->
    case Variant of
        c20_p_kw ->
            {fun kryptos@aead:chacha20_poly1305/1, <<"ChaCha20-Poly1305"/utf8>>};

        x_c20_p_kw ->
            {fun kryptos@aead:xchacha20_poly1305/1,
                <<"XChaCha20-Poly1305"/utf8>>}
    end.

-file("src/gose/internal/key_encryption.gleam", 126).
?DOC(false).
-spec wrap_chacha20_variant(
    bitstring(),
    bitstring(),
    bitstring(),
    fun((bitstring()) -> {ok, kryptos@aead:aead_context()} | {error, nil}),
    binary()
) -> {ok, {bitstring(), bitstring()}} | {error, gose:gose_error()}.
wrap_chacha20_variant(Kek, Cek, Nonce, Cipher_fn, Variant_name) ->
    gleam@result:'try'(
        begin
            _pipe = Cipher_fn(Kek),
            gleam@result:replace_error(
                _pipe,
                {crypto_error,
                    <<<<"invalid key size for "/utf8, Variant_name/binary>>/binary,
                        " Key Wrap"/utf8>>}
            )
        end,
        fun(Ctx) -> _pipe@1 = kryptos@aead:seal(Ctx, Nonce, Cek),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error, <<Variant_name/binary, " Key Wrap failed"/utf8>>}
            ) end
    ).

-file("src/gose/internal/key_encryption.gleam", 143).
?DOC(false).
-spec unwrap_chacha20_variant(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    fun((bitstring()) -> {ok, kryptos@aead:aead_context()} | {error, nil}),
    binary()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_chacha20_variant(Kek, Encrypted_cek, Nonce, Tag, Cipher_fn, Variant_name) ->
    gleam@result:'try'(
        begin
            _pipe = Cipher_fn(Kek),
            gleam@result:replace_error(
                _pipe,
                {crypto_error,
                    <<<<"invalid key size for "/utf8, Variant_name/binary>>/binary,
                        " Key Unwrap"/utf8>>}
            )
        end,
        fun(Ctx) -> _pipe@1 = kryptos@aead:open(Ctx, Nonce, Tag, Encrypted_cek),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error,
                    <<Variant_name/binary, " Key Unwrap failed"/utf8>>}
            ) end
    ).

-file("src/gose/internal/key_encryption.gleam", 161).
?DOC(false).
-spec wrap_chacha20_by_variant(
    bitstring(),
    bitstring(),
    bitstring(),
    gose:cha_cha20_kw()
) -> {ok, {bitstring(), bitstring()}} | {error, gose:gose_error()}.
wrap_chacha20_by_variant(Kek, Cek, Nonce, Variant) ->
    {Cipher_fn, Variant_name} = chacha20_variant_params(Variant),
    wrap_chacha20_variant(Kek, Cek, Nonce, Cipher_fn, Variant_name).

-file("src/gose/internal/key_encryption.gleam", 177).
?DOC(false).
-spec unwrap_chacha20_by_variant(
    bitstring(),
    bitstring(),
    bitstring(),
    bitstring(),
    gose:cha_cha20_kw()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_chacha20_by_variant(Kek, Encrypted_cek, Nonce, Tag, Variant) ->
    {Cipher_fn, Variant_name} = chacha20_variant_params(Variant),
    unwrap_chacha20_variant(
        Kek,
        Encrypted_cek,
        Nonce,
        Tag,
        Cipher_fn,
        Variant_name
    ).

-file("src/gose/internal/key_encryption.gleam", 195).
?DOC(false).
-spec unwrap_chacha20_kw(
    gose:key(any()),
    bitstring(),
    gose:cha_cha20_kw(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_chacha20_kw(Key, Encrypted_cek, Variant, Kw_iv, Kw_tag) ->
    gleam@result:'try'(
        gleam@option:to_result(
            Kw_iv,
            {parse_error, <<"missing iv header for ChaCha20 Key Wrap"/utf8>>}
        ),
        fun(Iv) ->
            gleam@result:'try'(
                gleam@option:to_result(
                    Kw_tag,
                    {parse_error,
                        <<"missing tag header for ChaCha20 Key Wrap"/utf8>>}
                ),
                fun(Tag) ->
                    gleam@result:'try'(
                        get_octet_key(Key, 32),
                        fun(Kek) ->
                            unwrap_chacha20_by_variant(
                                Kek,
                                Encrypted_cek,
                                Iv,
                                Tag,
                                Variant
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 271).
?DOC(false).
-spec wrap_rsa_oaep(gose:key(any()), bitstring(), kryptos@hash:hash_algorithm()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
wrap_rsa_oaep(Key, Cek, Hash_alg) ->
    gleam@result:'try'(
        begin
            _pipe = gose@internal@key_extract:rsa_public_key(gose:material(Key)),
            gleam@result:replace_error(
                _pipe,
                {invalid_state, <<"RSA encryption requires an RSA key"/utf8>>}
            )
        end,
        fun(Public) ->
            Padding = {oaep, Hash_alg, <<>>},
            _pipe@1 = kryptos_ffi:rsa_encrypt(Public, Cek, Padding),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error, <<"RSA-OAEP encryption failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 287).
?DOC(false).
-spec unwrap_rsa_oaep(
    gose:key(any()),
    bitstring(),
    kryptos@hash:hash_algorithm()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_rsa_oaep(Key, Encrypted_key, Hash_alg) ->
    gleam@result:'try'(
        begin
            _pipe = gose@internal@key_extract:rsa_private_key(
                gose:material(Key)
            ),
            gleam@result:replace_error(
                _pipe,
                {invalid_state,
                    <<"RSA decryption requires an RSA private key"/utf8>>}
            )
        end,
        fun(Private) ->
            Padding = {oaep, Hash_alg, <<>>},
            _pipe@1 = kryptos_ffi:rsa_decrypt(Private, Encrypted_key, Padding),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error, <<"RSA-OAEP decryption failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 303).
?DOC(false).
-spec wrap_rsa_pkcs1v15(gose:key(any()), bitstring()) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
wrap_rsa_pkcs1v15(Key, Cek) ->
    gleam@result:'try'(
        begin
            _pipe = gose@internal@key_extract:rsa_public_key(gose:material(Key)),
            gleam@result:replace_error(
                _pipe,
                {invalid_state, <<"RSA encryption requires an RSA key"/utf8>>}
            )
        end,
        fun(Public) ->
            _pipe@1 = kryptos_ffi:rsa_encrypt(Public, Cek, encrypt_pkcs1v15),
            gleam@result:replace_error(
                _pipe@1,
                {crypto_error, <<"RSA PKCS1v15 encryption failed"/utf8>>}
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 337).
?DOC(false).
-spec validate_decrypted_size(bitstring(), integer()) -> {ok, bitstring()} |
    {error, nil}.
validate_decrypted_size(Decrypted, Expected_size) ->
    case erlang:byte_size(Decrypted) =:= Expected_size of
        true ->
            {ok, Decrypted};

        false ->
            {error, nil}
    end.

-file("src/gose/internal/key_encryption.gleam", 317).
?DOC(false).
-spec unwrap_rsa_pkcs1v15_safe(gose:key(any()), bitstring(), gose:content_alg()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
unwrap_rsa_pkcs1v15_safe(Key, Encrypted_key, Enc) ->
    gleam@result:'try'(
        begin
            _pipe = gose@internal@key_extract:rsa_private_key(
                gose:material(Key)
            ),
            gleam@result:replace_error(
                _pipe,
                {invalid_state,
                    <<"RSA decryption requires an RSA private key"/utf8>>}
            )
        end,
        fun(Private) ->
            Expected_size = gose:content_alg_key_size(Enc),
            Random_cek = gose@internal@content_encryption:generate_cek(Enc),
            Cek = begin
                _pipe@1 = kryptos_ffi:rsa_decrypt(
                    Private,
                    Encrypted_key,
                    encrypt_pkcs1v15
                ),
                _pipe@2 = gleam@result:'try'(
                    _pipe@1,
                    fun(_capture) ->
                        validate_decrypted_size(_capture, Expected_size)
                    end
                ),
                gleam@result:unwrap(_pipe@2, Random_cek)
            end,
            {ok, Cek}
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 347).
?DOC(false).
-spec unwrap_direct(gose:key(any()), gose:content_alg()) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
unwrap_direct(Key, Enc) ->
    gleam@result:'try'(
        begin
            _pipe = gose:material_octet_secret(gose:material(Key)),
            gleam@result:replace_error(
                _pipe,
                {invalid_state,
                    <<"direct encryption requires an octet key"/utf8>>}
            )
        end,
        fun(Secret) ->
            Expected_size = gose:content_alg_key_size(Enc),
            Actual_size = erlang:byte_size(Secret),
            case Actual_size =:= Expected_size of
                true ->
                    {ok, Secret};

                false ->
                    {error,
                        {invalid_state,
                            <<<<<<<<<<"direct encryption requires "/utf8,
                                                (erlang:integer_to_binary(
                                                    Expected_size
                                                ))/binary>>/binary,
                                            "-byte key for "/utf8>>/binary,
                                        (gleam@string:inspect(Enc))/binary>>/binary,
                                    ", got "/utf8>>/binary,
                                (erlang:integer_to_binary(Actual_size))/binary>>}}
            end
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 457).
?DOC(false).
-spec compute_ec_shared_secret(gose:key_material()) -> {ok,
        {bitstring(), ephemeral_public_key()}} |
    {error, gose:gose_error()}.
compute_ec_shared_secret(Mat) ->
    gleam@result:'try'(
        gose:material_ec(Mat),
        fun(Ec_mat) ->
            {Peer_public, Curve@2} = case Ec_mat of
                {ec_private, _, Public, Curve} ->
                    {Public, Curve};

                {ec_public, Public@1, Curve@1} ->
                    {Public@1, Curve@1}
            end,
            {Ephemeral_private, Ephemeral_public} = kryptos_ffi:ec_generate_key_pair(
                Curve@2
            ),
            gleam@result:'try'(
                begin
                    _pipe = kryptos_ffi:ecdh_compute_shared_secret(
                        Ephemeral_private,
                        Peer_public
                    ),
                    gleam@result:replace_error(
                        _pipe,
                        {crypto_error, <<"ECDH key agreement failed"/utf8>>}
                    )
                end,
                fun(Shared) ->
                    _pipe@1 = gose:ec_raw_coordinates(Ephemeral_public, Curve@2),
                    gleam@result:map(
                        _pipe@1,
                        fun(Coords) ->
                            {X, Y} = Coords,
                            {Shared, {ec_ephemeral_key, Curve@2, X, Y}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 477).
?DOC(false).
-spec compute_xdh_shared_secret(gose:key_material()) -> {ok,
        {bitstring(), ephemeral_public_key()}} |
    {error, gose:gose_error()}.
compute_xdh_shared_secret(Mat) ->
    gleam@result:'try'(
        gose:material_xdh(Mat),
        fun(Xdh_mat) ->
            {Peer_public, Curve@2} = case Xdh_mat of
                {xdh_private, _, Public, Curve} ->
                    {Public, Curve};

                {xdh_public, Public@1, Curve@1} ->
                    {Public@1, Curve@1}
            end,
            {Ephemeral_private, Ephemeral_public} = kryptos_ffi:xdh_generate_key_pair(
                Curve@2
            ),
            gleam@result:'try'(
                begin
                    _pipe = kryptos@xdh:compute_shared_secret(
                        Ephemeral_private,
                        Peer_public
                    ),
                    gleam@result:replace_error(
                        _pipe,
                        {crypto_error, <<"XDH key agreement failed"/utf8>>}
                    )
                end,
                fun(Shared) ->
                    X = kryptos_ffi:xdh_public_key_to_bytes(Ephemeral_public),
                    {ok, {Shared, {xdh_ephemeral_key, Curve@2, X}}}
                end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 448).
?DOC(false).
-spec compute_ecdh_shared_secret(gose:key(any())) -> {ok,
        {bitstring(), ephemeral_public_key()}} |
    {error, gose:gose_error()}.
compute_ecdh_shared_secret(Key) ->
    Mat = gose:material(Key),
    _pipe = compute_ec_shared_secret(Mat),
    _pipe@1 = gleam@result:lazy_or(
        _pipe,
        fun() -> compute_xdh_shared_secret(Mat) end
    ),
    gleam@result:replace_error(
        _pipe@1,
        {invalid_state, <<"ECDH-ES requires an EC or XDH key"/utf8>>}
    ).

-file("src/gose/internal/key_encryption.gleam", 494).
?DOC(false).
-spec compute_ecdh_shared_secret_with_epk(
    gose:key(any()),
    ephemeral_public_key()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
compute_ecdh_shared_secret_with_epk(Key, Epk) ->
    Mat = gose:material(Key),
    case Epk of
        {ec_ephemeral_key, Epk_curve, X, Y} ->
            Key_error = {invalid_state,
                <<"key type does not match ephemeral key type"/utf8>>},
            gleam@result:'try'(
                begin
                    _pipe = gose:material_ec(Mat),
                    gleam@result:replace_error(_pipe, Key_error)
                end,
                fun(Ec_mat) -> case Ec_mat of
                        {ec_private, Private, _, Curve} ->
                            gleam@bool:guard(
                                Curve /= Epk_curve,
                                {error,
                                    {invalid_state,
                                        <<"ephemeral key curve mismatch"/utf8>>}},
                                fun() ->
                                    gleam@result:'try'(
                                        gose:ec_public_key_from_raw_coordinates(
                                            Curve,
                                            X,
                                            Y
                                        ),
                                        fun(Epk_public) ->
                                            _pipe@1 = kryptos_ffi:ecdh_compute_shared_secret(
                                                Private,
                                                Epk_public
                                            ),
                                            gleam@result:replace_error(
                                                _pipe@1,
                                                {crypto_error,
                                                    <<"ECDH key agreement failed"/utf8>>}
                                            )
                                        end
                                    )
                                end
                            );

                        {ec_public, _, _} ->
                            {error, Key_error}
                    end end
            );

        {xdh_ephemeral_key, Epk_curve@1, X@1} ->
            Key_error@1 = {invalid_state,
                <<"key type does not match ephemeral key type"/utf8>>},
            gleam@result:'try'(
                begin
                    _pipe@2 = gose:material_xdh(Mat),
                    gleam@result:replace_error(_pipe@2, Key_error@1)
                end,
                fun(Xdh_mat) -> case Xdh_mat of
                        {xdh_private, Private@1, _, Curve@1} ->
                            gleam@bool:guard(
                                Curve@1 /= Epk_curve@1,
                                {error,
                                    {invalid_state,
                                        <<"ephemeral key curve mismatch"/utf8>>}},
                                fun() ->
                                    gleam@result:'try'(
                                        begin
                                            _pipe@3 = kryptos_ffi:xdh_public_key_from_bytes(
                                                Curve@1,
                                                X@1
                                            ),
                                            gleam@result:replace_error(
                                                _pipe@3,
                                                {parse_error,
                                                    <<"invalid ephemeral public key"/utf8>>}
                                            )
                                        end,
                                        fun(Epk_public@1) ->
                                            _pipe@4 = kryptos@xdh:compute_shared_secret(
                                                Private@1,
                                                Epk_public@1
                                            ),
                                            gleam@result:replace_error(
                                                _pipe@4,
                                                {crypto_error,
                                                    <<"XDH key agreement failed"/utf8>>}
                                            )
                                        end
                                    )
                                end
                            );

                        {xdh_public, _, _} ->
                            {error, Key_error@1}
                    end end
            )
    end.

-file("src/gose/internal/key_encryption.gleam", 550).
?DOC(false).
-spec derive_ecdh_key(
    bitstring(),
    binary(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring()),
    integer()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
derive_ecdh_key(Secret, Alg_id, Apu, Apv, Length) ->
    Alg_bits = gleam_stdlib:identity(Alg_id),
    Alg_len = erlang:byte_size(Alg_bits),
    Algorithm_id = <<Alg_len:32, Alg_bits/bitstring>>,
    Apu_bits = gleam@option:unwrap(Apu, <<>>),
    Apu_len = erlang:byte_size(Apu_bits),
    Party_u_info = <<Apu_len:32, Apu_bits/bitstring>>,
    Apv_bits = gleam@option:unwrap(Apv, <<>>),
    Apv_len = erlang:byte_size(Apv_bits),
    Party_v_info = <<Apv_len:32, Apv_bits/bitstring>>,
    Supp_pub_info = <<((Length * 8)):32>>,
    Info = gleam_stdlib:bit_array_concat(
        [Algorithm_id, Party_u_info, Party_v_info, Supp_pub_info]
    ),
    _pipe = kryptos@crypto:concat_kdf(sha256, Secret, Info, Length),
    gleam@result:replace_error(
        _pipe,
        {crypto_error, <<"ECDH key derivation failed"/utf8>>}
    ).

-file("src/gose/internal/key_encryption.gleam", 215).
?DOC(false).
-spec wrap_ecdh_es_chacha20_kw(
    gose:key(any()),
    bitstring(),
    gose:cha_cha20_kw(),
    binary(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, {bitstring(), ephemeral_public_key(), bitstring(), bitstring()}} |
    {error, gose:gose_error()}.
wrap_ecdh_es_chacha20_kw(Key, Cek, Variant, Alg_id, Apu, Apv) ->
    gleam@result:'try'(
        compute_ecdh_shared_secret(Key),
        fun(_use0) ->
            {Shared_secret, Epk} = _use0,
            gleam@result:'try'(
                derive_ecdh_key(Shared_secret, Alg_id, Apu, Apv, 32),
                fun(Kek) ->
                    Nonce_size = gose:chacha20_kw_nonce_size(Variant),
                    Nonce = kryptos_ffi:random_bytes(Nonce_size),
                    gleam@result:'try'(
                        wrap_chacha20_by_variant(Kek, Cek, Nonce, Variant),
                        fun(_use0@1) ->
                            {Encrypted_cek, Kw_tag} = _use0@1,
                            {ok, {Encrypted_cek, Epk, Nonce, Kw_tag}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 243).
?DOC(false).
-spec unwrap_ecdh_es_chacha20_kw(
    gose:key(any()),
    bitstring(),
    gose:cha_cha20_kw(),
    binary(),
    ephemeral_public_key(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring()),
    bitstring(),
    bitstring()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_ecdh_es_chacha20_kw(
    Key,
    Encrypted_key,
    Variant,
    Alg_id,
    Epk,
    Apu,
    Apv,
    Kw_iv,
    Kw_tag
) ->
    gleam@result:'try'(
        compute_ecdh_shared_secret_with_epk(Key, Epk),
        fun(Shared_secret) ->
            gleam@result:'try'(
                derive_ecdh_key(Shared_secret, Alg_id, Apu, Apv, 32),
                fun(Kek) ->
                    unwrap_chacha20_by_variant(
                        Kek,
                        Encrypted_key,
                        Kw_iv,
                        Kw_tag,
                        Variant
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 374).
?DOC(false).
-spec wrap_ecdh_es_direct(
    gose:key(any()),
    gose:content_alg(),
    binary(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, {bitstring(), ephemeral_public_key()}} | {error, gose:gose_error()}.
wrap_ecdh_es_direct(Key, Enc, Alg_id, Apu, Apv) ->
    Key_len = gose:content_alg_key_size(Enc),
    gleam@result:'try'(
        compute_ecdh_shared_secret(Key),
        fun(_use0) ->
            {Shared_secret, Epk} = _use0,
            _pipe = derive_ecdh_key(Shared_secret, Alg_id, Apu, Apv, Key_len),
            gleam@result:map(_pipe, fun(Cek) -> {Cek, Epk} end)
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 387).
?DOC(false).
-spec unwrap_ecdh_es_direct(
    gose:key(any()),
    gose:content_alg(),
    binary(),
    ephemeral_public_key(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_ecdh_es_direct(Key, Enc, Alg_id, Epk, Apu, Apv) ->
    Key_len = gose:content_alg_key_size(Enc),
    gleam@result:'try'(
        compute_ecdh_shared_secret_with_epk(Key, Epk),
        fun(Shared_secret) ->
            derive_ecdh_key(Shared_secret, Alg_id, Apu, Apv, Key_len)
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 400).
?DOC(false).
-spec wrap_ecdh_es_kw(
    gose:key(any()),
    bitstring(),
    gose:aes_key_size(),
    binary(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, {bitstring(), ephemeral_public_key()}} | {error, gose:gose_error()}.
wrap_ecdh_es_kw(Key, Cek, Size, Alg_id, Apu, Apv) ->
    gleam@result:'try'(
        compute_ecdh_shared_secret(Key),
        fun(_use0) ->
            {Shared_secret, Epk} = _use0,
            Kw_key_len = gose:aes_key_size(Size),
            gleam@result:'try'(
                derive_ecdh_key(Shared_secret, Alg_id, Apu, Apv, Kw_key_len),
                fun(Kek) ->
                    gleam@result:'try'(
                        gose@internal@content_encryption:aes_cipher(Size, Kek),
                        fun(Cipher) -> _pipe = kryptos@block:wrap(Cipher, Cek),
                            _pipe@1 = gleam@result:replace_error(
                                _pipe,
                                {crypto_error, <<"AES Key Wrap failed"/utf8>>}
                            ),
                            gleam@result:map(
                                _pipe@1,
                                fun(Wrapped) -> {Wrapped, Epk} end
                            ) end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_encryption.gleam", 424).
?DOC(false).
-spec unwrap_ecdh_es_kw(
    gose:key(any()),
    bitstring(),
    gose:aes_key_size(),
    binary(),
    ephemeral_public_key(),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_ecdh_es_kw(Key, Encrypted_key, Size, Alg_id, Epk, Apu, Apv) ->
    gleam@result:'try'(
        compute_ecdh_shared_secret_with_epk(Key, Epk),
        fun(Shared_secret) ->
            Kw_key_len = gose:aes_key_size(Size),
            gleam@result:'try'(
                derive_ecdh_key(Shared_secret, Alg_id, Apu, Apv, Kw_key_len),
                fun(Kek) ->
                    gleam@result:'try'(
                        gose@internal@content_encryption:aes_cipher(Size, Kek),
                        fun(Cipher) ->
                            _pipe = kryptos@block:unwrap(Cipher, Encrypted_key),
                            gleam@result:replace_error(
                                _pipe,
                                {crypto_error, <<"AES Key Unwrap failed"/utf8>>}
                            )
                        end
                    )
                end
            )
        end
    ).
