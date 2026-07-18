-module(gose@jose@jwe).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/jwe.gleam").
-export([key_decryptor/3, new_aes_gcm_kw/2, new_aes_kw/2, new_chacha20_kw/2, new_direct/1, new_ecdh_es/2, new_pbes2/2, new_rsa/2, password_decryptor/3, with_aad/2, with_apu/2, with_apv/2, with_cty/2, with_kid/2, with_typ/2, aad/1, alg/1, cty/1, decode_shared_unprotected_header/2, decode_unprotected_header/2, enc/1, has_shared_unprotected_header/1, has_unprotected_header/1, kid/1, typ/1, decrypt/2, encrypt_with_password/3, encrypt/3, serialize_compact/1, serialize_json_flattened/1, serialize_json_general/1, encrypt_to_compact/7, with_p2c/2, parse_compact/1, with_shared_unprotected/3, with_unprotected/3, parse_json/1]).
-export_type([unencrypted/0, encrypted/0, built/0, parsed/0, direct/0, aes_kw/0, rsa/0, ecdh_es/0, pbes2/0, aes_gcm_kw/0, cha_cha20_kw/0, jwe_header/0, builder_alg_fields/0, resolved_alg_fields/0, parsed_header/0, jwe/3, decryptor/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " JSON Web Encryption (JWE) - [RFC 7516](https://www.rfc-editor.org/rfc/rfc7516.html)\n"
    "\n"
    " Encryption using algorithms from\n"
    " [RFC 7518](https://www.rfc-editor.org/rfc/rfc7518.html):\n"
    " key encryption (RSA-OAEP, ECDH-ES, AES Key Wrap, AES-GCM Key Wrap, PBES2, dir)\n"
    " and content encryption (AES-GCM, AES-CBC-HMAC).\n"
    "\n"
    " Non-standard extensions are also supported: ChaCha20 Key Wrap (C20PKW,\n"
    " XC20PKW), ECDH-ES+ChaCha20KW, and ChaCha20-Poly1305/XChaCha20-Poly1305\n"
    " content encryption.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/jose/jwe\n"
    "\n"
    " let key = gose.generate_enc_key(gose.AesGcm(gose.Aes256))\n"
    " let plaintext = <<\"hello world\":utf8>>\n"
    "\n"
    " // Create and encrypt a JWE using direct encryption\n"
    " let assert Ok(encrypted) = jwe.new_direct(gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.encrypt(key, plaintext)\n"
    "\n"
    " // Serialize to compact format\n"
    " let assert Ok(token) = jwe.serialize_compact(encrypted)\n"
    "\n"
    " // Parse and decrypt with algorithm pinning\n"
    " let assert Ok(parsed) = jwe.parse_compact(token)\n"
    " let assert Ok(decryptor) =\n"
    "   jwe.key_decryptor(gose.Direct, gose.AesGcm(gose.Aes256), keys: [key])\n"
    " let assert Ok(decrypted) = jwe.decrypt(decryptor, parsed)\n"
    " ```\n"
    "\n"
    " ## Phantom Types\n"
    "\n"
    " `Jwe(state, family, origin)` carries three phantom parameters. The\n"
    " state is `Unencrypted` before `encrypt` and `Encrypted` after, gating\n"
    " serialization and decryption on a completed encryption. The family\n"
    " is one of `Direct`, `AesKw`, `AesGcmKw`, `Rsa`, `EcdhEs`, or `Pbes2`;\n"
    " it restricts algorithm-specific builders so `with_apu`/`with_apv`\n"
    " only compile on `EcdhEs` JWEs and `with_p2c` only compiles on `Pbes2`\n"
    " JWEs. The origin is `Built` for values produced by a `new_*` builder\n"
    " and `encrypt`, and `Parsed` for values from `parse_compact` or\n"
    " `parse_json`.\n"
    "\n"
    " ## Algorithm Pinning\n"
    "\n"
    " Algorithm pinning prevents algorithm confusion attacks:\n"
    "\n"
    " 1. **JWK `alg` metadata**: If a key has `alg` set via `gose.with_alg`,\n"
    "    the JWE algorithm must match during encryption and decryption.\n"
    " 2. **Decryptor API**: `jwe.decrypt()` with a `Decryptor` pins both key\n"
    "    encryption and content encryption algorithms; mismatches are rejected.\n"
    " 3. **Key type validation**: The key type must match the algorithm (RSA for\n"
    "    RSA-OAEP, EC for ECDH-ES, etc.).\n"
    "\n"
    " For strongest security, always set the `alg` field on keys or use decryptors.\n"
    "\n"
    " ## Unprotected Headers\n"
    "\n"
    " JWE supports unprotected headers at two levels in JSON serialization.\n"
    " The `unprotected` field carries shared headers that apply to all\n"
    " recipients, and each recipient's `header` field carries headers\n"
    " specific to that recipient.\n"
    "\n"
    " **Security Warning:** Unprotected headers are NOT integrity protected. They can be\n"
    " modified by an attacker without detection. Security-critical parameters\n"
    " (`alg`, `enc`, `crit`, `zip`) are rejected and must be integrity protected.\n"
    "\n"
    " Use `with_shared_unprotected` and `with_unprotected` to add headers during\n"
    " creation. Use `decode_shared_unprotected_header` and `decode_unprotected_header`\n"
    " to read parsed headers.\n"
    "\n"
    " ## Critical Header Support\n"
    "\n"
    " The `crit` header is validated per RFC 7516:\n"
    " - Empty arrays are rejected\n"
    " - Standard headers cannot appear in `crit`\n"
    " - No extensions are currently implemented, so any critical extension is rejected\n"
    "\n"
    " ## Key Metadata\n"
    "\n"
    " JWK metadata (`use`, `key_ops`) is enforced during encryption and decryption.\n"
    " Keys with incompatible metadata are rejected.\n"
    "\n"
    " ## Compression Not Supported\n"
    "\n"
    " The `zip` header (DEFLATE compression) is intentionally not supported.\n"
    " Compression before encryption leaks information about plaintext through\n"
    " ciphertext size variations (CRIME/BREACH-style attacks). JWEs with `zip`\n"
    " set are rejected during parsing.\n"
    "\n"
    " ## JSON Serialization Limitations\n"
    "\n"
    " `parse_json` accepts only a single recipient. For multi-recipient\n"
    " messages, use `gose/jose/jwe_multi`.\n"
).

-type unencrypted() :: any().

-type encrypted() :: any().

-type built() :: any().

-type parsed() :: any().

-type direct() :: any().

-type aes_kw() :: any().

-type rsa() :: any().

-type ecdh_es() :: any().

-type pbes2() :: any().

-type aes_gcm_kw() :: any().

-type cha_cha20_kw() :: any().

-type jwe_header() :: {jwe_header,
        gose:key_encryption_alg(),
        gose:content_alg(),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        gleam@option:option(binary())}.

-type builder_alg_fields() :: no_builder_alg_fields |
    {ecdh_es_builder_fields,
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring())} |
    {pbes2_builder_fields, gleam@option:option(integer())} |
    aes_gcm_kw_builder_fields |
    cha_cha20_kw_builder_fields.

-type resolved_alg_fields() :: no_resolved_alg_fields |
    {ecdh_es_resolved_fields,
        gleam@option:option(gose@internal@key_encryption:ephemeral_public_key()),
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring())} |
    {pbes2_resolved_fields, bitstring(), integer()} |
    {aes_gcm_kw_resolved_fields,
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring())} |
    {cha_cha20_kw_resolved_fields,
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring())} |
    {ecdh_es_cha_cha20_kw_resolved_fields,
        gleam@option:option(gose@internal@key_encryption:ephemeral_public_key()),
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring()),
        gleam@option:option(bitstring())}.

-type parsed_header() :: {parsed_header, jwe_header(), resolved_alg_fields()}.

-opaque jwe(SOI, SOJ, SOK) :: {jwe,
        jwe_header(),
        gleam@option:option(bitstring()),
        gleam@dict:dict(binary(), gleam@json:json()),
        gleam@dict:dict(binary(), gleam@json:json()),
        builder_alg_fields()} |
    {encrypted_jwe,
        jwe_header(),
        binary(),
        bitstring(),
        bitstring(),
        bitstring(),
        bitstring(),
        resolved_alg_fields(),
        gleam@option:option(bitstring()),
        gleam@dict:dict(binary(), gleam@json:json()),
        gleam@option:option(gleam@dynamic:dynamic_()),
        gleam@dict:dict(binary(), gleam@json:json()),
        gleam@option:option(gleam@dynamic:dynamic_())} |
    {gleam_phantom, SOI, SOJ, SOK}.

-opaque decryptor() :: {key_decryptor,
        gose:key_encryption_alg(),
        gose:content_alg(),
        list(gose:key(binary()))} |
    {password_decryptor, gose:pbes2_alg(), gose:content_alg(), binary()}.

-file("src/gose/jose/jwe.gleam", 267).
?DOC(
    " Create a key-based decryptor for symmetric (dir, AES-KW, AES-GCM-KW) or\n"
    " asymmetric (RSA-OAEP, ECDH-ES) algorithms with multiple keys.\n"
    "\n"
    " The decryptor pins the expected algorithm and encryption method.\n"
    " Tokens with different algorithms will be rejected.\n"
    "\n"
    " When decrypting, keys are tried in order. If the JWE has a `kid` header,\n"
    " a key with matching `kid` is prioritized.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(decryptor) = jwe.key_decryptor(gose.Direct, gose.AesGcm(gose.Aes256), [key])\n"
    " let assert Ok(plaintext) = jwe.decrypt(decryptor, encrypted_jwe)\n"
    " ```\n"
).
-spec key_decryptor(
    gose:key_encryption_alg(),
    gose:content_alg(),
    list(gose:key(binary()))
) -> {ok, decryptor()} | {error, gose:gose_error()}.
key_decryptor(Alg, Enc, Keys) ->
    gose@internal@key_helpers:require_non_empty_keys(
        Keys,
        fun() ->
            gleam@result:'try'(
                gleam@list:try_each(
                    Keys,
                    fun(_capture) ->
                        gose@internal@key_helpers:validate_key_for_jwe_decryption(
                            Alg,
                            _capture
                        )
                    end
                ),
                fun(_) -> {ok, {key_decryptor, Alg, Enc, Keys}} end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 288).
?DOC(
    " Create a new unencrypted JWE for AES-GCM Key Wrap encryption. A random CEK\n"
    " is generated and wrapped using AES-GCM with the provided symmetric key.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(encrypted) = jwe.new_aes_gcm_kw(gose.Aes256, gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.encrypt(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec new_aes_gcm_kw(gose:aes_key_size(), gose:content_alg()) -> jwe(unencrypted(), aes_gcm_kw(), built()).
new_aes_gcm_kw(Size, Enc) ->
    {jwe,
        {jwe_header, {aes_key_wrap, aes_gcm_kw, Size}, Enc, none, none, none},
        none,
        maps:new(),
        maps:new(),
        aes_gcm_kw_builder_fields}.

-file("src/gose/jose/jwe.gleam", 316).
?DOC(
    " Create a new unencrypted JWE for AES Key Wrap encryption. A random CEK is\n"
    " generated and wrapped with the provided symmetric key.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(encrypted) = jwe.new_aes_kw(gose.Aes256, gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.encrypt(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec new_aes_kw(gose:aes_key_size(), gose:content_alg()) -> jwe(unencrypted(), aes_kw(), built()).
new_aes_kw(Size, Enc) ->
    {jwe,
        {jwe_header, {aes_key_wrap, aes_kw, Size}, Enc, none, none, none},
        none,
        maps:new(),
        maps:new(),
        no_builder_alg_fields}.

-file("src/gose/jose/jwe.gleam", 347).
?DOC(
    " Create a new unencrypted JWE for ChaCha20-Poly1305 Key Wrap encryption.\n"
    " A random CEK is generated and wrapped using ChaCha20-Poly1305 or\n"
    " XChaCha20-Poly1305 with the provided 32-byte symmetric key.\n"
    "\n"
    " This is a non-standard extension (not defined in RFC 7518).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(encrypted) = jwe.new_chacha20_kw(gose.XC20PKw, gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.encrypt(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec new_chacha20_kw(gose:cha_cha20_kw(), gose:content_alg()) -> jwe(unencrypted(), cha_cha20_kw(), built()).
new_chacha20_kw(Variant, Enc) ->
    {jwe,
        {jwe_header, {cha_cha20_key_wrap, Variant}, Enc, none, none, none},
        none,
        maps:new(),
        maps:new(),
        cha_cha20_kw_builder_fields}.

-file("src/gose/jose/jwe.gleam", 375).
?DOC(
    " Create a new unencrypted JWE for direct key encryption. The symmetric key\n"
    " is used directly as the Content Encryption Key (CEK).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(encrypted) = jwe.new_direct(gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.encrypt(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec new_direct(gose:content_alg()) -> jwe(unencrypted(), direct(), built()).
new_direct(Enc) ->
    {jwe,
        {jwe_header, direct, Enc, none, none, none},
        none,
        maps:new(),
        maps:new(),
        no_builder_alg_fields}.

-file("src/gose/jose/jwe.gleam", 400).
?DOC(
    " Create a new unencrypted JWE for ECDH-ES key agreement. An ephemeral key\n"
    " pair is generated during encryption for the key agreement.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(encrypted) = jwe.new_ecdh_es(gose.EcdhEsDirect, gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.encrypt(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec new_ecdh_es(gose:ecdh_es_alg(), gose:content_alg()) -> jwe(unencrypted(), ecdh_es(), built()).
new_ecdh_es(Alg, Enc) ->
    Alg_fields = {ecdh_es_builder_fields, none, none},
    {jwe,
        {jwe_header, {ecdh_es, Alg}, Enc, none, none, none},
        none,
        maps:new(),
        maps:new(),
        Alg_fields}.

-file("src/gose/jose/jwe.gleam", 432).
?DOC(
    " Create a new unencrypted JWE for PBES2 password-based encryption. The CEK\n"
    " is derived from the password using PBKDF2.\n"
    "\n"
    " Use `with_p2c` to override the default iteration count. The salt\n"
    " is generated automatically.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(encrypted) = jwe.new_pbes2(gose.Pbes2Sha256Aes128Kw, gose.AesGcm(gose.Aes128))\n"
    "   |> jwe.encrypt_with_password(\"secret\", <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec new_pbes2(gose:pbes2_alg(), gose:content_alg()) -> jwe(unencrypted(), pbes2(), built()).
new_pbes2(Alg, Enc) ->
    {jwe,
        {jwe_header, {pbes2, Alg}, Enc, none, none, none},
        none,
        maps:new(),
        maps:new(),
        {pbes2_builder_fields, none}}.

-file("src/gose/jose/jwe.gleam", 460).
?DOC(
    " Create a new unencrypted JWE for RSA key encryption. A random CEK is\n"
    " generated and encrypted with the RSA public key.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(encrypted) = jwe.new_rsa(gose.RsaOaepSha256, gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.encrypt(rsa_key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec new_rsa(gose:rsa_encryption_alg(), gose:content_alg()) -> jwe(unencrypted(), rsa(), built()).
new_rsa(Alg, Enc) ->
    {jwe,
        {jwe_header, {rsa_encryption, Alg}, Enc, none, none, none},
        none,
        maps:new(),
        maps:new(),
        no_builder_alg_fields}.

-file("src/gose/jose/jwe.gleam", 494).
?DOC(
    " Create a password-based decryptor for PBES2 algorithms.\n"
    "\n"
    " The decryptor pins the expected algorithm and encryption method.\n"
    " Tokens with different algorithms will be rejected.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let decryptor = jwe.password_decryptor(\n"
    "   gose.Pbes2Sha256Aes128Kw,\n"
    "   gose.AesGcm(gose.Aes128),\n"
    "   \"super-secret\",\n"
    " )\n"
    " let assert Ok(plaintext) = jwe.decrypt(decryptor, encrypted_jwe)\n"
    " ```\n"
).
-spec password_decryptor(gose:pbes2_alg(), gose:content_alg(), binary()) -> decryptor().
password_decryptor(Alg, Enc, Password) ->
    {password_decryptor, Alg, Enc, Password}.

-file("src/gose/jose/jwe.gleam", 506).
?DOC(
    " Set the Additional Authenticated Data (AAD) for JSON serialization.\n"
    "\n"
    " AAD is only supported in JSON serialization (flattened and general formats).\n"
    " Attempting to serialize to compact format with AAD set will return an error.\n"
).
-spec with_aad(jwe(unencrypted(), SPK, built()), bitstring()) -> jwe(unencrypted(), SPK, built()).
with_aad(Jwe, Aad) ->
    case Jwe of
        {jwe, _, _, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"with_aad"/utf8>>,
                        line => 510,
                        value => _assert_fail,
                        start => 15906,
                        'end' => 15930,
                        pattern_start => 15917,
                        pattern_end => 15924})
    end,
    {jwe,
        erlang:element(2, Jwe),
        {some, Aad},
        erlang:element(4, Jwe),
        erlang:element(5, Jwe),
        erlang:element(6, Jwe)}.

-file("src/gose/jose/jwe.gleam", 525).
?DOC(
    " Set the Agreement PartyUInfo (apu) for ECDH-ES algorithms.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let jwe = jwe.new_ecdh_es(gose.EcdhEsDirect, gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.with_apu(<<\"Alice\":utf8>>)\n"
    "   |> jwe.with_apv(<<\"Bob\":utf8>>)\n"
    " let assert Ok(encrypted) = jwe\n"
    "   |> jwe.encrypt(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec with_apu(jwe(unencrypted(), ecdh_es(), built()), bitstring()) -> jwe(unencrypted(), ecdh_es(), built()).
with_apu(Jwe, Apu) ->
    case Jwe of
        {jwe, _, _, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"with_apu"/utf8>>,
                        line => 529,
                        value => _assert_fail,
                        start => 16424,
                        'end' => 16448,
                        pattern_start => 16435,
                        pattern_end => 16442})
    end,
    Apv@1 = case erlang:element(6, Jwe) of
        {ecdh_es_builder_fields, _, Apv} -> Apv;
        _assert_fail@1 ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"with_apu"/utf8>>,
                        line => 530,
                        value => _assert_fail@1,
                        start => 16451,
                        'end' => 16508,
                        pattern_start => 16462,
                        pattern_end => 16491})
    end,
    {jwe,
        erlang:element(2, Jwe),
        erlang:element(3, Jwe),
        erlang:element(4, Jwe),
        erlang:element(5, Jwe),
        {ecdh_es_builder_fields, {some, Apu}, Apv@1}}.

-file("src/gose/jose/jwe.gleam", 545).
?DOC(
    " Set the Agreement PartyVInfo (apv) for ECDH-ES algorithms.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let jwe = jwe.new_ecdh_es(gose.EcdhEsDirect, gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.with_apu(<<\"Alice\":utf8>>)\n"
    "   |> jwe.with_apv(<<\"Bob\":utf8>>)\n"
    " let assert Ok(encrypted) = jwe\n"
    "   |> jwe.encrypt(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec with_apv(jwe(unencrypted(), ecdh_es(), built()), bitstring()) -> jwe(unencrypted(), ecdh_es(), built()).
with_apv(Jwe, Apv) ->
    case Jwe of
        {jwe, _, _, _, _, _} -> nil;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"with_apv"/utf8>>,
                        line => 549,
                        value => _assert_fail,
                        start => 17041,
                        'end' => 17065,
                        pattern_start => 17052,
                        pattern_end => 17059})
    end,
    Apu@1 = case erlang:element(6, Jwe) of
        {ecdh_es_builder_fields, Apu, _} -> Apu;
        _assert_fail@1 ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"with_apv"/utf8>>,
                        line => 550,
                        value => _assert_fail@1,
                        start => 17068,
                        'end' => 17125,
                        pattern_start => 17079,
                        pattern_end => 17108})
    end,
    {jwe,
        erlang:element(2, Jwe),
        erlang:element(3, Jwe),
        erlang:element(4, Jwe),
        erlang:element(5, Jwe),
        {ecdh_es_builder_fields, Apu@1, {some, Apv}}}.

-file("src/gose/jose/jwe.gleam", 555).
?DOC(" Set the content type (cty) header parameter.\n").
-spec with_cty(jwe(unencrypted(), SQD, built()), binary()) -> jwe(unencrypted(), SQD, built()).
with_cty(Jwe, Cty) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"with_cty"/utf8>>,
                        line => 559,
                        value => _assert_fail,
                        start => 17366,
                        'end' => 17399,
                        pattern_start => 17377,
                        pattern_end => 17393})
    end,
    {jwe,
        {jwe_header,
            erlang:element(2, Header@1),
            erlang:element(3, Header@1),
            erlang:element(4, Header@1),
            erlang:element(5, Header@1),
            {some, Cty}},
        erlang:element(3, Jwe),
        erlang:element(4, Jwe),
        erlang:element(5, Jwe),
        erlang:element(6, Jwe)}.

