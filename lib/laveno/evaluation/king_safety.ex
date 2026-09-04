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

  def eval(board) do
    phase = Placement.phase(board)

    if phase == 0 do
      0
    else
      score = side(board, :white) - side(board, :black)
      Placement.interpolate(score, 0, phase)
    end
  end

  defp side(board, color) do
    {king, pawns, by} =
      case color do
        :white -> {:K, :P, :black}
        :black -> {:k, :p, :white}
      end

    case Utils.where_is(board, king) do
      [] ->
        0

      [sq | _] ->
        file = rem(63 - sq, 8)
        pawn_bb = Attacks.as_int(board.bb[pawns])
        shield(color, file, pawn_bb) +
          open_files(color, file, pawn_bb) +
          ring_pressure(board, sq, by) +
          uncastled(color, sq, board)
    end
  end

  defp shield(color, file, pawn_bb) do
    files = shield_files(file)
    {close, far} = shield_ranks(color)

    Enum.reduce(files, 0, fn f, acc ->
      close_bit = 1 <<< elem(close, f)
      far_bit = 1 <<< elem(far, f)

      cond do
        (pawn_bb &&& close_bit) != 0 -> acc
        (pawn_bb &&& far_bit) != 0 -> acc - 10
        true -> acc - 22
      end
    end)
  end

  defp shield_files(file) when file >= 5, do: [5, 6, 7]
  defp shield_files(file) when file <= 2, do: [0, 1, 2]
  defp shield_files(_file), do: [3, 4, 5]

  defp shield_ranks(:white), do: {@w_rank2, @w_rank3}
  defp shield_ranks(:black), do: {@b_rank7, @b_rank6}

  defp open_files(color, file, pawn_bb) do
    Enum.reduce(max(file - 1, 0)..min(file + 1, 7), 0, fn f, acc ->
      if file_has_pawn?(color, f, pawn_bb), do: acc, else: acc - 12
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

  defp ring_pressure(board, sq, by) do
    occ = Utils.occupancy_mask(board)
    ring = Attacks.king_attacks(sq) ||| 1 <<< sq

    Enum.reduce(Attacks.bits(ring), 0, fn dest, acc ->
      if Attacks.attacked?(board.bb, occ, dest, by), do: acc - 8, else: acc
    end)
  end

  # Extra cost for a king that never left e1/e8 while the opponent can still attack.
  defp uncastled(:white, 59, %{castles: <<0::2, _::2>>}), do: -25
  defp uncastled(:black, 3, %{castles: <<_::2, 0::2>>}), do: -25
  defp uncastled(_, _, _), do: 0
end
