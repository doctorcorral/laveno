defmodule Laveno.DrawTest do
  use ExUnit.Case, async: true

  alias Laveno.Board
  alias Laveno.Fen
  alias Laveno.Finders.MinimaxABPruningNegamaxETS, as: Finder

  test "FEN halfmove clock is the fifty-move ply count" do
    {_s, board} = Fen.load("4k3/8/8/8/8/8/8/4K3 w - - 17 40")
    assert board.fifty == 17
    refute Board.draw?(board)
  end

  test "100 reversible plies is a fifty-move draw" do
    {_s, board} = Fen.load("4k3/8/8/8/8/8/8/4K3 w - - 100 80")
    assert board.fifty == 100
    assert Board.draw?(board)
  end

  test "a quiet piece shuffle increments fifty and records the prior key" do
    {_s, board} = Fen.load("4k3/8/8/8/8/8/8/4K1N1 w - - 0 1")
    start_key = Board.rep_key(board)
    next = Board.move(board, "g1f3")
    assert next.fifty == 1
    assert hd(next.hist) == start_key
    refute Board.draw?(next)
  end

  test "returning to a seen position is a repetition draw" do
    {_s, board} = Fen.load("4k3/8/8/8/8/8/8/4K1N1 w - - 0 1")
    board = Board.move(board, "g1f3")
    board = Board.move(board, "e8d8")
    board = Board.move(board, "f3g1")
    board = Board.move(board, "d8e8")
    assert Board.draw?(board)
  end

  test "a pawn move resets the fifty-move clock" do
    board = Board.move(Board.new(), "e2e4")
    assert board.fifty == 0
    refute Board.draw?(board)
  end

  test "search scores a fifty-move position as a draw" do
    {_s, board} = Fen.load("4k3/8/8/8/8/8/8/4K3 w - - 100 80")
    {eval, _} = Finder.find(board, 3, -90, 90)
    assert eval == 0
  end

  test "search scores stalemate as a draw" do
    {_s, board} = Fen.load("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
    {eval, _} = Finder.find(board, 2, -90, 90)
    assert eval == 0
  end
end
