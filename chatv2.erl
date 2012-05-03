-module(chatv2).
-export([server/1]).

server(Port) ->
  Room = spawn(fun()-> room([]) end),
  {ok, LSock} =
    gen_tcp:listen(Port, [binary, {packet, line}, {reuseaddr, true}]),
  acceptor(LSock, Room).

acceptor(LSock, Room) ->
  {ok, Sock} = gen_tcp:accept(LSock),
  Room ! {new_user, self()},
  spawn(fun() -> acceptor(LSock, Room) end),
  user(Sock, Room).

room(Pids) ->
  receive
    {new_user, Pid} ->
      io:format("new user~n", []),
      room([Pid | Pids]);
    {line, Data} = Msg ->
      io:format("received ~p~n", [Data]),
      [Pid ! Msg || Pid <- Pids],
      room(Pids);
    {exit, Pid} ->
      io:format("user disconnected~n", []),
      room(Pids -- [Pid])
  end.

user(Sock, Room) ->
  receive
    {line, Data} ->
      gen_tcp:send(Sock, Data),
      user(Sock, Room);
    {tcp, _, Data} ->
      Room ! {line, Data},
      user(Sock, Room);
    {tcp_closed, Sock} ->
      Room ! {exit, self()};
    {tcp_error, Sock, _} ->
      Room ! {exit, self()}
  end.

