# TCEC Questionnaire v2.4 — Laveno

Copy the answers below into an email to the TCEC organizers. Submit via
the TCEC Discord (engine-authors / applications) and/or
https://www.chessdom.com/contact-us/

This questionnaire is required: https://wiki.chessdom.org/TCEC_Questionnaire

---

1. What is the name of your engine, do you use a github repository?

Laveno (also referred to as Laveno One). Repository:
https://github.com/doctorcorral/laveno

2. Who is the main author of your engine’s code?

Ricardo Corral-Corral

3. Which are your usernames (handles) in TCEC Discord and Twitch chat?

TCEC Discord: _please fill in_
Twitch: _please fill in_

4. Do you prefer being identified as author by your real name or by a pseudonym?

Real name: Ricardo Corral-Corral

5. Does your engine contain AI generated code, if so which part(s), and when was this genererated by which AI(s)?

The search, evaluation, and board representation are original Elixir code
written for Laveno. Tournament-protocol work (UCI options, time management,
TCEC/CCC packaging) was added in 2026. If any fragment was drafted with
assistance, it was reviewed and rewritten by the author. Laveno is a
hand-crafted-evaluation engine, not an LLM-play engine.

6. What is the license(s) under which (if applicable: the various parts of) your engine’s code is/are placed?

MIT License (see LICENSE in the repository).

7. Please name the parts and the authors of the code you use for training in case you use a neural network?

Not applicable. Laveno does not use a neural network.

8. In case your engine uses Training Data (NNUE or NN parts): what is the origin of this data? Did you obtain permission for use from the original authors if applicable?

Not applicable.

9. Please name any other engines and authors whose code (if applicable: the various parts of) your engine uses, including any NNUE/NN code if applicable?

None. Laveno does not include Stockfish, Ethereal, or any other engine’s
source. It is a from-scratch Elixir implementation (bitboards, move
generation, negamax alpha-beta, transposition table, quiescence).

10. Does you engine comply with the unofficial TCEC NNUE Guideline, to the best of your knowledge? If so please tell us why you believe it does?

Yes. Laveno does not use NNUE or any neural network, so the guideline’s
training-data and network-origin requirements do not apply.

11. Describe the unique features of your engine, what is with it that no other engines do, or how no other engines work, or was invented for it before others employed a similar thing too?

Laveno is a UCI chess engine implemented entirely in Elixir and running on
the BEAM virtual machine. Board state is stored as Elixir binaries /
bitboards. Search is negamax alpha-beta with an ETS transposition table,
iterative deepening, null-move pruning, quiescence, and root-split SMP via
BEAM processes. Evaluation is classical material plus center-control and
check/mate terms (hand-crafted, not NNUE). It is original work, not a
derivative of a C++ engine.

12. What is your engine's approximate elo?

Not yet established on CCRL or CEGT. Laveno is a developing original
engine; please assign a provisional testing rating. It is expected to be
well below the TCEC Entrance League 3000 Elo guideline on first entry and
is submitted as an original, actively developed engine for testing /
Swiss / HCE consideration.

13. Do you allow TCEC to publish your replies to this questionnaire (please also indicate here if you want your real name anonymized, see question 4)?

Yes, TCEC may publish these replies. Please use the real name
Ricardo Corral-Corral.

14. Is there any other information you think is relevant and is missing from your replies above?

- Protocol: UCI (Cute Chess). Required commands: uci, uciok, isready,
  readyok, position startpos / fen, go wtime/btime/winc/binc/movetime/depth,
  bestmove, stop, ucinewgame, quit. Options: Hash, Threads (1–512), Ponder
  (default false, no internal book), Move Overhead, SyzygyPath (accepted;
  probing not yet implemented), Clear Hash, OwnBook=false.
- Build: `tcec/update.sh` produces `./laveno` (Elixir escript). Linux x86_64.
- No internal opening book. TCEC books / FEN exits are used as sent.
- Fischer Random / DFRC is not supported yet; please do not enter Laveno
  in TCEC FRC/FRD until UCI_Chess960 is implemented.
- Ponder is off by default and should stay off.
- Author contact: GitHub @doctorcorral, project page https://laveno.one
