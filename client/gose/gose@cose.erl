-module(gose@cose).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cose.gleam").
-export([content_type_to_cbor/1, header_to_cbor/1, headers_to_cbor/1, algorithm/1, critical/1, content_type/1, kid/1, iv/1, partial_iv/1, header_from_cbor/1, headers_from_cbor/1, ec_curve_to_cose/1, ec_curve_from_cose/1, xdh_curve_to_cose/1, xdh_curve_from_cose/1, signature_alg_to_int/1, signature_alg_from_int/1, mac_alg_to_int/1, mac_alg_from_int/1, signing_alg_to_int/1, signing_alg_from_int/1, key_encryption_alg_to_int/1, key_encryption_alg_from_int/1, content_alg_to_int/1, key_to_cbor_map/1, key_to_cbor/1, content_alg_from_int/1, key_from_cbor_map/1, key_from_cbor/1]).
-export_type([content_type/0, header/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Typed accessors and builders for COSE message header parameters,\n"
    " plus the `Key` alias, COSE_Key CBOR serialization, and COSE algorithm\n"
    " integer ID mapping ([RFC 9053](https://www.rfc-editor.org/rfc/rfc9053.html)).\n"
    "\n"
    " ## Phantom-state vocabulary\n"
    "\n"
    " Each COSE message module uses a phantom state type named after the\n"
    " RFC 9052 operation it performs: `Sign1` uses `Unsigned`/`Signed`,\n"
    " `Encrypt0` and `Encrypt` use `Unencrypted`/`Encrypted`, `Mac0` uses\n"
    " `Untagged`/`Tagged`, and `Sign` uses `Building`/`Signed` for its builder\n"
    " body. The names match the RFC terminology rather than a single uniform\n"
    " vocabulary.\n"
).

-type content_type() :: text_plain |
    octet_stream |
    json |
    cbor |
    cwt |
    cose_sign |
    cose_sign1 |
    cose_encrypt |
    cose_encrypt0 |
    cose_mac |
    cose_mac0 |
    cose_key |
    cose_key_set |
    {int_content_type, integer()} |
    {text_content_type, binary()}.

-type header() :: {alg, integer()} |
    {crit, list(integer())} |
    {content_type, content_type()} |
    {kid, bitstring()} |
    {iv, bitstring()} |
    {partial_iv, bitstring()} |
    {unknown, gose@cbor:value(), gose@cbor:value()}.

-file("src/gose/cose.gleam", 173).
?DOC(false).
-spec content_type_to_cbor(content_type()) -> gose@cbor:value().
content_type_to_cbor(Ct) ->
    case Ct of
        text_plain ->
            {int, 0};

        octet_stream ->
            {int, 42};

        json ->
            {int, 50};

        cbor ->
            {int, 60};

        cwt ->
            {int, 61};

        cose_sign ->
            {int, 101};

        cose_sign1 ->
            {int, 102};

        cose_encrypt ->
            {int, 103};

        cose_encrypt0 ->
            {int, 104};

        cose_mac ->
            {int, 105};

        cose_mac0 ->
            {int, 106};

        cose_key ->
            {int, 10001};

        cose_key_set ->
            {int, 10002};

        {int_content_type, N} ->
            {int, N};

        {text_content_type, S} ->
            {text, S}
    end.

-file("src/gose/cose.gleam", 117).
?DOC(false).
-spec header_to_cbor(header()) -> {gose@cbor:value(), gose@cbor:value()}.
header_to_cbor(Header) ->
    case Header of
        {alg, Id} ->
            {{int, 1}, {int, Id}};

        {crit, Labels} ->
            {{int, 2},
                {array,
                    gleam@list:map(Labels, fun(Field@0) -> {int, Field@0} end)}};

        {content_type, Ct} ->
            {{int, 3}, content_type_to_cbor(Ct)};

        {kid, K} ->
            {{int, 4}, {bytes, K}};

        {iv, V} ->
            {{int, 5}, {bytes, V}};

        {partial_iv, V@1} ->
            {{int, 6}, {bytes, V@1}};

        {unknown, Key, Value} ->
            {Key, Value}
    end.

-file("src/gose/cose.gleam", 168).
?DOC(false).
-spec headers_to_cbor(list(header())) -> list({gose@cbor:value(),
    gose@cbor:value()}).
headers_to_cbor(Headers) ->
    gleam@list:map(Headers, fun header_to_cbor/1).

-file("src/gose/cose.gleam", 193).
-spec content_type_from_cbor(gose@cbor:value()) -> {ok, content_type()} |
    {error, gose:gose_error()}.
content_type_from_cbor(Value) ->
    case Value of
        {int, 0} ->
            {ok, text_plain};

        {int, 42} ->
            {ok, octet_stream};

        {int, 50} ->
            {ok, json};

        {int, 60} ->
            {ok, cbor};

        {int, 61} ->
            {ok, cwt};

        {int, 101} ->
            {ok, cose_sign};

        {int, 102} ->
            {ok, cose_sign1};

        {int, 103} ->
            {ok, cose_encrypt};

        {int, 104} ->
            {ok, cose_encrypt0};

        {int, 105} ->
            {ok, cose_mac};

        {int, 106} ->
            {ok, cose_mac0};

        {int, 10001} ->
            {ok, cose_key};

        {int, 10002} ->
            {ok, cose_key_set};

        {int, N} ->
            {ok, {int_content_type, N}};

        {text, S} ->
            {ok, {text_content_type, S}};

        _ ->
            {error,
                {parse_error,
                    <<"header label 3 (content type): expected Int or Text"/utf8>>}}
    end.

-file("src/gose/cose.gleam", 219).
-spec is_alg(header()) -> boolean().
is_alg(Header) ->
    case Header of
        {alg, _} ->
            true;

        _ ->
            false
    end.

-file("src/gose/cose.gleam", 67).
?DOC(" Extract the algorithm identifier (label 1).\n").
-spec algorithm(list(header())) -> {ok, integer()} | {error, gose:gose_error()}.
algorithm(Headers) ->
    case gleam@list:find(Headers, fun is_alg/1) of
        {ok, {alg, Id}} ->
            {ok, Id};

        _ ->
            {error, {parse_error, <<"missing header label 1 (alg)"/utf8>>}}
    end.

-file("src/gose/cose.gleam", 226).
-spec is_crit(header()) -> boolean().
is_crit(Header) ->
    case Header of
        {crit, _} ->
            true;

        _ ->
            false
    end.

-file("src/gose/cose.gleam", 75).
?DOC(" Extract the critical headers list (label 2).\n").
-spec critical(list(header())) -> {ok, list(integer())} |
    {error, gose:gose_error()}.
critical(Headers) ->
    case gleam@list:find(Headers, fun is_crit/1) of
        {ok, {crit, Labels}} ->
            {ok, Labels};

        _ ->
            {error, {parse_error, <<"missing header label 2 (crit)"/utf8>>}}
    end.

-file("src/gose/cose.gleam", 233).
-spec is_content_type(header()) -> boolean().
is_content_type(Header) ->
    case Header of
        {content_type, _} ->
            true;

        _ ->
            false
    end.

-file("src/gose/cose.gleam", 83).
?DOC(" Extract the content type (label 3).\n").
-spec content_type(list(header())) -> {ok, content_type()} |
    {error, gose:gose_error()}.
content_type(Headers) ->
    case gleam@list:find(Headers, fun is_content_type/1) of
        {ok, {content_type, Ct}} ->
            {ok, Ct};

        _ ->
            {error,
                {parse_error, <<"missing header label 3 (content type)"/utf8>>}}
    end.

-file("src/gose/cose.gleam", 240).
-spec is_kid(header()) -> boolean().
is_kid(Header) ->
    case Header of
        {kid, _} ->
            true;

        _ ->
            false
    end.

-file("src/gose/cose.gleam", 93).
?DOC(" Extract the key ID (label 4).\n").
-spec kid(list(header())) -> {ok, bitstring()} | {error, gose:gose_error()}.
kid(Headers) ->
    case gleam@list:find(Headers, fun is_kid/1) of
        {ok, {kid, K}} ->
            {ok, K};

        _ ->
            {error, {parse_error, <<"missing header label 4 (kid)"/utf8>>}}
    end.

-file("src/gose/cose.gleam", 247).
-spec is_iv(header()) -> boolean().
is_iv(Header) ->
    case Header of
        {iv, _} ->
            true;

        _ ->
            false
    end.

-file("src/gose/cose.gleam", 101).
?DOC(" Extract the IV (label 5).\n").
-spec iv(list(header())) -> {ok, bitstring()} | {error, gose:gose_error()}.
iv(Headers) ->
    case gleam@list:find(Headers, fun is_iv/1) of
        {ok, {iv, V}} ->
            {ok, V};

        _ ->
            {error, {parse_error, <<"missing header label 5 (IV)"/utf8>>}}
    end.

-file("src/gose/cose.gleam", 254).
-spec is_partial_iv(header()) -> boolean().
is_partial_iv(Header) ->
    case Header of
        {partial_iv, _} ->
            true;

        _ ->
            false
    end.

-file("src/gose/cose.gleam", 109).
?DOC(" Extract the partial IV (label 6).\n").
-spec partial_iv(list(header())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
partial_iv(Headers) ->
    case gleam@list:find(Headers, fun is_partial_iv/1) of
        {ok, {partial_iv, V}} ->
            {ok, V};

        _ ->
            {error,
                {parse_error, <<"missing header label 6 (Partial IV)"/utf8>>}}
    end.

-file("src/gose/cose.gleam", 261).
-spec parse_int_list(list(gose@cbor:value()), list(integer())) -> {ok,
        list(integer())} |
    {error, gose:gose_error()}.
parse_int_list(Values, Acc) ->
    case Values of
        [] ->
            {ok, lists:reverse(Acc)};

        [{int, N} | Rest] ->
            parse_int_list(Rest, [N | Acc]);

        _ ->
            {error,
                {parse_error,
                    <<"header label 2 (crit): expected array of Int"/utf8>>}}
    end.

-file("src/gose/cose.gleam", 130).
?DOC(false).
-spec header_from_cbor({gose@cbor:value(), gose@cbor:value()}) -> {ok, header()} |
    {error, gose:gose_error()}.
header_from_cbor(Pair) ->
    case Pair of
        {{int, 1}, {int, Id}} ->
            {ok, {alg, Id}};

        {{int, 1}, _} ->
            {error,
                {parse_error, <<"header label 1 (alg): expected Int"/utf8>>}};

        {{int, 2}, {array, Values}} ->
            gleam@result:map(
                parse_int_list(Values, []),
                fun(Labels) -> {crit, Labels} end
            );

        {{int, 2}, _} ->
            {error,
                {parse_error, <<"header label 2 (crit): expected Array"/utf8>>}};

        {{int, 3}, Value} ->
            gleam@result:map(
                content_type_from_cbor(Value),
                fun(Ct) -> {content_type, Ct} end
            );

        {{int, 4}, {bytes, K}} ->
            {ok, {kid, K}};

        {{int, 4}, _} ->
            {error,
                {parse_error, <<"header label 4 (kid): expected Bytes"/utf8>>}};

        {{int, 5}, {bytes, V}} ->
            {ok, {iv, V}};

        {{int, 5}, _} ->
            {error,
                {parse_error, <<"header label 5 (IV): expected Bytes"/utf8>>}};

        {{int, 6}, {bytes, V@1}} ->
            {ok, {partial_iv, V@1}};

        {{int, 6}, _} ->
            {error,
                {parse_error,
                    <<"header label 6 (Partial IV): expected Bytes"/utf8>>}};

        {Key, Value@1} ->
            {ok, {unknown, Key, Value@1}}
    end.

-file("src/gose/cose.gleam", 161).
?DOC(false).
-spec headers_from_cbor(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        list(header())} |
    {error, gose:gose_error()}.
headers_from_cbor(Pairs) ->
    gleam@list:try_map(Pairs, fun header_from_cbor/1).

-file("src/gose/cose.gleam", 308).
?DOC(false).
-spec ec_curve_to_cose(kryptos@ec:curve()) -> integer().
ec_curve_to_cose(Curve) ->
    case Curve of
        p256 ->
            1;

        p384 ->
            2;

        p521 ->
            3;

        secp256k1 ->
            8
    end.

-file("src/gose/cose.gleam", 318).
?DOC(false).
-spec ec_curve_from_cose(integer()) -> {ok, kryptos@ec:curve()} |
    {error, gose:gose_error()}.
ec_curve_from_cose(Id) ->
    case Id of
        1 ->
            {ok, p256};

        2 ->
            {ok, p384};

        3 ->
            {ok, p521};

        8 ->
            {ok, secp256k1};

        _ ->
            {error,
                {parse_error,
                    <<"unsupported COSE EC curve: "/utf8,
                        (erlang:integer_to_binary(Id))/binary>>}}
    end.

-file("src/gose/cose.gleam", 330).
?DOC(false).
-spec xdh_curve_to_cose(kryptos@xdh:curve()) -> integer().
xdh_curve_to_cose(Curve) ->
    case Curve of
        x25519 ->
            4;

        x448 ->
            5
    end.

-file("src/gose/cose.gleam", 338).
?DOC(false).
-spec xdh_curve_from_cose(integer()) -> {ok, kryptos@xdh:curve()} |
    {error, gose:gose_error()}.
xdh_curve_from_cose(Id) ->
    case Id of
        4 ->
            {ok, x25519};

        5 ->
            {ok, x448};

        _ ->
            {error,
                {parse_error,
                    <<"unsupported COSE XDH curve: "/utf8,
                        (erlang:integer_to_binary(Id))/binary>>}}
    end.

-file("src/gose/cose.gleam", 359).
-spec encode_ec(gose:ec_key_material()) -> list({gose@cbor:value(),
    gose@cbor:value()}).
encode_ec(Mat) ->
    {Curve, Public, Private_d} = case Mat of
        {ec_private, Priv, Public_key, C} ->
            {C, Public_key, {some, Priv}};

        {ec_public, Public_key@1, C@1} ->
            {C@1, Public_key@1, none}
    end,
    Crv_id = ec_curve_to_cose(Curve),
    Raw_point = kryptos_ffi:ec_public_key_to_raw_point(Public),
    Coord_size = kryptos@ec:coordinate_size(Curve),
    X@1 = case gleam_stdlib:bit_array_slice(Raw_point, 1, Coord_size) of
        {ok, X} -> X;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose"/utf8>>,
                        function => <<"encode_ec"/utf8>>,
                        line => 371,
                        value => _assert_fail,
                        start => 10147,
                        'end' => 10207,
                        pattern_start => 10158,
                        pattern_end => 10163})
    end,
    Y@1 = case gleam_stdlib:bit_array_slice(
        Raw_point,
        1 + Coord_size,
        Coord_size
    ) of
        {ok, Y} -> Y;
        _assert_fail@1 ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"gose/cose"/utf8>>,
                        function => <<"encode_ec"/utf8>>,
                        line => 372,
                        value => _assert_fail@1,
                        start => 10210,
                        'end' => 10283,
                        pattern_start => 10221,
                        pattern_end => 10226})
    end,
    Pairs = [{{int, 1}, {int, 2}},
        {{int, -1}, {int, Crv_id}},
        {{int, -2}, {bytes, X@1}},
        {{int, -3}, {bytes, Y@1}}],
    case Private_d of
        {some, Priv@1} ->
            [{{int, -4}, {bytes, kryptos_ffi:ec_private_key_to_bytes(Priv@1)}} |
                Pairs];

        none ->
            Pairs
    end.

