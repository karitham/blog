-module(gose@internal@key_helpers).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/internal/key_helpers.gleam").
-export([order_keys_by_kid/2, require_matching_signing_algorithm/2, require_matching_content_algorithm/2, require_non_empty_keys/2, validate_hmac_key_size/3, validate_signing_key_type/2, validate_jwe_key_type/2, validate_key_algorithm_jwe/2, validate_key_algorithm_signing/2, validate_content_key_type/2, validate_key_algorithm_content/2, validate_key_ops/2, validate_key_use/2, validate_key_for_signing_verification/2, validate_key_for_jwe_decryption/2, validate_key_for_jwe_encryption/2, validate_key_for_content_encryption/2, validate_key_for_content_decryption/2]).
-export_type([key_purpose/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(false).

-type key_purpose() :: for_signing |
    for_verification |
    for_encryption |
    for_decryption |
    for_key_agreement.

-file("src/gose/internal/key_helpers.gleam", 13).
?DOC(false).
-spec order_keys_by_kid(list(gose:key(binary())), gleam@option:option(binary())) -> list(gose:key(binary())).
order_keys_by_kid(Keys, Target_kid) ->
    case Target_kid of
        none ->
            Keys;

        {some, Target} ->
            {Matching, Others} = gleam@list:partition(
                Keys,
                fun(Key) -> gose:kid(Key) =:= {ok, Target} end
            ),
            lists:append(Matching, Others)
    end.

-file("src/gose/internal/key_helpers.gleam", 29).
?DOC(false).
-spec require_matching_signing_algorithm(gose:signing_alg(), gose:signing_alg()) -> {ok,
        nil} |
    {error, gose:gose_error()}.
require_matching_signing_algorithm(Expected, Actual) ->
    case Expected =:= Actual of
        true ->
            {ok, nil};

        false ->
            {error,
                {invalid_state,
                    <<<<<<"algorithm mismatch: expected "/utf8,
                                (gleam@string:inspect(Expected))/binary>>/binary,
                            ", got "/utf8>>/binary,
                        (gleam@string:inspect(Actual))/binary>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 45).
?DOC(false).
-spec require_matching_content_algorithm(gose:content_alg(), gose:content_alg()) -> {ok,
        nil} |
    {error, gose:gose_error()}.
require_matching_content_algorithm(Expected, Actual) ->
    case Expected =:= Actual of
        true ->
            {ok, nil};

        false ->
            {error,
                {invalid_state,
                    <<<<<<"algorithm mismatch: expected "/utf8,
                                (gleam@string:inspect(Expected))/binary>>/binary,
                            ", got "/utf8>>/binary,
                        (gleam@string:inspect(Actual))/binary>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 79).
?DOC(false).
-spec require_non_empty_keys(
    list(gose:key(any())),
    fun(() -> {ok, MVQ} | {error, gose:gose_error()})
) -> {ok, MVQ} | {error, gose:gose_error()}.
require_non_empty_keys(Keys, Continue) ->
    case Keys of
        [] ->
            {error, {invalid_state, <<"at least one key required"/utf8>>}};

        _ ->
            Continue()
    end.

-file("src/gose/internal/key_helpers.gleam", 90).
?DOC(false).
-spec validate_hmac_key_size(gose:key(any()), integer(), binary()) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_hmac_key_size(Key, Min_bytes, Alg_name) ->
    case gose:octet_key_size(Key) of
        {ok, Size} when Size < Min_bytes ->
            {error,
                {invalid_state,
                    <<<<<<<<Alg_name/binary, " requires key of at least "/utf8>>/binary,
                                (erlang:integer_to_binary(Min_bytes))/binary>>/binary,
                            " bytes, got "/utf8>>/binary,
                        (erlang:integer_to_binary(Size))/binary>>}};

        {ok, _} ->
            {ok, nil};

        {error, Err} ->
            {error, Err}
    end.

-file("src/gose/internal/key_helpers.gleam", 178).
?DOC(false).
-spec validate_ec_curve(gose:key(any()), kryptos@ec:curve()) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_ec_curve(Key, Expected) ->
    case gose:ec_curve(Key) of
        {ok, Actual} when Actual =:= Expected ->
            {ok, nil};

        {ok, _} ->
            {error,
                {invalid_state,
                    <<"EC key curve does not match algorithm"/utf8>>}};

        {error, _} ->
            {error,
                {invalid_state, <<"could not determine EC key curve"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 189).
?DOC(false).
-spec validate_eddsa_key(gose:key(any())) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_eddsa_key(Key) ->
    case gose:eddsa_curve(Key) of
        {ok, _} ->
            {ok, nil};

        {error, _} ->
            {error,
                {invalid_state,
                    <<"EdDSA algorithm requires an EdDSA key (Ed25519/Ed448), not XDH"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 116).
?DOC(false).
-spec validate_signing_key_type(gose:signing_alg(), gose:key(any())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_signing_key_type(Alg, Key) ->
    Key_type = gose:key_type(Key),
    case {Alg, Key_type} of
        {{mac, {hmac, Hmac_alg}}, oct_key_type} ->
            validate_hmac_key_size(
                Key,
                gose:hmac_alg_key_size(Hmac_alg),
                gleam@string:inspect(Alg)
            );

        {{digital_signature, {rsa_pkcs1, _}}, rsa_key_type} ->
            {ok, nil};

        {{digital_signature, {rsa_pss, _}}, rsa_key_type} ->
            {ok, nil};

        {{digital_signature, {ecdsa, ecdsa_p256}}, ec_key_type} ->
            validate_ec_curve(Key, p256);

        {{digital_signature, {ecdsa, ecdsa_p384}}, ec_key_type} ->
            validate_ec_curve(Key, p384);

        {{digital_signature, {ecdsa, ecdsa_p521}}, ec_key_type} ->
            validate_ec_curve(Key, p521);

        {{digital_signature, {ecdsa, ecdsa_secp256k1}}, ec_key_type} ->
            validate_ec_curve(Key, secp256k1);

        {{digital_signature, eddsa}, okp_key_type} ->
            validate_eddsa_key(Key);

        {_, _} ->
            {error,
                {invalid_state,
                    <<<<"algorithm "/utf8, (gleam@string:inspect(Alg))/binary>>/binary,
                        " incompatible with key type"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 199).
?DOC(false).
-spec validate_xdh_key(gose:key(any())) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_xdh_key(Key) ->
    case gose:xdh_curve(Key) of
        {ok, _} ->
            {ok, nil};

        {error, _} ->
            {error,
                {invalid_state,
                    <<"ECDH-ES algorithm requires an EC or XDH key (X25519/X448), not EdDSA"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 152).
?DOC(false).
-spec validate_jwe_key_type(gose:key_encryption_alg(), gose:key(any())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_jwe_key_type(Alg, Key) ->
    Key_type = gose:key_type(Key),
    case {Alg, Key_type} of
        {direct, oct_key_type} ->
            {ok, nil};

        {{aes_key_wrap, _, _}, oct_key_type} ->
            {ok, nil};

        {{cha_cha20_key_wrap, _}, oct_key_type} ->
            {ok, nil};

        {{rsa_encryption, _}, rsa_key_type} ->
            {ok, nil};

        {{ecdh_es, _}, ec_key_type} ->
            {ok, nil};

        {{ecdh_es, _}, okp_key_type} ->
            validate_xdh_key(Key);

        {{pbes2, _}, _} ->
            {error,
                {invalid_state,
                    <<"use password_decryptor for PBES2 algorithms"/utf8>>}};

        {_, _} ->
            {error,
                {invalid_state,
                    <<<<"algorithm "/utf8, (gleam@string:inspect(Alg))/binary>>/binary,
                        " incompatible with key type"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 213).
?DOC(false).
-spec validate_key_algorithm_jwe(gose:key(any()), gose:key_encryption_alg()) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_key_algorithm_jwe(Key, Expected) ->
    case gose:alg(Key) of
        {error, nil} ->
            {ok, nil};

        {ok, {key_encryption_alg, Alg}} when Alg =:= Expected ->
            {ok, nil};

        {ok, {key_encryption_alg, Alg@1}} ->
            {error,
                {invalid_state,
                    <<<<<<"key algorithm mismatch: key has "/utf8,
                                (gleam@string:inspect(Alg@1))/binary>>/binary,
                            ", expected "/utf8>>/binary,
                        (gleam@string:inspect(Expected))/binary>>}};

        {ok, {signing_alg, _}} ->
            {error,
                {invalid_state,
                    <<"key algorithm mismatch: key has JWS algorithm, expected JWE algorithm"/utf8>>}};

        {ok, {content_alg, _}} ->
            {error,
                {invalid_state,
                    <<"key algorithm mismatch: key has content algorithm, expected JWE algorithm"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 242).
?DOC(false).
-spec validate_key_algorithm_signing(gose:key(any()), gose:signing_alg()) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_key_algorithm_signing(Key, Expected) ->
    case gose:alg(Key) of
        {error, nil} ->
            {ok, nil};

        {ok, {signing_alg, Alg}} when Alg =:= Expected ->
            {ok, nil};

        {ok, {signing_alg, Alg@1}} ->
            {error,
                {invalid_state,
                    <<<<<<"key algorithm mismatch: key has "/utf8,
                                (gleam@string:inspect(Alg@1))/binary>>/binary,
                            ", expected "/utf8>>/binary,
                        (gleam@string:inspect(Expected))/binary>>}};

        {ok, {key_encryption_alg, _}} ->
            {error,
                {invalid_state,
                    <<"key algorithm mismatch: key has JWE algorithm, expected JWS algorithm"/utf8>>}};

        {ok, {content_alg, _}} ->
            {error,
                {invalid_state,
                    <<"key algorithm mismatch: key has content algorithm, expected JWS algorithm"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 308).
?DOC(false).
-spec jwe_key_ops_purpose(gose:key_encryption_alg(), key_purpose()) -> key_purpose().
jwe_key_ops_purpose(Alg, Base_purpose) ->
    case Alg of
        {ecdh_es, _} ->
            for_key_agreement;

        _ ->
            Base_purpose
    end.

-file("src/gose/internal/key_helpers.gleam", 321).
?DOC(false).
-spec validate_content_key_type(gose:content_alg(), gose:key(any())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_content_key_type(Alg, Key) ->
    case gose:key_type(Key) of
        oct_key_type ->
            {ok, nil};

        _ ->
            {error,
                {invalid_state,
                    <<<<"algorithm "/utf8, (gleam@string:inspect(Alg))/binary>>/binary,
                        " incompatible with key type"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 338).
?DOC(false).
-spec validate_key_algorithm_content(gose:key(any()), gose:content_alg()) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_key_algorithm_content(Key, Expected) ->
    case gose:alg(Key) of
        {error, nil} ->
            {ok, nil};

        {ok, {content_alg, Alg}} when Alg =:= Expected ->
            {ok, nil};

        {ok, {content_alg, Alg@1}} ->
            {error,
                {invalid_state,
                    <<<<<<"key algorithm mismatch: key has "/utf8,
                                (gleam@string:inspect(Alg@1))/binary>>/binary,
                            ", expected "/utf8>>/binary,
                        (gleam@string:inspect(Expected))/binary>>}};

        {ok, {signing_alg, _}} ->
            {error,
                {invalid_state,
                    <<"key algorithm mismatch: key has signing algorithm, expected content algorithm"/utf8>>}};

        {ok, {key_encryption_alg, _}} ->
            {error,
                {invalid_state,
                    <<"key algorithm mismatch: key has key encryption algorithm, expected content algorithm"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 401).
?DOC(false).
-spec validate_ops_for_purpose(list(gose:key_op()), key_purpose()) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_ops_for_purpose(Ops, Purpose) ->
    {Required_ops, Error_msg} = case Purpose of
        for_signing ->
            {[sign], <<"key_ops does not include 'sign' operation"/utf8>>};

        for_verification ->
            {[verify], <<"key_ops does not include 'verify' operation"/utf8>>};

        for_encryption ->
            {[encrypt, wrap_key],
                <<"key_ops does not include 'encrypt' or 'wrapKey' operation"/utf8>>};

        for_decryption ->
            {[decrypt, unwrap_key],
                <<"key_ops does not include 'decrypt' or 'unwrapKey' operation"/utf8>>};

        for_key_agreement ->
            {[derive_key, derive_bits],
                <<"key_ops does not include 'deriveKey' or 'deriveBits' operation"/utf8>>}
    end,
    case gleam@list:any(
        Required_ops,
        fun(_capture) -> gleam@list:contains(Ops, _capture) end
    ) of
        true ->
            {ok, nil};

        false ->
            {error, {invalid_state, Error_msg}}
    end.

-file("src/gose/internal/key_helpers.gleam", 391).
?DOC(false).
-spec validate_key_ops(gose:key(any()), key_purpose()) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_key_ops(Key, Purpose) ->
    case gose:key_ops(Key) of
        {error, nil} ->
            {ok, nil};

        {ok, Ops} ->
            validate_ops_for_purpose(Ops, Purpose)
    end.

-file("src/gose/internal/key_helpers.gleam", 443).
?DOC(false).
-spec validate_use_value(gose:key_use(), key_purpose()) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_use_value(Use_value, Purpose) ->
    case {Use_value, Purpose} of
        {signing, for_signing} ->
            {ok, nil};

        {signing, for_verification} ->
            {ok, nil};

        {encrypting, for_encryption} ->
            {ok, nil};

        {encrypting, for_decryption} ->
            {ok, nil};

        {encrypting, for_signing} ->
            {error,
                {invalid_state,
                    <<"key use is 'enc', cannot be used for signing"/utf8>>}};

        {encrypting, for_verification} ->
            {error,
                {invalid_state,
                    <<"key use is 'enc', cannot be used for verification"/utf8>>}};

        {encrypting, for_key_agreement} ->
            {ok, nil};

        {signing, for_encryption} ->
            {error,
                {invalid_state,
                    <<"key use is 'sig', cannot be used for encryption"/utf8>>}};

        {signing, for_decryption} ->
            {error,
                {invalid_state,
                    <<"key use is 'sig', cannot be used for decryption"/utf8>>}};

        {signing, for_key_agreement} ->
            {error,
                {invalid_state,
                    <<"key use is 'sig', cannot be used for key agreement"/utf8>>}}
    end.

-file("src/gose/internal/key_helpers.gleam", 433).
?DOC(false).
-spec validate_key_use(gose:key(any()), key_purpose()) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_key_use(Key, Purpose) ->
    case gose:key_use(Key) of
        {error, nil} ->
            {ok, nil};

        {ok, Use_value} ->
            validate_use_value(Use_value, Purpose)
    end.

-file("src/gose/internal/key_helpers.gleam", 270).
?DOC(false).
-spec validate_key_for_signing_verification(gose:signing_alg(), gose:key(any())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_key_for_signing_verification(Alg, Key) ->
    gleam@result:'try'(
        validate_signing_key_type(Alg, Key),
        fun(_) ->
            gleam@result:'try'(
                validate_key_use(Key, for_verification),
                fun(_) ->
                    gleam@result:'try'(
                        validate_key_ops(Key, for_verification),
                        fun(_) -> validate_key_algorithm_signing(Key, Alg) end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_helpers.gleam", 283).
?DOC(false).
-spec validate_key_for_jwe_decryption(
    gose:key_encryption_alg(),
    gose:key(any())
) -> {ok, nil} | {error, gose:gose_error()}.
validate_key_for_jwe_decryption(Alg, Key) ->
    Ops_purpose = jwe_key_ops_purpose(Alg, for_decryption),
    gleam@result:'try'(
        validate_jwe_key_type(Alg, Key),
        fun(_) ->
            gleam@result:'try'(
                validate_key_use(Key, Ops_purpose),
                fun(_) ->
                    gleam@result:'try'(
                        validate_key_ops(Key, Ops_purpose),
                        fun(_) -> validate_key_algorithm_jwe(Key, Alg) end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_helpers.gleam", 297).
?DOC(false).
-spec validate_key_for_jwe_encryption(
    gose:key_encryption_alg(),
    gose:key(any())
) -> {ok, nil} | {error, gose:gose_error()}.
validate_key_for_jwe_encryption(Alg, Key) ->
    Ops_purpose = jwe_key_ops_purpose(Alg, for_encryption),
    gleam@result:'try'(
        validate_jwe_key_type(Alg, Key),
        fun(_) ->
            gleam@result:'try'(
                validate_key_use(Key, Ops_purpose),
                fun(_) ->
                    gleam@result:'try'(
                        validate_key_ops(Key, Ops_purpose),
                        fun(_) -> validate_key_algorithm_jwe(Key, Alg) end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_helpers.gleam", 366).
?DOC(false).
-spec validate_key_for_content_encryption(gose:content_alg(), gose:key(any())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_key_for_content_encryption(Alg, Key) ->
    gleam@result:'try'(
        validate_content_key_type(Alg, Key),
        fun(_) ->
            gleam@result:'try'(
                validate_key_use(Key, for_encryption),
                fun(_) ->
                    gleam@result:'try'(
                        validate_key_ops(Key, for_encryption),
                        fun(_) -> validate_key_algorithm_content(Key, Alg) end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/key_helpers.gleam", 379).
?DOC(false).
-spec validate_key_for_content_decryption(gose:content_alg(), gose:key(any())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_key_for_content_decryption(Alg, Key) ->
    gleam@result:'try'(
        validate_content_key_type(Alg, Key),
        fun(_) ->
            gleam@result:'try'(
                validate_key_use(Key, for_decryption),
                fun(_) ->
                    gleam@result:'try'(
                        validate_key_ops(Key, for_decryption),
                        fun(_) -> validate_key_algorithm_content(Key, Alg) end
                    )
                end
            )
        end
    ).
