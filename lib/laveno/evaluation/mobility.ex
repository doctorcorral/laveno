defmodule Laveno.Evaluation.Mobility do
  @moduledoc """
  Piece activity: destination counts for knights, bishops, rooks, and queens,
  plus the bishop pair. Destinations are occupancy-aware and exclude own pieces.
  """

  import Bitwise

  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Placement

  @w_own [:P, :N, :B, :R, :Q, :K]
  @b_own [:p, :n, :b, :r, :q, :k]

  def eval(board) do
    occ = Utils.occupancy_mask(board)
    {w_mg, w_eg} = side(board, occ, Utils.union_mask(board, @w_own), :white)
    {b_mg, b_eg} = side(board, occ, Utils.union_mask(board, @b_own), :black)
    Placement.interpolate(w_mg - b_mg, w_eg - b_eg, Placement.phase(board))
  end

  defp side(board, occ, own, color) do
    {n, b, r, q} = pieces(color)

    {0, 0}
    |> add_count(Utils.where_is(board, n), fn sq -> Attacks.knight_attacks(sq) &&& ~~~own end, 4, 3)
    |> add_count(Utils.where_is(board, b), fn sq -> Attacks.bishop_attacks(sq, occ) &&& ~~~own end, 5, 4)
    |> add_count(Utils.where_is(board, r), fn sq -> Attacks.rook_attacks(sq, occ) &&& ~~~own end, 3, 4)
    |> add_count(Utils.where_is(board, q), fn sq -> Attacks.queen_attacks(sq, occ) &&& ~~~own end, 1, 2)
    |> add_bishop_pair(Utils.where_is(board, b))
  end

  defp pieces(:white), do: {:N, :B, :R, :Q}
  defp pieces(:black), do: {:n, :b, :r, :q}

  defp add_count({mg, eg}, squares, attacks, wmg, weg) do
    Enum.reduce(squares, {mg, eg}, fn sq, {m, e} ->
      n = Attacks.popcount(attacks.(sq))
      {m + n * wmg, e + n * weg}
    end)
  end

  defp add_bishop_pair({mg, eg}, squares) when length(squares) >= 2, do: {mg + 28, eg + 42}
  defp add_bishop_pair(score, _), do: score
end
