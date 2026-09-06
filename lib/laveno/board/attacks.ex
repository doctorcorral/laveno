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

  def popcount(0), do: 0
  def popcount(bb) when is_integer(bb) and bb > 0, do: popcount_acc(bb, 0)
  def popcount(other), do: popcount(as_int(other))

  defp popcount_acc(0, n), do: n

  defp popcount_acc(bb, n) do
    popcount_acc(bxor(bb, bb &&& -bb), n + 1)
  end

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

  @doc "Bitboard of pieces of `by` that attack `king_sq`."
  def checkers(bbs, occ, king_sq, :black) do
    (pawn_attacks_white(king_sq) &&& as_int(bbs[:p])) |||
      (knight_attacks(king_sq) &&& as_int(bbs[:n])) |||
      (king_attacks(king_sq) &&& as_int(bbs[:k])) |||
      (bishop_attacks(king_sq, occ) &&& (as_int(bbs[:b]) ||| as_int(bbs[:q]))) |||
      (rook_attacks(king_sq, occ) &&& (as_int(bbs[:r]) ||| as_int(bbs[:q])))
  end

  def checkers(bbs, occ, king_sq, :white) do
    (pawn_attacks_black(king_sq) &&& as_int(bbs[:P])) |||
      (knight_attacks(king_sq) &&& as_int(bbs[:N])) |||
      (king_attacks(king_sq) &&& as_int(bbs[:K])) |||
      (bishop_attacks(king_sq, occ) &&& (as_int(bbs[:B]) ||| as_int(bbs[:Q]))) |||
      (rook_attacks(king_sq, occ) &&& (as_int(bbs[:R]) ||| as_int(bbs[:Q])))
  end

  @doc "Bitboard of own pieces pinned to `king_sq` by an enemy slider."
  def pinned(bbs, occ, king_sq, :white) do
    own = as_int(bbs[:P]) ||| as_int(bbs[:N]) ||| as_int(bbs[:B]) ||| as_int(bbs[:R]) |||
      as_int(bbs[:Q]) ||| as_int(bbs[:K])
    rq = as_int(bbs[:r]) ||| as_int(bbs[:q])
    bq = as_int(bbs[:b]) ||| as_int(bbs[:q])
    pins_ortho(occ, own, rq, king_sq) ||| pins_diag(occ, own, bq, king_sq)
  end

  def pinned(bbs, occ, king_sq, :black) do
    own = as_int(bbs[:p]) ||| as_int(bbs[:n]) ||| as_int(bbs[:b]) ||| as_int(bbs[:r]) |||
      as_int(bbs[:q]) ||| as_int(bbs[:k])
    rq = as_int(bbs[:R]) ||| as_int(bbs[:Q])
    bq = as_int(bbs[:B]) ||| as_int(bbs[:Q])
    pins_ortho(occ, own, rq, king_sq) ||| pins_diag(occ, own, bq, king_sq)
  end

  @doc "Squares strictly between two aligned squares; 0 if they are not on a ray."
  def between(a, b) do
    case ray_dir(a, b) do
      nil -> 0
      dir -> fill_until(elem(dir, a), b, dir, 0)
    end
  end

  defp pins_ortho(occ, own, sliders, king_sq) do
    pin_ray(occ, own, sliders, king_sq, @tables.n) |||
      pin_ray(occ, own, sliders, king_sq, @tables.s) |||
      pin_ray(occ, own, sliders, king_sq, @tables.e) |||
      pin_ray(occ, own, sliders, king_sq, @tables.w)
  end

  defp pins_diag(occ, own, sliders, king_sq) do
    pin_ray(occ, own, sliders, king_sq, @tables.ne) |||
      pin_ray(occ, own, sliders, king_sq, @tables.nw) |||
      pin_ray(occ, own, sliders, king_sq, @tables.se) |||
      pin_ray(occ, own, sliders, king_sq, @tables.sw)
  end

  defp pin_ray(occ, own, sliders, from, dir) do
    case first_occupied(elem(dir, from), occ, dir) do
      nil ->
        0

      first ->
        if (own &&& 1 <<< first) == 0 do
          0
        else
          case first_occupied(elem(dir, first), occ, dir) do
            nil ->
              0

            second ->
              if (sliders &&& 1 <<< second) != 0, do: 1 <<< first, else: 0
          end
        end
    end
  end

  defp first_occupied(nil, _occ, _dir), do: nil

  defp first_occupied(sq, occ, dir) do
    if (occ &&& 1 <<< sq) != 0, do: sq, else: first_occupied(elem(dir, sq), occ, dir)
  end

  defp ray_dir(a, b) do
    fa = rem(63 - a, 8)
    ra = div(63 - a, 8)
    fb = rem(63 - b, 8)
    rb = div(63 - b, 8)
    df = fb - fa
    dr = rb - ra
    adf = abs(df)
    adr = abs(dr)

    cond do
      df == 0 and dr > 0 -> @tables.n
      df == 0 and dr < 0 -> @tables.s
      dr == 0 and df > 0 -> @tables.e
      dr == 0 and df < 0 -> @tables.w
      adf == adr and adf > 0 and df > 0 and dr > 0 -> @tables.ne
      adf == adr and df < 0 and dr > 0 -> @tables.nw
      adf == adr and df > 0 and dr < 0 -> @tables.se
      adf == adr and df < 0 and dr < 0 -> @tables.sw
      true -> nil
    end
  end

  defp fill_until(nil, _target, _dir, acc), do: acc
  defp fill_until(sq, target, _dir, acc) when sq == target, do: acc

  defp fill_until(sq, target, dir, acc) do
    fill_until(elem(dir, sq), target, dir, acc ||| 1 <<< sq)
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
