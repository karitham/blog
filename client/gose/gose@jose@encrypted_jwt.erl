-module(gose@jose@encrypted_jwt).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/encrypted_jwt.gleam").
-export([key_decryptor/4, password_decryptor/4, encrypt_with_key/4, encrypt_with_password/5, serialize/1, peek_headers/1, decode/2, alg/1, enc/1, kid/1, dangerously_decrypt_and_skip_validation/2, decrypt_and_validate/3]).
-export_type([encrypted_jwt/0, decryptor/0, peek_headers/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Encrypted JWT (JWE-based) - [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519.html)\n"
    "\n"
    " Encrypted JWTs built on JWE protect the claims payload through\n"
    " encryption, providing confidentiality and ciphertext integrity.\n"
    " **Encryption alone does not\n"
    " authenticate the issuer.** For asymmetric algorithms (RSA-OAEP, ECDH-ES),\n"
    " anyone with the recipient's public key can produce a valid encrypted token.\n"
    "\n"
    " If your application requires proof of origin, use sign-then-encrypt\n"
    " (nested JWT): sign the claims with JWS first, then encrypt the signed\n"
    " token with JWE.\n"
    "\n"
    " Use `peek_headers()` to inspect a token's headers without decrypting.\n"
    " Use `decrypt_and_validate()` to decrypt and validate claim fields (exp,\n"
    " nbf, iss, aud), producing an `EncryptedJwt` whose claims have been\n"
    " decrypted and validated.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gleam/dynamic/decode\n"
    " import gleam/time/duration\n"
    " import gleam/time/timestamp\n"
    " import gose\n"
    " import gose/jose/encrypted_jwt\n"
    " import gose/jose/jwt\n"
    "\n"
    " let key = gose.generate_enc_key(gose.AesGcm(gose.Aes256))\n"
    " let now = timestamp.system_time()\n"
    "\n"
    " // Create claims and encrypt\n"
    " let claims = jwt.claims()\n"
    "   |> jwt.with_subject(\"user123\")\n"
    "   |> jwt.with_issuer(\"my-app\")\n"
    "   |> jwt.with_expiration(timestamp.add(now, duration.hours(1)))\n"
    "\n"
    " let assert Ok(encrypted) =\n"
    "   encrypted_jwt.encrypt_with_key(\n"
    "     claims,\n"
    "     gose.Direct,\n"
    "     gose.AesGcm(gose.Aes256),\n"
    "     key,\n"
    "   )\n"
    " let token = encrypted_jwt.serialize(encrypted)\n"
    "\n"
    " // Decrypt and validate using Decryptor (enforces algorithm pinning)\n"
    " let assert Ok(decryptor) =\n"
    "   encrypted_jwt.key_decryptor(\n"
    "     alg: gose.Direct,\n"
    "     enc: gose.AesGcm(gose.Aes256),\n"
    "     keys: [key],\n"
    "     options: jwt.default_validation(),\n"
    "   )\n"
    " let assert Ok(decrypted) =\n"
    "   encrypted_jwt.decrypt_and_validate(decryptor, token, now)\n"
    "\n"
    " // Decode decrypted and validated claims\n"
    " let decoder = decode.field(\"sub\", decode.string, decode.success)\n"
    " let assert Ok(subject) = encrypted_jwt.decode(decrypted, decoder)\n"
    " ```\n"
).

-opaque encrypted_jwt() :: {encrypted_jwt,
        gose:key_encryption_alg(),
        gose:content_alg(),
        gleam@option:option(binary()),
        gose@jose@jwt:claims(),
        bitstring(),
        binary()}.

-opaque decryptor() :: {key_decryptor,
        gose:key_encryption_alg(),
        gose:content_alg(),
        list(gose:key(binary())),
        gose@jose@jwt:jwt_validation_options()} |
    {password_decryptor,
        gose:pbes2_alg(),
        gose:content_alg(),
        binary(),
        gose@jose@jwt:jwt_validation_options()}.

-type peek_headers() :: {peek_headers,
        gose:key_encryption_alg(),
        gose:content_alg(),
        gleam@option:option(binary())}.

-file("src/gose/jose/encrypted_jwt.gleam", 111).
-spec validate_decryption_keys(
    gose:key_encryption_alg(),
    list(gose:key(binary()))
) -> {ok, nil} | {error, gose:gose_error()}.
validate_decryption_keys(Alg, Keys) ->
    gose@internal@key_helpers:require_non_empty_keys(
        Keys,
        fun() ->
            gleam@list:try_each(
                Keys,
                fun(_capture) ->
                    gose@internal@key_helpers:validate_key_for_jwe_decryption(
                        Alg,
                        _capture
                    )
                end
            )
        end
    ).

-file("src/gose/jose/encrypted_jwt.gleam", 124).
?DOC(
    " Create a key-based decryptor for symmetric (dir, AES-KW, AES-GCM-KW) or\n"
    " asymmetric (RSA-OAEP, ECDH-ES) algorithms.\n"
    "\n"
    " The decryptor pins the expected algorithms. Tokens with different\n"
    " algorithms will be rejected.\n"
).
-spec key_decryptor(
    gose:key_encryption_alg(),
    gose:content_alg(),
    list(gose:key(binary())),
    gose@jose@jwt:jwt_validation_options()
) -> {ok, decryptor()} | {error, gose@jose@jwt:jwt_error()}.
key_decryptor(Alg, Enc, Keys, Options) ->
    _pipe = validate_decryption_keys(Alg, Keys),
    _pipe@1 = gleam@result:replace(
        _pipe,
        {key_decryptor, Alg, Enc, Keys, Options}
    ),
    gleam@result:map_error(_pipe@1, fun(Field@0) -> {jose_error, Field@0} end).

-file("src/gose/jose/encrypted_jwt.gleam", 139).
?DOC(
    " Create a password-based decryptor for PBES2 algorithms.\n"
    "\n"
    " The decryptor pins the expected algorithms. Tokens with different\n"
    " algorithms will be rejected.\n"
).
-spec password_decryptor(
    gose:pbes2_alg(),
    gose:content_alg(),
    binary(),
    gose@jose@jwt:jwt_validation_options()
) -> decryptor().
password_decryptor(Alg, Enc, Password, Options) ->
    {password_decryptor, Alg, Enc, Password, Options}.

-file("src/gose/jose/encrypted_jwt.gleam", 239).
-spec claims_to_plaintext(gose@jose@jwt:claims()) -> bitstring().
claims_to_plaintext(Claims) ->
    _pipe = gose@jose@jwt:claims_to_json_string(Claims),
    gleam_stdlib:identity(_pipe).

-file("src/gose/jose/encrypted_jwt.gleam", 167).
-spec do_encrypt_with_key(
    gose@jose@jwt:claims(),
    gose:key_encryption_alg(),
    gose:content_alg(),
    gose:key(binary()),
    gleam@option:option(binary())
) -> {ok, encrypted_jwt()} | {error, gose:gose_error()}.
do_encrypt_with_key(Claims, Alg, Enc, Key, Kid) ->
    Claims_json = claims_to_plaintext(Claims),
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(Alg, Key),
        fun(_) ->
            _pipe = gose@jose@jwe:encrypt_to_compact(
                Alg,
                Enc,
                Claims_json,
                Key,
                Kid,
                {some, <<"JWT"/utf8>>},
                none
            ),
            gleam@result:map(
                _pipe,
                fun(Pair) ->
                    {Token, Jwe_alg} = Pair,
                    {encrypted_jwt,
                        Jwe_alg,
                        Enc,
                        Kid,
                        Claims,
                        Claims_json,
                        Token}
                end
            )
        end
    ).

