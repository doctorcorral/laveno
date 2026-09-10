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

  def eval(board), do: eval(board, nil)

  def eval(board, nil) do
    occ = Utils.occupancy_mask(board)
    w = side(board, occ, @white, :black, :white)
    b = side(board, occ, @black, :white, :black)

    # Only the side that cannot move is charged. The side to move can still
    # step a hanging piece away; counting both sides made leaves panic.
    if board.active_color == <<0::1>>, do: -b, else: w
  end

  def eval(board, ctx) do
    c = counts(board, ctx)

    c.hang_p * -100 + c.hang_n * -300 + c.hang_b * -300 + c.hang_r * -500 +
      c.hang_q * -900 + c.fork_n * -150 + c.fork_b * -150 + c.fork_r * -250 +
      c.fork_q * -450
  end

  def counts(board, ctx) do
    empty = %{
      hang_p: 0,
      hang_n: 0,
      hang_b: 0,
      hang_r: 0,
      hang_q: 0,
      fork_n: 0,
      fork_b: 0,
      fork_r: 0,
      fork_q: 0
    }

    {pieces, att_by, def_by, pawn_att, sign} =
      if board.active_color == <<0::1>> do
        {@black, ctx.w_att, ctx.b_att, ctx.w_pawn_att, -1}
      else
        {@white, ctx.b_att, ctx.w_att, ctx.b_pawn_att, 1}
      end

    Enum.reduce(pieces, empty, fn piece, acc ->
      Enum.reduce(Utils.where_is(board, piece), acc, fn sq, acc ->
        bit = 1 <<< sq

        cond do
          (att_by &&& bit) == 0 ->
            acc

          (def_by &&& bit) == 0 ->
            bump(acc, hang_key(piece), sign)

          (pawn_att &&& bit) != 0 and Material.piece_value(piece) > 100 ->
            bump(acc, fork_key(piece), sign)

          true ->
            acc
        end
      end)
    end)
  end

  defp hang_key(:P), do: :hang_p
  defp hang_key(:p), do: :hang_p
  defp hang_key(:N), do: :hang_n
  defp hang_key(:n), do: :hang_n
  defp hang_key(:B), do: :hang_b
  defp hang_key(:b), do: :hang_b
  defp hang_key(:R), do: :hang_r
  defp hang_key(:r), do: :hang_r
  defp hang_key(:Q), do: :hang_q
  defp hang_key(:q), do: :hang_q

  defp fork_key(:N), do: :fork_n
  defp fork_key(:n), do: :fork_n
  defp fork_key(:B), do: :fork_b
  defp fork_key(:b), do: :fork_b
  defp fork_key(:R), do: :fork_r
  defp fork_key(:r), do: :fork_r
  defp fork_key(:Q), do: :fork_q
  defp fork_key(:q), do: :fork_q

  defp bump(acc, key, sign), do: Map.update!(acc, key, &(&1 + sign))

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