-file("src/gose/jose/jwe.gleam", 564).
?DOC(" Set the key ID (kid) header parameter.\n").
-spec with_kid(jwe(unencrypted(), SQK, built()), binary()) -> jwe(unencrypted(), SQK, built()).
with_kid(Jwe, Kid) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"with_kid"/utf8>>,
                        line => 568,
                        value => _assert_fail,
                        start => 17624,
                        'end' => 17657,
                        pattern_start => 17635,
                        pattern_end => 17651})
    end,
    {jwe,
        {jwe_header,
            erlang:element(2, Header@1),
            erlang:element(3, Header@1),
            {some, Kid},
            erlang:element(5, Header@1),
            erlang:element(6, Header@1)},
        erlang:element(3, Jwe),
        erlang:element(4, Jwe),
        erlang:element(5, Jwe),
        erlang:element(6, Jwe)}.

-file("src/gose/jose/jwe.gleam", 729).
?DOC(" Set the type (typ) header parameter (e.g., \"JWT\").\n").
-spec with_typ(jwe(unencrypted(), SSA, built()), binary()) -> jwe(unencrypted(), SSA, built()).
with_typ(Jwe, Typ) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"with_typ"/utf8>>,
                        line => 733,
                        value => _assert_fail,
                        start => 23312,
                        'end' => 23345,
                        pattern_start => 23323,
                        pattern_end => 23339})
    end,
    {jwe,
        {jwe_header,
            erlang:element(2, Header@1),
            erlang:element(3, Header@1),
            erlang:element(4, Header@1),
            {some, Typ},
            erlang:element(6, Header@1)},
        erlang:element(3, Jwe),
        erlang:element(4, Jwe),
        erlang:element(5, Jwe),
        erlang:element(6, Jwe)}.

-file("src/gose/jose/jwe.gleam", 778).
?DOC(
    " Get the Additional Authenticated Data (AAD) from an encrypted JWE.\n"
    "\n"
    " Returns `Ok(aad)` if AAD was set, `Error(Nil)` if not.\n"
    " AAD is only present in JSON serialization; compact format never has AAD.\n"
).
-spec aad(jwe(encrypted(), any(), any())) -> {ok, bitstring()} | {error, nil}.
aad(Jwe) ->
    Aad@1 = case Jwe of
        {encrypted_jwe, _, _, _, _, _, _, _, Aad, _, _, _, _} -> Aad;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"aad"/utf8>>,
                        line => 779,
                        value => _assert_fail,
                        start => 24885,
                        'end' => 24924,
                        pattern_start => 24896,
                        pattern_end => 24918})
    end,
    gleam@option:to_result(Aad@1, nil).

-file("src/gose/jose/jwe.gleam", 784).
?DOC(" Get the key encryption algorithm (`alg`) from a JWE.\n").
-spec alg(jwe(any(), any(), any())) -> gose:key_encryption_alg().
alg(Jwe) ->
    case Jwe of
        {jwe, Header, _, _, _, _} ->
            erlang:element(2, Header);

        {encrypted_jwe, Header, _, _, _, _, _, _, _, _, _, _, _} ->
            erlang:element(2, Header)
    end.

-file("src/gose/jose/jwe.gleam", 791).
?DOC(" Get the content type (cty) from a JWE header.\n").
-spec cty(jwe(any(), any(), any())) -> {ok, binary()} | {error, nil}.
cty(Jwe) ->
    case Jwe of
        {jwe, Header, _, _, _, _} ->
            gleam@option:to_result(erlang:element(6, Header), nil);

        {encrypted_jwe, Header, _, _, _, _, _, _, _, _, _, _, _} ->
            gleam@option:to_result(erlang:element(6, Header), nil)
    end.

-file("src/gose/jose/jwe.gleam", 820).
?DOC(
    " Decode the shared unprotected header using a custom decoder.\n"
    "\n"
    " **Security Warning:** Shared unprotected headers are NOT integrity protected.\n"
    " Values can be modified by an attacker without detection. Never trust\n"
    " security-critical parameters from unprotected headers.\n"
    "\n"
    " This function only works on parsed JWE instances. When building a JWE,\n"
    " you already know what unprotected headers you set - use `has_shared_unprotected_header`\n"
    " to check their presence.\n"
    "\n"
    " Returns an error if no shared unprotected headers are present.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let decoder = {\n"
    "   use id <- decode.field(\"x-request-id\", decode.string)\n"
    "   decode.success(id)\n"
    " }\n"
    " let assert Ok(request_id) =\n"
    "   jwe.decode_shared_unprotected_header(parsed_jwe, decoder)\n"
    " ```\n"
).
-spec decode_shared_unprotected_header(
    jwe(encrypted(), any(), parsed()),
    gleam@dynamic@decode:decoder(STP)
) -> {ok, STP} | {error, gose:gose_error()}.
decode_shared_unprotected_header(Jwe, Decoder) ->
    Shared_unprotected_raw@1 = case Jwe of
        {encrypted_jwe, _, _, _, _, _, _, _, _, _, Shared_unprotected_raw, _, _} -> Shared_unprotected_raw;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"decode_shared_unprotected_header"/utf8>>,
                        line => 824,
                        value => _assert_fail,
                        start => 26349,
                        'end' => 26407,
                        pattern_start => 26360,
                        pattern_end => 26401})
    end,
    case Shared_unprotected_raw@1 of
        {some, Raw} ->
            _pipe = gleam@dynamic@decode:run(Raw, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error,
                    <<"failed to decode shared unprotected header"/utf8>>}
            );

        none ->
            {error,
                {parse_error, <<"no shared unprotected headers present"/utf8>>}}
    end.

-file("src/gose/jose/jwe.gleam", 858).
?DOC(
    " Decode the per-recipient unprotected header using a custom decoder.\n"
    "\n"
    " **Security Warning:** Per-recipient unprotected headers are NOT integrity protected.\n"
    " Values can be modified by an attacker without detection. Never trust\n"
    " security-critical parameters from unprotected headers.\n"
    "\n"
    " This function only works on parsed JWE instances. When building a JWE,\n"
    " you already know what unprotected headers you set - use `has_unprotected_header`\n"
    " to check their presence.\n"
    "\n"
    " Returns an error if no per-recipient unprotected headers are present.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let decoder = {\n"
    "   use id <- decode.field(\"x-recipient-id\", decode.string)\n"
    "   decode.success(id)\n"
    " }\n"
    " let assert Ok(recipient_id) =\n"
    "   jwe.decode_unprotected_header(parsed_jwe, decoder)\n"
    " ```\n"
).
-spec decode_unprotected_header(
    jwe(encrypted(), any(), parsed()),
    gleam@dynamic@decode:decoder(STX)
) -> {ok, STX} | {error, gose:gose_error()}.
decode_unprotected_header(Jwe, Decoder) ->
    Per_recipient_unprotected_raw@1 = case Jwe of
        {encrypted_jwe,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            Per_recipient_unprotected_raw} -> Per_recipient_unprotected_raw;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"decode_unprotected_header"/utf8>>,
                        line => 862,
                        value => _assert_fail,
                        start => 27655,
                        'end' => 27720,
                        pattern_start => 27666,
                        pattern_end => 27714})
    end,
    case Per_recipient_unprotected_raw@1 of
        {some, Raw} ->
            _pipe = gleam@dynamic@decode:run(Raw, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error,
                    <<"failed to decode per-recipient unprotected header"/utf8>>}
            );

        none ->
            {error,
                {parse_error,
                    <<"no per-recipient unprotected headers present"/utf8>>}}
    end.

-file("src/gose/jose/jwe.gleam", 875).
?DOC(" Get the content encryption algorithm (`enc`) from a JWE.\n").
-spec enc(jwe(any(), any(), any())) -> gose:content_alg().
enc(Jwe) ->
    case Jwe of
        {jwe, Header, _, _, _, _} ->
            erlang:element(3, Header);

        {encrypted_jwe, Header, _, _, _, _, _, _, _, _, _, _, _} ->
            erlang:element(3, Header)
    end.

-file("src/gose/jose/jwe.gleam", 885).
?DOC(
    " Check if shared unprotected headers are present.\n"
    "\n"
    " Returns True if the JWE was parsed from JSON with shared unprotected headers,\n"
    " or if shared unprotected headers were added via `with_shared_unprotected`.\n"
).
-spec has_shared_unprotected_header(jwe(encrypted(), any(), any())) -> boolean().
has_shared_unprotected_header(Jwe) ->
    {Shared_unprotected@1, Shared_unprotected_raw@1} = case Jwe of
        {encrypted_jwe,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            Shared_unprotected,
            Shared_unprotected_raw,
            _,
            _} -> {Shared_unprotected, Shared_unprotected_raw};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"has_shared_unprotected_header"/utf8>>,
                        line => 888,
                        value => _assert_fail,
                        start => 28553,
                        'end' => 28636,
                        pattern_start => 28564,
                        pattern_end => 28626})
    end,
    gleam@option:is_some(Shared_unprotected_raw@1) orelse not gleam@dict:is_empty(
        Shared_unprotected@1
    ).

-file("src/gose/jose/jwe.gleam", 897).
?DOC(
    " Check if per-recipient unprotected headers are present.\n"
    "\n"
    " Returns True if the JWE was parsed from JSON with per-recipient unprotected headers,\n"
    " or if per-recipient unprotected headers were added via `with_unprotected`.\n"
).
-spec has_unprotected_header(jwe(encrypted(), any(), any())) -> boolean().
has_unprotected_header(Jwe) ->
    {Per_recipient_unprotected@1, Per_recipient_unprotected_raw@1} = case Jwe of
        {encrypted_jwe,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            Per_recipient_unprotected,
            Per_recipient_unprotected_raw} -> {
        Per_recipient_unprotected,
            Per_recipient_unprotected_raw};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"has_unprotected_header"/utf8>>,
                        line => 898,
                        value => _assert_fail,
                        start => 29030,
                        'end' => 29140,
                        pattern_start => 29041,
                        pattern_end => 29134})
    end,
    gleam@option:is_some(Per_recipient_unprotected_raw@1) orelse not gleam@dict:is_empty(
        Per_recipient_unprotected@1
    ).

-file("src/gose/jose/jwe.gleam", 908).
?DOC(" Get the key ID (kid) from a JWE header.\n").
-spec kid(jwe(any(), any(), any())) -> {ok, binary()} | {error, nil}.
kid(Jwe) ->
    case Jwe of
        {jwe, Header, _, _, _, _} ->
            gleam@option:to_result(erlang:element(4, Header), nil);

        {encrypted_jwe, Header, _, _, _, _, _, _, _, _, _, _, _} ->
            gleam@option:to_result(erlang:element(4, Header), nil)
    end.

-file("src/gose/jose/jwe.gleam", 916).
?DOC(" Get the type (typ) from a JWE header.\n").
-spec typ(jwe(any(), any(), any())) -> {ok, binary()} | {error, nil}.
typ(Jwe) ->
    case Jwe of
        {jwe, Header, _, _, _, _} ->
            gleam@option:to_result(erlang:element(5, Header), nil);

        {encrypted_jwe, Header, _, _, _, _, _, _, _, _, _, _, _} ->
            gleam@option:to_result(erlang:element(5, Header), nil)
    end.

-file("src/gose/jose/jwe.gleam", 1069).
-spec wrap_ecdh_by_alg(
    gose:ecdh_es_alg(),
    gose:content_alg(),
    gose:key(binary()),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, {bitstring(), bitstring(), resolved_alg_fields()}} |
    {error, gose:gose_error()}.
wrap_ecdh_by_alg(Alg, Enc, Key, Apu, Apv) ->
    case Alg of
        ecdh_es_direct ->
            Alg_id = gose@jose:content_alg_to_string(Enc),
            gleam@result:'try'(
                gose@internal@key_encryption:wrap_ecdh_es_direct(
                    Key,
                    Enc,
                    Alg_id,
                    Apu,
                    Apv
                ),
                fun(_use0) ->
                    {Derived_cek, Epk} = _use0,
                    {ok,
                        {Derived_cek,
                            <<>>,
                            {ecdh_es_resolved_fields, {some, Epk}, Apu, Apv}}}
                end
            );

        {ecdh_es_aes_kw, Size} ->
            Cek = gose@internal@content_encryption:generate_cek(Enc),
            Alg_id@1 = gose@jose:key_encryption_alg_to_string(
                {ecdh_es, {ecdh_es_aes_kw, Size}}
            ),
            gleam@result:'try'(
                gose@internal@key_encryption:wrap_ecdh_es_kw(
                    Key,
                    Cek,
                    Size,
                    Alg_id@1,
                    Apu,
                    Apv
                ),
                fun(_use0@1) ->
                    {Wrapped, Epk@1} = _use0@1,
                    {ok,
                        {Cek,
                            Wrapped,
                            {ecdh_es_resolved_fields, {some, Epk@1}, Apu, Apv}}}
                end
            );

        {ecdh_es_cha_cha20_kw, Variant} ->
            Cek@1 = gose@internal@content_encryption:generate_cek(Enc),
            Alg_id@2 = gose@jose:key_encryption_alg_to_string(
                {ecdh_es, {ecdh_es_cha_cha20_kw, Variant}}
            ),
            gleam@result:'try'(
                gose@internal@key_encryption:wrap_ecdh_es_chacha20_kw(
                    Key,
                    Cek@1,
                    Variant,
                    Alg_id@2,
                    Apu,
                    Apv
                ),
                fun(_use0@2) ->
                    {Encrypted_cek, Epk@2, Kw_iv, Kw_tag} = _use0@2,
                    {ok,
                        {Cek@1,
                            Encrypted_cek,
                            {ecdh_es_cha_cha20_kw_resolved_fields,
                                {some, Epk@2},
                                Apu,
                                Apv,
                                {some, Kw_iv},
                                {some, Kw_tag}}}}
                end
            )
    end.

-file("src/gose/jose/jwe.gleam", 1141).
-spec extract_ecdh_apu_apv(builder_alg_fields()) -> {gleam@option:option(bitstring()),
    gleam@option:option(bitstring())}.
extract_ecdh_apu_apv(Alg_fields) ->
    {Apu@1, Apv@1} = case Alg_fields of
        {ecdh_es_builder_fields, Apu, Apv} -> {Apu, Apv};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"extract_ecdh_apu_apv"/utf8>>,
                        line => 1144,
                        value => _assert_fail,
                        start => 35474,
                        'end' => 35529,
                        pattern_start => 35485,
                        pattern_end => 35516})
    end,
    {Apu@1, Apv@1}.