-file("src/gose/jose/encrypted_jwt.gleam", 156).
?DOC(
    " Encrypt claims using a key-based algorithm.\n"
    "\n"
    " Supports all key-based JWE algorithms: direct symmetric (dir), AES Key Wrap,\n"
    " AES-GCM Key Wrap, RSA-OAEP, and ECDH-ES. PBES2 password-based algorithms\n"
    " return an error. Use `encrypt_with_password` for those.\n"
    "\n"
    " Sets `typ: \"JWT\"` in the header. If the encryption key has a `kid`, it is\n"
    " included in the JWE header.\n"
).
-spec encrypt_with_key(
    gose@jose@jwt:claims(),
    gose:key_encryption_alg(),
    gose:content_alg(),
    gose:key(binary())
) -> {ok, encrypted_jwt()} | {error, gose@jose@jwt:jwt_error()}.
encrypt_with_key(Claims, Alg, Enc, Key) ->
    Kid = gleam@option:from_result(gose:kid(Key)),
    _pipe = do_encrypt_with_key(Claims, Alg, Enc, Key, Kid),
    gleam@result:map_error(_pipe, fun(Field@0) -> {jose_error, Field@0} end).

-file("src/gose/jose/encrypted_jwt.gleam", 205).
-spec do_encrypt_with_password(
    gose@jose@jwt:claims(),
    gose:pbes2_alg(),
    gose:content_alg(),
    binary(),
    gleam@option:option(binary())
) -> {ok, encrypted_jwt()} | {error, gose:gose_error()}.
do_encrypt_with_password(Claims, Alg, Enc, Password, Kid) ->
    Claims_json = claims_to_plaintext(Claims),
    Unencrypted = begin
        _pipe = gose@jose@jwe:new_pbes2(Alg, Enc),
        gose@jose@jwe:with_typ(_pipe, <<"JWT"/utf8>>)
    end,
    Unencrypted@1 = case Kid of
        {some, K} ->
            gose@jose@jwe:with_kid(Unencrypted, K);

        none ->
            Unencrypted
    end,
    gleam@result:'try'(
        gose@jose@jwe:encrypt_with_password(
            Unencrypted@1,
            Password,
            Claims_json
        ),
        fun(Encrypted) -> _pipe@1 = gose@jose@jwe:serialize_compact(Encrypted),
            gleam@result:map(
                _pipe@1,
                fun(Token) ->
                    {encrypted_jwt,
                        gose@jose@jwe:alg(Encrypted),
                        Enc,
                        Kid,
                        Claims,
                        Claims_json,
                        Token}
                end
            ) end
    ).

