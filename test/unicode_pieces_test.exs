defmodule LavenoTest.UnicodePiecesTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "piece presence over initial position :" do
    test "there is a ♘ on g1" do
      assert Board.new()
             |> Utils.which_piece?("g1")
             |> Utils.piece_atom_to_unicode() == "♘"
    end

    test "there is a ♞ on b8" do
      assert Board.new()
             |> Utils.which_piece?("b8")
             |> Utils.piece_atom_to_unicode() == "♞"
    end

    test "there is a ♝ on f8" do
      assert Board.new()
             |> Utils.which_piece?("f8")
             |> Utils.piece_atom_to_unicode() == "♝"
    end

    test "there is a ♜ on h8" do
      assert Board.new()
             |> Utils.which_piece?("h8")
             |> Utils.piece_atom_to_unicode() == "♜"
    end

    test "there is a ♖ on a1" do
      assert Board.new()
             |> Utils.which_piece?("a1")
             |> Utils.piece_atom_to_unicode() == "♖"
    end

    test "there is a ♚ on e8" do
      assert Board.new()
             |> Utils.which_piece?("e8")
             |> Utils.piece_atom_to_unicode() == "♚"
    end

    test "there is a ♔ on e1" do
      assert Board.new()
             |> Utils.which_piece?("e1")
             |> Utils.piece_atom_to_unicode() == "♔"
    end

    test "there is a ♛ on d8" do
      assert Board.new()
             |> Utils.which_piece?("d8")
             |> Utils.piece_atom_to_unicode() == "♛"
    end

    test "there is a ♕ on d1" do
      assert Board.new()
             |> Utils.which_piece?("d1")
             |> Utils.piece_atom_to_unicode() == "♕"
    end

    test "there is a ♟ on b7" do
      assert Board.new()
             |> Utils.which_piece?("b7")
             |> Utils.piece_atom_to_unicode() == "♟"
    end

    test "there is a ♟ on d7" do
      assert Board.new()
             |> Utils.which_piece?("d7")
             |> Utils.piece_atom_to_unicode() == "♟"
    end

    test "there is a ♙ on h2" do
      assert Board.new()
             |> Utils.which_piece?("h2")
             |> Utils.piece_atom_to_unicode() == "♙"
    end

    test "there is a ♙ on c2" do
      assert Board.new()
             |> Utils.which_piece?("c2")
             |> Utils.piece_atom_to_unicode() == "♙"
    end
  end
end
