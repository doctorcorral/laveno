defmodule Laveno.EvaluationTest do
  use ExUnit.Case, async: true

  alias Laveno.Board
  alias Laveno.Evaluation.Evaluator
  alias Laveno.Evaluation.KingSafety
  alias Laveno.Evaluation.Placement
  alias Laveno.Fen

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
end
