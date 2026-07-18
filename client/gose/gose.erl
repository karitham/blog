-module(gose).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose.gleam").
-export([error_message/1, new_key/1, is_private_key/1, material/1, material_octet_secret/1, material_rsa/1, material_ec/1, material_eddsa/1, material_xdh/1, from_der/1, from_eddsa_bits/2, from_eddsa_public_bits/2, from_octet_bits/1, from_pem/1, from_xdh_bits/2, from_xdh_public_bits/2, generate_ec/1, generate_eddsa/1, generate_chacha20_kw_key/0, generate_rsa/1, generate_xdh/1, ec_public_key_from_raw_coordinates/3, ec_public_key_from_coordinates/3, ec_raw_coordinates/2, with_alg/2, with_kid/2, with_kid_bits/2, validate_key_use_ops/2, with_key_ops/2, with_key_use/2, alg/1, ec_curve/1, ec_public_key/1, ec_public_key_coordinates/1, eddsa_curve/1, eddsa_public_key/1, key_ops/1, key_type/1, key_use/1, kid/1, octet_key_size/1, rsa_public_key/1, xdh_curve/1, xdh_public_key/1, public_key/1, to_der/1, to_octet_bits/1, to_pem/1, build/5, validate_rfc8037_key_use_public/2, aes_key_size/1, generate_aes_kw_key/1, hmac_alg_key_size/1, generate_hmac_key/1, content_alg_key_size/1, generate_enc_key/1, chacha20_kw_nonce_size/1]).
-export_type([gose_error/0, key_use/0, key_op/0, aes_key_size/0, aes_kw_mode/0, cha_cha20_kw/0, hmac_alg/0, rsa_pkcs1_alg/0, rsa_pss_alg/0, ecdsa_alg/0, digital_signature_alg/0, mac_alg/0, signing_alg/0, rsa_encryption_alg/0, ecdh_es_alg/0, pbes2_alg/0, key_encryption_alg/0, content_alg/0, alg/0, rsa_key_material/0, ec_key_material/0, eddsa_key_material/0, xdh_key_material/0, key_material/0, key_type/0, key/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " A Gleam library for JOSE (JSON Object Signing and Encryption) and\n"
    " COSE (CBOR Object Signing and Encryption).\n"
    "\n"
    " Core:\n"
    " - `gose`: error type, algorithm identifiers, and key management (types,\n"
    "   generators, builders, accessors, serializers)\n"
    " - `gose/cbor`: CBOR encoding for COSE\n"
    "\n"
    " `gose/key`, `gose/algorithm`, `gose/jose/algorithm`, `gose/cose/key`, and\n"
    " `gose/cose/algorithm` are deprecated shims retained for the v2.x migration\n"
    " window. They will be removed in v3.0. New code should import `gose`,\n"
    " `gose/jose`, and `gose/cose` directly.\n"
    "\n"
    " JOSE:\n"
    " - `gose/jose`: JOSE algorithm string conversion ([RFC 7518](https://www.rfc-editor.org/rfc/rfc7518.html))\n"
    " - `gose/jose/jws`: JSON Web Signature ([RFC 7515](https://www.rfc-editor.org/rfc/rfc7515.html))\n"
    " - `gose/jose/jws_multi`: JWS JSON Serialization for multi-signer workflows\n"
    " - `gose/jose/jwe`: JSON Web Encryption ([RFC 7516](https://www.rfc-editor.org/rfc/rfc7516.html))\n"
    " - `gose/jose/jwe_multi`: JWE JSON Serialization for multi-recipient workflows\n"
    " - `gose/jose/jwk`: JSON Web Key serialization ([RFC 7517](https://www.rfc-editor.org/rfc/rfc7517.html))\n"
    " - `gose/jose/key_set`: JWK Set ([RFC 7517 Section 5](https://www.rfc-editor.org/rfc/rfc7517.html#section-5))\n"
    " - `gose/jose/encrypted_key`: encrypted JWK export/import\n"
    " - `gose/jose/jwt`: JSON Web Token ([RFC 7519](https://www.rfc-editor.org/rfc/rfc7519.html))\n"
    " - `gose/jose/encrypted_jwt`: encrypted JWT (JWE-based)\n"
    "\n"
    " COSE:\n"
    " - `gose/cose`: header parameters, the `Key` alias, COSE_Key CBOR serialization, and COSE algorithm ID mapping ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html), [RFC 9053](https://www.rfc-editor.org/rfc/rfc9053.html))\n"
    " - `gose/cose/sign1`: COSE_Sign1 ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html))\n"
    " - `gose/cose/sign`: COSE_Sign multi-signer ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html))\n"
    " - `gose/cose/encrypt0`: COSE_Encrypt0 ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html))\n"
    " - `gose/cose/encrypt`: COSE_Encrypt multi-recipient ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html))\n"
    " - `gose/cose/mac0`: COSE_Mac0 ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html))\n"
    " - `gose/cose/cwt`: CBOR Web Token ([RFC 8392](https://www.rfc-editor.org/rfc/rfc8392.html))\n"
    " - `gose/cose/encrypted_cwt`: encrypted CWT (Encrypt0-wrapped Sign1)\n"
).

-type gose_error() :: {parse_error, binary()} |
    {crypto_error, binary()} |
    {invalid_state, binary()} |
    verification_failed.

-type key_use() :: signing | encrypting.

-type key_op() :: sign |
    verify |
    encrypt |
    decrypt |
    wrap_key |
    unwrap_key |
    derive_key |
    derive_bits.

-type aes_key_size() :: aes128 | aes192 | aes256.

-type aes_kw_mode() :: aes_kw | aes_gcm_kw.

-type cha_cha20_kw() :: c20_p_kw | x_c20_p_kw.

-type hmac_alg() :: hmac_sha256 | hmac_sha384 | hmac_sha512.

-type rsa_pkcs1_alg() :: rsa_pkcs1_sha256 | rsa_pkcs1_sha384 | rsa_pkcs1_sha512.

-type rsa_pss_alg() :: rsa_pss_sha256 | rsa_pss_sha384 | rsa_pss_sha512.

-type ecdsa_alg() :: ecdsa_p256 | ecdsa_p384 | ecdsa_p521 | ecdsa_secp256k1.

-type digital_signature_alg() :: {rsa_pkcs1, rsa_pkcs1_alg()} |
    {rsa_pss, rsa_pss_alg()} |
    {ecdsa, ecdsa_alg()} |
    eddsa.

-type mac_alg() :: {hmac, hmac_alg()}.

-type signing_alg() :: {digital_signature, digital_signature_alg()} |
    {mac, mac_alg()}.

-type rsa_encryption_alg() :: rsa_pkcs1v15 | rsa_oaep_sha1 | rsa_oaep_sha256.

-type ecdh_es_alg() :: ecdh_es_direct |
    {ecdh_es_aes_kw, aes_key_size()} |
    {ecdh_es_cha_cha20_kw, cha_cha20_kw()}.

-type pbes2_alg() :: pbes2_sha256_aes128_kw |
    pbes2_sha384_aes192_kw |
    pbes2_sha512_aes256_kw.

-type key_encryption_alg() :: direct |
    {aes_key_wrap, aes_kw_mode(), aes_key_size()} |
    {cha_cha20_key_wrap, cha_cha20_kw()} |
    {rsa_encryption, rsa_encryption_alg()} |
    {ecdh_es, ecdh_es_alg()} |
    {pbes2, pbes2_alg()}.

-type content_alg() :: {aes_gcm, aes_key_size()} |
    {aes_cbc_hmac, aes_key_size()} |
    cha_cha20_poly1305 |
    x_cha_cha20_poly1305.

-type alg() :: {signing_alg, signing_alg()} |
    {key_encryption_alg, key_encryption_alg()} |
    {content_alg, content_alg()}.

-type rsa_key_material() :: {rsa_private,
        kryptos@rsa:private_key(),
        kryptos@rsa:public_key()} |
    {rsa_public, kryptos@rsa:public_key()}.

-type ec_key_material() :: {ec_private,
        kryptos@ec:private_key(),
        kryptos@ec:public_key(),
        kryptos@ec:curve()} |
    {ec_public, kryptos@ec:public_key(), kryptos@ec:curve()}.

-type eddsa_key_material() :: {eddsa_private,
        kryptos@eddsa:private_key(),
        kryptos@eddsa:public_key(),
        kryptos@eddsa:curve()} |
    {eddsa_public, kryptos@eddsa:public_key(), kryptos@eddsa:curve()}.

-type xdh_key_material() :: {xdh_private,
        kryptos@xdh:private_key(),
        kryptos@xdh:public_key(),
        kryptos@xdh:curve()} |
    {xdh_public, kryptos@xdh:public_key(), kryptos@xdh:curve()}.

-type key_material() :: {octet_key, bitstring()} |
    {rsa, rsa_key_material()} |
    {elliptic, ec_key_material()} |
    {edwards, eddsa_key_material()} |
    {xdh, xdh_key_material()}.

-type key_type() :: oct_key_type | rsa_key_type | ec_key_type | okp_key_type.

-opaque key(JSA) :: {key,
        key_material(),
        gleam@option:option(JSA),
        gleam@option:option(key_use()),
        gleam@option:option(list(key_op())),
        gleam@option:option(alg())}.

-file("src/gose.gleam", 68).
?DOC(" Extract the message string from a GoseError, regardless of variant.\n").
-spec error_message(gose_error()) -> binary().
error_message(Error) ->
    case Error of
        {parse_error, Msg} ->
            Msg;

        {crypto_error, Msg@1} ->
            Msg@1;

        {invalid_state, Msg@2} ->
            Msg@2;

        verification_failed ->
            <<"verification failed"/utf8>>
    end.

-file("src/gose.gleam", 342).
?DOC(false).
-spec new_key(key_material()) -> key(any()).
new_key(Material) ->
    {key, Material, none, none, none, none}.

-file("src/gose.gleam", 353).
?DOC(false).
-spec is_private_key(key(any())) -> boolean().
is_private_key(Key) ->
    case erlang:element(2, Key) of
        {octet_key, _} ->
            true;

        {rsa, {rsa_private, _, _}} ->
            true;

        {rsa, {rsa_public, _}} ->
            false;

        {elliptic, {ec_private, _, _, _}} ->
            true;

        {elliptic, {ec_public, _, _}} ->
            false;

        {edwards, {eddsa_private, _, _, _}} ->
            true;

        {edwards, {eddsa_public, _, _}} ->
            false;

        {xdh, {xdh_private, _, _, _}} ->
            true;

        {xdh, {xdh_public, _, _}} ->
            false
    end.

-file("src/gose.gleam", 368).
?DOC(false).
-spec material(key(any())) -> key_material().
material(Key) ->
    erlang:element(2, Key).

-file("src/gose.gleam", 373).
?DOC(false).
-spec material_octet_secret(key_material()) -> {ok, bitstring()} |
    {error, gose_error()}.
material_octet_secret(Mat) ->
    case Mat of
        {octet_key, Secret} ->
            {ok, Secret};

        {rsa, _} ->
            {error, {invalid_state, <<"expected octet key"/utf8>>}};

        {elliptic, _} ->
            {error, {invalid_state, <<"expected octet key"/utf8>>}};

        {edwards, _} ->
            {error, {invalid_state, <<"expected octet key"/utf8>>}};

        {xdh, _} ->
            {error, {invalid_state, <<"expected octet key"/utf8>>}}
    end.

-file("src/gose.gleam", 382).
?DOC(false).
-spec material_rsa(key_material()) -> {ok, rsa_key_material()} |
    {error, gose_error()}.
material_rsa(Mat) ->
    case Mat of
        {rsa, Rsa} ->
            {ok, Rsa};

        {octet_key, _} ->
            {error, {invalid_state, <<"expected RSA key"/utf8>>}};

        {elliptic, _} ->
            {error, {invalid_state, <<"expected RSA key"/utf8>>}};

        {edwards, _} ->
            {error, {invalid_state, <<"expected RSA key"/utf8>>}};

        {xdh, _} ->
            {error, {invalid_state, <<"expected RSA key"/utf8>>}}
    end.

-file("src/gose.gleam", 391).
?DOC(false).
-spec material_ec(key_material()) -> {ok, ec_key_material()} |
    {error, gose_error()}.
material_ec(Mat) ->
    case Mat of
        {elliptic, Ec} ->
            {ok, Ec};

        {octet_key, _} ->
            {error, {invalid_state, <<"expected EC key"/utf8>>}};

        {rsa, _} ->
            {error, {invalid_state, <<"expected EC key"/utf8>>}};

        {edwards, _} ->
            {error, {invalid_state, <<"expected EC key"/utf8>>}};

        {xdh, _} ->
            {error, {invalid_state, <<"expected EC key"/utf8>>}}
    end.

-file("src/gose.gleam", 400).
?DOC(false).
-spec material_eddsa(key_material()) -> {ok, eddsa_key_material()} |
    {error, gose_error()}.
material_eddsa(Mat) ->
    case Mat of
        {edwards, Eddsa} ->
            {ok, Eddsa};

        {octet_key, _} ->
            {error, {invalid_state, <<"expected EdDSA key"/utf8>>}};

        {rsa, _} ->
            {error, {invalid_state, <<"expected EdDSA key"/utf8>>}};

        {elliptic, _} ->
            {error, {invalid_state, <<"expected EdDSA key"/utf8>>}};

        {xdh, _} ->
            {error, {invalid_state, <<"expected EdDSA key"/utf8>>}}
    end.

-file("src/gose.gleam", 409).
?DOC(false).
-spec material_xdh(key_material()) -> {ok, xdh_key_material()} |
    {error, gose_error()}.
material_xdh(Mat) ->
    case Mat of
        {xdh, Xdh} ->
            {ok, Xdh};

        {octet_key, _} ->
            {error, {invalid_state, <<"expected XDH key"/utf8>>}};

        {rsa, _} ->
            {error, {invalid_state, <<"expected XDH key"/utf8>>}};

        {elliptic, _} ->
            {error, {invalid_state, <<"expected XDH key"/utf8>>}};

        {edwards, _} ->
            {error, {invalid_state, <<"expected XDH key"/utf8>>}}
    end.

-file("src/gose.gleam", 433).
-spec ec_private_key({kryptos@ec:private_key(), kryptos@ec:public_key()}) -> key(any()).
ec_private_key(Pair) ->
    {Private, Public} = Pair,
    Curve = kryptos_ffi:ec_private_key_curve(Private),
    new_key({elliptic, {ec_private, Private, Public, Curve}}).

-file("src/gose.gleam", 439).
-spec ec_public_key_internal(kryptos@ec:public_key()) -> key(any()).
ec_public_key_internal(Public) ->
    Curve = kryptos_ffi:ec_public_key_curve(Public),
    new_key({elliptic, {ec_public, Public, Curve}}).

-file("src/gose.gleam", 444).
-spec eddsa_private_key(
    {kryptos@eddsa:private_key(), kryptos@eddsa:public_key()}
) -> key(any()).
eddsa_private_key(Pair) ->
    {Private, Public} = Pair,
    Curve = kryptos_ffi:eddsa_private_key_curve(Private),
    new_key({edwards, {eddsa_private, Private, Public, Curve}}).

-file("src/gose.gleam", 450).
-spec eddsa_public_key_internal(kryptos@eddsa:public_key()) -> key(any()).
eddsa_public_key_internal(Public) ->
    Curve = kryptos_ffi:eddsa_public_key_curve(Public),
    new_key({edwards, {eddsa_public, Public, Curve}}).

-file("src/gose.gleam", 455).
-spec rsa_private_key_internal(
    {kryptos@rsa:private_key(), kryptos@rsa:public_key()}
) -> key(any()).
rsa_private_key_internal(Pair) ->
    {Private, Public} = Pair,
    new_key({rsa, {rsa_private, Private, Public}}).

-file("src/gose.gleam", 460).
-spec rsa_public_key_internal(kryptos@rsa:public_key()) -> key(any()).
rsa_public_key_internal(Public) ->
    new_key({rsa, {rsa_public, Public}}).

-file("src/gose.gleam", 464).
-spec xdh_private_key({kryptos@xdh:private_key(), kryptos@xdh:public_key()}) -> key(any()).
xdh_private_key(Pair) ->
    {Private, Public} = Pair,
    Curve = kryptos_ffi:xdh_private_key_curve(Private),
    new_key({xdh, {xdh_private, Private, Public, Curve}}).

-file("src/gose.gleam", 470).
-spec xdh_public_key_internal(kryptos@xdh:public_key()) -> key(any()).
xdh_public_key_internal(Public) ->
    Curve = kryptos_ffi:xdh_public_key_curve(Public),
    new_key({xdh, {xdh_public, Public, Curve}}).

-file("src/gose.gleam", 475).
-spec parse_ec_der(bitstring()) -> {ok, key(any())} | {error, nil}.
parse_ec_der(Der) ->
    _pipe = kryptos_ffi:ec_import_private_key_der(Der),
    _pipe@1 = gleam@result:map(_pipe, fun ec_private_key/1),
    gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = kryptos_ffi:ec_import_public_key_der(Der),
            gleam@result:map(_pipe@2, fun ec_public_key_internal/1) end
    ).

