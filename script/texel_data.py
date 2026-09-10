#!/usr/bin/env python3
"""SF vs SF games → quiet FEN + white WDL for Texel."""

import json
import random
import re
import subprocess
import sys
import time
from pathlib import Path

STOCKFISH = sys.argv[1] if len(sys.argv) > 1 else "/opt/homebrew/bin/stockfish"
OUT = sys.argv[2] if len(sys.argv) > 2 else "priv/texel.jsonl"
MOVETIME = 50
MAX_PLIES = 48
GAMES = 96
OPENINGS = [
    [],
    ["e2e4", "e7e5", "g1f3", "b8c6"],
    ["d2d4", "d7d5", "c2c4", "e7e6"],
    ["e2e4", "c7c5", "g1f3", "d7d6"],
    ["c2c4", "e7e5"],
]
PAIRS = [(1500, 1900), (1900, 1500), (1700, 2100), (2100, 1700)]


def start():
    return subprocess.Popen(
        [STOCKFISH],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )


def send(p, line):
    p.stdin.write(line + "\n")
    p.stdin.flush()


def read_until(p, pred, timeout=12):
    deadline = time.time() + timeout
    lines = []
    while time.time() < deadline:
        line = p.stdout.readline()
        if line == "":
            break
        line = line.rstrip("\n")
        lines.append(line)
        if pred(line):
            return lines
    return lines


def handshake(p):
    send(p, "uci")
    read_until(p, lambda s: s == "uciok")
    send(p, "isready")
    read_until(p, lambda s: s == "readyok")


def set_elo(p, elo):
    send(p, "setoption name UCI_LimitStrength value true")
    send(p, f"setoption name UCI_Elo value {elo}")
    send(p, "setoption name Hash value 16")
    send(p, "setoption name Threads value 1")
    send(p, "isready")
    read_until(p, lambda s: s == "readyok")


def bestmove(p, go):
    send(p, go)
    lines = read_until(p, lambda s: s.startswith("bestmove "), timeout=8)
    bm, score = None, None
    for line in lines:
        m = re.search(r"score (cp|mate) (-?\d+)", line)
        if m:
            score = (m.group(1), int(m.group(2)))
        if line.startswith("bestmove "):
            parts = line.split()
            bm = parts[1] if len(parts) > 1 else None
    return bm, score


def fen_after(ref, moves):
    send(ref, "ucinewgame")
    send(ref, "setoption name UCI_LimitStrength value false")
    pos = "position startpos" + (f" moves {' '.join(moves)}" if moves else "")
    send(ref, pos)
    send(ref, "d")
    lines = read_until(ref, lambda s: s.startswith("Fen: ") or s.startswith("fen: "), timeout=4)
    for line in lines:
        if line.lower().startswith("fen:"):
            return line.split(":", 1)[1].strip()
    return None


def play(white, black, ref, book, w_elo, b_elo):
    send(white, "ucinewgame")
    send(black, "ucinewgame")
    set_elo(white, w_elo)
    set_elo(black, b_elo)
    moves = list(book)
    fens = []
    result = None

    for _ in range(MAX_PLIES):
        stm_white = len(moves) % 2 == 0
        engine = white if stm_white else black
        pos = "position startpos" + (f" moves {' '.join(moves)}" if moves else "")
        send(engine, pos)
        bm, _ = bestmove(engine, f"go movetime {MOVETIME}")
        if bm in (None, "(none)", "0000"):
            result = "0-1" if stm_white else "1-0"
            break
        moves.append(bm)
        if len(moves) >= len(book) + 8:
            fen = fen_after(ref, moves)
            if fen:
                fens.append(fen)

    if result is None:
        send(ref, "setoption name UCI_LimitStrength value false")
        send(ref, "isready")
        read_until(ref, lambda s: s == "readyok")
        pos = "position startpos" + (f" moves {' '.join(moves)}" if moves else "")
        send(ref, pos)
        _, score = bestmove(ref, "go depth 10")
        if not score:
            result = "1/2-1/2"
        else:
            kind, val = score
            stm_white = len(moves) % 2 == 0
            if kind == "mate":
                cp = 0 if val == 0 else (100000 - abs(val) * 10) * (1 if val > 0 else -1)
            else:
                cp = val
            white_cp = cp if stm_white else -cp
            if white_cp >= 150:
                result = "1-0"
            elif white_cp <= -150:
                result = "0-1"
            else:
                result = "1/2-1/2"

    pts = {"1-0": 1.0, "0-1": 0.0, "1/2-1/2": 0.5}[result]
    return fens, pts, result


def main():
    Path(OUT).parent.mkdir(parents=True, exist_ok=True)
    white, black, ref = start(), start(), start()
    try:
        for p in (white, black, ref):
            handshake(p)
        send(ref, "setoption name Hash value 32")
        send(ref, "setoption name Threads value 1")
        random.seed(7)
        n = 0
        with open(OUT, "w") as fh:
            for i in range(GAMES):
                book = OPENINGS[i % len(OPENINGS)]
                w_elo, b_elo = PAIRS[i % len(PAIRS)]
                fens, pts, result = play(white, black, ref, book, w_elo, b_elo)
                kept = 0
                for fen in fens:
                    # skip the last stretch later in the tuner via in-check filter
                    fh.write(json.dumps({"fen": fen, "result": pts}) + "\n")
                    kept += 1
                    n += 1
                print(f"[{i+1:03d}/{GAMES}] SF{w_elo} vs SF{b_elo} {result:7}  {kept} fens", flush=True)
        print(f"wrote {n} positions to {OUT}")
    finally:
        for p in (white, black, ref):
            try:
                send(p, "quit")
                p.terminate()
            except Exception:
                pass


if __name__ == "__main__":
    main()
