defmodule LavenoTest.PieceMovility.RookTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "Rook piece movility :" do
    test "a ♜ can move from c3 to c6" do
      assert Board.new(:empty)
             |> Board.place_piece(:r, "c3")
             |> Utils.valid_move?("c3c6") == true
    end

    test "a ♜ can move from c4 to f4" do
      assert Board.new(:empty)
             |> Board.place_piece(:r, "c4")
             |> Utils.valid_move?("c4f4") == true
    end

    test "a ♖ can move from h8 to h1" do
      assert Board.new(:empty)
             |> Board.place_piece(:R, "h8")
             |> Utils.valid_move?("h8h1") == true
    end

    test "a ♖ can move from b7 to g7" do
      assert Board.new(:empty)
             |> Board.place_piece(:R, "b7")
             |> Utils.valid_move?("b7g7") == true
    end

    test "a ♖ can move from d4 to e4" do
      assert Board.new(:empty)
             |> Board.place_piece(:R, "d4")
             |> Utils.valid_move?("d4e4") == true
    end

    test "a ♖ can not move from d4 to e5" do
      assert Board.new(:empty)
             |> Board.place_piece(:R, "d4")
             |> Utils.valid_move?("d4e5") == false
    end

    test "a ♖ can not move from h4 to a4" do
      assert Board.new(:empty)
             |> Board.place_piece(:R, "h4")
             |> Utils.valid_move?("h4a4") == true
    end

    test "a ♖ can not move from d4 to d4" do
      assert Board.new(:empty)
             |> Board.place_piece(:R, "d4")
             |> Utils.valid_move?("d4d4") == false
    end
  end
end
