-module(gose@jose).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose.gleam").
-export([signing_alg_to_string/1, signing_alg_from_string/1, key_encryption_alg_to_string/1, key_encryption_alg_from_string/1, content_alg_to_string/1, content_alg_from_string/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " JOSE algorithm string mapping ([RFC 7518](https://www.rfc-editor.org/rfc/rfc7518.html)).\n"
    "\n"
    " Maps between `gose` algorithm types and JOSE string identifiers.\n"
).

-file("src/gose/jose.gleam", 8).
?DOC(" Convert a signing algorithm to its JOSE string representation.\n").
-spec signing_alg_to_string(gose:signing_alg()) -> binary().
signing_alg_to_string(Alg) ->
    case Alg of
        {mac, {hmac, hmac_sha256}} ->
            <<"HS256"/utf8>>;

        {mac, {hmac, hmac_sha384}} ->
            <<"HS384"/utf8>>;

        {mac, {hmac, hmac_sha512}} ->
            <<"HS512"/utf8>>;

        {digital_signature, {rsa_pkcs1, rsa_pkcs1_sha256}} ->
            <<"RS256"/utf8>>;

        {digital_signature, {rsa_pkcs1, rsa_pkcs1_sha384}} ->
            <<"RS384"/utf8>>;

        {digital_signature, {rsa_pkcs1, rsa_pkcs1_sha512}} ->
            <<"RS512"/utf8>>;

        {digital_signature, {rsa_pss, rsa_pss_sha256}} ->
            <<"PS256"/utf8>>;

        {digital_signature, {rsa_pss, rsa_pss_sha384}} ->
            <<"PS384"/utf8>>;

        {digital_signature, {rsa_pss, rsa_pss_sha512}} ->
            <<"PS512"/utf8>>;

        {digital_signature, {ecdsa, ecdsa_p256}} ->
            <<"ES256"/utf8>>;

        {digital_signature, {ecdsa, ecdsa_p384}} ->
            <<"ES384"/utf8>>;

        {digital_signature, {ecdsa, ecdsa_p521}} ->
            <<"ES512"/utf8>>;

        {digital_signature, {ecdsa, ecdsa_secp256k1}} ->
            <<"ES256K"/utf8>>;

        {digital_signature, eddsa} ->
            <<"EdDSA"/utf8>>
    end.

-file("src/gose/jose.gleam", 28).
?DOC(" Parse a signing algorithm from its JOSE string representation.\n").
-spec signing_alg_from_string(binary()) -> {ok, gose:signing_alg()} |
    {error, gose:gose_error()}.
signing_alg_from_string(Alg) ->
    case Alg of
        <<"HS256"/utf8>> ->
            {ok, {mac, {hmac, hmac_sha256}}};

        <<"HS384"/utf8>> ->
            {ok, {mac, {hmac, hmac_sha384}}};

        <<"HS512"/utf8>> ->
            {ok, {mac, {hmac, hmac_sha512}}};

        <<"RS256"/utf8>> ->
            {ok, {digital_signature, {rsa_pkcs1, rsa_pkcs1_sha256}}};

        <<"RS384"/utf8>> ->
            {ok, {digital_signature, {rsa_pkcs1, rsa_pkcs1_sha384}}};

        <<"RS512"/utf8>> ->
            {ok, {digital_signature, {rsa_pkcs1, rsa_pkcs1_sha512}}};

        <<"PS256"/utf8>> ->
            {ok, {digital_signature, {rsa_pss, rsa_pss_sha256}}};

        <<"PS384"/utf8>> ->
            {ok, {digital_signature, {rsa_pss, rsa_pss_sha384}}};

        <<"PS512"/utf8>> ->
            {ok, {digital_signature, {rsa_pss, rsa_pss_sha512}}};

        <<"ES256"/utf8>> ->
            {ok, {digital_signature, {ecdsa, ecdsa_p256}}};

        <<"ES384"/utf8>> ->
            {ok, {digital_signature, {ecdsa, ecdsa_p384}}};

        <<"ES512"/utf8>> ->
            {ok, {digital_signature, {ecdsa, ecdsa_p521}}};

        <<"ES256K"/utf8>> ->
            {ok, {digital_signature, {ecdsa, ecdsa_secp256k1}}};

        <<"EdDSA"/utf8>> ->
            {ok, {digital_signature, eddsa}};

        _ ->
            {error,
                {parse_error, <<"unknown JWS algorithm: "/utf8, Alg/binary>>}}
    end.

-file("src/gose/jose.gleam", 51).
?DOC(" Convert a key encryption algorithm to its JOSE string representation.\n").
-spec key_encryption_alg_to_string(gose:key_encryption_alg()) -> binary().
key_encryption_alg_to_string(Alg) ->
    case Alg of
        direct ->
            <<"dir"/utf8>>;

        {aes_key_wrap, aes_kw, aes128} ->
            <<"A128KW"/utf8>>;

        {aes_key_wrap, aes_kw, aes192} ->
            <<"A192KW"/utf8>>;

        {aes_key_wrap, aes_kw, aes256} ->
            <<"A256KW"/utf8>>;

        {aes_key_wrap, aes_gcm_kw, aes128} ->
            <<"A128GCMKW"/utf8>>;

        {aes_key_wrap, aes_gcm_kw, aes192} ->
            <<"A192GCMKW"/utf8>>;

        {aes_key_wrap, aes_gcm_kw, aes256} ->
            <<"A256GCMKW"/utf8>>;

        {rsa_encryption, rsa_pkcs1v15} ->
            <<"RSA1_5"/utf8>>;

        {rsa_encryption, rsa_oaep_sha1} ->
            <<"RSA-OAEP"/utf8>>;

        {rsa_encryption, rsa_oaep_sha256} ->
            <<"RSA-OAEP-256"/utf8>>;

        {ecdh_es, ecdh_es_direct} ->
            <<"ECDH-ES"/utf8>>;

        {ecdh_es, {ecdh_es_aes_kw, aes128}} ->
            <<"ECDH-ES+A128KW"/utf8>>;

        {ecdh_es, {ecdh_es_aes_kw, aes192}} ->
            <<"ECDH-ES+A192KW"/utf8>>;

        {ecdh_es, {ecdh_es_aes_kw, aes256}} ->
            <<"ECDH-ES+A256KW"/utf8>>;

        {ecdh_es, {ecdh_es_cha_cha20_kw, c20_p_kw}} ->
            <<"ECDH-ES+C20PKW"/utf8>>;

        {ecdh_es, {ecdh_es_cha_cha20_kw, x_c20_p_kw}} ->
            <<"ECDH-ES+XC20PKW"/utf8>>;

        {cha_cha20_key_wrap, c20_p_kw} ->
            <<"C20PKW"/utf8>>;

        {cha_cha20_key_wrap, x_c20_p_kw} ->
            <<"XC20PKW"/utf8>>;

        {pbes2, pbes2_sha256_aes128_kw} ->
            <<"PBES2-HS256+A128KW"/utf8>>;

        {pbes2, pbes2_sha384_aes192_kw} ->
            <<"PBES2-HS384+A192KW"/utf8>>;

        {pbes2, pbes2_sha512_aes256_kw} ->
            <<"PBES2-HS512+A256KW"/utf8>>
    end.

-file("src/gose/jose.gleam", 78).
?DOC(" Parse a key encryption algorithm from its JOSE string representation.\n").
-spec key_encryption_alg_from_string(binary()) -> {ok,
        gose:key_encryption_alg()} |
    {error, gose:gose_error()}.
key_encryption_alg_from_string(Alg) ->
    case Alg of
        <<"dir"/utf8>> ->
            {ok, direct};

        <<"A128KW"/utf8>> ->
            {ok, {aes_key_wrap, aes_kw, aes128}};

        <<"A192KW"/utf8>> ->
            {ok, {aes_key_wrap, aes_kw, aes192}};

        <<"A256KW"/utf8>> ->
            {ok, {aes_key_wrap, aes_kw, aes256}};

        <<"A128GCMKW"/utf8>> ->
            {ok, {aes_key_wrap, aes_gcm_kw, aes128}};

        <<"A192GCMKW"/utf8>> ->
            {ok, {aes_key_wrap, aes_gcm_kw, aes192}};

        <<"A256GCMKW"/utf8>> ->
            {ok, {aes_key_wrap, aes_gcm_kw, aes256}};

        <<"RSA1_5"/utf8>> ->
            {ok, {rsa_encryption, rsa_pkcs1v15}};

        <<"RSA-OAEP"/utf8>> ->
            {ok, {rsa_encryption, rsa_oaep_sha1}};

        <<"RSA-OAEP-256"/utf8>> ->
            {ok, {rsa_encryption, rsa_oaep_sha256}};

        <<"ECDH-ES"/utf8>> ->
            {ok, {ecdh_es, ecdh_es_direct}};

        <<"ECDH-ES+A128KW"/utf8>> ->
            {ok, {ecdh_es, {ecdh_es_aes_kw, aes128}}};

        <<"ECDH-ES+A192KW"/utf8>> ->
            {ok, {ecdh_es, {ecdh_es_aes_kw, aes192}}};

        <<"ECDH-ES+A256KW"/utf8>> ->
            {ok, {ecdh_es, {ecdh_es_aes_kw, aes256}}};

        <<"ECDH-ES+C20PKW"/utf8>> ->
            {ok, {ecdh_es, {ecdh_es_cha_cha20_kw, c20_p_kw}}};

        <<"ECDH-ES+XC20PKW"/utf8>> ->
            {ok, {ecdh_es, {ecdh_es_cha_cha20_kw, x_c20_p_kw}}};

        <<"C20PKW"/utf8>> ->
            {ok, {cha_cha20_key_wrap, c20_p_kw}};

        <<"XC20PKW"/utf8>> ->
            {ok, {cha_cha20_key_wrap, x_c20_p_kw}};

        <<"PBES2-HS256+A128KW"/utf8>> ->
            {ok, {pbes2, pbes2_sha256_aes128_kw}};

        <<"PBES2-HS384+A192KW"/utf8>> ->
            {ok, {pbes2, pbes2_sha384_aes192_kw}};

        <<"PBES2-HS512+A256KW"/utf8>> ->
            {ok, {pbes2, pbes2_sha512_aes256_kw}};

        _ ->
            {error,
                {parse_error, <<"unknown JWE algorithm: "/utf8, Alg/binary>>}}
    end.

-file("src/gose/jose.gleam", 108).
?DOC(" Convert a content encryption algorithm to its JOSE string representation.\n").
-spec content_alg_to_string(gose:content_alg()) -> binary().
content_alg_to_string(Alg) ->
    case Alg of
        {aes_gcm, aes128} ->
            <<"A128GCM"/utf8>>;

        {aes_gcm, aes192} ->
            <<"A192GCM"/utf8>>;

        {aes_gcm, aes256} ->
            <<"A256GCM"/utf8>>;

        {aes_cbc_hmac, aes128} ->
            <<"A128CBC-HS256"/utf8>>;

        {aes_cbc_hmac, aes192} ->
            <<"A192CBC-HS384"/utf8>>;

        {aes_cbc_hmac, aes256} ->
            <<"A256CBC-HS512"/utf8>>;

        cha_cha20_poly1305 ->
            <<"C20P"/utf8>>;

        x_cha_cha20_poly1305 ->
            <<"XC20P"/utf8>>
    end.

-file("src/gose/jose.gleam", 122).
?DOC(" Parse a content encryption algorithm from its JOSE string representation.\n").
-spec content_alg_from_string(binary()) -> {ok, gose:content_alg()} |
    {error, gose:gose_error()}.
content_alg_from_string(Alg) ->
    case Alg of
        <<"A128GCM"/utf8>> ->
            {ok, {aes_gcm, aes128}};

        <<"A192GCM"/utf8>> ->
            {ok, {aes_gcm, aes192}};

        <<"A256GCM"/utf8>> ->
            {ok, {aes_gcm, aes256}};

        <<"A128CBC-HS256"/utf8>> ->
            {ok, {aes_cbc_hmac, aes128}};

        <<"A192CBC-HS384"/utf8>> ->
            {ok, {aes_cbc_hmac, aes192}};

        <<"A256CBC-HS512"/utf8>> ->
            {ok, {aes_cbc_hmac, aes256}};

        <<"C20P"/utf8>> ->
            {ok, cha_cha20_poly1305};

        <<"XC20P"/utf8>> ->
            {ok, x_cha_cha20_poly1305};

        _ ->
            {error,
                {parse_error,
                    <<"unknown content encryption algorithm: "/utf8,
                        Alg/binary>>}}
    end.
