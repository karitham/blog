-module(gose@cbor).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/cbor.gleam").
-export([to_diagnostic/1, decode_with_remainder/1, decode/1, encode/1]).
-export_type([value/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " CBOR encoding and decoding ([RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)).\n"
    "\n"
    " Used by the COSE layer for binary serialization. The `Value` type\n"
    " represents CBOR data items and is needed for CWT custom claims.\n"
    "\n"
    " Indefinite-length encoding is not supported and will return a parse error.\n"
).

-type value() :: {int, integer()} |
    {bytes, bitstring()} |
    {text, binary()} |
    {array, list(value())} |
    {map, list({value(), value()})} |
    {tag, integer(), value()} |
    {bool, boolean()} |
    {float, float()} |
    null.

-file("src/gose/cbor.gleam", 126).
-spec encode_major_with_argument(integer(), integer()) -> bitstring().
encode_major_with_argument(Major, Value) ->
    Major_bits = erlang:'bsl'(Major, 5),
    case Value of
        V when V < 24 ->
            <<((Major_bits + V))>>;

        V@1 when V@1 < 256 ->
            <<((Major_bits + 24)), V@1>>;

        V@2 when V@2 < 65536 ->
            <<((Major_bits + 25)), V@2:16>>;

        V@3 when V@3 < 4294967296 ->
            <<((Major_bits + 26)), V@3:32>>;

        V@4 ->
            <<((Major_bits + 27)), V@4:64>>
    end.

-file("src/gose/cbor.gleam", 85).
-spec encode_int(integer()) -> bitstring().
encode_int(N) ->
    case N >= 0 of
        true ->
            encode_major_with_argument(0, N);

        false ->
            encode_major_with_argument(1, -1 - N)
    end.

-file("src/gose/cbor.gleam", 92).
-spec encode_bytes(bitstring()) -> bitstring().
encode_bytes(B) ->
    Length = erlang:byte_size(B),
    gleam@bit_array:append(encode_major_with_argument(2, Length), B).

-file("src/gose/cbor.gleam", 97).
-spec encode_text(binary()) -> bitstring().
encode_text(S) ->
    Bytes = gleam_stdlib:identity(S),
    Length = erlang:byte_size(Bytes),
    gleam@bit_array:append(encode_major_with_argument(3, Length), Bytes).

-file("src/gose/cbor.gleam", 145).
-spec compare_bit_arrays(bitstring(), bitstring()) -> gleam@order:order().
compare_bit_arrays(A, B) ->
    case {A, B} of
        {<<>>, <<>>} ->
            eq;

        {<<>>, _} ->
            lt;

        {_, <<>>} ->
            gt;

        {<<Byte_a, Rest_a/bitstring>>, <<Byte_b, Rest_b/bitstring>>} ->
            case gleam@int:compare(Byte_a, Byte_b) of
                eq ->
                    compare_bit_arrays(Rest_a, Rest_b);

                Other ->
                    Other
            end;

        {_, _} ->
            erlang:error(#{gleam_error => panic,
                    message => <<"non-byte-aligned CBOR in map key sort"/utf8>>,
                    file => <<?FILEPATH/utf8>>,
                    module => <<"gose/cbor"/utf8>>,
                    function => <<"compare_bit_arrays"/utf8>>,
                    line => 155})
    end.

-file("src/gose/cbor.gleam", 180).
-spec decode_argument(integer(), bitstring()) -> {ok, {integer(), bitstring()}} |
    {error, gose:gose_error()}.
decode_argument(Info, Rest) ->
    case Info of
        N when N < 24 ->
            {ok, {N, Rest}};

        24 ->
            case Rest of
                <<Value, Remainder/bitstring>> ->
                    {ok, {Value, Remainder}};

                _ ->
                    {error, {parse_error, <<"truncated CBOR argument"/utf8>>}}
            end;

        25 ->
            case Rest of
                <<Value@1:16, Remainder@1/bitstring>> ->
                    {ok, {Value@1, Remainder@1}};

                _ ->
                    {error, {parse_error, <<"truncated CBOR argument"/utf8>>}}
            end;

        26 ->
            case Rest of
                <<Value@2:32, Remainder@2/bitstring>> ->
                    {ok, {Value@2, Remainder@2}};

                _ ->
                    {error, {parse_error, <<"truncated CBOR argument"/utf8>>}}
            end;

        27 ->
            case Rest of
                <<Value@3:64, Remainder@3/bitstring>> ->
                    {ok, {Value@3, Remainder@3}};

                _ ->
                    {error, {parse_error, <<"truncated CBOR argument"/utf8>>}}
            end;

        _ ->
            {error,
                {parse_error,
                    <<"invalid CBOR additional info: "/utf8,
                        (erlang:integer_to_binary(Info))/binary>>}}
    end.

