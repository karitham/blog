-module(gose@internal@utils).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/internal/utils.gleam").
-export([decode_base64_url/2, ec_curve_from_string/1, ec_curve_to_string/1, eddsa_curve_from_string/1, eddsa_curve_to_string/1, encode_base64_url/1, strip_leading_zeros/1, validate_crit_headers/3, xdh_curve_from_string/1, xdh_curve_to_string/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(false).

-file("src/gose/internal/utils.gleam", 14).
?DOC(false).
-spec decode_base64_url(binary(), binary()) -> {ok, bitstring()} |
    {error, gose:gose_error()}.
decode_base64_url(B64, Name) ->
    _pipe = gleam@bit_array:base64_url_decode(B64),
    gleam@result:replace_error(
        _pipe,
        {parse_error,
            <<<<"invalid "/utf8, Name/binary>>/binary, " base64"/utf8>>}
    ).

-file("src/gose/internal/utils.gleam", 23).
?DOC(false).
-spec ec_curve_from_string(binary()) -> {ok, kryptos@ec:curve()} |
    {error, gose:gose_error()}.
ec_curve_from_string(S) ->
    case S of
        <<"P-256"/utf8>> ->
            {ok, p256};

        <<"P-384"/utf8>> ->
            {ok, p384};

        <<"P-521"/utf8>> ->
            {ok, p521};

        <<"secp256k1"/utf8>> ->
            {ok, secp256k1};

        _ ->
            {error, {parse_error, <<"unsupported EC curve: "/utf8, S/binary>>}}
    end.

-file("src/gose/internal/utils.gleam", 34).
?DOC(false).
-spec ec_curve_to_string(kryptos@ec:curve()) -> binary().
ec_curve_to_string(Curve) ->
    case Curve of
        p256 ->
            <<"P-256"/utf8>>;

        p384 ->
            <<"P-384"/utf8>>;

        p521 ->
            <<"P-521"/utf8>>;

        secp256k1 ->
            <<"secp256k1"/utf8>>
    end.

-file("src/gose/internal/utils.gleam", 44).
?DOC(false).
-spec eddsa_curve_from_string(binary()) -> {ok, kryptos@eddsa:curve()} |
    {error, gose:gose_error()}.
eddsa_curve_from_string(S) ->
    case S of
        <<"Ed25519"/utf8>> ->
            {ok, ed25519};

        <<"Ed448"/utf8>> ->
            {ok, ed448};

        _ ->
            {error,
                {parse_error, <<"unsupported EdDSA curve: "/utf8, S/binary>>}}
    end.

-file("src/gose/internal/utils.gleam", 53).
?DOC(false).
-spec eddsa_curve_to_string(kryptos@eddsa:curve()) -> binary().
eddsa_curve_to_string(Curve) ->
    case Curve of
        ed25519 ->
            <<"Ed25519"/utf8>>;

        ed448 ->
            <<"Ed448"/utf8>>
    end.

-file("src/gose/internal/utils.gleam", 61).
?DOC(false).
-spec encode_base64_url(bitstring()) -> binary().
encode_base64_url(Data) ->
    gleam@bit_array:base64_url_encode(Data, false).

-file("src/gose/internal/utils.gleam", 66).
?DOC(false).
-spec strip_leading_zeros(bitstring()) -> bitstring().
strip_leading_zeros(Data) ->
    case Data of
        <<0, Rest/bitstring>> ->
            case erlang:byte_size(Rest) > 0 of
                true ->
                    strip_leading_zeros(Rest);

                false ->
                    Data
            end;

        _ ->
            Data
    end.

-file("src/gose/internal/utils.gleam", 81).
?DOC(false).
-spec validate_crit_headers(list(binary()), list(binary()), list(binary())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_crit_headers(Extensions, Standard_headers, Known_extensions) ->
    Standard = gleam@set:from_list(Standard_headers),
    Known = gleam@set:from_list(Known_extensions),
    Crit_set = gleam@set:from_list(Extensions),
    gleam@bool:guard(
        gleam@set:is_empty(Crit_set),
        {error, {parse_error, <<"crit array must not be empty"/utf8>>}},
        fun() ->
            gleam@bool:guard(
                erlang:length(Extensions) /= gleam@set:size(Crit_set),
                {error,
                    {parse_error,
                        <<"crit array contains duplicate values"/utf8>>}},
                fun() ->
                    gleam@list:try_each(
                        Extensions,
                        fun(Header) ->
                            case {gleam@set:contains(Standard, Header),
                                gleam@set:contains(Known, Header)} of
                                {true, _} ->
                                    {error,
                                        {parse_error,
                                            <<"standard header in crit: "/utf8,
                                                Header/binary>>}};

                                {_, true} ->
                                    {ok, nil};

                                {_, false} ->
                                    {error,
                                        {parse_error,
                                            <<"unsupported critical header: "/utf8,
                                                Header/binary>>}}
                            end
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/utils.gleam", 108).
?DOC(false).
-spec xdh_curve_from_string(binary()) -> {ok, kryptos@xdh:curve()} |
    {error, gose:gose_error()}.
xdh_curve_from_string(S) ->
    case S of
        <<"X25519"/utf8>> ->
            {ok, x25519};

        <<"X448"/utf8>> ->
            {ok, x448};

        _ ->
            {error, {parse_error, <<"unsupported XDH curve: "/utf8, S/binary>>}}
    end.

-file("src/gose/internal/utils.gleam", 117).
?DOC(false).
-spec xdh_curve_to_string(kryptos@xdh:curve()) -> binary().
xdh_curve_to_string(Curve) ->
    case Curve of
        x25519 ->
            <<"X25519"/utf8>>;

        x448 ->
            <<"X448"/utf8>>
    end.