-file("src/gose/cose.gleam", 414).
-spec encode_xdh(gose:xdh_key_material()) -> list({gose@cbor:value(),
    gose@cbor:value()}).
encode_xdh(Mat) ->
    {Curve, Public_bytes, Private_d} = case Mat of
        {xdh_private, Priv, Public_key, C} ->
            {C,
                kryptos_ffi:xdh_public_key_to_bytes(Public_key),
                {some, kryptos_ffi:xdh_private_key_to_bytes(Priv)}};

        {xdh_public, Public_key@1, C@1} ->
            {C@1, kryptos_ffi:xdh_public_key_to_bytes(Public_key@1), none}
    end,
    Crv_id = xdh_curve_to_cose(Curve),
    Pairs = [{{int, 1}, {int, 1}},
        {{int, -1}, {int, Crv_id}},
        {{int, -2}, {bytes, Public_bytes}}],
    case Private_d of
        {some, D} ->
            [{{int, -4}, {bytes, D}} | Pairs];

        none ->
            Pairs
    end.

-file("src/gose/cose.gleam", 439).
-spec encode_rsa(gose:rsa_key_material()) -> list({gose@cbor:value(),
    gose@cbor:value()}).
encode_rsa(Mat) ->
    case Mat of
        {rsa_private, Priv, Public_key} ->
            N = gose@internal@utils:strip_leading_zeros(
                kryptos_ffi:rsa_public_key_modulus(Public_key)
            ),
            E = gose@internal@utils:strip_leading_zeros(
                kryptos_ffi:rsa_public_key_exponent_bytes(Public_key)
            ),
            [{{int, 1}, {int, 3}},
                {{int, -1}, {bytes, N}},
                {{int, -2}, {bytes, E}},
                {{int, -3},
                    {bytes,
                        kryptos_ffi:rsa_private_key_private_exponent_bytes(Priv)}},
                {{int, -4}, {bytes, kryptos_ffi:rsa_private_key_prime1(Priv)}},
                {{int, -5}, {bytes, kryptos_ffi:rsa_private_key_prime2(Priv)}},
                {{int, -6},
                    {bytes, kryptos_ffi:rsa_private_key_exponent1(Priv)}},
                {{int, -7},
                    {bytes, kryptos_ffi:rsa_private_key_exponent2(Priv)}},
                {{int, -8},
                    {bytes, kryptos_ffi:rsa_private_key_coefficient(Priv)}}];

        {rsa_public, Public_key@1} ->
            N@1 = gose@internal@utils:strip_leading_zeros(
                kryptos_ffi:rsa_public_key_modulus(Public_key@1)
            ),
            E@1 = gose@internal@utils:strip_leading_zeros(
                kryptos_ffi:rsa_public_key_exponent_bytes(Public_key@1)
            ),
            [{{int, 1}, {int, 3}},
                {{int, -1}, {bytes, N@1}},
                {{int, -2}, {bytes, E@1}}]
    end.