-file("src/gose/jose/encrypted_jwt.gleam", 194).
?DOC(
    " Encrypt claims using PBES2 password-based encryption.\n"
    "\n"
    " Sets `typ: \"JWT\"` in the header.\n"
).
-spec encrypt_with_password(
    gose@jose@jwt:claims(),
    gose:pbes2_alg(),
    gose:content_alg(),
    binary(),
    gleam@option:option(binary())
) -> {ok, encrypted_jwt()} | {error, gose@jose@jwt:jwt_error()}.
encrypt_with_password(Claims, Alg, Enc, Password, Kid) ->
    _pipe = do_encrypt_with_password(Claims, Alg, Enc, Password, Kid),
    gleam@result:map_error(_pipe, fun(Field@0) -> {jose_error, Field@0} end).

-file("src/gose/jose/encrypted_jwt.gleam", 245).
?DOC(" Return the compact serialization of an encrypted JWT.\n").
-spec serialize(encrypted_jwt()) -> binary().
serialize(Jwt) ->
    erlang:element(7, Jwt).

-file("src/gose/jose/encrypted_jwt.gleam", 270).
-spec parse_jwe(binary()) -> {ok,
        gose@jose@jwe:jwe(gose@jose@jwe:encrypted(), nil, gose@jose@jwe:parsed())} |
    {error, gose@jose@jwt:jwt_error()}.
parse_jwe(Token) ->
    _pipe = gose@jose@jwe:parse_compact(Token),
    gleam@result:map_error(
        _pipe,
        fun gose@jose@jwt:gose_error_to_malformed_token_error/1
    ).

-file("src/gose/jose/encrypted_jwt.gleam", 259).
?DOC(" Peek at the header fields from a token without decrypting.\n").
-spec peek_headers(binary()) -> {ok, peek_headers()} |
    {error, gose@jose@jwt:jwt_error()}.
peek_headers(Token) ->
    _pipe = parse_jwe(Token),
    gleam@result:map(
        _pipe,
        fun(Parsed_jwe) ->
            {peek_headers,
                gose@jose@jwe:alg(Parsed_jwe),
                gose@jose@jwe:enc(Parsed_jwe),
                gleam@option:from_result(gose@jose@jwe:kid(Parsed_jwe))}
        end
    ).

-file("src/gose/jose/encrypted_jwt.gleam", 343).
?DOC(
    " Decode an encrypted JWT's claims using a custom decoder.\n"
    "\n"
    " This allows extracting claims directly into your own types using\n"
    " `gleam/dynamic/decode`. The decoder receives the raw claims JSON.\n"
).
-spec decode(encrypted_jwt(), gleam@dynamic@decode:decoder(YAR)) -> {ok, YAR} |
    {error, gose@jose@jwt:jwt_error()}.
decode(Jwt, Decoder) ->
    _pipe = gleam@json:parse_bits(erlang:element(6, Jwt), Decoder),
    gleam@result:replace_error(
        _pipe,
        {claim_decoding_failed, <<"failed to decode claims"/utf8>>}
    ).

-file("src/gose/jose/encrypted_jwt.gleam", 352).
?DOC(" Get the key encryption algorithm (`alg`) from a decrypted and validated encrypted JWT.\n").
-spec alg(encrypted_jwt()) -> gose:key_encryption_alg().
alg(Jwt) ->
    erlang:element(2, Jwt).

