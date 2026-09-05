defmodule Laveno.SearchHeuristicsTest do
  use ExUnit.Case, async: false

  alias Laveno.Board
  alias Laveno.Finders.MinimaxABPruningNegamaxETS, as: Finder
  alias Laveno.Search.Heuristics
  alias Laveno.SearchControl

  setup do
    Heuristics.clear()
    :ok
  end

  test "a new cutoff becomes first killer and the previous first is kept" do
    Heuristics.record_cutoff(40, "e2e4")
    Heuristics.record_cutoff(40, "d2d4")
    assert Heuristics.killers(40) == {"d2d4", "e2e4"}
  end

  test "repeating the first killer does not drop the second" do
    Heuristics.record_cutoff(41, "a2a3")
    Heuristics.record_cutoff(41, "h2h3")
    Heuristics.record_cutoff(41, "h2h3")
    assert Heuristics.killers(41) == {"h2h3", "a2a3"}
  end

  test "promotions are not stored as killers or history" do
    Heuristics.record_cutoff(42, "e7e8q")
    assert Heuristics.killers(42) == {nil, nil}
    assert Heuristics.history("e7e8q") == 0
  end

  test "history grows with depth-squared gravity" do
    Heuristics.record_cutoff(43, "g1f3")
    first = Heuristics.history("g1f3")
    Heuristics.record_cutoff(44, "g1f3")
    assert first == 43 * 43
    assert Heuristics.history("g1f3") > first
  end

  test "sort_quiets puts k1, k2, then the highest history quiet" do
    Heuristics.record_cutoff(45, "b1c3")
    Heuristics.record_cutoff(45, "g1f3")
    Heuristics.record_cutoff(46, "e2e3")

    assert Heuristics.sort_quiets(["a2a3", "e2e3", "b1c3", "g1f3"], 45) == [
             "g1f3",
             "b1c3",
             "e2e3",
             "a2a3"
           ]
  end

  test "ucinewgame hash clear wipes killers and history" do
    Heuristics.record_cutoff(47, "c2c4")
    SearchControl.clear_hash()
    assert Heuristics.killers(47) == {nil, nil}
    assert Heuristics.history("c2c4") == 0
  end

  test "a real search records quiet cutoffs" do
    Finder.find(Board.new(), 3, -1_000_000, 1_000_000)
    size = :ets.info(:laveno_history, :size)
    assert is_integer(size) and size > 0
  end

  test "aspiration search at depth 4 still returns a legal startpos move" do
    board = Board.new()
    {_eval, result} = Finder.find(board, 4, -1_000_000, 1_000_000)
    move = List.last(result.moves)
    assert move in Laveno.Board.Utils.generate_moves(board)
  end
end
