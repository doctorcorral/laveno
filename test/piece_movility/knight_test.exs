defmodule LavenoTest.PieceMovility.KnightTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "Knight piece movility :" do
    test "a ♘ can move from b1 to c3" do
      assert Board.new()
             |> Utils.valid_move?("b1c3") == true
    end

    test "a ♘ can move from b1 to a3" do
      assert Board.new()
             |> Utils.valid_move?("b1a3") == true
    end

    test "a ♘ can move from g1 to f3" do
      assert Board.new()
             |> Utils.valid_move?("g1f3") == true
    end

    test "a ♘ can move from g1 to h3" do
      assert Board.new()
             |> Utils.valid_move?("g1h3") == true
    end

    test "a ♘ can move from e4 to c5" do
      assert Board.new(:empty)
             |> Board.place_piece(:N, "e4")
             |> Utils.valid_move?("e4c5") == true
    end

    test "a ♘ can not move from h2 to a4" do
      assert Board.new(:empty)
             |> Board.place_piece(:N, "h2")
             |> Utils.valid_move?("h2a4") == false
    end

    test "a ♘ can not move from a8 to g7" do
      assert Board.new(:empty)
             |> Board.place_piece(:N, "a8")
             |> Utils.valid_move?("a8g7") == false
    end

    test "a ♘ can not move from a4 to h5" do
      assert Board.new(:empty)
             |> Board.place_piece(:N, "a4")
             |> Utils.valid_move?("a4h5") == false
    end
  end
end
