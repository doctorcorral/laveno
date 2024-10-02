defmodule LavenoTest.PieceMovility.PawnTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "Pawn piece movility :" do
    test "a ♙ can move from b2 to b3" do
      assert Board.new()
             |> Utils.valid_move?("b2b3") == true
    end

    test "a ♙ can move from e2 to e4" do
      assert Board.new()
             |> Utils.valid_move?("e2e4") == true
    end

    test "a ♟ can move from g7 to g5" do
      assert Board.new()
             |> Utils.valid_move?("g7g5") == true
    end

    test "a ♟ can move from g7 to g6" do
      assert Board.new()
             |> Utils.valid_move?("g7g6") == true
    end

    test "a ♟ can not move from f5 to f3" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "f5")
             |> Utils.valid_move?("f5f3") == false
    end

    test "a ♙ can not move from f3 to f5" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "f3")
             |> Utils.valid_move?("f3f5") == false
    end

    test "a ♙ can not move from b5 to b7" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "b5")
             |> Utils.valid_move?("b5b7") == false
    end

    test "a ♟ can not move from a7 to h5" do
      assert Board.new()
             |> Board.move("e2e4")
             |> Utils.valid_move?("a7h5") == false
    end

    test "a ♟ can not move from a7 to h5 from empty" do
      assert Board.new(:empty)
             |> Board.place_piece(:p, "a7")
             |> Utils.valid_move?("a7h5") == false
    end
  end

  describe "Pawn en passant :" do
    test "a ♙ can move en passant from c5 to d6" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "c5")
             |> Board.set_en_passant("d6")
             |> Utils.valid_move?("c5d6") == true
    end

    test "a ♙ can not move from c5 to d6" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "c5")
             |> Utils.valid_move?("c5d6") == false
    end

    test "a ♙ can not move from h3 to a4" do
      assert Board.new(:empty)
             |> Board.place_piece(:P, "h3")
             |> Utils.valid_move?("h3a4") == false
    end
  end
end
