defmodule Laveno.Evaluation.Threats do
  @moduledoc """
  Hanging and pawn-forked pieces. Undefended attacked pieces lose their value;
  a pawn attacking a heavier piece scores half even if the piece is defended.
  """

  import Bitwise

  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Material

  @white [:P, :N, :B, :R, :Q]
  @black [:p, :n, :b, :r, :q]

  def eval(board) do
    occ = Utils.occupancy_mask(board)
    w = side(board, occ, @white, :black, :white)
    b = side(board, occ, @black, :white, :black)

    # Only the side that cannot move is charged. The side to move can still
    # step a hanging piece away; counting both sides made leaves panic.
    if board.active_color == <<0::1>>, do: -b, else: w
  end

  defp side(board, occ, pieces, by, ours) do
    Enum.reduce(pieces, 0, fn piece, acc ->
      val = Material.piece_value(piece)

      Enum.reduce(Utils.where_is(board, piece), acc, fn sq, sum ->
        if Attacks.attacked?(board.bb, occ, sq, by) do
          cond do
            not Attacks.attacked?(board.bb, occ, sq, ours) ->
              sum - val

            pawn_hits?(board, sq, by) and val > 100 ->
              sum - div(val, 2)

            true ->
              sum
          end
        else
          sum
        end
      end)
    end)
  end

  defp pawn_hits?(board, sq, :black) do
    (Attacks.pawn_attacks_white(sq) &&& Attacks.as_int(board.bb[:p])) != 0
  end

  defp pawn_hits?(board, sq, :white) do
    (Attacks.pawn_attacks_black(sq) &&& Attacks.as_int(board.bb[:P])) != 0
  end
end
