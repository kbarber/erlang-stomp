%% --------------------------
%% @copyright 2010 Bob.sh
%% @doc Primary entry point for tests.
%%
%% @end
%% --------------------------

-module(stomp_alltests).
-export([start/0]).

start() ->
    error_logger:tty(false),
    eunit:test(stomp,[verbose]),
    halt().