-file("src/gose/cbor.gleam", 213).
-spec decode_unsigned_int(integer(), bitstring()) -> {ok,
        {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_unsigned_int(Info, Rest) ->
    gleam@result:'try'(
        decode_argument(Info, Rest),
        fun(_use0) ->
            {Value, Remainder} = _use0,
            {ok, {{int, Value}, Remainder}}
        end
    ).

-file("src/gose/cbor.gleam", 221).
-spec decode_negative_int(integer(), bitstring()) -> {ok,
        {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_negative_int(Info, Rest) ->
    gleam@result:'try'(
        decode_argument(Info, Rest),
        fun(_use0) ->
            {Value, Remainder} = _use0,
            {ok, {{int, -1 - Value}, Remainder}}
        end
    ).

-file("src/gose/cbor.gleam", 229).
-spec decode_byte_string(integer(), bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_byte_string(Info, Rest) ->
    gleam@result:'try'(
        decode_argument(Info, Rest),
        fun(_use0) ->
            {Length, After_length} = _use0,
            Remaining_size = erlang:byte_size(After_length),
            case Length > Remaining_size of
                true ->
                    {error,
                        {parse_error, <<"truncated CBOR byte string"/utf8>>}};

                false ->
                    Bytes@1 = case gleam_stdlib:bit_array_slice(
                        After_length,
                        0,
                        Length
                    ) of
                        {ok, Bytes} -> Bytes;
                        _assert_fail ->
                            erlang:error(#{gleam_error => let_assert,
                                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                        file => <<?FILEPATH/utf8>>,
                                        module => <<"gose/cbor"/utf8>>,
                                        function => <<"decode_byte_string"/utf8>>,
                                        line => 238,
                                        value => _assert_fail,
                                        start => 6919,
                                        'end' => 6982,
                                        pattern_start => 6930,
                                        pattern_end => 6939})
                    end,
                    Remainder@1 = case gleam_stdlib:bit_array_slice(
                        After_length,
                        Length,
                        Remaining_size - Length
                    ) of
                        {ok, Remainder} -> Remainder;
                        _assert_fail@1 ->
                            erlang:error(#{gleam_error => let_assert,
                                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                        file => <<?FILEPATH/utf8>>,
                                        module => <<"gose/cbor"/utf8>>,
                                        function => <<"decode_byte_string"/utf8>>,
                                        line => 239,
                                        value => _assert_fail@1,
                                        start => 6989,
                                        'end' => 7086,
                                        pattern_start => 7000,
                                        pattern_end => 7013})
                    end,
                    {ok, {{bytes, Bytes@1}, Remainder@1}}
            end
        end
    ).

-file("src/gose/cbor.gleam", 246).
-spec decode_text_string(integer(), bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_text_string(Info, Rest) ->
    gleam@result:'try'(
        decode_argument(Info, Rest),
        fun(_use0) ->
            {Length, After_length} = _use0,
            Remaining_size = erlang:byte_size(After_length),
            case Length > Remaining_size of
                true ->
                    {error,
                        {parse_error, <<"truncated CBOR text string"/utf8>>}};

                false ->
                    Bytes@1 = case gleam_stdlib:bit_array_slice(
                        After_length,
                        0,
                        Length
                    ) of
                        {ok, Bytes} -> Bytes;
                        _assert_fail ->
                            erlang:error(#{gleam_error => let_assert,
                                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                        file => <<?FILEPATH/utf8>>,
                                        module => <<"gose/cbor"/utf8>>,
                                        function => <<"decode_text_string"/utf8>>,
                                        line => 255,
                                        value => _assert_fail,
                                        start => 7490,
                                        'end' => 7553,
                                        pattern_start => 7501,
                                        pattern_end => 7510})
                    end,
                    Remainder@1 = case gleam_stdlib:bit_array_slice(
                        After_length,
                        Length,
                        Remaining_size - Length
                    ) of
                        {ok, Remainder} -> Remainder;
                        _assert_fail@1 ->
                            erlang:error(#{gleam_error => let_assert,
                                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                                        file => <<?FILEPATH/utf8>>,
                                        module => <<"gose/cbor"/utf8>>,
                                        function => <<"decode_text_string"/utf8>>,
                                        line => 256,
                                        value => _assert_fail@1,
                                        start => 7560,
                                        'end' => 7657,
                                        pattern_start => 7571,
                                        pattern_end => 7584})
                    end,
                    case gleam@bit_array:to_string(Bytes@1) of
                        {ok, Text} ->
                            {ok, {{text, Text}, Remainder@1}};

                        {error, _} ->
                            {error,
                                {parse_error,
                                    <<"invalid UTF-8 in CBOR text string"/utf8>>}}
                    end
            end
        end
    ).

-file("src/gose/cbor.gleam", 398).
-spec do_exp2(integer(), float()) -> float().
do_exp2(N, Acc) ->
    case N of
        0 ->
            Acc;

        _ when N > 0 ->
            do_exp2(N - 1, Acc * 2.0);

        _ ->
            do_exp2(N + 1, Acc / 2.0)
    end.

-file("src/gose/cbor.gleam", 394).
-spec exp2(integer()) -> float().
exp2(N) ->
    do_exp2(N, 1.0).

-file("src/gose/cbor.gleam", 368).
-spec convert_f16_to_f64(integer(), integer(), integer()) -> {ok, float()} |
    {error, gose:gose_error()}.
convert_f16_to_f64(Sign, Exponent, Mantissa) ->
    Sign_factor = case Sign of
        0 ->
            1.0;

        _ ->
            -1.0
    end,
    case Exponent of
        0 ->
            case Mantissa of
                0 ->
                    {ok, Sign_factor * +0.0};

                _ ->
                    M = erlang:float(Mantissa) / 1024.0,
                    {ok, (Sign_factor * M) * exp2(-14)}
            end;

        31 ->
            {error,
                {parse_error, <<"NaN and Infinity are not supported"/utf8>>}};

        _ ->
            M@1 = 1.0 + (erlang:float(Mantissa) / 1024.0),
            {ok, (Sign_factor * M@1) * exp2(Exponent - 15)}
    end.

-file("src/gose/cbor.gleam", 358).
-spec decode_f16(bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_f16(Rest) ->
    case Rest of
        <<Sign:1, Exponent:5, Mantissa:10, Remainder/bitstring>> ->
            gleam@result:'try'(
                convert_f16_to_f64(Sign, Exponent, Mantissa),
                fun(F) -> {ok, {{float, F}, Remainder}} end
            );

        _ ->
            {error, {parse_error, <<"truncated CBOR float16"/utf8>>}}
    end.

-file("src/gose/cbor.gleam", 406).
-spec decode_f32(bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_f32(Rest) ->
    case Rest of
        <<_:1, 255:8, _:23, _/bitstring>> ->
            {error,
                {parse_error, <<"NaN and Infinity are not supported"/utf8>>}};

        <<F:32/float, Remainder/bitstring>> ->
            {ok, {{float, F}, Remainder}};

        _ ->
            {error, {parse_error, <<"truncated CBOR float32"/utf8>>}}
    end.

-file("src/gose/cbor.gleam", 415).
-spec decode_f64(bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_f64(Rest) ->
    case Rest of
        <<_:1, 2047:11, _:52, _/bitstring>> ->
            {error,
                {parse_error, <<"NaN and Infinity are not supported"/utf8>>}};

        <<F/float, Remainder/bitstring>> ->
            {ok, {{float, F}, Remainder}};

        _ ->
            {error, {parse_error, <<"truncated CBOR float64"/utf8>>}}
    end.

-file("src/gose/cbor.gleam", 340).
-spec decode_simple(integer(), bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_simple(Info, Rest) ->
    case Info of
        20 ->
            {ok, {{bool, false}, Rest}};

        21 ->
            {ok, {{bool, true}, Rest}};

        22 ->
            {ok, {null, Rest}};

        25 ->
            decode_f16(Rest);

        26 ->
            decode_f32(Rest);

        27 ->
            decode_f64(Rest);

        _ ->
            {error,
                {parse_error,
                    <<"unsupported CBOR simple value: "/utf8,
                        (erlang:integer_to_binary(Info))/binary>>}}
    end.

-file("src/gose/cbor.gleam", 426).
?DOC(false).
-spec to_diagnostic(value()) -> binary().
to_diagnostic(Value) ->
    case Value of
        {int, N} ->
            erlang:integer_to_binary(N);

        {bytes, B} ->
            <<<<"h'"/utf8,
                    (begin
                        _pipe = gleam_stdlib:base16_encode(B),
                        string:lowercase(_pipe)
                    end)/binary>>/binary,
                "'"/utf8>>;

        {text, S} ->
            <<<<"\""/utf8, S/binary>>/binary, "\""/utf8>>;

        {array, Items} ->
            <<<<"["/utf8,
                    (gleam@string:join(
                        gleam@list:map(Items, fun to_diagnostic/1),
                        <<", "/utf8>>
                    ))/binary>>/binary,
                "]"/utf8>>;

        {map, Pairs} ->
            <<<<"{"/utf8,
                    (gleam@string:join(
                        gleam@list:map(
                            Pairs,
                            fun(Pair) ->
                                <<<<(to_diagnostic(erlang:element(1, Pair)))/binary,
                                        ": "/utf8>>/binary,
                                    (to_diagnostic(erlang:element(2, Pair)))/binary>>
                            end
                        ),
                        <<", "/utf8>>
                    ))/binary>>/binary,
                "}"/utf8>>;

        {tag, Tag, Content} ->
            <<<<<<(erlang:integer_to_binary(Tag))/binary, "("/utf8>>/binary,
                    (to_diagnostic(Content))/binary>>/binary,
                ")"/utf8>>;

        {bool, true} ->
            <<"true"/utf8>>;

        {bool, false} ->
            <<"false"/utf8>>;

        {float, F} ->
            gleam_stdlib:float_to_string(F);

        null ->
            <<"null"/utf8>>
    end.

-file("src/gose/cbor.gleam", 282).
-spec decode_n_items_loop(integer(), bitstring(), list(value())) -> {ok,
        {list(value()), bitstring()}} |
    {error, gose:gose_error()}.
decode_n_items_loop(Remaining, Data, Acc) ->
    case Remaining of
        0 ->
            {ok, {lists:reverse(Acc), Data}};

        _ ->
            gleam@result:'try'(
                decode_with_remainder(Data),
                fun(_use0) ->
                    {Item, Rest} = _use0,
                    decode_n_items_loop(Remaining - 1, Rest, [Item | Acc])
                end
            )
    end.

-file("src/gose/cbor.gleam", 74).
?DOC(false).
-spec decode_with_remainder(bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_with_remainder(Data) ->
    case Data of
        <<>> ->
            {error, {parse_error, <<"unexpected end of CBOR input"/utf8>>}};

        <<Major:3, Info:5, Rest/bitstring>> ->
            decode_major(Major, Info, Rest);

        _ ->
            {error, {parse_error, <<"truncated CBOR input"/utf8>>}}
    end.

-file("src/gose/cbor.gleam", 159).
-spec decode_major(integer(), integer(), bitstring()) -> {ok,
        {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_major(Major, Info, Rest) ->
    case Major of
        0 ->
            decode_unsigned_int(Info, Rest);

        1 ->
            decode_negative_int(Info, Rest);

        2 ->
            decode_byte_string(Info, Rest);

        3 ->
            decode_text_string(Info, Rest);

        4 ->
            decode_array(Info, Rest);

        5 ->
            decode_map(Info, Rest);

        6 ->
            decode_tag(Info, Rest);

        7 ->
            decode_simple(Info, Rest);

        _ ->
            {error,
                {parse_error,
                    <<"unsupported CBOR major type: "/utf8,
                        (erlang:integer_to_binary(Major))/binary>>}}
    end.

-file("src/gose/cbor.gleam", 266).
-spec decode_array(integer(), bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_array(Info, Rest) ->
    gleam@result:'try'(
        decode_argument(Info, Rest),
        fun(_use0) ->
            {Length, After_length} = _use0,
            gleam@result:'try'(
                decode_n_items(Length, After_length),
                fun(_use0@1) ->
                    {Items, Remainder} = _use0@1,
                    {ok, {{array, Items}, Remainder}}
                end
            )
        end
    ).

-file("src/gose/cbor.gleam", 275).
-spec decode_n_items(integer(), bitstring()) -> {ok,
        {list(value()), bitstring()}} |
    {error, gose:gose_error()}.
decode_n_items(Count, Data) ->
    decode_n_items_loop(Count, Data, []).

-file("src/gose/cbor.gleam", 64).
?DOC(false).
-spec decode(bitstring()) -> {ok, value()} | {error, gose:gose_error()}.
decode(Data) ->
    gleam@result:'try'(
        decode_with_remainder(Data),
        fun(_use0) ->
            {Value, Remainder} = _use0,
            case erlang:byte_size(Remainder) of
                0 ->
                    {ok, Value};

                _ ->
                    {error,
                        {parse_error,
                            <<"trailing bytes after CBOR value"/utf8>>}}
            end
        end
    ).

-file("src/gose/cbor.gleam", 316).
-spec decode_n_pairs_loop(integer(), bitstring(), list({value(), value()})) -> {ok,
        {list({value(), value()}), bitstring()}} |
    {error, gose:gose_error()}.
decode_n_pairs_loop(Remaining, Data, Acc) ->
    case Remaining of
        0 ->
            {ok, {lists:reverse(Acc), Data}};

        _ ->
            gleam@result:'try'(
                decode_with_remainder(Data),
                fun(_use0) ->
                    {Key, After_key} = _use0,
                    gleam@result:'try'(
                        decode_with_remainder(After_key),
                        fun(_use0@1) ->
                            {Value, After_value} = _use0@1,
                            decode_n_pairs_loop(
                                Remaining - 1,
                                After_value,
                                [{Key, Value} | Acc]
                            )
                        end
                    )
                end
            )
    end.

-file("src/gose/cbor.gleam", 309).
-spec decode_n_pairs(integer(), bitstring()) -> {ok,
        {list({value(), value()}), bitstring()}} |
    {error, gose:gose_error()}.
decode_n_pairs(Count, Data) ->
    decode_n_pairs_loop(Count, Data, []).

-file("src/gose/cbor.gleam", 296).
-spec decode_map(integer(), bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_map(Info, Rest) ->
    gleam@result:'try'(
        decode_argument(Info, Rest),
        fun(_use0) ->
            {Length, After_length} = _use0,
            gleam@result:'try'(
                decode_n_pairs(Length, After_length),
                fun(_use0@1) ->
                    {Pairs, Remainder} = _use0@1,
                    Keys = gleam@list:map(Pairs, fun gleam@pair:first/1),
                    case erlang:length(gleam@list:unique(Keys)) =:= erlang:length(
                        Keys
                    ) of
                        true ->
                            {ok, {{map, Pairs}, Remainder}};

                        false ->
                            {error,
                                {parse_error,
                                    <<"CBOR map contains duplicate keys"/utf8>>}}
                    end
                end
            )
        end
    ).

-file("src/gose/cbor.gleam", 331).
-spec decode_tag(integer(), bitstring()) -> {ok, {value(), bitstring()}} |
    {error, gose:gose_error()}.
decode_tag(Info, Rest) ->
    gleam@result:'try'(
        decode_argument(Info, Rest),
        fun(_use0) ->
            {Tag_number, After_tag} = _use0,
            gleam@result:'try'(
                decode_with_remainder(After_tag),
                fun(_use0@1) ->
                    {Content, Remainder} = _use0@1,
                    {ok, {{tag, Tag_number, Content}, Remainder}}
                end
            )
        end
    ).

-file("src/gose/cbor.gleam", 103).
-spec encode_array(list(value())) -> bitstring().
encode_array(Items) ->
    Length = erlang:length(Items),
    Header = encode_major_with_argument(4, Length),
    Encoded_items = gleam@list:map(Items, fun encode/1),
    gleam@list:fold(Encoded_items, Header, fun gleam@bit_array:append/2).

-file("src/gose/cbor.gleam", 46).
?DOC(false).
-spec encode(value()) -> bitstring().
encode(Value) ->
    case Value of
        {int, N} ->
            encode_int(N);

        {bytes, B} ->
            encode_bytes(B);

        {text, S} ->
            encode_text(S);

        {array, Items} ->
            encode_array(Items);

        {map, Pairs} ->
            encode_map(Pairs);

        {tag, Tag, Content} ->
            encode_tag(Tag, Content);

        {bool, true} ->
            <<16#f5>>;

        {bool, false} ->
            <<16#f4>>;

        {float, F} ->
            <<16#fb, F/float>>;

        null ->
            <<16#f6>>
    end.

-file("src/gose/cbor.gleam", 122).
-spec encode_tag(integer(), value()) -> bitstring().
encode_tag(Tag, Content) ->
    gleam@bit_array:append(encode_major_with_argument(6, Tag), encode(Content)).

-file("src/gose/cbor.gleam", 137).
-spec sort_map_pairs(list({value(), value()})) -> list({value(), value()}).
sort_map_pairs(Pairs) ->
    gleam@list:sort(
        Pairs,
        fun(A, B) ->
            Encoded_a = encode(erlang:element(1, A)),
            Encoded_b = encode(erlang:element(1, B)),
            compare_bit_arrays(Encoded_a, Encoded_b)
        end
    ).

-file("src/gose/cbor.gleam", 110).
-spec encode_map(list({value(), value()})) -> bitstring().
encode_map(Pairs) ->
    Sorted = sort_map_pairs(Pairs),
    Length = erlang:length(Sorted),
    Header = encode_major_with_argument(5, Length),
    gleam@list:fold(
        Sorted,
        Header,
        fun(Acc, Pair) ->
            {K, V} = Pair,
            _pipe = Acc,
            _pipe@1 = gleam@bit_array:append(_pipe, encode(K)),
            gleam@bit_array:append(_pipe@1, encode(V))
        end
    ).
