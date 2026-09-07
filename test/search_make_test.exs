defmodule Laveno.SearchMakeTest do
  use ExUnit.Case, async: false

  alias Laveno.Board
  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Fen
  alias Laveno.Finders.MinimaxABPruningNegamaxETS, as: Finder
  alias Laveno.SearchControl

  defp norm(bb), do: Map.new(bb, fn {k, v} -> {k, Attacks.as_int(v)} end)

  test "generate_moves does not inject opponent e1g1 as a castle" do
    board =
      Board.new(:empty)
      |> Board.place_piece(:K, "c2")
      |> Board.place_piece(:k, "g8")
      |> Board.place_piece(:r, "e1")
      |> Board.place_piece(:R, "h1")
      |> Board.clear_castles()

    refute "e1g1" in Utils.generate_moves(board)
    refute "e1c1" in Utils.generate_moves(board)
    assert Board.apply_search(board, "e1g1") == {:error, "invalid move"}
  end

  test "e1g1 is a rook slide when the king is not on e1" do
    board =
      Board.new(:empty)
      |> Board.place_piece(:K, "h2")
      |> Board.place_piece(:k, "e8")
      |> Board.place_piece(:R, "e1")
      |> Board.clear_castles()

    via_move = Board.move(board, "e1g1")
    via_search = Board.apply_search(board, "e1g1")

    assert Utils.which_piece?(via_move, "g1") == :R
    assert Utils.which_piece?(via_move, "e1") == nil
    assert Utils.which_piece?(via_move, "h2") == :K
    assert Utils.which_piece?(via_search, "g1") == :R
    assert Utils.which_piece?(via_search, "e1") == nil
    assert Utils.which_piece?(via_search, "h2") == :K
    assert Utils.which_piece?(via_search, "f1") == nil
    assert norm(via_search.bb) == norm(via_move.bb)
  end

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
