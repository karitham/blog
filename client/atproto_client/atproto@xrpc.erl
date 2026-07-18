-module(atproto@xrpc).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/atproto/xrpc.gleam").
-export([describe/1, send_text/2, get/3, get_bits/3, post_json/4, post_bits/5, parse/2]).
-export_type([client/0, xrpc_error/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Transport-agnostic XRPC plumbing. The `Client` wraps a `send` function so\n"
    " the caller chooses the HTTP backend (erlang `httpc`, JS `fetch`, a test\n"
    " stub), keeping this module free of any target-specific dependency. Bodies\n"
    " are BitArrays so blobs ride the same client; the text helpers below keep\n"
    " JSON call sites string-shaped.\n"
).

-type client() :: {client,
        fun((gleam@http@request:request(bitstring())) -> {ok,
                gleam@http@response:response(bitstring())} |
            {error, binary()})}.

-type xrpc_error() :: {request_failed, binary()} |
    {bad_status,
        integer(),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        binary()} |
    {decode_failed, binary()}.

-file("src/atproto/xrpc.gleam", 36).
?DOC(" A one-line human-readable rendering of an error, for CLI and log output.\n").
-spec describe(xrpc_error()) -> binary().
describe(Error) ->
    case Error of
        {request_failed, E} ->
            <<"request failed: "/utf8, E/binary>>;

        {bad_status, Status, Code, Message, _} ->
            <<<<<<"HTTP "/utf8, (gleam@string:inspect(Status))/binary>>/binary,
                    (begin
                        _pipe = gleam@option:map(
                            Code,
                            fun(C) -> <<" "/utf8, C/binary>> end
                        ),
                        gleam@option:unwrap(_pipe, <<""/utf8>>)
                    end)/binary>>/binary,
                (begin
                    _pipe@1 = gleam@option:map(
                        Message,
                        fun(M) -> <<": "/utf8, M/binary>> end
                    ),
                    gleam@option:unwrap(_pipe@1, <<""/utf8>>)
                end)/binary>>;

        {decode_failed, E@1} ->
            <<"decode failed: "/utf8, E@1/binary>>
    end.

-file("src/atproto/xrpc.gleam", 50).
?DOC(
    " Send a text request and decode the response body as text. The seam between\n"
    " the string-shaped JSON world and the BitArray transport.\n"
).
-spec send_text(client(), gleam@http@request:request(binary())) -> {ok,
        gleam@http@response:response(binary())} |
    {error, binary()}.
send_text(Client, Req) ->
    gleam@result:'try'(
        (erlang:element(2, Client))(
            gleam@http@request:map(Req, fun gleam_stdlib:identity/1)
        ),
        fun(Resp) -> case gleam@bit_array:to_string(erlang:element(4, Resp)) of
                {ok, Body} ->
                    {ok, gleam@http@response:set_body(Resp, Body)};

                {error, _} ->
                    {error, <<"response body is not valid utf-8"/utf8>>}
            end end
    ).

-file("src/atproto/xrpc.gleam", 171).
-spec parse_error(binary()) -> {gleam@option:option(binary()),
    gleam@option:option(binary())}.
parse_error(Body) ->
    Decoder = begin
        gleam@dynamic@decode:optional_field(
            <<"error"/utf8>>,
            none,
            gleam@dynamic@decode:optional(
                {decoder, fun gleam@dynamic@decode:decode_string/1}
            ),
            fun(Error) ->
                gleam@dynamic@decode:optional_field(
                    <<"message"/utf8>>,
                    none,
                    gleam@dynamic@decode:optional(
                        {decoder, fun gleam@dynamic@decode:decode_string/1}
                    ),
                    fun(Message) ->
                        gleam@dynamic@decode:success({Error, Message})
                    end
                )
            end
        )
    end,
    _pipe = gleam@json:parse(Body, Decoder),
    gleam@result:unwrap(_pipe, {none, none}).

-file("src/atproto/xrpc.gleam", 161).
-spec check_ok(gleam@http@response:response(binary())) -> {ok,
        gleam@http@response:response(binary())} |
    {error, xrpc_error()}.
check_ok(Resp) ->
    case (erlang:element(2, Resp) >= 200) andalso (erlang:element(2, Resp) < 300) of
        true ->
            {ok, Resp};

        false ->
            {Error, Message} = parse_error(erlang:element(4, Resp)),
            {error,
                {bad_status,
                    erlang:element(2, Resp),
                    Error,
                    Message,
                    erlang:element(4, Resp)}}
    end.

-file("src/atproto/xrpc.gleam", 154).
-spec with_auth(
    gleam@http@request:request(binary()),
    gleam@option:option(binary())
) -> gleam@http@request:request(binary()).
with_auth(Req, Token) ->
    case Token of
        {some, T} ->
            gleam@http@request:set_header(
                Req,
                <<"authorization"/utf8>>,
                <<"Bearer "/utf8, T/binary>>
            );

        none ->
            Req
    end.

-file("src/atproto/xrpc.gleam", 61).
-spec get(client(), binary(), gleam@option:option(binary())) -> {ok,
        gleam@http@response:response(binary())} |
    {error, xrpc_error()}.
get(Client, Url, Token) ->
    gleam@result:'try'(
        begin
            _pipe = gleam@http@request:to(Url),
            gleam@result:replace_error(
                _pipe,
                {request_failed, <<"bad url: "/utf8, Url/binary>>}
            )
        end,
        fun(Base) -> _pipe@1 = Base,
            _pipe@2 = with_auth(_pipe@1, Token),
            _pipe@3 = send_text(Client, _pipe@2),
            _pipe@4 = gleam@result:map_error(
                _pipe@3,
                fun(Field@0) -> {request_failed, Field@0} end
            ),
            gleam@result:'try'(_pipe@4, fun check_ok/1) end
    ).

-file("src/atproto/xrpc.gleam", 78).
?DOC(
    " GET returning the raw bytes (e.g. blob or image downloads). The error body\n"
    " on a bad status is decoded leniently for the message.\n"
).
-spec get_bits(client(), binary(), gleam@option:option(binary())) -> {ok,
        gleam@http@response:response(bitstring())} |
    {error, xrpc_error()}.
get_bits(Client, Url, Token) ->
    gleam@result:'try'(
        begin
            _pipe = gleam@http@request:to(Url),
            gleam@result:replace_error(
                _pipe,
                {request_failed, <<"bad url: "/utf8, Url/binary>>}
            )
        end,
        fun(Base) -> _pipe@1 = Base,
            _pipe@2 = with_auth(_pipe@1, Token),
            _pipe@3 = gleam@http@request:map(
                _pipe@2,
                fun gleam_stdlib:identity/1
            ),
            _pipe@4 = (erlang:element(2, Client))(_pipe@3),
            _pipe@5 = gleam@result:map_error(
                _pipe@4,
                fun(Field@0) -> {request_failed, Field@0} end
            ),
            gleam@result:'try'(
                _pipe@5,
                fun(Resp) ->
                    case (erlang:element(2, Resp) >= 200) andalso (erlang:element(
                        2,
                        Resp
                    )
                    < 300) of
                        true ->
                            {ok, Resp};

                        false ->
                            Body = begin
                                _pipe@6 = gleam@bit_array:to_string(
                                    erlang:element(4, Resp)
                                ),
                                gleam@result:unwrap(
                                    _pipe@6,
                                    <<"<binary body>"/utf8>>
                                )
                            end,
                            {Error, Message} = parse_error(Body),
                            {error,
                                {bad_status,
                                    erlang:element(2, Resp),
                                    Error,
                                    Message,
                                    Body}}
                    end
                end
            ) end
    ).

-file("src/atproto/xrpc.gleam", 104).
-spec post_json(
    client(),
    binary(),
    gleam@option:option(binary()),
    gleam@json:json()
) -> {ok, gleam@http@response:response(binary())} | {error, xrpc_error()}.
post_json(Client, Url, Token, Body) ->
    gleam@result:'try'(
        begin
            _pipe = gleam@http@request:to(Url),
            gleam@result:replace_error(
                _pipe,
                {request_failed, <<"bad url: "/utf8, Url/binary>>}
            )
        end,
        fun(Base) -> _pipe@1 = Base,
            _pipe@2 = gleam@http@request:set_method(_pipe@1, post),
            _pipe@3 = gleam@http@request:set_header(
                _pipe@2,
                <<"content-type"/utf8>>,
                <<"application/json"/utf8>>
            ),
            _pipe@4 = with_auth(_pipe@3, Token),
            _pipe@5 = gleam@http@request:set_body(
                _pipe@4,
                gleam@json:to_string(Body)
            ),
            _pipe@6 = send_text(Client, _pipe@5),
            _pipe@7 = gleam@result:map_error(
                _pipe@6,
                fun(Field@0) -> {request_failed, Field@0} end
            ),
            gleam@result:'try'(_pipe@7, fun check_ok/1) end
    ).

-file("src/atproto/xrpc.gleam", 124).
?DOC(" POST raw bytes (e.g. `uploadBlob`); the response is decoded as text (JSON).\n").
-spec post_bits(
    client(),
    binary(),
    gleam@option:option(binary()),
    bitstring(),
    binary()
) -> {ok, gleam@http@response:response(binary())} | {error, xrpc_error()}.
post_bits(Client, Url, Token, Body, Content_type) ->
    gleam@result:'try'(
        begin
            _pipe = gleam@http@request:to(Url),
            gleam@result:replace_error(
                _pipe,
                {request_failed, <<"bad url: "/utf8, Url/binary>>}
            )
        end,
        fun(Base) ->
            Sent = begin
                _pipe@1 = Base,
                _pipe@2 = gleam@http@request:set_method(_pipe@1, post),
                _pipe@3 = gleam@http@request:set_header(
                    _pipe@2,
                    <<"content-type"/utf8>>,
                    Content_type
                ),
                _pipe@4 = with_auth(_pipe@3, Token),
                _pipe@5 = gleam@http@request:map(
                    _pipe@4,
                    fun gleam_stdlib:identity/1
                ),
                _pipe@6 = gleam@http@request:set_body(_pipe@5, Body),
                (erlang:element(2, Client))(_pipe@6)
            end,
            gleam@result:'try'(
                begin
                    _pipe@7 = Sent,
                    gleam@result:map_error(
                        _pipe@7,
                        fun(Field@0) -> {request_failed, Field@0} end
                    )
                end,
                fun(Resp) ->
                    case gleam@bit_array:to_string(erlang:element(4, Resp)) of
                        {ok, Text} ->
                            check_ok(gleam@http@response:set_body(Resp, Text));

                        {error, _} ->
                            {error,
                                {request_failed,
                                    <<"response body is not valid utf-8"/utf8>>}}
                    end
                end
            )
        end
    ).

-file("src/atproto/xrpc.gleam", 149).
-spec parse(binary(), gleam@dynamic@decode:decoder(ADNY)) -> {ok, ADNY} |
    {error, xrpc_error()}.
parse(Body, Decoder) ->
    _pipe = gleam@json:parse(Body, Decoder),
    gleam@result:map_error(
        _pipe,
        fun(E) -> {decode_failed, gleam@string:inspect(E)} end
    ).
