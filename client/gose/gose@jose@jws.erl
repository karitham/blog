-module(gose@jose@jws).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/jws.gleam").
-export([new/1, verifier/2, with_detached/1, with_unencoded/1, with_cty/2, with_kid/2, with_typ/2, alg/1, cty/1, decode_custom_headers/2, decode_unprotected_header/2, has_unprotected_header/1, is_detached/1, has_unencoded_payload/1, kid/1, payload/1, typ/1, verify/2, verify_detached/3, sign/3, serialize_compact/1, serialize_json_flattened/1, serialize_json_general/1, with_unprotected/3, with_header/3, parse_compact/1, parse_json/1]).
-export_type([built/0, parsed/0, signed/0, unsigned/0, jws_header/0, parsed_header/0, jws/2, verifier/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " JSON Web Signature (JWS) - [RFC 7515](https://www.rfc-editor.org/rfc/rfc7515.html)\n"
    "\n"
    " Digital signatures using all algorithms from RFC 7518: HMAC\n"
    " (HS256/384/512), RSA (RS256/384/512, PS256/384/512), ECDSA\n"
    " (ES256/384/512), and EdDSA.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/jose/jws\n"
    "\n"
    " let key = gose.generate_hmac_key(gose.HmacSha256)\n"
    " let payload = <<\"hello world\":utf8>>\n"
    "\n"
    " // Create and sign a JWS\n"
    " let assert Ok(signed) = jws.new(gose.Mac(gose.Hmac(gose.HmacSha256)))\n"
    "   |> jws.sign(key, payload)\n"
    "\n"
    " // Serialize to compact format\n"
    " let assert Ok(token) = jws.serialize_compact(signed)\n"
    "\n"
    " // Parse and verify using a Verifier\n"
    " let assert Ok(parsed) = jws.parse_compact(token)\n"
    " let assert Ok(verifier) =\n"
    "   jws.verifier(gose.Mac(gose.Hmac(gose.HmacSha256)), keys: [key])\n"
    " let assert Ok(Nil) = jws.verify(verifier, parsed)\n"
    " ```\n"
    "\n"
    " ## Phantom Types\n"
    "\n"
    " `Jws(state, origin)` carries two phantom parameters. The state is\n"
    " `Unsigned` before `sign` and `Signed` after, so only signed instances\n"
    " can be serialized or verified. The origin is `Built` for JWS values\n"
    " produced by `new` and `sign`, and `Parsed` for values from\n"
    " `parse_compact` or `parse_json`. This prevents calling\n"
    " `decode_unprotected_header` on a builder-created JWS (which has no\n"
    " raw JSON to decode from).\n"
    "\n"
    " ## Algorithm Pinning\n"
    "\n"
    " Each verifier is pinned to a single algorithm. This is a deliberate\n"
    " security design, not a limitation. Algorithm confusion attacks\n"
    " (e.g., CVE-2015-9235) exploit libraries that trust the `alg` header\n"
    " from the token itself, allowing an attacker to switch from an asymmetric\n"
    " algorithm to HMAC and sign with a public key. By requiring the caller\n"
    " to declare the expected algorithm upfront, gose ensures the token's\n"
    " `alg` header is verified against the application's intent, not the\n"
    " other way around. This follows RFC 8725 Section 3.1: the algorithm\n"
    " used for verification should be specified by the application, not\n"
    " taken from the message.\n"
    "\n"
    " Algorithm pinning is enforced at multiple levels:\n"
    "\n"
    " 1. **Verifier pinning**: `verifier()` requires the expected algorithm;\n"
    "    tokens with different algorithms are rejected by `verify` and\n"
    "    `verify_detached`.\n"
    " 2. **JWK `alg` metadata**: If a key has `alg` set via `gose.with_alg`,\n"
    "    the JWS algorithm must match during signing and verification.\n"
    " 3. **JWT verifier**: `jwt.verifier()` requires the expected algorithm upfront;\n"
    "    tokens with different algorithms are rejected.\n"
    " 4. **Key type validation**: The key type must match the algorithm (RSA for\n"
    "    RS256, EC P-256 for ES256, etc.).\n"
    "\n"
    " ### Multi-Algorithm Verification\n"
    "\n"
    " When migrating between algorithms (e.g., RS256 to ES256) or consuming\n"
    " tokens from issuers that use different algorithms, create one verifier\n"
    " per algorithm and try each in sequence:\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(rs_verifier) =\n"
    "   jws.verifier(\n"
    "     gose.DigitalSignature(gose.RsaPkcs1(gose.RsaPkcs1Sha256)),\n"
    "     keys: rsa_keys,\n"
    "   )\n"
    " let assert Ok(ec_verifier) =\n"
    "   jws.verifier(\n"
    "     gose.DigitalSignature(gose.Ecdsa(gose.EcdsaP256)),\n"
    "     keys: ec_keys,\n"
    "   )\n"
    "\n"
    " let assert Ok(parsed) = jws.parse_compact(token)\n"
    " let result = case jws.verify(rs_verifier, parsed) {\n"
    "   Ok(Nil) -> Ok(Nil)\n"
    "   _ -> jws.verify(ec_verifier, parsed)\n"
    " }\n"
    " ```\n"
    "\n"
    " This keeps each verifier's algorithm policy explicit and auditable,\n"
    " rather than hiding multi-algorithm logic inside the library.\n"
    "\n"
    " ## Custom Headers\n"
    "\n"
    " Custom headers can be added via `with_header` when building a JWS. For\n"
    " parsed JWS, use `decode_custom_headers` with a custom decoder to extract\n"
    " header values. `with_header` rejects reserved names (`alg`, `kid`, `typ`,\n"
    " `cty`, `crit`, `b64`) to prevent conflicts with standard behavior.\n"
    "\n"
    " ## Unprotected Headers\n"
    "\n"
    " Unprotected headers can be added via `with_unprotected` (for JSON serialization)\n"
    " and accessed via `decode_unprotected_header`. When parsing JSON format,\n"
    " unprotected header names must not overlap with protected header names.\n"
    "\n"
    " **Security Warning:** Unprotected headers are NOT integrity protected.\n"
    " They can be modified by an attacker without invalidating the signature.\n"
    " Only use for non-security-critical metadata.\n"
    "\n"
    " ## Critical Header Support\n"
    "\n"
    " The `crit` header is validated per RFC 7515:\n"
    " - Empty arrays are rejected\n"
    " - Standard headers cannot appear in `crit`\n"
    " - `b64` (RFC 7797 unencoded payload) is the only supported extension\n"
    " - Unknown extensions are rejected\n"
    "\n"
    " ## Key Metadata\n"
    "\n"
    " JWK metadata (`use`, `key_ops`) is enforced during signing and verification.\n"
    " Keys with incompatible metadata are rejected.\n"
    "\n"
    " ## JSON Serialization Limitations\n"
    "\n"
    " `parse_json` accepts only a single signature. For multi-signer\n"
    " messages, use `gose/jose/jws_multi`.\n"
).

-type built() :: any().

-type parsed() :: any().

-type signed() :: any().

-type unsigned() :: any().

-type jws_header() :: {jws_header,
        gose:signing_alg(),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@dict:dict(binary(), gleam@json:json())}.

-type parsed_header() :: {parsed_header,
        jws_header(),
        boolean(),
        gleam@option:option(gleam@dynamic:dynamic_()),
        gleam@set:set(binary())}.

-opaque jws(VQR, VQS) :: {unsigned_jws,
        jws_header(),
        bitstring(),
        boolean(),
        boolean(),
        gleam@dict:dict(binary(), gleam@json:json())} |
    {signed_jws,
        jws_header(),
        gleam@option:option(gleam@dynamic:dynamic_()),
        bitstring(),
        boolean(),
        boolean(),
        binary(),
        binary(),
        bitstring(),
        gleam@dict:dict(binary(), gleam@json:json()),
        gleam@option:option(gleam@dynamic:dynamic_())} |
    {gleam_phantom, VQR, VQS}.

-opaque verifier() :: {verifier, gose:signing_alg(), list(gose:key(binary()))}.

-file("src/gose/jose/jws.gleam", 226).
?DOC(
    " Create a new unsigned JWS with the specified signing algorithm. The payload\n"
    " is provided at sign time via `sign`.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(signed) = jws.new(gose.Mac(gose.Hmac(gose.HmacSha256)))\n"
    "   |> jws.sign(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec new(gose:signing_alg()) -> jws(unsigned(), built()).
new(Alg) ->
    {unsigned_jws,
        {jws_header, Alg, none, none, none, maps:new()},
        <<>>,
        false,
        false,
        maps:new()}.

-file("src/gose/jose/jws.gleam", 251).
?DOC(
    " Create a verifier for JWS signature verification.\n"
    "\n"
    " Accepts one or more keys for key rotation scenarios. The verifier pins\n"
    " the expected algorithm and will reject tokens with different algorithms.\n"
    "\n"
    " Key selection during verification:\n"
    " 1. If the JWS has a `kid` header, prioritize keys with matching kid\n"
    " 2. Try keys in order until one succeeds\n"
    " 3. Fail if no key verifies the signature\n"
).
-spec verifier(gose:signing_alg(), list(gose:key(binary()))) -> {ok, verifier()} |
    {error, gose:gose_error()}.
verifier(Alg, Keys) ->
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
                fun(_) -> {ok, {verifier, Alg, Keys}} end
            )
        end
    ).