-file("src/gose/jose/jwe.gleam", 1177).
-spec wrap_rsa_by_alg(
    gose:rsa_encryption_alg(),
    gose:key(binary()),
    bitstring()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
wrap_rsa_by_alg(Alg, Key, Cek) ->
    case Alg of
        rsa_pkcs1v15 ->
            gose@internal@key_encryption:wrap_rsa_pkcs1v15(Key, Cek);

        rsa_oaep_sha1 ->
            gose@internal@key_encryption:wrap_rsa_oaep(Key, Cek, sha1);

        rsa_oaep_sha256 ->
            gose@internal@key_encryption:wrap_rsa_oaep(Key, Cek, sha256)
    end.

-file("src/gose/jose/jwe.gleam", 1256).
-spec unwrap_cek_ecdh(
    gose:ecdh_es_alg(),
    resolved_alg_fields(),
    gose:key(binary()),
    bitstring(),
    gose:content_alg()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_cek_ecdh(Ecdh_alg, Alg_fields, Key, Encrypted_key, Enc) ->
    case Ecdh_alg of
        ecdh_es_direct ->
            {Epk@1, Apu@1, Apv@1} = case Alg_fields of
                {ecdh_es_resolved_fields, Epk, Apu, Apv} -> {Epk, Apu, Apv};
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"unwrap_cek_ecdh"/utf8>>,
                                line => 1265,
                                value => _assert_fail,
                                start => 39088,
                                'end' => 39150,
                                pattern_start => 39099,
                                pattern_end => 39137})
            end,
            gleam@result:'try'(
                gleam@option:to_result(
                    Epk@1,
                    {invalid_state, <<"missing epk in header"/utf8>>}
                ),
                fun(Epk@2) ->
                    Alg_id = gose@jose:content_alg_to_string(Enc),
                    gose@internal@key_encryption:unwrap_ecdh_es_direct(
                        Key,
                        Enc,
                        Alg_id,
                        Epk@2,
                        Apu@1,
                        Apv@1
                    )
                end
            );

        {ecdh_es_aes_kw, Size} ->
            {Epk@4, Apu@3, Apv@3} = case Alg_fields of
                {ecdh_es_resolved_fields, Epk@3, Apu@2, Apv@2} -> {
                Epk@3,
                    Apu@2,
                    Apv@2};
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"unwrap_cek_ecdh"/utf8>>,
                                line => 1274,
                                value => _assert_fail@1,
                                start => 39447,
                                'end' => 39509,
                                pattern_start => 39458,
                                pattern_end => 39496})
            end,
            gleam@result:'try'(
                gleam@option:to_result(
                    Epk@4,
                    {invalid_state, <<"missing epk in header"/utf8>>}
                ),
                fun(Epk@5) ->
                    Alg_id@1 = gose@jose:key_encryption_alg_to_string(
                        {ecdh_es, {ecdh_es_aes_kw, Size}}
                    ),
                    gose@internal@key_encryption:unwrap_ecdh_es_kw(
                        Key,
                        Encrypted_key,
                        Size,
                        Alg_id@1,
                        Epk@5,
                        Apu@3,
                        Apv@3
                    )
                end
            );

        {ecdh_es_cha_cha20_kw, Variant} ->
            {Epk@7, Apu@5, Apv@5, Kw_iv@1, Kw_tag@1} = case Alg_fields of
                {ecdh_es_cha_cha20_kw_resolved_fields,
                    Epk@6,
                    Apu@4,
                    Apv@4,
                    Kw_iv,
                    Kw_tag} -> {Epk@6, Apu@4, Apv@4, Kw_iv, Kw_tag};
                _assert_fail@2 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"unwrap_cek_ecdh"/utf8>>,
                                line => 1292,
                                value => _assert_fail@2,
                                start => 39939,
                                'end' => 40077,
                                pattern_start => 39950,
                                pattern_end => 40064})
            end,
            gleam@result:'try'(
                gleam@option:to_result(
                    Epk@7,
                    {invalid_state, <<"missing epk in header"/utf8>>}
                ),
                fun(Epk@8) ->
                    gleam@result:'try'(
                        gleam@option:to_result(
                            Kw_iv@1,
                            {parse_error,
                                <<"missing iv header for ECDH-ES+ChaCha20 Key Wrap"/utf8>>}
                        ),
                        fun(Kw_iv@2) ->
                            gleam@result:'try'(
                                gleam@option:to_result(
                                    Kw_tag@1,
                                    {parse_error,
                                        <<"missing tag header for ECDH-ES+ChaCha20 Key Wrap"/utf8>>}
                                ),
                                fun(Kw_tag@2) ->
                                    Alg_id@2 = gose@jose:key_encryption_alg_to_string(
                                        {ecdh_es,
                                            {ecdh_es_cha_cha20_kw, Variant}}
                                    ),
                                    gose@internal@key_encryption:unwrap_ecdh_es_chacha20_kw(
                                        Key,
                                        Encrypted_key,
                                        Variant,
                                        Alg_id@2,
                                        Epk@8,
                                        Apu@5,
                                        Apv@5,
                                        Kw_iv@2,
                                        Kw_tag@2
                                    )
                                end
                            )
                        end
                    )
                end
            )
    end.

-file("src/gose/jose/jwe.gleam", 1209).
-spec unwrap_cek(
    jwe_header(),
    resolved_alg_fields(),
    gose:key(binary()),
    bitstring()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
unwrap_cek(Header, Alg_fields, Key, Encrypted_key) ->
    case erlang:element(2, Header) of
        direct ->
            gose@internal@key_encryption:unwrap_direct(
                Key,
                erlang:element(3, Header)
            );

        {aes_key_wrap, aes_kw, Aes_size} ->
            gose@internal@key_encryption:unwrap_aes_kw(
                Key,
                Encrypted_key,
                Aes_size
            );

        {aes_key_wrap, aes_gcm_kw, Aes_size@1} ->
            {Kw_iv@1, Kw_tag@1} = case Alg_fields of
                {aes_gcm_kw_resolved_fields, Kw_iv, Kw_tag} -> {Kw_iv, Kw_tag};
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"unwrap_cek"/utf8>>,
                                line => 1220,
                                value => _assert_fail,
                                start => 37724,
                                'end' => 37787,
                                pattern_start => 37735,
                                pattern_end => 37774})
            end,
            gose@internal@key_encryption:unwrap_aes_gcm_kw(
                Key,
                Encrypted_key,
                Aes_size@1,
                Kw_iv@1,
                Kw_tag@1
            );

        {rsa_encryption, rsa_pkcs1v15} ->
            gose@internal@key_encryption:unwrap_rsa_pkcs1v15_safe(
                Key,
                Encrypted_key,
                erlang:element(3, Header)
            );

        {rsa_encryption, rsa_oaep_sha1} ->
            gose@internal@key_encryption:unwrap_rsa_oaep(
                Key,
                Encrypted_key,
                sha1
            );

        {rsa_encryption, rsa_oaep_sha256} ->
            gose@internal@key_encryption:unwrap_rsa_oaep(
                Key,
                Encrypted_key,
                sha256
            );

        {cha_cha20_key_wrap, Variant} ->
            {Kw_iv@3, Kw_tag@3} = case Alg_fields of
                {cha_cha20_kw_resolved_fields, Kw_iv@2, Kw_tag@2} -> {
                Kw_iv@2,
                    Kw_tag@2};
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"unwrap_cek"/utf8>>,
                                line => 1240,
                                value => _assert_fail@1,
                                start => 38406,
                                'end' => 38471,
                                pattern_start => 38417,
                                pattern_end => 38458})
            end,
            gose@internal@key_encryption:unwrap_chacha20_kw(
                Key,
                Encrypted_key,
                Variant,
                Kw_iv@3,
                Kw_tag@3
            );

        {ecdh_es, Ecdh_alg} ->
            unwrap_cek_ecdh(
                Ecdh_alg,
                Alg_fields,
                Key,
                Encrypted_key,
                erlang:element(3, Header)
            );

        {pbes2, _} ->
            {error,
                {invalid_state,
                    <<"use password_decryptor for PBES2 algorithms"/utf8>>}}
    end.

-file("src/gose/jose/jwe.gleam", 1330).
-spec decrypt_with_key(jwe(encrypted(), any(), any()), gose:key(binary())) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
decrypt_with_key(Jwe, Key) ->
    {
    Header@1,
        Protected_b64@1,
        Encrypted_key@1,
        Iv@1,
        Ciphertext@1,
        Tag@1,
        Alg_fields@1,
        User_aad@1} = case Jwe of
        {encrypted_jwe,
            Header,
            Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            Alg_fields,
            User_aad,
            _,
            _,
            _,
            _} -> {
        Header,
            Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            Alg_fields,
            User_aad};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"decrypt_with_key"/utf8>>,
                        line => 1334,
                        value => _assert_fail,
                        start => 40968,
                        'end' => 41135,
                        pattern_start => 40979,
                        pattern_end => 41129})
    end,
    Ops_purpose = case erlang:element(2, Header@1) of
        {ecdh_es, _} ->
            for_key_agreement;

        _ ->
            for_decryption
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_use(Key, Ops_purpose),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@key_helpers:validate_key_ops(Key, Ops_purpose),
                fun(_) ->
                    gleam@result:'try'(
                        gose@internal@key_helpers:validate_key_algorithm_jwe(
                            Key,
                            erlang:element(2, Header@1)
                        ),
                        fun(_) ->
                            gleam@result:'try'(
                                unwrap_cek(
                                    Header@1,
                                    Alg_fields@1,
                                    Key,
                                    Encrypted_key@1
                                ),
                                fun(Cek) ->
                                    Aead_aad = gose@internal@content_encryption:build_jwe_aad(
                                        Protected_b64@1,
                                        User_aad@1
                                    ),
                                    gose@internal@content_encryption:decrypt_content(
                                        erlang:element(3, Header@1),
                                        Cek,
                                        Iv@1,
                                        Aead_aad,
                                        Ciphertext@1,
                                        Tag@1
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1367).
-spec require_pbes2_alg(gose:key_encryption_alg()) -> {ok, gose:pbes2_alg()} |
    {error, gose:gose_error()}.
require_pbes2_alg(Alg) ->
    case Alg of
        {pbes2, Pbes2_alg} ->
            {ok, Pbes2_alg};

        direct ->
            {error, {invalid_state, <<"expected PBES2 algorithm"/utf8>>}};

        {aes_key_wrap, _, _} ->
            {error, {invalid_state, <<"expected PBES2 algorithm"/utf8>>}};

        {cha_cha20_key_wrap, _} ->
            {error, {invalid_state, <<"expected PBES2 algorithm"/utf8>>}};

        {rsa_encryption, _} ->
            {error, {invalid_state, <<"expected PBES2 algorithm"/utf8>>}};

        {ecdh_es, _} ->
            {error, {invalid_state, <<"expected PBES2 algorithm"/utf8>>}}
    end.

-file("src/gose/jose/jwe.gleam", 1380).
-spec resolve_pbes2_params(gose:pbes2_alg()) -> {kryptos@hash:hash_algorithm(),
    gose:aes_key_size(),
    integer()}.
resolve_pbes2_params(Alg) ->
    case Alg of
        pbes2_sha256_aes128_kw ->
            {sha256, aes128, 310000};

        pbes2_sha384_aes192_kw ->
            {sha384, aes192, 250000};

        pbes2_sha512_aes256_kw ->
            {sha512, aes256, 120000}
    end.

-file("src/gose/jose/jwe.gleam", 1390).
-spec decrypt_with_password(jwe(encrypted(), any(), any()), binary()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
decrypt_with_password(Jwe, Password) ->
    {
    Header@1,
        Protected_b64@1,
        Encrypted_key@1,
        Iv@1,
        Ciphertext@1,
        Tag@1,
        Alg_fields@1,
        User_aad@1} = case Jwe of
        {encrypted_jwe,
            Header,
            Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            Alg_fields,
            User_aad,
            _,
            _,
            _,
            _} -> {
        Header,
            Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            Alg_fields,
            User_aad};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"decrypt_with_password"/utf8>>,
                        line => 1394,
                        value => _assert_fail,
                        start => 42554,
                        'end' => 42721,
                        pattern_start => 42565,
                        pattern_end => 42715})
    end,
    gleam@result:'try'(
        require_pbes2_alg(erlang:element(2, Header@1)),
        fun(Pbes2_alg) ->
            {Hash_alg, Kw_size, _} = resolve_pbes2_params(Pbes2_alg),
            Kw_key_len = gose:aes_key_size(Kw_size),
            {Salt_input@1, Iterations@1} = case Alg_fields@1 of
                {pbes2_resolved_fields, Salt_input, Iterations} -> {
                Salt_input,
                    Iterations};
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"decrypt_with_password"/utf8>>,
                                line => 1410,
                                value => _assert_fail@1,
                                start => 42897,
                                'end' => 42974,
                                pattern_start => 42908,
                                pattern_end => 42961})
            end,
            Alg_str = gose@jose:key_encryption_alg_to_string(
                erlang:element(2, Header@1)
            ),
            Salt = gleam_stdlib:bit_array_concat(
                [gleam_stdlib:identity(Alg_str), <<0>>, Salt_input@1]
            ),
            gleam@result:'try'(
                begin
                    _pipe = kryptos@crypto:pbkdf2(
                        Hash_alg,
                        gleam_stdlib:identity(Password),
                        Salt,
                        Iterations@1,
                        Kw_key_len
                    ),
                    gleam@result:replace_error(
                        _pipe,
                        {crypto_error, <<"PBKDF2 key derivation failed"/utf8>>}
                    )
                end,
                fun(Kek) ->
                    gleam@result:'try'(
                        gose@internal@content_encryption:aes_cipher(
                            Kw_size,
                            Kek
                        ),
                        fun(Cipher) ->
                            gleam@result:'try'(
                                begin
                                    _pipe@1 = kryptos@block:unwrap(
                                        Cipher,
                                        Encrypted_key@1
                                    ),
                                    gleam@result:replace_error(
                                        _pipe@1,
                                        {crypto_error,
                                            <<"AES Key Unwrap failed"/utf8>>}
                                    )
                                end,
                                fun(Cek) ->
                                    Aead_aad = gose@internal@content_encryption:build_jwe_aad(
                                        Protected_b64@1,
                                        User_aad@1
                                    ),
                                    gose@internal@content_encryption:decrypt_content(
                                        erlang:element(3, Header@1),
                                        Cek,
                                        Iv@1,
                                        Aead_aad,
                                        Ciphertext@1,
                                        Tag@1
                                    )
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1477).
-spec require_matching_jwe_algorithms(
    decryptor(),
    gose:key_encryption_alg(),
    gose:content_alg()
) -> {ok, nil} | {error, gose:gose_error()}.
require_matching_jwe_algorithms(Decryptor, Actual_alg, Actual_enc) ->
    {Expected_alg, Expected_enc} = case Decryptor of
        {key_decryptor, Alg, Enc, _} ->
            {Alg, Enc};

        {password_decryptor, Alg@1, Enc@1, _} ->
            {{pbes2, Alg@1}, Enc@1}
    end,
    gleam@bool:guard(
        Expected_alg /= Actual_alg,
        {error,
            {invalid_state,
                <<<<<<"algorithm mismatch: expected "/utf8,
                            (gose@jose:key_encryption_alg_to_string(
                                Expected_alg
                            ))/binary>>/binary,
                        ", got "/utf8>>/binary,
                    (gose@jose:key_encryption_alg_to_string(Actual_alg))/binary>>}},
        fun() ->
            gleam@bool:guard(
                Expected_enc /= Actual_enc,
                {error,
                    {invalid_state,
                        <<<<<<"encryption mismatch: expected "/utf8,
                                    (gose@jose:content_alg_to_string(
                                        Expected_enc
                                    ))/binary>>/binary,
                                ", got "/utf8>>/binary,
                            (gose@jose:content_alg_to_string(Actual_enc))/binary>>}},
                fun() -> {ok, nil} end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1529).
-spec try_keys(
    list(gose:key(binary())),
    jwe(encrypted(), TAF, TAG),
    fun((jwe(encrypted(), TAF, TAG), gose:key(binary())) -> {ok, bitstring()} |
        {error, gose:gose_error()}),
    {ok, bitstring()} | {error, gose:gose_error()}
) -> {ok, bitstring()} | {error, gose:gose_error()}.
try_keys(Keys, Jwe, Decrypt_fn, Last_error) ->
    case Keys of
        [] ->
            Last_error;

        [Key | Rest] ->
            case Decrypt_fn(Jwe, Key) of
                {ok, Plaintext} ->
                    {ok, Plaintext};

                {error, {crypto_error, _} = E} ->
                    try_keys(Rest, Jwe, Decrypt_fn, {error, E});

                {error, verification_failed = E@1} ->
                    try_keys(Rest, Jwe, Decrypt_fn, {error, E@1});

                {error, E@2} ->
                    {error, E@2}
            end
    end.

-file("src/gose/jose/jwe.gleam", 1509).
-spec decrypt_with_keys(
    jwe(encrypted(), SZO, SZP),
    list(gose:key(binary())),
    fun((jwe(encrypted(), SZO, SZP), gose:key(binary())) -> {ok, bitstring()} |
        {error, gose:gose_error()})
) -> {ok, bitstring()} | {error, gose:gose_error()}.
decrypt_with_keys(Jwe, Keys, Decrypt_fn) ->
    Ordered_keys = gose@internal@key_helpers:order_keys_by_kid(
        Keys,
        gleam@option:from_result(kid(Jwe))
    ),
    try_keys(
        Ordered_keys,
        Jwe,
        Decrypt_fn,
        {error, {invalid_state, <<"no keys provided"/utf8>>}}
    ).

-file("src/gose/jose/jwe.gleam", 1459).
?DOC(
    " Decrypt a JWE using a decryptor with algorithm pinning.\n"
    "\n"
    " This is the recommended way to decrypt JWEs as it prevents algorithm\n"
    " confusion attacks by validating that the token's algorithms match\n"
    " the expected algorithms configured in the decryptor.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " // Create a decryptor that only accepts A256GCM with direct encryption\n"
    " let assert Ok(decryptor) = jwe.key_decryptor(gose.Direct, gose.AesGcm(gose.Aes256), [key])\n"
    "\n"
    " // This will fail if the token uses a different algorithm\n"
    " let assert Ok(plaintext) = jwe.decrypt(decryptor, jwe)\n"
    " ```\n"
).
-spec decrypt(decryptor(), jwe(encrypted(), any(), any())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
decrypt(Decryptor, Jwe) ->
    Header@1 = case Jwe of
        {encrypted_jwe, Header, _, _, _, _, _, _, _, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"decrypt"/utf8>>,
                        line => 1463,
                        value => _assert_fail,
                        start => 44522,
                        'end' => 44564,
                        pattern_start => 44533,
                        pattern_end => 44558})
    end,
    gleam@result:'try'(
        require_matching_jwe_algorithms(
            Decryptor,
            erlang:element(2, Header@1),
            erlang:element(3, Header@1)
        ),
        fun(_) -> case Decryptor of
                {key_decryptor, _, _, Keys} ->
                    decrypt_with_keys(Jwe, Keys, fun decrypt_with_key/2);

                {password_decryptor, _, _, Password} ->
                    decrypt_with_password(Jwe, Password)
            end end
    ).

-file("src/gose/jose/jwe.gleam", 1617).
-spec epk_to_json_field(gose@internal@key_encryption:ephemeral_public_key()) -> {binary(),
    gleam@json:json()}.
epk_to_json_field(Epk) ->
    case Epk of
        {ec_ephemeral_key, Curve, X, Y} ->
            {<<"epk"/utf8>>,
                gleam@json:object(
                    [{<<"kty"/utf8>>, gleam@json:string(<<"EC"/utf8>>)},
                        {<<"crv"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:ec_curve_to_string(Curve)
                            )},
                        {<<"x"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(X)
                            )},
                        {<<"y"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(Y)
                            )}]
                )};

        {xdh_ephemeral_key, Curve@1, X@1} ->
            {<<"epk"/utf8>>,
                gleam@json:object(
                    [{<<"kty"/utf8>>, gleam@json:string(<<"OKP"/utf8>>)},
                        {<<"crv"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:xdh_curve_to_string(Curve@1)
                            )},
                        {<<"x"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(X@1)
                            )}]
                )}
    end.

