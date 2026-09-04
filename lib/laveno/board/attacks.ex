defmodule Laveno.Board.Attacks do
  @moduledoc """
  Compile-time leaper tables and occupancy-aware slider rays.

  Square offsets match the rest of the engine: 0 = h8, 63 = a1.
  File a = 0 … h = 7, rank 1 = 0 … 8 = 7.
  North (toward rank 8) decreases the offset by 8; east (toward h) decreases it by 1.
  """
  import Bitwise

  @lsb Map.new(for i <- 0..63, do: {1 <<< i, i})

  @knight_deltas [{-1, 2}, {1, 2}, {-2, 1}, {2, 1}, {-2, -1}, {2, -1}, {-1, -2}, {1, -2}]
  @king_deltas for df <- -1..1, dr <- -1..1, {df, dr} != {0, 0}, do: {df, dr}

  @tables (
    leaper = fn sq, deltas ->
      f = rem(63 - sq, 8)
      r = div(63 - sq, 8)

      Enum.reduce(deltas, 0, fn {df, dr}, acc ->
        nf = f + df
        nr = r + dr

        if nf in 0..7 and nr in 0..7 do
          acc ||| 1 <<< (64 - 8 * nr - nf - 1)
        else
          acc
        end
      end)
    end

    step = fn sq, df, dr ->
      f = rem(63 - sq, 8)
      r = div(63 - sq, 8)
      nf = f + df
      nr = r + dr
      if nf in 0..7 and nr in 0..7, do: 64 - 8 * nr - nf - 1, else: nil
    end

    next_tuple = fn df, dr ->
      List.to_tuple(for sq <- 0..63, do: step.(sq, df, dr))
    end

    %{
      knight: List.to_tuple(for sq <- 0..63, do: leaper.(sq, @knight_deltas)),
      king: List.to_tuple(for sq <- 0..63, do: leaper.(sq, @king_deltas)),
      wpawn: List.to_tuple(for sq <- 0..63, do: leaper.(sq, [{-1, 1}, {1, 1}])),
      bpawn: List.to_tuple(for sq <- 0..63, do: leaper.(sq, [{-1, -1}, {1, -1}])),
      n: next_tuple.(0, 1),
      s: next_tuple.(0, -1),
      e: next_tuple.(1, 0),
      w: next_tuple.(-1, 0),
      ne: next_tuple.(1, 1),
      nw: next_tuple.(-1, 1),
      se: next_tuple.(1, -1),
      sw: next_tuple.(-1, -1)
    }
  )

  def as_int(n) when is_integer(n) and n >= 0, do: n
  def as_int(<<n::unsigned-integer-64>>), do: n
  def as_int(_), do: 0

  def bits(0), do: []

  def bits(bb) when is_integer(bb) and bb > 0 do
    iso = bb &&& -bb
    [Map.fetch!(@lsb, iso) | bits(bxor(bb, iso))]
  end

  def bits(other), do: bits(as_int(other))

  def knight_attacks(sq), do: elem(@tables.knight, sq)
  def king_attacks(sq), do: elem(@tables.king, sq)
  def pawn_attacks_white(sq), do: elem(@tables.wpawn, sq)
  def pawn_attacks_black(sq), do: elem(@tables.bpawn, sq)

  def rook_attacks(sq, occ) do
    ray(sq, occ, @tables.n) ||| ray(sq, occ, @tables.s) ||| ray(sq, occ, @tables.e) |||
      ray(sq, occ, @tables.w)
  end

  def bishop_attacks(sq, occ) do
    ray(sq, occ, @tables.ne) ||| ray(sq, occ, @tables.nw) ||| ray(sq, occ, @tables.se) |||
      ray(sq, occ, @tables.sw)
  end

  def queen_attacks(sq, occ), do: rook_attacks(sq, occ) ||| bishop_attacks(sq, occ)

  def attacked?(bbs, occ, sq, :black) do
    (pawn_attacks_white(sq) &&& as_int(bbs[:p])) != 0 or
      (knight_attacks(sq) &&& as_int(bbs[:n])) != 0 or
      (king_attacks(sq) &&& as_int(bbs[:k])) != 0 or
      (bishop_attacks(sq, occ) &&& (as_int(bbs[:b]) ||| as_int(bbs[:q]))) != 0 or
      (rook_attacks(sq, occ) &&& (as_int(bbs[:r]) ||| as_int(bbs[:q]))) != 0
  end

  def attacked?(bbs, occ, sq, :white) do
    (pawn_attacks_black(sq) &&& as_int(bbs[:P])) != 0 or
      (knight_attacks(sq) &&& as_int(bbs[:N])) != 0 or
      (king_attacks(sq) &&& as_int(bbs[:K])) != 0 or
      (bishop_attacks(sq, occ) &&& (as_int(bbs[:B]) ||| as_int(bbs[:Q]))) != 0 or
      (rook_attacks(sq, occ) &&& (as_int(bbs[:R]) ||| as_int(bbs[:Q]))) != 0
  end

  defp ray(sq, occ, dir), do: walk(elem(dir, sq), occ, dir, 0)

  defp walk(nil, _occ, _dir, acc), do: acc

  defp walk(to, occ, dir, acc) do
    bit = 1 <<< to
    acc = acc ||| bit

    if (occ &&& bit) != 0 do
      acc
    else
      walk(elem(dir, to), occ, dir, acc)
    end
  end
end