-file("src/gose.gleam", 483).
-spec parse_eddsa_der(bitstring()) -> {ok, key(any())} | {error, nil}.
parse_eddsa_der(Der) ->
    _pipe = kryptos_ffi:eddsa_import_private_key_der(Der),
    _pipe@1 = gleam@result:map(_pipe, fun eddsa_private_key/1),
    gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = kryptos_ffi:eddsa_import_public_key_der(Der),
            gleam@result:map(_pipe@2, fun eddsa_public_key_internal/1) end
    ).

-file("src/gose.gleam", 491).
-spec parse_rsa_der(bitstring()) -> {ok, key(any())} | {error, nil}.
parse_rsa_der(Der) ->
    _pipe = kryptos_ffi:rsa_import_private_key_der(Der, pkcs8),
    _pipe@1 = gleam@result:map(_pipe, fun rsa_private_key_internal/1),
    _pipe@3 = gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = kryptos_ffi:rsa_import_private_key_der(Der, pkcs1),
            gleam@result:map(_pipe@2, fun rsa_private_key_internal/1) end
    ),
    _pipe@5 = gleam@result:lazy_or(
        _pipe@3,
        fun() -> _pipe@4 = kryptos_ffi:rsa_import_public_key_der(Der, spki),
            gleam@result:map(_pipe@4, fun rsa_public_key_internal/1) end
    ),
    gleam@result:lazy_or(
        _pipe@5,
        fun() ->
            _pipe@6 = kryptos_ffi:rsa_import_public_key_der(Der, rsa_public_key),
            gleam@result:map(_pipe@6, fun rsa_public_key_internal/1)
        end
    ).

