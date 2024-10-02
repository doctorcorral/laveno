defmodule LavenoTest.GamesTest do
  use ExUnit.Case, async: true
  doctest Laveno.Board.Utils

  alias Laveno.Board
  alias Laveno.Board.Render

  describe "First Moves :" do
    test "French Tarrasch exchange 3..dxe" do
      game = Board.new()

      game = game |> Board.move("e2e4")
      Render.print_board(game, :green)
      assert game.en_passant == "e3"

      game = game |> Board.move("e7e6")
      Render.print_board(game, :green)

      wrong_game = game |> Board.move("d7d5")
      assert {:error, "invalid move"} == wrong_game

      game = game |> Board.move("d2d4")
      Render.print_board(game, :green)

      game = game |> Board.move("d7d5")
      Render.print_board(game, :green)

      game = game |> Board.move("b1d2")
      Render.print_board(game, :green)

      game = game |> Board.move("d5e4")
      Render.print_board(game, :green)

      wrong_game = game |> Board.move("f4f5")
      assert {:error, "invalid move"} == wrong_game

      game = game |> Board.move("d2e4")
      Render.print_board(game, :green)
    end
  end
end
