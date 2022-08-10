defmodule LavenoTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "piece presence over initial position :" do
    test "there is a ♘ on g1" do
      assert Board.new() |> Utils.which_piece?("g1") == :N
    end

    test "there is a ♞ on b8" do
      assert Board.new() |> Utils.which_piece?("b8") == :n
    end

    test "there is a ♝ on f8" do
      assert Board.new() |> Utils.which_piece?("f8") == :b
    end

    test "there is a ♜ on h8" do
      assert Board.new() |> Utils.which_piece?("h8") == :r
    end

    test "there is a ♚ on e8" do
      assert Board.new() |> Utils.which_piece?("e8") == :k
    end

    test "there is a ♔ on e1" do
      assert Board.new() |> Utils.which_piece?("e1") == :K
    end

    test "there is a ♛ on d8" do
      assert Board.new() |> Utils.which_piece?("d8") == :q
    end

    test "there is a ♕ on d1" do
      assert Board.new() |> Utils.which_piece?("d1") == :Q
    end

    test "there is a ♟ on b7" do
      assert Board.new() |> Utils.which_piece?("b7") == :p
    end

    test "there is a ♟ on d7" do
      assert Board.new() |> Utils.which_piece?("d7") == :p
    end

    test "there is a ♙ on h2" do
      assert Board.new() |> Utils.which_piece?("h2") == :P
    end

    test "there is a ♙ on c2" do
      assert Board.new() |> Utils.which_piece?("c2") == :P
    end
  end

  describe "piece movility :" do
    test "a ♘ can move from b1 to c3" do
      assert Board.new() |> Utils.valid_move?("b1c3") == true
    end

    test "a ♘ can move from b1 to a3" do
      assert Board.new() |> Utils.valid_move?("b1a3") == true
    end

    test "a ♘ can move from g1 to f3" do
      assert Board.new() |> Utils.valid_move?("g1f3") == true
    end

    test "a ♘ can move from g1 to h3" do
      assert Board.new() |> Utils.valid_move?("g1h3") == true
    end

    test "the ♔ can move from e1 to f2" do
      assert Board.new() |> Utils.valid_move?("e1f2") == true
    end

    test "the ♔ can move from e1 to d2" do
      assert Board.new() |> Utils.valid_move?("e1d2") == true
    end

    test "the ♔ can move from e1 to d1" do
      assert Board.new() |> Utils.valid_move?("e1d1") == true
    end

    test "the ♚ can move from e8 to f7" do
      assert Board.new() |> Utils.valid_move?("e8f7") == true
    end
  end

  test "printing board on starting position" do
    b = Board.new()
    #Board.print_board( )
    assert b |> Utils.which_piece?("c2") == :P
  end
end