-file("src/gose/jose/encrypted_jwt.gleam", 357).
?DOC(" Get the content encryption algorithm (`enc`) from a decrypted and validated encrypted JWT.\n").
-spec enc(encrypted_jwt()) -> gose:content_alg().
enc(Jwt) ->
    erlang:element(3, Jwt).

-file("src/gose/jose/encrypted_jwt.gleam", 366).
?DOC(
    " Get the key ID (kid) from a decrypted and validated encrypted JWT header.\n"
    "\n"
    " **Security Warning:** The `kid` value comes from the token and is untrusted\n"
    " input. If you use it to look up keys (from a database, filesystem, or key\n"
    " store), you must sanitize it first to prevent injection attacks.\n"
).
-spec kid(encrypted_jwt()) -> {ok, binary()} | {error, nil}.
kid(Jwt) ->
    gleam@option:to_result(erlang:element(4, Jwt), nil).

-file("src/gose/jose/encrypted_jwt.gleam", 370).
-spec decryptor_options(decryptor()) -> gose@jose@jwt:jwt_validation_options().
decryptor_options(Decryptor) ->
    erlang:element(5, Decryptor).

-file("src/gose/jose/encrypted_jwt.gleam", 415).
-spec build_jwe_decryptor(decryptor(), list(gose:key(binary()))) -> {ok,
        gose@jose@jwe:decryptor()} |
    {error, gose@jose@jwt:jwt_error()}.
build_jwe_decryptor(Decryptor, Decryption_keys) ->
    case Decryptor of
        {key_decryptor, Alg, Enc, _, _} ->
            _pipe = gose@jose@jwe:key_decryptor(Alg, Enc, Decryption_keys),
            gleam@result:map_error(
                _pipe,
                fun(Field@0) -> {jose_error, Field@0} end
            );

        {password_decryptor, Alg@1, Enc@1, Password, _} ->
            {ok, gose@jose@jwe:password_decryptor(Alg@1, Enc@1, Password)}
    end.

-file("src/gose/jose/encrypted_jwt.gleam", 428).
-spec gose_error_to_decryption_failed(gose:gose_error()) -> gose@jose@jwt:jwt_error().
gose_error_to_decryption_failed(Err) ->
    {decryption_failed, gose:error_message(Err)}.

-file("src/gose/jose/encrypted_jwt.gleam", 432).
-spec parse_plaintext_claims(bitstring()) -> {ok, gose@jose@jwt:claims()} |
    {error, gose@jose@jwt:jwt_error()}.
parse_plaintext_claims(Plaintext) ->
    gose@jose@jwt:parse_claims_bits(Plaintext).

-file("src/gose/jose/encrypted_jwt.gleam", 438).
-spec require_matching_algorithms(
    decryptor(),
    gose:key_encryption_alg(),
    gose:content_alg()
) -> {ok, nil} | {error, gose@jose@jwt:jwt_error()}.
require_matching_algorithms(Decryptor, Actual_alg, Actual_enc) ->
    {Expected_alg, Expected_enc} = case Decryptor of
        {key_decryptor, Alg, Enc, _, _} ->
            {Alg, Enc};

        {password_decryptor, Alg@1, Enc@1, _, _} ->
            {{pbes2, Alg@1}, Enc@1}
    end,
    case (Expected_alg /= Actual_alg) orelse (Expected_enc /= Actual_enc) of
        true ->
            {error,
                {jwe_algorithm_mismatch,
                    Expected_alg,
                    Expected_enc,
                    Actual_alg,
                    Actual_enc}};

        false ->
            {ok, nil}
    end.

-file("src/gose/jose/encrypted_jwt.gleam", 460).
-spec select_decryption_keys(
    decryptor(),
    gleam@option:option(binary()),
    gose@jose@jwt:kid_policy()
) -> {ok, list(gose:key(binary()))} | {error, gose@jose@jwt:jwt_error()}.
select_decryption_keys(Decryptor, Token_kid, Kid_policy) ->
    case Decryptor of
        {password_decryptor, _, _, _, _} ->
            {ok, []};

        {key_decryptor, _, _, Keys, _} ->
            gose@jose@jwt:select_keys_by_policy(Keys, Token_kid, Kid_policy)
    end.

-file("src/gose/jose/encrypted_jwt.gleam", 374).
-spec decrypt_token(decryptor(), binary()) -> {ok,
        {bitstring(),
            gose:key_encryption_alg(),
            gose:content_alg(),
            gleam@option:option(binary())}} |
    {error, gose@jose@jwt:jwt_error()}.
