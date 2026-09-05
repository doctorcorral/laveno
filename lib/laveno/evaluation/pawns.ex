defmodule Laveno.Evaluation.Pawns do
  @moduledoc """
  Pawn structure and rook-file bonuses: isolated, doubled, connected, passed,
  and rooks on open or semi-open files.
  """

  import Bitwise

  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Placement

  @isolated_mg -16
  @isolated_eg -22
  @doubled_mg -12
  @doubled_eg -20
  @connected_mg 6
  @connected_eg 8
  @open_file_mg 18
  @open_file_eg 12
  @semi_open_mg 10
  @semi_open_eg 8

  # Indexed by relative rank (0 = own first rank). Rank-7 passers are huge in EG.
  @passed_mg {0, 8, 12, 20, 35, 55, 90, 0}
  @passed_eg {0, 16, 24, 40, 70, 110, 180, 0}

  @masks (
    files =
      List.to_tuple(
        for f <- 0..7 do
          Enum.reduce(0..7, 0, fn r, acc -> acc ||| 1 <<< (64 - 8 * r - f - 1) end)
        end
      )

    adj =
      List.to_tuple(
        for f <- 0..7 do
          left = if f > 0, do: elem(files, f - 1), else: 0
          right = if f < 7, do: elem(files, f + 1), else: 0
          left ||| right
        end
      )

    connected =
      List.to_tuple(
        for sq <- 0..63 do
          f = rem(63 - sq, 8)
          r = div(63 - sq, 8)

          Enum.reduce(max(f - 1, 0)..min(f + 1, 7), 0, fn ff, acc ->
            if ff == f do
              acc
            else
              Enum.reduce(max(r - 1, 0)..min(r + 1, 7), acc, fn rr, a ->
                a ||| 1 <<< (64 - 8 * rr - ff - 1)
              end)
            end
          end)
        end
      )

    w_front =
      List.to_tuple(
        for sq <- 0..63 do
          f = rem(63 - sq, 8)
          r = div(63 - sq, 8)

          Enum.reduce(max(f - 1, 0)..min(f + 1, 7), 0, fn ff, acc ->
            Enum.reduce((r + 1)..7//1, acc, fn rr, a ->
              a ||| 1 <<< (64 - 8 * rr - ff - 1)
            end)
          end)
        end
      )

    b_front =
      List.to_tuple(
        for sq <- 0..63 do
          f = rem(63 - sq, 8)
          r = div(63 - sq, 8)

          Enum.reduce(max(f - 1, 0)..min(f + 1, 7), 0, fn ff, acc ->
            Enum.reduce(0..(r - 1)//1, acc, fn rr, a ->
              a ||| 1 <<< (64 - 8 * rr - ff - 1)
            end)
          end)
        end
      )

    %{files: files, adj: adj, connected: connected, w_front: w_front, b_front: b_front}
  )

  def eval(board) do
    {w_mg, w_eg} = side(board, :white)
    {b_mg, b_eg} = side(board, :black)
    Placement.interpolate(w_mg - b_mg, w_eg - b_eg, Placement.phase(board))
  end

  defp side(board, color) do
    {ours_p, theirs_p, rook} = pieces(color)
    ours = Attacks.as_int(board.bb[ours_p])
    theirs = Attacks.as_int(board.bb[theirs_p])
    front = if color == :white, do: @masks.w_front, else: @masks.b_front

    {mg, eg} = doubled(ours)

    {mg, eg} =
      Enum.reduce(Attacks.bits(ours), {mg, eg}, fn sq, {m, e} ->
        f = rem(63 - sq, 8)
        rel = relative_rank(sq, color)
        isolated? = (ours &&& elem(@masks.adj, f)) == 0
        passed? = (theirs &&& elem(front, sq)) == 0
        connected? = (ours &&& elem(@masks.connected, sq)) != 0

        {m, e}
        |> add_if(isolated?, @isolated_mg, @isolated_eg)
        |> add_if(connected?, @connected_mg, @connected_eg)
        |> add_if(passed?, elem(@passed_mg, rel), elem(@passed_eg, rel))
      end)

    rook_files(Utils.where_is(board, rook), ours, theirs, {mg, eg})
  end

  defp pieces(:white), do: {:P, :p, :R}
  defp pieces(:black), do: {:p, :P, :r}

  defp relative_rank(sq, :white), do: div(63 - sq, 8)
  defp relative_rank(sq, :black), do: 7 - div(63 - sq, 8)

  defp doubled(ours) do
    Enum.reduce(0..7, {0, 0}, fn f, {m, e} ->
      extra = max(Attacks.popcount(ours &&& elem(@masks.files, f)) - 1, 0)
      {m + extra * @doubled_mg, e + extra * @doubled_eg}
    end)
  end

  defp rook_files(squares, ours, theirs, score) do
    all = ours ||| theirs

    Enum.reduce(squares, score, fn sq, {m, e} ->
      file = elem(@masks.files, rem(63 - sq, 8))

      cond do
        (all &&& file) == 0 -> {m + @open_file_mg, e + @open_file_eg}
        (ours &&& file) == 0 -> {m + @semi_open_mg, e + @semi_open_eg}
        true -> {m, e}
      end
    end)
  end

  defp add_if({m, e}, true, dmg, deg), do: {m + dmg, e + deg}
  defp add_if(score, false, _, _), do: score
end
