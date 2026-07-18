-module(atproto@constellation).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/constellation.gleam").
-export([get_backlinks/6, record_uri/1]).
-export_type([backlink/0, backlinks_page/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Client for [Constellation](https://constellation.microcosm.blue), the\n"
    " microcosm atproto-wide backlink index: which records link to a given\n"
    " record, identity, or URL.\n"
).

-type backlink() :: {backlink, binary(), binary(), binary()}.

-type backlinks_page() :: {backlinks_page,
        integer(),
        list(backlink()),
        gleam@option:option(binary())}.

-file("src/atproto/constellation.gleam", 67).
-spec backlink_decoder() -> gleam@dynamic@decode:decoder(backlink()).
backlink_decoder() ->
    gleam@dynamic@decode:field(
        <<"did"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        fun(Did) ->
            gleam@dynamic@decode:field(
                <<"collection"/utf8>>,
                {decoder, fun gleam@dynamic@decode:decode_string/1},
                fun(Collection) ->
                    gleam@dynamic@decode:field(
                        <<"rkey"/utf8>>,
                        {decoder, fun gleam@dynamic@decode:decode_string/1},
                        fun(Rkey) ->
                            gleam@dynamic@decode:success(
                                {backlink, Did, Collection, Rkey}
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/atproto/constellation.gleam", 56).
-spec page_decoder() -> gleam@dynamic@decode:decoder(backlinks_page()).
page_decoder() ->
    gleam@dynamic@decode:field(
        <<"total"/utf8>>,
        {decoder, fun gleam@dynamic@decode:decode_int/1},
        fun(Total) ->
            gleam@dynamic@decode:field(
                <<"records"/utf8>>,
                gleam@dynamic@decode:list(backlink_decoder()),
                fun(Records) ->
                    gleam@dynamic@decode:optional_field(
                        <<"cursor"/utf8>>,
                        none,
                        gleam@dynamic@decode:optional(
                            {decoder, fun gleam@dynamic@decode:decode_string/1}
                        ),
                        fun(Cursor) ->
                            gleam@dynamic@decode:success(
                                {backlinks_page, Total, Records, Cursor}
                            )
                        end
                    )
                end
            )
        end
    ).

-file("src/atproto/constellation.gleam", 27).
?DOC(
    " Records linking to `subject` (an at-uri, DID, or plain URL). `source` names\n"
    " where the link must appear: `<collection>:<json.path>`, e.g.\n"
    " `app.bsky.feed.like:subject.uri`.\n"
).
-spec get_backlinks(
    atproto@xrpc:client(),
    binary(),
    binary(),
    binary(),
    integer(),
    gleam@option:option(binary())
) -> {ok, backlinks_page()} | {error, atproto@xrpc:xrpc_error()}.
get_backlinks(Client, Host, Subject, Source, Limit, Cursor) ->
    Params = [{<<"subject"/utf8>>, Subject},
        {<<"source"/utf8>>, Source},
        {<<"limit"/utf8>>, erlang:integer_to_binary(Limit)}],
    Params@1 = case Cursor of
        {some, C} ->
            lists:append(Params, [{<<"cursor"/utf8>>, C}]);

        none ->
            Params
    end,
    Url = <<<<Host/binary, "/xrpc/blue.microcosm.links.getBacklinks?"/utf8>>/binary,
        (gleam@uri:query_to_string(Params@1))/binary>>,
    gleam@result:'try'(
        atproto@xrpc:get(Client, Url, none),
        fun(Resp) ->
            atproto@xrpc:parse(erlang:element(4, Resp), page_decoder())
        end
    ).

-file("src/atproto/constellation.gleam", 52).
-spec record_uri(backlink()) -> binary().
record_uri(Backlink) ->
    <<<<<<<<<<"at://"/utf8, (erlang:element(2, Backlink))/binary>>/binary,
                    "/"/utf8>>/binary,
                (erlang:element(3, Backlink))/binary>>/binary,
            "/"/utf8>>/binary,
        (erlang:element(4, Backlink))/binary>>.