-file("src/gose/jose/jws.gleam", 274).
?DOC(
    " Mark this JWS as using a detached payload.\n"
    "\n"
    " The payload will not be included in the serialized output, but is still\n"
    " provided at sign time and used for signature computation.\n"
).
-spec with_detached(jws(unsigned(), built())) -> jws(unsigned(), built()).
with_detached(Jws) ->
    {Header@1, Payload@1, Unencoded_payload@1, Unprotected@1} = case Jws of
        {unsigned_jws, Header, Payload, _, Unencoded_payload, Unprotected} -> {
        Header,
            Payload,
            Unencoded_payload,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"with_detached"/utf8>>,
                        line => 275,
                        value => _assert_fail,
                        start => 9264,
                        'end' => 9374,
                        pattern_start => 9275,
                        pattern_end => 9368})
    end,
    {unsigned_jws,
        Header@1,
        Payload@1,
        true,
        Unencoded_payload@1,
        Unprotected@1}.

-file("src/gose/jose/jws.gleam", 331).
?DOC(
    " Mark this JWS as using an unencoded payload (RFC 7797, b64=false).\n"
    "\n"
    " The payload will be included directly in the serialized output without\n"
    " base64 encoding. The header will include `\"crit\":[\"b64\"],\"b64\":false`.\n"
    " The payload is still provided at sign time.\n"
).
-spec with_unencoded(jws(unsigned(), built())) -> jws(unsigned(), built()).
with_unencoded(Jws) ->
    {Header@1, Payload@1, Detached@1, Unprotected@1} = case Jws of
        {unsigned_jws, Header, Payload, Detached, _, Unprotected} -> {
        Header,
            Payload,
            Detached,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"with_unencoded"/utf8>>,
                        line => 332,
                        value => _assert_fail,
                        start => 11097,
                        'end' => 11173,
                        pattern_start => 11108,
                        pattern_end => 11167})
    end,
    {unsigned_jws, Header@1, Payload@1, Detached@1, true, Unprotected@1}.

-file("src/gose/jose/jws.gleam", 381).
-spec map_unsigned_header(
    jws(unsigned(), built()),
    fun((jws_header()) -> jws_header())
) -> jws(unsigned(), built()).
map_unsigned_header(Jws, F) ->
    {Header@1, Payload@1, Detached@1, Unencoded_payload@1, Unprotected@1} = case Jws of
        {unsigned_jws,
            Header,
            Payload,
            Detached,
            Unencoded_payload,
            Unprotected} -> {
        Header,
            Payload,
            Detached,
            Unencoded_payload,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"map_unsigned_header"/utf8>>,
                        line => 385,
                        value => _assert_fail,
                        start => 12584,
                        'end' => 12701,
                        pattern_start => 12595,
                        pattern_end => 12695})
    end,
    {unsigned_jws,
        F(Header@1),
        Payload@1,
        Detached@1,
        Unencoded_payload@1,
        Unprotected@1}.

-file("src/gose/jose/jws.gleam", 266).
?DOC(" Set the content type (cty) header parameter.\n").
-spec with_cty(jws(unsigned(), built()), binary()) -> jws(unsigned(), built()).
with_cty(Jws, Cty) ->
    map_unsigned_header(
        Jws,
        fun(H) ->
            {jws_header,
                erlang:element(2, H),
                erlang:element(3, H),
                erlang:element(4, H),
                {some, Cty},
                erlang:element(6, H)}
        end
    ).

-file("src/gose/jose/jws.gleam", 317).
?DOC(" Set the key ID (kid) header parameter.\n").
-spec with_kid(jws(unsigned(), built()), binary()) -> jws(unsigned(), built()).
with_kid(Jws, Kid) ->
    map_unsigned_header(
        Jws,
        fun(H) ->
            {jws_header,
                erlang:element(2, H),
                {some, Kid},
                erlang:element(4, H),
                erlang:element(5, H),
                erlang:element(6, H)}
        end
    ).

-file("src/gose/jose/jws.gleam", 322).
?DOC(" Set the type (typ) header parameter (e.g., \"JWT\").\n").
-spec with_typ(jws(unsigned(), built()), binary()) -> jws(unsigned(), built()).
with_typ(Jws, Typ) ->
    map_unsigned_header(
        Jws,
        fun(H) ->
            {jws_header,
                erlang:element(2, H),
                erlang:element(3, H),
                {some, Typ},
                erlang:element(5, H),
                erlang:element(6, H)}
        end
    ).

-file("src/gose/jose/jws.gleam", 402).
?DOC(" Get the algorithm (`alg`) from a JWS.\n").
-spec alg(jws(any(), any())) -> gose:signing_alg().
alg(Jws) ->
    erlang:element(2, erlang:element(2, Jws)).

-file("src/gose/jose/jws.gleam", 407).
?DOC(" Get the content type (cty) from a JWS header.\n").
-spec cty(jws(any(), any())) -> {ok, binary()} | {error, nil}.
cty(Jws) ->
    gleam@option:to_result(erlang:element(5, erlang:element(2, Jws)), nil).

-file("src/gose/jose/jws.gleam", 415).
?DOC(
    " Decode custom headers from a parsed JWS using a custom decoder.\n"
    "\n"
    " This allows reading non-standard header fields that were present during parsing.\n"
    " For JWS built via `new`, you already know what headers you set.\n"
).
-spec decode_custom_headers(
    jws(signed(), parsed()),
    gleam@dynamic@decode:decoder(VSV)
) -> {ok, VSV} | {error, gose:gose_error()}.
decode_custom_headers(Jws, Decoder) ->
    Header_raw@1 = case Jws of
        {signed_jws, _, Header_raw, _, _, _, _, _, _, _, _} -> Header_raw;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"decode_custom_headers"/utf8>>,
                        line => 419,
                        value => _assert_fail,
                        start => 13439,
                        'end' => 13482,
                        pattern_start => 13450,
                        pattern_end => 13476})
    end,
    case Header_raw@1 of
        {some, Raw} ->
            _pipe = gleam@dynamic@decode:run(Raw, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"failed to decode custom headers"/utf8>>}
            );

        none ->
            {error, {parse_error, <<"no header data available"/utf8>>}}
    end.

