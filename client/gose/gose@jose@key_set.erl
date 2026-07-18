-module(gose@jose@key_set).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gose/jose/key_set.gleam").
-export([from_list/1, new/0, to_json/1, to_list/1, strict_decoder/0, from_json/1, from_json_bits/1, decoder/0, from_json_strict/1, from_json_strict_bits/1, get/2, insert/2, delete/2, filter/2, first/1]).
-export_type([jwk_set/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " JWK Set - [RFC 7517 Section 5](https://www.rfc-editor.org/rfc/rfc7517.html#section-5)\n"
    "\n"
    " A JWK Set is a JSON object containing an array of JWK values.\n"
    " The `keys` member is REQUIRED and contains the array.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " // Build a key set\n"
    " let key =\n"
    "   gose.generate_ec(ec.P256)\n"
    "   |> gose.with_kid(\"key-1\")\n"
    " let set =\n"
    "   key_set.new()\n"
    "   |> key_set.insert(key)\n"
    "\n"
    " // Serialize to JSON and parse back\n"
    " let json_string = key_set.to_json(set)\n"
    "   |> json.to_string()\n"
    " let assert Ok(parsed) = key_set.from_json(json_string)\n"
    "\n"
    " // Look up a key by kid\n"
    " let assert Ok(found) = key_set.get(parsed, \"key-1\")\n"
    " ```\n"
).

-opaque jwk_set() :: {jwk_set, list(gose:key(binary()))}.

-file("src/gose/jose/key_set.gleam", 40).
?DOC(" Create a JWK Set from a list of keys.\n").
-spec from_list(list(gose:key(binary()))) -> jwk_set().
from_list(Keys) ->
    {jwk_set, Keys}.

-file("src/gose/jose/key_set.gleam", 45).
?DOC(" Create an empty JWK Set.\n").
-spec new() -> jwk_set().
new() ->
    {jwk_set, []}.

-file("src/gose/jose/key_set.gleam", 50).
?DOC(" Serialize a JWK Set to its JSON representation.\n").
-spec to_json(jwk_set()) -> gleam@json:json().
to_json(Jwk_set) ->
    Json_keys = gleam@list:map(
        erlang:element(2, Jwk_set),
        fun gose@jose@jwk:to_json/1
    ),
    gleam@json:object(
        [{<<"keys"/utf8>>, gleam@json:preprocessed_array(Json_keys)}]
    ).

-file("src/gose/jose/key_set.gleam", 56).
?DOC(" Get all keys from a JWK Set as a list.\n").
-spec to_list(jwk_set()) -> list(gose:key(binary())).
to_list(Jwk_set) ->
    erlang:element(2, Jwk_set).

-file("src/gose/jose/key_set.gleam", 140).
?DOC(
    " Return a strict decoder for JWK Set values.\n"
    "\n"
    " Unlike `decoder()`, this fails if any key in the set is invalid.\n"
    "\n"
    " Note that RFC 7517 Section 5 says implementations SHOULD ignore JWKs\n"
    " with unrecognised key types, missing required members, or unsupported\n"
    " parameter values. Prefer `decoder()` unless you need to guarantee\n"
    " every key in the set is valid.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(set) = json.parse(json_string, key_set.strict_decoder())\n"
    " ```\n"
).
-spec strict_decoder() -> gleam@dynamic@decode:decoder(jwk_set()).
strict_decoder() ->
    gleam@dynamic@decode:field(
        <<"keys"/utf8>>,
        gleam@dynamic@decode:list(gose@jose@jwk:decoder()),
        fun(Keys) -> gleam@dynamic@decode:success({jwk_set, Keys}) end
    ).

-file("src/gose/jose/key_set.gleam", 145).
-spec parse_keys_array(
    fun((gleam@dynamic@decode:decoder(list(gleam@dynamic:dynamic_()))) -> {ok,
            list(gleam@dynamic:dynamic_())} |
        {error, gleam@json:decode_error()})
) -> {ok, list(gleam@dynamic:dynamic_())} | {error, gose:gose_error()}.
parse_keys_array(Parse) ->
    _pipe = Parse(
        gleam@dynamic@decode:at(
            [<<"keys"/utf8>>],
            gleam@dynamic@decode:list(
                {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
            )
        )
    ),
    gleam@result:replace_error(
        _pipe,
        {parse_error, <<"missing or invalid keys array"/utf8>>}
    ).

-file("src/gose/jose/key_set.gleam", 153).
-spec parse_keys_lenient(list(gleam@dynamic:dynamic_())) -> jwk_set().
parse_keys_lenient(Keys_dyn) ->
    Keys = gleam@list:filter_map(
        Keys_dyn,
        fun(Key_dyn) -> _pipe = gose@jose@jwk:from_dynamic(Key_dyn),
            gleam@result:replace_error(_pipe, nil) end
    ),
    {jwk_set, Keys}.

-file("src/gose/jose/key_set.gleam", 64).
?DOC(
    " Parse a JWK Set from a JSON string.\n"
    "\n"
    " The `keys` array is required. Unknown top-level members are ignored per RFC.\n"
    " Invalid keys are silently skipped.\n"
).
-spec from_json(binary()) -> {ok, jwk_set()} | {error, gose:gose_error()}.
from_json(Json_str) ->
    _pipe = parse_keys_array(
        fun(_capture) -> gleam@json:parse(Json_str, _capture) end
    ),
    gleam@result:map(_pipe, fun parse_keys_lenient/1).

-file("src/gose/jose/key_set.gleam", 73).
?DOC(
    " Parse a JWK Set from a JSON BitArray.\n"
    "\n"
    " The `keys` array is required. Unknown top-level members are ignored per RFC.\n"
    " Invalid keys are silently skipped.\n"
).
-spec from_json_bits(bitstring()) -> {ok, jwk_set()} |
    {error, gose:gose_error()}.
from_json_bits(Json_bits) ->
    _pipe = parse_keys_array(
        fun(_capture) -> gleam@json:parse_bits(Json_bits, _capture) end
    ),
    gleam@result:map(_pipe, fun parse_keys_lenient/1).

-file("src/gose/jose/key_set.gleam", 121).
?DOC(
    " Return a lenient decoder for JWK Set values.\n"
    "\n"
    " Invalid keys are silently skipped, matching `from_json` behavior.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " let assert Ok(set) = json.parse(json_string, key_set.decoder())\n"
    " ```\n"
).
-spec decoder() -> gleam@dynamic@decode:decoder(jwk_set()).
decoder() ->
    gleam@dynamic@decode:field(
        <<"keys"/utf8>>,
        gleam@dynamic@decode:list(
            {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
        ),
        fun(Keys_dyn) ->
            gleam@dynamic@decode:success(parse_keys_lenient(Keys_dyn))
        end
    ).

-file("src/gose/jose/key_set.gleam", 162).
-spec parse_keys_strict(list(gleam@dynamic:dynamic_())) -> {ok,
        list(gose:key(binary()))} |
    {error, gose:gose_error()}.
parse_keys_strict(Keys_dyn) ->
    _pipe = gleam@list:index_fold(
        Keys_dyn,
        {ok, []},
        fun(Acc, Key_dyn, Index) ->
            gleam@result:'try'(
                Acc,
                fun(Keys) -> case gose@jose@jwk:from_dynamic(Key_dyn) of
                        {ok, Key} ->
                            {ok, [Key | Keys]};

                        {error, Err} ->
                            Reason = gose:error_message(Err),
                            {error,
                                {parse_error,
                                    <<<<<<"invalid key at index "/utf8,
                                                (erlang:integer_to_binary(Index))/binary>>/binary,
                                            ": "/utf8>>/binary,
                                        Reason/binary>>}}
                    end end
            )
        end
    ),
    gleam@result:map(_pipe, fun lists:reverse/1).

-file("src/gose/jose/key_set.gleam", 88).
?DOC(
    " Parse a JWK Set from a JSON string, failing on any invalid key.\n"
    "\n"
    " Unlike `from_json` which silently skips invalid keys, this function\n"
    " returns an error if any key in the array fails to parse. The error\n"
    " message includes the index of the invalid key.\n"
    "\n"
    " Note that RFC 7517 Section 5 says implementations SHOULD ignore JWKs\n"
    " with unrecognised key types, missing required members, or unsupported\n"
    " parameter values. Prefer `from_json` unless you need to guarantee\n"
    " every key in the set is valid.\n"
).
-spec from_json_strict(binary()) -> {ok, jwk_set()} | {error, gose:gose_error()}.
from_json_strict(Json_str) ->
    _pipe = parse_keys_array(
        fun(_capture) -> gleam@json:parse(Json_str, _capture) end
    ),
    _pipe@1 = gleam@result:'try'(_pipe, fun parse_keys_strict/1),
    gleam@result:map(_pipe@1, fun(Field@0) -> {jwk_set, Field@0} end).

-file("src/gose/jose/key_set.gleam", 104).
?DOC(
    " Parse a JWK Set from a JSON BitArray, failing on any invalid key.\n"
    "\n"
    " Unlike `from_json_bits` which silently skips invalid keys, this function\n"
    " returns an error if any key in the array fails to parse. The error\n"
    " message includes the index of the invalid key.\n"
    "\n"
    " Note that RFC 7517 Section 5 says implementations SHOULD ignore JWKs\n"
    " with unrecognised key types, missing required members, or unsupported\n"
    " parameter values. Prefer `from_json_bits` unless you need to guarantee\n"
    " every key in the set is valid.\n"
).
-spec from_json_strict_bits(bitstring()) -> {ok, jwk_set()} |
    {error, gose:gose_error()}.
from_json_strict_bits(Json_bits) ->
    _pipe = parse_keys_array(
        fun(_capture) -> gleam@json:parse_bits(Json_bits, _capture) end
    ),
    _pipe@1 = gleam@result:'try'(_pipe, fun parse_keys_strict/1),
    gleam@result:map(_pipe@1, fun(Field@0) -> {jwk_set, Field@0} end).

-file("src/gose/jose/key_set.gleam", 181).
?DOC(" Find a key by its key ID (kid).\n").
-spec get(jwk_set(), binary()) -> {ok, gose:key(binary())} | {error, nil}.
get(Jwk_set, Kid) ->
    gleam@list:find(
        erlang:element(2, Jwk_set),
        fun(Key) -> case gose:kid(Key) of
                {ok, K} ->
                    K =:= Kid;

                {error, _} ->
                    false
            end end
    ).

-file("src/gose/jose/key_set.gleam", 195).
?DOC(
    " Add a key to the set.\n"
    "\n"
    " Keys are prepended, so if a key with the same `kid` already exists,\n"
    " the newer key shadows the older one and `get` will return the most\n"
    " recently inserted key.\n"
).
-spec insert(jwk_set(), gose:key(binary())) -> jwk_set().
insert(Jwk_set, Key) ->
    {jwk_set, [Key | erlang:element(2, Jwk_set)]}.

-file("src/gose/jose/key_set.gleam", 202).
?DOC(
    " Remove a key by its key ID (kid).\n"
    "\n"
    " If no key with the given kid exists, returns the set unchanged.\n"
).
-spec delete(jwk_set(), binary()) -> jwk_set().
delete(Jwk_set, Kid) ->
    Filtered = gleam@list:filter(
        erlang:element(2, Jwk_set),
        fun(Key) -> case gose:kid(Key) of
                {ok, K} ->
                    K /= Kid;

                {error, _} ->
                    true
            end end
    ),
    {jwk_set, Filtered}.

-file("src/gose/jose/key_set.gleam", 214).
?DOC(" Filter keys by a predicate function.\n").
-spec filter(jwk_set(), fun((gose:key(binary())) -> boolean())) -> jwk_set().
filter(Jwk_set, Predicate) ->
    {jwk_set, gleam@list:filter(erlang:element(2, Jwk_set), Predicate)}.

-file("src/gose/jose/key_set.gleam", 224).
?DOC(
    " Get the first key in the set.\n"
    "\n"
    " Useful for single-key sets or when any key will suffice.\n"
).
-spec first(jwk_set()) -> {ok, gose:key(binary())} | {error, nil}.
first(Jwk_set) ->
    gleam@list:first(erlang:element(2, Jwk_set)).
