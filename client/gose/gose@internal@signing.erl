-module(gose@internal@signing).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/internal/signing.gleam").
-export([compute_signature/3, verify_signature/4]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(false).

-file("src/gose/internal/signing.gleam", 126).
?DOC(false).
-spec require_valid(boolean()) -> {ok, nil} | {error, gose:gose_error()}.
require_valid(Valid) ->
    gleam@bool:guard(
        not Valid,
        {error, verification_failed},
        fun() -> {ok, nil} end
    ).

-file("src/gose/internal/signing.gleam", 150).
?DOC(false).
-spec hmac_verify(
    kryptos@hash:hash_algorithm(),
    bitstring(),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
hmac_verify(Algorithm, Key, Message, Expected) ->
    case kryptos@hmac:verify(Algorithm, Key, Message, Expected) of
        {ok, true} ->
            {ok, nil};

        {ok, false} ->
            {error, verification_failed};

        {error, _} ->
            {error, {crypto_error, <<"HMAC verification failed"/utf8>>}}
    end.

-file("src/gose/internal/signing.gleam", 163).
?DOC(false).
-spec resolve_ecdsa_params(gose:ecdsa_alg()) -> {kryptos@hash:hash_algorithm(),
    kryptos@ec:curve()}.
resolve_ecdsa_params(Alg) ->
    case Alg of
        ecdsa_p256 ->
            {sha256, p256};

        ecdsa_p384 ->
            {sha384, p384};

        ecdsa_p521 ->
            {sha512, p521};

        ecdsa_secp256k1 ->
            {sha256, secp256k1}
    end.

-file("src/gose/internal/signing.gleam", 172).
?DOC(false).
-spec resolve_hmac_params(gose:hmac_alg()) -> {kryptos@hash:hash_algorithm(),
    integer(),
    binary()}.
resolve_hmac_params(Alg) ->
    case Alg of
        hmac_sha256 ->
            {sha256, 32, <<"HS256"/utf8>>};

        hmac_sha384 ->
            {sha384, 48, <<"HS384"/utf8>>};

        hmac_sha512 ->
            {sha512, 64, <<"HS512"/utf8>>}
    end.

-file("src/gose/internal/signing.gleam", 131).
?DOC(false).
-spec extract_validated_hmac_secret(gose:key(any()), gose:hmac_alg()) -> {ok,
        {kryptos@hash:hash_algorithm(), bitstring()}} |
    {error, gose:gose_error()}.
extract_validated_hmac_secret(Key, Hmac_alg) ->
    gleam@result:'try'(
        begin
            _pipe = gose:material_octet_secret(gose:material(Key)),
            gleam@result:replace_error(
                _pipe,
                {invalid_state, <<"HMAC algorithms require an octet key"/utf8>>}
            )
        end,
        fun(Secret) ->
            {Hash_alg, Min_size, Alg_name} = resolve_hmac_params(Hmac_alg),
            gleam@result:'try'(
                gose@internal@key_helpers:validate_hmac_key_size(
                    Key,
                    Min_size,
                    Alg_name
                ),
                fun(_) -> {ok, {Hash_alg, Secret}} end
            )
        end
    ).

-file("src/gose/internal/signing.gleam", 180).
?DOC(false).
-spec resolve_rsa_pkcs1_params(gose:rsa_pkcs1_alg()) -> {kryptos@hash:hash_algorithm(),
    kryptos@rsa:sign_padding()}.
resolve_rsa_pkcs1_params(Alg) ->
    case Alg of
        rsa_pkcs1_sha256 ->
            {sha256, pkcs1v15};

        rsa_pkcs1_sha384 ->
            {sha384, pkcs1v15};

        rsa_pkcs1_sha512 ->
            {sha512, pkcs1v15}
    end.

-file("src/gose/internal/signing.gleam", 190).
?DOC(false).
-spec resolve_rsa_pss_params(gose:rsa_pss_alg()) -> {kryptos@hash:hash_algorithm(),
    kryptos@rsa:sign_padding()}.
resolve_rsa_pss_params(Alg) ->
    case Alg of
        rsa_pss_sha256 ->
            {sha256, {pss, salt_length_hash_len}};

        rsa_pss_sha384 ->
            {sha384, {pss, salt_length_hash_len}};

        rsa_pss_sha512 ->
            {sha512, {pss, salt_length_hash_len}}
    end.

-file("src/gose/internal/signing.gleam", 200).
?DOC(false).
-spec extract_ec_private_key(gose:key_material(), kryptos@ec:curve(), binary()) -> {ok,
        kryptos@ec:private_key()} |
    {error, gose:gose_error()}.
extract_ec_private_key(Material, Expected_curve, Alg_name) ->
    Curve_error = {invalid_state,
        <<<<<<Alg_name/binary, " requires an EC private key with "/utf8>>/binary,
                (gose@internal@utils:ec_curve_to_string(Expected_curve))/binary>>/binary,
            " curve"/utf8>>},
    gleam@result:'try'(
        begin
            _pipe = gose:material_ec(Material),
            gleam@result:replace_error(_pipe, Curve_error)
        end,
        fun(Ec) -> case Ec of
                {ec_private, Private, _, Curve} ->
                    gleam@bool:guard(
                        Curve /= Expected_curve,
                        {error, Curve_error},
                        fun() -> {ok, Private} end
                    );

                {ec_public, _, _} ->
                    {error, Curve_error}
            end end
    ).

-file("src/gose/internal/signing.gleam", 227).
?DOC(false).
-spec extract_ec_public_key(gose:key_material(), kryptos@ec:curve(), binary()) -> {ok,
        kryptos@ec:public_key()} |
    {error, gose:gose_error()}.
extract_ec_public_key(Material, Expected_curve, Alg_name) ->
    Curve_error = {invalid_state,
        <<<<<<Alg_name/binary, " requires an EC key with "/utf8>>/binary,
                (gose@internal@utils:ec_curve_to_string(Expected_curve))/binary>>/binary,
            " curve"/utf8>>},
    gleam@result:'try'(
        begin
            _pipe = gose:material_ec(Material),
            gleam@result:replace_error(_pipe, Curve_error)
        end,
        fun(Ec) ->
            {Public@2, Curve@2} = case Ec of
                {ec_private, _, Public, Curve} ->
                    {Public, Curve};

                {ec_public, Public@1, Curve@1} ->
                    {Public@1, Curve@1}
            end,
            gleam@bool:guard(
                Curve@2 /= Expected_curve,
                {error, Curve_error},
                fun() -> {ok, Public@2} end
            )
        end
    ).

-file("src/gose/internal/signing.gleam", 250).
?DOC(false).
-spec extract_eddsa_private_key(gose:key_material()) -> {ok,
        kryptos@eddsa:private_key()} |
    {error, gose:gose_error()}.
extract_eddsa_private_key(Material) ->
    Error = {invalid_state, <<"EdDSA requires an EdDSA private key"/utf8>>},
    gleam@result:'try'(
        begin
            _pipe = gose:material_eddsa(Material),
            gleam@result:replace_error(_pipe, Error)
        end,
        fun(Eddsa) -> case Eddsa of
                {eddsa_private, Private, _, _} ->
                    {ok, Private};

                {eddsa_public, _, _} ->
                    {error, Error}
            end end
    ).

-file("src/gose/internal/signing.gleam", 16).
?DOC(false).
-spec compute_signature(gose:signing_alg(), gose:key(any()), bitstring()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
compute_signature(Alg, Key, Message) ->
    Mat = gose:material(Key),
    case Alg of
        {mac, {hmac, Hmac_alg}} ->
            gleam@result:'try'(
                extract_validated_hmac_secret(Key, Hmac_alg),
                fun(_use0) ->
                    {Hash_alg, Secret} = _use0,
                    _pipe = kryptos@crypto:hmac(Hash_alg, Secret, Message),
                    gleam@result:replace_error(
                        _pipe,
                        {crypto_error, <<"HMAC computation failed"/utf8>>}
                    )
                end
            );

        {digital_signature, {rsa_pkcs1, Pkcs1_alg}} ->
            gleam@result:'try'(
                begin
                    _pipe@1 = gose@internal@key_extract:rsa_private_key(Mat),
                    gleam@result:replace_error(
                        _pipe@1,
                        {invalid_state,
                            <<"RSA algorithms require an RSA private key"/utf8>>}
                    )
                end,
                fun(Private) ->
                    {Hash_alg@1, Padding} = resolve_rsa_pkcs1_params(Pkcs1_alg),
                    {ok,
                        kryptos_ffi:rsa_sign(
                            Private,
                            Message,
                            Hash_alg@1,
                            Padding
                        )}
                end
            );

        {digital_signature, {rsa_pss, Pss_alg}} ->
            gleam@result:'try'(
                begin
                    _pipe@2 = gose@internal@key_extract:rsa_private_key(Mat),
                    gleam@result:replace_error(
                        _pipe@2,
                        {invalid_state,
                            <<"RSA algorithms require an RSA private key"/utf8>>}
                    )
                end,
                fun(Private@1) ->
                    {Hash_alg@2, Padding@1} = resolve_rsa_pss_params(Pss_alg),
                    {ok,
                        kryptos_ffi:rsa_sign(
                            Private@1,
                            Message,
                            Hash_alg@2,
                            Padding@1
                        )}
                end
            );

        {digital_signature, {ecdsa, Ecdsa_alg}} ->
            {Hash_alg@3, Expected_curve} = resolve_ecdsa_params(Ecdsa_alg),
            gleam@result:'try'(
                extract_ec_private_key(
                    Mat,
                    Expected_curve,
                    gleam@string:inspect(Alg)
                ),
                fun(Private@2) ->
                    {ok, kryptos@ecdsa:sign_rs(Private@2, Message, Hash_alg@3)}
                end
            );

        {digital_signature, eddsa} ->
            gleam@result:'try'(
                extract_eddsa_private_key(Mat),
                fun(Private@3) ->
                    {ok, kryptos_ffi:eddsa_sign(Private@3, Message)}
                end
            )
    end.

-file("src/gose/internal/signing.gleam", 263).
?DOC(false).
-spec extract_eddsa_public_key(gose:key_material()) -> {ok,
        kryptos@eddsa:public_key()} |
    {error, gose:gose_error()}.
extract_eddsa_public_key(Material) ->
    gleam@result:'try'(
        begin
            _pipe = gose:material_eddsa(Material),
            gleam@result:replace_error(
                _pipe,
                {invalid_state, <<"EdDSA requires an EdDSA key"/utf8>>}
            )
        end,
        fun(Eddsa) -> case Eddsa of
                {eddsa_private, _, Public, _} ->
                    {ok, Public};

                {eddsa_public, Public@1, _} ->
                    {ok, Public@1}
            end end
    ).

-file("src/gose/internal/signing.gleam", 71).
?DOC(false).
-spec verify_signature(
    gose:signing_alg(),
    gose:key(any()),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
verify_signature(Alg, Key, Message, Signature) ->
    Mat = gose:material(Key),
    case Alg of
        {mac, {hmac, Hmac_alg}} ->
            gleam@result:'try'(
                extract_validated_hmac_secret(Key, Hmac_alg),
                fun(_use0) ->
                    {Hash_alg, Secret} = _use0,
                    hmac_verify(Hash_alg, Secret, Message, Signature)
                end
            );

        {digital_signature, {rsa_pkcs1, Pkcs1_alg}} ->
            gleam@result:'try'(
                begin
                    _pipe = gose@internal@key_extract:rsa_public_key(Mat),
                    gleam@result:replace_error(
                        _pipe,
                        {invalid_state,
                            <<"RSA algorithms require an RSA key"/utf8>>}
                    )
                end,
                fun(Public) ->
                    {Hash_alg@1, Padding} = resolve_rsa_pkcs1_params(Pkcs1_alg),
                    require_valid(
                        kryptos_ffi:rsa_verify(
                            Public,
                            Message,
                            Signature,
                            Hash_alg@1,
                            Padding
                        )
                    )
                end
            );

        {digital_signature, {rsa_pss, Pss_alg}} ->
            gleam@result:'try'(
                begin
                    _pipe@1 = gose@internal@key_extract:rsa_public_key(Mat),
                    gleam@result:replace_error(
                        _pipe@1,
                        {invalid_state,
                            <<"RSA algorithms require an RSA key"/utf8>>}
                    )
                end,
                fun(Public@1) ->
                    {Hash_alg@2, Padding@1} = resolve_rsa_pss_params(Pss_alg),
                    require_valid(
                        kryptos_ffi:rsa_verify(
                            Public@1,
                            Message,
                            Signature,
                            Hash_alg@2,
                            Padding@1
                        )
                    )
                end
            );

        {digital_signature, {ecdsa, Ecdsa_alg}} ->
            {Hash_alg@3, Expected_curve} = resolve_ecdsa_params(Ecdsa_alg),
            gleam@result:'try'(
                extract_ec_public_key(
                    Mat,
                    Expected_curve,
                    gleam@string:inspect(Alg)
                ),
                fun(Public@2) ->
                    require_valid(
                        kryptos@ecdsa:verify_rs(
                            Public@2,
                            Message,
                            Signature,
                            Hash_alg@3
                        )
                    )
                end
            );

        {digital_signature, eddsa} ->
            gleam@result:'try'(
                extract_eddsa_public_key(Mat),
                fun(Public@3) ->
                    require_valid(
                        kryptos_ffi:eddsa_verify(Public@3, Message, Signature)
                    )
                end
            )
    end.
