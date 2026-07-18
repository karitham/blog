-module(gose@cose@cwt).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/cwt.gleam").
-export([new/0, with_issuer/2, with_subject/2, with_audience/2, with_audiences/2, with_expiration/2, with_not_before/2, with_issued_at/2, with_cti/2, with_custom_claim/3, issuer/1, subject/1, audience/1, expiration/1, not_before/1, issued_at/1, cti/1, custom_claim/2, verifier/2, with_issuer_validation/2, with_audience_validation/2, with_clock_skew/2, with_require_expiration/2, verified_claims/1, sign/3, verify_and_validate/3]).
-export_type([cwt_error/0, unverified/0, verified/0, cwt_claims/0, cwt/1, verifier/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " CBOR Web Token (CWT) [RFC 8392](https://www.rfc-editor.org/rfc/rfc8392.html)\n"
    "\n"
    " CWT is the CBOR equivalent of JWT, providing claims-based tokens using\n"
    " COSE for signing and verification.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gleam/time/duration\n"
    " import gleam/time/timestamp\n"
    " import gose\n"
    " import gose/cose/cwt\n"
    " import kryptos/ec\n"
    "\n"
    " let signing_key = gose.generate_ec(ec.P256)\n"
    " let now = timestamp.system_time()\n"
    " let exp = timestamp.add(now, duration.hours(1))\n"
    "\n"
    " let claims = cwt.new()\n"
    "   |> cwt.with_subject(\"user123\")\n"
    "   |> cwt.with_issuer(\"my-app\")\n"
    "   |> cwt.with_expiration(exp)\n"
    "\n"
    " let assert Ok(token) =\n"
    "   cwt.sign(\n"
    "     claims,\n"
    "     alg: gose.Ecdsa(gose.EcdsaP256),\n"
    "     key: signing_key,\n"
    "   )\n"
    "\n"
    " let assert Ok(verifier) =\n"
    "   cwt.verifier(gose.Ecdsa(gose.EcdsaP256), keys: [signing_key])\n"
    " let assert Ok(verified) = cwt.verify_and_validate(verifier, token:, now:)\n"
    " let verified_claims = cwt.verified_claims(verified)\n"
    " ```\n"
    "\n"
    " ## Phantom Types\n"
    "\n"
    " `Cwt(state)` uses a phantom type to track verification state:\n"
    " - `Unverified`: parsed but not yet verified\n"
    " - `Verified`: signature verified and claims validated, safe to trust\n"
).

-type cwt_error() :: {cose_error, gose:gose_error()} |
    invalid_signature |
    {malformed_token, binary()} |
    {token_expired, gleam@time@timestamp:timestamp()} |
    {token_not_yet_valid, gleam@time@timestamp:timestamp()} |
    {issuer_mismatch, binary(), gleam@option:option(binary())} |
    {audience_mismatch, binary(), gleam@option:option(list(binary()))} |
    missing_expiration |
    {decryption_failed, binary()} |
    {invalid_claim, binary()}.

-type unverified() :: any().

-type verified() :: any().

-opaque cwt_claims() :: {cwt_claims,
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(list(binary())),
        gleam@option:option(integer()),
        gleam@option:option(integer()),
        gleam@option:option(integer()),
        gleam@option:option(bitstring()),
        list({gose@cbor:value(), gose@cbor:value()})}.

-opaque cwt(OKI) :: {cwt, cwt_claims()} | {gleam_phantom, OKI}.

-opaque verifier() :: {verifier,
        gose:digital_signature_alg(),
        list(gose:key(bitstring())),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        integer(),
        boolean()}.

-file("src/gose/cose/cwt.gleam", 116).
?DOC(" Create an empty set of CWT claims.\n").
-spec new() -> cwt_claims().
new() ->
    {cwt_claims, none, none, none, none, none, none, none, []}.

-file("src/gose/cose/cwt.gleam", 130).
?DOC(" Set the issuer (`iss`, label 1) claim.\n").
-spec with_issuer(cwt_claims(), binary()) -> cwt_claims().
with_issuer(Claims, Issuer) ->
    {cwt_claims,
        {some, Issuer},
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/cose/cwt.gleam", 135).
?DOC(" Set the subject (`sub`, label 2) claim.\n").
-spec with_subject(cwt_claims(), binary()) -> cwt_claims().
with_subject(Claims, Subject) ->
    {cwt_claims,
        erlang:element(2, Claims),
        {some, Subject},
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/cose/cwt.gleam", 140).
?DOC(" Set a single audience (`aud`, label 3) claim.\n").
-spec with_audience(cwt_claims(), binary()) -> cwt_claims().
with_audience(Claims, Audience) ->
    {cwt_claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        {some, [Audience]},
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/cose/cwt.gleam", 145).
?DOC(" Set multiple audiences (`aud`, label 3) as an array.\n").
-spec with_audiences(cwt_claims(), list(binary())) -> {ok, cwt_claims()} |
    {error, cwt_error()}.
with_audiences(Claims, Audiences) ->
    case Audiences of
        [] ->
            {error, {invalid_claim, <<"audience list cannot be empty"/utf8>>}};

        _ ->
            {ok,
                {cwt_claims,
                    erlang:element(2, Claims),
                    erlang:element(3, Claims),
                    {some, Audiences},
                    erlang:element(5, Claims),
                    erlang:element(6, Claims),
                    erlang:element(7, Claims),
                    erlang:element(8, Claims),
                    erlang:element(9, Claims)}}
    end.

-file("src/gose/cose/cwt.gleam", 156).
?DOC(" Set the expiration time (`exp`, label 4) claim.\n").
-spec with_expiration(cwt_claims(), gleam@time@timestamp:timestamp()) -> cwt_claims().
with_expiration(Claims, Exp) ->
    {Seconds, _} = gleam@time@timestamp:to_unix_seconds_and_nanoseconds(Exp),
    {cwt_claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        {some, Seconds},
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/cose/cwt.gleam", 162).
?DOC(" Set the not-before time (`nbf`, label 5) claim.\n").
-spec with_not_before(cwt_claims(), gleam@time@timestamp:timestamp()) -> cwt_claims().
with_not_before(Claims, Nbf) ->
    {Seconds, _} = gleam@time@timestamp:to_unix_seconds_and_nanoseconds(Nbf),
    {cwt_claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        {some, Seconds},
        erlang:element(7, Claims),
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/cose/cwt.gleam", 168).
?DOC(" Set the issued-at time (`iat`, label 6) claim.\n").
-spec with_issued_at(cwt_claims(), gleam@time@timestamp:timestamp()) -> cwt_claims().
with_issued_at(Claims, Iat) ->
    {Seconds, _} = gleam@time@timestamp:to_unix_seconds_and_nanoseconds(Iat),
    {cwt_claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        {some, Seconds},
        erlang:element(8, Claims),
        erlang:element(9, Claims)}.

-file("src/gose/cose/cwt.gleam", 174).
?DOC(" Set the CWT ID (`cti`, label 7) claim.\n").
-spec with_cti(cwt_claims(), bitstring()) -> cwt_claims().
with_cti(Claims, Cti) ->
    {cwt_claims,
        erlang:element(2, Claims),
        erlang:element(3, Claims),
        erlang:element(4, Claims),
        erlang:element(5, Claims),
        erlang:element(6, Claims),
        erlang:element(7, Claims),
        {some, Cti},
        erlang:element(9, Claims)}.

-file("src/gose/cose/cwt.gleam", 182).
?DOC(
    " Add a custom (non-registered) claim keyed by an arbitrary CBOR value.\n"
    "\n"
    " Returns an error if the key collides with a registered CWT label (1-7).\n"
    " If the key already exists in custom claims, the value is replaced.\n"
).
-spec with_custom_claim(cwt_claims(), gose@cbor:value(), gose@cbor:value()) -> {ok,
        cwt_claims()} |
    {error, cwt_error()}.
with_custom_claim(Claims, Key, Value) ->
    case Key of
        {int, N} when (N >= 1) andalso (N =< 7) ->
            {error,
                {malformed_token,
                    <<"custom claim key collides with registered CWT label "/utf8,
                        (erlang:integer_to_binary(N))/binary>>}};

        _ ->
            {ok,
                {cwt_claims,
                    erlang:element(2, Claims),
                    erlang:element(3, Claims),
                    erlang:element(4, Claims),
                    erlang:element(5, Claims),
                    erlang:element(6, Claims),
                    erlang:element(7, Claims),
                    erlang:element(8, Claims),
                    gleam@list:key_set(erlang:element(9, Claims), Key, Value)}}
    end.

-file("src/gose/cose/cwt.gleam", 199).
?DOC(" Read the issuer claim.\n").
-spec issuer(cwt_claims()) -> {ok, binary()} | {error, nil}.
issuer(Claims) ->
    gleam@option:to_result(erlang:element(2, Claims), nil).

-file("src/gose/cose/cwt.gleam", 204).
?DOC(" Read the subject claim.\n").
-spec subject(cwt_claims()) -> {ok, binary()} | {error, nil}.
subject(Claims) ->
    gleam@option:to_result(erlang:element(3, Claims), nil).

-file("src/gose/cose/cwt.gleam", 209).
?DOC(" Read the audience claim as a list of strings.\n").
-spec audience(cwt_claims()) -> {ok, list(binary())} | {error, nil}.
audience(Claims) ->
    gleam@option:to_result(erlang:element(4, Claims), nil).

-file("src/gose/cose/cwt.gleam", 214).
?DOC(" Read the expiration time as a timestamp.\n").
-spec expiration(cwt_claims()) -> {ok, gleam@time@timestamp:timestamp()} |
    {error, nil}.
expiration(Claims) ->
    _pipe = gleam@option:to_result(erlang:element(5, Claims), nil),
    gleam@result:map(_pipe, fun gleam@time@timestamp:from_unix_seconds/1).

-file("src/gose/cose/cwt.gleam", 220).
?DOC(" Read the not-before time as a timestamp.\n").
-spec not_before(cwt_claims()) -> {ok, gleam@time@timestamp:timestamp()} |
    {error, nil}.
not_before(Claims) ->
    _pipe = gleam@option:to_result(erlang:element(6, Claims), nil),
    gleam@result:map(_pipe, fun gleam@time@timestamp:from_unix_seconds/1).

-file("src/gose/cose/cwt.gleam", 226).
?DOC(" Read the issued-at time as a timestamp.\n").
-spec issued_at(cwt_claims()) -> {ok, gleam@time@timestamp:timestamp()} |
    {error, nil}.
issued_at(Claims) ->
    _pipe = gleam@option:to_result(erlang:element(7, Claims), nil),
    gleam@result:map(_pipe, fun gleam@time@timestamp:from_unix_seconds/1).

-file("src/gose/cose/cwt.gleam", 232).
?DOC(" Read the CWT ID.\n").
-spec cti(cwt_claims()) -> {ok, bitstring()} | {error, nil}.
cti(Claims) ->
    gleam@option:to_result(erlang:element(8, Claims), nil).

-file("src/gose/cose/cwt.gleam", 237).
?DOC(" Look up a custom claim by its CBOR key.\n").
-spec custom_claim(cwt_claims(), gose@cbor:value()) -> {ok, gose@cbor:value()} |
    {error, nil}.
custom_claim(Claims, Key) ->
    gleam@list:key_find(erlang:element(9, Claims), Key).

-file("src/gose/cose/cwt.gleam", 266).
-spec build_verifier(gose:digital_signature_alg(), list(gose:key(bitstring()))) -> {ok,
        verifier()} |
    {error, gose:gose_error()}.
build_verifier(Alg, Keys) ->
    gose@internal@key_helpers:require_non_empty_keys(
        Keys,
        fun() ->
            gleam@result:'try'(
                gleam@list:try_each(
                    Keys,
                    fun(_capture) ->
                        gose@internal@key_helpers:validate_key_for_signing_verification(
                            {digital_signature, Alg},
                            _capture
                        )
                    end
                ),
                fun(_) -> {ok, {verifier, Alg, Keys, none, none, 60, true}} end
            )
        end
    ).

-file("src/gose/cose/cwt.gleam", 258).
?DOC(" Build a CWT verifier pinned to a single signature algorithm and one or more keys.\n").
-spec verifier(gose:digital_signature_alg(), list(gose:key(bitstring()))) -> {ok,
        verifier()} |
    {error, cwt_error()}.
verifier(Alg, Keys) ->
    _pipe = build_verifier(Alg, Keys),
    gleam@result:map_error(_pipe, fun(Field@0) -> {cose_error, Field@0} end).

-file("src/gose/cose/cwt.gleam", 288).
?DOC(" Require the token's `iss` claim to match the given issuer.\n").
-spec with_issuer_validation(verifier(), binary()) -> verifier().
with_issuer_validation(Verifier, Issuer) ->
    {verifier,
        erlang:element(2, Verifier),
        erlang:element(3, Verifier),
        {some, Issuer},
        erlang:element(5, Verifier),
        erlang:element(6, Verifier),
        erlang:element(7, Verifier)}.

-file("src/gose/cose/cwt.gleam", 293).
?DOC(" Require the token's `aud` claim to include the given audience.\n").
-spec with_audience_validation(verifier(), binary()) -> verifier().
with_audience_validation(Verifier, Audience) ->
    {verifier,
        erlang:element(2, Verifier),
        erlang:element(3, Verifier),
        erlang:element(4, Verifier),
        {some, Audience},
        erlang:element(6, Verifier),
        erlang:element(7, Verifier)}.

-file("src/gose/cose/cwt.gleam", 302).
?DOC(
    " Set the allowed clock skew in seconds (default: 60).\n"
    " Tokens are accepted up to `seconds` past `exp` or before `nbf`.\n"
).
-spec with_clock_skew(verifier(), integer()) -> verifier().
with_clock_skew(Verifier, Seconds) ->
    {verifier,
        erlang:element(2, Verifier),
        erlang:element(3, Verifier),
        erlang:element(4, Verifier),
        erlang:element(5, Verifier),
        Seconds,
        erlang:element(7, Verifier)}.

-file("src/gose/cose/cwt.gleam", 307).
?DOC(" Control whether the `exp` claim is required (default: `True`).\n").
-spec with_require_expiration(verifier(), boolean()) -> verifier().
with_require_expiration(Verifier, Required) ->
    {verifier,
        erlang:element(2, Verifier),
        erlang:element(3, Verifier),
        erlang:element(4, Verifier),
        erlang:element(5, Verifier),
        erlang:element(6, Verifier),
        Required}.

-file("src/gose/cose/cwt.gleam", 327).
?DOC(" Extract the validated claims from a verified CWT.\n").
-spec verified_claims(cwt(verified())) -> cwt_claims().
verified_claims(Cwt) ->
    {cwt, Claims} = Cwt,
    Claims.

-file("src/gose/cose/cwt.gleam", 332).
-spec parse_sign1(bitstring()) -> {ok,
        gose@cose@sign1:sign1(gose@cose@sign1:signed())} |
    {error, cwt_error()}.
parse_sign1(Token) ->
    _pipe = gose@cose@sign1:parse(Token),
    gleam@result:map_error(
        _pipe,
        fun(Err) -> {malformed_token, gose:error_message(Err)} end
    ).

-file("src/gose/cose/cwt.gleam", 337).
-spec verify_signature(
    gose:digital_signature_alg(),
    list(gose:key(bitstring())),
    gose@cose@sign1:sign1(gose@cose@sign1:signed())
) -> {ok, nil} | {error, cwt_error()}.
verify_signature(Alg, Keys, Parsed) ->
    gleam@result:'try'(
        begin
            _pipe = gose@cose@sign1:verifier(Alg, Keys),
            gleam@result:map_error(
                _pipe,
                fun(Field@0) -> {cose_error, Field@0} end
            )
        end,
        fun(Sign1_verifier) ->
            case gose@cose@sign1:verify(Sign1_verifier, Parsed) of
                {ok, nil} ->
                    {ok, nil};

                {error, verification_failed} ->
                    {error, invalid_signature};

                {error, {crypto_error, _}} ->
                    {error, invalid_signature};

                {error, Err} ->
                    {error, {cose_error, Err}}
            end
        end
    ).

-file("src/gose/cose/cwt.gleam", 353).
-spec extract_payload(gose@cose@sign1:sign1(gose@cose@sign1:signed())) -> {ok,
        bitstring()} |
    {error, cwt_error()}.
extract_payload(Parsed) ->
    _pipe = gose@cose@sign1:payload(Parsed),
    gleam@result:replace_error(
        _pipe,
        {malformed_token, <<"missing payload"/utf8>>}
    ).

-file("src/gose/cose/cwt.gleam", 380).
-spec encode_audience(list(binary())) -> {gose@cbor:value(), gose@cbor:value()}.
encode_audience(Audiences) ->
    case Audiences of
        [Single] ->
            {{int, 3}, {text, Single}};

        Multiple ->
            {{int, 3},
                {array,
                    gleam@list:map(
                        Multiple,
                        fun(Field@0) -> {text, Field@0} end
                    )}}
    end.

-file("src/gose/cose/cwt.gleam", 366).
-spec encode_registered_claims(cwt_claims()) -> list({gose@cbor:value(),
    gose@cbor:value()}).
encode_registered_claims(Claims) ->
    gleam@option:values(
        [gleam@option:map(
                erlang:element(2, Claims),
                fun(V) -> {{int, 1}, {text, V}} end
            ),
            gleam@option:map(
                erlang:element(3, Claims),
                fun(V@1) -> {{int, 2}, {text, V@1}} end
            ),
            gleam@option:map(erlang:element(4, Claims), fun encode_audience/1),
            gleam@option:map(
                erlang:element(5, Claims),
                fun(V@2) -> {{int, 4}, {int, V@2}} end
            ),
            gleam@option:map(
                erlang:element(6, Claims),
                fun(V@3) -> {{int, 5}, {int, V@3}} end
            ),
            gleam@option:map(
                erlang:element(7, Claims),
                fun(V@4) -> {{int, 6}, {int, V@4}} end
            ),
            gleam@option:map(
                erlang:element(8, Claims),
                fun(V@5) -> {{int, 7}, {bytes, V@5}} end
            )]
    ).

-file("src/gose/cose/cwt.gleam", 360).
-spec encode_claims(cwt_claims()) -> bitstring().
encode_claims(Claims) ->
    Pairs = encode_registered_claims(Claims),
    All_pairs = lists:append(Pairs, erlang:element(9, Claims)),
    gose@cbor:encode({map, All_pairs}).

-file("src/gose/cose/cwt.gleam", 245).
?DOC(" Sign a set of claims as a COSE_Sign1-wrapped CWT, returning the serialized CBOR bytes.\n").
-spec sign(cwt_claims(), gose:digital_signature_alg(), gose:key(bitstring())) -> {ok,
        bitstring()} |
    {error, cwt_error()}.
sign(Claims, Alg, Key) ->
    Payload = encode_claims(Claims),
    Unsigned = gose@cose@sign1:new(Alg),
    _pipe = gose@cose@sign1:sign(Unsigned, Key, Payload),
    _pipe@1 = gleam@result:map(_pipe, fun gose@cose@sign1:serialize/1),
    gleam@result:map_error(_pipe@1, fun(Field@0) -> {cose_error, Field@0} end).

-file("src/gose/cose/cwt.gleam", 409).
-spec decode_optional_text(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer(),
    binary()
) -> {ok, gleam@option:option(binary())} | {error, cwt_error()}.
decode_optional_text(Pairs, Label, Name) ->
    case gleam@list:key_find(Pairs, {int, Label}) of
        {ok, {text, V}} ->
            {ok, {some, V}};

        {ok, _} ->
            {error,
                {malformed_token,
                    <<Name/binary, " claim must be a text string"/utf8>>}};

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/cose/cwt.gleam", 421).
-spec decode_optional_int(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer(),
    binary()
) -> {ok, gleam@option:option(integer())} | {error, cwt_error()}.
decode_optional_int(Pairs, Label, Name) ->
    case gleam@list:key_find(Pairs, {int, Label}) of
        {ok, {int, V}} ->
            {ok, {some, V}};

        {ok, _} ->
            {error,
                {malformed_token,
                    <<Name/binary, " claim must be an integer"/utf8>>}};

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/cose/cwt.gleam", 433).
-spec decode_optional_bytes(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer(),
    binary()
) -> {ok, gleam@option:option(bitstring())} | {error, cwt_error()}.
decode_optional_bytes(Pairs, Label, Name) ->
    case gleam@list:key_find(Pairs, {int, Label}) of
        {ok, {bytes, V}} ->
            {ok, {some, V}};

        {ok, _} ->
            {error,
                {malformed_token,
                    <<Name/binary, " claim must be a byte string"/utf8>>}};

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/cose/cwt.gleam", 459).
-spec decode_audience_array(list(gose@cbor:value())) -> {ok,
        gleam@option:option(list(binary()))} |
    {error, cwt_error()}.
decode_audience_array(Items) ->
    _pipe = gleam@list:try_map(Items, fun(Item) -> case Item of
                {text, S} ->
                    {ok, S};

                _ ->
                    {error,
                        {malformed_token,
                            <<"aud array must contain only text strings"/utf8>>}}
            end end),
    gleam@result:map(_pipe, fun(Field@0) -> {some, Field@0} end).

-file("src/gose/cose/cwt.gleam", 445).
-spec decode_optional_audience(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gleam@option:option(list(binary()))} |
    {error, cwt_error()}.
decode_optional_audience(Pairs) ->
    case gleam@list:key_find(Pairs, {int, 3}) of
        {ok, {text, V}} ->
            {ok, {some, [V]}};

        {ok, {array, Items}} ->
            decode_audience_array(Items);

        {ok, _} ->
            {error,
                {malformed_token,
                    <<"aud claim must be a text string or array of text strings"/utf8>>}};

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/cose/cwt.gleam", 471).
-spec extract_custom_claims(list({gose@cbor:value(), gose@cbor:value()})) -> list({gose@cbor:value(),
    gose@cbor:value()}).
extract_custom_claims(Pairs) ->
    gleam@list:filter(Pairs, fun(Pair) -> case erlang:element(1, Pair) of
                {int, 1} ->
                    false;

                {int, 2} ->
                    false;

                {int, 3} ->
                    false;

                {int, 4} ->
                    false;

                {int, 5} ->
                    false;

                {int, 6} ->
                    false;

                {int, 7} ->
                    false;

                _ ->
                    true
            end end).

-file("src/gose/cose/cwt.gleam", 395).
-spec decode_claims_from_map(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        cwt_claims()} |
    {error, cwt_error()}.
decode_claims_from_map(Pairs) ->
    gleam@result:'try'(
        decode_optional_text(Pairs, 1, <<"iss"/utf8>>),
        fun(Iss) ->
            gleam@result:'try'(
                decode_optional_text(Pairs, 2, <<"sub"/utf8>>),
                fun(Sub) ->
                    gleam@result:'try'(
                        decode_optional_audience(Pairs),
                        fun(Aud) ->
                            gleam@result:'try'(
                                decode_optional_int(Pairs, 4, <<"exp"/utf8>>),
                                fun(Exp) ->
                                    gleam@result:'try'(
                                        decode_optional_int(
                                            Pairs,
                                            5,
                                            <<"nbf"/utf8>>
                                        ),
                                        fun(Nbf) ->
                                            gleam@result:'try'(
                                                decode_optional_int(
                                                    Pairs,
                                                    6,
                                                    <<"iat"/utf8>>
                                                ),
                                                fun(Iat) ->
                                                    gleam@result:'try'(
                                                        decode_optional_bytes(
                                                            Pairs,
                                                            7,
                                                            <<"cti"/utf8>>
                                                        ),
                                                        fun(Cti) ->
                                                            Custom = extract_custom_claims(
                                                                Pairs
                                                            ),
                                                            {ok,
                                                                {cwt_claims,
                                                                    Iss,
                                                                    Sub,
                                                                    Aud,
                                                                    Exp,
                                                                    Nbf,
                                                                    Iat,
                                                                    Cti,
                                                                    Custom}}
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

-file("src/gose/cose/cwt.gleam", 387).
-spec decode_claims(bitstring()) -> {ok, cwt_claims()} | {error, cwt_error()}.
decode_claims(Payload) ->
    case gose@cbor:decode(Payload) of
        {ok, {map, Pairs}} ->
            decode_claims_from_map(Pairs);

        {ok, _} ->
            {error, {malformed_token, <<"CWT claims must be a CBOR map"/utf8>>}};

        {error, Err} ->
            {error, {malformed_token, gose:error_message(Err)}}
    end.

-file("src/gose/cose/cwt.gleam", 501).
-spec validate_exp(cwt_claims(), integer(), verifier()) -> {ok, nil} |
    {error, cwt_error()}.
validate_exp(Claims, Now_seconds, Verifier) ->
    case {erlang:element(5, Claims), erlang:element(7, Verifier)} of
        {none, true} ->
            {error, missing_expiration};

        {none, false} ->
            {ok, nil};

        {{some, Exp}, _} ->
            Adjusted_now = Now_seconds - erlang:element(6, Verifier),
            gleam@bool:guard(
                Adjusted_now >= Exp,
                {error,
                    {token_expired, gleam@time@timestamp:from_unix_seconds(Exp)}},
                fun() -> {ok, nil} end
            )
    end.

-file("src/gose/cose/cwt.gleam", 522).
-spec validate_nbf(cwt_claims(), integer(), verifier()) -> {ok, nil} |
    {error, cwt_error()}.
validate_nbf(Claims, Now_seconds, Verifier) ->
    case erlang:element(6, Claims) of
        none ->
            {ok, nil};

        {some, Nbf} ->
            Adjusted_now = Now_seconds + erlang:element(6, Verifier),
            gleam@bool:guard(
                Adjusted_now < Nbf,
                {error,
                    {token_not_yet_valid,
                        gleam@time@timestamp:from_unix_seconds(Nbf)}},
                fun() -> {ok, nil} end
            )
    end.

-file("src/gose/cose/cwt.gleam", 542).
-spec validate_issuer(cwt_claims(), verifier()) -> {ok, nil} |
    {error, cwt_error()}.
validate_issuer(Claims, Verifier) ->
    case {erlang:element(4, Verifier), erlang:element(2, Claims)} of
        {none, _} ->
            {ok, nil};

        {{some, Expected}, {some, Actual}} when Expected =:= Actual ->
            {ok, nil};

        {{some, Expected@1}, Actual@1} ->
            {error, {issuer_mismatch, Expected@1, Actual@1}}
    end.

-file("src/gose/cose/cwt.gleam", 553).
-spec validate_audience_claim(cwt_claims(), verifier()) -> {ok, nil} |
    {error, cwt_error()}.
validate_audience_claim(Claims, Verifier) ->
    case {erlang:element(5, Verifier), erlang:element(4, Claims)} of
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

-file("src/gose/cose/cwt.gleam", 488).
-spec validate_claims(
    cwt_claims(),
    gleam@time@timestamp:timestamp(),
    verifier()
) -> {ok, nil} | {error, cwt_error()}.
validate_claims(Claims, Now, Verifier) ->
    {Now_seconds, _} = gleam@time@timestamp:to_unix_seconds_and_nanoseconds(Now),
    gleam@result:'try'(
        validate_exp(Claims, Now_seconds, Verifier),
        fun(_) ->
            gleam@result:'try'(
                validate_nbf(Claims, Now_seconds, Verifier),
                fun(_) ->
                    gleam@result:'try'(
                        validate_issuer(Claims, Verifier),
                        fun(_) -> validate_audience_claim(Claims, Verifier) end
                    )
                end
            )
        end
    ).

-file("src/gose/cose/cwt.gleam", 312).
?DOC(" Parse, verify the signature, and validate claims in one step.\n").
-spec verify_and_validate(
    verifier(),
    bitstring(),
    gleam@time@timestamp:timestamp()
) -> {ok, cwt(verified())} | {error, cwt_error()}.
verify_and_validate(Verifier, Token, Now) ->
    {verifier, Alg, Keys, _, _, _, _} = Verifier,
    gleam@result:'try'(
        parse_sign1(Token),
        fun(Parsed) ->
            gleam@result:'try'(
                verify_signature(Alg, Keys, Parsed),
                fun(_) ->
                    gleam@result:'try'(
                        extract_payload(Parsed),
                        fun(Payload) ->
                            gleam@result:'try'(
                                decode_claims(Payload),
                                fun(Claims) ->
                                    gleam@result:'try'(
                                        validate_claims(Claims, Now, Verifier),
                                        fun(_) -> {ok, {cwt, Claims}} end
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).
