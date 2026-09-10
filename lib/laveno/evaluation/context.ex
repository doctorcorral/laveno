defmodule Laveno.Evaluation.Context do
  @moduledoc """
  One occupancy / attack pass shared by mobility, threats, and king safety.

  Also exposes signed piece and destination counts so Texel can fit those
  knobs without a second walk.
  """

  import Bitwise

  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Placement

  defstruct [
    :occ,
    :phase,
    :w_att,
    :b_att,
    :w_pawn_att,
    :b_pawn_att,
    :material,
    :placement,
    :mobility,
    :pawn,
    :knight,
    :bishop,
    :rook,
    :queen,
    :pst_mg,
    :pst_eg,
    :n_dest,
    :b_dest,
    :r_dest,
    :q_dest,
    :bishop_pair
  ]

  @w_own [:P, :N, :B, :R, :Q, :K]
  @b_own [:p, :n, :b, :r, :q, :k]

  @scan [
    {:P, :white, 100, :pawn},
    {:N, :white, 300, :knight},
    {:B, :white, 300, :bishop},
    {:R, :white, 500, :rook},
    {:Q, :white, 900, :queen},
    {:K, :white, 0, :king},
    {:p, :black, -100, :pawn},
    {:n, :black, -300, :knight},
    {:b, :black, -300, :bishop},
    {:r, :black, -500, :rook},
    {:q, :black, -900, :queen},
    {:k, :black, 0, :king}
  ]

  def build(board) do
    occ = Utils.occupancy_mask(board)
    w_own = Utils.union_mask(board, @w_own)
    b_own = Utils.union_mask(board, @b_own)
    phase = Placement.phase(board)

    acc = %{
      material: 0,
      pawn: 0,
      knight: 0,
      bishop: 0,
      rook: 0,
      queen: 0,
      w_pst: {0, 0},
      b_pst: {0, 0},
      w_att: 0,
      b_att: 0,
      w_pawn_att: 0,
      b_pawn_att: 0,
      w_n_dest: 0,
      w_b_dest: 0,
      w_r_dest: 0,
      w_q_dest: 0,
      b_n_dest: 0,
      b_b_dest: 0,
      b_r_dest: 0,
      b_q_dest: 0,
      w_pair: 0,
      b_pair: 0
    }

    acc =
      Enum.reduce(@scan, acc, fn {piece, color, mat, kind}, acc ->
        add_piece(acc, board.bb[piece], color, mat, kind, occ, own(color, w_own, b_own))
      end)

    {w_mg, w_eg} = acc.w_pst
    {b_mg, b_eg} = acc.b_pst
    pst_mg = w_mg - b_mg
    pst_eg = w_eg - b_eg
    n_dest = acc.w_n_dest - acc.b_n_dest
    b_dest = acc.w_b_dest - acc.b_b_dest
    r_dest = acc.w_r_dest - acc.b_r_dest
    q_dest = acc.w_q_dest - acc.b_q_dest
    pair = acc.w_pair - acc.b_pair
    mob_mg = n_dest * 4 + b_dest * 5 + r_dest * 3 + q_dest * 1 + pair * 28
    mob_eg = n_dest * 3 + b_dest * 4 + r_dest * 4 + q_dest * 2 + pair * 42

    %__MODULE__{
      occ: occ,
      phase: phase,
      w_att: acc.w_att,
      b_att: acc.b_att,
      w_pawn_att: acc.w_pawn_att,
      b_pawn_att: acc.b_pawn_att,
      material: acc.material,
      placement: Placement.interpolate(pst_mg, pst_eg, phase),
      mobility: Placement.interpolate(mob_mg, mob_eg, phase),
      pawn: acc.pawn,
      knight: acc.knight,
      bishop: acc.bishop,
      rook: acc.rook,
      queen: acc.queen,
      pst_mg: pst_mg,
      pst_eg: pst_eg,
      n_dest: n_dest,
      b_dest: b_dest,
      r_dest: r_dest,
      q_dest: q_dest,
      bishop_pair: pair
    }
  end

  defp own(:white, w_own, _), do: w_own
  defp own(:black, _, b_own), do: b_own

  defp add_piece(acc, bb, color, mat, kind, occ, own) do
    squares = Attacks.bits(bb)
    n = length(squares)
    sign = if color == :white, do: 1, else: -1
    acc = %{acc | material: acc.material + n * mat}
    acc = add_count(acc, kind, sign * n)
    acc = add_bishop_pair(acc, color, kind, n)

    Enum.reduce(squares, acc, fn sq, acc ->
      acc
      |> add_pst(color, kind_piece(color, kind), sq)
      |> add_attacks(color, kind, sq, occ, own)
    end)
  end

  defp add_count(acc, :pawn, n), do: %{acc | pawn: acc.pawn + n}
  defp add_count(acc, :knight, n), do: %{acc | knight: acc.knight + n}
  defp add_count(acc, :bishop, n), do: %{acc | bishop: acc.bishop + n}
  defp add_count(acc, :rook, n), do: %{acc | rook: acc.rook + n}
  defp add_count(acc, :queen, n), do: %{acc | queen: acc.queen + n}
  defp add_count(acc, :king, _), do: acc

  defp kind_piece(:white, :pawn), do: :P
  defp kind_piece(:white, :knight), do: :N
  defp kind_piece(:white, :bishop), do: :B
  defp kind_piece(:white, :rook), do: :R
  defp kind_piece(:white, :queen), do: :Q
  defp kind_piece(:white, :king), do: :K
  defp kind_piece(:black, :pawn), do: :p
  defp kind_piece(:black, :knight), do: :n
  defp kind_piece(:black, :bishop), do: :b
  defp kind_piece(:black, :rook), do: :r
  defp kind_piece(:black, :queen), do: :q
  defp kind_piece(:black, :king), do: :k

  defp add_pst(acc, :white, piece, sq) do
    {mg, eg} = Placement.pst(piece, sq)
    {m, e} = acc.w_pst
    %{acc | w_pst: {m + mg, e + eg}}
  end

  defp add_pst(acc, :black, piece, sq) do
    {mg, eg} = Placement.pst(piece, sq)
    {m, e} = acc.b_pst
    %{acc | b_pst: {m + mg, e + eg}}
  end

  defp add_bishop_pair(acc, :white, :bishop, n) when n >= 2, do: %{acc | w_pair: 1}
  defp add_bishop_pair(acc, :black, :bishop, n) when n >= 2, do: %{acc | b_pair: 1}
  defp add_bishop_pair(acc, _, _, _), do: acc

  defp add_attacks(acc, color, :pawn, sq, _occ, _own) do
    raw = if color == :white, do: Attacks.pawn_attacks_white(sq), else: Attacks.pawn_attacks_black(sq)
    put_att(acc, color, raw, true)
  end

  defp add_attacks(acc, color, :knight, sq, _occ, own) do
    raw = Attacks.knight_attacks(sq)
    acc = put_att(acc, color, raw, false)
    add_dest(acc, color, :n, raw &&& ~~~own)
  end

  defp add_attacks(acc, color, :bishop, sq, occ, own) do
    raw = Attacks.bishop_attacks(sq, occ)
    acc = put_att(acc, color, raw, false)
    add_dest(acc, color, :b, raw &&& ~~~own)
  end

  defp add_attacks(acc, color, :rook, sq, occ, own) do
    raw = Attacks.rook_attacks(sq, occ)
    acc = put_att(acc, color, raw, false)
    add_dest(acc, color, :r, raw &&& ~~~own)
  end

  defp add_attacks(acc, color, :queen, sq, occ, own) do
    raw = Attacks.queen_attacks(sq, occ)
    acc = put_att(acc, color, raw, false)
    add_dest(acc, color, :q, raw &&& ~~~own)
  end

  defp add_attacks(acc, color, :king, sq, _occ, _own) do
    put_att(acc, color, Attacks.king_attacks(sq), false)
  end

  defp put_att(acc, :white, raw, true) do
    %{acc | w_att: acc.w_att ||| raw, w_pawn_att: acc.w_pawn_att ||| raw}
  end

  defp put_att(acc, :white, raw, false), do: %{acc | w_att: acc.w_att ||| raw}

  defp put_att(acc, :black, raw, true) do
    %{acc | b_att: acc.b_att ||| raw, b_pawn_att: acc.b_pawn_att ||| raw}
  end

  defp put_att(acc, :black, raw, false), do: %{acc | b_att: acc.b_att ||| raw}

  defp add_dest(acc, :white, :n, dests), do: %{acc | w_n_dest: acc.w_n_dest + Attacks.popcount(dests)}
  defp add_dest(acc, :white, :b, dests), do: %{acc | w_b_dest: acc.w_b_dest + Attacks.popcount(dests)}
  defp add_dest(acc, :white, :r, dests), do: %{acc | w_r_dest: acc.w_r_dest + Attacks.popcount(dests)}
  defp add_dest(acc, :white, :q, dests), do: %{acc | w_q_dest: acc.w_q_dest + Attacks.popcount(dests)}
  defp add_dest(acc, :black, :n, dests), do: %{acc | b_n_dest: acc.b_n_dest + Attacks.popcount(dests)}
  defp add_dest(acc, :black, :b, dests), do: %{acc | b_b_dest: acc.b_b_dest + Attacks.popcount(dests)}
  defp add_dest(acc, :black, :r, dests), do: %{acc | b_r_dest: acc.b_r_dest + Attacks.popcount(dests)}
  defp add_dest(acc, :black, :q, dests), do: %{acc | b_q_dest: acc.b_q_dest + Attacks.popcount(dests)}
end
