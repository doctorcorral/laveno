defmodule Laveno.Evaluation.Material do
  @piece_values %{Q: 10, q: 10, P: 1, p: 1, N: 3, n: 3, B: 4, b: 4, R: 5, r: 5}

  @w_pieces [:Q, :R, :N, :B, :P]
  @b_pieces [:q, :r, :n, :b, :p]

  alias Laveno.Board
  alias Laveno.Board.Utils

  def eval(board) do
    eval(board, :w) - eval(board, :b)
  end

  def eval(board, :w), do: piece_contributions(board, @w_pieces)
  def eval(board, :b), do: piece_contributions(board, @b_pieces)

  def piece_contributions(board, pieces) do
    Enum.reduce(pieces, 0, fn piece, val ->
      val + length(Utils.where_is(board, piece)) * @piece_values[piece]
    end)
  end
end