decrypt_token(Decryptor, Token) ->
    gleam@result:'try'(
        begin
            _pipe = gose@jose@jwe:parse_compact(Token),
            gleam@result:map_error(
                _pipe,
                fun gose@jose@jwt:gose_error_to_malformed_token_error/1
            )
        end,
        fun(Parsed_jwe) ->
            Actual_alg = gose@jose@jwe:alg(Parsed_jwe),
            Actual_enc = gose@jose@jwe:enc(Parsed_jwe),
            Token_kid = gleam@option:from_result(gose@jose@jwe:kid(Parsed_jwe)),
            gleam@result:'try'(
                require_matching_algorithms(Decryptor, Actual_alg, Actual_enc),
                fun(_) ->
                    Options = decryptor_options(Decryptor),
                    gleam@result:'try'(
                        select_decryption_keys(
                            Decryptor,
                            Token_kid,
                            erlang:element(8, Options)
                        ),
                        fun(Decryption_keys) ->
                            gleam@result:'try'(
                                build_jwe_decryptor(Decryptor, Decryption_keys),
                                fun(Jwe_decryptor) ->
                                    gleam@result:'try'(
                                        begin
                                            _pipe@1 = gose@jose@jwe:decrypt(
                                                Jwe_decryptor,
                                                Parsed_jwe
                                            ),
                                            gleam@result:map_error(
                                                _pipe@1,
                                                fun gose_error_to_decryption_failed/1
                                            )
                                        end,
                                        fun(Plaintext) ->
                                            {ok,
                                                {Plaintext,
                                                    Actual_alg,
                                                    Actual_enc,
                                                    Token_kid}}
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

-file("src/gose/jose/encrypted_jwt.gleam", 285).
?DOC(
    " Decrypt an encrypted JWT, skipping all claim validation.\n"
    "\n"
    " **Warning:** This skips expiration, not-before, issuer, and audience checks.\n"
    " Use only when you have a legitimate reason to bypass validation, such as\n"
    " inspecting claims before deciding on validation policy.\n"
    "\n"
    " Still enforces algorithm pinning for security. **Note:** `kid_policy` only\n"
    " applies to key-based decryptors, not password-based decryptors.\n"
).
-spec dangerously_decrypt_and_skip_validation(decryptor(), binary()) -> {ok,
        encrypted_jwt()} |
    {error, gose@jose@jwt:jwt_error()}.
dangerously_decrypt_and_skip_validation(Decryptor, Token) ->
    gleam@result:'try'(
        decrypt_token(Decryptor, Token),
        fun(_use0) ->
            {Plaintext, Actual_alg, Actual_enc, Kid} = _use0,
            _pipe = parse_plaintext_claims(Plaintext),
            gleam@result:map(
                _pipe,
                fun(Claims) ->
                    {encrypted_jwt,
                        Actual_alg,
                        Actual_enc,
                        Kid,
                        Claims,
                        Plaintext,
                        Token}
                end
            )
        end
    ).

-file("src/gose/jose/encrypted_jwt.gleam", 317).
?DOC(
    " Decrypt an encrypted JWT and validate its claims using a Decryptor.\n"
    "\n"
    " Checks:\n"
    " 1. Token's `alg` and `enc` headers match the decryptor's expected algorithms\n"
    " 2. Decryption succeeds with one of the decryptor's keys\n"
    " 3. Claims pass validation (exp, nbf, iss, aud per options)\n"
    "\n"
    " When multiple keys are configured:\n"
    " - Keys with matching `kid` are tried first (if token has `kid` header)\n"
    " - `kid_policy` controls kid header enforcement (see `KidPolicy` type)\n"
    " - With `NoKidRequirement`, all keys are tried with matching keys prioritized\n"
).
-spec decrypt_and_validate(
    decryptor(),
    binary(),
    gleam@time@timestamp:timestamp()
) -> {ok, encrypted_jwt()} | {error, gose@jose@jwt:jwt_error()}.
decrypt_and_validate(Decryptor, Token, Now) ->
    gleam@result:'try'(
        decrypt_token(Decryptor, Token),
        fun(_use0) ->
            {Plaintext, Actual_alg, Actual_enc, Kid} = _use0,
            gleam@result:'try'(
                parse_plaintext_claims(Plaintext),
                fun(Claims) ->
                    Options = decryptor_options(Decryptor),
                    _pipe = gose@jose@jwt:validate_claims(Claims, Now, Options),
                    gleam@result:replace(
                        _pipe,
                        {encrypted_jwt,
                            Actual_alg,
                            Actual_enc,
                            Kid,
                            Claims,
                            Plaintext,
                            Token}
                    )
                end
            )
        end
    ).
