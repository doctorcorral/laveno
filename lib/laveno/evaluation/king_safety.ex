defmodule Laveno.Evaluation.KingSafety do
  @moduledoc """
  Middlegame king safety: pawn shield, open files, and attacks on the king ring.
  Scaled to zero in a pure endgame so kings can centralize.
  """

  import Bitwise

  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Placement

  # White shield: rank-2 / rank-3 offsets for files a–h
  @w_rank2 {55, 54, 53, 52, 51, 50, 49, 48}
  @w_rank3 {47, 46, 45, 44, 43, 42, 41, 40}
  @b_rank7 {15, 14, 13, 12, 11, 10, 9, 8}
  @b_rank6 {23, 22, 21, 20, 19, 18, 17, 16}

  def eval(board), do: eval(board, nil)

  def eval(board, ctx) do
    phase = if ctx, do: ctx.phase, else: Placement.phase(board)

    if phase == 0 do
      0
    else
      Placement.interpolate(raw(counts(board, ctx)), 0, phase)
    end
  end

  def counts(board, ctx) do
    merge(side_counts(board, :white, ctx), side_counts(board, :black, ctx))
  end

  defp raw(c) do
    c.shield_far * -10 + c.shield_gone * -22 + c.king_open * -12 + c.ring * -8 +
      c.uncastled * -25
  end

  defp merge(w, b) do
    Map.merge(w, b, fn _k, wv, bv -> wv - bv end)
  end

  defp side_counts(board, color, ctx) do
    {king, pawns, by} =
      case color do
        :white -> {:K, :P, :black}
        :black -> {:k, :p, :white}
      end

    empty = %{shield_far: 0, shield_gone: 0, king_open: 0, ring: 0, uncastled: 0}

    case Utils.where_is(board, king) do
      [] ->
        empty

      [sq | _] ->
        file = rem(63 - sq, 8)
        pawn_bb = Attacks.as_int(board.bb[pawns])

        empty
        |> shield_counts(color, file, pawn_bb)
        |> open_file_counts(color, file, pawn_bb)
        |> ring_counts(board, sq, by, ctx)
        |> then(fn acc ->
          if uncastled?(color, sq, board), do: %{acc | uncastled: 1}, else: acc
        end)
    end
  end

  defp shield_counts(acc, color, file, pawn_bb) do
    files = shield_files(file)
    {close, far} = shield_ranks(color)

    Enum.reduce(files, acc, fn f, acc ->
      close_bit = 1 <<< elem(close, f)
      far_bit = 1 <<< elem(far, f)

      cond do
        (pawn_bb &&& close_bit) != 0 -> acc
        (pawn_bb &&& far_bit) != 0 -> %{acc | shield_far: acc.shield_far + 1}
        true -> %{acc | shield_gone: acc.shield_gone + 1}
      end
    end)
  end

  defp shield_files(file) when file >= 5, do: [5, 6, 7]
  defp shield_files(file) when file <= 2, do: [0, 1, 2]
  defp shield_files(_file), do: [3, 4, 5]

  defp shield_ranks(:white), do: {@w_rank2, @w_rank3}
  defp shield_ranks(:black), do: {@b_rank7, @b_rank6}

  defp open_file_counts(acc, color, file, pawn_bb) do
    Enum.reduce(max(file - 1, 0)..min(file + 1, 7), acc, fn f, acc ->
      if file_has_pawn?(color, f, pawn_bb), do: acc, else: %{acc | king_open: acc.king_open + 1}
    end)
  end

  defp file_has_pawn?(:white, file, pawn_bb) do
    mask =
      Enum.reduce(1..6, 0, fn rank, acc ->
        acc ||| 1 <<< (64 - 8 * rank - file - 1)
      end)

    (pawn_bb &&& mask) != 0
  end

  defp file_has_pawn?(:black, file, pawn_bb) do
    file_has_pawn?(:white, file, pawn_bb)
  end

  defp ring_counts(acc, board, sq, by, nil) do
    occ = Utils.occupancy_mask(board)
    ring = Attacks.king_attacks(sq) ||| 1 <<< sq

    Enum.reduce(Attacks.bits(ring), acc, fn dest, acc ->
      if Attacks.attacked?(board.bb, occ, dest, by), do: %{acc | ring: acc.ring + 1}, else: acc
    end)
  end

  defp ring_counts(acc, _board, sq, by, ctx) do
    att = if by == :black, do: ctx.b_att, else: ctx.w_att
    ring = Attacks.king_attacks(sq) ||| 1 <<< sq

    Enum.reduce(Attacks.bits(ring), acc, fn dest, acc ->
      if (att &&& 1 <<< dest) != 0, do: %{acc | ring: acc.ring + 1}, else: acc
    end)
  end

  defp uncastled?(:white, 59, %{castles: <<0::2, _::2>>}), do: true
  defp uncastled?(:black, 3, %{castles: <<_::2, 0::2>>}), do: true
  defp uncastled?(_, _, _), do: false
end
