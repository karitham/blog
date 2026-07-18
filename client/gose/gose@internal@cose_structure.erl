-module(gose@internal@cose_structure).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/internal/cose_structure.gleam").
-export([serialize_protected/1, decode_protected/1, decode_unprotected/1, validate_no_header_overlap/2, validate_iv_partial_iv_exclusion/2, extract_signing_alg_from_headers/1, extract_signature_alg_from_headers/1, extract_content_alg_from_headers/1, extract_key_encryption_alg_from_headers/1, extract_signature_alg_from_serialized/1, extract_signing_alg_from_serialized/1, extract_content_alg_from_serialized/1, extract_key_encryption_alg_from_serialized/1, decode_payload/1, try_verify_keys/4, parse_cose_array_value/3, parse_cose_array/3, require_embedded_payload/1, require_detached_payload/1, build_enc_structure/3, split_ciphertext_tag/2, validate_crit/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(false).

-file("src/gose/internal/cose_structure.gleam", 14).
?DOC(false).
-spec serialize_protected(list(gose@cose:header())) -> bitstring().
serialize_protected(Headers) ->
    case Headers of
        [] ->
            <<>>;

        _ ->
            gose@cbor:encode({map, gose@cose:headers_to_cbor(Headers)})
    end.

-file("src/gose/internal/cose_structure.gleam", 21).
?DOC(false).
-spec decode_protected(bitstring()) -> {ok, list(gose@cose:header())} |
    {error, gose:gose_error()}.
decode_protected(Data) ->
    case erlang:byte_size(Data) of
        0 ->
            {ok, []};

        _ ->
            gleam@result:'try'(
                gose@cbor:decode(Data),
                fun(Value) -> case Value of
                        {map, []} ->
                            {error,
                                {parse_error,
                                    <<"empty protected header must be encoded as the empty bstr"/utf8>>}};

                        {map, Pairs} ->
                            gose@cose:headers_from_cbor(Pairs);

                        _ ->
                            {error,
                                {parse_error,
                                    <<"protected header is not a CBOR map"/utf8>>}}
                    end end
            )
    end.

-file("src/gose/internal/cose_structure.gleam", 40).
?DOC(false).
-spec decode_unprotected(list({gose@cbor:value(), gose@cbor:value()})) -> {ok,
        list(gose@cose:header())} |
    {error, gose:gose_error()}.
decode_unprotected(Pairs) ->
    gose@cose:headers_from_cbor(Pairs).

-file("src/gose/internal/cose_structure.gleam", 46).
?DOC(false).
-spec validate_no_header_overlap(
    list(gose@cose:header()),
    list(gose@cose:header())
) -> {ok, nil} | {error, gose:gose_error()}.
validate_no_header_overlap(Protected, Unprotected) ->
    Protected_cbor = gose@cose:headers_to_cbor(Protected),
    Unprotected_cbor = gose@cose:headers_to_cbor(Unprotected),
    Protected_keys = gleam@list:map(Protected_cbor, fun gleam@pair:first/1),
    Has_overlap = gleam@list:any(
        Unprotected_cbor,
        fun(Entry) ->
            gleam@list:contains(Protected_keys, erlang:element(1, Entry))
        end
    ),
    gleam@bool:guard(
        Has_overlap,
        {error,
            {parse_error,
                <<"duplicate label in protected and unprotected headers"/utf8>>}},
        fun() -> {ok, nil} end
    ).

-file("src/gose/internal/cose_structure.gleam", 66).
?DOC(false).
-spec validate_iv_partial_iv_exclusion(
    list(gose@cose:header()),
    list(gose@cose:header())
) -> {ok, nil} | {error, gose:gose_error()}.
validate_iv_partial_iv_exclusion(Protected, Unprotected) ->
    All_headers = lists:append(Protected, Unprotected),
    Has_iv = gleam@list:any(All_headers, fun(H) -> case H of
                {iv, _} ->
                    true;

                _ ->
                    false
            end end),
    Has_partial_iv = gleam@list:any(All_headers, fun(H@1) -> case H@1 of
                {partial_iv, _} ->
                    true;

                _ ->
                    false
            end end),
    gleam@bool:guard(
        Has_iv andalso Has_partial_iv,
        {error,
            {parse_error, <<"IV and Partial IV must not both be present"/utf8>>}},
        fun() -> {ok, nil} end
    ).

-file("src/gose/internal/cose_structure.gleam", 158).
?DOC(false).
-spec extract_signing_alg_from_headers(list(gose@cose:header())) -> {ok,
        gose:signing_alg()} |
    {error, gose:gose_error()}.
extract_signing_alg_from_headers(Headers) ->
    gleam@result:'try'(
        gose@cose:algorithm(Headers),
        fun(Id) -> gose@cose:signing_alg_from_int(Id) end
    ).

-file("src/gose/internal/cose_structure.gleam", 165).
?DOC(false).
-spec extract_signature_alg_from_headers(list(gose@cose:header())) -> {ok,
        gose:digital_signature_alg()} |
    {error, gose:gose_error()}.
extract_signature_alg_from_headers(Headers) ->
    gleam@result:'try'(
        gose@cose:algorithm(Headers),
        fun(Id) -> gose@cose:signature_alg_from_int(Id) end
    ).

-file("src/gose/internal/cose_structure.gleam", 181).
?DOC(false).
-spec extract_content_alg_from_headers(list(gose@cose:header())) -> {ok,
        gose:content_alg()} |
    {error, gose:gose_error()}.
extract_content_alg_from_headers(Headers) ->
    gleam@result:'try'(
        gose@cose:algorithm(Headers),
        fun(Id) -> gose@cose:content_alg_from_int(Id) end
    ).

-file("src/gose/internal/cose_structure.gleam", 200).
?DOC(false).
-spec extract_key_encryption_alg_from_headers(list(gose@cose:header())) -> {ok,
        gose:key_encryption_alg()} |
    {error, gose:gose_error()}.
extract_key_encryption_alg_from_headers(Headers) ->
    gleam@result:'try'(
        gose@cose:algorithm(Headers),
        fun(Id) -> gose@cose:key_encryption_alg_from_int(Id) end
    ).

-file("src/gose/internal/cose_structure.gleam", 216).
?DOC(false).
-spec with_decoded_protected(
    bitstring(),
    fun((list(gose@cose:header())) -> {ok, NTK} | {error, gose:gose_error()})
) -> {ok, NTK} | {error, gose:gose_error()}.
with_decoded_protected(Protected_serialized, Extract) ->
    case erlang:byte_size(Protected_serialized) of
        0 ->
            {error,
                {parse_error, <<"empty protected header, no alg found"/utf8>>}};

        _ ->
            gleam@result:'try'(
                decode_protected(Protected_serialized),
                fun(Headers) -> Extract(Headers) end
            )
    end.

-file("src/gose/internal/cose_structure.gleam", 172).
?DOC(false).
-spec extract_signature_alg_from_serialized(bitstring()) -> {ok,
        gose:digital_signature_alg()} |
    {error, gose:gose_error()}.
extract_signature_alg_from_serialized(Protected_serialized) ->
    with_decoded_protected(
        Protected_serialized,
        fun extract_signature_alg_from_headers/1
    ).

-file("src/gose/internal/cose_structure.gleam", 188).
?DOC(false).
-spec extract_signing_alg_from_serialized(bitstring()) -> {ok,
        gose:signing_alg()} |
    {error, gose:gose_error()}.
extract_signing_alg_from_serialized(Protected_serialized) ->
    with_decoded_protected(
        Protected_serialized,
        fun extract_signing_alg_from_headers/1
    ).

-file("src/gose/internal/cose_structure.gleam", 194).
?DOC(false).
-spec extract_content_alg_from_serialized(bitstring()) -> {ok,
        gose:content_alg()} |
    {error, gose:gose_error()}.
extract_content_alg_from_serialized(Protected_serialized) ->
    with_decoded_protected(
        Protected_serialized,
        fun extract_content_alg_from_headers/1
    ).

-file("src/gose/internal/cose_structure.gleam", 207).
?DOC(false).
-spec extract_key_encryption_alg_from_serialized(bitstring()) -> {ok,
        gose:key_encryption_alg()} |
    {error, gose:gose_error()}.
extract_key_encryption_alg_from_serialized(Protected_serialized) ->
    with_decoded_protected(
        Protected_serialized,
        fun extract_key_encryption_alg_from_headers/1
    ).

-file("src/gose/internal/cose_structure.gleam", 229).
?DOC(false).
-spec decode_payload(gose@cbor:value()) -> {ok,
        gleam@option:option(bitstring())} |
    {error, gose:gose_error()}.
decode_payload(Value) ->
    case Value of
        {bytes, B} ->
            {ok, {some, B}};

        null ->
            {ok, none};

        _ ->
            {error,
                {parse_error,
                    <<"invalid COSE payload: expected bstr or null"/utf8>>}}
    end.

-file("src/gose/internal/cose_structure.gleam", 239).
?DOC(false).
-spec try_verify_keys(
    gose:signing_alg(),
    list(gose:key(any())),
    bitstring(),
    bitstring()
) -> {ok, nil} | {error, gose:gose_error()}.
try_verify_keys(Alg, Keys, Message, Signature) ->
    case Keys of
        [] ->
            {error, verification_failed};

        [Key | Rest] ->
            case gose@internal@signing:verify_signature(
                Alg,
                Key,
                Message,
                Signature
            ) of
                {ok, nil} ->
                    {ok, nil};

                {error, verification_failed} ->
                    try_verify_keys(Alg, Rest, Message, Signature);

                {error, Err} ->
                    {error, Err}
            end
    end.

-file("src/gose/internal/cose_structure.gleam", 266).
?DOC(false).
-spec parse_cose_array_value(gose@cbor:value(), integer(), integer()) -> {ok,
        list(gose@cbor:value())} |
    {error, gose:gose_error()}.
parse_cose_array_value(Value, Expected_tag, Expected_length) ->
    case Value of
        {tag, Tag, Inner} when Tag =:= Expected_tag ->
            parse_cose_array_value(Inner, Expected_tag, Expected_length);

        {array, Items} ->
            case erlang:length(Items) =:= Expected_length of
                true ->
                    {ok, Items};

                false ->
                    {error, {parse_error, <<"invalid COSE structure"/utf8>>}}
            end;

        _ ->
            {error, {parse_error, <<"invalid COSE structure"/utf8>>}}
    end.

-file("src/gose/internal/cose_structure.gleam", 257).
?DOC(false).
-spec parse_cose_array(bitstring(), integer(), integer()) -> {ok,
        list(gose@cbor:value())} |
    {error, gose:gose_error()}.
parse_cose_array(Data, Expected_tag, Expected_length) ->
    gleam@result:'try'(
        gose@cbor:decode(Data),
        fun(Value) ->
            parse_cose_array_value(Value, Expected_tag, Expected_length)
        end
    ).

-file("src/gose/internal/cose_structure.gleam", 283).
?DOC(false).
-spec require_embedded_payload(gleam@option:option(bitstring())) -> {ok,
        bitstring()} |
    {error, gose:gose_error()}.
require_embedded_payload(Payload) ->
    case Payload of
        {some, P} ->
            {ok, P};

        none ->
            {error,
                {invalid_state,
                    <<"message has detached payload; use verify_detached"/utf8>>}}
    end.

-file("src/gose/internal/cose_structure.gleam", 295).
?DOC(false).
-spec require_detached_payload(gleam@option:option(bitstring())) -> {ok, nil} |
    {error, gose:gose_error()}.
require_detached_payload(Payload) ->
    case Payload of
        none ->
            {ok, nil};

        {some, _} ->
            {error,
                {invalid_state,
                    <<"message has embedded payload; use verify"/utf8>>}}
    end.

-file("src/gose/internal/cose_structure.gleam", 305).
?DOC(false).
-spec build_enc_structure(binary(), bitstring(), bitstring()) -> bitstring().
build_enc_structure(Context, Protected_serialized, Aad) ->
    gose@cbor:encode(
        {array, [{text, Context}, {bytes, Protected_serialized}, {bytes, Aad}]}
    ).

-file("src/gose/internal/cose_structure.gleam", 319).
?DOC(false).
-spec split_ciphertext_tag(bitstring(), integer()) -> {ok,
        {bitstring(), bitstring()}} |
    {error, gose:gose_error()}.
split_ciphertext_tag(Ciphertext_with_tag, Tag_size) ->
    Total = erlang:byte_size(Ciphertext_with_tag),
    Ct_len = Total - Tag_size,
    case Ct_len >= 0 of
        false ->
            {error,
                {parse_error,
                    <<"ciphertext too short to contain authentication tag"/utf8>>}};

        true ->
            case {gleam_stdlib:bit_array_slice(Ciphertext_with_tag, 0, Ct_len),
                gleam_stdlib:bit_array_slice(
                    Ciphertext_with_tag,
                    Ct_len,
                    Tag_size
                )} of
                {{ok, Ct}, {ok, Tag}} ->
                    {ok, {Ct, Tag}};

                {_, _} ->
                    {error,
                        {parse_error,
                            <<"failed to split ciphertext and authentication tag"/utf8>>}}
            end
    end.

-file("src/gose/internal/cose_structure.gleam", 122).
?DOC(false).
-spec validate_crit_labels(list(integer()), list(gose@cose:header())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_crit_labels(Labels, Protected) ->
    Crit_set = gleam@set:from_list(Labels),
    gleam@bool:guard(
        gleam@list:is_empty(Labels),
        {error, {parse_error, <<"crit array must not be empty"/utf8>>}},
        fun() ->
            gleam@bool:guard(
                erlang:length(Labels) /= gleam@set:size(Crit_set),
                {error,
                    {parse_error,
                        <<"crit array contains duplicate values"/utf8>>}},
                fun() ->
                    Protected_keys = begin
                        _pipe = gose@cose:headers_to_cbor(Protected),
                        gleam@list:map(_pipe, fun gleam@pair:first/1)
                    end,
                    Standard_set = gleam@set:from_list([1, 2, 3, 4, 5, 6, 7]),
                    gleam@list:try_each(
                        Labels,
                        fun(Label) ->
                            Is_present = gleam@list:contains(
                                Protected_keys,
                                {int, Label}
                            ),
                            gleam@bool:guard(
                                not Is_present,
                                {error,
                                    {parse_error,
                                        <<"crit references label not in protected headers: "/utf8,
                                            (erlang:integer_to_binary(Label))/binary>>}},
                                fun() ->
                                    case gleam@set:contains(Standard_set, Label) of
                                        true ->
                                            {ok, nil};

                                        false ->
                                            {error,
                                                {parse_error,
                                                    <<"unsupported critical header: "/utf8,
                                                        (erlang:integer_to_binary(
                                                            Label
                                                        ))/binary>>}}
                                    end
                                end
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/gose/internal/cose_structure.gleam", 99).
?DOC(false).
-spec validate_crit(list(gose@cose:header()), list(gose@cose:header())) -> {ok,
        nil} |
    {error, gose:gose_error()}.
validate_crit(Protected, Unprotected) ->
    Has_crit_in_unprotected = gleam@list:any(Unprotected, fun(H) -> case H of
                {crit, _} ->
                    true;

                _ ->
                    false
            end end),
    gleam@bool:guard(
        Has_crit_in_unprotected,
        {error,
            {parse_error,
                <<"crit header must be in the protected bucket"/utf8>>}},
        fun() -> case gose@cose:critical(Protected) of
                {error, _} ->
                    {ok, nil};

                {ok, Labels} ->
                    validate_crit_labels(Labels, Protected)
            end end
    ).
