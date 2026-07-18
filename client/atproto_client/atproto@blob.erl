-module(atproto@blob).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/blob.gleam").
-export([encode_blob/1, blob_decoder/0, public_url/3]).
-export_type([blob/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " The atproto blob reference, as embedded in records and returned by\n"
    " `com.atproto.repo.uploadBlob`:\n"
    " `{\"$type\":\"blob\",\"ref\":{\"$link\":<cid>},\"mimeType\":...,\"size\":...}`.\n"
).

-type blob() :: {blob, binary(), binary(), integer()}.

-file("src/atproto/blob.gleam", 13).
-spec encode_blob(blob()) -> gleam@json:json().
encode_blob(Value) ->
    gleam@json:object(
        [{<<"$type"/utf8>>, gleam@json:string(<<"blob"/utf8>>)},
            {<<"ref"/utf8>>,
                gleam@json:object(
                    [{<<"$link"/utf8>>,
                            gleam@json:string(erlang:element(2, Value))}]
                )},
            {<<"mimeType"/utf8>>, gleam@json:string(erlang:element(3, Value))},
            {<<"size"/utf8>>, gleam@json:int(erlang:element(4, Value))}]
    ).

-file("src/atproto/blob.gleam", 22).
-spec blob_decoder() -> gleam@dynamic@decode:decoder(blob()).
blob_decoder() ->
    gleam@dynamic@decode:field(
        <<"ref"/utf8>>,
        gleam@dynamic@decode:at(
            [<<"$link"/utf8>>],
            {decoder, fun gleam@dynamic@decode:decode_string/1}
        ),
        fun(Cid) ->
            gleam@dynamic@decode:field(
                <<"mimeType"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(Mime_type) ->
                    gleam@dynamic@decode:field(
                        <<"size"/utf8>>,
                        {decoder, fun gleam@dynamic@decode:decode_int/1},
                        fun(Size) ->
                            gleam@dynamic@decode:success(
                                {blob, Cid, Mime_type, Size}
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/atproto/blob.gleam", 30).
?DOC(" The public URL a PDS serves this blob's bytes from.\n").
-spec public_url(binary(), binary(), blob()) -> binary().
public_url(Pds, Did, Blob) ->
    <<<<Pds/binary, "/xrpc/com.atproto.sync.getBlob?"/utf8>>/binary,
        (gleam@uri:query_to_string(
            [{<<"did"/utf8>>, Did}, {<<"cid"/utf8>>, erlang:element(2, Blob)}]
        ))/binary>>.
