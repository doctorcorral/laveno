# Competing with Laveno

The two events that define engine chess are:

1. **TCEC** — [Top Chess Engine Championship](https://wiki.chessdom.org/Main_Page),
   the long-time-control “unofficial world championship” (Linux, Cute Chess,
   invitation after a questionnaire).
2. **CCC** — [Chess.com Computer Chess Championship](https://www.chess.com/computer-chess-championship),
   the other flagship, also Linux / UCI / Cute Chess, invitation after
   stability testing.

Neither has an open “submit binary” button. Both require a **stable UCI
engine on Linux**, then an application to the organizers. This tree is
wired for that.

## What Laveno now implements for those events

| Requirement | TCEC | CCC | Laveno |
| --- | --- | --- | --- |
| UCI (`uci` / `isready` / `position` / `go` / `bestmove` / `quit`) | required (4K subset) | required | yes |
| Tolerate `stop`, `ucinewgame`, unknown commands | required | required | yes |
| `position fen` including book exits | required (TCEC books) | required | yes |
| `go wtime btime winc binc` | 30'+3" / 60'+6" / 120'+12" | 15'+5" and others | time-sliced search |
| `Hash` / `Threads` options | up to 256 GiB / 512 threads | 8+ threads required | `Hash`, `Threads` 1–512 (root-split SMP) |
| `Ponder` default off, no internal book | ponder off, TCEC book | ponder usually off | `Ponder` false, `OwnBook` false |
| Linux 64-bit binary | required | Docker on Linux | `tcec/update.sh`, `ccc/Dockerfile` |
| Evaluation in centipawns (`info score cp`) | used for draw adjudication | displayed live | yes |
| Syzygy | 7-man available | preferred | option accepted, probing not yet |
| Chess960 / FRC | TCEC FRD event | some events | not yet — do not enter FRC |
| Original, actively developed | required | required | original Elixir engine, MIT |
| ~3000 Elo | leagues guideline | guideline, exceptions exist | **not there yet** |

Honesty: first entry will not be Premier Division. TCEC’s Entrance League
and Swiss, and CCC qualifying / experimental invites, are the realistic
doors. Season 30 also tests unusual engines in the Swiss path. Strength
work after protocol compliance is how engines climb those lists.

## TCEC application

1. Join the [TCEC Discord](https://wiki.chessdom.org/Main_Page) (linked from
   the wiki) and/or write via https://www.chessdom.com/contact-us/
2. Email the filled answers in `tcec/QUESTIONNAIRE.md` (fill Discord/Twitch
   handles first).
3. Point them at this repository and `tcec/update.sh`.
4. Suggested Cute Chess settings:
   - `option.Threads=64` (or whatever they allocate; max 512)
   - `option.Hash=4096` or their standard
   - `option.Ponder=false`
   - `option.Move Overhead=80`
5. Do **not** ask for TCEC FRC/FRD until Chess960 is implemented.

## CCC application

CCC is invite-only. Organizers watch CCRL / CEGT / TCEC and test stability
on their hardware ([ccc-configs](https://github.com/chesscom/ccc-configs)).

1. Publish tagged releases and keep Linux builds reproducible
   (`ccc/Dockerfile`).
2. Get games on public rating lists (CCRL 40/4 or 40/15, FastGM, etc.).
3. Contact the CCC staff (Chess.com computer-chess / the engine-author
   channels they advertise) once there is a rating and a crash-free log.
4. Config they would use is sketched in `ccc/laveno.json`
   (`Threads` ≥ 8 is a CCC eligibility rule).

## Local verification (same protocol as the GUIs)

```sh
mix escript.build

printf 'uci
setoption name Threads value 2
setoption name Hash value 16
isready
ucinewgame
position startpos moves e2e4 e7e5
go wtime 5000 btime 5000 winc 100 binc 100
quit
' | ./laveno
```

You should see `uciok`, the option list, `readyok`, an `info ... score cp`
line, and `bestmove` with a legal coordinate move.

Cute Chess:

```sh
cutechess-cli \
  -engine name=Laveno cmd=./laveno proto=uci option.Threads=2 option.Hash=64 \
  -engine name=Opponent cmd=/path/to/other proto=uci \
  -each tc=30+0.3 -games 2 -pgnout laveno-smoke.pgn
```
