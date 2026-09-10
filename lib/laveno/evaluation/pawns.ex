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

  def eval(board), do: eval(board, Placement.phase(board))

  def eval(board, phase) do
    c = counts(board)

    mg =
      c.isolated * @isolated_mg + c.doubled * @doubled_mg + c.connected * @connected_mg +
        c.passed_1 * elem(@passed_mg, 1) + c.passed_2 * elem(@passed_mg, 2) +
        c.passed_3 * elem(@passed_mg, 3) + c.passed_4 * elem(@passed_mg, 4) +
        c.passed_5 * elem(@passed_mg, 5) + c.passed_6 * elem(@passed_mg, 6) +
        c.open_file * @open_file_mg + c.semi_open * @semi_open_mg

    eg =
      c.isolated * @isolated_eg + c.doubled * @doubled_eg + c.connected * @connected_eg +
        c.passed_1 * elem(@passed_eg, 1) + c.passed_2 * elem(@passed_eg, 2) +
        c.passed_3 * elem(@passed_eg, 3) + c.passed_4 * elem(@passed_eg, 4) +
        c.passed_5 * elem(@passed_eg, 5) + c.passed_6 * elem(@passed_eg, 6) +
        c.open_file * @open_file_eg + c.semi_open * @semi_open_eg

    Placement.interpolate(mg, eg, phase)
  end

  def counts(board) do
    merge(side_counts(board, :white), side_counts(board, :black))
  end

  defp merge(w, b) do
    Map.merge(w, b, fn _k, wv, bv -> wv - bv end)
  end

  defp side_counts(board, color) do
    {ours_p, theirs_p, rook} = pieces(color)
    ours = Attacks.as_int(board.bb[ours_p])
    theirs = Attacks.as_int(board.bb[theirs_p])
    front = if color == :white, do: @masks.w_front, else: @masks.b_front

    acc = %{
      isolated: 0,
      doubled: doubled_extra(ours),
      connected: 0,
      passed_1: 0,
      passed_2: 0,
      passed_3: 0,
      passed_4: 0,
      passed_5: 0,
      passed_6: 0,
      open_file: 0,
      semi_open: 0
    }

    acc =
      Enum.reduce(Attacks.bits(ours), acc, fn sq, acc ->
        f = rem(63 - sq, 8)
        rel = relative_rank(sq, color)
        acc = if (ours &&& elem(@masks.adj, f)) == 0, do: %{acc | isolated: acc.isolated + 1}, else: acc
        acc = if (ours &&& elem(@masks.connected, sq)) != 0, do: %{acc | connected: acc.connected + 1}, else: acc

        if (theirs &&& elem(front, sq)) == 0 do
          add_passed(acc, rel)
        else
          acc
        end
      end)

    rook_file_counts(Utils.where_is(board, rook), ours, theirs, acc)
  end

  defp add_passed(acc, 1), do: %{acc | passed_1: acc.passed_1 + 1}
  defp add_passed(acc, 2), do: %{acc | passed_2: acc.passed_2 + 1}
  defp add_passed(acc, 3), do: %{acc | passed_3: acc.passed_3 + 1}
  defp add_passed(acc, 4), do: %{acc | passed_4: acc.passed_4 + 1}
  defp add_passed(acc, 5), do: %{acc | passed_5: acc.passed_5 + 1}
  defp add_passed(acc, 6), do: %{acc | passed_6: acc.passed_6 + 1}
  defp add_passed(acc, _), do: acc

  defp doubled_extra(ours) do
    Enum.reduce(0..7, 0, fn f, acc ->
      acc + max(Attacks.popcount(ours &&& elem(@masks.files, f)) - 1, 0)
    end)
  end

  defp rook_file_counts(squares, ours, theirs, acc) do
    all = ours ||| theirs

    Enum.reduce(squares, acc, fn sq, acc ->
      file = elem(@masks.files, rem(63 - sq, 8))

      cond do
        (all &&& file) == 0 -> %{acc | open_file: acc.open_file + 1}
        (ours &&& file) == 0 -> %{acc | semi_open: acc.semi_open + 1}
        true -> acc
      end
    end)
  end

  defp pieces(:white), do: {:P, :p, :R}
  defp pieces(:black), do: {:p, :P, :r}

  defp relative_rank(sq, :white), do: div(63 - sq, 8)
  defp relative_rank(sq, :black), do: 7 - div(63 - sq, 8)

end