-file("src/gose.gleam", 507).
-spec parse_xdh_der(bitstring()) -> {ok, key(any())} | {error, nil}.
parse_xdh_der(Der) ->
    _pipe = kryptos_ffi:xdh_import_private_key_der(Der),
    _pipe@1 = gleam@result:map(_pipe, fun xdh_private_key/1),
    gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = kryptos_ffi:xdh_import_public_key_der(Der),
            gleam@result:map(_pipe@2, fun xdh_public_key_internal/1) end
    ).

-file("src/gose.gleam", 421).
?DOC(
    " Create a key from DER-encoded data.\n"
    "\n"
    " Auto-detects key type (RSA, EC, EdDSA, XDH) and format (PKCS#1, PKCS#8, SPKI).\n"
    " Supports both private and public keys.\n"
).
-spec from_der(bitstring()) -> {ok, key(any())} | {error, gose_error()}.
from_der(Der) ->
    _pipe = parse_rsa_der(Der),
    _pipe@1 = gleam@result:lazy_or(_pipe, fun() -> parse_eddsa_der(Der) end),
    _pipe@2 = gleam@result:lazy_or(_pipe@1, fun() -> parse_xdh_der(Der) end),
    _pipe@3 = gleam@result:lazy_or(_pipe@2, fun() -> parse_ec_der(Der) end),
    gleam@result:map_error(
        _pipe@3,
        fun(_) ->
            {parse_error,
                <<"invalid DER: not a recognized RSA, EC, EdDSA, or XDH key format"/utf8>>}
        end
    ).

-file("src/gose.gleam", 519).
?DOC(
    " Create an EdDSA key pair from raw private key bytes.\n"
    "\n"
    " The public key is derived from the private key.\n"
    " This is the inverse of `to_octet_bits` for EdDSA private keys.\n"
).
-spec from_eddsa_bits(kryptos@eddsa:curve(), bitstring()) -> {ok, key(any())} |
    {error, gose_error()}.
from_eddsa_bits(Curve, Private_bits) ->
    _pipe = kryptos_ffi:eddsa_private_key_from_bytes(Curve, Private_bits),
    _pipe@1 = gleam@result:map(
        _pipe,
        fun(Pair) ->
            {Private, Public} = Pair,
            new_key({edwards, {eddsa_private, Private, Public, Curve}})
        end
    ),
    gleam@result:replace_error(
        _pipe@1,
        {parse_error, <<"invalid EdDSA private key bits"/utf8>>}
    ).

-file("src/gose.gleam", 534).
?DOC(
    " Create an EdDSA public key from raw bytes.\n"
    "\n"
    " This is the inverse of `to_octet_bits` for EdDSA public keys.\n"
).
-spec from_eddsa_public_bits(kryptos@eddsa:curve(), bitstring()) -> {ok,
        key(any())} |
    {error, gose_error()}.
from_eddsa_public_bits(Curve, Public_bits) ->
    _pipe = kryptos_ffi:eddsa_public_key_from_bytes(Curve, Public_bits),
    _pipe@1 = gleam@result:map(
        _pipe,
        fun(Public) -> new_key({edwards, {eddsa_public, Public, Curve}}) end
    ),
    gleam@result:replace_error(
        _pipe@1,
        {parse_error, <<"invalid EdDSA public key bits"/utf8>>}
    ).

-file("src/gose.gleam", 556).
?DOC(
    " Create a symmetric key from raw bytes.\n"
    "\n"
    " Used for HMAC signing (HS256/384/512) and direct encryption.\n"
    " Returns an error if the secret is empty.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let secret = crypto.random_bytes(32)\n"
    " let assert Ok(key) = gose.from_octet_bits(secret)\n"
    " ```\n"
).
-spec from_octet_bits(bitstring()) -> {ok, key(any())} | {error, gose_error()}.
from_octet_bits(Secret) ->
    case erlang:byte_size(Secret) of
        0 ->
            {error, {invalid_state, <<"oct key must not be empty"/utf8>>}};

        _ ->
            {ok, new_key({octet_key, Secret})}
    end.

-file("src/gose.gleam", 579).
-spec parse_ec_pem(binary()) -> {ok, key(any())} | {error, nil}.
parse_ec_pem(Pem) ->
    _pipe = kryptos_ffi:ec_import_private_key_pem(Pem),
    _pipe@1 = gleam@result:map(_pipe, fun ec_private_key/1),
    gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = kryptos_ffi:ec_import_public_key_pem(Pem),
            gleam@result:map(_pipe@2, fun ec_public_key_internal/1) end
    ).

-file("src/gose.gleam", 587).
-spec parse_eddsa_pem(binary()) -> {ok, key(any())} | {error, nil}.
parse_eddsa_pem(Pem) ->
    _pipe = kryptos_ffi:eddsa_import_private_key_pem(Pem),
    _pipe@1 = gleam@result:map(_pipe, fun eddsa_private_key/1),
    gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = kryptos_ffi:eddsa_import_public_key_pem(Pem),
            gleam@result:map(_pipe@2, fun eddsa_public_key_internal/1) end
    ).