-file("src/gose/cose.gleam", 470).
-spec encode_symmetric(bitstring()) -> list({gose@cbor:value(),
    gose@cbor:value()}).
encode_symmetric(Secret) ->
    [{{int, 1}, {int, 4}}, {{int, -1}, {bytes, Secret}}].

-file("src/gose/cose.gleam", 773).
-spec eddsa_curve_to_cose(kryptos@eddsa:curve()) -> integer().
eddsa_curve_to_cose(Curve) ->
    case Curve of
        ed25519 ->
            6;

        ed448 ->
            7
    end.

-file("src/gose/cose.gleam", 389).
-spec encode_eddsa(gose:eddsa_key_material()) -> list({gose@cbor:value(),
    gose@cbor:value()}).
encode_eddsa(Mat) ->
    {Curve, Public_bytes, Private_d} = case Mat of
        {eddsa_private, Priv, Public_key, C} ->
            {C,
                kryptos_ffi:eddsa_public_key_to_bytes(Public_key),
                {some, kryptos_ffi:eddsa_private_key_to_bytes(Priv)}};

        {eddsa_public, Public_key@1, C@1} ->
            {C@1, kryptos_ffi:eddsa_public_key_to_bytes(Public_key@1), none}
    end,
    Crv_id = eddsa_curve_to_cose(Curve),
    Pairs = [{{int, 1}, {int, 1}},
        {{int, -1}, {int, Crv_id}},
        {{int, -2}, {bytes, Public_bytes}}],
    case Private_d of
        {some, D} ->
            [{{int, -4}, {bytes, D}} | Pairs];

        none ->
            Pairs
    end.

-file("src/gose/cose.gleam", 347).
-spec encode_key_material(gose:key_material()) -> {ok,
        list({gose@cbor:value(), gose@cbor:value()})} |
    {error, gose:gose_error()}.
encode_key_material(Mat) ->
    case Mat of
        {elliptic, Ec_mat} ->
            {ok, encode_ec(Ec_mat)};

        {edwards, Eddsa_mat} ->
            {ok, encode_eddsa(Eddsa_mat)};

        {xdh, Xdh_mat} ->
            {ok, encode_xdh(Xdh_mat)};

        {rsa, Rsa_mat} ->
            {ok, encode_rsa(Rsa_mat)};

        {octet_key, Secret} ->
            {ok, encode_symmetric(Secret)}
    end.

-file("src/gose/cose.gleam", 780).
-spec key_op_to_cose(gose:key_op()) -> integer().
key_op_to_cose(Op) ->
    case Op of
        sign ->
            1;

        verify ->
            2;

        encrypt ->
            3;

        decrypt ->
            4;

        wrap_key ->
            5;

        unwrap_key ->
            6;

        derive_key ->
            7;

        derive_bits ->
            8
    end.

