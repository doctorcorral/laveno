defmodule LavenoTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Utils

  describe "piece presence over initial position :" do
    test "there is a :N on g1" do
      assert Board.new()
             |> Utils.which_piece?("g1") == :N
    end

    test "there is a :n on b8" do
      assert Board.new()
             |> Utils.which_piece?("b8") == :n
    end

    test "there is a :b on f8" do
      assert Board.new()
             |> Utils.which_piece?("f8") == :b
    end

    test "there is a :r on h8" do
      assert Board.new()
             |> Utils.which_piece?("h8") == :r
    end

    test "there is a :k on e8" do
      assert Board.new()
             |> Utils.which_piece?("e8") == :k
    end

    test "there is a :K on e1" do
      assert Board.new()
             |> Utils.which_piece?("e1") == :K
    end

    test "there is a :q on d8" do
      assert Board.new()
             |> Utils.which_piece?("d8") == :q
    end

    test "there is a :Q on d1" do
      assert Board.new()
             |> Utils.which_piece?("d1") == :Q
    end

    test "there is a ;p on b7" do
      assert Board.new()
             |> Utils.which_piece?("b7") == :p
    end

    test "there is a :p on d7" do
      assert Board.new()
             |> Utils.which_piece?("d7") == :p
    end

    test "there is a :P on h2" do
      assert Board.new()
             |> Utils.which_piece?("h2") == :P
    end

    test "there is a :P on c2" do
      assert Board.new()
             |> Utils.which_piece?("c2") == :P
    end
  end
end
