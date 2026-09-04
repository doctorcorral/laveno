defmodule Laveno.Board.See do
  @moduledoc """
  Static exchange evaluation. Returns the expected material gain of a capture
  or promotion, in the same centipawns as `Laveno.Evaluation.Material`.
  """
  import Bitwise

  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils

  @values %{
    P: 100,
    p: 100,
    N: 300,
    n: 300,
    B: 300,
    b: 300,
    R: 500,
    r: 500,
    Q: 900,
    q: 900,
    K: 10_000,
    k: 10_000
  }

  @white_order [:P, :N, :B, :R, :Q, :K]
  @black_order [:p, :n, :b, :r, :q, :k]

  def value(piece), do: Map.get(@values, piece, 0)

  def of(_board, move) when not is_binary(move), do: 0

  def of(board, <<c1::8, r1::8, c2::8, r2::8, promo::8>>) do
    exchange(board, <<c1, r1>>, <<c2, r2>>, promo)
  end

  def of(board, <<c1::8, r1::8, c2::8, r2::8>>) do
    exchange(board, <<c1, r1>>, <<c2, r2>>, nil)
  end

  def of(_board, _), do: 0

  defp exchange(board, from_sq, to_sq, promo) do
    from = offset(from_sq)
    to = offset(to_sq)
    attacker = Utils.which_piece?(board, from)
    {victim, victim_off} = victim(board, attacker, from_sq, to_sq, to)

    if attacker == nil do
      0
    else
      promo_gain = promo_delta(promo)
      gain0 = value(victim) + promo_gain
      placed = placed_piece(attacker, promo)
      {bbs, occ} = apply_first(board.bb, attacker, from, victim, victim_off, placed, to)
      next_white? = board.active_color != <<0::1>>
      fold_gains(swap_gains(bbs, occ, to, next_white?, placed, [gain0]))
    end
  end

  defp victim(board, attacker, <<_c1::8, r1::8>>, <<c2::8, r2::8>>, to) do
    case Utils.which_piece?(board, to) do
      nil when attacker in [:P, :p] and board.en_passant == <<c2, r2>> ->
        ep_off = offset(<<c2, r1>>)
        {if(attacker == :P, do: :p, else: :P), ep_off}

      nil ->
        {nil, to}

      piece ->
        {piece, to}
    end
  end

  defp promo_delta(?q), do: value(:Q) - value(:P)
  defp promo_delta(?r), do: value(:R) - value(:P)
  defp promo_delta(?b), do: value(:B) - value(:P)
  defp promo_delta(?n), do: value(:N) - value(:P)
  defp promo_delta(_), do: 0

  defp placed_piece(:P, promo) when promo in [?q, ?r, ?b, ?n] do
    case promo do
      ?q -> :Q
      ?r -> :R
      ?b -> :B
      ?n -> :N
    end
  end

  defp placed_piece(:p, promo) when promo in [?q, ?r, ?b, ?n] do
    case promo do
      ?q -> :q
      ?r -> :r
      ?b -> :b
      ?n -> :n
    end
  end

  defp placed_piece(piece, _), do: piece

  defp apply_first(bbs, attacker, from, victim, victim_off, placed, to) do
    bbs =
      bbs
      |> clear_bit(attacker, from)
      |> then(fn bb -> if victim, do: clear_bit(bb, victim, victim_off), else: bb end)
      |> set_bit(placed, to)

    occ =
      occupancy(bbs)

    {bbs, occ}
  end

  defp swap_gains(bbs, occ, to, white?, on_sq, gains) do
    case lva(bbs, occ, to, white?) do
      nil ->
        gains

      {piece, from} ->
        next_gain = value(on_sq) - hd(gains)
        {bbs, occ} = recapture(bbs, occ, piece, from, on_sq, to)
        swap_gains(bbs, occ, to, not white?, piece, [next_gain | gains])
    end
  end

  defp recapture(bbs, _occ, piece, from, prev, to) do
    bbs =
      bbs
      |> clear_bit(piece, from)
      |> clear_bit(prev, to)
      |> set_bit(piece, to)

    {bbs, occupancy(bbs)}
  end

  # `gains` is newest-first. Fold from the last capture back to the first:
  # gain[d-1] = -max(-gain[d-1], gain[d]).
  defp fold_gains([]), do: 0
  defp fold_gains(gains), do: Enum.reduce(gains, fn earlier, later -> -max(-earlier, later) end)

  defp lva(bbs, occ, sq, white?) do
    order = if white?, do: @white_order, else: @black_order
    attacks = attackers_to(bbs, occ, sq)

    Enum.find_value(order, fn piece ->
      hits = attacks &&& Attacks.as_int(bbs[piece])

      case Attacks.bits(hits) do
        [from | _] -> {piece, from}
        [] -> nil
      end
    end)
  end

  defp attackers_to(bbs, occ, sq) do
    (Attacks.pawn_attacks_black(sq) &&& Attacks.as_int(bbs[:P])) |||
      (Attacks.pawn_attacks_white(sq) &&& Attacks.as_int(bbs[:p])) |||
      (Attacks.knight_attacks(sq) &&& (Attacks.as_int(bbs[:N]) ||| Attacks.as_int(bbs[:n]))) |||
      (Attacks.king_attacks(sq) &&& (Attacks.as_int(bbs[:K]) ||| Attacks.as_int(bbs[:k]))) |||
      (Attacks.bishop_attacks(sq, occ) &&&
         (Attacks.as_int(bbs[:B]) ||| Attacks.as_int(bbs[:b]) ||| Attacks.as_int(bbs[:Q]) |||
            Attacks.as_int(bbs[:q]))) |||
      (Attacks.rook_attacks(sq, occ) &&&
         (Attacks.as_int(bbs[:R]) ||| Attacks.as_int(bbs[:r]) ||| Attacks.as_int(bbs[:Q]) |||
            Attacks.as_int(bbs[:q])))
  end

  defp occupancy(bbs) do
    Enum.reduce([:P, :p, :N, :n, :B, :b, :R, :r, :Q, :q, :K, :k], 0, fn piece, acc ->
      acc ||| Attacks.as_int(bbs[piece])
    end)
  end

  defp offset(<<c::8, r::8>>) do
    {_row, _col, off} = Utils.rco(r, c)
    off
  end

  defp set_bit(bbs, nil, _sq), do: bbs

  defp set_bit(bbs, piece, sq) do
    Map.update(bbs, piece, 0, fn x -> Attacks.as_int(x) ||| 1 <<< sq end)
  end

  defp clear_bit(bbs, nil, _sq), do: bbs

  defp clear_bit(bbs, piece, sq) do
    Map.update(bbs, piece, 0, fn x -> Attacks.as_int(x) &&& ~~~(1 <<< sq) end)
  end
end
