-module(gose@jose@encrypted_key).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/encrypted_key.gleam").
-export([decrypt/2, encrypt_with_key/4, encrypt_with_password/4]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Encrypted JWK Export/Import - [RFC 7516](https://www.rfc-editor.org/rfc/rfc7516.html)\n"
    "\n"
    " Export and import JWKs as encrypted JSON using JWE. The plaintext JWK\n"
    " JSON becomes the JWE payload with `cty: \"jwk+json\"`.\n"
    "\n"
    " ## Example\n"
    "\n"
    " Key-based encryption:\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/jose/encrypted_key\n"
    " import gose/jose/jwe\n"
    " import kryptos/ec\n"
    "\n"
    " // Generate a wrapping key and an EC key to protect\n"
    " let wrapping_key = gose.generate_enc_key(gose.AesGcm(gose.Aes256))\n"
    " let k = gose.generate_ec(ec.P256)\n"
    "\n"
    " // Export with key-based encryption\n"
    " let assert Ok(encrypted) = encrypted_key.encrypt_with_key(\n"
    "   k,\n"
    "   alg: gose.Direct,\n"
    "   enc: gose.AesGcm(gose.Aes256),\n"
    "   with: wrapping_key,\n"
    " )\n"
    "\n"
    " // Import it back\n"
    " let assert Ok(decryptor) = jwe.key_decryptor(\n"
    "   gose.Direct,\n"
    "   gose.AesGcm(gose.Aes256),\n"
    "   keys: [wrapping_key],\n"
    " )\n"
    " let assert Ok(recovered) = encrypted_key.decrypt(decryptor, encrypted)\n"
    " ```\n"
    "\n"
    " Password-based encryption:\n"
    "\n"
    " ```gleam\n"
    " import gose\n"
    " import gose/jose/encrypted_key\n"
    " import gose/jose/jwe\n"
    " import kryptos/ec\n"
    "\n"
    " let k = gose.generate_ec(ec.P256)\n"
    "\n"
    " // Export with password protection\n"
    " let assert Ok(encrypted) = encrypted_key.encrypt_with_password(\n"
    "   k,\n"
    "   gose.Pbes2Sha256Aes128Kw,\n"
    "   gose.AesGcm(gose.Aes256),\n"
    "   \"my-secure-password\",\n"
    " )\n"
    "\n"
    " // Import it back using a decryptor\n"
    " let decryptor = jwe.password_decryptor(\n"
    "   gose.Pbes2Sha256Aes128Kw,\n"
    "   gose.AesGcm(gose.Aes256),\n"
    "   \"my-secure-password\",\n"
    " )\n"
    " let assert Ok(recovered) = encrypted_key.decrypt(decryptor, encrypted)\n"
    " ```\n"
).

-file("src/gose/jose/encrypted_key.gleam", 89).
?DOC(
    " Import a JWK from encrypted JSON using a decryptor with algorithm pinning.\n"
    "\n"
    " Works for all algorithms. Create a decryptor with `jwe.key_decryptor`\n"
    " for key-based algorithms or `jwe.password_decryptor` for PBES2.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let decryptor =\n"
    "   jwe.password_decryptor(\n"
    "     gose.Pbes2Sha256Aes128Kw,\n"
    "     gose.AesGcm(gose.Aes256),\n"
    "     \"my-password\",\n"
    "   )\n"
    " let assert Ok(key) = encrypted_key.decrypt(decryptor, encrypted_token)\n"
    " ```\n"
).
-spec decrypt(gose@jose@jwe:decryptor(), binary()) -> {ok, gose:key(binary())} |
    {error, gose:gose_error()}.
decrypt(Decryptor, Encrypted) ->
    gleam@result:'try'(
        gose@jose@jwe:parse_compact(Encrypted),
        fun(Parsed) ->
            gleam@result:'try'(
                gose@jose@jwe:decrypt(Decryptor, Parsed),
                fun(Plaintext) -> gose@jose@jwk:from_json_bits(Plaintext) end
            )
        end
    ).

-file("src/gose/jose/encrypted_key.gleam", 154).
-spec jwk_to_plaintext(gose:key(binary())) -> bitstring().
jwk_to_plaintext(Key) ->
    _pipe = gose@jose@jwk:to_json(Key),
    _pipe@1 = gleam@json:to_string(_pipe),
    gleam_stdlib:identity(_pipe@1).

-file("src/gose/jose/encrypted_key.gleam", 113).
?DOC(
    " Export a JWK as encrypted JSON using a key-based algorithm.\n"
    "\n"
    " Supports all key-based JWE algorithms: direct symmetric (dir), AES Key Wrap,\n"
    " AES-GCM Key Wrap, RSA-OAEP, and ECDH-ES. PBES2 password-based algorithms\n"
    " return an error. Use `encrypt_with_password` for those.\n"
    "\n"
    " The encryption key type must match the algorithm:\n"
    " - `Direct`: octet key matching the content encryption key size\n"
    " - `AesKeyWrap(AesKw, _)`: octet key (16, 24, or 32 bytes)\n"
    " - `AesKeyWrap(AesGcmKw, _)`: octet key (16, 24, or 32 bytes)\n"
    " - `ChaCha20KeyWrap(_)`: octet key (32 bytes)\n"
    " - `RsaEncryption(_)`: RSA key\n"
    " - `EcdhEs(_)`: EC or XDH key\n"
    "\n"
    " If the encryption key has a `kid`, it is included in the JWE header.\n"
).
-spec encrypt_with_key(
    gose:key(binary()),
    gose:key_encryption_alg(),
    gose:content_alg(),
    gose:key(binary())
) -> {ok, binary()} | {error, gose:gose_error()}.
encrypt_with_key(Key, Alg, Enc, Encryption_key) ->
    Plaintext = jwk_to_plaintext(Key),
    Kid = gleam@option:from_result(gose:kid(Encryption_key)),
    _pipe = gose@jose@jwe:encrypt_to_compact(
        Alg,
        Enc,
        Plaintext,
        Encryption_key,
        Kid,
        none,
        {some, <<"jwk+json"/utf8>>}
    ),
    gleam@result:map(_pipe, fun gleam@pair:first/1).

-file("src/gose/jose/encrypted_key.gleam", 138).
?DOC(
    " Export a JWK as encrypted JSON using PBES2 password-based encryption.\n"
    "\n"
    " This is the most common method for protecting stored keys with a password.\n"
    " The JWK is serialized to JSON, then encrypted using the specified PBES2\n"
    " algorithm and content encryption algorithm.\n"
).
-spec encrypt_with_password(
    gose:key(binary()),
    gose:pbes2_alg(),
    gose:content_alg(),
    binary()
) -> {ok, binary()} | {error, gose:gose_error()}.
encrypt_with_password(Key, Alg, Enc, Password) ->
    Plaintext = jwk_to_plaintext(Key),
    Encryptor = begin
        _pipe = gose@jose@jwe:new_pbes2(Alg, Enc),
        gose@jose@jwe:with_cty(_pipe, <<"jwk+json"/utf8>>)
    end,
    _pipe@1 = gose@jose@jwe:encrypt_with_password(
        Encryptor,
        Password,
        Plaintext
    ),
    gleam@result:'try'(_pipe@1, fun gose@jose@jwe:serialize_compact/1).
