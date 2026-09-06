defmodule Laveno.SearchMakeTest do
  use ExUnit.Case, async: false

  alias Laveno.Board
  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Fen
  alias Laveno.Finders.MinimaxABPruningNegamaxETS, as: Finder
  alias Laveno.SearchControl

  defp norm(bb), do: Map.new(bb, fn {k, v} -> {k, Attacks.as_int(v)} end)

  test "apply_search matches Board.move on already-legal moves" do
    {_s, board} = Fen.load("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

    Enum.each(Utils.generate_moves(board), fn mv ->
      via_move = Board.move(board, mv)
      via_search = Board.apply_search(board, mv)
      assert %Board{} = via_move
      assert %Board{} = via_search
      assert norm(via_search.bb) == norm(via_move.bb)
      assert via_search.castles == via_move.castles
      assert via_search.en_passant == via_move.en_passant
      assert via_search.active_color == via_move.active_color
    end)
  end

  test "search still returns a legal startpos move after fast make" do
    SearchControl.ensure()
    SearchControl.start_search(60_000)
    board = Board.new()
    {_eval, result} = Finder.find(board, 3, -1_000_000, 1_000_000)
    move = List.last(result.moves)
    assert move in Utils.generate_moves(board)
  end
end
