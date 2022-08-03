defmodule LavenoTest do
  use ExUnit.Case, async: true
  doctest Laveno

  alias Laveno.Board

  test "there is a ♘ on g1" do
    assert Board.new() |> Board.which_piece?("g1") == :N
  end

  test "there is a ♞ on b8" do
    assert Board.new() |> Board.which_piece?("b8") == :n
  end

  test "there is a ♝ on f8" do
    assert Board.new() |> Board.which_piece?("f8") == :b
  end

  test "there is a ♜ on h8" do
    assert Board.new() |> Board.which_piece?("h8") == :r
  end

  test "there is a ♚ on e8" do
    assert Board.new() |> Board.which_piece?("e8") == :k
  end

  test "there is a ♔ on e1" do
    assert Board.new() |> Board.which_piece?("e1") == :K
  end

  test "there is a ♛ on d8" do
    assert Board.new() |> Board.which_piece?("d8") == :q
  end

  test "there is a ♕ on d1" do
    assert Board.new() |> Board.which_piece?("d1") == :Q
  end

  test "there is a ♟ on b7" do
    assert Board.new() |> Board.which_piece?("b7") == :p
  end

  test "there is a ♟ on d7" do
    assert Board.new() |> Board.which_piece?("d7") == :p
  end

  test "there is a ♙ on h2" do
    assert Board.new() |> Board.which_piece?("h2") == :P
  end

  test "there is a ♙ on c2" do
    assert Board.new() |> Board.which_piece?("c2") == :P
  end

  test "printing board on starting position" do
    b = Board.new()
    Board.print_board( )
    assert b |> Board.which_piece?("c2") == :P
  end
end
