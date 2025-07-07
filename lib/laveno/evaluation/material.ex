defmodule Laveno.Evaluation.Material do
  # Static piece values in centipawns
  @piece_values %{Q: 900, q: 900, R: 500, r: 500, N: 300, n: 300, B: 300, b: 300, P: 100, p: 100}

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

  @doc "Get the centipawn value for a single piece atom"
  def piece_value(piece) do
    Map.get(@piece_values, piece, 0)
  end
end