-file("src/gose.gleam", 595).
-spec parse_rsa_pem(binary()) -> {ok, key(any())} | {error, nil}.
parse_rsa_pem(Pem) ->
    _pipe = kryptos_ffi:rsa_import_private_key_pem(Pem, pkcs8),
    _pipe@1 = gleam@result:map(_pipe, fun rsa_private_key_internal/1),
    _pipe@3 = gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = kryptos_ffi:rsa_import_private_key_pem(Pem, pkcs1),
            gleam@result:map(_pipe@2, fun rsa_private_key_internal/1) end
    ),
    _pipe@5 = gleam@result:lazy_or(
        _pipe@3,
        fun() -> _pipe@4 = kryptos_ffi:rsa_import_public_key_pem(Pem, spki),
            gleam@result:map(_pipe@4, fun rsa_public_key_internal/1) end
    ),
    gleam@result:lazy_or(
        _pipe@5,
        fun() ->
            _pipe@6 = kryptos_ffi:rsa_import_public_key_pem(Pem, rsa_public_key),
            gleam@result:map(_pipe@6, fun rsa_public_key_internal/1)
        end
    ).

-file("src/gose.gleam", 611).
-spec parse_xdh_pem(binary()) -> {ok, key(any())} | {error, nil}.
parse_xdh_pem(Pem) ->
    _pipe = kryptos_ffi:xdh_import_private_key_pem(Pem),
    _pipe@1 = gleam@result:map(_pipe, fun xdh_private_key/1),
    gleam@result:lazy_or(
        _pipe@1,
        fun() -> _pipe@2 = kryptos_ffi:xdh_import_public_key_pem(Pem),
            gleam@result:map(_pipe@2, fun xdh_public_key_internal/1) end
    ).

-file("src/gose.gleam", 567).
?DOC(
    " Create a key from PEM-encoded data.\n"
    "\n"
    " Auto-detects key type (RSA, EC, EdDSA, XDH) and format (PKCS#1, PKCS#8, SPKI).\n"
    " Supports both private and public keys.\n"
).
-spec from_pem(binary()) -> {ok, key(any())} | {error, gose_error()}.
from_pem(Pem) ->
    _pipe = parse_rsa_pem(Pem),
    _pipe@1 = gleam@result:lazy_or(_pipe, fun() -> parse_eddsa_pem(Pem) end),
    _pipe@2 = gleam@result:lazy_or(_pipe@1, fun() -> parse_xdh_pem(Pem) end),
    _pipe@3 = gleam@result:lazy_or(_pipe@2, fun() -> parse_ec_pem(Pem) end),
    gleam@result:map_error(
        _pipe@3,
        fun(_) ->
            {parse_error,
                <<"invalid PEM: not a recognized RSA, EC, EdDSA, or XDH key format"/utf8>>}
        end
    ).

-file("src/gose.gleam", 623).
?DOC(
    " Create an XDH key pair from raw private key bytes.\n"
    "\n"
    " The public key is derived from the private key.\n"
    " This is the inverse of `to_octet_bits` for XDH private keys.\n"
).
-spec from_xdh_bits(kryptos@xdh:curve(), bitstring()) -> {ok, key(any())} |
    {error, gose_error()}.
from_xdh_bits(Curve, Private_bits) ->
    _pipe = kryptos_ffi:xdh_private_key_from_bytes(Curve, Private_bits),
    _pipe@1 = gleam@result:map(
        _pipe,
        fun(Pair) ->
            {Private, Public} = Pair,
            new_key({xdh, {xdh_private, Private, Public, Curve}})
        end
    ),
    gleam@result:replace_error(
        _pipe@1,
        {parse_error, <<"invalid XDH private key bits"/utf8>>}
    ).

-file("src/gose.gleam", 638).
?DOC(
    " Create an XDH public key from raw bytes.\n"
    "\n"
    " This is the inverse of `to_octet_bits` for XDH public keys.\n"
).
-spec from_xdh_public_bits(kryptos@xdh:curve(), bitstring()) -> {ok, key(any())} |
    {error, gose_error()}.
from_xdh_public_bits(Curve, Public_bits) ->
    _pipe = kryptos_ffi:xdh_public_key_from_bytes(Curve, Public_bits),
    _pipe@1 = gleam@result:map(
        _pipe,
        fun(Public) -> new_key({xdh, {xdh_public, Public, Curve}}) end
    ),
    gleam@result:replace_error(
        _pipe@1,
        {parse_error, <<"invalid XDH public key bits"/utf8>>}
    ).

-file("src/gose.gleam", 650).
?DOC(
    " Generate a new EC key pair for the given curve.\n"
    "\n"
    " Supported curves: P256, P384, P521, Secp256k1.\n"
).
-spec generate_ec(kryptos@ec:curve()) -> key(any()).
generate_ec(Curve) ->
    {Private, Public} = kryptos_ffi:ec_generate_key_pair(Curve),
    new_key({elliptic, {ec_private, Private, Public, Curve}}).

-file("src/gose.gleam", 658).
?DOC(
    " Generate a new EdDSA key pair for the given curve.\n"
    "\n"
    " Supported curves: Ed25519, Ed448.\n"
).
-spec generate_eddsa(kryptos@eddsa:curve()) -> key(any()).
generate_eddsa(Curve) ->
    {Private, Public} = kryptos_ffi:eddsa_generate_key_pair(Curve),
    new_key({edwards, {eddsa_private, Private, Public, Curve}}).

-file("src/gose.gleam", 707).
?DOC(
    " Generate a symmetric key for ChaCha20-Poly1305 Key Wrap (C20PKW / XC20PKW).\n"
    "\n"
    " Always generates a 32-byte key, as both ChaCha20 and XChaCha20 use 256-bit keys.\n"
).
-spec generate_chacha20_kw_key() -> key(any()).
generate_chacha20_kw_key() ->
    Secret = kryptos_ffi:random_bytes(32),
    new_key({octet_key, Secret}).

-file("src/gose.gleam", 715).
?DOC(
    " Generate a new RSA key pair with the given key size in bits.\n"
    " Common sizes are 2048, 3072, and 4096. Keys smaller than 2048\n"
    " bits are not recommended for security.\n"
).
-spec generate_rsa(integer()) -> {ok, key(any())} | {error, gose_error()}.
generate_rsa(Bits) ->
    case kryptos@rsa:generate_key_pair(Bits) of
        {ok, {Private, Public}} ->
            {ok, new_key({rsa, {rsa_private, Private, Public}})};

        {error, _} ->
            {error, {crypto_error, <<"RSA key generation failed"/utf8>>}}
    end.

-file("src/gose.gleam", 726).
?DOC(
    " Generate a new XDH key pair for key agreement.\n"
    "\n"
    " Supported curves: X25519, X448.\n"
).
-spec generate_xdh(kryptos@xdh:curve()) -> key(any()).
generate_xdh(Curve) ->
    {Private, Public} = kryptos_ffi:xdh_generate_key_pair(Curve),
    new_key({xdh, {xdh_private, Private, Public, Curve}}).