-file("src/gose/jose/jwe.gleam", 1572).
-spec alg_fields_to_json(resolved_alg_fields()) -> list(gleam@option:option({binary(),
    gleam@json:json()})).
alg_fields_to_json(Alg_fields) ->
    case Alg_fields of
        no_resolved_alg_fields ->
            [];

        {ecdh_es_resolved_fields, Epk, Apu, Apv} ->
            [gleam@option:map(Epk, fun epk_to_json_field/1),
                gleam@option:map(
                    Apu,
                    fun(A) ->
                        {<<"apu"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(A)
                            )}
                    end
                ),
                gleam@option:map(
                    Apv,
                    fun(A@1) ->
                        {<<"apv"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(A@1)
                            )}
                    end
                )];

        {pbes2_resolved_fields, P2s, P2c} ->
            [{some,
                    {<<"p2s"/utf8>>,
                        gleam@json:string(
                            gose@internal@utils:encode_base64_url(P2s)
                        )}},
                {some, {<<"p2c"/utf8>>, gleam@json:int(P2c)}}];

        {aes_gcm_kw_resolved_fields, Kw_iv, Kw_tag} ->
            [gleam@option:map(
                    Kw_iv,
                    fun(Iv) ->
                        {<<"iv"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(Iv)
                            )}
                    end
                ),
                gleam@option:map(
                    Kw_tag,
                    fun(T) ->
                        {<<"tag"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(T)
                            )}
                    end
                )];

        {cha_cha20_kw_resolved_fields, Kw_iv, Kw_tag} ->
            [gleam@option:map(
                    Kw_iv,
                    fun(Iv) ->
                        {<<"iv"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(Iv)
                            )}
                    end
                ),
                gleam@option:map(
                    Kw_tag,
                    fun(T) ->
                        {<<"tag"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(T)
                            )}
                    end
                )];

        {ecdh_es_cha_cha20_kw_resolved_fields,
            Epk@1,
            Apu@1,
            Apv@1,
            Kw_iv@1,
            Kw_tag@1} ->
            [gleam@option:map(Epk@1, fun epk_to_json_field/1),
                gleam@option:map(
                    Apu@1,
                    fun(A@2) ->
                        {<<"apu"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(A@2)
                            )}
                    end
                ),
                gleam@option:map(
                    Apv@1,
                    fun(A@3) ->
                        {<<"apv"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(A@3)
                            )}
                    end
                ),
                gleam@option:map(
                    Kw_iv@1,
                    fun(Iv@1) ->
                        {<<"iv"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(Iv@1)
                            )}
                    end
                ),
                gleam@option:map(
                    Kw_tag@1,
                    fun(T@1) ->
                        {<<"tag"/utf8>>,
                            gleam@json:string(
                                gose@internal@utils:encode_base64_url(T@1)
                            )}
                    end
                )]
    end.

-file("src/gose/jose/jwe.gleam", 1550).
-spec header_to_json(jwe_header(), resolved_alg_fields()) -> bitstring().
header_to_json(Header, Alg_fields) ->
    Alg_field = {<<"alg"/utf8>>,
        gleam@json:string(
            gose@jose:key_encryption_alg_to_string(erlang:element(2, Header))
        )},
    Enc_field = {<<"enc"/utf8>>,
        gleam@json:string(
            gose@jose:content_alg_to_string(erlang:element(3, Header))
        )},
    Optional_fields = begin
        _pipe = [gleam@option:map(
                erlang:element(4, Header),
                fun(K) -> {<<"kid"/utf8>>, gleam@json:string(K)} end
            ),
            gleam@option:map(
                erlang:element(5, Header),
                fun(T) -> {<<"typ"/utf8>>, gleam@json:string(T)} end
            ),
            gleam@option:map(
                erlang:element(6, Header),
                fun(C) -> {<<"cty"/utf8>>, gleam@json:string(C)} end
            ) |
            alg_fields_to_json(Alg_fields)],
        gleam@option:values(_pipe)
    end,
    Fields = [Alg_field, Enc_field | Optional_fields],
    _pipe@1 = gleam@json:object(Fields),
    _pipe@2 = gleam@json:to_string(_pipe@1),
    gleam_stdlib:identity(_pipe@2).

-file("src/gose/jose/jwe.gleam", 923).
-spec finalize_encryption(
    jwe(unencrypted(), SVH, built()),
    bitstring(),
    bitstring(),
    resolved_alg_fields(),
    bitstring()
) -> {ok, jwe(encrypted(), SVH, built())} | {error, gose:gose_error()}.
finalize_encryption(Jwe, Cek, Encrypted_key, Alg_fields, Plaintext) ->
    {Header@1, Aad@1, Shared_unprotected@1, Per_recipient_unprotected@1} = case Jwe of
        {jwe, Header, Aad, Shared_unprotected, Per_recipient_unprotected, _} -> {
        Header,
            Aad,
            Shared_unprotected,
            Per_recipient_unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"finalize_encryption"/utf8>>,
                        line => 930,
                        value => _assert_fail,
                        start => 29914,
                        'end' => 30027,
                        pattern_start => 29925,
                        pattern_end => 30021})
    end,
    Iv = gose@internal@content_encryption:generate_iv(
        erlang:element(3, Header@1)
    ),
    Protected_json = header_to_json(Header@1, Alg_fields),
    Protected_b64 = gose@internal@utils:encode_base64_url(Protected_json),
    Aead_aad = gose@internal@content_encryption:build_jwe_aad(
        Protected_b64,
        Aad@1
    ),
    gleam@result:'try'(
        gose@internal@content_encryption:encrypt_content(
            erlang:element(3, Header@1),
            Cek,
            Iv,
            Aead_aad,
            Plaintext
        ),
        fun(_use0) ->
            {Ciphertext, Tag} = _use0,
            {ok,
                {encrypted_jwe,
                    Header@1,
                    Protected_b64,
                    Encrypted_key,
                    Iv,
                    Ciphertext,
                    Tag,
                    Alg_fields,
                    Aad@1,
                    Shared_unprotected@1,
                    none,
                    Per_recipient_unprotected@1,
                    none}}
        end
    ).