-file("src/gose/jose/jws.gleam", 437).
?DOC(
    " Decode the unprotected header using a custom decoder.\n"
    "\n"
    " **Security Warning:** Unprotected headers are NOT integrity protected.\n"
    " They can be modified by an attacker without invalidating the signature.\n"
    " Only use for non-security-critical metadata.\n"
    "\n"
    " This function only works on parsed JWS instances. When building a JWS,\n"
    " you already know what unprotected headers you set - use `has_unprotected_header`\n"
    " to check their presence.\n"
).
-spec decode_unprotected_header(
    jws(signed(), parsed()),
    gleam@dynamic@decode:decoder(VTB)
) -> {ok, VTB} | {error, gose:gose_error()}.
decode_unprotected_header(Jws, Decoder) ->
    Unprotected_raw@1 = case Jws of
        {signed_jws, _, _, _, _, _, _, _, _, _, Unprotected_raw} -> Unprotected_raw;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"decode_unprotected_header"/utf8>>,
                        line => 441,
                        value => _assert_fail,
                        start => 14299,
                        'end' => 14347,
                        pattern_start => 14310,
                        pattern_end => 14341})
    end,
    case Unprotected_raw@1 of
        {some, Raw} ->
            _pipe = gleam@dynamic@decode:run(Raw, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"failed to decode unprotected header"/utf8>>}
            );

        none ->
            {error, {parse_error, <<"no unprotected headers present"/utf8>>}}
    end.

-file("src/gose/jose/jws.gleam", 456).
?DOC(
    " Check if the JWS has unprotected headers.\n"
    "\n"
    " Returns True if the JWS was parsed from JSON with unprotected headers,\n"
    " or if unprotected headers were added via `with_unprotected`.\n"
).
-spec has_unprotected_header(jws(signed(), any())) -> boolean().
has_unprotected_header(Jws) ->
    {Unprotected@1, Unprotected_raw@1} = case Jws of
        {signed_jws, _, _, _, _, _, _, _, _, Unprotected, Unprotected_raw} -> {
        Unprotected,
            Unprotected_raw};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"has_unprotected_header"/utf8>>,
                        line => 457,
                        value => _assert_fail,
                        start => 14872,
                        'end' => 14934,
                        pattern_start => 14883,
                        pattern_end => 14928})
    end,
    gleam@option:is_some(Unprotected_raw@1) orelse not gleam@dict:is_empty(
        Unprotected@1
    ).

-file("src/gose/jose/jws.gleam", 462).
?DOC(" Check if the JWS has a detached payload.\n").
-spec is_detached(jws(any(), any())) -> boolean().
is_detached(Jws) ->
    case Jws of
        {unsigned_jws, _, _, Detached, _, _} ->
            Detached;

        {signed_jws, _, _, _, Detached@1, _, _, _, _, _, _} ->
            Detached@1
    end.

-file("src/gose/jose/jws.gleam", 470).
?DOC(" Check if the JWS uses an unencoded payload (b64=false per RFC 7797).\n").
-spec has_unencoded_payload(jws(any(), any())) -> boolean().
has_unencoded_payload(Jws) ->
    case Jws of
        {unsigned_jws, _, _, _, Unencoded_payload, _} ->
            Unencoded_payload;

        {signed_jws, _, _, _, _, Unencoded_payload@1, _, _, _, _, _} ->
            Unencoded_payload@1
    end.

-file("src/gose/jose/jws.gleam", 485).
?DOC(
    " Get the key ID (kid) from a JWS header.\n"
    "\n"
    " **Security Warning:** The `kid` value comes from the token and is untrusted\n"
    " input. If you use it to look up keys (from a database, filesystem, or key\n"
    " store), you must sanitize it first to prevent injection attacks:\n"
    " - Use parameterized queries for database lookups\n"
    " - Validate the format matches your expected key ID pattern\n"
    " - Never use it directly in file paths or shell commands\n"
).
-spec kid(jws(any(), any())) -> {ok, binary()} | {error, nil}.
kid(Jws) ->
    gleam@option:to_result(erlang:element(3, erlang:element(2, Jws)), nil).

-file("src/gose/jose/jws.gleam", 490).
?DOC(" Get the payload from a JWS.\n").
-spec payload(jws(any(), any())) -> bitstring().
payload(Jws) ->
    case Jws of
        {unsigned_jws, _, Payload, _, _, _} ->
            Payload;

        {signed_jws, _, _, Payload@1, _, _, _, _, _, _, _} ->
            Payload@1
    end.

-file("src/gose/jose/jws.gleam", 498).
?DOC(" Get the type (typ) from a JWS header.\n").
-spec typ(jws(any(), any())) -> {ok, binary()} | {error, nil}.
typ(Jws) ->
    gleam@option:to_result(erlang:element(4, erlang:element(2, Jws)), nil).

-file("src/gose/jose/jws.gleam", 559).
-spec do_verify(jws(signed(), any()), gose:key(binary())) -> {ok, nil} |
    {error, gose:gose_error()}.