-file("src/gose/cose.gleam", 793).
-spec key_op_from_cose(integer()) -> {ok, gose:key_op()} |
    {error, gose:gose_error()}.
key_op_from_cose(Id) ->
    case Id of
        1 ->
            {ok, sign};

        2 ->
            {ok, verify};

        3 ->
            {ok, encrypt};

        4 ->
            {ok, decrypt};

        5 ->
            {ok, wrap_key};

        6 ->
            {ok, unwrap_key};

        7 ->
            {ok, derive_key};

        8 ->
            {ok, derive_bits};

        _ ->
            {error,
                {parse_error,
                    <<"unknown COSE key_op: "/utf8,
                        (erlang:integer_to_binary(Id))/binary>>}}
    end.

-file("src/gose/cose.gleam", 762).
-spec decode_key_ops(list(gose@cbor:value())) -> {ok, list(gose:key_op())} |
    {error, gose:gose_error()}.
decode_key_ops(Ops) ->
    gleam@list:try_map(Ops, fun(V) -> case V of
                {int, Id} ->
                    key_op_from_cose(Id);

                _ ->
                    {error,
                        {parse_error, <<"key_ops must contain integers"/utf8>>}}
            end end).

-file("src/gose/cose.gleam", 807).
-spec lookup_int(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer(),
    binary()
) -> {ok, integer()} | {error, gose:gose_error()}.
lookup_int(Map, Label, Error_msg) ->
    case gleam@list:key_find(Map, {int, Label}) of
        {ok, {int, Value}} ->
            {ok, Value};

        {ok, _} ->
            {error, {parse_error, <<Error_msg/binary, " (wrong type)"/utf8>>}};

        {error, _} ->
            {error, {parse_error, Error_msg}}
    end.

-file("src/gose/cose.gleam", 819).
-spec lookup_bytes(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer(),
    binary()
) -> {ok, bitstring()} | {error, gose:gose_error()}.
lookup_bytes(Map, Label, Error_msg) ->
    case gleam@list:key_find(Map, {int, Label}) of
        {ok, {bytes, Value}} ->
            {ok, Value};

        {ok, _} ->
            {error, {parse_error, <<Error_msg/binary, " (wrong type)"/utf8>>}};

        {error, _} ->
            {error, {parse_error, Error_msg}}
    end.

-file("src/gose/cose.gleam", 691).
-spec decode_symmetric(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose:key(bitstring())} |
    {error, gose:gose_error()}.
decode_symmetric(Map) ->
    gleam@result:'try'(
        lookup_bytes(Map, -1, <<"missing symmetric key (label -1)"/utf8>>),
        fun(K) -> gose:from_octet_bits(K) end
    ).

-file("src/gose/cose.gleam", 831).
-spec lookup_int_optional(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer()
) -> {ok, gleam@option:option(integer())} | {error, gose:gose_error()}.
lookup_int_optional(Map, Label) ->
    case gleam@list:key_find(Map, {int, Label}) of
        {ok, {int, Value}} ->
            {ok, {some, Value}};

        {ok, _} ->
            {error,
                {parse_error,
                    <<<<"key parameter "/utf8,
                            (erlang:integer_to_binary(Label))/binary>>/binary,
                        " has wrong type"/utf8>>}};

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/cose.gleam", 845).
-spec lookup_bytes_optional(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer()
) -> {ok, gleam@option:option(bitstring())} | {error, gose:gose_error()}.
lookup_bytes_optional(Map, Label) ->
    case gleam@list:key_find(Map, {int, Label}) of
        {ok, {bytes, Value}} ->
            {ok, {some, Value}};

        {ok, _} ->
            {error,
                {parse_error,
                    <<<<"key parameter "/utf8,
                            (erlang:integer_to_binary(Label))/binary>>/binary,
                        " has wrong type"/utf8>>}};

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/cose.gleam", 707).
-spec apply_kid(
    gose:key(bitstring()),
    list({gose@cbor:value(), gose@cbor:value()})
) -> {ok, gose:key(bitstring())} | {error, gose:gose_error()}.
apply_kid(K, Map) ->
    gleam@result:'try'(
        lookup_bytes_optional(Map, 2),
        fun(Opt_kid) -> case Opt_kid of
                {some, Kid_bytes} ->
                    {ok, gose:with_kid_bits(K, Kid_bytes)};

                none ->
                    {ok, K}
            end end
    ).

-file("src/gose/cose.gleam", 859).
-spec lookup_array_optional(
    list({gose@cbor:value(), gose@cbor:value()}),
    integer()
) -> {ok, gleam@option:option(list(gose@cbor:value()))} |
    {error, gose:gose_error()}.
lookup_array_optional(Map, Label) ->
    case gleam@list:key_find(Map, {int, Label}) of
        {ok, {array, Items}} ->
            {ok, {some, Items}};

        {ok, _} ->
            {error,
                {parse_error,
                    <<<<"key parameter "/utf8,
                            (erlang:integer_to_binary(Label))/binary>>/binary,
                        " has wrong type"/utf8>>}};

        {error, _} ->
            {ok, none}
    end.

-file("src/gose/cose.gleam", 732).
-spec apply_key_ops(
    gose:key(bitstring()),
    list({gose@cbor:value(), gose@cbor:value()})
) -> {ok, gose:key(bitstring())} | {error, gose:gose_error()}.
apply_key_ops(K, Map) ->
    gleam@result:'try'(
        lookup_array_optional(Map, 4),
        fun(Opt_ops) -> case Opt_ops of
                {some, Ops_cbor} ->
                    gleam@result:'try'(
                        decode_key_ops(Ops_cbor),
                        fun(Ops) -> gose:with_key_ops(K, Ops) end
                    );

                none ->
                    {ok, K}
            end end
    ).

-file("src/gose/cose.gleam", 873).
-spec has_label(list({gose@cbor:value(), gose@cbor:value()}), integer()) -> boolean().
has_label(Map, Label) ->
    _pipe = gleam@list:key_find(Map, {int, Label}),
    gleam@result:is_ok(_pipe).

-file("src/gose/cose.gleam", 539).
-spec decode_ec2(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose:key(bitstring())} |
    {error, gose:gose_error()}.