-file("src/gose/jose/jwe.gleam", 651).
?DOC(
    " Encrypt a JWE using a password (PBES2).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(encrypted) = jwe.new_pbes2(gose.Pbes2Sha256Aes128Kw, gose.AesGcm(gose.Aes128))\n"
    "   |> jwe.encrypt_with_password(\"super-secret\", <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec encrypt_with_password(
    jwe(unencrypted(), pbes2(), built()),
    binary(),
    bitstring()
) -> {ok, jwe(encrypted(), pbes2(), built())} | {error, gose:gose_error()}.
encrypt_with_password(Jwe, Password, Plaintext) ->
    {Header@1, Custom_p2c@1} = case Jwe of
        {jwe, Header, _, _, _, {pbes2_builder_fields, Custom_p2c}} -> {
        Header,
            Custom_p2c};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"encrypt_with_password"/utf8>>,
                        line => 656,
                        value => _assert_fail,
                        start => 20670,
                        'end' => 20756,
                        pattern_start => 20681,
                        pattern_end => 20746})
    end,
    Pbes2_alg@1 = case erlang:element(2, Header@1) of
        {pbes2, Pbes2_alg} -> Pbes2_alg;
        _assert_fail@1 ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"encrypt_with_password"/utf8>>,
                        line => 659,
                        value => _assert_fail@1,
                        start => 20760,
                        'end' => 20805,
                        pattern_start => 20771,
                        pattern_end => 20792})
    end,
    {Hash_alg, Kw_size, Default_iterations} = resolve_pbes2_params(Pbes2_alg@1),
    Kw_key_len = gose:aes_key_size(Kw_size),
    Iterations = gleam@option:unwrap(Custom_p2c@1, Default_iterations),
    Salt_input = kryptos_ffi:random_bytes(16),
    Alg_str = gose@jose:key_encryption_alg_to_string(
        erlang:element(2, Header@1)
    ),
    Salt = gleam_stdlib:bit_array_concat(
        [gleam_stdlib:identity(Alg_str), <<0>>, Salt_input]
    ),
    gleam@result:'try'(
        begin
            _pipe = kryptos@crypto:pbkdf2(
                Hash_alg,
                gleam_stdlib:identity(Password),
                Salt,
                Iterations,
                Kw_key_len
            ),
            gleam@result:replace_error(
                _pipe,
                {crypto_error, <<"PBKDF2 key derivation failed"/utf8>>}
            )
        end,
        fun(Kek) ->
            Cek = gose@internal@content_encryption:generate_cek(
                erlang:element(3, Header@1)
            ),
            gleam@result:'try'(
                gose@internal@content_encryption:aes_cipher(Kw_size, Kek),
                fun(Cipher) ->
                    gleam@result:'try'(
                        begin
                            _pipe@1 = kryptos@block:wrap(Cipher, Cek),
                            gleam@result:replace_error(
                                _pipe@1,
                                {crypto_error, <<"AES Key Wrap failed"/utf8>>}
                            )
                        end,
                        fun(Encrypted_key) ->
                            Out_alg_fields = {pbes2_resolved_fields,
                                Salt_input,
                                Iterations},
                            finalize_encryption(
                                Jwe,
                                Cek,
                                Encrypted_key,
                                Out_alg_fields,
                                Plaintext
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 966).
-spec do_encrypt_aes_gcm_kw(
    jwe(unencrypted(), SVQ, built()),
    gose:key(binary()),
    bitstring()
) -> {ok, jwe(encrypted(), SVQ, built())} | {error, gose:gose_error()}.
do_encrypt_aes_gcm_kw(Jwe, Key, Plaintext) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"do_encrypt_aes_gcm_kw"/utf8>>,
                        line => 971,
                        value => _assert_fail,
                        start => 30890,
                        'end' => 30923,
                        pattern_start => 30901,
                        pattern_end => 30917})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(
            erlang:element(2, Header@1),
            Key
        ),
        fun(_) ->
            Aes_size@1 = case erlang:element(2, Header@1) of
                {aes_key_wrap, _, Aes_size} -> Aes_size;
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"do_encrypt_aes_gcm_kw"/utf8>>,
                                line => 977,
                                value => _assert_fail@1,
                                start => 31024,
                                'end' => 31076,
                                pattern_start => 31035,
                                pattern_end => 31063})
            end,
            gleam@result:'try'(
                gose@internal@key_encryption:get_octet_key(
                    Key,
                    gose:aes_key_size(Aes_size@1)
                ),
                fun(Kek) ->
                    Cek = gose@internal@content_encryption:generate_cek(
                        erlang:element(3, Header@1)
                    ),
                    Kw_iv = kryptos_ffi:random_bytes(12),
                    gleam@result:'try'(
                        gose@internal@key_encryption:wrap_aes_gcm(
                            Kek,
                            Cek,
                            Kw_iv,
                            Aes_size@1
                        ),
                        fun(_use0) ->
                            {Encrypted_cek, Kw_tag} = _use0,
                            Out_alg_fields = {aes_gcm_kw_resolved_fields,
                                {some, Kw_iv},
                                {some, Kw_tag}},
                            finalize_encryption(
                                Jwe,
                                Cek,
                                Encrypted_cek,
                                Out_alg_fields,
                                Plaintext
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1001).
-spec do_encrypt_chacha20_kw(
    jwe(unencrypted(), SWA, built()),
    gose:key(binary()),
    bitstring()
) -> {ok, jwe(encrypted(), SWA, built())} | {error, gose:gose_error()}.
do_encrypt_chacha20_kw(Jwe, Key, Plaintext) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"do_encrypt_chacha20_kw"/utf8>>,
                        line => 1006,
                        value => _assert_fail,
                        start => 31788,
                        'end' => 31821,
                        pattern_start => 31799,
                        pattern_end => 31815})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(
            erlang:element(2, Header@1),
            Key
        ),
        fun(_) ->
            Variant@1 = case erlang:element(2, Header@1) of
                {cha_cha20_key_wrap, Variant} -> Variant;
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"do_encrypt_chacha20_kw"/utf8>>,
                                line => 1012,
                                value => _assert_fail@1,
                                start => 31922,
                                'end' => 31975,
                                pattern_start => 31933,
                                pattern_end => 31962})
            end,
            gleam@result:'try'(
                gose@internal@key_encryption:get_octet_key(Key, 32),
                fun(Kek) ->
                    Cek = gose@internal@content_encryption:generate_cek(
                        erlang:element(3, Header@1)
                    ),
                    Nonce_size = gose:chacha20_kw_nonce_size(Variant@1),
                    Kw_iv = kryptos_ffi:random_bytes(Nonce_size),
                    gleam@result:'try'(
                        gose@internal@key_encryption:wrap_chacha20_by_variant(
                            Kek,
                            Cek,
                            Kw_iv,
                            Variant@1
                        ),
                        fun(_use0) ->
                            {Encrypted_cek, Kw_tag} = _use0,
                            Out_alg_fields = {cha_cha20_kw_resolved_fields,
                                {some, Kw_iv},
                                {some, Kw_tag}},
                            finalize_encryption(
                                Jwe,
                                Cek,
                                Encrypted_cek,
                                Out_alg_fields,
                                Plaintext
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1031).
-spec do_encrypt_aes_kw(
    jwe(unencrypted(), SWK, built()),
    gose:key(binary()),
    bitstring()
) -> {ok, jwe(encrypted(), SWK, built())} | {error, gose:gose_error()}.
do_encrypt_aes_kw(Jwe, Key, Plaintext) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"do_encrypt_aes_kw"/utf8>>,
                        line => 1036,
                        value => _assert_fail,
                        start => 32707,
                        'end' => 32740,
                        pattern_start => 32718,
                        pattern_end => 32734})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(
            erlang:element(2, Header@1),
            Key
        ),
        fun(_) ->
            Cek = gose@internal@content_encryption:generate_cek(
                erlang:element(3, Header@1)
            ),
            Aes_size@1 = case erlang:element(2, Header@1) of
                {aes_key_wrap, _, Aes_size} -> Aes_size;
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"do_encrypt_aes_kw"/utf8>>,
                                line => 1043,
                                value => _assert_fail@1,
                                start => 32897,
                                'end' => 32949,
                                pattern_start => 32908,
                                pattern_end => 32936})
            end,
            gleam@result:'try'(
                gose@internal@key_encryption:wrap_aes_kw(Key, Cek, Aes_size@1),
                fun(Encrypted_key) ->
                    finalize_encryption(
                        Jwe,
                        Cek,
                        Encrypted_key,
                        no_resolved_alg_fields,
                        Plaintext
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1053).
-spec do_encrypt_direct(
    jwe(unencrypted(), SWU, built()),
    gose:key(binary()),
    bitstring()
) -> {ok, jwe(encrypted(), SWU, built())} | {error, gose:gose_error()}.
do_encrypt_direct(Jwe, Key, Plaintext) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"do_encrypt_direct"/utf8>>,
                        line => 1058,
                        value => _assert_fail,
                        start => 33312,
                        'end' => 33345,
                        pattern_start => 33323,
                        pattern_end => 33339})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(
            erlang:element(2, Header@1),
            Key
        ),
        fun(_) ->
            gleam@result:'try'(
                gose@internal@key_encryption:unwrap_direct(
                    Key,
                    erlang:element(3, Header@1)
                ),
                fun(Cek) ->
                    finalize_encryption(
                        Jwe,
                        Cek,
                        <<>>,
                        no_resolved_alg_fields,
                        Plaintext
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1148).
-spec do_encrypt_ecdh(
    jwe(unencrypted(), SXL, built()),
    gose:key(binary()),
    bitstring()
) -> {ok, jwe(encrypted(), SXL, built())} | {error, gose:gose_error()}.
do_encrypt_ecdh(Jwe, Key, Plaintext) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"do_encrypt_ecdh"/utf8>>,
                        line => 1153,
                        value => _assert_fail,
                        start => 35718,
                        'end' => 35751,
                        pattern_start => 35729,
                        pattern_end => 35745})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(
            erlang:element(2, Header@1),
            Key
        ),
        fun(_) ->
            {Apu, Apv} = extract_ecdh_apu_apv(erlang:element(6, Jwe)),
            gleam@bool:guard(
                (gleam@option:is_some(Apu) andalso gleam@option:is_some(Apv))
                andalso (Apu =:= Apv),
                {error,
                    {invalid_state, <<"apu and apv must be distinct"/utf8>>}},
                fun() ->
                    Ecdh_alg@1 = case erlang:element(2, Header@1) of
                        {ecdh_es, Ecdh_alg} -> Ecdh_alg;
                        _assert_fail@1 ->
                            erlang:error(#{gleam_error => let_assert,
                                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                        file => <<?FILEPATH/utf8>>,
                                        module => <<"gose/jose/jwe"/utf8>>,
                                        function => <<"do_encrypt_ecdh"/utf8>>,
                                        line => 1166,
                                        value => _assert_fail@1,
                                        start => 36074,
                                        'end' => 36119,
                                        pattern_start => 36085,
                                        pattern_end => 36106})
                    end,
                    gleam@result:'try'(
                        wrap_ecdh_by_alg(
                            Ecdh_alg@1,
                            erlang:element(3, Header@1),
                            Key,
                            Apu,
                            Apv
                        ),
                        fun(_use0) ->
                            {Cek, Encrypted_key, Out_alg_fields} = _use0,
                            finalize_encryption(
                                Jwe,
                                Cek,
                                Encrypted_key,
                                Out_alg_fields,
                                Plaintext
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1191).
-spec do_encrypt_rsa(
    jwe(unencrypted(), SXY, built()),
    gose:key(binary()),
    bitstring()
) -> {ok, jwe(encrypted(), SXY, built())} | {error, gose:gose_error()}.
do_encrypt_rsa(Jwe, Key, Plaintext) ->
    Header@1 = case Jwe of
        {jwe, Header, _, _, _, _} -> Header;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"do_encrypt_rsa"/utf8>>,
                        line => 1196,
                        value => _assert_fail,
                        start => 36910,
                        'end' => 36943,
                        pattern_start => 36921,
                        pattern_end => 36937})
    end,
    gleam@result:'try'(
        gose@internal@key_helpers:validate_key_for_jwe_encryption(
            erlang:element(2, Header@1),
            Key
        ),
        fun(_) ->
            Cek = gose@internal@content_encryption:generate_cek(
                erlang:element(3, Header@1)
            ),
            Rsa_alg@1 = case erlang:element(2, Header@1) of
                {rsa_encryption, Rsa_alg} -> Rsa_alg;
                _assert_fail@1 ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"do_encrypt_rsa"/utf8>>,
                                line => 1203,
                                value => _assert_fail@1,
                                start => 37100,
                                'end' => 37151,
                                pattern_start => 37111,
                                pattern_end => 37138})
            end,
            gleam@result:'try'(
                wrap_rsa_by_alg(Rsa_alg@1, Key, Cek),
                fun(Encrypted_key) ->
                    finalize_encryption(
                        Jwe,
                        Cek,
                        Encrypted_key,
                        no_resolved_alg_fields,
                        Plaintext
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 623).
?DOC(
    " Encrypt a JWE using the appropriate key-based algorithm.\n"
    "\n"
    " Dispatches to the correct key encryption method based on the algorithm\n"
    " selected when the JWE was created. Supports direct, AES Key Wrap,\n"
    " AES-GCM Key Wrap, RSA, and ECDH-ES algorithms.\n"
    "\n"
    " For PBES2 password-based algorithms, use `encrypt_with_password` instead.\n"
    "\n"
    " JWK metadata (`use`, `key_ops`) is enforced when present:\n"
    " - Keys with `use=sig` are rejected\n"
    " - Keys with `key_ops` that don't include `encrypt` or `wrapKey` are rejected\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let key = gose.generate_enc_key(gose.AesGcm(gose.Aes256))\n"
    " let assert Ok(encrypted) = jwe.new_direct(gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.encrypt(key, <<\"hello\":utf8>>)\n"
    " ```\n"
).
-spec encrypt(jwe(unencrypted(), SQZ, built()), gose:key(binary()), bitstring()) -> {ok,
        jwe(encrypted(), SQZ, built())} |
    {error, gose:gose_error()}.
encrypt(Jwe, Key, Plaintext) ->
    case erlang:element(2, erlang:element(2, Jwe)) of
        direct ->
            do_encrypt_direct(Jwe, Key, Plaintext);

        {aes_key_wrap, aes_kw, _} ->
            do_encrypt_aes_kw(Jwe, Key, Plaintext);

        {aes_key_wrap, aes_gcm_kw, _} ->
            do_encrypt_aes_gcm_kw(Jwe, Key, Plaintext);

        {rsa_encryption, _} ->
            do_encrypt_rsa(Jwe, Key, Plaintext);

        {ecdh_es, _} ->
            do_encrypt_ecdh(Jwe, Key, Plaintext);

        {cha_cha20_key_wrap, _} ->
            do_encrypt_chacha20_kw(Jwe, Key, Plaintext);

        {pbes2, _} ->
            {error,
                {invalid_state,
                    <<"PBES2 algorithms require a password; use encrypt_with_password"/utf8>>}}
    end.

-file("src/gose/jose/jwe.gleam", 1654).
?DOC(
    " Serialize an encrypted JWE to compact format.\n"
    "\n"
    " Format: `{protected}.{encrypted_key}.{iv}.{ciphertext}.{tag}`\n"
    "\n"
    " Returns an error if AAD is set, since compact format does not support AAD.\n"
    " Use `serialize_json_flattened` or `serialize_json_general` for JWEs with AAD.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(token) = jwe.serialize_compact(encrypted)\n"
    " // -> \"eyJhbGci...ciphertext...tag\"\n"
    " ```\n"
).
-spec serialize_compact(jwe(encrypted(), any(), built())) -> {ok, binary()} |
    {error, gose:gose_error()}.
serialize_compact(Jwe) ->
    {
    Protected_b64@1,
        Encrypted_key@1,
        Iv@1,
        Ciphertext@1,
        Tag@1,
        Aad@1,
        Shared_unprotected@1,
        Per_recipient_unprotected@1} = case Jwe of
        {encrypted_jwe,
            _,
            Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            _,
            Aad,
            Shared_unprotected,
            _,
            Per_recipient_unprotected,
            _} -> {
        Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            Aad,
            Shared_unprotected,
            Per_recipient_unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"serialize_compact"/utf8>>,
                        line => 1657,
                        value => _assert_fail,
                        start => 50219,
                        'end' => 50404,
                        pattern_start => 50230,
                        pattern_end => 50398})
    end,
    gleam@bool:guard(
        gleam@option:is_some(Aad@1),
        {error,
            {invalid_state,
                <<"cannot serialize to compact format: AAD is only supported in JSON serialization"/utf8>>}},
        fun() ->
            gleam@bool:guard(
                not gleam@dict:is_empty(Shared_unprotected@1) orelse not gleam@dict:is_empty(
                    Per_recipient_unprotected@1
                ),
                {error,
                    {invalid_state,
                        <<"cannot serialize to compact format: unprotected headers are only supported in JSON serialization"/utf8>>}},
                fun() ->
                    Ek_b64 = gose@internal@utils:encode_base64_url(
                        Encrypted_key@1
                    ),
                    Iv_b64 = gose@internal@utils:encode_base64_url(Iv@1),
                    Ct_b64 = gose@internal@utils:encode_base64_url(Ciphertext@1),
                    Tag_b64 = gose@internal@utils:encode_base64_url(Tag@1),
                    {ok,
                        <<<<<<<<<<<<<<<<Protected_b64@1/binary, "."/utf8>>/binary,
                                                    Ek_b64/binary>>/binary,
                                                "."/utf8>>/binary,
                                            Iv_b64/binary>>/binary,
                                        "."/utf8>>/binary,
                                    Ct_b64/binary>>/binary,
                                "."/utf8>>/binary,
                            Tag_b64/binary>>}
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 1934).
-spec validate_apu_apv_distinct(
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, nil} | {error, gose:gose_error()}.
validate_apu_apv_distinct(Apu, Apv) ->
    case (gleam@option:is_some(Apu) andalso gleam@option:is_some(Apv)) andalso (Apu
    =:= Apv) of
        true ->
            {error, {parse_error, <<"apu and apv must be distinct"/utf8>>}};

        false ->
            {ok, nil}
    end.

-file("src/gose/jose/jwe.gleam", 2039).
-spec reject_disallowed_headers(binary(), list({boolean(), binary()})) -> {ok,
        nil} |
    {error, gose:gose_error()}.
reject_disallowed_headers(Alg_str, Checks) ->
    case Checks of
        [] ->
            {ok, nil};

        [{true, Name} | _] ->
            {error,
                {parse_error,
                    <<<<Name/binary, " header not allowed for "/utf8>>/binary,
                        Alg_str/binary>>}};

        [{false, _} | Rest] ->
            reject_disallowed_headers(Alg_str, Rest)
    end.

-file("src/gose/jose/jwe.gleam", 1944).
-spec build_parsed_alg_fields(
    gose:key_encryption_alg(),
    gleam@option:option(gose@internal@key_encryption:ephemeral_public_key()),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring()),
    gleam@option:option(integer()),
    gleam@option:option(bitstring()),
    gleam@option:option(bitstring())
) -> {ok, resolved_alg_fields()} | {error, gose:gose_error()}.
build_parsed_alg_fields(Alg, Epk, Apu, Apv, P2s, P2c, Kw_iv, Kw_tag) ->
    Alg_str = gose@jose:key_encryption_alg_to_string(Alg),
    case Alg of
        {cha_cha20_key_wrap, _} ->
            gleam@result:'try'(
                reject_disallowed_headers(
                    Alg_str,
                    [{gleam@option:is_some(Epk), <<"epk"/utf8>>},
                        {gleam@option:is_some(Apu), <<"apu"/utf8>>},
                        {gleam@option:is_some(Apv), <<"apv"/utf8>>},
                        {gleam@option:is_some(P2s), <<"p2s"/utf8>>},
                        {gleam@option:is_some(P2c), <<"p2c"/utf8>>}]
                ),
                fun(_) ->
                    {ok, {cha_cha20_kw_resolved_fields, Kw_iv, Kw_tag}}
                end
            );

        {ecdh_es, {ecdh_es_cha_cha20_kw, _}} ->
            gleam@result:'try'(
                reject_disallowed_headers(
                    Alg_str,
                    [{gleam@option:is_some(P2s), <<"p2s"/utf8>>},
                        {gleam@option:is_some(P2c), <<"p2c"/utf8>>}]
                ),
                fun(_) ->
                    gleam@result:'try'(
                        validate_apu_apv_distinct(Apu, Apv),
                        fun(_) ->
                            {ok,
                                {ecdh_es_cha_cha20_kw_resolved_fields,
                                    Epk,
                                    Apu,
                                    Apv,
                                    Kw_iv,
                                    Kw_tag}}
                        end
                    )
                end
            );

        {ecdh_es, _} ->
            gleam@result:'try'(
                reject_disallowed_headers(
                    Alg_str,
                    [{gleam@option:is_some(P2s), <<"p2s"/utf8>>},
                        {gleam@option:is_some(P2c), <<"p2c"/utf8>>}]
                ),
                fun(_) ->
                    gleam@result:'try'(
                        validate_apu_apv_distinct(Apu, Apv),
                        fun(_) ->
                            {ok, {ecdh_es_resolved_fields, Epk, Apu, Apv}}
                        end
                    )
                end
            );

        {pbes2, _} ->
            gleam@result:'try'(
                reject_disallowed_headers(
                    Alg_str,
                    [{gleam@option:is_some(Epk), <<"epk"/utf8>>},
                        {gleam@option:is_some(Apu), <<"apu"/utf8>>},
                        {gleam@option:is_some(Apv), <<"apv"/utf8>>}]
                ),
                fun(_) ->
                    gleam@result:'try'(
                        gleam@option:to_result(
                            P2s,
                            {parse_error,
                                <<"missing p2s header for "/utf8,
                                    Alg_str/binary>>}
                        ),
                        fun(P2s@1) ->
                            gleam@bool:guard(
                                erlang:byte_size(P2s@1) < 8,
                                {error,
                                    {parse_error,
                                        <<"p2s must be at least 8 bytes"/utf8>>}},
                                fun() ->
                                    gleam@result:'try'(
                                        gleam@option:to_result(
                                            P2c,
                                            {parse_error,
                                                <<"missing p2c header for "/utf8,
                                                    Alg_str/binary>>}
                                        ),
                                        fun(P2c@1) ->
                                            {ok,
                                                {pbes2_resolved_fields,
                                                    P2s@1,
                                                    P2c@1}}
                                        end
                                    )
                                end
                            )
                        end
                    )
                end
            );

        {aes_key_wrap, aes_gcm_kw, _} ->
            gleam@result:'try'(
                reject_disallowed_headers(
                    Alg_str,
                    [{gleam@option:is_some(Epk), <<"epk"/utf8>>},
                        {gleam@option:is_some(Apu), <<"apu"/utf8>>},
                        {gleam@option:is_some(Apv), <<"apv"/utf8>>},
                        {gleam@option:is_some(P2s), <<"p2s"/utf8>>},
                        {gleam@option:is_some(P2c), <<"p2c"/utf8>>}]
                ),
                fun(_) -> {ok, {aes_gcm_kw_resolved_fields, Kw_iv, Kw_tag}} end
            );

        direct ->
            gleam@result:'try'(
                reject_disallowed_headers(
                    Alg_str,
                    [{gleam@option:is_some(Epk), <<"epk"/utf8>>},
                        {gleam@option:is_some(Apu), <<"apu"/utf8>>},
                        {gleam@option:is_some(Apv), <<"apv"/utf8>>},
                        {gleam@option:is_some(P2s), <<"p2s"/utf8>>},
                        {gleam@option:is_some(P2c), <<"p2c"/utf8>>},
                        {gleam@option:is_some(Kw_iv), <<"iv"/utf8>>},
                        {gleam@option:is_some(Kw_tag), <<"tag"/utf8>>}]
                ),
                fun(_) -> {ok, no_resolved_alg_fields} end
            );

        {aes_key_wrap, aes_kw, _} ->
            gleam@result:'try'(
                reject_disallowed_headers(
                    Alg_str,
                    [{gleam@option:is_some(Epk), <<"epk"/utf8>>},
                        {gleam@option:is_some(Apu), <<"apu"/utf8>>},
                        {gleam@option:is_some(Apv), <<"apv"/utf8>>},
                        {gleam@option:is_some(P2s), <<"p2s"/utf8>>},
                        {gleam@option:is_some(P2c), <<"p2c"/utf8>>},
                        {gleam@option:is_some(Kw_iv), <<"iv"/utf8>>},
                        {gleam@option:is_some(Kw_tag), <<"tag"/utf8>>}]
                ),
                fun(_) -> {ok, no_resolved_alg_fields} end
            );

        {rsa_encryption, _} ->
            gleam@result:'try'(
                reject_disallowed_headers(
                    Alg_str,
                    [{gleam@option:is_some(Epk), <<"epk"/utf8>>},
                        {gleam@option:is_some(Apu), <<"apu"/utf8>>},
                        {gleam@option:is_some(Apv), <<"apv"/utf8>>},
                        {gleam@option:is_some(P2s), <<"p2s"/utf8>>},
                        {gleam@option:is_some(P2c), <<"p2c"/utf8>>},
                        {gleam@option:is_some(Kw_iv), <<"iv"/utf8>>},
                        {gleam@option:is_some(Kw_tag), <<"tag"/utf8>>}]
                ),
                fun(_) -> {ok, no_resolved_alg_fields} end
            )
    end.

