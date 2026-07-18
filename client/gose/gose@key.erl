-module(gose@key).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/key.gleam").
-export([from_der/1, from_pem/1, from_octet_bits/1, from_eddsa_bits/2, from_eddsa_public_bits/2, from_xdh_bits/2, from_xdh_public_bits/2, ec_public_key_from_coordinates/3, generate_ec/1, generate_eddsa/1, generate_hmac_key/1, generate_enc_key/1, generate_aes_kw_key/1, generate_chacha20_kw_key/0, generate_rsa/1, generate_xdh/1, with_alg/2, with_key_ops/2, with_key_use/2, with_kid/2, with_kid_bits/2, alg/1, ec_curve/1, ec_public_key/1, ec_public_key_coordinates/1, eddsa_curve/1, eddsa_public_key/1, key_ops/1, key_type/1, key_use/1, kid/1, octet_key_size/1, rsa_public_key/1, xdh_curve/1, xdh_public_key/1, public_key/1, to_der/1, to_octet_bits/1, to_pem/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Deprecated: use the `gose` module instead.\n"
    "\n"
    " Re-exports the key API from `gose` for the v2.x migration window.\n"
    " The module will be removed in v3.0. New code should import `gose`\n"
    " directly.\n"
    "\n"
    " Constructors of `KeyUse`, `KeyOp`, `Alg`, and `KeyType` are not\n"
    " re-exported (Gleam type aliases re-export the type but not its\n"
    " constructors). Callers that reference those constructors must\n"
    " update to `gose.Signing`, `gose.SigningAlg(_)`, and so on. See\n"
    " `docs/MIGRATION.md` for the full list.\n"
).

-file("src/gose/key.gleam", 40).
-spec from_der(bitstring()) -> {ok, gose:key(any())} |
    {error, gose:gose_error()}.
from_der(Der) ->
    gose:from_der(Der).

-file("src/gose/key.gleam", 45).
-spec from_pem(binary()) -> {ok, gose:key(any())} | {error, gose:gose_error()}.
from_pem(Pem) ->
    gose:from_pem(Pem).

-file("src/gose/key.gleam", 50).
-spec from_octet_bits(bitstring()) -> {ok, gose:key(any())} |
    {error, gose:gose_error()}.
from_octet_bits(Secret) ->
    gose:from_octet_bits(Secret).

-file("src/gose/key.gleam", 57).
-spec from_eddsa_bits(kryptos@eddsa:curve(), bitstring()) -> {ok,
        gose:key(any())} |
    {error, gose:gose_error()}.
from_eddsa_bits(Curve, Private_bits) ->
    gose:from_eddsa_bits(Curve, Private_bits).

-file("src/gose/key.gleam", 65).
-spec from_eddsa_public_bits(kryptos@eddsa:curve(), bitstring()) -> {ok,
        gose:key(any())} |
    {error, gose:gose_error()}.
from_eddsa_public_bits(Curve, Public_bits) ->
    gose:from_eddsa_public_bits(Curve, Public_bits).

-file("src/gose/key.gleam", 73).
-spec from_xdh_bits(kryptos@xdh:curve(), bitstring()) -> {ok, gose:key(any())} |
    {error, gose:gose_error()}.
from_xdh_bits(Curve, Private_bits) ->
    gose:from_xdh_bits(Curve, Private_bits).

-file("src/gose/key.gleam", 81).
-spec from_xdh_public_bits(kryptos@xdh:curve(), bitstring()) -> {ok,
        gose:key(any())} |
    {error, gose:gose_error()}.
from_xdh_public_bits(Curve, Public_bits) ->
    gose:from_xdh_public_bits(Curve, Public_bits).

-file("src/gose/key.gleam", 89).
-spec ec_public_key_from_coordinates(
    kryptos@ec:curve(),
    bitstring(),
    bitstring()
) -> {ok, gose:key(any())} | {error, gose:gose_error()}.
ec_public_key_from_coordinates(Curve, X, Y) ->
    gose:ec_public_key_from_coordinates(Curve, X, Y).

-file("src/gose/key.gleam", 98).
-spec generate_ec(kryptos@ec:curve()) -> gose:key(any()).
generate_ec(Curve) ->
    gose:generate_ec(Curve).

-file("src/gose/key.gleam", 103).
-spec generate_eddsa(kryptos@eddsa:curve()) -> gose:key(any()).
generate_eddsa(Curve) ->
    gose:generate_eddsa(Curve).

-file("src/gose/key.gleam", 108).
-spec generate_hmac_key(gose:hmac_alg()) -> gose:key(any()).
generate_hmac_key(Alg) ->
    gose:generate_hmac_key(Alg).

-file("src/gose/key.gleam", 113).
-spec generate_enc_key(gose:content_alg()) -> gose:key(any()).
generate_enc_key(Enc) ->
    gose:generate_enc_key(Enc).

-file("src/gose/key.gleam", 118).
-spec generate_aes_kw_key(gose:aes_key_size()) -> gose:key(any()).
generate_aes_kw_key(Size) ->
    gose:generate_aes_kw_key(Size).

-file("src/gose/key.gleam", 123).
-spec generate_chacha20_kw_key() -> gose:key(any()).
generate_chacha20_kw_key() ->
    gose:generate_chacha20_kw_key().

-file("src/gose/key.gleam", 128).
-spec generate_rsa(integer()) -> {ok, gose:key(any())} |
    {error, gose:gose_error()}.
generate_rsa(Bits) ->
    gose:generate_rsa(Bits).

-file("src/gose/key.gleam", 133).
-spec generate_xdh(kryptos@xdh:curve()) -> gose:key(any()).
generate_xdh(Curve) ->
    gose:generate_xdh(Curve).

-file("src/gose/key.gleam", 138).
-spec with_alg(gose:key(ACCC), gose:alg()) -> gose:key(ACCC).
with_alg(Key, Alg) ->
    gose:with_alg(Key, Alg).

-file("src/gose/key.gleam", 143).
-spec with_key_ops(gose:key(ACCF), list(gose:key_op())) -> {ok, gose:key(ACCF)} |
    {error, gose:gose_error()}.
with_key_ops(Key, Ops) ->
    gose:with_key_ops(Key, Ops).

-file("src/gose/key.gleam", 151).
-spec with_key_use(gose:key(ACCL), gose:key_use()) -> {ok, gose:key(ACCL)} |
    {error, gose:gose_error()}.
with_key_use(Key, Use_) ->
    gose:with_key_use(Key, Use_).

-file("src/gose/key.gleam", 159).
-spec with_kid(gose:key(any()), binary()) -> gose:key(binary()).
with_kid(Key, Kid) ->
    gose:with_kid(Key, Kid).

-file("src/gose/key.gleam", 164).
-spec with_kid_bits(gose:key(any()), bitstring()) -> gose:key(bitstring()).
with_kid_bits(Key, Kid) ->
    gose:with_kid_bits(Key, Kid).

-file("src/gose/key.gleam", 169).
-spec alg(gose:key(any())) -> {ok, gose:alg()} | {error, nil}.
alg(Key) ->
    gose:alg(Key).

-file("src/gose/key.gleam", 174).
-spec ec_curve(gose:key(any())) -> {ok, kryptos@ec:curve()} |
    {error, gose:gose_error()}.
ec_curve(Key) ->
    gose:ec_curve(Key).

-file("src/gose/key.gleam", 179).
-spec ec_public_key(gose:key(any())) -> {ok, kryptos@ec:public_key()} |
    {error, gose:gose_error()}.
ec_public_key(Key) ->
    gose:ec_public_key(Key).

-file("src/gose/key.gleam", 184).
-spec ec_public_key_coordinates(gose:key(any())) -> {ok,
        {bitstring(), bitstring()}} |
    {error, gose:gose_error()}.
ec_public_key_coordinates(Key) ->
    gose:ec_public_key_coordinates(Key).

-file("src/gose/key.gleam", 191).
-spec eddsa_curve(gose:key(any())) -> {ok, kryptos@eddsa:curve()} |
    {error, gose:gose_error()}.
eddsa_curve(Key) ->
    gose:eddsa_curve(Key).

-file("src/gose/key.gleam", 196).
-spec eddsa_public_key(gose:key(any())) -> {ok, kryptos@eddsa:public_key()} |
    {error, gose:gose_error()}.
eddsa_public_key(Key) ->
    gose:eddsa_public_key(Key).

-file("src/gose/key.gleam", 203).
-spec key_ops(gose:key(any())) -> {ok, list(gose:key_op())} | {error, nil}.
key_ops(Key) ->
    gose:key_ops(Key).

-file("src/gose/key.gleam", 208).
-spec key_type(gose:key(any())) -> gose:key_type().
key_type(Key) ->
    gose:key_type(Key).

-file("src/gose/key.gleam", 213).
-spec key_use(gose:key(any())) -> {ok, gose:key_use()} | {error, nil}.
key_use(Key) ->
    gose:key_use(Key).

-file("src/gose/key.gleam", 218).
-spec kid(gose:key(ACEF)) -> {ok, ACEF} | {error, nil}.
kid(Key) ->
    gose:kid(Key).

-file("src/gose/key.gleam", 223).
-spec octet_key_size(gose:key(any())) -> {ok, integer()} |
    {error, gose:gose_error()}.
octet_key_size(Key) ->
    gose:octet_key_size(Key).

-file("src/gose/key.gleam", 228).
-spec rsa_public_key(gose:key(any())) -> {ok, kryptos@rsa:public_key()} |
    {error, gose:gose_error()}.
rsa_public_key(Key) ->
    gose:rsa_public_key(Key).

-file("src/gose/key.gleam", 235).
-spec xdh_curve(gose:key(any())) -> {ok, kryptos@xdh:curve()} |
    {error, gose:gose_error()}.
xdh_curve(Key) ->
    gose:xdh_curve(Key).

-file("src/gose/key.gleam", 240).
-spec xdh_public_key(gose:key(any())) -> {ok, kryptos@xdh:public_key()} |
    {error, gose:gose_error()}.
xdh_public_key(Key) ->
    gose:xdh_public_key(Key).

-file("src/gose/key.gleam", 247).
-spec public_key(gose:key(ACEZ)) -> {ok, gose:key(ACEZ)} |
    {error, gose:gose_error()}.
public_key(Key) ->
    gose:public_key(Key).

-file("src/gose/key.gleam", 252).
-spec to_der(gose:key(any())) -> {ok, bitstring()} | {error, gose:gose_error()}.
to_der(Key) ->
    gose:to_der(Key).

-file("src/gose/key.gleam", 257).
-spec to_octet_bits(gose:key(any())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
to_octet_bits(Key) ->
    gose:to_octet_bits(Key).

-file("src/gose/key.gleam", 262).
-spec to_pem(gose:key(any())) -> {ok, binary()} | {error, gose:gose_error()}.
to_pem(Key) ->
    gose:to_pem(Key).