decode_ec2(Map) ->
    gleam@result:'try'(
        lookup_int(Map, -1, <<"missing EC curve (label -1)"/utf8>>),
        fun(Crv_id) ->
            gleam@result:'try'(
                ec_curve_from_cose(Crv_id),
                fun(Curve) ->
                    gleam@result:'try'(
                        lookup_bytes(
                            Map,
                            -2,
                            <<"missing EC x (label -2)"/utf8>>
                        ),
                        fun(X) ->
                            gleam@result:'try'(
                                lookup_bytes(
                                    Map,
                                    -3,
                                    <<"missing EC y (label -3)"/utf8>>
                                ),
                                fun(Y) -> case has_label(Map, -4) of
                                        true ->
                                            gleam@result:'try'(
                                                lookup_bytes(
                                                    Map,
                                                    -4,
                                                    <<"missing EC d (label -4)"/utf8>>
                                                ),
                                                fun(D) ->
                                                    gleam@result:'try'(
                                                        begin
                                                            _pipe = kryptos_ffi:ec_private_key_from_bytes(
                                                                Curve,
                                                                D
                                                            ),
                                                            gleam@result:replace_error(
                                                                _pipe,
                                                                {parse_error,
                                                                    <<"invalid EC private key"/utf8>>}
                                                            )
                                                        end,
                                                        fun(_use0) ->
                                                            {Private, Public} = _use0,
                                                            Computed_point = kryptos_ffi:ec_public_key_to_raw_point(
                                                                Public
                                                            ),
                                                            Raw_point = gleam_stdlib:bit_array_concat(
                                                                [<<16#04>>,
                                                                    X,
                                                                    Y]
                                                            ),
                                                            gleam@bool:guard(
                                                                not fun kryptos_ffi:constant_time_equal/2(
                                                                    Computed_point,
                                                                    Raw_point
                                                                ),
                                                                {error,
                                                                    {parse_error,
                                                                        <<"x/y do not match computed public key"/utf8>>}},
                                                                fun() ->
                                                                    {ok,
                                                                        gose:new_key(
                                                                            {elliptic,
                                                                                {ec_private,
                                                                                    Private,
                                                                                    Public,
                                                                                    Curve}}
                                                                        )}
                                                                end
                                                            )
                                                        end
                                                    )
                                                end
                                            );

                                        false ->
                                            gose:ec_public_key_from_coordinates(
                                                Curve,
                                                X,
                                                Y
                                            )
                                    end end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/cose.gleam", 583).
-spec decode_eddsa_key(
    kryptos@eddsa:curve(),
    list({gose@cbor:value(), gose@cbor:value()})
) -> {ok, gose:key(bitstring())} | {error, gose:gose_error()}.
decode_eddsa_key(Curve, Map) ->
    case has_label(Map, -4) of
        true ->
            gleam@result:'try'(
                lookup_bytes(Map, -2, <<"missing EdDSA x (label -2)"/utf8>>),
                fun(X) ->
                    gleam@result:'try'(
                        lookup_bytes(
                            Map,
                            -4,
                            <<"missing EdDSA d (label -4)"/utf8>>
                        ),
                        fun(D) ->
                            gleam@result:'try'(
                                begin
                                    _pipe = kryptos_ffi:eddsa_private_key_from_bytes(
                                        Curve,
                                        D
                                    ),
                                    gleam@result:replace_error(
                                        _pipe,
                                        {parse_error,
                                            <<"invalid EdDSA private key"/utf8>>}
                                    )
                                end,
                                fun(_use0) ->
                                    {Private, Public} = _use0,
                                    Computed_x = kryptos_ffi:eddsa_public_key_to_bytes(
                                        Public
                                    ),
                                    gleam@bool:guard(
                                        not fun kryptos_ffi:constant_time_equal/2(
                                            Computed_x,
                                            X
                                        ),
                                        {error,
                                            {parse_error,
                                                <<"x does not match computed public key"/utf8>>}},
                                        fun() ->
                                            {ok,
                                                gose:new_key(
                                                    {edwards,
                                                        {eddsa_private,
                                                            Private,
                                                            Public,
                                                            Curve}}
                                                )}
                                        end
                                    )
                                end
                            )
                        end
                    )
                end
            );

        false ->
            gleam@result:'try'(
                lookup_bytes(Map, -2, <<"missing EdDSA x (label -2)"/utf8>>),
                fun(X@1) -> gose:from_eddsa_public_bits(Curve, X@1) end
            )
    end.

-file("src/gose/cose.gleam", 613).
-spec decode_xdh_key(
    kryptos@xdh:curve(),
    list({gose@cbor:value(), gose@cbor:value()})
) -> {ok, gose:key(bitstring())} | {error, gose:gose_error()}.
decode_xdh_key(Curve, Map) ->
    case has_label(Map, -4) of
        true ->
            gleam@result:'try'(
                lookup_bytes(Map, -2, <<"missing XDH x (label -2)"/utf8>>),
                fun(X) ->
                    gleam@result:'try'(
                        lookup_bytes(
                            Map,
                            -4,
                            <<"missing XDH d (label -4)"/utf8>>
                        ),
                        fun(D) ->
                            gleam@result:'try'(
                                begin
                                    _pipe = kryptos_ffi:xdh_private_key_from_bytes(
                                        Curve,
                                        D
                                    ),
                                    gleam@result:replace_error(
                                        _pipe,
                                        {parse_error,
                                            <<"invalid XDH private key"/utf8>>}
                                    )
                                end,
                                fun(_use0) ->
                                    {Private, Public} = _use0,
                                    Computed_x = kryptos_ffi:xdh_public_key_to_bytes(
                                        Public
                                    ),
                                    gleam@bool:guard(
                                        not fun kryptos_ffi:constant_time_equal/2(
                                            Computed_x,
                                            X
                                        ),
                                        {error,
                                            {parse_error,
                                                <<"x does not match computed public key"/utf8>>}},
                                        fun() ->
                                            {ok,
                                                gose:new_key(
                                                    {xdh,
                                                        {xdh_private,
                                                            Private,
                                                            Public,
                                                            Curve}}
                                                )}
                                        end
                                    )
                                end
                            )
                        end
                    )
                end
            );

        false ->
            gleam@result:'try'(
                lookup_bytes(Map, -2, <<"missing XDH x (label -2)"/utf8>>),
                fun(X@1) -> gose:from_xdh_public_bits(Curve, X@1) end
            )
    end.

-file("src/gose/cose.gleam", 569).
-spec decode_okp(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose:key(bitstring())} |
    {error, gose:gose_error()}.
decode_okp(Map) ->
    gleam@result:'try'(
        lookup_int(Map, -1, <<"missing OKP curve (label -1)"/utf8>>),
        fun(Crv_id) -> case Crv_id of
                6 ->
                    decode_eddsa_key(ed25519, Map);

                7 ->
                    decode_eddsa_key(ed448, Map);

                4 ->
                    decode_xdh_key(x25519, Map);

                5 ->
                    decode_xdh_key(x448, Map);

                _ ->
                    {error,
                        {parse_error,
                            <<"unsupported OKP curve: "/utf8,
                                (erlang:integer_to_binary(Crv_id))/binary>>}}
            end end
    ).

-file("src/gose/cose.gleam", 657).
-spec decode_rsa_private(
    list({gose@cbor:value(), gose@cbor:value()}),
    bitstring(),
    bitstring()
) -> {ok, gose:key(bitstring())} | {error, gose:gose_error()}.
decode_rsa_private(Map, N, E) ->
    gleam@result:'try'(
        lookup_bytes(Map, -3, <<"missing RSA d (label -3)"/utf8>>),
        fun(D) -> case has_label(Map, -4) of
                true ->
                    gleam@result:'try'(
                        lookup_bytes(
                            Map,
                            -4,
                            <<"missing RSA p (label -4)"/utf8>>
                        ),
                        fun(P) ->
                            gleam@result:'try'(
                                lookup_bytes(
                                    Map,
                                    -5,
                                    <<"missing RSA q (label -5)"/utf8>>
                                ),
                                fun(Q) ->
                                    gleam@result:'try'(
                                        lookup_bytes(
                                            Map,
                                            -6,
                                            <<"missing RSA dp (label -6)"/utf8>>
                                        ),
                                        fun(Dp) ->
                                            gleam@result:'try'(
                                                lookup_bytes(
                                                    Map,
                                                    -7,
                                                    <<"missing RSA dq (label -7)"/utf8>>
                                                ),
                                                fun(Dq) ->
                                                    gleam@result:'try'(
                                                        lookup_bytes(
                                                            Map,
                                                            -8,
                                                            <<"missing RSA qi (label -8)"/utf8>>
                                                        ),
                                                        fun(Qi) ->
                                                            _pipe = kryptos_ffi:rsa_private_key_from_full_components(
                                                                N,
                                                                E,
                                                                D,
                                                                P,
                                                                Q,
                                                                Dp,
                                                                Dq,
                                                                Qi
                                                            ),
                                                            _pipe@1 = gleam@result:replace_error(
                                                                _pipe,
                                                                {parse_error,
                                                                    <<"invalid RSA private key components"/utf8>>}
                                                            ),
                                                            gleam@result:map(
                                                                _pipe@1,
                                                                fun(Pair) ->
                                                                    {Private,
                                                                        Public} = Pair,
                                                                    gose:new_key(
                                                                        {rsa,
                                                                            {rsa_private,
                                                                                Private,
                                                                                Public}}
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

                false ->
                    _pipe@2 = kryptos@rsa:from_components(N, E, D),
                    _pipe@3 = gleam@result:replace_error(
                        _pipe@2,
                        {parse_error,
                            <<"invalid RSA private key components"/utf8>>}
                    ),
                    gleam@result:map(
                        _pipe@3,
                        fun(Pair@1) ->
                            {Private@1, Public@1} = Pair@1,
                            gose:new_key(
                                {rsa, {rsa_private, Private@1, Public@1}}
                            )
                        end
                    )
            end end
    ).

-file("src/gose/cose.gleam", 639).
-spec decode_rsa(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose:key(bitstring())} |
    {error, gose:gose_error()}.
decode_rsa(Map) ->
    gleam@result:'try'(
        lookup_bytes(Map, -1, <<"missing RSA n (label -1)"/utf8>>),
        fun(N) ->
            gleam@result:'try'(
                lookup_bytes(Map, -2, <<"missing RSA e (label -2)"/utf8>>),
                fun(E) -> case has_label(Map, -3) of
                        true ->
                            decode_rsa_private(Map, N, E);

                        false ->
                            _pipe = kryptos_ffi:rsa_public_key_from_components(
                                N,
                                E
                            ),
                            _pipe@1 = gleam@result:replace_error(
                                _pipe,
                                {parse_error,
                                    <<"invalid RSA public key components"/utf8>>}
                            ),
                            gleam@result:map(
                                _pipe@1,
                                fun(Public_key) ->
                                    gose:new_key(
                                        {rsa, {rsa_public, Public_key}}
                                    )
                                end
                            )
                    end end
            )
        end
    ).

-file("src/gose/cose.gleam", 525).
-spec decode_key_by_type(
    integer(),
    list({gose@cbor:value(), gose@cbor:value()})
) -> {ok, gose:key(bitstring())} | {error, gose:gose_error()}.
decode_key_by_type(Kty, Map) ->
    case Kty of
        1 ->
            decode_okp(Map);

        2 ->
            decode_ec2(Map);

        3 ->
            decode_rsa(Map);

        4 ->
            decode_symmetric(Map);

        _ ->
            {error,
                {parse_error,
                    <<"unsupported COSE key type: "/utf8,
                        (erlang:integer_to_binary(Kty))/binary>>}}
    end.

-file("src/gose/cose.gleam", 878).
?DOC(" Convert a signature algorithm to its COSE integer identifier.\n").
-spec signature_alg_to_int(gose:digital_signature_alg()) -> integer().
signature_alg_to_int(Alg) ->
    case Alg of
        {ecdsa, ecdsa_p256} ->
            -7;

        {ecdsa, ecdsa_p384} ->
            -35;

        {ecdsa, ecdsa_p521} ->
            -36;

        {ecdsa, ecdsa_secp256k1} ->
            -47;

        eddsa ->
            -8;

        {rsa_pkcs1, rsa_pkcs1_sha256} ->
            -257;

        {rsa_pkcs1, rsa_pkcs1_sha384} ->
            -258;

        {rsa_pkcs1, rsa_pkcs1_sha512} ->
            -259;

        {rsa_pss, rsa_pss_sha256} ->
            -37;

        {rsa_pss, rsa_pss_sha384} ->
            -38;

        {rsa_pss, rsa_pss_sha512} ->
            -39
    end.

-file("src/gose/cose.gleam", 895).
?DOC(" Parse a signature algorithm from its COSE integer identifier.\n").
-spec signature_alg_from_int(integer()) -> {ok, gose:digital_signature_alg()} |
    {error, gose:gose_error()}.
signature_alg_from_int(Id) ->
    case Id of
        -257 ->
            {ok, {rsa_pkcs1, rsa_pkcs1_sha256}};

        -258 ->
            {ok, {rsa_pkcs1, rsa_pkcs1_sha384}};

        -259 ->
            {ok, {rsa_pkcs1, rsa_pkcs1_sha512}};

        -35 ->
            {ok, {ecdsa, ecdsa_p384}};

        -36 ->
            {ok, {ecdsa, ecdsa_p521}};

        -37 ->
            {ok, {rsa_pss, rsa_pss_sha256}};

        -38 ->
            {ok, {rsa_pss, rsa_pss_sha384}};

        -39 ->
            {ok, {rsa_pss, rsa_pss_sha512}};

        -47 ->
            {ok, {ecdsa, ecdsa_secp256k1}};

        -7 ->
            {ok, {ecdsa, ecdsa_p256}};

        -8 ->
            {ok, eddsa};

        _ ->
            {error,
                {parse_error,
                    <<"unknown COSE signature algorithm: "/utf8,
                        (erlang:integer_to_binary(Id))/binary>>}}
    end.

-file("src/gose/cose.gleam", 918).
?DOC(" Convert a MAC algorithm to its COSE integer identifier.\n").
-spec mac_alg_to_int(gose:mac_alg()) -> integer().
mac_alg_to_int(Alg) ->
    case Alg of
        {hmac, hmac_sha256} ->
            5;

        {hmac, hmac_sha384} ->
            6;

        {hmac, hmac_sha512} ->
            7
    end.

-file("src/gose/cose.gleam", 927).
?DOC(" Parse a MAC algorithm from its COSE integer identifier.\n").
-spec mac_alg_from_int(integer()) -> {ok, gose:mac_alg()} |
    {error, gose:gose_error()}.
mac_alg_from_int(Id) ->
    case Id of
        5 ->
            {ok, {hmac, hmac_sha256}};

        6 ->
            {ok, {hmac, hmac_sha384}};

        7 ->
            {ok, {hmac, hmac_sha512}};

        _ ->
            {error,
                {parse_error,
                    <<"unknown COSE MAC algorithm: "/utf8,
                        (erlang:integer_to_binary(Id))/binary>>}}
    end.

-file("src/gose/cose.gleam", 938).
?DOC(" Convert a signing algorithm to its COSE integer identifier.\n").
-spec signing_alg_to_int(gose:signing_alg()) -> integer().
signing_alg_to_int(Alg) ->
    case Alg of
        {digital_signature, Sig_alg} ->
            signature_alg_to_int(Sig_alg);

        {mac, Mac_alg} ->
            mac_alg_to_int(Mac_alg)
    end.

-file("src/gose/cose.gleam", 946).
?DOC(" Parse a signing algorithm from its COSE integer identifier.\n").
-spec signing_alg_from_int(integer()) -> {ok, gose:signing_alg()} |
    {error, gose:gose_error()}.
signing_alg_from_int(Id) ->
    case signature_alg_from_int(Id) of
        {ok, Alg} ->
            {ok, {digital_signature, Alg}};

        {error, _} ->
            case mac_alg_from_int(Id) of
                {ok, Alg@1} ->
                    {ok, {mac, Alg@1}};

                {error, _} ->
                    {error,
                        {parse_error,
                            <<"unknown COSE signing algorithm: "/utf8,
                                (erlang:integer_to_binary(Id))/binary>>}}
            end
    end.

-file("src/gose/cose.gleam", 964).
?DOC(
    " Convert a key encryption algorithm to its COSE integer identifier.\n"
    "\n"
    " Some key encryption algorithms are JOSE-only and have no COSE\n"
    " identifier, in which case this returns an error.\n"
).
-spec key_encryption_alg_to_int(gose:key_encryption_alg()) -> {ok, integer()} |
    {error, gose:gose_error()}.
key_encryption_alg_to_int(Alg) ->
    case Alg of
        direct ->
            {ok, -6};

        {aes_key_wrap, aes_kw, aes128} ->
            {ok, -3};

        {aes_key_wrap, aes_kw, aes192} ->
            {ok, -4};

        {aes_key_wrap, aes_kw, aes256} ->
            {ok, -5};

        {ecdh_es, ecdh_es_direct} ->
            {ok, -25};

        {ecdh_es, {ecdh_es_aes_kw, aes128}} ->
            {ok, -29};

        {ecdh_es, {ecdh_es_aes_kw, aes192}} ->
            {ok, -30};

        {ecdh_es, {ecdh_es_aes_kw, aes256}} ->
            {ok, -31};

        {rsa_encryption, rsa_oaep_sha1} ->
            {ok, -40};

        {rsa_encryption, rsa_oaep_sha256} ->
            {ok, -41};

        {aes_key_wrap, aes_gcm_kw, _} ->
            {error,
                {invalid_state,
                    <<"no COSE identifier for algorithm: "/utf8,
                        (gleam@string:inspect(Alg))/binary>>}};

        {cha_cha20_key_wrap, _} ->
            {error,
                {invalid_state,
                    <<"no COSE identifier for algorithm: "/utf8,
                        (gleam@string:inspect(Alg))/binary>>}};

        {rsa_encryption, rsa_pkcs1v15} ->
            {error,
                {invalid_state,
                    <<"no COSE identifier for algorithm: "/utf8,
                        (gleam@string:inspect(Alg))/binary>>}};

        {ecdh_es, {ecdh_es_cha_cha20_kw, _}} ->
            {error,
                {invalid_state,
                    <<"no COSE identifier for algorithm: "/utf8,
                        (gleam@string:inspect(Alg))/binary>>}};

        {pbes2, _} ->
            {error,
                {invalid_state,
                    <<"no COSE identifier for algorithm: "/utf8,
                        (gleam@string:inspect(Alg))/binary>>}}
    end.

-file("src/gose/cose.gleam", 997).
?DOC(
    " Parse a key encryption algorithm from its COSE integer identifier.\n"
    "\n"
    " Both ECDH-ES+HKDF-256 (-25) and ECDH-ES+HKDF-512 (-26) map to\n"
    " `EcdhEs(EcdhEsDirect)` because the shared algorithm type does not\n"
    " distinguish the HKDF variant. The HKDF variant is preserved at the\n"
    " `cose/encrypt` layer via `EcdhEsDirectVariant`. Use\n"
    " `new_ecdh_es_direct_recipient` and `ecdh_es_direct_decryptor` for\n"
    " HKDF-512 support.\n"
).
-spec key_encryption_alg_from_int(integer()) -> {ok, gose:key_encryption_alg()} |
    {error, gose:gose_error()}.
key_encryption_alg_from_int(Id) ->
    case Id of
        -25 ->
            {ok, {ecdh_es, ecdh_es_direct}};

        -26 ->
            {ok, {ecdh_es, ecdh_es_direct}};

        -29 ->
            {ok, {ecdh_es, {ecdh_es_aes_kw, aes128}}};

        -3 ->
            {ok, {aes_key_wrap, aes_kw, aes128}};

        -30 ->
            {ok, {ecdh_es, {ecdh_es_aes_kw, aes192}}};

        -31 ->
            {ok, {ecdh_es, {ecdh_es_aes_kw, aes256}}};

        -4 ->
            {ok, {aes_key_wrap, aes_kw, aes192}};

        -5 ->
            {ok, {aes_key_wrap, aes_kw, aes256}};

        -6 ->
            {ok, direct};

        -40 ->
            {ok, {rsa_encryption, rsa_oaep_sha1}};

        -41 ->
            {ok, {rsa_encryption, rsa_oaep_sha256}};

        _ ->
            {error,
                {parse_error,
                    <<"unknown COSE key encryption algorithm: "/utf8,
                        (erlang:integer_to_binary(Id))/binary>>}}
    end.

-file("src/gose/cose.gleam", 1022).
?DOC(
    " Convert a content encryption algorithm to its COSE integer identifier.\n"
    "\n"
    " Some content encryption algorithms are JOSE-only and have no COSE\n"
    " identifier, in which case this returns an error.\n"
).
-spec content_alg_to_int(gose:content_alg()) -> {ok, integer()} |
    {error, gose:gose_error()}.
content_alg_to_int(Alg) ->
    case Alg of
        {aes_gcm, aes128} ->
            {ok, 1};

        {aes_gcm, aes192} ->
            {ok, 2};

        {aes_gcm, aes256} ->
            {ok, 3};

        cha_cha20_poly1305 ->
            {ok, 24};

        {aes_cbc_hmac, _} ->
            {error,
                {invalid_state,
                    <<"no COSE identifier for algorithm: "/utf8,
                        (gleam@string:inspect(Alg))/binary>>}};

        x_cha_cha20_poly1305 ->
            {error,
                {invalid_state,
                    <<"no COSE identifier for algorithm: "/utf8,
                        (gleam@string:inspect(Alg))/binary>>}}
    end.

-file("src/gose/cose.gleam", 506).
-spec encode_alg_metadata(gose:alg()) -> {ok,
        list({gose@cbor:value(), gose@cbor:value()})} |
    {error, gose:gose_error()}.
encode_alg_metadata(Alg) ->
    case Alg of
        {signing_alg, Signing_alg} ->
            {ok, [{{int, 3}, {int, signing_alg_to_int(Signing_alg)}}]};

        {key_encryption_alg, Ke_alg} ->
            gleam@result:map(
                key_encryption_alg_to_int(Ke_alg),
                fun(Id) -> [{{int, 3}, {int, Id}}] end
            );

        {content_alg, Content_alg} ->
            gleam@result:map(
                content_alg_to_int(Content_alg),
                fun(Id@1) -> [{{int, 3}, {int, Id@1}}] end
            )
    end.

-file("src/gose/cose.gleam", 497).
-spec resolve_alg_metadata(gose:key(any())) -> {ok,
        list({gose@cbor:value(), gose@cbor:value()})} |
    {error, gose:gose_error()}.
resolve_alg_metadata(K) ->
    case gose:alg(K) of
        {ok, Alg} ->
            encode_alg_metadata(Alg);

        {error, _} ->
            {ok, []}
    end.

-file("src/gose/cose.gleam", 477).
-spec encode_metadata(gose:key(bitstring())) -> {ok,
        list({gose@cbor:value(), gose@cbor:value()})} |
    {error, gose:gose_error()}.
encode_metadata(K) ->
    Kid_pair = case gose:kid(K) of
        {ok, Kid} ->
            [{{int, 2}, {bytes, Kid}}];

        {error, _} ->
            []
    end,
    gleam@result:'try'(
        resolve_alg_metadata(K),
        fun(Alg_pair) ->
            Ops_pair = case gose:key_ops(K) of
                {ok, Ops} ->
                    [{{int, 4},
                            {array,
                                gleam@list:map(
                                    Ops,
                                    fun(Op) -> {int, key_op_to_cose(Op)} end
                                )}}];

                {error, _} ->
                    []
            end,
            {ok, lists:append([Kid_pair, Alg_pair, Ops_pair])}
        end
    ).

-file("src/gose/cose.gleam", 289).
?DOC(
    " Encode a `Key` to its CBOR map entries, for embedding in larger\n"
    " CBOR structures.\n"
).
-spec key_to_cbor_map(gose:key(bitstring())) -> {ok,
        list({gose@cbor:value(), gose@cbor:value()})} |
    {error, gose:gose_error()}.
key_to_cbor_map(K) ->
    Mat = gose:material(K),
    gleam@result:'try'(
        encode_key_material(Mat),
        fun(Key_pairs) ->
            gleam@result:'try'(
                encode_metadata(K),
                fun(Metadata_pairs) ->
                    {ok, lists:append(Key_pairs, Metadata_pairs)}
                end
            )
        end
    ).

-file("src/gose/cose.gleam", 273).
?DOC(" Encode a `Key` to COSE_Key CBOR bytes ([RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html)).\n").
-spec key_to_cbor(gose:key(bitstring())) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
key_to_cbor(K) ->
    gleam@result:'try'(
        key_to_cbor_map(K),
        fun(Pairs) -> {ok, gose@cbor:encode({map, Pairs})} end
    ).

-file("src/gose/cose.gleam", 1036).
?DOC(" Parse a content encryption algorithm from its COSE integer identifier.\n").
-spec content_alg_from_int(integer()) -> {ok, gose:content_alg()} |
    {error, gose:gose_error()}.
content_alg_from_int(Id) ->
    case Id of
        1 ->
            {ok, {aes_gcm, aes128}};

        2 ->
            {ok, {aes_gcm, aes192}};

        3 ->
            {ok, {aes_gcm, aes256}};

        24 ->
            {ok, cha_cha20_poly1305};

        _ ->
            {error,
                {parse_error,
                    <<"unknown COSE content encryption algorithm: "/utf8,
                        (erlang:integer_to_binary(Id))/binary>>}}
    end.

-file("src/gose/cose.gleam", 746).
-spec decode_alg(integer()) -> {ok, gose:alg()} | {error, gose:gose_error()}.
decode_alg(Id) ->
    case signing_alg_from_int(Id) of
        {ok, Alg} ->
            {ok, {signing_alg, Alg}};

        {error, _} ->
            case key_encryption_alg_from_int(Id) of
                {ok, Alg@1} ->
                    {ok, {key_encryption_alg, Alg@1}};

                {error, _} ->
                    _pipe = content_alg_from_int(Id),
                    _pipe@1 = gleam@result:map(
                        _pipe,
                        fun(Field@0) -> {content_alg, Field@0} end
                    ),
                    gleam@result:replace_error(
                        _pipe@1,
                        {parse_error,
                            <<"unknown COSE algorithm: "/utf8,
                                (erlang:integer_to_binary(Id))/binary>>}
                    )
            end
    end.

-file("src/gose/cose.gleam", 718).
-spec apply_alg(
    gose:key(bitstring()),
    list({gose@cbor:value(), gose@cbor:value()})
) -> {ok, gose:key(bitstring())} | {error, gose:gose_error()}.
apply_alg(K, Map) ->
    gleam@result:'try'(
        lookup_int_optional(Map, 3),
        fun(Opt_alg_id) -> case Opt_alg_id of
                {some, Alg_id} ->
                    gleam@result:map(
                        decode_alg(Alg_id),
                        fun(Alg) -> gose:with_alg(K, Alg) end
                    );

                none ->
                    {ok, K}
            end end
    ).

-file("src/gose/cose.gleam", 698).
-spec apply_metadata(
    gose:key(bitstring()),
    list({gose@cbor:value(), gose@cbor:value()})
) -> {ok, gose:key(bitstring())} | {error, gose:gose_error()}.
apply_metadata(K, Map) ->
    gleam@result:'try'(
        apply_kid(K, Map),
        fun(K@1) ->
            gleam@result:'try'(
                apply_alg(K@1, Map),
                fun(K@2) -> apply_key_ops(K@2, Map) end
            )
        end
    ).

-file("src/gose/cose.gleam", 299).
?DOC(" Decode CBOR map entries to a `Key`.\n").
-spec key_from_cbor_map(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        gose:key(bitstring())} |
    {error, gose:gose_error()}.
key_from_cbor_map(Map) ->
    gleam@result:'try'(
        lookup_int(Map, 1, <<"missing kty (label 1)"/utf8>>),
        fun(Kty) ->
            gleam@result:'try'(
                decode_key_by_type(Kty, Map),
                fun(Base_key) -> apply_metadata(Base_key, Map) end
            )
        end
    ).

-file("src/gose/cose.gleam", 279).
?DOC(" Decode COSE_Key bytes to a `Key`.\n").
-spec key_from_cbor(bitstring()) -> {ok, gose:key(bitstring())} |
    {error, gose:gose_error()}.
key_from_cbor(Data) ->
    gleam@result:'try'(gose@cbor:decode(Data), fun(Value) -> case Value of
                {map, Pairs} ->
                    key_from_cbor_map(Pairs);

                _ ->
                    {error,
                        {parse_error, <<"COSE_Key must be a CBOR map"/utf8>>}}
            end end).