-file("src/gose/jose/jwe.gleam", 2051).
-spec validate_encrypted_key_for_algorithm(
    gose:key_encryption_alg(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
validate_encrypted_key_for_algorithm(Alg, Encrypted_key) ->
    Is_direct = case Alg of
        direct ->
            true;

        {ecdh_es, ecdh_es_direct} ->
            true;

        _ ->
            false
    end,
    Key_size = erlang:byte_size(Encrypted_key),
    case {Is_direct, Key_size} of
        {true, 0} ->
            {ok, nil};

        {true, _} ->
            {error,
                {parse_error,
                    <<"encrypted_key must be empty for "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}};

        {false, 0} ->
            {error,
                {parse_error,
                    <<"encrypted_key required for "/utf8,
                        (gose@jose:key_encryption_alg_to_string(Alg))/binary>>}};

        {false, _} ->
            {ok, nil}
    end.

-file("src/gose/jose/jwe.gleam", 2113).
-spec present_field_names(list({boolean(), binary()})) -> list(binary()).
present_field_names(Fields) ->
    gleam@list:filter_map(Fields, fun(Field) -> case Field of
                {true, Name} ->
                    {ok, Name};

                {false, _} ->
                    {error, nil}
            end end).

-file("src/gose/jose/jwe.gleam", 2124).
?DOC(
    " Validate that protected and unprotected headers have disjoint parameter names.\n"
    " Per RFC 7516, the same parameter MUST NOT appear in both protected and unprotected.\n"
).
-spec validate_jwe_header_disjointness(
    jwe_header(),
    resolved_alg_fields(),
    list(binary()),
    list(binary())
) -> {ok, nil} | {error, gose:gose_error()}.
validate_jwe_header_disjointness(
    Header,
    Alg_fields,
    Shared_unprotected_names,
    Per_recipient_unprotected_names
) ->
    Alg_specific_names = case Alg_fields of
        {ecdh_es_resolved_fields, Epk, Apu, Apv} ->
            present_field_names(
                [{gleam@option:is_some(Epk), <<"epk"/utf8>>},
                    {gleam@option:is_some(Apu), <<"apu"/utf8>>},
                    {gleam@option:is_some(Apv), <<"apv"/utf8>>}]
            );

        {pbes2_resolved_fields, _, _} ->
            [<<"p2s"/utf8>>, <<"p2c"/utf8>>];

        {aes_gcm_kw_resolved_fields, Kw_iv, Kw_tag} ->
            present_field_names(
                [{gleam@option:is_some(Kw_iv), <<"iv"/utf8>>},
                    {gleam@option:is_some(Kw_tag), <<"tag"/utf8>>}]
            );

        {cha_cha20_kw_resolved_fields, Kw_iv, Kw_tag} ->
            present_field_names(
                [{gleam@option:is_some(Kw_iv), <<"iv"/utf8>>},
                    {gleam@option:is_some(Kw_tag), <<"tag"/utf8>>}]
            );

        {ecdh_es_cha_cha20_kw_resolved_fields,
            Epk@1,
            Apu@1,
            Apv@1,
            Kw_iv@1,
            Kw_tag@1} ->
            present_field_names(
                [{gleam@option:is_some(Epk@1), <<"epk"/utf8>>},
                    {gleam@option:is_some(Apu@1), <<"apu"/utf8>>},
                    {gleam@option:is_some(Apv@1), <<"apv"/utf8>>},
                    {gleam@option:is_some(Kw_iv@1), <<"iv"/utf8>>},
                    {gleam@option:is_some(Kw_tag@1), <<"tag"/utf8>>}]
            );

        no_resolved_alg_fields ->
            []
    end,
    Protected_names = lists:append(
        [[<<"alg"/utf8>>, <<"enc"/utf8>>],
            present_field_names(
                [{gleam@option:is_some(erlang:element(4, Header)),
                        <<"kid"/utf8>>},
                    {gleam@option:is_some(erlang:element(5, Header)),
                        <<"typ"/utf8>>},
                    {gleam@option:is_some(erlang:element(6, Header)),
                        <<"cty"/utf8>>}]
            ),
            Alg_specific_names]
    ),
    Protected_set = gleam@set:from_list(Protected_names),
    Shared_names = Shared_unprotected_names,
    Per_recipient_names = Per_recipient_unprotected_names,
    Shared_overlap = gleam@list:filter(
        Shared_names,
        fun(_capture) -> gleam@set:contains(Protected_set, _capture) end
    ),
    gleam@bool:guard(
        not gleam@list:is_empty(Shared_overlap),
        {error,
            {parse_error,
                <<"header parameter appears in both protected and shared unprotected: "/utf8,
                    (gleam@string:join(Shared_overlap, <<", "/utf8>>))/binary>>}},
        fun() ->
            Per_recipient_overlap = gleam@list:filter(
                Per_recipient_names,
                fun(_capture@1) ->
                    gleam@set:contains(Protected_set, _capture@1)
                end
            ),
            gleam@bool:guard(
                not gleam@list:is_empty(Per_recipient_overlap),
                {error,
                    {parse_error,
                        <<"header parameter appears in both protected and per-recipient unprotected: "/utf8,
                            (gleam@string:join(
                                Per_recipient_overlap,
                                <<", "/utf8>>
                            ))/binary>>}},
                fun() ->
                    Shared_set = gleam@set:from_list(Shared_names),
                    Shared_per_recipient_overlap = gleam@list:filter(
                        Per_recipient_names,
                        fun(_capture@2) ->
                            gleam@set:contains(Shared_set, _capture@2)
                        end
                    ),
                    gleam@bool:guard(
                        not gleam@list:is_empty(Shared_per_recipient_overlap),
                        {error,
                            {parse_error,
                                <<"header parameter appears in both shared and per-recipient unprotected: "/utf8,
                                    (gleam@string:join(
                                        Shared_per_recipient_overlap,
                                        <<", "/utf8>>
                                    ))/binary>>}},
                        fun() -> {ok, nil} end
                    )
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 2203).
-spec parse_optional_epk(
    gleam@option:option({binary(),
        binary(),
        binary(),
        gleam@option:option(binary())})
) -> {ok,
        gleam@option:option(gose@internal@key_encryption:ephemeral_public_key())} |
    {error, gose:gose_error()}.
parse_optional_epk(Epk_raw) ->
    case Epk_raw of
        none ->
            {ok, none};

        {some, {Kty, Crv, X_b64, Y_opt}} ->
            gleam@result:'try'(
                begin
                    _pipe = gleam@bit_array:base64_url_decode(X_b64),
                    gleam@result:replace_error(
                        _pipe,
                        {parse_error, <<"invalid epk x base64"/utf8>>}
                    )
                end,
                fun(X) -> case Kty of
                        <<"EC"/utf8>> ->
                            gleam@result:'try'(
                                gleam@option:to_result(
                                    Y_opt,
                                    {parse_error,
                                        <<"EC epk requires y coordinate"/utf8>>}
                                ),
                                fun(Y_b64) ->
                                    gleam@result:'try'(
                                        begin
                                            _pipe@1 = gleam@bit_array:base64_url_decode(
                                                Y_b64
                                            ),
                                            gleam@result:replace_error(
                                                _pipe@1,
                                                {parse_error,
                                                    <<"invalid epk y base64"/utf8>>}
                                            )
                                        end,
                                        fun(Y) ->
                                            gleam@result:'try'(
                                                gose@internal@utils:ec_curve_from_string(
                                                    Crv
                                                ),
                                                fun(Curve) ->
                                                    {ok,
                                                        {some,
                                                            {ec_ephemeral_key,
                                                                Curve,
                                                                X,
                                                                Y}}}
                                                end
                                            )
                                        end
                                    )
                                end
                            );

                        <<"OKP"/utf8>> ->
                            gleam@result:'try'(
                                gose@internal@utils:xdh_curve_from_string(Crv),
                                fun(Curve@1) ->
                                    {ok,
                                        {some, {xdh_ephemeral_key, Curve@1, X}}}
                                end
                            );

                        _ ->
                            {error,
                                {parse_error,
                                    <<"unsupported epk kty: "/utf8, Kty/binary>>}}
                    end end
            )
    end.

-file("src/gose/jose/jwe.gleam", 2236).
-spec parse_optional_base64(gleam@option:option(binary()), binary()) -> {ok,
        gleam@option:option(bitstring())} |
    {error, gose:gose_error()}.
parse_optional_base64(Opt, Name) ->
    case Opt of
        none ->
            {ok, none};

        {some, B64} ->
            gleam@result:'try'(
                begin
                    _pipe = gleam@bit_array:base64_url_decode(B64),
                    gleam@result:replace_error(
                        _pipe,
                        {parse_error,
                            <<<<"invalid "/utf8, Name/binary>>/binary,
                                " base64"/utf8>>}
                    )
                end,
                fun(Decoded) -> {ok, {some, Decoded}} end
            )
    end.

-file("src/gose/jose/jwe.gleam", 2360).
-spec append_optional_jwe_fields(
    list({binary(), gleam@json:json()}),
    gleam@dict:dict(binary(), gleam@json:json()),
    gleam@option:option(bitstring())
) -> list({binary(), gleam@json:json()}).
append_optional_jwe_fields(Fields, Shared_unprotected, Aad) ->
    Fields@1 = case gleam@dict:is_empty(Shared_unprotected) of
        true ->
            Fields;

        false ->
            [{<<"unprotected"/utf8>>,
                    gleam@json:object(maps:to_list(Shared_unprotected))} |
                Fields]
    end,
    case Aad of
        {some, Aad@1} ->
            Aad_b64 = gose@internal@utils:encode_base64_url(Aad@1),
            [{<<"aad"/utf8>>, gleam@json:string(Aad_b64)} | Fields@1];

        none ->
            Fields@1
    end.

-file("src/gose/jose/jwe.gleam", 2261).
?DOC(
    " Serialize an encrypted JWE to JSON Flattened format.\n"
    "\n"
    " Format: `{\"protected\":\"...\",\"encrypted_key\":\"...\",\"iv\":\"...\",\"ciphertext\":\"...\",\"tag\":\"...\"}`\n"
    "\n"
    " For Direct or ECDH-ES algorithms, the encrypted_key field is omitted.\n"
    " When AAD is present, includes the `aad` field.\n"
    " When unprotected headers are present, includes the `unprotected` and/or `header` fields.\n"
    "\n"
    " For multiple recipients, use `gose/jose/jwe_multi`.\n"
).
-spec serialize_json_flattened(jwe(encrypted(), any(), built())) -> gleam@json:json().
serialize_json_flattened(Jwe) ->
    {
    Protected_b64@1,
        Encrypted_key@1,
        Iv@1,
        Ciphertext@1,
        Tag@1,
        Aad@1,
        Shared_unprotected@1,
        Per_recipient_unprotected@1} = case Jwe of
        {encrypted_jwe,
            _,
            Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            _,
            Aad,
            Shared_unprotected,
            _,
            Per_recipient_unprotected,
            _} -> {
        Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            Aad,
            Shared_unprotected,
            Per_recipient_unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"serialize_json_flattened"/utf8>>,
                        line => 2262,
                        value => _assert_fail,
                        start => 67858,
                        'end' => 68043,
                        pattern_start => 67869,
                        pattern_end => 68037})
    end,
    Ek_b64 = gose@internal@utils:encode_base64_url(Encrypted_key@1),
    Iv_b64 = gose@internal@utils:encode_base64_url(Iv@1),
    Ct_b64 = gose@internal@utils:encode_base64_url(Ciphertext@1),
    Tag_b64 = gose@internal@utils:encode_base64_url(Tag@1),
    Base_fields = case erlang:byte_size(Encrypted_key@1) of
        0 ->
            [{<<"protected"/utf8>>, gleam@json:string(Protected_b64@1)},
                {<<"iv"/utf8>>, gleam@json:string(Iv_b64)},
                {<<"ciphertext"/utf8>>, gleam@json:string(Ct_b64)},
                {<<"tag"/utf8>>, gleam@json:string(Tag_b64)}];

        _ ->
            [{<<"protected"/utf8>>, gleam@json:string(Protected_b64@1)},
                {<<"encrypted_key"/utf8>>, gleam@json:string(Ek_b64)},
                {<<"iv"/utf8>>, gleam@json:string(Iv_b64)},
                {<<"ciphertext"/utf8>>, gleam@json:string(Ct_b64)},
                {<<"tag"/utf8>>, gleam@json:string(Tag_b64)}]
    end,
    Fields_with_header = case gleam@dict:is_empty(Per_recipient_unprotected@1) of
        true ->
            Base_fields;

        false ->
            [{<<"header"/utf8>>,
                    gleam@json:object(maps:to_list(Per_recipient_unprotected@1))} |
                Base_fields]
    end,
    _pipe = Fields_with_header,
    _pipe@1 = append_optional_jwe_fields(_pipe, Shared_unprotected@1, Aad@1),
    gleam@json:object(_pipe@1).

-file("src/gose/jose/jwe.gleam", 2318).
?DOC(
    " Serialize an encrypted JWE to JSON General format.\n"
    "\n"
    " Format: `{\"protected\":\"...\",\"recipients\":[{\"encrypted_key\":\"...\"}],\"iv\":\"...\",\"ciphertext\":\"...\",\"tag\":\"...\"}`\n"
    "\n"
    " For Direct or ECDH-ES algorithms, the encrypted_key field is omitted.\n"
    " When AAD is present, includes the `aad` field.\n"
    " When unprotected headers are present, includes the `unprotected` field and/or\n"
    " the `header` field in the recipient object.\n"
    "\n"
    " For multiple recipients, use `gose/jose/jwe_multi`.\n"
).
-spec serialize_json_general(jwe(encrypted(), any(), built())) -> gleam@json:json().
serialize_json_general(Jwe) ->
    {
    Protected_b64@1,
        Encrypted_key@1,
        Iv@1,
        Ciphertext@1,
        Tag@1,
        Aad@1,
        Shared_unprotected@1,
        Per_recipient_unprotected@1} = case Jwe of
        {encrypted_jwe,
            _,
            Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            _,
            Aad,
            Shared_unprotected,
            _,
            Per_recipient_unprotected,
            _} -> {
        Protected_b64,
            Encrypted_key,
            Iv,
            Ciphertext,
            Tag,
            Aad,
            Shared_unprotected,
            Per_recipient_unprotected};
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/jose/jwe"/utf8>>,
                        function => <<"serialize_json_general"/utf8>>,
                        line => 2319,
                        value => _assert_fail,
                        start => 69615,
                        'end' => 69800,
                        pattern_start => 69626,
                        pattern_end => 69794})
    end,
    Ek_b64 = gose@internal@utils:encode_base64_url(Encrypted_key@1),
    Iv_b64 = gose@internal@utils:encode_base64_url(Iv@1),
    Ct_b64 = gose@internal@utils:encode_base64_url(Ciphertext@1),
    Tag_b64 = gose@internal@utils:encode_base64_url(Tag@1),
    Recipient_fields = case erlang:byte_size(Encrypted_key@1) of
        0 ->
            [];

        _ ->
            [{<<"encrypted_key"/utf8>>, gleam@json:string(Ek_b64)}]
    end,
    Recipient_with_header = case gleam@dict:is_empty(
        Per_recipient_unprotected@1
    ) of
        true ->
            Recipient_fields;

        false ->
            [{<<"header"/utf8>>,
                    gleam@json:object(maps:to_list(Per_recipient_unprotected@1))} |
                Recipient_fields]
    end,
    Recipient = gleam@json:object(Recipient_with_header),
    _pipe = [{<<"protected"/utf8>>, gleam@json:string(Protected_b64@1)},
        {<<"iv"/utf8>>, gleam@json:string(Iv_b64)},
        {<<"ciphertext"/utf8>>, gleam@json:string(Ct_b64)},
        {<<"tag"/utf8>>, gleam@json:string(Tag_b64)},
        {<<"recipients"/utf8>>, gleam@json:preprocessed_array([Recipient])}],
    _pipe@1 = append_optional_jwe_fields(_pipe, Shared_unprotected@1, Aad@1),
    gleam@json:object(_pipe@1).

-file("src/gose/jose/jwe.gleam", 2396).
-spec decode_base64_url_or_empty(gleam@option:option(binary()), binary()) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
decode_base64_url_or_empty(Opt, Name) ->
    case Opt of
        {some, B64} ->
            gose@internal@utils:decode_base64_url(B64, Name);

        none ->
            {ok, <<>>}
    end.

-file("src/gose/jose/jwe.gleam", 2406).
-spec decode_optional_base64_url(gleam@option:option(binary()), binary()) -> {ok,
        gleam@option:option(bitstring())} |
    {error, gose:gose_error()}.
decode_optional_base64_url(Opt, Name) ->
    case Opt of
        {some, B64} ->
            _pipe = gose@internal@utils:decode_base64_url(B64, Name),
            gleam@result:map(_pipe, fun(Field@0) -> {some, Field@0} end);

        none ->
            {ok, none}
    end.

-file("src/gose/jose/jwe.gleam", 2650).
-spec apply_optional(
    jwe(unencrypted(), TEN, built()),
    gleam@option:option(TER),
    fun((jwe(unencrypted(), TEN, built()), TER) -> jwe(unencrypted(), TEN, built()))
) -> jwe(unencrypted(), TEN, built()).
apply_optional(Jwe, Value, Setter) ->
    case Value of
        {some, V} ->
            Setter(Jwe, V);

        none ->
            Jwe
    end.

-file("src/gose/jose/jwe.gleam", 2662).
-spec apply_headers(
    jwe(unencrypted(), TFC, built()),
    gleam@option:option(binary()),
    gleam@option:option(binary()),
    gleam@option:option(binary())
) -> jwe(unencrypted(), TFC, built()).
apply_headers(Jwe, Kid, Typ, Cty) ->
    _pipe = Jwe,
    _pipe@1 = apply_optional(_pipe, Kid, fun with_kid/2),
    _pipe@2 = apply_optional(_pipe@1, Typ, fun with_typ/2),
    apply_optional(_pipe@2, Cty, fun with_cty/2).

