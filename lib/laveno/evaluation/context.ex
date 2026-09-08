defmodule Laveno.Evaluation.Context do
  @moduledoc """
  One occupancy / attack pass shared by mobility, threats, and king safety.

  Slider attacks are generated once per piece. Threats and the king ring then
  bit-test those maps instead of walking rays again. Material, placement, and
  mobility are accumulated on the same walk so `Evaluator.static/1` stays
  score-identical to summing the individual modules.
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
    :mobility
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
      w_pst: {0, 0},
      b_pst: {0, 0},
      w_att: 0,
      b_att: 0,
      w_pawn_att: 0,
      b_pawn_att: 0,
      w_mob: {0, 0},
      b_mob: {0, 0}
    }

    acc =
      Enum.reduce(@scan, acc, fn {piece, color, mat, kind}, acc ->
        add_piece(acc, board.bb[piece], color, mat, kind, occ, own(color, w_own, b_own))
      end)

    {w_mg, w_eg} = acc.w_pst
    {b_mg, b_eg} = acc.b_pst
    {wm_mg, wm_eg} = acc.w_mob
    {bm_mg, bm_eg} = acc.b_mob

    %__MODULE__{
      occ: occ,
      phase: phase,
      w_att: acc.w_att,
      b_att: acc.b_att,
      w_pawn_att: acc.w_pawn_att,
      b_pawn_att: acc.b_pawn_att,
      material: acc.material,
      placement: Placement.interpolate(w_mg - b_mg, w_eg - b_eg, phase),
      mobility: Placement.interpolate(wm_mg - bm_mg, wm_eg - bm_eg, phase)
    }
  end

  defp own(:white, w_own, _), do: w_own
  defp own(:black, _, b_own), do: b_own

  defp add_piece(acc, bb, color, mat, kind, occ, own) do
    squares = Attacks.bits(bb)
    acc = %{acc | material: acc.material + length(squares) * mat}
    acc = add_bishop_pair(acc, color, kind, squares)

    Enum.reduce(squares, acc, fn sq, acc ->
      acc
      |> add_pst(color, kind_piece(color, kind), sq)
      |> add_attacks(color, kind, sq, occ, own)
    end)
  end

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

  defp add_bishop_pair(acc, :white, :bishop, squares) when length(squares) >= 2 do
    {m, e} = acc.w_mob
    %{acc | w_mob: {m + 28, e + 42}}
  end

  defp add_bishop_pair(acc, :black, :bishop, squares) when length(squares) >= 2 do
    {m, e} = acc.b_mob
    %{acc | b_mob: {m + 28, e + 42}}
  end

  defp add_bishop_pair(acc, _, _, _), do: acc

  defp add_attacks(acc, color, :pawn, sq, _occ, _own) do
    raw = if color == :white, do: Attacks.pawn_attacks_white(sq), else: Attacks.pawn_attacks_black(sq)
    put_att(acc, color, raw, true)
  end

  defp add_attacks(acc, color, :knight, sq, _occ, own) do
    raw = Attacks.knight_attacks(sq)
    acc = put_att(acc, color, raw, false)
    add_mob(acc, color, raw &&& ~~~own, 4, 3)
  end

  defp add_attacks(acc, color, :bishop, sq, occ, own) do
    raw = Attacks.bishop_attacks(sq, occ)
    acc = put_att(acc, color, raw, false)
    add_mob(acc, color, raw &&& ~~~own, 5, 4)
  end

  defp add_attacks(acc, color, :rook, sq, occ, own) do
    raw = Attacks.rook_attacks(sq, occ)
    acc = put_att(acc, color, raw, false)
    add_mob(acc, color, raw &&& ~~~own, 3, 4)
  end

  defp add_attacks(acc, color, :queen, sq, occ, own) do
    raw = Attacks.queen_attacks(sq, occ)
    acc = put_att(acc, color, raw, false)
    add_mob(acc, color, raw &&& ~~~own, 1, 2)
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

  defp add_mob(acc, :white, dests, wmg, weg) do
    n = Attacks.popcount(dests)
    {m, e} = acc.w_mob
    %{acc | w_mob: {m + n * wmg, e + n * weg}}
  end

  defp add_mob(acc, :black, dests, wmg, weg) do
    n = Attacks.popcount(dests)
    {m, e} = acc.b_mob
    %{acc | b_mob: {m + n * wmg, e + n * weg}}
  end
end
