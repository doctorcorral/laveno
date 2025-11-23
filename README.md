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
' | ./laveno | cat
```
you should see
```sh
id name laveno.one 0.2.0
id author Corral-Corral, Ricardo
uciok
readyok
info depth 2 score cp -1 nodes 0 time 0 pv c7c5
bestmove c7c5
```

## Correspondence Games

Laveno supports correspondence chess games, where moves are exchanged asynchronously with longer time controls. This is ideal for playing against other engines or players with deliberate, thoughtful gameplay.

### How Correspondence Games Work

1. **Long Time Controls**: Unlike rapid or blitz games, correspondence games allow for much longer thinking time (hours or even days per move)
2. **UCI Compatible**: Laveno follows the Universal Chess Interface protocol, making it compatible with any UCI-compliant chess GUI or server
3. **Advanced Search**: Laveno uses negamax with alpha-beta pruning and transposition tables optimized for deep analysis

### Playing Correspondence Games

To play a correspondence game, you can use Laveno with a chess GUI like:
- **Arena Chess GUI**
- **Cute Chess**
- **Lichess** (via lichess-bot)

Example configuration for longer time controls:

```sh
printf 'uci
isready
position startpos moves e2e4 e7e5
go movetime 60000
quit
' | ./laveno | cat
```

The `movetime 60000` value is how lichess-bot signals to the engine that this is a correspondence game (configured in lichess-bot's `correspondence.move_time` setting). This is not an actual 60-second time limit - in correspondence games, the engine can take much longer (hours or even longer) to analyze positions deeply. The engine will continue thinking until it completes its search or reaches other internal stopping criteria, taking full advantage of the extended time controls that correspondence games allow.

### Integration with Lichess Bot

Laveno can be integrated with [lichess-bot](https://github.com/lichess-bot-devs/lichess-bot) to play correspondence games on Lichess.org. Configure it as a UCI engine in the `config.yml` file.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `laveno` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:laveno, "~> 0.3.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/laveno>.