-file("src/gose.gleam", 742).
?DOC(false).
-spec ec_public_key_from_raw_coordinates(
    kryptos@ec:curve(),
    bitstring(),
    bitstring()
) -> {ok, kryptos@ec:public_key()} | {error, gose_error()}.
ec_public_key_from_raw_coordinates(Curve, X, Y) ->
    Coord_size = kryptos@ec:coordinate_size(Curve),
    gleam@bool:guard(
        erlang:byte_size(X) /= Coord_size,
        {error, {parse_error, <<"EC x coordinate wrong length"/utf8>>}},
        fun() ->
            gleam@bool:guard(
                erlang:byte_size(Y) /= Coord_size,
                {error, {parse_error, <<"EC y coordinate wrong length"/utf8>>}},
                fun() ->
                    Raw_point = gleam_stdlib:bit_array_concat([<<16#04>>, X, Y]),
                    _pipe = kryptos_ffi:ec_public_key_from_raw_point(
                        Curve,
                        Raw_point
                    ),
                    gleam@result:replace_error(
                        _pipe,
                        {parse_error, <<"invalid EC coordinates"/utf8>>}
                    )
                end
            )
        end
    ).

-file("src/gose.gleam", 732).
?DOC(" Create an EC public key from curve and x,y coordinates (big-endian bytes).\n").
-spec ec_public_key_from_coordinates(
    kryptos@ec:curve(),
    bitstring(),
    bitstring()
) -> {ok, key(any())} | {error, gose_error()}.
ec_public_key_from_coordinates(Curve, X, Y) ->
    _pipe = ec_public_key_from_raw_coordinates(Curve, X, Y),
    gleam@result:map(
        _pipe,
        fun(Public) -> new_key({elliptic, {ec_public, Public, Curve}}) end
    ).

-file("src/gose.gleam", 762).
?DOC(false).
-spec ec_raw_coordinates(kryptos@ec:public_key(), kryptos@ec:curve()) -> {ok,
        {bitstring(), bitstring()}} |
    {error, gose_error()}.
ec_raw_coordinates(Public, Curve) ->
    Coord_size = kryptos@ec:coordinate_size(Curve),
    Raw_point = kryptos_ffi:ec_public_key_to_raw_point(Public),
    Expected_size = 1 + (Coord_size * 2),
    case {erlang:byte_size(Raw_point) =:= Expected_size, Raw_point} of
        {true, <<16#04, Rest/bitstring>>} ->
            Error = {invalid_state, <<"invalid raw point format"/utf8>>},
            gleam@result:'try'(
                begin
                    _pipe = gleam_stdlib:bit_array_slice(Rest, 0, Coord_size),
                    gleam@result:replace_error(_pipe, Error)
                end,
                fun(X) ->
                    gleam@result:'try'(
                        begin
                            _pipe@1 = gleam_stdlib:bit_array_slice(
                                Rest,
                                Coord_size,
                                Coord_size
                            ),
                            gleam@result:replace_error(_pipe@1, Error)
                        end,
                        fun(Y) -> {ok, {X, Y}} end
                    )
                end
            );

        {_, _} ->
            {error, {invalid_state, <<"invalid raw point format"/utf8>>}}
    end.

-file("src/gose.gleam", 787).
?DOC(" Set the algorithm (`alg`) metadata parameter on a key.\n").
-spec with_alg(key(JWP), alg()) -> key(JWP).
with_alg(Key, Alg) ->
    {key,
        erlang:element(2, Key),
        erlang:element(3, Key),
        erlang:element(4, Key),
        erlang:element(5, Key),
        {some, Alg}}.

-file("src/gose.gleam", 831).
?DOC(
    " Validate key use against RFC 8037 curve restrictions.\n"
    " - EdDSA keys (Ed25519/Ed448): only `sig` allowed\n"
    " - XDH keys (X25519/X448): only `enc` allowed\n"
).
-spec validate_rfc8037_key_use(key_material(), gleam@option:option(key_use())) -> {ok,
        nil} |
    {error, gose_error()}.
validate_rfc8037_key_use(Material, Use_) ->
    case {Material, Use_} of
        {{edwards, _}, {some, encrypting}} ->
            {error,
                {invalid_state,
                    <<"EdDSA keys (Ed25519/Ed448) cannot be used for encryption"/utf8>>}};

        {{xdh, _}, {some, signing}} ->
            {error,
                {invalid_state,
                    <<"XDH keys (X25519/X448) cannot be used for signing"/utf8>>}};

        {_, _} ->
            {ok, nil}
    end.

-file("src/gose.gleam", 847).
?DOC(" Set the key ID (`kid`) metadata parameter on a key.\n").
-spec with_kid(key(any()), binary()) -> key(binary()).
with_kid(Key, Kid) ->
    {key,
        erlang:element(2, Key),
        {some, Kid},
        erlang:element(4, Key),
        erlang:element(5, Key),
        erlang:element(6, Key)}.

-file("src/gose.gleam", 855).
?DOC(
    " Set the key ID (`kid`) metadata parameter on a key using raw bytes.\n"
    "\n"
    " In COSE (RFC 9052), kid is a bstr that may contain arbitrary bytes.\n"
    " For JWK interoperability where kid is a JSON string, use `with_kid`.\n"
).
-spec with_kid_bits(key(any()), bitstring()) -> key(bitstring()).
with_kid_bits(Key, Kid) ->
    {key,
        erlang:element(2, Key),
        {some, Kid},
        erlang:element(4, Key),
        erlang:element(5, Key),
        erlang:element(6, Key)}.

-file("src/gose.gleam", 859).
-spec is_signing_op(key_op()) -> boolean().
is_signing_op(Op) ->
    case Op of
        sign ->
            true;

        verify ->
            true;

        encrypt ->
            false;

        decrypt ->
            false;

        wrap_key ->
            false;

        unwrap_key ->
            false;

        derive_key ->
            false;

        derive_bits ->
            false
    end.

-file("src/gose.gleam", 866).
-spec is_encrypting_op(key_op()) -> boolean().
is_encrypting_op(Op) ->
    case Op of
        encrypt ->
            true;

        decrypt ->
            true;

        wrap_key ->
            true;

        unwrap_key ->
            true;

        derive_key ->
            true;

        derive_bits ->
            true;

        sign ->
            false;

        verify ->
            false
    end.

-file("src/gose.gleam", 874).
?DOC(false).
-spec validate_key_use_ops(
    gleam@option:option(key_use()),
    gleam@option:option(list(key_op()))
) -> {ok, nil} | {error, gose_error()}.
validate_key_use_ops(Key_use, Key_ops) ->
    case {Key_use, Key_ops} of
        {none, _} ->
            {ok, nil};

        {_, none} ->
            {ok, nil};

        {{some, signing}, {some, Ops}} ->
            case gleam@list:all(Ops, fun is_signing_op/1) of
                true ->
                    {ok, nil};

                false ->
                    {error,
                        {invalid_state,
                            <<"key_ops incompatible with use=sig"/utf8>>}}
            end;

        {{some, encrypting}, {some, Ops@1}} ->
            case gleam@list:all(Ops@1, fun is_encrypting_op/1) of
                true ->
                    {ok, nil};

                false ->
                    {error,
                        {invalid_state,
                            <<"key_ops incompatible with use=enc"/utf8>>}}
            end
    end.

-file("src/gose.gleam", 799).
?DOC(
    " Set the key operations parameter.\n"
    "\n"
    " Per RFC 7517, the values should be consistent with `key_use` if both are present:\n"
    " - `Signing` use implies `Sign` and/or `Verify` operations\n"
    " - `Encrypting` use implies `Encrypt`, `Decrypt`, `WrapKey`, `UnwrapKey`, `DeriveKey`, `DeriveBits`\n"
    "\n"
    " Returns an error if the list is empty, contains duplicates, or is\n"
    " incompatible with the key's existing `key_use`.\n"
).
-spec with_key_ops(key(JWS), list(key_op())) -> {ok, key(JWS)} |
    {error, gose_error()}.
with_key_ops(Key, Ops) ->
    case Ops of
        [] ->
            {error, {invalid_state, <<"key_ops must not be empty"/utf8>>}};

        _ ->
            gleam@bool:guard(
                gleam@list:unique(Ops) /= Ops,
                {error,
                    {invalid_state,
                        <<"key_ops must not contain duplicates"/utf8>>}},
                fun() ->
                    _pipe = validate_key_use_ops(
                        erlang:element(4, Key),
                        {some, Ops}
                    ),
                    gleam@result:replace(
                        _pipe,
                        {key,
                            erlang:element(2, Key),
                            erlang:element(3, Key),
                            erlang:element(4, Key),
                            {some, Ops},
                            erlang:element(6, Key)}
                    )
                end
            )
    end.

-file("src/gose.gleam", 822).
?DOC(
    " Set the public key use parameter.\n"
    "\n"
    " Returns an error if the key already has `key_ops` that are incompatible with\n"
    " the specified use, or if the use is incompatible with the key type per RFC\n"
    " 8037 (EdDSA keys can only be used for signing, XDH keys can only be used for\n"
    " encryption).\n"
).
-spec with_key_use(key(JWY), key_use()) -> {ok, key(JWY)} |
    {error, gose_error()}.
with_key_use(Key, Use_) ->
    gleam@result:'try'(
        validate_key_use_ops({some, Use_}, erlang:element(5, Key)),
        fun(_) ->
            gleam@result:'try'(
                validate_rfc8037_key_use(erlang:element(2, Key), {some, Use_}),
                fun(_) ->
                    {ok,
                        {key,
                            erlang:element(2, Key),
                            erlang:element(3, Key),
                            {some, Use_},
                            erlang:element(5, Key),
                            erlang:element(6, Key)}}
                end
            )
        end
    ).

-file("src/gose.gleam", 894).
?DOC(" Get the algorithm (`alg`) parameter.\n").
-spec alg(key(any())) -> {ok, alg()} | {error, nil}.
alg(Key) ->
    gleam@option:to_result(erlang:element(6, Key), nil).

-file("src/gose.gleam", 901).
?DOC(
    " Get the curve used by an EC key.\n"
    "\n"
    " Returns an error if the key is not an EC key.\n"
).
-spec ec_curve(key(any())) -> {ok, kryptos@ec:curve()} | {error, gose_error()}.
ec_curve(Key) ->
    _pipe = material_ec(erlang:element(2, Key)),
    gleam@result:map(_pipe, fun(Ec) -> case Ec of
                {ec_private, _, _, Curve} ->
                    Curve;

                {ec_public, _, Curve} ->
                    Curve
            end end).

-file("src/gose.gleam", 916).
?DOC(
    " Extract the EC public key.\n"
    "\n"
    " Works with both EC private keys (extracts the public component)\n"
    " and EC public keys.\n"
    "\n"
    " Returns an error if the key is not an EC key.\n"
).
-spec ec_public_key(key(any())) -> {ok, kryptos@ec:public_key()} |
    {error, gose_error()}.
ec_public_key(Key) ->
    _pipe = material_ec(erlang:element(2, Key)),
    gleam@result:map(_pipe, fun(Ec) -> case Ec of
                {ec_private, _, Public, _} ->
                    Public;

                {ec_public, K, _} ->
                    K
            end end).

-file("src/gose.gleam", 932).
?DOC(
    " Get the x and y coordinates from an EC public key.\n"
    "\n"
    " The coordinates are returned as raw big-endian bytes, padded to\n"
    " the coordinate size for the curve.\n"
    "\n"
    " Returns an error if the key is not an EC key.\n"
).
-spec ec_public_key_coordinates(key(any())) -> {ok, {bitstring(), bitstring()}} |
    {error, gose_error()}.
ec_public_key_coordinates(Key) ->
    gleam@result:'try'(
        ec_public_key(Key),
        fun(Public) ->
            gleam@result:'try'(
                ec_curve(Key),
                fun(Curve) -> ec_raw_coordinates(Public, Curve) end
            )
        end
    ).

-file("src/gose.gleam", 943).
?DOC(
    " Get the curve used by an EdDSA key.\n"
    "\n"
    " Returns an error if the key is not an EdDSA key.\n"
).
-spec eddsa_curve(key(any())) -> {ok, kryptos@eddsa:curve()} |
    {error, gose_error()}.
eddsa_curve(Key) ->
    _pipe = material_eddsa(erlang:element(2, Key)),
    gleam@result:map(_pipe, fun(Eddsa) -> case Eddsa of
                {eddsa_private, _, _, Curve} ->
                    Curve;

                {eddsa_public, _, Curve} ->
                    Curve
            end end).

-file("src/gose.gleam", 958).
?DOC(
    " Extract the EdDSA public key.\n"
    "\n"
    " Works with both EdDSA private keys (extracts the public component)\n"
    " and EdDSA public keys.\n"
    "\n"
    " Returns an error if the key is not an EdDSA key.\n"
).
-spec eddsa_public_key(key(any())) -> {ok, kryptos@eddsa:public_key()} |
    {error, gose_error()}.
eddsa_public_key(Key) ->
    _pipe = material_eddsa(erlang:element(2, Key)),
    gleam@result:map(_pipe, fun(Eddsa) -> case Eddsa of
                {eddsa_private, _, Public, _} ->
                    Public;

                {eddsa_public, K, _} ->
                    K
            end end).

-file("src/gose.gleam", 969).
?DOC(" Get the key operations parameter.\n").
-spec key_ops(key(any())) -> {ok, list(key_op())} | {error, nil}.
key_ops(Key) ->
    gleam@option:to_result(erlang:element(5, Key), nil).

-file("src/gose.gleam", 974).
?DOC(" Get the key type (kty) for this key.\n").
-spec key_type(key(any())) -> key_type().
key_type(Key) ->
    case erlang:element(2, Key) of
        {octet_key, _} ->
            oct_key_type;

        {rsa, _} ->
            rsa_key_type;

        {elliptic, _} ->
            ec_key_type;

        {edwards, _} ->
            okp_key_type;

        {xdh, _} ->
            okp_key_type
    end.

-file("src/gose.gleam", 984).
?DOC(" Get the public key use parameter.\n").
-spec key_use(key(any())) -> {ok, key_use()} | {error, nil}.
key_use(Key) ->
    gleam@option:to_result(erlang:element(4, Key), nil).

-file("src/gose.gleam", 993).
?DOC(
    " Get the key ID (kid) parameter.\n"
    "\n"
    " The return type depends on the key's kid type parameter:\n"
    " - `Key(String)` (from JWK) → `Result(String, Nil)`\n"
    " - `Key(BitArray)` (from COSE) → `Result(BitArray, Nil)`\n"
).
-spec kid(key(JZA)) -> {ok, JZA} | {error, nil}.
kid(Key) ->
    gleam@option:to_result(erlang:element(3, Key), nil).

-file("src/gose.gleam", 1000).
?DOC(
    " Get the size of an octet (symmetric) key in bytes.\n"
    "\n"
    " Returns an error if the key is not an octet key.\n"
).
-spec octet_key_size(key(any())) -> {ok, integer()} | {error, gose_error()}.
octet_key_size(Key) ->
    case material_octet_secret(erlang:element(2, Key)) of
        {ok, Secret} ->
            {ok, erlang:byte_size(Secret)};

        {error, _} ->
            {error, {invalid_state, <<"key is not an octet key"/utf8>>}}
    end.

-file("src/gose.gleam", 1013).
?DOC(
    " Extract the RSA public key.\n"
    "\n"
    " Works with both RSA private keys (extracts the public component)\n"
    " and RSA public keys.\n"
    "\n"
    " Returns an error if the key is not an RSA key.\n"
).
-spec rsa_public_key(key(any())) -> {ok, kryptos@rsa:public_key()} |
    {error, gose_error()}.
rsa_public_key(Key) ->
    _pipe = material_rsa(erlang:element(2, Key)),
    gleam@result:map(_pipe, fun(Rsa) -> case Rsa of
                {rsa_private, _, Public} ->
                    Public;

                {rsa_public, K} ->
                    K
            end end).

-file("src/gose.gleam", 1026).
?DOC(
    " Get the curve used by an XDH key.\n"
    "\n"
    " Returns an error if the key is not an XDH key.\n"
).
-spec xdh_curve(key(any())) -> {ok, kryptos@xdh:curve()} | {error, gose_error()}.
xdh_curve(Key) ->
    _pipe = material_xdh(erlang:element(2, Key)),
    gleam@result:map(_pipe, fun(Xdh) -> case Xdh of
                {xdh_private, _, _, Curve} ->
                    Curve;

                {xdh_public, _, Curve} ->
                    Curve
            end end).

-file("src/gose.gleam", 1041).
?DOC(
    " Extract the XDH public key (X25519/X448).\n"
    "\n"
    " Works with both XDH private keys (extracts the public component)\n"
    " and XDH public keys.\n"
    "\n"
    " Returns an error if the key is not an XDH key.\n"
).
-spec xdh_public_key(key(any())) -> {ok, kryptos@xdh:public_key()} |
    {error, gose_error()}.
xdh_public_key(Key) ->
    _pipe = material_xdh(erlang:element(2, Key)),
    gleam@result:map(_pipe, fun(Xdh) -> case Xdh of
                {xdh_private, _, Public, _} ->
                    Public;

                {xdh_public, K, _} ->
                    K
            end end).

-file("src/gose.gleam", 1117).
-spec map_public_key_op(key_op()) -> {ok, key_op()} | {error, nil}.
map_public_key_op(Op) ->
    case Op of
        sign ->
            {ok, verify};

        decrypt ->
            {error, nil};

        unwrap_key ->
            {error, nil};

        verify ->
            {ok, Op};

        encrypt ->
            {ok, Op};

        wrap_key ->
            {ok, Op};

        derive_key ->
            {ok, Op};

        derive_bits ->
            {ok, Op}
    end.

-file("src/gose.gleam", 1110).
-spec filter_public_key_ops(list(key_op())) -> {ok, list(key_op())} |
    {error, nil}.
filter_public_key_ops(Ops) ->
    case gleam@list:unique(gleam@list:filter_map(Ops, fun map_public_key_op/1)) of
        [] ->
            {error, nil};

        Filtered ->
            {ok, Filtered}
    end.

-file("src/gose.gleam", 1068).
?DOC(
    " Extract the public key from an asymmetric key.\n"
    "\n"
    " For private keys, extracts the corresponding public key.\n"
    " For public keys, returns the key unchanged.\n"
    " Returns an error for symmetric octet keys.\n"
    "\n"
    " When extracting a public key, `key_ops` are filtered to public-safe operations:\n"
    " - `Sign` is mapped to `Verify`\n"
    " - `Decrypt` and `UnwrapKey` are removed (private-only)\n"
    " - Other operations are preserved\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let private_key = gose.generate_ec(ec.P256)\n"
    " let assert Ok(pub_key) = gose.public_key(private_key)\n"
    " ```\n"
).
-spec public_key(key(JZU)) -> {ok, key(JZU)} | {error, gose_error()}.
public_key(Key) ->
    Filtered_ops = begin
        _pipe = erlang:element(5, Key),
        _pipe@1 = gleam@option:map(_pipe, fun filter_public_key_ops/1),
        gleam@option:then(_pipe@1, fun gleam@option:from_result/1)
    end,
    case erlang:element(2, Key) of
        {rsa, {rsa_private, _, Public}} ->
            {ok,
                {key,
                    {rsa, {rsa_public, Public}},
                    erlang:element(3, Key),
                    erlang:element(4, Key),
                    Filtered_ops,
                    erlang:element(6, Key)}};

        {rsa, {rsa_public, _}} ->
            {ok,
                {key,
                    erlang:element(2, Key),
                    erlang:element(3, Key),
                    erlang:element(4, Key),
                    Filtered_ops,
                    erlang:element(6, Key)}};

        {elliptic, {ec_private, _, Public@1, Curve}} ->
            {ok,
                {key,
                    {elliptic, {ec_public, Public@1, Curve}},
                    erlang:element(3, Key),
                    erlang:element(4, Key),
                    Filtered_ops,
                    erlang:element(6, Key)}};

        {elliptic, {ec_public, _, _}} ->
            {ok,
                {key,
                    erlang:element(2, Key),
                    erlang:element(3, Key),
                    erlang:element(4, Key),
                    Filtered_ops,
                    erlang:element(6, Key)}};

        {edwards, {eddsa_private, _, Public@2, Curve@1}} ->
            {ok,
                {key,
                    {edwards, {eddsa_public, Public@2, Curve@1}},
                    erlang:element(3, Key),
                    erlang:element(4, Key),
                    Filtered_ops,
                    erlang:element(6, Key)}};

        {edwards, {eddsa_public, _, _}} ->
            {ok,
                {key,
                    erlang:element(2, Key),
                    erlang:element(3, Key),
                    erlang:element(4, Key),
                    Filtered_ops,
                    erlang:element(6, Key)}};

        {xdh, {xdh_private, _, Public@3, Curve@2}} ->
            {ok,
                {key,
                    {xdh, {xdh_public, Public@3, Curve@2}},
                    erlang:element(3, Key),
                    erlang:element(4, Key),
                    Filtered_ops,
                    erlang:element(6, Key)}};

        {xdh, {xdh_public, _, _}} ->
            {ok,
                {key,
                    erlang:element(2, Key),
                    erlang:element(3, Key),
                    erlang:element(4, Key),
                    Filtered_ops,
                    erlang:element(6, Key)}};

        {octet_key, _} ->
            {error, {invalid_state, <<"octet keys are not asymmetric"/utf8>>}}
    end.

-file("src/gose.gleam", 1129).
?DOC(
    " Serialize a key to DER format.\n"
    "\n"
    " Supports RSA, EC, EdDSA, and XDH keys (both private and public).\n"
    " Uses PKCS#8 for private keys and SPKI for public keys.\n"
).
-spec to_der(key(any())) -> {ok, bitstring()} | {error, gose_error()}.
to_der(Key) ->
    case erlang:element(2, Key) of
        {rsa, {rsa_private, Private, _}} ->
            _pipe = kryptos_ffi:rsa_export_private_key_der(Private, pkcs8),
            gleam@result:replace_error(
                _pipe,
                {invalid_state, <<"failed to serialize RSA private key"/utf8>>}
            );

        {rsa, {rsa_public, Public}} ->
            _pipe@1 = kryptos_ffi:rsa_export_public_key_der(Public, spki),
            gleam@result:replace_error(
                _pipe@1,
                {invalid_state, <<"failed to serialize RSA public key"/utf8>>}
            );

        {elliptic, {ec_private, Private@1, _, _}} ->
            _pipe@2 = kryptos_ffi:ec_export_private_key_der(Private@1),
            gleam@result:replace_error(
                _pipe@2,
                {invalid_state, <<"failed to serialize EC private key"/utf8>>}
            );

        {elliptic, {ec_public, Public@1, _}} ->
            _pipe@3 = kryptos_ffi:ec_export_public_key_der(Public@1),
            gleam@result:replace_error(
                _pipe@3,
                {invalid_state, <<"failed to serialize EC public key"/utf8>>}
            );

        {edwards, {eddsa_private, Private@2, _, _}} ->
            _pipe@4 = kryptos_ffi:eddsa_export_private_key_der(Private@2),
            gleam@result:replace_error(
                _pipe@4,
                {invalid_state,
                    <<"failed to serialize EdDSA private key"/utf8>>}
            );

        {edwards, {eddsa_public, Public@2, _}} ->
            _pipe@5 = kryptos_ffi:eddsa_export_public_key_der(Public@2),
            gleam@result:replace_error(
                _pipe@5,
                {invalid_state, <<"failed to serialize EdDSA public key"/utf8>>}
            );

        {xdh, {xdh_private, Private@3, _, _}} ->
            _pipe@6 = kryptos_ffi:xdh_export_private_key_der(Private@3),
            gleam@result:replace_error(
                _pipe@6,
                {invalid_state, <<"failed to serialize XDH private key"/utf8>>}
            );

        {xdh, {xdh_public, Public@3, _}} ->
            _pipe@7 = kryptos_ffi:xdh_export_public_key_der(Public@3),
            gleam@result:replace_error(
                _pipe@7,
                {invalid_state, <<"failed to serialize XDH public key"/utf8>>}
            );

        {octet_key, _} ->
            {error,
                {invalid_state,
                    <<"octet keys cannot be serialized to DER"/utf8>>}}
    end.

-file("src/gose.gleam", 1174).
?DOC(
    " Export the raw bytes of a key.\n"
    "\n"
    " Supported key types:\n"
    " - Octet keys: returns the secret bytes\n"
    " - EdDSA/XDH private keys: returns the private key bytes (d)\n"
    " - EdDSA/XDH public keys: returns the public key bytes (x)\n"
).
-spec to_octet_bits(key(any())) -> {ok, bitstring()} | {error, gose_error()}.
to_octet_bits(Key) ->
    case erlang:element(2, Key) of
        {octet_key, Secret} ->
            {ok, Secret};

        {edwards, {eddsa_private, Private, _, _}} ->
            {ok, kryptos_ffi:eddsa_private_key_to_bytes(Private)};

        {edwards, {eddsa_public, Public, _}} ->
            {ok, kryptos_ffi:eddsa_public_key_to_bytes(Public)};

        {xdh, {xdh_private, Private@1, _, _}} ->
            {ok, kryptos_ffi:xdh_private_key_to_bytes(Private@1)};

        {xdh, {xdh_public, Public@1, _}} ->
            {ok, kryptos_ffi:xdh_public_key_to_bytes(Public@1)};

        {rsa, _} ->
            {error,
                {invalid_state,
                    <<"key has no single-value byte representation"/utf8>>}};

        {elliptic, _} ->
            {error,
                {invalid_state,
                    <<"key has no single-value byte representation"/utf8>>}}
    end.

-file("src/gose.gleam", 1191).
?DOC(
    " Serialize a key to PEM format.\n"
    "\n"
    " Supports RSA, EC, EdDSA, and XDH keys (both private and public).\n"
    " Uses PKCS#8 for private keys and SPKI for public keys.\n"
).
-spec to_pem(key(any())) -> {ok, binary()} | {error, gose_error()}.
to_pem(Key) ->
    case erlang:element(2, Key) of
        {rsa, {rsa_private, Private, _}} ->
            _pipe = kryptos@rsa:to_pem(Private, pkcs8),
            gleam@result:replace_error(
                _pipe,
                {invalid_state, <<"failed to serialize RSA private key"/utf8>>}
            );

        {rsa, {rsa_public, Public}} ->
            _pipe@1 = kryptos@rsa:public_key_to_pem(Public, spki),
            gleam@result:replace_error(
                _pipe@1,
                {invalid_state, <<"failed to serialize RSA public key"/utf8>>}
            );

        {elliptic, {ec_private, Private@1, _, _}} ->
            _pipe@2 = kryptos@ec:to_pem(Private@1),
            gleam@result:replace_error(
                _pipe@2,
                {invalid_state, <<"failed to serialize EC private key"/utf8>>}
            );

        {elliptic, {ec_public, Public@1, _}} ->
            _pipe@3 = kryptos@ec:public_key_to_pem(Public@1),
            gleam@result:replace_error(
                _pipe@3,
                {invalid_state, <<"failed to serialize EC public key"/utf8>>}
            );

        {edwards, {eddsa_private, Private@2, _, _}} ->
            _pipe@4 = kryptos@eddsa:to_pem(Private@2),
            gleam@result:replace_error(
                _pipe@4,
                {invalid_state,
                    <<"failed to serialize EdDSA private key"/utf8>>}
            );

        {edwards, {eddsa_public, Public@2, _}} ->
            _pipe@5 = kryptos@eddsa:public_key_to_pem(Public@2),
            gleam@result:replace_error(
                _pipe@5,
                {invalid_state, <<"failed to serialize EdDSA public key"/utf8>>}
            );

        {xdh, {xdh_private, Private@3, _, _}} ->
            _pipe@6 = kryptos@xdh:to_pem(Private@3),
            gleam@result:replace_error(
                _pipe@6,
                {invalid_state, <<"failed to serialize XDH private key"/utf8>>}
            );

        {xdh, {xdh_public, Public@3, _}} ->
            _pipe@7 = kryptos@xdh:public_key_to_pem(Public@3),
            gleam@result:replace_error(
                _pipe@7,
                {invalid_state, <<"failed to serialize XDH public key"/utf8>>}
            );

        {octet_key, _} ->
            {error,
                {invalid_state,
                    <<"octet keys cannot be serialized to PEM"/utf8>>}}
    end.

-file("src/gose.gleam", 1231).
?DOC(false).
-spec build(
    key_material(),
    gleam@option:option(KAR),
    gleam@option:option(key_use()),
    gleam@option:option(list(key_op())),
    gleam@option:option(alg())
) -> key(KAR).
build(Material, Kid, Key_use, Key_ops, Alg) ->
    {key, Material, Kid, Key_use, Key_ops, Alg}.

-file("src/gose.gleam", 1242).
?DOC(false).
-spec validate_rfc8037_key_use_public(
    key_material(),
    gleam@option:option(key_use())
) -> {ok, nil} | {error, gose_error()}.
validate_rfc8037_key_use_public(Material, Use_) ->
    validate_rfc8037_key_use(Material, Use_).

-file("src/gose.gleam", 1250).
?DOC(false).
-spec aes_key_size(aes_key_size()) -> integer().
aes_key_size(Size) ->
    case Size of
        aes128 ->
            16;

        aes192 ->
            24;

        aes256 ->
            32
    end.

-file("src/gose.gleam", 698).
?DOC(
    " Generate a symmetric key for AES Key Wrap.\n"
    "\n"
    " The key size is derived from the AES variant:\n"
    " - `Aes128` → 16 bytes\n"
    " - `Aes192` → 24 bytes\n"
    " - `Aes256` → 32 bytes\n"
).
-spec generate_aes_kw_key(aes_key_size()) -> key(any()).
generate_aes_kw_key(Size) ->
    Byte_count = aes_key_size(Size),
    Secret = kryptos_ffi:random_bytes(Byte_count),
    new_key({octet_key, Secret}).

-file("src/gose.gleam", 1259).
?DOC(false).
-spec hmac_alg_key_size(hmac_alg()) -> integer().
hmac_alg_key_size(Alg) ->
    case Alg of
        hmac_sha256 ->
            32;

        hmac_sha384 ->
            48;

        hmac_sha512 ->
            64
    end.

-file("src/gose.gleam", 669).
?DOC(
    " Generate a symmetric key for HMAC signing.\n"
    "\n"
    " The key size is derived from the algorithm:\n"
    " - `HmacSha256` → 32 bytes\n"
    " - `HmacSha384` → 48 bytes\n"
    " - `HmacSha512` → 64 bytes\n"
).
-spec generate_hmac_key(hmac_alg()) -> key(any()).
generate_hmac_key(Alg) ->
    Size = hmac_alg_key_size(Alg),
    Secret = kryptos_ffi:random_bytes(Size),
    new_key({octet_key, Secret}).

-file("src/gose.gleam", 1268).
?DOC(false).
-spec content_alg_key_size(content_alg()) -> integer().
content_alg_key_size(Enc) ->
    case Enc of
        {aes_gcm, Size} ->
            aes_key_size(Size);

        {aes_cbc_hmac, Size@1} ->
            aes_key_size(Size@1) * 2;

        cha_cha20_poly1305 ->
            32;

        x_cha_cha20_poly1305 ->
            32
    end.

-file("src/gose.gleam", 686).
?DOC(
    " Generate a symmetric key for JWE content encryption.\n"
    "\n"
    " The key size is derived from the encryption algorithm:\n"
    " - `AesGcm(Aes128)` → 16 bytes\n"
    " - `AesGcm(Aes192)` → 24 bytes\n"
    " - `AesGcm(Aes256)` → 32 bytes\n"
    " - `AesCbcHmac(Aes128)` → 32 bytes (16 + 16 for MAC)\n"
    " - `AesCbcHmac(Aes192)` → 48 bytes (24 + 24 for MAC)\n"
    " - `AesCbcHmac(Aes256)` → 64 bytes (32 + 32 for MAC)\n"
    " - `ChaCha20Poly1305` → 32 bytes\n"
    " - `XChaCha20Poly1305` → 32 bytes\n"
).
-spec generate_enc_key(content_alg()) -> key(any()).
generate_enc_key(Enc) ->
    Size = content_alg_key_size(Enc),
    Secret = kryptos_ffi:random_bytes(Size),
    new_key({octet_key, Secret}).

-file("src/gose.gleam", 1278).
?DOC(false).
-spec chacha20_kw_nonce_size(cha_cha20_kw()) -> integer().
chacha20_kw_nonce_size(Variant) ->
    case Variant of
        c20_p_kw ->
            12;

        x_c20_p_kw ->
            24
    end.