-file("src/gose/jose/jwe.gleam", 2674).
-spec encrypt_and_serialize(
    jwe(unencrypted(), any(), built()),
    gose:key_encryption_alg(),
    gose:key(binary()),
    bitstring()
) -> {ok, {binary(), gose:key_encryption_alg()}} | {error, gose:gose_error()}.
encrypt_and_serialize(Unencrypted, Alg, Key, Plaintext) ->
    gleam@result:'try'(
        encrypt(Unencrypted, Key, Plaintext),
        fun(Encrypted) ->
            gleam@result:'try'(
                serialize_compact(Encrypted),
                fun(Token) -> {ok, {Token, Alg}} end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 2686).
?DOC(false).
-spec encrypt_to_compact(
    gose:key_encryption_alg(),
    gose:content_alg(),
    bitstring(),
    gose:key(binary()),
    gleam@option:option(binary()),
    gleam@option:option(binary()),
    gleam@option:option(binary())
) -> {ok, {binary(), gose:key_encryption_alg()}} | {error, gose:gose_error()}.
encrypt_to_compact(Alg, Enc, Plaintext, Key, Kid, Typ, Cty) ->
    case Alg of
        direct ->
            encrypt_and_serialize(
                apply_headers(new_direct(Enc), Kid, Typ, Cty),
                Alg,
                Key,
                Plaintext
            );

        {aes_key_wrap, aes_kw, Size} ->
            encrypt_and_serialize(
                apply_headers(new_aes_kw(Size, Enc), Kid, Typ, Cty),
                Alg,
                Key,
                Plaintext
            );

        {aes_key_wrap, aes_gcm_kw, Size@1} ->
            encrypt_and_serialize(
                apply_headers(new_aes_gcm_kw(Size@1, Enc), Kid, Typ, Cty),
                Alg,
                Key,
                Plaintext
            );

        {rsa_encryption, Rsa_alg} ->
            encrypt_and_serialize(
                apply_headers(new_rsa(Rsa_alg, Enc), Kid, Typ, Cty),
                Alg,
                Key,
                Plaintext
            );

        {ecdh_es, Ecdh_alg} ->
            encrypt_and_serialize(
                apply_headers(new_ecdh_es(Ecdh_alg, Enc), Kid, Typ, Cty),
                Alg,
                Key,
                Plaintext
            );

        {cha_cha20_key_wrap, Variant} ->
            encrypt_and_serialize(
                apply_headers(new_chacha20_kw(Variant, Enc), Kid, Typ, Cty),
                Alg,
                Key,
                Plaintext
            );

        {pbes2, _} ->
            {error,
                {invalid_state,
                    <<"PBES2 algorithms require a password, not a key"/utf8>>}}
    end.

-file("src/gose/jose/jwe.gleam", 587).
?DOC(
    " Set the PBES2 iteration count (p2c) for password-based encryption.\n"
    "\n"
    " This allows customizing the PBKDF2 iteration count. Production should use\n"
    " a value tuned for the specific use case.\n"
    "\n"
    " Returns an error if iterations is less than 1,000 or greater than\n"
    " 10,000,000.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(jwe) =\n"
    "   jwe.new_pbes2(gose.Pbes2Sha256Aes128Kw, gose.AesGcm(gose.Aes128))\n"
    "   |> jwe.with_p2c(100_000)\n"
    " ```\n"
).
-spec with_p2c(jwe(unencrypted(), pbes2(), built()), integer()) -> {ok,
        jwe(unencrypted(), pbes2(), built())} |
    {error, gose:gose_error()}.
with_p2c(Jwe, Iterations) ->
    gleam@bool:guard(
        (Iterations < 1000) orelse (Iterations > 10000000),
        {error,
            {invalid_state,
                <<<<<<"p2c must be >= "/utf8,
                            (erlang:integer_to_binary(1000))/binary>>/binary,
                        " and <= "/utf8>>/binary,
                    (erlang:integer_to_binary(10000000))/binary>>}},
        fun() ->
            case Jwe of
                {jwe, _, _, _, _, {pbes2_builder_fields, _}} -> nil;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"with_p2c"/utf8>>,
                                line => 600,
                                value => _assert_fail,
                                start => 18560,
                                'end' => 18620,
                                pattern_start => 18571,
                                pattern_end => 18614})
            end,
            {ok,
                {jwe,
                    erlang:element(2, Jwe),
                    erlang:element(3, Jwe),
                    erlang:element(4, Jwe),
                    erlang:element(5, Jwe),
                    {pbes2_builder_fields, {some, Iterations}}}}
        end
    ).

-file("src/gose/jose/jwe.gleam", 1922).
-spec validate_crit(gleam@option:option(list(binary()))) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_crit(Crit) ->
    case Crit of
        none ->
            {ok, nil};

        {some, Extensions} ->
            gose@internal@utils:validate_crit_headers(
                Extensions,
                [<<"alg"/utf8>>,
                    <<"enc"/utf8>>,
                    <<"zip"/utf8>>,
                    <<"jku"/utf8>>,
                    <<"jwk"/utf8>>,
                    <<"kid"/utf8>>,
                    <<"x5u"/utf8>>,
                    <<"x5c"/utf8>>,
                    <<"x5t"/utf8>>,
                    <<"x5t#S256"/utf8>>,
                    <<"typ"/utf8>>,
                    <<"cty"/utf8>>,
                    <<"apu"/utf8>>,
                    <<"apv"/utf8>>,
                    <<"epk"/utf8>>,
                    <<"iv"/utf8>>,
                    <<"tag"/utf8>>,
                    <<"p2s"/utf8>>,
                    <<"p2c"/utf8>>,
                    <<"crit"/utf8>>],
                []
            )
    end.

-file("src/gose/jose/jwe.gleam", 1762).
-spec parse_header_json(bitstring()) -> {ok, parsed_header()} |
    {error, gose:gose_error()}.
