-module(atproto@repo).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/repo.gleam").
-export([list_records/6, create_record/6, get_record_envelope/7, get_record/7, put_record/7, upload_blob/5, delete_record/6]).
-export_type([created_record/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Generic `com.atproto.repo.*` record CRUD. Callers supply the collection NSID\n"
    " and a decoder for each record row, so this module stays free of any lexicon.\n"
).

-type created_record() :: {created_record, binary(), binary()}.

-file("src/atproto/repo.gleam", 30).
-spec list_page(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    binary(),
    gleam@dynamic@decode:decoder(AEOB),
    gleam@option:option(binary()),
    list(AEOB)
) -> {ok, list(AEOB)} | {error, atproto@xrpc:xrpc_error()}.
list_page(Client, Pds, Token, Did, Collection, Row_decoder, Cursor, Acc) ->
    Base = [{<<"repo"/utf8>>, Did},
        {<<"collection"/utf8>>, Collection},
        {<<"limit"/utf8>>, <<"100"/utf8>>}],
    Params = case Cursor of
        {some, C} ->
            [{<<"cursor"/utf8>>, C} | Base];

        none ->
            Base
    end,
    Url = <<<<Pds/binary, "/xrpc/com.atproto.repo.listRecords?"/utf8>>/binary,
        (gleam@uri:query_to_string(Params))/binary>>,
    gleam@result:'try'(
        atproto@xrpc:get(Client, Url, {some, Token}),
        fun(Resp) ->
            Page = begin
                gleam@dynamic@decode:field(
                    <<"records"/utf8>>,
                    gleam@dynamic@decode:list(Row_decoder),
                    fun(Rows) ->
                        gleam@dynamic@decode:optional_field(
                            <<"cursor"/utf8>>,
                            none,
                            gleam@dynamic@decode:optional(
                                {decoder,
                                    fun gleam@dynamic@decode:decode_string/1}
                            ),
                            fun(Next) ->
                                gleam@dynamic@decode:success({Rows, Next})
                            end
                        )
                    end
                )
            end,
            gleam@result:'try'(
                atproto@xrpc:parse(erlang:element(4, Resp), Page),
                fun(_use0) ->
                    {Rows@1, Next@1} = _use0,
                    All = lists:append(Acc, Rows@1),
                    case Next@1 of
                        {some, <<""/utf8>>} ->
                            {ok, All};

                        none ->
                            {ok, All};

                        {some, C@1} ->
                            list_page(
                                Client,
                                Pds,
                                Token,
                                Did,
                                Collection,
                                Row_decoder,
                                {some, C@1},
                                All
                            )
                    end
                end
            )
        end
    ).

-file("src/atproto/repo.gleam", 19).
?DOC(
    " List every record in a collection, following the cursor across pages (the\n"
    " XRPC endpoint caps each page at 100). Returns the full set.\n"
).
-spec list_records(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    binary(),
    gleam@dynamic@decode:decoder(AENW)
) -> {ok, list(AENW)} | {error, atproto@xrpc:xrpc_error()}.
list_records(Client, Pds, Token, Did, Collection, Row_decoder) ->
    list_page(Client, Pds, Token, Did, Collection, Row_decoder, none, []).

-file("src/atproto/repo.gleam", 66).
-spec create_record(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    binary(),
    gleam@json:json()
) -> {ok, created_record()} | {error, atproto@xrpc:xrpc_error()}.
create_record(Client, Pds, Token, Did, Collection, Record) ->
    Body = gleam@json:object(
        [{<<"repo"/utf8>>, gleam@json:string(Did)},
            {<<"collection"/utf8>>, gleam@json:string(Collection)},
            {<<"record"/utf8>>, Record}]
    ),
    gleam@result:'try'(
        atproto@xrpc:post_json(
            Client,
            <<Pds/binary, "/xrpc/com.atproto.repo.createRecord"/utf8>>,
            {some, Token},
            Body
        ),
        fun(Resp) ->
            Decoder = begin
                gleam@dynamic@decode:field(
                    <<"uri"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Uri) ->
                        gleam@dynamic@decode:field(
                            <<"cid"/utf8>>,
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            fun(Cid) ->
                                gleam@dynamic@decode:success(
                                    {created_record, Uri, Cid}
                                )
                            end
                        )
                    end
                )
            end,
            atproto@xrpc:parse(erlang:element(4, Resp), Decoder)
        end
    ).

-file("src/atproto/repo.gleam", 96).
?DOC(
    " Fetch one record, decoding the full envelope (uri/cid/value) with the\n"
    " supplied decoder, e.g. to build a strongRef to it.\n"
).
-spec get_record_envelope(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    binary(),
    binary(),
    gleam@dynamic@decode:decoder(AEOK)
) -> {ok, AEOK} | {error, atproto@xrpc:xrpc_error()}.
get_record_envelope(Client, Pds, Token, Did, Collection, Rkey, Decoder) ->
    Query = gleam@uri:query_to_string(
        [{<<"repo"/utf8>>, Did},
            {<<"collection"/utf8>>, Collection},
            {<<"rkey"/utf8>>, Rkey}]
    ),
    Url = <<<<Pds/binary, "/xrpc/com.atproto.repo.getRecord?"/utf8>>/binary,
        Query/binary>>,
    gleam@result:'try'(
        atproto@xrpc:get(Client, Url, {some, Token}),
        fun(Resp) -> atproto@xrpc:parse(erlang:element(4, Resp), Decoder) end
    ).

