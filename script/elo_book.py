#!/usr/bin/env python3
"""Fixed-opening match: Laveno vs Stockfish UCI_Elo."""

import math
import re
import subprocess
import sys
import time

LAVENO = sys.argv[1] if len(sys.argv) > 1 else "./laveno"
STOCKFISH = sys.argv[2] if len(sys.argv) > 2 else "stockfish"
MOVETIME = int(sys.argv[3]) if len(sys.argv) > 3 else 400
MAX_PLIES = 52
ELOS = [1500, 1700, 1900, 2100]
OPENINGS = [
    ("start", []),
    ("e4e5", ["e2e4", "e7e5", "g1f3", "b8c6"]),
    ("QGD", ["d2d4", "d7d5", "c2c4", "e7e6"]),
    ("Sicilian", ["e2e4", "c7c5", "g1f3", "d7d6"]),
    ("English", ["c2c4", "e7e5"]),
]


def start(cmd):
    return subprocess.Popen(
        cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )


def send(p, line):
    p.stdin.write(line + "\n")
    p.stdin.flush()


def read_until(p, pred, timeout=20):
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


def handshake(p, name):
    send(p, "uci")
    lines = read_until(p, lambda s: s == "uciok", timeout=10)
    if not any(s == "uciok" for s in lines):
        raise RuntimeError(f"{name} no uciok: {lines[-6:]}")
    send(p, "isready")
    read_until(p, lambda s: s == "readyok", timeout=10)


def ready(p):
    send(p, "isready")
    read_until(p, lambda s: s == "readyok", timeout=10)


def bestmove(p, go, timeout):
    send(p, go)
    lines = read_until(p, lambda s: s.startswith("bestmove "), timeout=timeout)
    bm, score = None, None
    for line in lines:
        m = re.search(r"score (cp|mate) (-?\d+)", line)
        if m:
            score = (m.group(1), int(m.group(2)))
        if line.startswith("bestmove "):
            parts = line.split()
            bm = parts[1] if len(parts) > 1 else None
    return bm, score


def set_sf_elo(sf, elo):
    send(sf, "setoption name UCI_LimitStrength value true")
    send(sf, f"setoption name UCI_Elo value {elo}")
    send(sf, "setoption name Hash value 16")
    send(sf, "setoption name Threads value 1")
    ready(sf)


def strong_eval(ref, moves, depth=8):
    pos = "position startpos" + (f" moves {' '.join(moves)}" if moves else "")
    send(ref, pos)
    _, score = bestmove(ref, f"go depth {depth}", timeout=8)
    if not score:
        return None
    kind, val = score
    stm_white = len(moves) % 2 == 0
    if kind == "mate":
        cp = 0 if val == 0 else (100000 - abs(val) * 10) * (1 if val > 0 else -1)
    else:
        cp = val
    return cp if stm_white else -cp


def play(lav, sf, ref, lav_white, elo, book):
    send(lav, "ucinewgame")
    send(sf, "ucinewgame")
    ready(lav)
    set_sf_elo(sf, elo)
    ready(ref)

    moves = list(book)
    result = None
    extra = 0

    while extra < MAX_PLIES:
        white = len(moves) % 2 == 0
        engine = lav if white == lav_white else sf
        pos = "position startpos" + (f" moves {' '.join(moves)}" if moves else "")
        send(engine, pos)
        bm, score = bestmove(engine, f"go movetime {MOVETIME}", timeout=15)

        if bm in (None, "(none)", "0000"):
            result = "0-1" if white else "1-0"
            break

        moves.append(bm)
        extra += 1

        if extra % 2 == 0 or extra >= 12:
            ev = strong_eval(ref, moves, depth=6)
            if ev is not None and abs(ev) >= 700 and extra >= 12:
                result = "1-0" if ev > 0 else "0-1"
                break

    if result is None:
        ev = strong_eval(ref, moves, depth=10)
        if ev is None:
            result = "1/2-1/2"
        elif ev >= 150:
            result = "1-0"
        elif ev <= -150:
            result = "0-1"
        else:
            result = "1/2-1/2"

    if lav_white:
        pts = {"1-0": 1.0, "0-1": 0.0, "1/2-1/2": 0.5}[result]
    else:
        pts = {"1-0": 0.0, "0-1": 1.0, "1/2-1/2": 0.5}[result]

    return {"result": result, "score": pts, "plies": extra, "lav_white": lav_white, "elo": elo}


def estimate_elo(rows):
    best, best_ll = 1500, -1e18
    for rating in range(1100, 2500, 10):
        ll = 0.0
        for row in rows:
            exp = 1.0 / (1.0 + 10 ** ((row["elo"] - rating) / 400.0))
            p = min(max(exp, 1e-6), 1 - 1e-6)
            s = row["score"]
            if s == 1:
                ll += math.log(p)
            elif s == 0:
                ll += math.log(1 - p)
            else:
                ll += math.log(max(2 * p * (1 - p), 1e-6))
        if ll > best_ll:
            best, best_ll = rating, ll
    return best


def main():
    lav = start([LAVENO])
    sf = start([STOCKFISH])
    ref = start([STOCKFISH])
    try:
        handshake(lav, "Laveno")
        handshake(sf, "Stockfish")
        handshake(ref, "Referee")
        send(ref, "setoption name Hash value 32")
        send(ref, "setoption name Threads value 1")
        send(ref, "setoption name UCI_LimitStrength value false")
        ready(ref)

        n = len(OPENINGS) * 2 * len(ELOS)
        print(f"Laveno vs Stockfish 17.1 UCI_Elo  movetime={MOVETIME}ms")
        print(f"{len(OPENINGS)} openings × 2 colors × {len(ELOS)} levels = {n} games")
        print(f"openings={[n for n,_ in OPENINGS]}  levels={ELOS}\n")

        rows = []
        game = 0
        for name, book in OPENINGS:
            for elo in ELOS:
                for lav_white in (True, False):
                    game += 1
                    color = "W" if lav_white else "B"
                    row = play(lav, sf, ref, lav_white, elo, book)
                    row["opening"] = name
                    rows.append(row)
                    print(
                        f"[{game:02d}/{n}] {name:8} SF{elo} Lav{color}  "
                        f"{row['result']:7}  {row['score']}  {row['plies']} plies",
                        flush=True,
                    )

        print("\n===== BY LEVEL =====")
        for elo in ELOS:
            pts = [r["score"] for r in rows if r["elo"] == elo]
            print(f"  vs {elo}: {sum(pts):.1f}/{len(pts)}  {pts}")

        print("\n===== BY OPENING =====")
        for name, _ in OPENINGS:
            pts = [r["score"] for r in rows if r["opening"] == name]
            print(f"  {name:8}: {sum(pts):.1f}/{len(pts)}")

        print("\n===== BY COLOR =====")
        for lav_white, label in ((True, "White"), (False, "Black")):
            pts = [r["score"] for r in rows if r["lav_white"] is lav_white]
            print(f"  Laveno {label}: {sum(pts):.1f}/{len(pts)}")

        est = estimate_elo(rows)
        print(f"\nEstimated Laveno Elo: {est}")
        print(f"(logistic MLE, {len(rows)} fixed-opening games; still +/- ~80–120)")
    finally:
        for p in (lav, sf, ref):
            try:
                send(p, "quit")
                p.terminate()
            except Exception:
                pass


if __name__ == "__main__":
    main()
