defmodule LavenoTest.FenTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Fen
  alias Laveno.Board.Render
  alias Laveno.Board.Utils

  describe "Read FEN :" do
    test "FEN initial position" do
      fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

      {fen_state, board} = fen = Fen.load(fen)

      Render.print_board(board)

      assert board
             |> Utils.which_piece?("e8")
             |> Utils.piece_atom_to_unicode() == "♚"
    end

    test "FEN initial positionm after 1.e4" do
      fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"

      {fen_state, board} = fen = Fen.load(fen)

      Render.print_board(board)

      assert board
             |> Utils.which_piece?("e4")
             |> Utils.piece_atom_to_unicode() == "♙"
    end

    test "FEN initial positionm after 1...c5" do
      fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2"

      {fen_state, board} = fen = Fen.load(fen)

      Render.print_board(board)

      assert board
             |> Utils.which_piece?("c5")
             |> Utils.piece_atom_to_unicode() == "♟"
    end

    test "FEN initial positionm after 2.Nf3" do
      fen = "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2"

      {fen_state, board} = fen = Fen.load(fen)

      Render.print_board(board)

      assert board
             |> Utils.which_piece?("f3")
             |> Utils.piece_atom_to_unicode() == "♘"
    end
  end

  describe "Tactics FEN :" do
    test "FEN just a tactic position. Nd6#" do
      fen = "1b1B1Nb1/rRqp1kPp/1p5P/8/2N2Pp1/p3R3/B3Q3/2K5"

      {fen_state, board} = fen = Fen.load(fen)

      Render.print_board(board)
    end
  end
end