-file("src/atproto/repo.gleam", 117).
?DOC(" Fetch one record and decode its `value` with the supplied decoder.\n").
-spec get_record(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    binary(),
    binary(),
    gleam@dynamic@decode:decoder(AEOO)
) -> {ok, AEOO} | {error, atproto@xrpc:xrpc_error()}.
get_record(Client, Pds, Token, Did, Collection, Rkey, Value_decoder) ->
    Query = gleam@uri:query_to_string(
        [{<<"repo"/utf8>>, Did},
            {<<"collection"/utf8>>, Collection},
            {<<"rkey"/utf8>>, Rkey}]
    ),
    Url = <<<<Pds/binary, "/xrpc/com.atproto.repo.getRecord?"/utf8>>/binary,
        Query/binary>>,
    gleam@result:'try'(
        atproto@xrpc:get(Client, Url, {some, Token}),
        fun(Resp) ->
            atproto@xrpc:parse(
                erlang:element(4, Resp),
                gleam@dynamic@decode:at([<<"value"/utf8>>], Value_decoder)
            )
        end
    ).

-file("src/atproto/repo.gleam", 138).
?DOC(" Write a record at a known rkey (create or replace), keeping a stable URI.\n").
-spec put_record(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    binary(),
    binary(),
    gleam@json:json()
) -> {ok, created_record()} | {error, atproto@xrpc:xrpc_error()}.
put_record(Client, Pds, Token, Did, Collection, Rkey, Record) ->
    Body = gleam@json:object(
        [{<<"repo"/utf8>>, gleam@json:string(Did)},
            {<<"collection"/utf8>>, gleam@json:string(Collection)},
            {<<"rkey"/utf8>>, gleam@json:string(Rkey)},
            {<<"record"/utf8>>, Record}]
    ),
    gleam@result:'try'(
        atproto@xrpc:post_json(
            Client,
            <<Pds/binary, "/xrpc/com.atproto.repo.putRecord"/utf8>>,
            {some, Token},
            Body
        ),
        fun(Resp) ->
            Decoder = begin
                gleam@dynamic@decode:field(
                    <<"uri"/utf8>>,
                    {decoder, fun gleam@dynamic@decode:decode_string/1},
                    fun(Uri) ->
                        gleam@dynamic@decode:field(
                            <<"cid"/utf8>>,
                            {decoder, fun gleam@dynamic@decode:decode_string/1},
                            fun(Cid) ->
                                gleam@dynamic@decode:success(
                                    {created_record, Uri, Cid}
                                )
                            end
                        )
                    end
                )
            end,
            atproto@xrpc:parse(erlang:element(4, Resp), Decoder)
        end
    ).

-file("src/atproto/repo.gleam", 170).
?DOC(
    " Upload bytes to the authed repo. The returned ref must be embedded in a\n"
    " record before the PDS garbage-collects it.\n"
).
-spec upload_blob(
    atproto@xrpc:client(),
    binary(),
    binary(),
    bitstring(),
    binary()
) -> {ok, atproto@blob:blob()} | {error, atproto@xrpc:xrpc_error()}.
upload_blob(Client, Pds, Token, Bytes, Mime_type) ->
    gleam@result:'try'(
        atproto@xrpc:post_bits(
            Client,
            <<Pds/binary, "/xrpc/com.atproto.repo.uploadBlob"/utf8>>,
            {some, Token},
            Bytes,
            Mime_type
        ),
        fun(Resp) ->
            atproto@xrpc:parse(
                erlang:element(4, Resp),
                gleam@dynamic@decode:at(
                    [<<"blob"/utf8>>],
                    atproto@blob:blob_decoder()
                )
            )
        end
    ).

-file("src/atproto/repo.gleam", 187).
-spec delete_record(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    binary(),
    binary()
) -> {ok, nil} | {error, atproto@xrpc:xrpc_error()}.
delete_record(Client, Pds, Token, Did, Collection, Rkey) ->
    Body = gleam@json:object(
        [{<<"repo"/utf8>>, gleam@json:string(Did)},
            {<<"collection"/utf8>>, gleam@json:string(Collection)},
            {<<"rkey"/utf8>>, gleam@json:string(Rkey)}]
    ),
    gleam@result:'try'(
        atproto@xrpc:post_json(
            Client,
            <<Pds/binary, "/xrpc/com.atproto.repo.deleteRecord"/utf8>>,
            {some, Token},
            Body
        ),
        fun(_) -> {ok, nil} end
    ).
