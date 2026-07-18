-module(gose@jose@jwt).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/jwt.gleam").
-export([gose_error_to_malformed_token_error/1, default_validation/0, with_jti_validator/2, with_max_token_age/2, verifier/3, claims/0, with_audience/2, with_audiences/2, with_expiration/2, with_issued_at/2, with_issuer/2, with_jwt_id/2, with_not_before/2, with_subject/2, alg/1, kid/1, select_keys_by_policy/3, serialize/1, sign/3, claims_to_json_string/1, dangerously_decode_unverified/2, decode/2, parse_claims_bits/1, verify_and_dangerously_skip_validation/2, parse/1, validate_claims/3, verify_and_validate/3, with_claim/3]).
-export_type([jwt_error/0, unverified/0, verified/0, claims/0, jwt/1, kid_policy/0, jwt_validation_options/0, verifier/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " JSON Web Token (JWT) - [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519.html)\n"
    "\n"
    " Claims-based tokens built on JWS for signing and verification. JWTs are\n"
    " a compact, URL-safe means of representing claims to be transferred\n"
    " between two parties.\n"
    "\n"
    " ## Phantom Types\n"
    "\n"
    " JWT uses phantom types to enforce compile-time safety:\n"
    " - `Jwt(Unverified)` - A JWT that has been parsed but not yet verified\n"
    " - `Jwt(Verified)` - A JWT with verified signature, safe to trust claims\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gleam/dynamic/decode\n"
    " import gleam/time/duration\n"
    " import gleam/time/timestamp\n"
    " import gose\n"
    " import gose/jose/jwt\n"
    "\n"
    " let signing_key = gose.generate_hmac_key(gose.HmacSha256)\n"
    " let now = timestamp.system_time()\n"
    "\n"
    " // Create claims and sign\n"
    " let claims = jwt.claims()\n"
    "   |> jwt.with_subject(\"user123\")\n"
    "   |> jwt.with_issuer(\"my-app\")\n"
    "   |> jwt.with_expiration(timestamp.add(now, duration.hours(1)))\n"
    "\n"
    " let assert Ok(signed) =\n"
    "   jwt.sign(\n"
    "     gose.Mac(gose.Hmac(gose.HmacSha256)),\n"
    "     claims:,\n"
    "     key: signing_key,\n"
    "   )\n"
    " let token = jwt.serialize(signed)\n"
    "\n"
    " // Verify and validate using Verifier (enforces algorithm pinning)\n"
    " let assert Ok(verifier) =\n"
    "   jwt.verifier(\n"
    "     gose.Mac(gose.Hmac(gose.HmacSha256)),\n"
    "     keys: [signing_key],\n"
    "     options: jwt.default_validation(),\n"
    "   )\n"
    " let assert Ok(verified) = jwt.verify_and_validate(verifier, token:, now:)\n"
    "\n"
    " // Decode verified claims\n"
    " let decoder = {\n"
    "   use sub <- decode.field(\"sub\", decode.string)\n"
    "   decode.success(sub)\n"
    " }\n"
    " let assert Ok(subject) = jwt.decode(verified, decoder)\n"
    " ```\n"
).

-type jwt_error() :: invalid_signature |
    {decryption_failed, binary()} |
    {token_expired, gleam@time@timestamp:timestamp()} |
    {token_not_yet_valid, gleam@time@timestamp:timestamp()} |
    missing_expiration |
    missing_issued_at |
    {issued_in_future, gleam@time@timestamp:timestamp()} |
    {token_too_old, gleam@time@timestamp:timestamp(), integer()} |
    {invalid_jti, binary()} |
    {issuer_mismatch, binary(), gleam@option:option(binary())} |
    {audience_mismatch, binary(), gleam@option:option(list(binary()))} |
    {jws_algorithm_mismatch, gose:signing_alg(), gose:signing_alg()} |
    {jwe_algorithm_mismatch,
        gose:key_encryption_alg(),
        gose:content_alg(),
        gose:key_encryption_alg(),
        gose:content_alg()} |
    missing_kid |
    {unknown_kid, binary()} |
    {malformed_token, binary()} |
    {claim_decoding_failed, binary()} |
    {insecure_unprotected_header, binary()} |
    {invalid_claim, binary()} |
    {jose_error, gose:gose_error()}.

-type unverified() :: any().

-type verified() :: any().

-opaque claims() :: {claims,
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(list(binary())),
        gleam@option:option(integer()),
        gleam@option:option(integer()),
        gleam@option:option(integer()),
        gleam@option:option(binary()),
        gleam@dict:dict(binary(), gleam@json:json())}.

-opaque jwt(WYG) :: {jwt,
        gose:signing_alg(),
        gleam@option:option(binary()),
        claims(),
        bitstring(),
        binary()} |
    {gleam_phantom, WYG}.

-type kid_policy() :: no_kid_requirement | require_kid | require_kid_match.

-type jwt_validation_options() :: {jwt_validation_options,
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        integer(),
        boolean(),
        gleam@option:option(integer()),
        gleam@option:option(fun((binary()) -> boolean())),
        kid_policy()}.

-opaque verifier() :: {verifier,
        gose:signing_alg(),
        list(gose:key(binary())),
        jwt_validation_options()}.

-file("src/gose/jose/jwt.gleam", 142).
?DOC(false).
-spec gose_error_to_malformed_token_error(gose:gose_error()) -> jwt_error().
gose_error_to_malformed_token_error(Err) ->
    {malformed_token, gose:error_message(Err)}.

-file("src/gose/jose/jwt.gleam", 246).
?DOC(
    " Create default validation options.\n"
    "\n"
    " Default settings:\n"
    " - No issuer validation\n"
    " - No audience validation\n"
    " - 60 seconds clock skew tolerance\n"
    " - Expiration claim required\n"
    " - No max token age\n"
    " - No JWT ID validator\n"
    " - No kid requirement (prioritizes matching keys but tries all)\n"
    "\n"
    " When an `iat` claim is present, it is always checked to ensure it is not\n"
    " in the future (beyond clock skew), regardless of whether `max_token_age`\n"
    " is configured.\n"
).
-spec default_validation() -> jwt_validation_options().
default_validation() ->
    {jwt_validation_options,
        none,
        none,
        60,
        true,
        none,
        none,
        no_kid_requirement}.

-file("src/gose/jose/jwt.gleam", 269).
?DOC(
    " Set a custom JWT ID (jti) validator.\n"
    "\n"
    " The validator function receives the `jti` claim value and should return\n"
    " `True` if the ID is valid, `False` if it should be rejected.\n"
    "\n"
    " Common use cases:\n"
    " - Check against a revocation list\n"
    " - Verify the ID hasn't been seen before (replay prevention)\n"
    " - Validate format/structure of the ID\n"
    "\n"
    " If the token has no `jti` claim, the validator is not called.\n"
).
-spec with_jti_validator(jwt_validation_options(), fun((binary()) -> boolean())) -> jwt_validation_options().
with_jti_validator(Options, Validator) ->
    {jwt_validation_options,
        erlang:element(2, Options),
        erlang:element(3, Options),
        erlang:element(4, Options),
        erlang:element(5, Options),
        erlang:element(6, Options),
        {some, Validator},
        erlang:element(8, Options)}.

-file("src/gose/jose/jwt.gleam", 281).
?DOC(
    " Set the maximum token age in seconds.\n"
    "\n"
    " If set, tokens with an `iat` claim older than `now - max_age_seconds` will\n"
    " be rejected with `TokenTooOld`. Requires the `iat` claim to be present.\n"
    " Tokens without `iat` are rejected with `MissingIssuedAt`.\n"
).
-spec with_max_token_age(jwt_validation_options(), integer()) -> jwt_validation_options().
with_max_token_age(Options, Max_age_seconds) ->
    {jwt_validation_options,
        erlang:element(2, Options),
        erlang:element(3, Options),
        erlang:element(4, Options),
        erlang:element(5, Options),
        {some, Max_age_seconds},
        erlang:element(7, Options),
        erlang:element(8, Options)}.

-file("src/gose/jose/jwt.gleam", 288).
-spec build_verifier(
    gose:signing_alg(),
    list(gose:key(binary())),
    jwt_validation_options()
) -> {ok, verifier()} | {error, gose:gose_error()}.
build_verifier(Alg, Keys, Options) ->
    gose@internal@key_helpers:require_non_empty_keys(
        Keys,
        fun() ->
            gleam@result:'try'(
                gleam@list:try_each(
                    Keys,
                    fun(_capture) ->
                        gose@internal@key_helpers:validate_key_for_signing_verification(
                            Alg,
                            _capture
                        )
                    end
                ),
                fun(_) -> {ok, {verifier, Alg, Keys, Options}} end
            )
        end
    ).

-file("src/gose/jose/jwt.gleam", 341).
?DOC(
    " Create a verifier for JWT signature verification and claim validation.\n"
    "\n"
    " Each verifier is pinned to a single algorithm. This prevents algorithm\n"
    " confusion attacks where an attacker changes the `alg` header to trick\n"
    " the verifier into using the wrong algorithm (see RFC 8725 Section 3.1).\n"
    " For multi-algorithm scenarios (e.g., algorithm migration), create one\n"
    " verifier per algorithm and try each in sequence:\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(rs_verifier) = jwt.verifier(\n"
    "   gose.DigitalSignature(gose.RsaPkcs1(gose.RsaPkcs1Sha256)),\n"
    "   keys: rsa_keys,\n"
    "   options: jwt.default_validation(),\n"
    " )\n"
    " let assert Ok(ec_verifier) = jwt.verifier(\n"
    "   gose.DigitalSignature(gose.Ecdsa(gose.EcdsaP256)),\n"
    "   keys: ec_keys,\n"
    "   options: jwt.default_validation(),\n"
    " )\n"
    "\n"
    " let result = case jwt.verify_and_validate(rs_verifier, token, now) {\n"
    "   Ok(verified) -> Ok(verified)\n"
    "   _ -> jwt.verify_and_validate(ec_verifier, token, now)\n"
    " }\n"
    " ```\n"
    "\n"
    " Accepts one or more keys for key rotation scenarios.\n"
    "\n"
    " Key selection during verification:\n"
    " 1. If token has `kid` header, prioritize keys with matching kid\n"
    " 2. Try keys in order until one succeeds\n"
    " 3. Fail if no key verifies the signature\n"
    "\n"
    " Returns an error if:\n"
    " - The key list is empty\n"
    " - Any algorithm is incompatible with any key type\n"
    " - Any key's `use` field is set but not `Signing`\n"
    " - Any key's `key_ops` field is set but doesn't include `Verify`\n"
).
-spec verifier(
    gose:signing_alg(),
    list(gose:key(binary())),
    jwt_validation_options()
) -> {ok, verifier()} | {error, jwt_error()}.
verifier(Alg, Keys, Options) ->
    _pipe = build_verifier(Alg, Keys, Options),
    gleam@result:map_error(_pipe, fun(Field@0) -> {jose_error, Field@0} end).

-file("src/gose/jose/jwt.gleam", 352).
?DOC(
    " Create an empty claims set with no registered or custom claims.\n"
    " Use the `with_*` functions to populate claims before signing.\n"
).
-spec claims() -> claims().
claims() ->
    {claims, none, none, none, none, none, none, none, maps:new()}.

-file("src/gose/jose/jwt.gleam", 366).
?DOC(" Set a single audience (aud) claim.\n").
-spec with_audience(claims(), binary()) -> claims().
with_audience(Claims, Aud) ->
    {claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        {some, [Aud]},
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/jose/jwt.gleam", 373).
?DOC(
    " Set multiple audiences (aud) claim.\n"
    "\n"
    " Returns an error if the audience list is empty.\n"
).
-spec with_audiences(claims(), list(binary())) -> {ok, claims()} |
    {error, jwt_error()}.
with_audiences(Claims, Aud) ->
    case Aud of
        [] ->
            {error, {invalid_claim, <<"audience list cannot be empty"/utf8>>}};

        _ ->
            {ok,
                {claims,
                    erlang:element(2, Claims),
                    erlang:element(3, Claims),
                    {some, Aud},
                    erlang:element(5, Claims),
                    erlang:element(6, Claims),
                    erlang:element(7, Claims),
                    erlang:element(8, Claims),
                    erlang:element(9, Claims)}}
    end.

-file("src/gose/jose/jwt.gleam", 400).
?DOC(" Set the expiration time (exp) claim.\n").
-spec with_expiration(claims(), gleam@time@timestamp:timestamp()) -> claims().
with_expiration(Claims, Exp) ->
    {Seconds, _} = gleam@time@timestamp:to_unix_seconds_and_nanoseconds(Exp),
    {claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        {some, Seconds},
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/jose/jwt.gleam", 406).
?DOC(" Set the issued at time (iat) claim.\n").
-spec with_issued_at(claims(), gleam@time@timestamp:timestamp()) -> claims().
with_issued_at(Claims, Iat) ->
    {Seconds, _} = gleam@time@timestamp:to_unix_seconds_and_nanoseconds(Iat),
    {claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        {some, Seconds},
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/jose/jwt.gleam", 412).
?DOC(" Set the issuer (iss) claim.\n").
-spec with_issuer(claims(), binary()) -> claims().
with_issuer(Claims, Iss) ->
    {claims,
        {some, Iss},
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/jose/jwt.gleam", 417).
?DOC(" Set the JWT ID (jti) claim.\n").
-spec with_jwt_id(claims(), binary()) -> claims().
with_jwt_id(Claims, Jti) ->
    {claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        {some, Jti},
        erlang:element(9, Claims)}.

-file("src/gose/jose/jwt.gleam", 422).
?DOC(" Set the not before time (nbf) claim.\n").
-spec with_not_before(claims(), gleam@time@timestamp:timestamp()) -> claims().
with_not_before(Claims, Nbf) ->
    {Seconds, _} = gleam@time@timestamp:to_unix_seconds_and_nanoseconds(Nbf),
    {claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        {some, Seconds},
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/jose/jwt.gleam", 428).
?DOC(" Set the subject (sub) claim.\n").
-spec with_subject(claims(), binary()) -> claims().
with_subject(Claims, Sub) ->
    {claims,
        erlang:element(2, Claims),
        {some, Sub},
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/jose/jwt.gleam", 433).
?DOC(" Get the algorithm (`alg`) from a JWT.\n").
-spec alg(jwt(any())) -> gose:signing_alg().
alg(Jwt) ->
    {jwt, Alg, _, _, _, _} = Jwt,
    Alg.

-file("src/gose/jose/jwt.gleam", 443).
?DOC(
    " Get the key ID (kid) from a JWT header.\n"
    "\n"
    " **Security Warning:** The `kid` value comes from the token and is untrusted\n"
    " input. If you use it to look up keys (from a database, filesystem, or key\n"
    " store), you must sanitize it first to prevent injection attacks.\n"
).
-spec kid(jwt(any())) -> {ok, binary()} | {error, nil}.
kid(Jwt) ->
    {jwt, _, Kid, _, _, _} = Jwt,
    gleam@option:to_result(Kid, nil).

-file("src/gose/jose/jwt.gleam", 483).
-spec do_sign(
    gose@jose@jws:jws(gose@jose@jws:unsigned(), gose@jose@jws:built()),
    gose:key(binary()),
    bitstring(),
    gose:signing_alg(),
    gleam@option:option(binary()),
    claims()
) -> {ok, jwt(verified())} | {error, gose:gose_error()}.
do_sign(Unsigned, Key, Claims_json, Alg, Kid, Claims) ->
    gleam@result:'try'(
        gose@jose@jws:sign(Unsigned, Key, Claims_json),
        fun(Signed) -> _pipe = gose@jose@jws:serialize_compact(Signed),
            gleam@result:map(
                _pipe,
                fun(Token) -> {jwt, Alg, Kid, Claims, Claims_json, Token} end
            ) end
    ).

-file("src/gose/jose/jwt.gleam", 496).
-spec apply_optional_kid(
    gose@jose@jws:jws(gose@jose@jws:unsigned(), gose@jose@jws:built()),
    gleam@option:option(binary())
) -> gose@jose@jws:jws(gose@jose@jws:unsigned(), gose@jose@jws:built()).
apply_optional_kid(Unsigned, Kid) ->
    case Kid of
        {some, K} ->
            gose@jose@jws:with_kid(Unsigned, K);

        none ->
            Unsigned
    end.

-file("src/gose/jose/jwt.gleam", 547).
-spec parse_jws(binary()) -> {ok,
        gose@jose@jws:jws(gose@jose@jws:signed(), gose@jose@jws:parsed())} |
    {error, jwt_error()}.
parse_jws(Token) ->
    _pipe = gose@jose@jws:parse_compact(Token),
    gleam@result:map_error(_pipe, fun gose_error_to_malformed_token_error/1).

-file("src/gose/jose/jwt.gleam", 598).
?DOC(false).
-spec select_keys_by_policy(
    list(gose:key(binary())),
    gleam@option:option(binary()),
    kid_policy()
) -> {ok, list(gose:key(binary()))} | {error, jwt_error()}.
select_keys_by_policy(Keys, Token_kid, Kid_policy) ->
    case {Token_kid, Kid_policy} of
        {none, no_kid_requirement} ->
            {ok, Keys};

        {none, require_kid} ->
            {error, missing_kid};

        {none, require_kid_match} ->
            {error, missing_kid};

        {{some, Target}, require_kid_match} ->
            Matching = gleam@list:filter(
                Keys,
                fun(Key) -> gose:kid(Key) =:= {ok, Target} end
            ),
            case Matching of
                [] ->
                    {error, {unknown_kid, Target}};

                _ ->
                    {ok, Matching}
            end;

        {{some, _}, require_kid} ->
            {ok, gose@internal@key_helpers:order_keys_by_kid(Keys, Token_kid)};

        {{some, _}, no_kid_requirement} ->
            {ok, gose@internal@key_helpers:order_keys_by_kid(Keys, Token_kid)}
    end.

-file("src/gose/jose/jwt.gleam", 622).
-spec try_verify_with_keys(
    gose@jose@jws:jws(gose@jose@jws:signed(), gose@jose@jws:parsed()),
    gose:signing_alg(),
    list(gose:key(binary()))
) -> {ok, nil} | {error, jwt_error()}.
try_verify_with_keys(Signed_jws, Expected_alg, Keys) ->
    gleam@result:'try'(
        begin
            _pipe = gose@jose@jws:verifier(Expected_alg, Keys),
            gleam@result:map_error(
                _pipe,
                fun(Field@0) -> {jose_error, Field@0} end
            )
        end,
        fun(Verifier) -> case gose@jose@jws:verify(Verifier, Signed_jws) of
                {ok, nil} ->
                    {ok, nil};

                {error, verification_failed} ->
                    {error, invalid_signature};

                {error, {crypto_error, _}} ->
                    {error, invalid_signature};

                {error, {parse_error, Reason}} ->
                    {error, {malformed_token, Reason}};

                {error, {invalid_state, _} = Err} ->
                    {error, {jose_error, Err}}
            end end
    ).

-file("src/gose/jose/jwt.gleam", 640).
-spec require_matching_algorithm(gose:signing_alg(), gose:signing_alg()) -> {ok,
        nil} |
    {error, jwt_error()}.
require_matching_algorithm(Expected, Actual) ->
    case Expected =:= Actual of
        true ->
            {ok, nil};

        false ->
            {error, {jws_algorithm_mismatch, Expected, Actual}}
    end.

-file("src/gose/jose/jwt.gleam", 719).
?DOC(" Serialize a verified JWT to compact format.\n").
-spec serialize(jwt(verified())) -> binary().
serialize(Jwt) ->
    erlang:element(6, Jwt).

-file("src/gose/jose/jwt.gleam", 733).
-spec claims_to_json(claims()) -> gleam@json:json().
claims_to_json(Claims) ->
    Registered_fields = gleam@option:values(
        [gleam@option:map(
                erlang:element(2, Claims),
                fun(V) -> {<<"iss"/utf8>>, gleam@json:string(V)} end
            ),
            gleam@option:map(
                erlang:element(3, Claims),
                fun(V@1) -> {<<"sub"/utf8>>, gleam@json:string(V@1)} end
            ),
            gleam@option:map(
                erlang:element(4, Claims),
                fun(Auds) -> case Auds of
                        [Single] ->
                            {<<"aud"/utf8>>, gleam@json:string(Single)};

                        Multiple ->
                            {<<"aud"/utf8>>,
                                gleam@json:array(
                                    Multiple,
                                    fun gleam@json:string/1
                                )}
                    end end
            ),
            gleam@option:map(
                erlang:element(5, Claims),
                fun(V@2) -> {<<"exp"/utf8>>, gleam@json:int(V@2)} end
            ),
            gleam@option:map(
                erlang:element(6, Claims),
                fun(V@3) -> {<<"nbf"/utf8>>, gleam@json:int(V@3)} end
            ),
            gleam@option:map(
                erlang:element(7, Claims),
                fun(V@4) -> {<<"iat"/utf8>>, gleam@json:int(V@4)} end
            ),
            gleam@option:map(
                erlang:element(8, Claims),
                fun(V@5) -> {<<"jti"/utf8>>, gleam@json:string(V@5)} end
            )]
    ),
    Custom_fields = maps:to_list(erlang:element(9, Claims)),
    gleam@json:object(lists:append(Registered_fields, Custom_fields)).

-file("src/gose/jose/jwt.gleam", 463).
?DOC(
    " Sign a JWT with the provided key.\n"
    "\n"
    " Automatically sets `typ: \"JWT\"` in the header. The token is marked\n"
    " `Verified` because locally-signed tokens are implicitly trusted.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let claims = jwt.claims()\n"
    "   |> jwt.with_subject(\"user123\")\n"
    "   |> jwt.with_expiration(exp)\n"
    "\n"
    " let assert Ok(signed) = jwt.sign(gose.Mac(gose.Hmac(gose.HmacSha256)), claims, key)\n"
    " let token = jwt.serialize(signed)\n"
    " ```\n"
).
-spec sign(gose:signing_alg(), claims(), gose:key(binary())) -> {ok,
        jwt(verified())} |
    {error, jwt_error()}.
sign(Alg, Claims, Key) ->
    Kid = gleam@option:from_result(gose:kid(Key)),
    Payload = claims_to_json(Claims),
    Payload_bits = begin
        _pipe = gleam@json:to_string(Payload),
        gleam_stdlib:identity(_pipe)
    end,
    Unsigned = begin
        _pipe@1 = gose@jose@jws:new(Alg),
        _pipe@2 = gose@jose@jws:with_typ(_pipe@1, <<"JWT"/utf8>>),
        apply_optional_kid(_pipe@2, Kid)
    end,
    _pipe@3 = do_sign(Unsigned, Key, Payload_bits, Alg, Kid, Claims),
    gleam@result:map_error(_pipe@3, fun(Field@0) -> {jose_error, Field@0} end).

-file("src/gose/jose/jwt.gleam", 728).
?DOC(false).
-spec claims_to_json_string(claims()) -> binary().
claims_to_json_string(Claims) ->
    _pipe = claims_to_json(Claims),
    gleam@json:to_string(_pipe).

-file("src/gose/jose/jwt.gleam", 770).
?DOC(
    " Decode an unverified JWT's claims using a custom decoder.\n"
    "\n"
    " **Warning:** These claims have not been verified. Do not trust them\n"
    " until the JWT has been verified with `verify_and_validate`.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(parsed) = jwt.parse(token)\n"
    " let decoder = {\n"
    "   use iss <- decode.field(\"iss\", decode.string)\n"
    "   decode.success(iss)\n"
    " }\n"
    " let assert Ok(issuer) = jwt.dangerously_decode_unverified(parsed, decoder)\n"
    " // issuer is untrusted - only use for routing/lookup, not authorization\n"
    " ```\n"
).
-spec dangerously_decode_unverified(
    jwt(unverified()),
    gleam@dynamic@decode:decoder(XBE)
) -> {ok, XBE} | {error, jwt_error()}.
dangerously_decode_unverified(Jwt, Decoder) ->
    _pipe = gleam@json:parse_bits(erlang:element(5, Jwt), Decoder),
    gleam@result:replace_error(
        _pipe,
        {claim_decoding_failed, <<"failed to decode claims"/utf8>>}
    ).

-file("src/gose/jose/jwt.gleam", 793).
?DOC(
    " Decode a verified JWT's claims using a custom decoder.\n"
    "\n"
    " This allows extracting claims directly into your own types using\n"
    " `gleam/dynamic/decode`. The decoder receives the raw claims JSON.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let decoder = {\n"
    "   use sub <- decode.field(\"sub\", decode.string)\n"
    "   use role <- decode.field(\"role\", decode.string)\n"
    "   decode.success(User(sub:, role:))\n"
    " }\n"
    " let assert Ok(user) = jwt.decode(verified_jwt, decoder)\n"
    " ```\n"
).
-spec decode(jwt(verified()), gleam@dynamic@decode:decoder(XBJ)) -> {ok, XBJ} |
    {error, jwt_error()}.
decode(Jwt, Decoder) ->
    _pipe = gleam@json:parse_bits(erlang:element(5, Jwt), Decoder),
    gleam@result:replace_error(
        _pipe,
        {claim_decoding_failed, <<"failed to decode claims"/utf8>>}
    ).

-file("src/gose/jose/jwt.gleam", 574).
-spec has_unprotected_alg(
    gose@jose@jws:jws(gose@jose@jws:signed(), gose@jose@jws:parsed())
) -> boolean().
has_unprotected_alg(Signed_jws) ->
    gleam@bool:guard(
        not gose@jose@jws:has_unprotected_header(Signed_jws),
        false,
        fun() ->
            Alg_decoder = begin
                gleam@dynamic@decode:optional_field(
                    <<"alg"/utf8>>,
                    none,
                    gleam@dynamic@decode:optional(
                        {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
                    ),
                    fun(Alg) -> gleam@dynamic@decode:success(Alg) end
                )
            end,
            case gose@jose@jws:decode_unprotected_header(
                Signed_jws,
                Alg_decoder
            ) of
                {ok, {some, _}} ->
                    true;

                _ ->
                    false
            end
        end
    ).

-file("src/gose/jose/jwt.gleam", 554).
?DOC(
    " Validate that a signed JWS is compatible with JWT requirements.\n"
    " JWTs do not support detached payloads or unencoded payloads (b64=false).\n"
).
-spec require_jwt_compatible_jws(
    gose@jose@jws:jws(gose@jose@jws:signed(), gose@jose@jws:parsed())
) -> {ok, nil} | {error, jwt_error()}.
require_jwt_compatible_jws(Signed_jws) ->
    gleam@bool:guard(
        gose@jose@jws:is_detached(Signed_jws),
        {error,
            {malformed_token, <<"JWTs do not support detached payloads"/utf8>>}},
        fun() ->
            gleam@bool:guard(
                gose@jose@jws:has_unencoded_payload(Signed_jws),
                {error,
                    {malformed_token,
                        <<"JWTs do not support unencoded payloads (b64=false)"/utf8>>}},
                fun() ->
                    gleam@bool:guard(
                        has_unprotected_alg(Signed_jws),
                        {error, {insecure_unprotected_header, <<"alg"/utf8>>}},
                        fun() -> {ok, nil} end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwt.gleam", 827).
-spec extract_optional_audience(
    gleam@dict:dict(binary(), gleam@dynamic:dynamic_())
) -> {ok, gleam@option:option(list(binary()))} | {error, jwt_error()}.
extract_optional_audience(Fields) ->
    case gleam_stdlib:map_get(Fields, <<"aud"/utf8>>) of
        {ok, Value} ->
            Audience_decoder = gleam@dynamic@decode:one_of(
                gleam@dynamic@decode:list(
                    {decoder, fun gleam@dynamic@decode:decode_string/1}
                ),
                [gleam@dynamic@decode:map(
                        {decoder, fun gleam@dynamic@decode:decode_string/1},
                        fun gleam@list:wrap/1
                    )]
            ),
            case gleam@dynamic@decode:run(Value, Audience_decoder) of
                {ok, []} ->
                    {error,
                        {malformed_token,
                            <<"aud claim cannot be an empty array"/utf8>>}};

                {ok, Audiences} ->
                    {ok, {some, Audiences}};

                {error, _} ->
                    {error,
                        {malformed_token,
                            <<"aud claim must be a string or array of strings"/utf8>>}}
            end;

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/jose/jwt.gleam", 847).
-spec extract_optional_numeric_date(
    gleam@dict:dict(binary(), gleam@dynamic:dynamic_()),
    binary()
) -> {ok, gleam@option:option(integer())} | {error, jwt_error()}.
extract_optional_numeric_date(Fields, Key) ->
    case gleam_stdlib:map_get(Fields, Key) of
        {ok, Value} ->
            Numeric_decoder = gleam@dynamic@decode:one_of(
                {decoder, fun gleam@dynamic@decode:decode_int/1},
                [gleam@dynamic@decode:map(
                        {decoder, fun gleam@dynamic@decode:decode_float/1},
                        fun erlang:trunc/1
                    )]
            ),
            _pipe = gleam@dynamic@decode:run(Value, Numeric_decoder),
            _pipe@1 = gleam@result:map(
                _pipe,
                fun(Field@0) -> {some, Field@0} end
            ),
            gleam@result:replace_error(
                _pipe@1,
                {malformed_token,
                    <<Key/binary, " claim must be a numeric value"/utf8>>}
            );

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/jose/jwt.gleam", 865).
-spec extract_optional_string(
    gleam@dict:dict(binary(), gleam@dynamic:dynamic_()),
    binary()
) -> {ok, gleam@option:option(binary())} | {error, jwt_error()}.
extract_optional_string(Fields, Key) ->
    case gleam_stdlib:map_get(Fields, Key) of
        {ok, Value} ->
            _pipe = gleam@dynamic@decode:run(
                Value,
                {decoder, fun gleam@dynamic@decode:decode_string/1}
            ),
            _pipe@1 = gleam@result:map(
                _pipe,
                fun(Field@0) -> {some, Field@0} end
            ),
            gleam@result:replace_error(
                _pipe@1,
                {malformed_token,
                    <<Key/binary, " claim must be a string"/utf8>>}
            );

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/jose/jwt.gleam", 878).
-spec parse_claims_from_fields(
    gleam@dict:dict(binary(), gleam@dynamic:dynamic_())
) -> {ok, claims()} | {error, jwt_error()}.
parse_claims_from_fields(All_fields) ->
    gleam@result:'try'(
        extract_optional_string(All_fields, <<"iss"/utf8>>),
        fun(Iss) ->
            gleam@result:'try'(
                extract_optional_string(All_fields, <<"sub"/utf8>>),
                fun(Sub) ->
                    gleam@result:'try'(
                        extract_optional_audience(All_fields),
                        fun(Aud) ->
                            gleam@result:'try'(
                                extract_optional_numeric_date(
                                    All_fields,
                                    <<"exp"/utf8>>
                                ),
                                fun(Exp) ->
                                    gleam@result:'try'(
                                        extract_optional_numeric_date(
                                            All_fields,
                                            <<"nbf"/utf8>>
                                        ),
                                        fun(Nbf) ->
                                            gleam@result:'try'(
                                                extract_optional_numeric_date(
                                                    All_fields,
                                                    <<"iat"/utf8>>
                                                ),
                                                fun(Iat) ->
                                                    gleam@result:'try'(
                                                        extract_optional_string(
                                                            All_fields,
                                                            <<"jti"/utf8>>
                                                        ),
                                                        fun(Jti) ->
                                                            {ok,
                                                                {claims,
                                                                    Iss,
                                                                    Sub,
                                                                    Aud,
                                                                    Exp,
                                                                    Nbf,
                                                                    Iat,
                                                                    Jti,
                                                                    maps:new()}}
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

-file("src/gose/jose/jwt.gleam", 820).
?DOC(false).
-spec parse_claims_bits(bitstring()) -> {ok, claims()} | {error, jwt_error()}.
parse_claims_bits(Payload) ->
    case gleam@json:parse_bits(
        Payload,
        gleam@dynamic@decode:dict(
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
        )
    ) of
        {ok, All_fields} ->
            parse_claims_from_fields(All_fields);

        {error, _} ->
            {error, {malformed_token, <<"invalid claims JSON"/utf8>>}}
    end.

-file("src/gose/jose/jwt.gleam", 685).
-spec build_verified_jwt(
    gose@jose@jws:jws(gose@jose@jws:signed(), gose@jose@jws:parsed()),
    binary()
) -> {ok, jwt(verified())} | {error, jwt_error()}.
build_verified_jwt(Signed_jws, Token) ->
    Claims_json = gose@jose@jws:payload(Signed_jws),
    gleam@result:'try'(
        parse_claims_bits(Claims_json),
        fun(Claims) ->
            Alg = gose@jose@jws:alg(Signed_jws),
            Kid = gleam@option:from_result(gose@jose@jws:kid(Signed_jws)),
            {ok, {jwt, Alg, Kid, Claims, Claims_json, Token}}
        end
    ).

-file("src/gose/jose/jwt.gleam", 658).
?DOC(
    " Verify a JWT's signature only, skipping all claim validation.\n"
    "\n"
    " **Warning:** This skips expiration, not-before, issuer, and audience checks.\n"
    " Use only when you have a legitimate reason to bypass validation, such as\n"
    " inspecting claims before deciding on validation policy.\n"
    "\n"
    " Still enforces algorithm pinning and `kid_policy` for security.\n"
    " When multiple keys are configured, keys with matching `kid` are tried first.\n"
).
-spec verify_and_dangerously_skip_validation(verifier(), binary()) -> {ok,
        jwt(verified())} |
    {error, jwt_error()}.
verify_and_dangerously_skip_validation(Verifier, Token) ->
    {verifier, Expected_alg, Keys, Options} = Verifier,
    gleam@result:'try'(
        parse_jws(Token),
        fun(Signed_jws) ->
            gleam@result:'try'(
                require_jwt_compatible_jws(Signed_jws),
                fun(_) ->
                    gleam@result:'try'(
                        require_matching_algorithm(
                            Expected_alg,
                            gose@jose@jws:alg(Signed_jws)
                        ),
                        fun(_) ->
                            Token_kid = gleam@option:from_result(
                                gose@jose@jws:kid(Signed_jws)
                            ),
                            gleam@result:'try'(
                                select_keys_by_policy(
                                    Keys,
                                    Token_kid,
                                    erlang:element(8, Options)
                                ),
                                fun(Verification_keys) ->
                                    gleam@result:'try'(
                                        try_verify_with_keys(
                                            Signed_jws,
                                            Expected_alg,
                                            Verification_keys
                                        ),
                                        fun(_) ->
                                            build_verified_jwt(
                                                Signed_jws,
                                                Token
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

-file("src/gose/jose/jwt.gleam", 805).
?DOC(
    " Parse a JWT from compact format.\n"
    "\n"
    " Returns an unverified JWT that needs to be verified with\n"
    " `verify_and_validate` or `verify_and_dangerously_skip_validation`.\n"
).
-spec parse(binary()) -> {ok, jwt(unverified())} | {error, jwt_error()}.
parse(Token) ->
    gleam@result:'try'(
        parse_jws(Token),
        fun(Signed) ->
            gleam@result:'try'(
                require_jwt_compatible_jws(Signed),
                fun(_) ->
                    Claims_json = gose@jose@jws:payload(Signed),
                    gleam@result:'try'(
                        parse_claims_bits(Claims_json),
                        fun(Claims) ->
                            Alg = gose@jose@jws:alg(Signed),
                            Kid = gleam@option:from_result(
                                gose@jose@jws:kid(Signed)
                            ),
                            {ok, {jwt, Alg, Kid, Claims, Claims_json, Token}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwt.gleam", 892).
-spec validate_audience(claims(), jwt_validation_options()) -> {ok, nil} |
    {error, jwt_error()}.
validate_audience(Claims, Options) ->
    case {erlang:element(3, Options), erlang:element(4, Claims)} of
        {none, _} ->
            {ok, nil};

        {{some, Expected}, {some, Audiences}} ->
            case gleam@list:contains(Audiences, Expected) of
                true ->
                    {ok, nil};

                false ->
                    {error, {audience_mismatch, Expected, {some, Audiences}}}
            end;

        {{some, Expected@1}, none} ->
            {error, {audience_mismatch, Expected@1, none}}
    end.

-file("src/gose/jose/jwt.gleam", 909).
-spec validate_exp(claims(), integer(), jwt_validation_options()) -> {ok, nil} |
    {error, jwt_error()}.
validate_exp(Claims, Now_seconds, Options) ->
    case {erlang:element(5, Claims), erlang:element(5, Options)} of
        {none, true} ->
            {error, missing_expiration};

        {none, false} ->
            {ok, nil};

        {{some, Exp}, _} ->
            Adjusted_now = Now_seconds - erlang:element(4, Options),
            gleam@bool:guard(
                Adjusted_now >= Exp,
                {error,
                    {token_expired, gleam@time@timestamp:from_unix_seconds(Exp)}},
                fun() -> {ok, nil} end
            )
    end.

-file("src/gose/jose/jwt.gleam", 943).
-spec validate_issuer(claims(), jwt_validation_options()) -> {ok, nil} |
    {error, jwt_error()}.
validate_issuer(Claims, Options) ->
    case {erlang:element(2, Options), erlang:element(2, Claims)} of
        {none, _} ->
            {ok, nil};

        {{some, Expected}, {some, Actual}} when Expected =:= Actual ->
            {ok, nil};

        {{some, Expected@1}, Actual@1} ->
            {error, {issuer_mismatch, Expected@1, Actual@1}}
    end.

-file("src/gose/jose/jwt.gleam", 954).
-spec validate_jti(claims(), jwt_validation_options()) -> {ok, nil} |
    {error, jwt_error()}.
validate_jti(Claims, Options) ->
    case {erlang:element(7, Options), erlang:element(8, Claims)} of
        {none, _} ->
            {ok, nil};

        {{some, _}, none} ->
            {ok, nil};

        {{some, Validator}, {some, Jti}} ->
            gleam@bool:guard(
                not Validator(Jti),
                {error, {invalid_jti, Jti}},
                fun() -> {ok, nil} end
            )
    end.

-file("src/gose/jose/jwt.gleam", 968).
-spec validate_nbf(claims(), integer(), jwt_validation_options()) -> {ok, nil} |
    {error, jwt_error()}.
validate_nbf(Claims, Now_seconds, Options) ->
    case erlang:element(6, Claims) of
        none ->
            {ok, nil};

        {some, Nbf} ->
            Adjusted_now = Now_seconds + erlang:element(4, Options),
            gleam@bool:guard(
                Adjusted_now < Nbf,
                {error,
                    {token_not_yet_valid,
                        gleam@time@timestamp:from_unix_seconds(Nbf)}},
                fun() -> {ok, nil} end
            )
    end.

-file("src/gose/jose/jwt.gleam", 986).
-spec validate_iat_not_future(integer(), integer(), jwt_validation_options()) -> {ok,
        nil} |
    {error, jwt_error()}.
validate_iat_not_future(Iat, Now_seconds, Options) ->
    gleam@bool:guard(
        Iat > (Now_seconds + erlang:element(4, Options)),
        {error, {issued_in_future, gleam@time@timestamp:from_unix_seconds(Iat)}},
        fun() -> {ok, nil} end
    ).

-file("src/gose/jose/jwt.gleam", 998).
-spec validate_token_age(integer(), integer(), jwt_validation_options()) -> {ok,
        nil} |
    {error, jwt_error()}.
validate_token_age(Iat, Now_seconds, Options) ->
    case erlang:element(6, Options) of
        none ->
            {ok, nil};

        {some, Max_age} ->
            Token_age = Now_seconds - Iat,
            gleam@bool:guard(
                Token_age > Max_age,
                {error,
                    {token_too_old,
                        gleam@time@timestamp:from_unix_seconds(Iat),
                        Max_age}},
                fun() -> {ok, nil} end
            )
    end.

-file("src/gose/jose/jwt.gleam", 928).
-spec validate_iat(claims(), integer(), jwt_validation_options()) -> {ok, nil} |
    {error, jwt_error()}.
validate_iat(Claims, Now_seconds, Options) ->
    case {erlang:element(7, Claims), erlang:element(6, Options)} of
        {none, {some, _}} ->
            {error, missing_issued_at};

        {none, none} ->
            {ok, nil};

        {{some, Iat}, _} ->
            gleam@result:'try'(
                validate_iat_not_future(Iat, Now_seconds, Options),
                fun(_) -> validate_token_age(Iat, Now_seconds, Options) end
            )
    end.

-file("src/gose/jose/jwt.gleam", 703).
?DOC(false).
-spec validate_claims(
    claims(),
    gleam@time@timestamp:timestamp(),
    jwt_validation_options()
) -> {ok, nil} | {error, jwt_error()}.
validate_claims(Claims, Now, Options) ->
    {Now_seconds, _} = gleam@time@timestamp:to_unix_seconds_and_nanoseconds(Now),
    gleam@result:'try'(
        validate_exp(Claims, Now_seconds, Options),
        fun(_) ->
            gleam@result:'try'(
                validate_nbf(Claims, Now_seconds, Options),
                fun(_) ->
                    gleam@result:'try'(
                        validate_issuer(Claims, Options),
                        fun(_) ->
                            gleam@result:'try'(
                                validate_audience(Claims, Options),
                                fun(_) ->
                                    gleam@result:'try'(
                                        validate_iat(
                                            Claims,
                                            Now_seconds,
                                            Options
                                        ),
                                        fun(_) ->
                                            validate_jti(Claims, Options)
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

-file("src/gose/jose/jwt.gleam", 517).
?DOC(
    " Verify a JWT's signature and validate its claims using a Verifier.\n"
    "\n"
    " Checks:\n"
    " 1. Token's `alg` header matches the verifier's expected algorithm\n"
    " 2. Signature is valid for one of the verifier's keys\n"
    " 3. Claims pass validation (exp, nbf, iss, aud per options)\n"
    "\n"
    " When multiple keys are configured:\n"
    " - Keys with matching `kid` are tried first (if token has `kid` header)\n"
    " - `kid_policy` controls kid header enforcement (see `KidPolicy` type)\n"
    " - With `NoKidRequirement`, all keys are tried with matching keys prioritized\n"
).
-spec verify_and_validate(
    verifier(),
    binary(),
    gleam@time@timestamp:timestamp()
) -> {ok, jwt(verified())} | {error, jwt_error()}.
verify_and_validate(Verifier, Token, Now) ->
    {verifier, Expected_alg, Keys, Options} = Verifier,
    gleam@result:'try'(
        parse_jws(Token),
        fun(Signed_jws) ->
            gleam@result:'try'(
                require_jwt_compatible_jws(Signed_jws),
                fun(_) ->
                    gleam@result:'try'(
                        require_matching_algorithm(
                            Expected_alg,
                            gose@jose@jws:alg(Signed_jws)
                        ),
                        fun(_) ->
                            Token_kid = gleam@option:from_result(
                                gose@jose@jws:kid(Signed_jws)
                            ),
                            gleam@result:'try'(
                                select_keys_by_policy(
                                    Keys,
                                    Token_kid,
                                    erlang:element(8, Options)
                                ),
                                fun(Verification_keys) ->
                                    gleam@result:'try'(
                                        try_verify_with_keys(
                                            Signed_jws,
                                            Expected_alg,
                                            Verification_keys
                                        ),
                                        fun(_) ->
                                            gleam@result:'try'(
                                                build_verified_jwt(
                                                    Signed_jws,
                                                    Token
                                                ),
                                                fun(Jwt) ->
                                                    gleam@result:'try'(
                                                        validate_claims(
                                                            erlang:element(
                                                                4,
                                                                Jwt
                                                            ),
                                                            Now,
                                                            Options
                                                        ),
                                                        fun(_) -> {ok, Jwt} end
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

-file("src/gose/jose/jwt.gleam", 387).
?DOC(
    " Set a custom claim.\n"
    "\n"
    " Returns an error if the key is a reserved claim name. Use the dedicated\n"
    " setters for registered claims (e.g., `with_issuer`, `with_subject`).\n"
).
-spec with_claim(claims(), binary(), gleam@json:json()) -> {ok, claims()} |
    {error, jwt_error()}.
with_claim(Claims, Key, Value) ->
    case gleam@list:contains(
        [<<"iss"/utf8>>,
            <<"sub"/utf8>>,
            <<"aud"/utf8>>,
            <<"exp"/utf8>>,
            <<"nbf"/utf8>>,
            <<"iat"/utf8>>,
            <<"jti"/utf8>>],
        Key
    ) of
        true ->
            {error,
                {invalid_claim,
                    <<<<"use dedicated setter for "/utf8, Key/binary>>/binary,
                        " claim"/utf8>>}};

        false ->
            {ok,
                {claims,
                    erlang:element(2, Claims),
                    erlang:element(3, Claims),
                    erlang:element(4, Claims),
                    erlang:element(5, Claims),
                    erlang:element(6, Claims),
                    erlang:element(7, Claims),
                    erlang:element(8, Claims),
                    gleam@dict:insert(erlang:element(9, Claims), Key, Value)}}
    end.
