# Laveno

This is Laveno One, a pure Elixir chess engine.
It includes board representation, game state management and valid moves generation as well as a set of board state evaluators with finders.
A finder is a game play brain to actually play a game.
It has UCI support, which enables using a chess GUI to interact with the engine.

Laveno exposes a handy API for each of it's components.

## How to play

```sh
mix escript.build
./laveno
```
So it is ready to recieve UCI commands

```sh
printf 'uci
isready
position startpos moves e2e4
go wtime 1000 btime 1000 winc 0 binc 0
quit
' | ./laveno --finder alphabeta-negamax-ets | cat
```
you should see
```sh
id name laveno.one 0.1.0
id author Corral-Corral, Ricardo
uciok
readyok
info depth 2 score cp -1 nodes 0 time 0 pv c7c5
bestmove c7c5
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `laveno` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:laveno, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/laveno>.

