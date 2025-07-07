defmodule LavenoTest.PieceMovility.BishopTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "Bishop piece movility :" do
    test "a ♗ can move from c2 to e4" do
      assert Board.new(:empty)
             |> Board.place_piece(:B, "c2")
             |> Utils.valid_move?("c2e4") == true
    end

    test "a ♗ can move from a1 to h8" do
      assert Board.new(:empty)
             |> Board.place_piece(:B, "a1")
             |> Utils.valid_move?("a1h8") == true
    end

    test "a ♗ can move from h1 to a8" do
      assert Board.new(:empty)
             |> Board.place_piece(:B, "h1")
             |> Utils.valid_move?("h1a8") == true
    end

    test "a ♝ can move from e4 to d5" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "e4")
             |> Utils.valid_move?("e4d5") == true
    end

    test "a ♝ can move from c7 to h2" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "c7")
             |> Utils.valid_move?("c7h2") == true
    end

    test "a ♝ can move from f2 to h4" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "f2")
             |> Utils.valid_move?("f2h4") == true
    end

    test "a ♝ can not move from e4 to e5" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "e4")
             |> Utils.valid_move?("e4e5") == false
    end

    test "a ♝ can not move from b7 to b6" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "b7")
             |> Utils.valid_move?("b7b6") == false
    end

    test "a ♝ can not move from c3 to a3" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "c3")
             |> Utils.valid_move?("c3a3") == false
    end

    test "a ♝ can not move from d3 to f3" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "d3")
             |> Utils.valid_move?("d3f3") == false
    end

    test "a ♝ can not move from g3 to a5" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "g3")
             |> Utils.valid_move?("g3a5") == false
    end

    test "a ♝ can not move from a1 to h1" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "a1")
             |> Utils.valid_move?("a1h1") == false
    end

    test "a ♝ can not move from h3 to a5" do
      assert Board.new(:empty)
             |> Board.place_piece(:b, "h3")
             |> Utils.valid_move?("h3a5") == false
    end

    test "a ♗ can move from f1 to a6" do
      assert Board.new(:empty)
             |> Board.place_piece(:B, "f1")
             |> Utils.valid_move?("f1a6") == true
    end
  end
end
