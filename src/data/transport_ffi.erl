-module(transport_ffi).
-export([sleep/1]).

%% Blocking sleep for the SSG's retry backoff. Runs on the build
%% machine, so blocking the process is fine.
sleep(Milliseconds) ->
    timer:sleep(Milliseconds).
