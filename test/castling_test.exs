defmodule Laveno.CastlingTest do
  use ExUnit.Case, async: true

  alias Laveno.Board
  alias Laveno.Board.Utils
  alias Laveno.Fen

  test "open king-and-rook position generates both white castling moves" do
    {_s, board} = Fen.load("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
    moves = Utils.generate_moves(board)
    assert "e1g1" in moves
    assert "e1c1" in moves
  end

  test "castling is applied as a king-and-rook move" do
    {_s, start} = Fen.load("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
    board = Board.move(start, "e1g1")
    assert %Board{} = board
    assert Utils.which_piece?(board, "g1") == :K
    assert Utils.which_piece?(board, "f1") == :R
    assert Utils.which_piece?(board, "e1") == nil
    assert Utils.which_piece?(board, "h1") == nil
  end

  test "capturing a rook clears that side's castling right" do
    # Black to move, rook on a8 hanging to a white... use FEN with white rook capturing a8
    {_s, board} = Fen.load("r3k3/8/8/8/8/8/8/R3K3 w Qq - 0 1")
    board = Board.move(board, "a1a8")
    assert %Board{} = board
    refute "e8c8" in Utils.generate_moves(board)
  end
end
