defmodule Laveno.Finders.Minimax do
  alias Laveno.Board
  alias Laveno.Board.Utils
  alias Laveno.Evaluation

  @infinity_plus 1_000
  @infinity_minus -1_000

  def find(board, 0), do: Evaluation.Material.eval(board)
  def find(board = %{checkmate: true}, _depth), do: Evaluation.Material.eval(board)

  def find(board = %{active_color: <<0::1>>}, depth) do
    moves = Utils.generate_moves(board)

    evals =
      Enum.map(moves, fn move ->
        board
        |> Board.move(move)
        |> find(depth - 1)
      end)

    Enum.reduce(
      evals,
      @infinity_minus,
      fn eval, maxeval -> max(maxeval, eval) end
    )
  end

  def find(board = %{active_color: <<1::1>>}, depth) do
    moves = Utils.generate_moves(board)

    evals =
      Enum.map(moves, fn move ->
        board
        |> Board.move(move)
        |> find(depth - 1)
      end)

    Enum.reduce(
      evals,
      @infinity_plus,
      fn eval, maxeval -> min(maxeval, eval) end
    )
  end
end
