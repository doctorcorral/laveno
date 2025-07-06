defmodule LavenoTest.PieceMovility.KingTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "King piece movility on starting position:" do
    test "the ♔ can not move from e1 to f2" do
      assert Board.new()
             |> Utils.valid_move?("e1f2") == false
    end

    test "the ♔ can not move from e1 to d2" do
      assert Board.new()
             |> Utils.valid_move?("e1d2") == false
    end

    test "the ♔ can not move from e1 to d1" do
      assert Board.new()
             |> Utils.valid_move?("e1d1") == false
    end

    test "the ♚ can not move from e8 to f7" do
      assert Board.new()
             |> Utils.valid_move?("e8f7") == false
    end
  end

  describe "King piece movility custom :" do
    test "the ♔ can move from d4 to e5" do
      assert Board.new(:empty)
             |> Board.place_piece(:K, "d4")
             |> Utils.valid_move?("d4e5") == true
    end

    test "the ♔ can move from e1 to d2" do
      assert Board.new(:empty)
             |> Board.place_piece(:K, "e1")
             |> Utils.valid_move?("e1d2") == true
    end

    test "the ♔ can move from c7 to b8" do
      assert Board.new(:empty)
             |> Board.place_piece(:K, "c7")
             |> Utils.valid_move?("c7b8") == true
    end

    test "the ♔ can move from g2 to h1" do
      assert Board.new(:empty)
             |> Board.place_piece(:K, "g2")
             |> Utils.valid_move?("g2h1") == true
    end

    test "the ♚ can move from b6 to c6" do
      assert Board.new(:empty)
             |> Board.place_piece(:k, "b6")
             |> Utils.valid_move?("b6c6") == true
    end

    test "the ♚ can not move from b6 to d6" do
      assert Board.new(:empty)
             |> Board.place_piece(:k, "b6")
             |> Utils.valid_move?("b6d6") == false
    end

    test "the ♚ can not move from h4 to a5" do
      assert Board.new(:empty)
             |> Board.place_piece(:k, "h4")
             |> Utils.valid_move?("h4a5") == false
    end

    test "the ♚ can not move from a6 to h5" do
      assert Board.new(:empty)
             |> Board.place_piece(:k, "a6")
             |> Utils.valid_move?("a6h5") == false
    end

    test "the ♚ can not move from a2 to h3" do
      assert Board.new(:empty)
             |> Board.place_piece(:k, "a2")
             |> Utils.valid_move?("a2h3") == false
    end
  end

  describe "King perform castling:" do
    test "the ♔ can castle O-O" do
      board = Board.new(:empty)
              |> Board.place_piece(:K, "e1")
              |> Board.place_piece(:R, "h1")

      assert Utils.valid_move?(board, "e1g1") == true
      new_board = Board.move(board, "e1g1")

      assert Utils.which_piece?(new_board, "g1") == :K
      assert Utils.which_piece?(new_board, "f1") == :R
      assert new_board.moves == ["e1g1"]
    end

    test "the ♔ can not castle O-O if the king has moved" do
      board = Board.new(:empty)
              |> Board.place_piece(:K, "e1")
              |> Board.place_piece(:R, "h1")
              |> Board.place_piece(:k, "e8")
      moved_board =
        board
        |> Board.move("e1f1")
        |> Board.move("e8e7")
        |> Board.move("f1e1")
        |> Board.move("e7e8")

      assert Utils.valid_move?(moved_board, "e1g1") == false
    end

    test "the ♔ can not castle O-O if in enemy piece in range" do
      board = Board.new(:empty)
              |> Board.place_piece(:K, "e1")
              |> Board.place_piece(:R, "h1")
              |> Board.place_piece(:b, "h3")

      assert Utils.valid_move?(board, "e1g1") == false
    end

    test "the ♚ can not castle O-O-O if no enemy piece in range" do
      board = Board.new(:empty)
              |> Board.place_piece(:k, "e8")
              |> Board.place_piece(:r, "a8")
              |> Board.place_piece(:K, "c6")
       moved_board = board
                |> Board.move("c6d5")
      assert Utils.valid_move?(moved_board, "e8c8") == true
    end

    test "the ♚ can not castle O-O-O if enemy piece in range" do
      board = Board.new(:empty)
              |> Board.place_piece(:k, "e8")
              |> Board.place_piece(:r, "a8")
              |> Board.place_piece(:N, "e4")
       moved_board = board
                |> Board.move("e4d6")
      assert Utils.valid_move?(moved_board, "e8c8") == false
    end
  end
end