parse_header_json(Json_bits) ->
    Epk_decoder = begin
        gleam@dynamic@decode:field(
            <<"kty"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Kty) ->
                gleam@dynamic@decode:field(
                    <<"crv"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Crv) ->
                        gleam@dynamic@decode:field(
                            <<"x"/utf8>>,
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            fun(X) ->
                                gleam@dynamic@decode:optional_field(
                                    <<"y"/utf8>>,
                                    none,
                                    gleam@dynamic@decode:optional(
                                        {decoder,
                                            fun gleam@dynamic@decode:decode_string/1}
                                    ),
                                    fun(Y) ->
                                        gleam@dynamic@decode:success(
                                            {Kty, Crv, X, Y}
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
    Decoder = begin
        gleam@dynamic@decode:field(
            <<"alg"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Alg) ->
                gleam@dynamic@decode:field(
                    <<"enc"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Enc) ->
                        gleam@dynamic@decode:optional_field(
                            <<"kid"/utf8>>,
                            none,
                            gleam@dynamic@decode:optional(
                                {decoder,
                                    fun gleam@dynamic@decode:decode_string/1}
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
                                                    <<"epk"/utf8>>,
                                                    none,
                                                    gleam@dynamic@decode:optional(
                                                        Epk_decoder
                                                    ),
                                                    fun(Epk_raw) ->
                                                        gleam@dynamic@decode:optional_field(
                                                            <<"apu"/utf8>>,
                                                            none,
                                                            gleam@dynamic@decode:optional(
                                                                {decoder,
                                                                    fun gleam@dynamic@decode:decode_string/1}
                                                            ),
                                                            fun(Apu) ->
                                                                gleam@dynamic@decode:optional_field(
                                                                    <<"apv"/utf8>>,
                                                                    none,
                                                                    gleam@dynamic@decode:optional(
                                                                        {decoder,
                                                                            fun gleam@dynamic@decode:decode_string/1}
                                                                    ),
                                                                    fun(Apv) ->
                                                                        gleam@dynamic@decode:optional_field(
                                                                            <<"p2s"/utf8>>,
                                                                            none,
                                                                            gleam@dynamic@decode:optional(
                                                                                {decoder,
                                                                                    fun gleam@dynamic@decode:decode_string/1}
                                                                            ),
                                                                            fun(
                                                                                P2s
                                                                            ) ->
                                                                                gleam@dynamic@decode:optional_field(
                                                                                    <<"p2c"/utf8>>,
                                                                                    none,
                                                                                    gleam@dynamic@decode:optional(
                                                                                        {decoder,
                                                                                            fun gleam@dynamic@decode:decode_int/1}
                                                                                    ),
                                                                                    fun(
                                                                                        P2c
                                                                                    ) ->
                                                                                        gleam@dynamic@decode:optional_field(
                                                                                            <<"iv"/utf8>>,
                                                                                            none,
                                                                                            gleam@dynamic@decode:optional(
                                                                                                {decoder,
                                                                                                    fun gleam@dynamic@decode:decode_string/1}
                                                                                            ),
                                                                                            fun(
                                                                                                Kw_iv
                                                                                            ) ->
                                                                                                gleam@dynamic@decode:optional_field(
                                                                                                    <<"tag"/utf8>>,
                                                                                                    none,
                                                                                                    gleam@dynamic@decode:optional(
                                                                                                        {decoder,
                                                                                                            fun gleam@dynamic@decode:decode_string/1}
                                                                                                    ),
                                                                                                    fun(
                                                                                                        Kw_tag
                                                                                                    ) ->
                                                                                                        gleam@dynamic@decode:optional_field(
                                                                                                            <<"crit"/utf8>>,
                                                                                                            none,
                                                                                                            gleam@dynamic@decode:optional(
                                                                                                                gleam@dynamic@decode:list(
                                                                                                                    {decoder,
                                                                                                                        fun gleam@dynamic@decode:decode_string/1}
                                                                                                                )
                                                                                                            ),
                                                                                                            fun(
                                                                                                                Crit
                                                                                                            ) ->
                                                                                                                gleam@dynamic@decode:optional_field(
                                                                                                                    <<"zip"/utf8>>,
                                                                                                                    none,
                                                                                                                    gleam@dynamic@decode:optional(
                                                                                                                        {decoder,
                                                                                                                            fun gleam@dynamic@decode:decode_string/1}
                                                                                                                    ),
                                                                                                                    fun(
                                                                                                                        Zip
                                                                                                                    ) ->
                                                                                                                        gleam@dynamic@decode:success(
                                                                                                                            {Alg,
                                                                                                                                Enc,
                                                                                                                                Kid,
                                                                                                                                Typ,
                                                                                                                                Cty,
                                                                                                                                Epk_raw,
                                                                                                                                Apu,
                                                                                                                                Apv,
                                                                                                                                P2s,
                                                                                                                                P2c,
                                                                                                                                Kw_iv,
                                                                                                                                Kw_tag,
                                                                                                                                Crit,
                                                                                                                                Zip}
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
                )
            end
        )
    end,
    gleam@result:'try'(
        begin
            _pipe = gleam@json:parse_bits(Json_bits, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"invalid header JSON"/utf8>>}
            )
        end,
        fun(_use0) ->
            {Alg_str,
                Enc_str,
                Kid@1,
                Typ@1,
                Cty@1,
                Epk_raw@1,
                Apu_b64,
                Apv_b64,
                P2s_b64,
                P2c@1,
                Kw_iv_b64,
                Kw_tag_b64,
                Crit@1,
                Zip@1} = _use0,
            gleam@result:'try'(
                validate_crit(Crit@1),
                fun(_) ->
                    gleam@bool:guard(
                        gleam@option:is_some(Zip@1),
                        {error,
                            {parse_error, <<"unsupported header: zip"/utf8>>}},
                        fun() ->
                            P2c_out_of_range = case P2c@1 of
                                {some, Iterations} ->
                                    (Iterations < 1000) orelse (Iterations > 10000000);

                                none ->
                                    false
                            end,
                            gleam@bool:guard(
                                P2c_out_of_range,
                                {error,
                                    {parse_error,
                                        <<<<<<"p2c must be >= "/utf8,
                                                    (erlang:integer_to_binary(
                                                        1000
                                                    ))/binary>>/binary,
                                                " and <= "/utf8>>/binary,
                                            (erlang:integer_to_binary(10000000))/binary>>}},
                                fun() ->
                                    gleam@result:'try'(
                                        gose@jose:key_encryption_alg_from_string(
                                            Alg_str
                                        ),
                                        fun(Alg@1) ->
                                            gleam@result:'try'(
                                                gose@jose:content_alg_from_string(
                                                    Enc_str
                                                ),
                                                fun(Enc@1) ->
                                                    gleam@result:'try'(
                                                        parse_optional_epk(
                                                            Epk_raw@1
                                                        ),
                                                        fun(Epk) ->
                                                            gleam@result:'try'(
                                                                parse_optional_base64(
                                                                    Apu_b64,
                                                                    <<"apu"/utf8>>
                                                                ),
                                                                fun(Apu@1) ->
                                                                    gleam@result:'try'(
                                                                        parse_optional_base64(
                                                                            Apv_b64,
                                                                            <<"apv"/utf8>>
                                                                        ),
                                                                        fun(
                                                                            Apv@1
                                                                        ) ->
                                                                            gleam@result:'try'(
                                                                                parse_optional_base64(
                                                                                    P2s_b64,
                                                                                    <<"p2s"/utf8>>
                                                                                ),
                                                                                fun(
                                                                                    P2s@1
                                                                                ) ->
                                                                                    gleam@result:'try'(
                                                                                        parse_optional_base64(
                                                                                            Kw_iv_b64,
                                                                                            <<"iv"/utf8>>
                                                                                        ),
                                                                                        fun(
                                                                                            Kw_iv@1
                                                                                        ) ->
                                                                                            gleam@result:'try'(
                                                                                                parse_optional_base64(
                                                                                                    Kw_tag_b64,
                                                                                                    <<"tag"/utf8>>
                                                                                                ),
                                                                                                fun(
                                                                                                    Kw_tag@1
                                                                                                ) ->
                                                                                                    gleam@result:'try'(
                                                                                                        build_parsed_alg_fields(
                                                                                                            Alg@1,
                                                                                                            Epk,
                                                                                                            Apu@1,
                                                                                                            Apv@1,
                                                                                                            P2s@1,
                                                                                                            P2c@1,
                                                                                                            Kw_iv@1,
                                                                                                            Kw_tag@1
                                                                                                        ),
                                                                                                        fun(
                                                                                                            Alg_fields
                                                                                                        ) ->
                                                                                                            Header = {jwe_header,
                                                                                                                Alg@1,
                                                                                                                Enc@1,
                                                                                                                Kid@1,
                                                                                                                Typ@1,
                                                                                                                Cty@1},
                                                                                                            {ok,
                                                                                                                {parsed_header,
                                                                                                                    Header,
                                                                                                                    Alg_fields}}
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

-file("src/gose/jose/jwe.gleam", 1757).
-spec parse_protected_header(binary()) -> {ok, parsed_header()} |
    {error, gose:gose_error()}.
parse_protected_header(B64) ->
    gleam@result:'try'(
        gose@internal@utils:decode_base64_url(B64, <<"header"/utf8>>),
        fun(Header_bits) -> parse_header_json(Header_bits) end
    ).

-file("src/gose/jose/jwe.gleam", 1710).
?DOC(
    " Parse a JWE from compact format.\n"
    "\n"
    " Returns an encrypted JWE that can be decrypted.\n"
    " Uses Nil family since algorithm family isn't known at compile time.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(parsed) = jwe.parse_compact(token)\n"
    " let assert Ok(decryptor) = jwe.key_decryptor(gose.Direct, gose.AesGcm(gose.Aes256), [key])\n"
    " let assert Ok(plaintext) = jwe.decrypt(decryptor, parsed)\n"
    " ```\n"
).
-spec parse_compact(binary()) -> {ok, jwe(encrypted(), nil, parsed())} |
    {error, gose:gose_error()}.
parse_compact(Token) ->
    case gleam@string:split(Token, <<"."/utf8>>) of
        [Protected_b64, Ek_b64, Iv_b64, Ct_b64, Tag_b64] ->
            gleam@result:'try'(
                parse_protected_header(Protected_b64),
                fun(_use0) ->
                    {parsed_header, Header, Alg_fields} = _use0,
                    gleam@result:'try'(
                        gose@internal@utils:decode_base64_url(
                            Ek_b64,
                            <<"encrypted_key"/utf8>>
                        ),
                        fun(Encrypted_key) ->
                            gleam@result:'try'(
                                validate_encrypted_key_for_algorithm(
                                    erlang:element(2, Header),
                                    Encrypted_key
                                ),
                                fun(_) ->
                                    gleam@result:'try'(
                                        gose@internal@utils:decode_base64_url(
                                            Iv_b64,
                                            <<"iv"/utf8>>
                                        ),
                                        fun(Iv) ->
                                            gleam@result:'try'(
                                                gose@internal@utils:decode_base64_url(
                                                    Ct_b64,
                                                    <<"ciphertext"/utf8>>
                                                ),
                                                fun(Ciphertext) ->
                                                    gleam@result:'try'(
                                                        gose@internal@utils:decode_base64_url(
                                                            Tag_b64,
                                                            <<"tag"/utf8>>
                                                        ),
                                                        fun(Tag) ->
                                                            gleam@result:'try'(
                                                                gose@internal@content_encryption:validate_iv_tag_sizes(
                                                                    erlang:element(
                                                                        3,
                                                                        Header
                                                                    ),
                                                                    Iv,
                                                                    Tag
                                                                ),
                                                                fun(_) ->
                                                                    {ok,
                                                                        {encrypted_jwe,
                                                                            Header,
                                                                            Protected_b64,
                                                                            Encrypted_key,
                                                                            Iv,
                                                                            Ciphertext,
                                                                            Tag,
                                                                            Alg_fields,
                                                                            none,
                                                                            maps:new(
                                                                                
                                                                            ),
                                                                            none,
                                                                            maps:new(
                                                                                
                                                                            ),
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
                    )
                end
            );

        _ ->
            {error,
                {parse_error,
                    <<"invalid compact serialization: expected 5 parts"/utf8>>}}
    end.

-file("src/gose/jose/jwe.gleam", 711).
?DOC(
    " Add a shared unprotected header parameter.\n"
    "\n"
    " **Security Warning:** Shared unprotected headers are NOT integrity protected.\n"
    " They can be modified by an attacker without detection.\n"
    "\n"
    " Returns an error if the name is a protected-only header (`alg`, `enc`,\n"
    " `crit`, `zip`) which must be integrity protected.\n"
    "\n"
    " Shared unprotected headers apply to all recipients in JSON serialization.\n"
    " Compact serialization will return an error if unprotected headers are present.\n"
    "\n"
    " If the same header name is set multiple times, the last value wins.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(jwe) =\n"
    "   jwe.new_direct(gose.AesGcm(gose.Aes256))\n"
    "   |> jwe.with_shared_unprotected(\"x-request-id\", json.string(\"abc-123\"))\n"
    " ```\n"
).
-spec with_shared_unprotected(
    jwe(unencrypted(), SRR, built()),
    binary(),
    gleam@json:json()
) -> {ok, jwe(unencrypted(), SRR, built())} | {error, gose:gose_error()}.
with_shared_unprotected(Jwe, Name, Value) ->
    gleam@bool:guard(
        gleam@list:contains(
            [<<"alg"/utf8>>, <<"enc"/utf8>>, <<"crit"/utf8>>, <<"zip"/utf8>>],
            Name
        ),
        {error,
            {invalid_state,
                <<"protected-only header cannot be in unprotected: "/utf8,
                    Name/binary>>}},
        fun() ->
            Shared_unprotected@1 = case Jwe of
                {jwe, _, _, Shared_unprotected, _, _} -> Shared_unprotected;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"with_shared_unprotected"/utf8>>,
                                line => 722,
                                value => _assert_fail,
                                start => 23003,
                                'end' => 23048,
                                pattern_start => 23014,
                                pattern_end => 23042})
            end,
            {ok,
                {jwe,
                    erlang:element(2, Jwe),
                    erlang:element(3, Jwe),
                    gleam@dict:insert(Shared_unprotected@1, Name, Value),
                    erlang:element(5, Jwe),
                    erlang:element(6, Jwe)}}
        end
    ).

-file("src/gose/jose/jwe.gleam", 750).
?DOC(
    " Add a per-recipient unprotected header parameter.\n"
    "\n"
    " **Security Warning:** Per-recipient unprotected headers are NOT integrity protected.\n"
    " They can be modified by an attacker without detection.\n"
    "\n"
    " Returns an error if the name is a protected-only header (`alg`, `enc`,\n"
    " `crit`, `zip`) which must be integrity protected.\n"
    "\n"
    " Per-recipient headers appear in JSON serialization only and apply to\n"
    " the single recipient. Compact serialization will return an error if\n"
    " unprotected headers are present.\n"
    "\n"
    " If the same header name is set multiple times, the last value wins.\n"
).
-spec with_unprotected(
    jwe(unencrypted(), SSH, built()),
    binary(),
    gleam@json:json()
) -> {ok, jwe(unencrypted(), SSH, built())} | {error, gose:gose_error()}.
with_unprotected(Jwe, Name, Value) ->
    gleam@bool:guard(
        gleam@list:contains(
            [<<"alg"/utf8>>, <<"enc"/utf8>>, <<"crit"/utf8>>, <<"zip"/utf8>>],
            Name
        ),
        {error,
            {invalid_state,
                <<"protected-only header cannot be in unprotected: "/utf8,
                    Name/binary>>}},
        fun() ->
            Per_recipient_unprotected@1 = case Jwe of
                {jwe, _, _, _, Per_recipient_unprotected, _} -> Per_recipient_unprotected;
                _assert_fail ->
                    erlang:error(#{gleam_error => let_assert,
                                message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                file => <<?FILEPATH/utf8>>,
                                module => <<"gose/jose/jwe"/utf8>>,
                                function => <<"with_unprotected"/utf8>>,
                                line => 761,
                                value => _assert_fail,
                                start => 24383,
                                'end' => 24435,
                                pattern_start => 24394,
                                pattern_end => 24429})
            end,
            {ok,
                {jwe,
                    erlang:element(2, Jwe),
                    erlang:element(3, Jwe),
                    erlang:element(4, Jwe),
                    gleam@dict:insert(Per_recipient_unprotected@1, Name, Value),
                    erlang:element(6, Jwe)}}
        end
    ).

-file("src/gose/jose/jwe.gleam", 2099).
?DOC(" Validate that no protected-only headers appear in unprotected.\n").
-spec validate_no_protected_only_headers(list(binary())) -> {ok, nil} |
    {error, gose:gose_error()}.
validate_no_protected_only_headers(Names) ->
    Violations = gleam@list:filter(
        Names,
        fun(_capture) ->
            gleam@list:contains(
                [<<"alg"/utf8>>,
                    <<"enc"/utf8>>,
                    <<"crit"/utf8>>,
                    <<"zip"/utf8>>],
                _capture
            )
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

-file("src/gose/jose/jwe.gleam", 2079).
?DOC(
    " Parse an unprotected header from a decode.Dynamic value.\n"
    " Returns a tuple of (raw dynamic for decoder, header names for disjointness validation).\n"
    " The dict is not populated. Parsed values are accessed via decoders on the raw dynamic.\n"
).
-spec parse_unprotected_header(gleam@option:option(gleam@dynamic:dynamic_())) -> {ok,
        {gleam@option:option(gleam@dynamic:dynamic_()), list(binary())}} |
    {error, gose:gose_error()}.
parse_unprotected_header(Raw) ->
    case Raw of
        none ->
            {ok, {none, []}};

        {some, Dyn} ->
            gleam@result:'try'(
                begin
                    _pipe = gleam@dynamic@decode:run(
                        Dyn,
                        gleam@dynamic@decode:dict(
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
                        )
                    ),
                    gleam@result:replace_error(
                        _pipe,
                        {parse_error,
                            <<"unprotected header must be a JSON object"/utf8>>}
                    )
                end,
                fun(Unprotected_dict) ->
                    Names = maps:keys(Unprotected_dict),
                    gleam@result:'try'(
                        validate_no_protected_only_headers(Names),
                        fun(_) -> {ok, {{some, Dyn}, Names}} end
                    )
                end
            )
    end.

-file("src/gose/jose/jwe.gleam", 2417).
-spec parse_json_flattened(binary()) -> {ok, jwe(encrypted(), nil, parsed())} |
    {error, gose:gose_error()}.
parse_json_flattened(Json_str) ->
    Decoder = begin
        gleam@dynamic@decode:field(
            <<"protected"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Protected) ->
                gleam@dynamic@decode:optional_field(
                    <<"encrypted_key"/utf8>>,
                    none,
                    gleam@dynamic@decode:optional(
                        {decoder, fun gleam@dynamic@decode:decode_string/1}
                    ),
                    fun(Encrypted_key) ->
                        gleam@dynamic@decode:field(
                            <<"iv"/utf8>>,
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            fun(Iv) ->
                                gleam@dynamic@decode:field(
                                    <<"ciphertext"/utf8>>,
                                    {decoder,
                                        fun gleam@dynamic@decode:decode_string/1},
                                    fun(Ciphertext) ->
                                        gleam@dynamic@decode:field(
                                            <<"tag"/utf8>>,
                                            {decoder,
                                                fun gleam@dynamic@decode:decode_string/1},
                                            fun(Tag) ->
                                                gleam@dynamic@decode:optional_field(
                                                    <<"header"/utf8>>,
                                                    none,
                                                    gleam@dynamic@decode:optional(
                                                        {decoder,
                                                            fun gleam@dynamic@decode:decode_dynamic/1}
                                                    ),
                                                    fun(Header_raw) ->
                                                        gleam@dynamic@decode:optional_field(
                                                            <<"aad"/utf8>>,
                                                            none,
                                                            gleam@dynamic@decode:optional(
                                                                {decoder,
                                                                    fun gleam@dynamic@decode:decode_string/1}
                                                            ),
                                                            fun(Aad_b64) ->
                                                                gleam@dynamic@decode:optional_field(
                                                                    <<"unprotected"/utf8>>,
                                                                    none,
                                                                    gleam@dynamic@decode:optional(
                                                                        {decoder,
                                                                            fun gleam@dynamic@decode:decode_dynamic/1}
                                                                    ),
                                                                    fun(
                                                                        Unprotected_raw
                                                                    ) ->
                                                                        gleam@dynamic@decode:success(
                                                                            {Protected,
                                                                                Encrypted_key,
                                                                                Iv,
                                                                                Ciphertext,
                                                                                Tag,
                                                                                Header_raw,
                                                                                Aad_b64,
                                                                                Unprotected_raw}
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
                {parse_error, <<"invalid JWE JSON (flattened)"/utf8>>}
            )
        end,
        fun(_use0) ->
            {Protected_b64,
                Ek_opt,
                Iv_b64,
                Ct_b64,
                Tag_b64,
                Header_raw@1,
                Aad_b64_opt,
                Unprotected_raw@1} = _use0,
            gleam@result:'try'(
                parse_protected_header(Protected_b64),
                fun(_use0@1) ->
                    {parsed_header, Header, Alg_fields} = _use0@1,
                    gleam@result:'try'(
                        parse_unprotected_header(Unprotected_raw@1),
                        fun(_use0@2) ->
                            {Shared_unprotected_raw, Shared_names} = _use0@2,
                            gleam@result:'try'(
                                parse_unprotected_header(Header_raw@1),
                                fun(_use0@3) ->
                                    {Per_recipient_unprotected_raw,
                                        Per_recipient_names} = _use0@3,
                                    gleam@result:'try'(
                                        validate_jwe_header_disjointness(
                                            Header,
                                            Alg_fields,
                                            Shared_names,
                                            Per_recipient_names
                                        ),
                                        fun(_) ->
                                            gleam@result:'try'(
                                                decode_base64_url_or_empty(
                                                    Ek_opt,
                                                    <<"encrypted_key"/utf8>>
                                                ),
                                                fun(Encrypted_key@1) ->
                                                    gleam@result:'try'(
                                                        validate_encrypted_key_for_algorithm(
                                                            erlang:element(
                                                                2,
                                                                Header
                                                            ),
                                                            Encrypted_key@1
                                                        ),
                                                        fun(_) ->
                                                            gleam@result:'try'(
                                                                gose@internal@utils:decode_base64_url(
                                                                    Iv_b64,
                                                                    <<"iv"/utf8>>
                                                                ),
                                                                fun(Iv@1) ->
                                                                    gleam@result:'try'(
                                                                        gose@internal@utils:decode_base64_url(
                                                                            Ct_b64,
                                                                            <<"ciphertext"/utf8>>
                                                                        ),
                                                                        fun(
                                                                            Ciphertext@1
                                                                        ) ->
                                                                            gleam@result:'try'(
                                                                                gose@internal@utils:decode_base64_url(
                                                                                    Tag_b64,
                                                                                    <<"tag"/utf8>>
                                                                                ),
                                                                                fun(
                                                                                    Tag@1
                                                                                ) ->
                                                                                    gleam@result:'try'(
                                                                                        gose@internal@content_encryption:validate_iv_tag_sizes(
                                                                                            erlang:element(
                                                                                                3,
                                                                                                Header
                                                                                            ),
                                                                                            Iv@1,
                                                                                            Tag@1
                                                                                        ),
                                                                                        fun(
                                                                                            _
                                                                                        ) ->
                                                                                            gleam@result:'try'(
                                                                                                decode_optional_base64_url(
                                                                                                    Aad_b64_opt,
                                                                                                    <<"aad"/utf8>>
                                                                                                ),
                                                                                                fun(
                                                                                                    User_aad
                                                                                                ) ->
                                                                                                    {ok,
                                                                                                        {encrypted_jwe,
                                                                                                            Header,
                                                                                                            Protected_b64,
                                                                                                            Encrypted_key@1,
                                                                                                            Iv@1,
                                                                                                            Ciphertext@1,
                                                                                                            Tag@1,
                                                                                                            Alg_fields,
                                                                                                            User_aad,
                                                                                                            maps:new(
                                                                                                                
                                                                                                            ),
                                                                                                            Shared_unprotected_raw,
                                                                                                            maps:new(
                                                                                                                
                                                                                                            ),
                                                                                                            Per_recipient_unprotected_raw}}
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

-file("src/gose/jose/jwe.gleam", 2527).
-spec parse_json_general(binary()) -> {ok, jwe(encrypted(), nil, parsed())} |
    {error, gose:gose_error()}.
parse_json_general(Json_str) ->
    Recipient_decoder = begin
        gleam@dynamic@decode:optional_field(
            <<"encrypted_key"/utf8>>,
            none,
            gleam@dynamic@decode:optional(
                {decoder, fun gleam@dynamic@decode:decode_string/1}
            ),
            fun(Encrypted_key) ->
                gleam@dynamic@decode:optional_field(
                    <<"header"/utf8>>,
                    none,
                    gleam@dynamic@decode:optional(
                        {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
                    ),
                    fun(Header_raw) ->
                        gleam@dynamic@decode:success(
                            {Encrypted_key, Header_raw}
                        )
                    end
                )
            end
        )
    end,
    Decoder = begin
        gleam@dynamic@decode:field(
            <<"protected"/utf8>>,
            {decoder, fun gleam@dynamic@decode:decode_string/1},
            fun(Protected) ->
                gleam@dynamic@decode:field(
                    <<"recipients"/utf8>>,
                    gleam@dynamic@decode:list(Recipient_decoder),
                    fun(Recipients) ->
                        gleam@dynamic@decode:field(
                            <<"iv"/utf8>>,
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            fun(Iv) ->
                                gleam@dynamic@decode:field(
                                    <<"ciphertext"/utf8>>,
                                    {decoder,
                                        fun gleam@dynamic@decode:decode_string/1},
                                    fun(Ciphertext) ->
                                        gleam@dynamic@decode:field(
                                            <<"tag"/utf8>>,
                                            {decoder,
                                                fun gleam@dynamic@decode:decode_string/1},
                                            fun(Tag) ->
                                                gleam@dynamic@decode:optional_field(
                                                    <<"aad"/utf8>>,
                                                    none,
                                                    gleam@dynamic@decode:optional(
                                                        {decoder,
                                                            fun gleam@dynamic@decode:decode_string/1}
                                                    ),
                                                    fun(Aad_b64) ->
                                                        gleam@dynamic@decode:optional_field(
                                                            <<"unprotected"/utf8>>,
                                                            none,
                                                            gleam@dynamic@decode:optional(
                                                                {decoder,
                                                                    fun gleam@dynamic@decode:decode_dynamic/1}
                                                            ),
                                                            fun(Unprotected_raw) ->
                                                                gleam@dynamic@decode:success(
                                                                    {Protected,
                                                                        Recipients,
                                                                        Iv,
                                                                        Ciphertext,
                                                                        Tag,
                                                                        Aad_b64,
                                                                        Unprotected_raw}
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
            end
        )
    end,
    gleam@result:'try'(
        begin
            _pipe = gleam@json:parse(Json_str, Decoder),
            gleam@result:replace_error(
                _pipe,
                {parse_error, <<"invalid JWE JSON (general)"/utf8>>}
            )
        end,
        fun(_use0) ->
            {Protected_b64,
                Recipients@1,
                Iv_b64,
                Ct_b64,
                Tag_b64,
                Aad_b64_opt,
                Unprotected_raw@1} = _use0,
            gleam@result:'try'(
                parse_unprotected_header(Unprotected_raw@1),
                fun(_use0@1) ->
                    {Shared_unprotected_raw, Shared_names} = _use0@1,
                    case Recipients@1 of
                        [{Ek_opt, Header_raw@1}] ->
                            gleam@result:'try'(
                                parse_protected_header(Protected_b64),
                                fun(_use0@2) ->
                                    {parsed_header, Header, Alg_fields} = _use0@2,
                                    gleam@result:'try'(
                                        parse_unprotected_header(Header_raw@1),
                                        fun(_use0@3) ->
                                            {Per_recipient_unprotected_raw,
                                                Per_recipient_names} = _use0@3,
                                            gleam@result:'try'(
                                                validate_jwe_header_disjointness(
                                                    Header,
                                                    Alg_fields,
                                                    Shared_names,
                                                    Per_recipient_names
                                                ),
                                                fun(_) ->
                                                    gleam@result:'try'(
                                                        decode_base64_url_or_empty(
                                                            Ek_opt,
                                                            <<"encrypted_key"/utf8>>
                                                        ),
                                                        fun(Encrypted_key@1) ->
                                                            gleam@result:'try'(
                                                                validate_encrypted_key_for_algorithm(
                                                                    erlang:element(
                                                                        2,
                                                                        Header
                                                                    ),
                                                                    Encrypted_key@1
                                                                ),
                                                                fun(_) ->
                                                                    gleam@result:'try'(
                                                                        gose@internal@utils:decode_base64_url(
                                                                            Iv_b64,
                                                                            <<"iv"/utf8>>
                                                                        ),
                                                                        fun(
                                                                            Iv@1
                                                                        ) ->
                                                                            gleam@result:'try'(
                                                                                gose@internal@utils:decode_base64_url(
                                                                                    Ct_b64,
                                                                                    <<"ciphertext"/utf8>>
                                                                                ),
                                                                                fun(
                                                                                    Ciphertext@1
                                                                                ) ->
                                                                                    gleam@result:'try'(
                                                                                        gose@internal@utils:decode_base64_url(
                                                                                            Tag_b64,
                                                                                            <<"tag"/utf8>>
                                                                                        ),
                                                                                        fun(
                                                                                            Tag@1
                                                                                        ) ->
                                                                                            gleam@result:'try'(
                                                                                                gose@internal@content_encryption:validate_iv_tag_sizes(
                                                                                                    erlang:element(
                                                                                                        3,
                                                                                                        Header
                                                                                                    ),
                                                                                                    Iv@1,
                                                                                                    Tag@1
                                                                                                ),
                                                                                                fun(
                                                                                                    _
                                                                                                ) ->
                                                                                                    gleam@result:'try'(
                                                                                                        decode_optional_base64_url(
                                                                                                            Aad_b64_opt,
                                                                                                            <<"aad"/utf8>>
                                                                                                        ),
                                                                                                        fun(
                                                                                                            Aad
                                                                                                        ) ->
                                                                                                            {ok,
                                                                                                                {encrypted_jwe,
                                                                                                                    Header,
                                                                                                                    Protected_b64,
                                                                                                                    Encrypted_key@1,
                                                                                                                    Iv@1,
                                                                                                                    Ciphertext@1,
                                                                                                                    Tag@1,
                                                                                                                    Alg_fields,
                                                                                                                    Aad,
                                                                                                                    maps:new(
                                                                                                                        
                                                                                                                    ),
                                                                                                                    Shared_unprotected_raw,
                                                                                                                    maps:new(
                                                                                                                        
                                                                                                                    ),
                                                                                                                    Per_recipient_unprotected_raw}}
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
                                    <<"JWE JSON (general) has multiple recipients (not supported)"/utf8>>}};

                        [] ->
                            {error,
                                {parse_error,
                                    <<"JWE JSON (general) has no recipients"/utf8>>}}
                    end
                end
            )
        end
    ).

-file("src/gose/jose/jwe.gleam", 2382).
?DOC(" Parse a JWE from JSON format (supports both General and Flattened).\n").
-spec parse_json(binary()) -> {ok, jwe(encrypted(), nil, parsed())} |
    {error, gose:gose_error()}.
parse_json(Json_str) ->
    Format_detector = begin
        gleam@dynamic@decode:field(
            <<"recipients"/utf8>>,
            gleam@dynamic@decode:list(
                {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
            ),
            fun(_) -> gleam@dynamic@decode:success(true) end
        )
    end,
    Is_general_format = begin
        _pipe = gleam@json:parse(Json_str, Format_detector),
        gleam@result:is_ok(_pipe)
    end,
    case Is_general_format of
        true ->
            parse_json_general(Json_str);

        false ->
            parse_json_flattened(Json_str)
    end.
