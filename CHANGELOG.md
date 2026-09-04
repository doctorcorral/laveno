## 0.4.0 [2026-09-04]

- [Tournament] UCI protocol required by TCEC and Chess.com CCC: options
  (Hash, Threads, Ponder, Move Overhead, SyzygyPath, Clear Hash, OwnBook),
  `go wtime/btime/winc/binc`, `stop` during search, `ucinewgame` hash clear.
- [Tournament] Time management so classical/rapid clocks are used instead of
  a fixed depth-2 burst.
- [Tournament] Root-split SMP via the `Threads` option (CCC requires ≥ 8).
- [Bug Fix] FEN loader now starts from zero castling rights and accepts
  en passant on files g and h (TCEC/CCC book exits).
- [Bug Fix] Castling moves are generated and rook captures clear rights.
- [Packaging] TCEC `update.sh` + questionnaire, CCC Dockerfile, MIT LICENSE.

## 0.3.0 [2025-11-20]

- [New Feature] Add correspondence game support.

## 0.2.1 [2025-11-02]

- [Bug Fix] Proper move validation on promotion moves.

## 0.2.0 [2025-07-06]

- [New Feature] Implemented minimax negamax with ETS lookups.
- [Bug Fix] Handling of castling, including SAN normalization.
- [Bug Fix] Adequate handling of check for valid move generation and mate.
- [Bug Fix] Several fixes regarding piece movility.