do_verify(Jws, Key) ->
    {Header@1, Detached@1, Protected_b64@1, Payload_segment@1, Signature@1} = case Jws of
        {signed_jws,
            Header,
            _,
            _,
            Detached,
            _,
            Protected_b64,
            Payload_segment,
            Signature,
            _,
            _} -> {Header, Detached, Protected_b64, Payload_segment, Signature};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"do_verify"/utf8>>,
                        line => 563,
                        value => _assert_fail,
                        start => 18056,
                        'end' => 18181,
                        pattern_start => 18067,
                        pattern_end => 18175})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_use(Key, for_verification),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@key_helpers:validate_key_ops(
                    Key,
                    for_verification
                ),
                fun(_) ->
                    gleam@result:'try'(
                        gose@internal@key_helpers:validate_key_algorithm_signing(
                            Key,
                            erlang:element(2, Header@1)
                        ),
                        fun(_) ->
                            gleam@bool:guard(
                                Detached@1,
                                {error,
                                    {invalid_state,
                                        <<"Cannot verify detached JWS without payload. Use verify_detached instead."/utf8>>}},
                                fun() ->
                                    Signing_input = <<<<Protected_b64@1/binary,
                                            "."/utf8>>/binary,
                                        Payload_segment@1/binary>>,
                                    gose@internal@signing:verify_signature(
                                        erlang:element(2, Header@1),
                                        Key,
                                        gleam_stdlib:identity(Signing_input),
                                        Signature@1
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jws.gleam", 642).
-spec encode_payload_segment(bitstring(), boolean()) -> {ok, binary()} |
    {error, nil}.
encode_payload_segment(Payload, Unencoded) ->
    case Unencoded of
        true ->
            gleam@bit_array:to_string(Payload);

        false ->
            {ok, gose@internal@utils:encode_base64_url(Payload)}
    end.

-file("src/gose/jose/jws.gleam", 601).
-spec do_verify_with_payload(
    jws(signed(), any()),
    bitstring(),
    gose:key(binary())
) -> {ok, nil} | {error, gose:gose_error()}.
do_verify_with_payload(Jws, Payload, Key) ->
    {Header@1, Unencoded_payload@1, Protected_b64@1, Signature@1} = case Jws of
        {signed_jws,
            Header,
            _,
            _,
            _,
            Unencoded_payload,
            Protected_b64,
            _,
            Signature,
            _,
            _} -> {Header, Unencoded_payload, Protected_b64, Signature};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"do_verify_with_payload"/utf8>>,
                        line => 606,
                        value => _assert_fail,
                        start => 18983,
                        'end' => 19095,
                        pattern_start => 18994,
                        pattern_end => 19089})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_use(Key, for_verification),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@key_helpers:validate_key_ops(
                    Key,
                    for_verification
                ),
                fun(_) ->
                    gleam@result:'try'(
                        gose@internal@key_helpers:validate_key_algorithm_signing(
                            Key,
                            erlang:element(2, Header@1)
                        ),
                        fun(_) ->
                            gleam@result:'try'(
                                begin
                                    _pipe = encode_payload_segment(
                                        Payload,
                                        Unencoded_payload@1
                                    ),
                                    gleam@result:replace_error(
                                        _pipe,
                                        {invalid_state,
                                            <<"unencoded payload must be valid UTF-8"/utf8>>}
                                    )
                                end,
                                fun(Payload_segment) ->
                                    Signing_input = <<<<Protected_b64@1/binary,
                                            "."/utf8>>/binary,
                                        Payload_segment/binary>>,
                                    gose@internal@signing:verify_signature(
                                        erlang:element(2, Header@1),
                                        Key,
                                        gleam_stdlib:identity(Signing_input),
                                        Signature@1
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jws.gleam", 652).
-spec decode_payload_segment(binary(), boolean()) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
decode_payload_segment(Segment, Unencoded) ->
    case Unencoded of
        true ->
            {ok, gleam_stdlib:identity(Segment)};

        false ->
            gose@internal@utils:decode_base64_url(Segment, <<"payload"/utf8>>)
    end.

-file("src/gose/jose/jws.gleam", 703).
-spec try_verify_keys(jws(signed(), any()), list(gose:key(binary()))) -> {ok,
        nil} |
    {error, gose:gose_error()}.
try_verify_keys(Jws, Keys) ->
    case Keys of
        [] ->
            {error, verification_failed};

        [Key | Rest] ->
            case do_verify(Jws, Key) of
                {ok, nil} ->
                    {ok, nil};

                {error, verification_failed} ->
                    try_verify_keys(Jws, Rest);

                {error, Err} ->
                    {error, Err}
            end
    end.

-file("src/gose/jose/jws.gleam", 688).
?DOC(
    " Verify a JWS signature using the verifier.\n"
    "\n"
    " Checks:\n"
    " 1. Token's `alg` header matches the verifier's expected algorithm\n"
    " 2. Signature is valid for one of the verifier's keys\n"
    "\n"
    " When multiple keys are configured, keys with matching `kid` are tried first.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(v) =\n"
    "   jws.verifier(gose.Mac(gose.Hmac(gose.HmacSha256)), [key])\n"
    " let assert Ok(parsed) = jws.parse_compact(token)\n"
    " let assert Ok(Nil) = jws.verify(v, parsed)\n"
    " ```\n"
).
-spec verify(verifier(), jws(signed(), any())) -> {ok, nil} |
    {error, gose:gose_error()}.
verify(Verifier, Jws) ->
    {verifier, Expected_alg, Keys} = Verifier,
    gleam@result:'try'(
        gose@internal@key_helpers:require_matching_signing_algorithm(
            Expected_alg,
            alg(Jws)
        ),
        fun(_) ->
            Jws_kid = gleam@option:from_result(kid(Jws)),
            Ordered_keys = gose@internal@key_helpers:order_keys_by_kid(
                Keys,
                Jws_kid
            ),
            try_verify_keys(Jws, Ordered_keys)
        end
    ).

-file("src/gose/jose/jws.gleam", 753).
-spec try_verify_detached_keys(
    jws(signed(), any()),
    bitstring(),
    list(gose:key(binary()))
) -> {ok, nil} | {error, gose:gose_error()}.
try_verify_detached_keys(Jws, Payload, Keys) ->
    case Keys of
        [] ->
            {error, verification_failed};

        [Key | Rest] ->
            case do_verify_with_payload(Jws, Payload, Key) of
                {ok, nil} ->
                    {ok, nil};

                {error, verification_failed} ->
                    try_verify_detached_keys(Jws, Payload, Rest);

                {error, Err} ->
                    {error, Err}
            end
    end.

-file("src/gose/jose/jws.gleam", 730).
?DOC(
    " Verify a JWS with a detached payload using the verifier.\n"
    "\n"
    " Use this when the payload was not included in the serialized JWS.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(v) =\n"
    "   jws.verifier(gose.Mac(gose.Hmac(gose.HmacSha256)), [key])\n"
    " let assert Ok(parsed) = jws.parse_compact(detached_token)\n"
    " let assert Ok(Nil) = jws.verify_detached(v, parsed, payload)\n"
    " ```\n"
).
-spec verify_detached(verifier(), jws(signed(), any()), bitstring()) -> {ok,
        nil} |
    {error, gose:gose_error()}.
verify_detached(Verifier, Jws, Payload) ->
    gleam@bool:guard(
        not is_detached(Jws),
        {error,
            {invalid_state,
                <<"JWS payload is not detached; use verify instead"/utf8>>}},
        fun() ->
            {verifier, Expected_alg, Keys} = Verifier,
            gleam@result:'try'(
                gose@internal@key_helpers:require_matching_signing_algorithm(
                    Expected_alg,
                    alg(Jws)
                ),
                fun(_) ->
                    Jws_kid = gleam@option:from_result(kid(Jws)),
                    Ordered_keys = gose@internal@key_helpers:order_keys_by_kid(
                        Keys,
                        Jws_kid
                    ),
                    try_verify_detached_keys(Jws, Payload, Ordered_keys)
                end
            )
        end
    ).

-file("src/gose/jose/jws.gleam", 770).
-spec header_to_json(jws_header(), boolean()) -> bitstring().
header_to_json(Header, Unencoded_payload) ->
    Alg_field = {<<"alg"/utf8>>,
        gleam@json:string(
            gose@jose:signing_alg_to_string(erlang:element(2, Header))
        )},
    Optional_fields = gleam@option:values(
        [gleam@option:map(
                erlang:element(3, Header),
                fun(K) -> {<<"kid"/utf8>>, gleam@json:string(K)} end
            ),
            gleam@option:map(
                erlang:element(4, Header),
                fun(T) -> {<<"typ"/utf8>>, gleam@json:string(T)} end
            ),
            gleam@option:map(
                erlang:element(5, Header),
                fun(C) -> {<<"cty"/utf8>>, gleam@json:string(C)} end
            )]
    ),
    B64_fields = case Unencoded_payload of
        true ->
            [{<<"b64"/utf8>>, gleam@json:bool(false)},
                {<<"crit"/utf8>>,
                    gleam@json:array([<<"b64"/utf8>>], fun gleam@json:string/1)}];

        false ->
            []
    end,
    Custom_sorted = begin
        _pipe = erlang:element(6, Header),
        _pipe@1 = maps:to_list(_pipe),
        gleam@list:sort(
            _pipe@1,
            fun(A, B) ->
                gleam@string:compare(erlang:element(1, A), erlang:element(1, B))
            end
        )
    end,
    Fields = begin
        _pipe@2 = [Alg_field | Optional_fields],
        _pipe@3 = lists:append(_pipe@2, B64_fields),
        lists:append(_pipe@3, Custom_sorted)
    end,
    _pipe@4 = gleam@json:object(Fields),
    _pipe@5 = gleam@json:to_string(_pipe@4),
    gleam_stdlib:identity(_pipe@5).

-file("src/gose/jose/jws.gleam", 507).
?DOC(
    " Sign an unsigned JWS with the provided key.\n"
    "\n"
    " JWK metadata (`use`, `key_ops`) is enforced when present:\n"
    " - Keys with `use=enc` are rejected\n"
    " - Keys with `key_ops` that don't include `sign` are rejected\n"
).
-spec sign(jws(unsigned(), built()), gose:key(binary()), bitstring()) -> {ok,
        jws(signed(), built())} |
    {error, gose:gose_error()}.
sign(Jws, Key, Payload) ->
    {Header@1, Detached@1, Unencoded_payload@1, Unprotected@1} = case Jws of
        {unsigned_jws, Header, _, Detached, Unencoded_payload, Unprotected} -> {
        Header,
            Detached,
            Unencoded_payload,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"sign"/utf8>>,
                        line => 512,
                        value => _assert_fail,
                        start => 16740,
                        'end' => 16851,
                        pattern_start => 16751,
                        pattern_end => 16845})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_signing_key_type(
            erlang:element(2, Header@1),
            Key
        ),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@key_helpers:validate_key_use(Key, for_signing),
                fun(_) ->
                    gleam@result:'try'(
                        gose@internal@key_helpers:validate_key_ops(
                            Key,
                            for_signing
                        ),
                        fun(_) ->
                            gleam@result:'try'(
                                gose@internal@key_helpers:validate_key_algorithm_signing(
                                    Key,
                                    erlang:element(2, Header@1)
                                ),
                                fun(_) ->
                                    Protected_json = header_to_json(
                                        Header@1,
                                        Unencoded_payload@1
                                    ),
                                    Protected_b64 = gose@internal@utils:encode_base64_url(
                                        Protected_json
                                    ),
                                    gleam@result:'try'(
                                        begin
                                            _pipe = encode_payload_segment(
                                                Payload,
                                                Unencoded_payload@1
                                            ),
                                            gleam@result:replace_error(
                                                _pipe,
                                                {invalid_state,
                                                    <<"unencoded payload must be valid UTF-8"/utf8>>}
                                            )
                                        end,
                                        fun(Payload_segment) ->
                                            Signing_input = <<<<Protected_b64/binary,
                                                    "."/utf8>>/binary,
                                                Payload_segment/binary>>,
                                            gleam@result:'try'(
                                                gose@internal@signing:compute_signature(
                                                    erlang:element(2, Header@1),
                                                    Key,
                                                    gleam_stdlib:identity(
                                                        Signing_input
                                                    )
                                                ),
                                                fun(Signature) ->
                                                    {ok,
                                                        {signed_jws,
                                                            Header@1,
                                                            none,
                                                            Payload,
                                                            Detached@1,
                                                            Unencoded_payload@1,
                                                            Protected_b64,
                                                            Payload_segment,
                                                            Signature,
                                                            Unprotected@1,
                                                            none}}
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

-file("src/gose/jose/jws.gleam", 836).
?DOC(
    " Serialize a signed JWS to compact format.\n"
    "\n"
    " Format: `{base64url(header)}.{base64url(payload)}.{base64url(signature)}`\n"
    "\n"
    " For detached payloads: `{base64url(header)}..{base64url(signature)}`\n"
    "\n"
    " For unencoded payloads (b64=false): `{base64url(header)}.{payload}.{base64url(signature)}`\n"
    "\n"
    " Returns an error if the payload contains `.` characters when using b64=false,\n"
    " as this would create an invalid compact serialization (RFC 7797).\n"
    " Use JSON serialization instead for payloads containing periods.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(token) = jws.serialize_compact(signed)\n"
    " ```\n"
).
-spec serialize_compact(jws(signed(), built())) -> {ok, binary()} |
    {error, gose:gose_error()}.
serialize_compact(Jws) ->
    {
    Detached@1,
        Unencoded_payload@1,
        Protected_b64@1,
        Payload_segment@1,
        Signature@1,
        Unprotected@1} = case Jws of
        {signed_jws,
            _,
            _,
            _,
            Detached,
            Unencoded_payload,
            Protected_b64,
            Payload_segment,
            Signature,
            Unprotected,
            _} -> {
        Detached,
            Unencoded_payload,
            Protected_b64,
            Payload_segment,
            Signature,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"serialize_compact"/utf8>>,
                        line => 839,
                        value => _assert_fail,
                        start => 25450,
                        'end' => 25604,
                        pattern_start => 25461,
                        pattern_end => 25598})
    end,
    gleam@bool:guard(
        not gleam@dict:is_empty(Unprotected@1),
        {error,
            {invalid_state,
                <<"cannot serialize to compact format: unprotected headers are only supported in JSON serialization"/utf8>>}},
        fun() ->
            gleam@bool:guard(
                (Unencoded_payload@1 andalso not Detached@1) andalso gleam_stdlib:contains_string(
                    Payload_segment@1,
                    <<"."/utf8>>
                ),
                {error,
                    {invalid_state,
                        <<"unencoded payload cannot contain '.' for compact serialization"/utf8>>}},
                fun() ->
                    Sig_b64 = gose@internal@utils:encode_base64_url(Signature@1),
                    case Detached@1 of
                        true ->
                            {ok,
                                <<<<Protected_b64@1/binary, ".."/utf8>>/binary,
                                    Sig_b64/binary>>};

                        false ->
                            {ok,
                                <<<<<<<<Protected_b64@1/binary, "."/utf8>>/binary,
                                            Payload_segment@1/binary>>/binary,
                                        "."/utf8>>/binary,
                                    Sig_b64/binary>>}
                    end
                end
            )
        end
    ).

-file("src/gose/jose/jws.gleam", 889).
?DOC(
    " Serialize a signed JWS to JSON Flattened format.\n"
    "\n"
    " Format: `{\"payload\":\"...\",\"protected\":\"...\",\"signature\":\"...\"}`\n"
    "\n"
    " For detached payloads, the payload field is omitted.\n"
    " If unprotected headers are present, includes the `header` field.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(signed) =\n"
    "   jws.new(gose.Mac(gose.Hmac(gose.HmacSha256)))\n"
    "   |> jws.sign(key, payload)\n"
    " let json_str =\n"
    "   jws.serialize_json_flattened(signed)\n"
    "   |> json.to_string\n"
    " ```\n"
).
-spec serialize_json_flattened(jws(signed(), built())) -> gleam@json:json().
serialize_json_flattened(Jws) ->
    {
    Detached@1,
        Protected_b64@1,
        Payload_segment@1,
        Signature@1,
        Unprotected@1} = case Jws of
        {signed_jws,
            _,
            _,
            _,
            Detached,
            _,
            Protected_b64,
            Payload_segment,
            Signature,
            Unprotected,
            _} -> {
        Detached,
            Protected_b64,
            Payload_segment,
            Signature,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"serialize_json_flattened"/utf8>>,
                        line => 890,
                        value => _assert_fail,
                        start => 26831,
                        'end' => 26961,
                        pattern_start => 26842,
                        pattern_end => 26955})
    end,
    Sig_b64 = gose@internal@utils:encode_base64_url(Signature@1),
    Base_fields = case Detached@1 of
        true ->
            [{<<"protected"/utf8>>, gleam@json:string(Protected_b64@1)},
                {<<"signature"/utf8>>, gleam@json:string(Sig_b64)}];

        false ->
            [{<<"payload"/utf8>>, gleam@json:string(Payload_segment@1)},
                {<<"protected"/utf8>>, gleam@json:string(Protected_b64@1)},
                {<<"signature"/utf8>>, gleam@json:string(Sig_b64)}]
    end,
    Fields = case gleam@dict:is_empty(Unprotected@1) of
        true ->
            Base_fields;

        false ->
            Header_obj = gleam@json:object(maps:to_list(Unprotected@1)),
            [{<<"header"/utf8>>, Header_obj} | Base_fields]
    end,
    gleam@json:object(Fields).

-file("src/gose/jose/jws.gleam", 940).
?DOC(
    " Serialize a signed JWS to JSON General format.\n"
    "\n"
    " Format: `{\"payload\":\"...\",\"signatures\":[{\"protected\":\"...\",\"signature\":\"...\"}]}`\n"
    "\n"
    " For detached payloads, the payload field is omitted.\n"
    " If unprotected headers are present, includes the `header` field in the signature entry.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(signed) =\n"
    "   jws.new(gose.Mac(gose.Hmac(gose.HmacSha256)))\n"
    "   |> jws.sign(key, payload)\n"
    " let json_str =\n"
    "   jws.serialize_json_general(signed)\n"
    "   |> json.to_string\n"
    " ```\n"
).
-spec serialize_json_general(jws(signed(), built())) -> gleam@json:json().
serialize_json_general(Jws) ->
    {
    Detached@1,
        Protected_b64@1,
        Payload_segment@1,
        Signature@1,
        Unprotected@1} = case Jws of
        {signed_jws,
            _,
            _,
            _,
            Detached,
            _,
            Protected_b64,
            Payload_segment,
            Signature,
            Unprotected,
            _} -> {
        Detached,
            Protected_b64,
            Payload_segment,
            Signature,
            Unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jws"/utf8>>,
                        function => <<"serialize_json_general"/utf8>>,
                        line => 941,
                        value => _assert_fail,
                        start => 28172,
                        'end' => 28302,
                        pattern_start => 28183,
                        pattern_end => 28296})
    end,
    Sig_b64 = gose@internal@utils:encode_base64_url(Signature@1),
    Sig_base_fields = [{<<"protected"/utf8>>,
            gleam@json:string(Protected_b64@1)},
        {<<"signature"/utf8>>, gleam@json:string(Sig_b64)}],
    Sig_fields = case gleam@dict:is_empty(Unprotected@1) of
        true ->
            Sig_base_fields;

        false ->
            Header_obj = gleam@json:object(maps:to_list(Unprotected@1)),
            [{<<"header"/utf8>>, Header_obj} | Sig_base_fields]
    end,
    Sig_obj = gleam@json:object(Sig_fields),
    Fields = case Detached@1 of
        true ->
            [{<<"signatures"/utf8>>, gleam@json:preprocessed_array([Sig_obj])}];

        false ->
            [{<<"payload"/utf8>>, gleam@json:string(Payload_segment@1)},
                {<<"signatures"/utf8>>,
                    gleam@json:preprocessed_array([Sig_obj])}]
    end,
    gleam@json:object(Fields).

-file("src/gose/jose/jws.gleam", 1020).
-spec is_general_json_format(binary()) -> boolean().
is_general_json_format(Json_str) ->
    Detector = begin
        gleam@dynamic@decode:field(
            <<"signatures"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_dynamic/1},
            fun(_) -> gleam@dynamic@decode:success(true) end
        )
    end,
    _pipe = gleam@json:parse(Json_str, Detector),
    gleam@result:is_ok(_pipe).

-file("src/gose/jose/jws.gleam", 1105).
-spec build_signed_jws_json(
    jws_header(),
    gleam@option:option(gleam@dynamic:dynamic_()),
    binary(),
    bitstring(),
    gleam@option:option(binary()),
    boolean(),
    gleam@dict:dict(binary(), gleam@json:json()),
    gleam@option:option(gleam@dynamic:dynamic_())
) -> {ok, jws(signed(), parsed())} | {error, gose:gose_error()}.
build_signed_jws_json(
    Header,
    Header_raw,
    Protected_b64,
    Signature,
    Payload_opt,
    Unencoded_payload,
    Unprotected,
    Unprotected_raw
) ->
    {Payload_b64, Detached} = case Payload_opt of
        {some, P} ->
            {P, false};

        none ->
            {<<""/utf8>>, true}
    end,
    gleam@result:'try'(
        decode_payload_segment(Payload_b64, Unencoded_payload),
        fun(Payload) ->
            {ok,
                {signed_jws,
                    Header,
                    Header_raw,
                    Payload,
                    Detached,
                    Unencoded_payload,
                    Protected_b64,
                    Payload_b64,
                    Signature,
                    Unprotected,
                    Unprotected_raw}}
        end
    ).

-file("src/gose/jose/jws.gleam", 1278).
-spec signature_decoder() -> gleam@dynamic@decode:decoder({binary(),
    binary(),
    gleam@option:option(gleam@dynamic:dynamic_())}).
signature_decoder() ->
    gleam@dynamic@decode:field(
        <<"protected"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(Protected) ->
            gleam@dynamic@decode:field(
                <<"signature"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(Signature) ->
                    gleam@dynamic@decode:optional_field(
                        <<"header"/utf8>>,
                        none,
                        gleam@dynamic@decode:optional(
                            {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
                        ),
                        fun(Header_raw) ->
                            gleam@dynamic@decode:success(
                                {Protected, Signature, Header_raw}
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jws.gleam", 1325).
?DOC(" Validate that unprotected header names don't overlap with protected header names.\n").
-spec validate_header_disjointness(
    jws_header(),
    gleam@set:set(binary()),
    list(binary())
) -> {ok, nil} | {error, gose:gose_error()}.
validate_header_disjointness(
    Protected,
    Protected_custom_keys,
    Unprotected_names
) ->
    Optional_headers = gleam@option:values(
        [gleam@option:map(
                erlang:element(3, Protected),
                fun(_) -> <<"kid"/utf8>> end
            ),
            gleam@option:map(
                erlang:element(4, Protected),
                fun(_) -> <<"typ"/utf8>> end
            ),
            gleam@option:map(
                erlang:element(5, Protected),
                fun(_) -> <<"cty"/utf8>> end
            )]
    ),
    Protected_set = begin
        _pipe = gleam@set:from_list([<<"alg"/utf8>> | Optional_headers]),
        gleam@set:union(_pipe, Protected_custom_keys)
    end,
    Unprotected_set = gleam@set:from_list(Unprotected_names),
    Overlap = gleam@set:intersection(Protected_set, Unprotected_set),
    case gleam@set:is_empty(Overlap) of
        true ->
            {ok, nil};

        false ->
            {error,
                {parse_error,
                    <<"header names must be disjoint, overlap: "/utf8,
                        (gleam@string:join(
                            gleam@set:to_list(Overlap),
                            <<", "/utf8>>
                        ))/binary>>}}
    end.

-file("src/gose/jose/jws.gleam", 354).
?DOC(
    " Add an unprotected header field (for JSON serialization only).\n"
    "\n"
    " **Security Warning:** Unprotected headers are NOT integrity protected.\n"
    " They can be modified by an attacker without invalidating the signature.\n"
    " Only use for non-security-critical metadata.\n"
    "\n"
    " Returns an error if the name is a protected-only header (`crit`, `b64`) which\n"
    " MUST be integrity protected per RFC 7515/7797.\n"
    "\n"
    " Compact serialization will return an error if unprotected headers are present.\n"
    "\n"
    " If the same header name is set multiple times, the last value wins.\n"
).
-spec with_unprotected(jws(unsigned(), built()), binary(), gleam@json:json()) -> {ok,
        jws(unsigned(), built())} |
    {error, gose:gose_error()}.
with_unprotected(Jws, Name, Value) ->
    gleam@bool:guard(
        gleam@list:contains([<<"crit"/utf8>>, <<"b64"/utf8>>], Name),
        {error,
            {invalid_state,
                <<"protected-only header cannot be in unprotected: "/utf8,
                    Name/binary>>}},
        fun() ->
            {
            Header@1,
                Payload@1,
                Detached@1,
                Unencoded_payload@1,
                Unprotected@1} = case Jws of
                {unsigned_jws,
                    Header,
                    Payload,
                    Detached,
                    Unencoded_payload,
                    Unprotected} -> {
                Header,
                    Payload,
                    Detached,
                    Unencoded_payload,
                    Unprotected};
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jws"/utf8>>,
                                function => <<"with_unprotected"/utf8>>,
                                line => 365,
                                value => _assert_fail,
                                start => 12202,
                                'end' => 12319,
                                pattern_start => 12213,
                                pattern_end => 12313})
            end,
            {ok,
                {unsigned_jws,
                    Header@1,
                    Payload@1,
                    Detached@1,
                    Unencoded_payload@1,
                    gleam@dict:insert(Unprotected@1, Name, Value)}}
        end
    ).

-file("src/gose/jose/jws.gleam", 1352).
?DOC(" Validate that no protected-only headers appear in unprotected.\n").
-spec validate_no_protected_only_headers(list(binary())) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_no_protected_only_headers(Names) ->
    Violations = gleam@list:filter(
        Names,
        fun(_capture) ->
            gleam@list:contains([<<"crit"/utf8>>, <<"b64"/utf8>>], _capture)
        end
    ),
    case gleam@list:is_empty(Violations) of
        true ->
            {ok, nil};

        false ->
            {error,
                {parse_error,
                    <<"protected-only headers in unprotected: "/utf8,
                        (gleam@string:join(Violations, <<", "/utf8>>))/binary>>}}
    end.

-file("src/gose/jose/jws.gleam", 1249).
?DOC(" Parse and validate unprotected headers, checking for disjointness with protected.\n").
-spec parse_unprotected_header(
    gleam@option:option(gleam@dynamic:dynamic_()),
    jws_header(),
    gleam@set:set(binary())
) -> {ok,
        {gleam@dict:dict(binary(), gleam@json:json()),
            gleam@option:option(gleam@dynamic:dynamic_())}} |
    {error, gose:gose_error()}.
parse_unprotected_header(Header_raw, Protected, Protected_custom_keys) ->
    case Header_raw of
        none ->
            {ok, {maps:new(), none}};

        {some, Raw} ->
            gleam@result:'try'(
                begin
                    _pipe = gleam@dynamic@decode:run(
                        Raw,
                        gleam@dynamic@decode:dict(
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
                        )
                    ),
                    gleam@result:replace_error(
                        _pipe,
                        {parse_error,
                            <<"unprotected header must be an object"/utf8>>}
                    )
                end,
                fun(Unprotected_dict) ->
                    Unprotected_names = maps:keys(Unprotected_dict),
                    gleam@result:'try'(
                        validate_no_protected_only_headers(Unprotected_names),
                        fun(_) ->
                            gleam@result:'try'(
                                validate_header_disjointness(
                                    Protected,
                                    Protected_custom_keys,
                                    Unprotected_names
                                ),
                                fun(_) -> {ok, {maps:new(), {some, Raw}}} end
                            )
                        end
                    )
                end
            )
    end.

-file("src/gose/jose/jws.gleam", 298).
?DOC(
    " Add a custom protected header field.\n"
    "\n"
    " Custom headers are sorted alphabetically by name and appear after standard fields (alg, kid, typ, cty).\n"
    " Returns an error if the name is a reserved header (`alg`, `kid`, `typ`, `cty`,\n"
    " `crit`, `b64`) to prevent security issues like algorithm confusion.\n"
    "\n"
    " If the same header name is set multiple times, the last value wins.\n"
).
-spec with_header(jws(unsigned(), built()), binary(), gleam@json:json()) -> {ok,
        jws(unsigned(), built())} |
    {error, gose:gose_error()}.
with_header(Jws, Name, Value) ->
    gleam@bool:guard(
        gleam@list:contains(
            [<<"alg"/utf8>>,
                <<"kid"/utf8>>,
                <<"typ"/utf8>>,
                <<"cty"/utf8>>,
                <<"crit"/utf8>>,
                <<"b64"/utf8>>],
            Name
        ),
        {error,
            {invalid_state,
                <<"cannot set reserved header via with_header: "/utf8,
                    Name/binary>>}},
        fun() ->
            {ok,
                map_unsigned_header(
                    Jws,
                    fun(H) ->
                        {jws_header,
                            erlang:element(2, H),
                            erlang:element(3, H),
                            erlang:element(4, H),
                            erlang:element(5, H),
                            gleam@dict:insert(erlang:element(6, H), Name, Value)}
                    end
                )}
        end
    ).

-file("src/gose/jose/jws.gleam", 1306).
-spec validate_crit(list(binary()), gleam@option:option(boolean())) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_crit(Crit, B64) ->
    gleam@result:'try'(
        gose@internal@utils:validate_crit_headers(
            Crit,
            [<<"alg"/utf8>>,
                <<"jku"/utf8>>,
                <<"jwk"/utf8>>,
                <<"kid"/utf8>>,
                <<"x5u"/utf8>>,
                <<"x5c"/utf8>>,
                <<"x5t"/utf8>>,
                <<"x5t#S256"/utf8>>,
                <<"typ"/utf8>>,
                <<"cty"/utf8>>,
                <<"crit"/utf8>>],
            [<<"b64"/utf8>>]
        ),
        fun(_) ->
            Crit_set = gleam@set:from_list(Crit),
            case gleam@set:contains(Crit_set, <<"b64"/utf8>>) andalso gleam@option:is_none(
                B64
            ) of
                true ->
                    {error,
                        {parse_error,
                            <<"b64 listed in crit but not present in header"/utf8>>}};

                false ->
                    {ok, nil}
            end
        end
    ).

-file("src/gose/jose/jws.gleam", 662).
-spec validate_optional_crit(
    gleam@option:option(list(binary())),
    gleam@option:option(boolean())
) -> {ok, nil} | {error, gose:gose_error()}.
validate_optional_crit(Crit, B64) ->
    case Crit of
        {some, Crit_list} ->
            validate_crit(Crit_list, B64);

        none ->
            {ok, nil}
    end.

-file("src/gose/jose/jws.gleam", 1031).
-spec parse_header_json(bitstring()) -> {ok, parsed_header()} |
    {error, gose:gose_error()}.
parse_header_json(Json_bits) ->
    Standard_decoder = begin
        gleam@dynamic@decode:field(
            <<"alg"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Alg) ->
                gleam@dynamic@decode:optional_field(
                    <<"kid"/utf8>>,
                    none,
                    gleam@dynamic@decode:optional(
                        {decoder, fun gleam@dynamic@decode:decode_string/1}
                    ),
                    fun(Kid) ->
                        gleam@dynamic@decode:optional_field(
                            <<"typ"/utf8>>,
                            none,
                            gleam@dynamic@decode:optional(
                                {decoder,
                                    fun gleam@dynamic@decode:decode_string/1}
                            ),
                            fun(Typ) ->
                                gleam@dynamic@decode:optional_field(
                                    <<"cty"/utf8>>,
                                    none,
                                    gleam@dynamic@decode:optional(
                                        {decoder,
                                            fun gleam@dynamic@decode:decode_string/1}
                                    ),
                                    fun(Cty) ->
                                        gleam@dynamic@decode:optional_field(
                                            <<"crit"/utf8>>,
                                            none,
                                            gleam@dynamic@decode:optional(
                                                gleam@dynamic@decode:list(
                                                    {decoder,
                                                        fun gleam@dynamic@decode:decode_string/1}
                                                )
                                            ),
                                            fun(Crit) ->
                                                gleam@dynamic@decode:optional_field(
                                                    <<"b64"/utf8>>,
                                                    none,
                                                    gleam@dynamic@decode:optional(
                                                        {decoder,
                                                            fun gleam@dynamic@decode:decode_bool/1}
                                                    ),
                                                    fun(B64) ->
                                                        gleam@dynamic@decode:success(
                                                            {Alg,
                                                                Kid,
                                                                Typ,
                                                                Cty,
                                                                Crit,
                                                                B64}
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
            _pipe = gleam@json:parse_bits(
                Json_bits,
                {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
            ),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"invalid header JSON"/utf8>>}
            )
        end,
        fun(Raw_dynamic) ->
            gleam@result:'try'(
                begin
                    _pipe@1 = gleam@dynamic@decode:run(
                        Raw_dynamic,
                        Standard_decoder
                    ),
                    gleam@result:replace_error(
                        _pipe@1,
                        {parse_error, <<"invalid header JSON"/utf8>>}
                    )
                end,
                fun(_use0) ->
                    {Alg_str, Kid@1, Typ@1, Cty@1, Crit@1, B64@1} = _use0,
                    gleam@result:'try'(
                        validate_optional_crit(Crit@1, B64@1),
                        fun(_) ->
                            B64_in_crit = begin
                                _pipe@2 = gleam@option:map(
                                    Crit@1,
                                    fun(_capture) ->
                                        gleam@list:contains(
                                            _capture,
                                            <<"b64"/utf8>>
                                        )
                                    end
                                ),
                                gleam@option:unwrap(_pipe@2, false)
                            end,
                            gleam@bool:guard(
                                gleam@option:is_some(B64@1) andalso not B64_in_crit,
                                {error,
                                    {parse_error,
                                        <<"b64 header present but not in crit"/utf8>>}},
                                fun() ->
                                    gleam@result:'try'(
                                        gose@jose:signing_alg_from_string(
                                            Alg_str
                                        ),
                                        fun(Alg@1) ->
                                            Unencoded_payload = B64@1 =:= {some,
                                                false},
                                            gleam@result:'try'(
                                                begin
                                                    _pipe@3 = gleam@dynamic@decode:run(
                                                        Raw_dynamic,
                                                        gleam@dynamic@decode:dict(
                                                            {decoder,
                                                                fun gleam@dynamic@decode:decode_string/1},
                                                            {decoder,
                                                                fun gleam@dynamic@decode:decode_dynamic/1}
                                                        )
                                                    ),
                                                    gleam@result:replace_error(
                                                        _pipe@3,
                                                        {parse_error,
                                                            <<"invalid header JSON"/utf8>>}
                                                    )
                                                end,
                                                fun(All_keys) ->
                                                    Custom_keys = begin
                                                        _pipe@4 = maps:keys(
                                                            All_keys
                                                        ),
                                                        _pipe@5 = gleam@list:filter(
                                                            _pipe@4,
                                                            fun(K) ->
                                                                not gleam@list:contains(
                                                                    [<<"alg"/utf8>>,
                                                                        <<"kid"/utf8>>,
                                                                        <<"typ"/utf8>>,
                                                                        <<"cty"/utf8>>,
                                                                        <<"crit"/utf8>>,
                                                                        <<"b64"/utf8>>],
                                                                    K
                                                                )
                                                            end
                                                        ),
                                                        gleam@set:from_list(
                                                            _pipe@5
                                                        )
                                                    end,
                                                    {ok,
                                                        {parsed_header,
                                                            {jws_header,
                                                                Alg@1,
                                                                Kid@1,
                                                                Typ@1,
                                                                Cty@1,
                                                                maps:new()},
                                                            Unencoded_payload,
                                                            {some, Raw_dynamic},
                                                            Custom_keys}}
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

-file("src/gose/jose/jws.gleam", 1243).
-spec parse_protected_header(binary()) -> {ok, parsed_header()} |
    {error, gose:gose_error()}.
parse_protected_header(B64) ->
    gleam@result:'try'(
        gose@internal@utils:decode_base64_url(B64, <<"header"/utf8>>),
        fun(Header_bits) -> parse_header_json(Header_bits) end
    ).

-file("src/gose/jose/jws.gleam", 987).
-spec build_signed_jws(binary(), binary(), binary(), boolean()) -> {ok,
        jws(signed(), parsed())} |
    {error, gose:gose_error()}.
build_signed_jws(Protected_b64, Payload_segment, Sig_b64, Detached) ->
    gleam@result:'try'(
        parse_protected_header(Protected_b64),
        fun(_use0) ->
            {parsed_header, Header, Unencoded_payload, Header_raw, _} = _use0,
            gleam@result:'try'(
                gose@internal@utils:decode_base64_url(
                    Sig_b64,
                    <<"signature"/utf8>>
                ),
                fun(Signature) ->
                    gleam@result:'try'(
                        decode_payload_segment(
                            Payload_segment,
                            Unencoded_payload
                        ),
                        fun(Payload) ->
                            {ok,
                                {signed_jws,
                                    Header,
                                    Header_raw,
                                    Payload,
                                    Detached,
                                    Unencoded_payload,
                                    Protected_b64,
                                    Payload_segment,
                                    Signature,
                                    maps:new(),
                                    none}}
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jws.gleam", 806).
?DOC(
    " Parse a JWS from compact format.\n"
    "\n"
    " Returns a signed JWS that can be verified with a `Verifier`.\n"
    " An empty payload segment (`header..signature`) is treated as a detached\n"
    " payload; use `verify_detached` to verify with the out-of-band payload.\n"
).
-spec parse_compact(binary()) -> {ok, jws(signed(), parsed())} |
    {error, gose:gose_error()}.
parse_compact(Token) ->
    case gleam@string:split(Token, <<"."/utf8>>) of
        [Protected_b64, Payload_b64, Sig_b64] ->
            Detached = Payload_b64 =:= <<""/utf8>>,
            build_signed_jws(Protected_b64, Payload_b64, Sig_b64, Detached);

        _ ->
            {error,
                {parse_error,
                    <<"invalid compact serialization: expected 3 parts"/utf8>>}}
    end.

-file("src/gose/jose/jws.gleam", 1137).
-spec parse_json_flattened(binary()) -> {ok, jws(signed(), parsed())} |
    {error, gose:gose_error()}.
parse_json_flattened(Json_str) ->
    Decoder = begin
        gleam@dynamic@decode:field(
            <<"protected"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Protected) ->
                gleam@dynamic@decode:field(
                    <<"signature"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Signature) ->
                        gleam@dynamic@decode:optional_field(
                            <<"payload"/utf8>>,
                            none,
                            gleam@dynamic@decode:optional(
                                {decoder,
                                    fun gleam@dynamic@decode:decode_string/1}
                            ),
                            fun(Payload_opt) ->
                                gleam@dynamic@decode:optional_field(
                                    <<"header"/utf8>>,
                                    none,
                                    gleam@dynamic@decode:optional(
                                        {decoder,
                                            fun gleam@dynamic@decode:decode_dynamic/1}
                                    ),
                                    fun(Unprotected_header_raw) ->
                                        gleam@dynamic@decode:success(
                                            {Protected,
                                                Signature,
                                                Payload_opt,
                                                Unprotected_header_raw}
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
                {parse_error, <<"invalid JWS JSON (flattened)"/utf8>>}
            )
        end,
        fun(_use0) ->
            {Protected_b64, Sig_b64, Payload_opt@1, Unprotected_header_raw@1} = _use0,
            gleam@result:'try'(
                parse_protected_header(Protected_b64),
                fun(_use0@1) ->
                    {parsed_header,
                        Header,
                        Unencoded_payload,
                        Header_raw,
                        Custom_keys} = _use0@1,
                    gleam@result:'try'(
                        parse_unprotected_header(
                            Unprotected_header_raw@1,
                            Header,
                            Custom_keys
                        ),
                        fun(_use0@2) ->
                            {Unprotected, Unprotected_raw} = _use0@2,
                            gleam@result:'try'(
                                gose@internal@utils:decode_base64_url(
                                    Sig_b64,
                                    <<"signature"/utf8>>
                                ),
                                fun(Signature@1) ->
                                    build_signed_jws_json(
                                        Header,
                                        Header_raw,
                                        Protected_b64,
                                        Signature@1,
                                        Payload_opt@1,
                                        Unencoded_payload,
                                        Unprotected,
                                        Unprotected_raw
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jws.gleam", 1190).
?DOC(
    " Parse a JWS from JSON General format.\n"
    "\n"
    " **Note:** Only single signatures are supported here. For multiple\n"
    " signatures per payload, use `gose/jose/jws_multi`.\n"
).
-spec parse_json_general(binary()) -> {ok, jws(signed(), parsed())} |
    {error, gose:gose_error()}.
parse_json_general(Json_str) ->
    Decoder = begin
        gleam@dynamic@decode:field(
            <<"signatures"/utf8>>,
            gleam@dynamic@decode:list(signature_decoder()),
            fun(Signatures) ->
                gleam@dynamic@decode:optional_field(
                    <<"payload"/utf8>>,
                    none,
                    gleam@dynamic@decode:optional(
                        {decoder, fun gleam@dynamic@decode:decode_string/1}
                    ),
                    fun(Payload_opt) ->
                        gleam@dynamic@decode:success({Signatures, Payload_opt})
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
                {parse_error, <<"invalid JWS JSON (general)"/utf8>>}
            )
        end,
        fun(_use0) ->
            {Signatures@1, Payload_opt@1} = _use0,
            case Signatures@1 of
                [{Protected_b64, Sig_b64, Unprotected_header_raw}] ->
                    gleam@result:'try'(
                        parse_protected_header(Protected_b64),
                        fun(_use0@1) ->
                            {parsed_header,
                                Header,
                                Unencoded_payload,
                                Header_raw,
                                Custom_keys} = _use0@1,
                            gleam@result:'try'(
                                parse_unprotected_header(
                                    Unprotected_header_raw,
                                    Header,
                                    Custom_keys
                                ),
                                fun(_use0@2) ->
                                    {Unprotected, Unprotected_raw} = _use0@2,
                                    gleam@result:'try'(
                                        gose@internal@utils:decode_base64_url(
                                            Sig_b64,
                                            <<"signature"/utf8>>
                                        ),
                                        fun(Signature) ->
                                            build_signed_jws_json(
                                                Header,
                                                Header_raw,
                                                Protected_b64,
                                                Signature,
                                                Payload_opt@1,
                                                Unencoded_payload,
                                                Unprotected,
                                                Unprotected_raw
                                            )
                                        end
                                    )
                                end
                            )
                        end
                    );

                [_, _ | _] ->
                    {error,
                        {parse_error,
                            <<"JWS JSON (general) has multiple signatures (not supported)"/utf8>>}};

                [] ->
                    {error,
                        {parse_error,
                            <<"JWS JSON (general) has no signatures"/utf8>>}}
            end
        end
    ).

-file("src/gose/jose/jws.gleam", 978).
?DOC(" Parse a JWS from JSON format (supports both General and Flattened).\n").
-spec parse_json(binary()) -> {ok, jws(signed(), parsed())} |
    {error, gose:gose_error()}.
parse_json(Json_str) ->
    case is_general_json_format(Json_str) of
        true ->
            parse_json_general(Json_str);

        false ->
            parse_json_flattened(Json_str)
    end.
