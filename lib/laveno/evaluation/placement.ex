defmodule Laveno.Evaluation.Placement do
  @piece_values %{Q: 900, q: 900, R: 500, r: 500, N: 300, n: 300, B: 300, b: 300, P: 100, p: 100}

  @w_pieces [:Q, :R, :N, :B, :P]
  @b_pieces [:q, :r, :n, :b, :p]
  # Core central squares (highest bonus): c4,f4,c5,f5 and inner ring
  @central_squares [26, 27, 28, 29, 34, 35, 36, 37]
  # Near-central squares (lower bonus)
  @near_center_squares [
    17, 18, 19, 20, 21, 22,
    25, 30, 33, 38,
    41, 46,
    50, 51, 52, 53
  ]
  # Placement bonus factors in centipawns (inverse proportional)
  @central_factor 42
  @near_factor 26

  alias Laveno.Board
  alias Laveno.Board.Utils

  def eval(board) do
    eval(board, :w) - eval(board, :b)
  end

  def eval(board, :w), do: centered_piece_contributions(board, @w_pieces)
  def eval(board, :b), do: centered_piece_contributions(board, @b_pieces)

  @doc "Compute center-control bonus with higher weight for central squares"
  def centered_piece_contributions(board, pieces) do
    Enum.reduce(pieces, 0, fn piece, acc ->
      Enum.reduce(Utils.where_is(board, piece), acc, fn place, sum ->
        bonus = cond do
          place in @central_squares -> @central_factor / @piece_values[piece]
          place in @near_center_squares -> @near_factor / @piece_values[piece]
          true -> 0
        end
        sum + bonus
      end)
    end)
  end
end
