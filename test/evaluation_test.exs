defmodule Laveno.EvaluationTest do
  use ExUnit.Case, async: true
  import Bitwise

  alias Laveno.Board
  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Context
  alias Laveno.Evaluation.Evaluator
  alias Laveno.Evaluation.KingSafety
  alias Laveno.Evaluation.Material
  alias Laveno.Evaluation.Mobility
  alias Laveno.Evaluation.Pawns
  alias Laveno.Evaluation.Placement
  alias Laveno.Evaluation.Threats
  alias Laveno.Fen
  alias Laveno.Finders.MinimaxABPruningNegamaxETS, as: Finder

  test "start position is roughly equal" do
    score = Evaluator.static(Board.new())
    assert_in_delta score, 0, 25
  end

  test "castled king is safer than a king stuck on e1" do
    {_s, castled} = Fen.load("rnbq1rk1/pppp1ppp/8/8/8/8/PPPP1PPP/RNBQ1RK1 w - - 0 1")
    {_s, center} = Fen.load("rnbq1rk1/pppp1ppp/8/8/8/8/PPPP1PPP/RNBQKBNR w - - 0 1")
    assert KingSafety.eval(castled) > KingSafety.eval(center)
  end

  test "a knight on f3 scores better than a knight on h3" do
    {_s, f3} = Fen.load("4k3/8/8/8/8/5N2/8/4K3 w - - 0 1")
    {_s, h3} = Fen.load("4k3/8/8/8/8/7N/8/4K3 w - - 0 1")
    assert Placement.eval(f3) > Placement.eval(h3)
  end

  test "an e4 pawn is preferred to a g3 pawn in the opening" do
    {_s, e4} = Fen.load("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1")
    {_s, g3} = Fen.load("rnbqkbnr/pppppppp/8/8/8/6P1/PPPPPP1P/RNBQKBNR w KQkq - 0 1")
    assert Evaluator.static(e4) > Evaluator.static(g3)
  end

  test "a centralized knight has more mobility than a corner knight" do
    {_s, center} = Fen.load("4k3/8/8/3N4/8/8/8/4K3 w - - 0 1")
    {_s, corner} = Fen.load("4k3/8/8/8/8/8/8/N3K3 w - - 0 1")
    assert Mobility.eval(center) > Mobility.eval(corner)
  end

  test "an unblocked bishop outscores a bishop hemmed in by its own pawn" do
    {_s, open} = Fen.load("4k3/8/8/8/4P3/8/8/4KB2 w - - 0 1")
    {_s, shut} = Fen.load("4k3/8/8/8/8/8/4P3/4KB2 w - - 0 1")
    assert Mobility.eval(open) > Mobility.eval(shut)
  end

  test "a rook on an open file outscores a rook behind its own pawn" do
    {_s, open} = Fen.load("4k3/8/8/8/8/8/8/R3K3 w - - 0 1")
    {_s, shut} = Fen.load("4k3/8/8/8/8/8/P7/R3K3 w - - 0 1")
    assert Mobility.eval(open) > Mobility.eval(shut)
    assert Pawns.eval(open) > Pawns.eval(shut)
  end

  test "connected pawns outscore a doubled isolated pair" do
    {_s, connected} = Fen.load("4k3/8/8/8/8/8/3PP3/4K3 w - - 0 1")
    {_s, doubled} = Fen.load("4k3/8/8/8/8/4P3/4P3/4K3 w - - 0 1")
    assert Pawns.eval(connected) > Pawns.eval(doubled)
  end

  test "a passer on the sixth outscores the same passer on the second" do
    {_s, sixth} = Fen.load("4k3/8/4P3/8/8/8/8/4K3 w - - 0 1")
    {_s, second} = Fen.load("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")
    assert Pawns.eval(sixth) > Pawns.eval(second)
  end

  test "an undefended knight attacked by a pawn is hanging" do
    {_s, white_hang_w} = Fen.load("4k3/8/8/2p5/3N4/8/8/4K3 w - - 0 1")
    {_s, white_hang_b} = Fen.load("4k3/8/8/2p5/3N4/8/8/4K3 b - - 0 1")
    {_s, black_hang_w} = Fen.load("4k3/8/8/3n4/2P5/8/8/4K3 w - - 0 1")
    {_s, safe} = Fen.load("4k3/8/8/8/3N4/8/8/4K3 w - - 0 1")

    assert_in_delta Threats.eval(white_hang_w), 0, 25
    assert Threats.eval(white_hang_b) <= -150
    assert Threats.eval(black_hang_w) >= 150
    assert_in_delta Threats.eval(safe), 0, 25
  end

  test "fused static matches the sum of the eval modules" do
    fens = [
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
      "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
      "rnbq1rk1/pppp1ppp/8/8/8/8/PPPP1PPP/RNBQ1RK1 w - - 0 1",
      "4k3/8/8/2p5/3N4/8/8/4K3 b - - 0 1"
    ]

    Enum.each(fens, fn fen ->
      {_s, board} = Fen.load(fen)
      assert Evaluator.static(board) == oracle_static(board)
    end)
  end

  test "fused static matches the oracle along a random legal walk" do
    board =
      Enum.reduce(1..80, Board.new(), fn _, board ->
        assert Evaluator.static(board) == oracle_static(board)
        case Utils.generate_moves(board) do
          [] -> board
          moves -> Board.move(board, Enum.random(moves))
        end
      end)

    assert Evaluator.static(board) == oracle_static(board)
  end

  test "shared attack maps match attacked?/4 on every square" do
    {_s, board} = Fen.load("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
    ctx = Context.build(board)
    occ = ctx.occ

    Enum.each(0..63, fn sq ->
      bit = Bitwise.<<<(1, sq)
      assert Attacks.attacked?(board.bb, occ, sq, :white) == ((ctx.w_att &&& bit) != 0)
      assert Attacks.attacked?(board.bb, occ, sq, :black) == ((ctx.b_att &&& bit) != 0)
    end)
  end

  test "search does not give a queen for an undefended bishop" do
    {_s, board} = Fen.load("4k3/3b4/8/8/8/8/8/Q3K3 w - - 0 1")
    {_eval, result} = Finder.find(board, 3, -90, 90)
    refute List.last(result.moves) == "a1d7"
  end

  defp oracle_static(board) do
    Material.eval(board) + Placement.eval(board) + KingSafety.eval(board) +
      Mobility.eval(board) + Pawns.eval(board) + Threats.eval(board)
  end
end
