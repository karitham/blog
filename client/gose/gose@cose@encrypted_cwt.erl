-module(gose@cose@encrypted_cwt).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose/encrypted_cwt.gleam").
-export([encrypt/3, decrypt_and_validate/4]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Encrypted CWT with decrypt-then-validate workflow for encrypted CWT tokens.\n"
    "\n"
    " An encrypted CWT is a CWT (signed COSE_Sign1 containing claims) that is\n"
    " then encrypted with COSE_Encrypt0. The workflow to consume one is:\n"
    " 1. Decrypt the outer Encrypt0 layer to get the inner signed CWT bytes\n"
    " 2. Verify the Sign1 signature and validate the CWT claims\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " import gleam/time/duration\n"
    " import gleam/time/timestamp\n"
    " import gose\n"
    " import gose/cose/cwt\n"
    " import gose/cose/encrypt0\n"
    " import gose/cose/encrypted_cwt\n"
    " import kryptos/ec\n"
    "\n"
    " let signing_key = gose.generate_ec(ec.P256)\n"
    " let encryption_key = gose.generate_enc_key(gose.AesGcm(gose.Aes128))\n"
    " let now = timestamp.system_time()\n"
    " let exp = timestamp.add(now, duration.hours(1))\n"
    "\n"
    " let claims = cwt.new()\n"
    "   |> cwt.with_subject(\"user123\")\n"
    "   |> cwt.with_expiration(exp)\n"
    "\n"
    " let assert Ok(signed) =\n"
    "   cwt.sign(claims, alg: gose.Ecdsa(gose.EcdsaP256), key: signing_key)\n"
    " let assert Ok(encrypted) =\n"
    "   encrypted_cwt.encrypt(signed, enc: gose.AesGcm(gose.Aes128), key: encryption_key)\n"
    "\n"
    " let assert Ok(verifier) =\n"
    "   cwt.verifier(gose.Ecdsa(gose.EcdsaP256), keys: [signing_key])\n"
    " let assert Ok(decryptor) =\n"
    "   encrypt0.decryptor(gose.AesGcm(gose.Aes128), key: encryption_key)\n"
    " let assert Ok(verified) =\n"
    "   encrypted_cwt.decrypt_and_validate(encrypted, decryptor:, verifier:, now:)\n"
    " ```\n"
).

-file("src/gose/cose/encrypted_cwt.gleam", 80).
-spec map_gose_error(gose:gose_error()) -> gose@cose@cwt:cwt_error().
map_gose_error(Err) ->
    {cose_error, Err}.

-file("src/gose/cose/encrypted_cwt.gleam", 48).
?DOC(" Encrypt a signed CWT with COSE_Encrypt0.\n").
-spec encrypt(bitstring(), gose:content_alg(), gose:key(bitstring())) -> {ok,
        bitstring()} |
    {error, gose@cose@cwt:cwt_error()}.
encrypt(Signed_cwt, Content_alg, Encryption_key) ->
    gleam@result:'try'(
        begin
            _pipe = gose@cose@encrypt0:new(Content_alg),
            gleam@result:map_error(_pipe, fun map_gose_error/1)
        end,
        fun(Message) ->
            _pipe@1 = gose@cose@encrypt0:encrypt(
                Message,
                Encryption_key,
                Signed_cwt
            ),
            _pipe@2 = gleam@result:map(
                _pipe@1,
                fun gose@cose@encrypt0:serialize/1
            ),
            gleam@result:map_error(_pipe@2, fun map_gose_error/1)
        end
    ).

-file("src/gose/cose/encrypted_cwt.gleam", 62).
?DOC(" Decrypt an encrypted CWT and validate its claims.\n").
-spec decrypt_and_validate(
    bitstring(),
    gose@cose@encrypt0:decryptor(),
    gose@cose@cwt:verifier(),
    gleam@time@timestamp:timestamp()
) -> {ok, gose@cose@cwt:cwt(gose@cose@cwt:verified())} |
    {error, gose@cose@cwt:cwt_error()}.
decrypt_and_validate(Token, Decryptor, Verifier, Now) ->
    gleam@result:'try'(
        begin
            _pipe = gose@cose@encrypt0:parse(Token),
            gleam@result:map_error(_pipe, fun map_gose_error/1)
        end,
        fun(Parsed) ->
            gleam@result:'try'(
                begin
                    _pipe@1 = gose@cose@encrypt0:decrypt(Decryptor, Parsed),
                    gleam@result:map_error(
                        _pipe@1,
                        fun(Err) ->
                            {decryption_failed, gose:error_message(Err)}
                        end
                    )
                end,
                fun(Inner_bytes) ->
                    gose@cose@cwt:verify_and_validate(
                        Verifier,
                        Inner_bytes,
                        Now
                    )
                end
            )
        end
    ).
