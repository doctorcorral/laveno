defmodule LavenoTest.PieceMovility.QueenTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "Queen piece movility on starting position:" do
    test "the ♕ can not move from d1 to e2" do
      assert Board.new()
             |> Utils.valid_move?("d1e2") == false
    end
  end

  describe "Queen piece movility custom :" do
    test "the ♕ can move from d4 to e5" do
      assert Board.new(:empty)
             |> Board.place_piece(:Q, "d4")
             |> Utils.valid_move?("d4e5") == true
    end

    test "the ♕ can move from c2 to f5" do
      assert Board.new(:empty)
             |> Board.place_piece(:Q, "c2")
             |> Utils.valid_move?("c2f5") == true
    end

    test "the ♕ can move from f3 to b3" do
      assert Board.new(:empty)
             |> Board.place_piece(:Q, "f3")
             |> Utils.valid_move?("f3b3") == true
    end

    test "the ♛ can move from g2 to h1" do
      assert Board.new(:empty)
             |> Board.place_piece(:q, "g2")
             |> Utils.valid_move?("g2h1") == true
    end

    test "the ♛ can move from b6 to d6" do
      assert Board.new(:empty)
             |> Board.place_piece(:q, "b6")
             |> Utils.valid_move?("b6d6") == true
    end

    test "the ♛ can not move from h4 to a5" do
      assert Board.new(:empty)
             |> Board.place_piece(:q, "h4")
             |> Utils.valid_move?("h4a5") == false
    end

    test "the ♛ can not move from a6 to h5" do
      assert Board.new(:empty)
             |> Board.place_piece(:q, "a6")
             |> Utils.valid_move?("a6h5") == false
    end

    test "the ♛ can not move from a2 to h3" do
      assert Board.new(:empty)
             |> Board.place_piece(:q, "a2")
             |> Utils.valid_move?("a2h3") == false
    end

    test "the ♛ can not move from d8 to a4" do
      assert Board.new(:empty)
             |> Board.place_piece(:q, "d8")
             |> Utils.valid_move?("d8a4") == false
    end

    test "the ♕ can not move from d1 to f6" do
      assert Board.new(:empty)
             |> Board.place_piece(:Q, "d1")
             |> Utils.valid_move?("d1f6") == false
    end

    test "the ♕ can not move from f6 to d4" do
      assert Board.new(:empty)
             |> Board.place_piece(:Q, "f6")
             |> Utils.valid_move?("f6d4") == false
    end

    test "the ♕ can not move from d1 to h4" do
      assert Board.new(:empty)
             |> Board.place_piece(:Q, "d1")
             |> Utils.valid_move?("d1h4") == false
    end

    test "the ♛ can not move from d8 to g2" do
      assert Board.new(:empty)
             |> Board.place_piece(:q, "d8")
             |> Utils.valid_move?("d8g2") == false
    end

    test "the ♛ can not move from g2 to a2 with intermediate pieces" do
      assert Board.new()
             |> Board.place_piece(:q, "g2")
             |> Board.flip_active_color()
             |> Utils.valid_move?("g2a2") == false
    end
  end
end
