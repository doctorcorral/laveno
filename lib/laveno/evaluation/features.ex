defmodule Laveno.Evaluation.Features do
  @moduledoc """
  Signed counts plus game phase. `dot/2` interpolates the mg/eg groups
  the same way the eval modules do, so default weights match the oracle.
  """

  alias Laveno.Evaluation.Context
  alias Laveno.Evaluation.KingSafety
  alias Laveno.Evaluation.Pawns
  alias Laveno.Evaluation.Placement
  alias Laveno.Evaluation.Threats
  alias Laveno.Evaluation.Weights

  @linear [
    :pawn,
    :knight,
    :bishop,
    :rook,
    :queen,
    :hang_p,
    :hang_n,
    :hang_b,
    :hang_r,
    :hang_q,
    :fork_n,
    :fork_b,
    :fork_r,
    :fork_q
  ]

  @mg_eg [
    {:n_dest, :n_dest_mg, :n_dest_eg},
    {:b_dest, :b_dest_mg, :b_dest_eg},
    {:r_dest, :r_dest_mg, :r_dest_eg},
    {:q_dest, :q_dest_mg, :q_dest_eg},
    {:bishop_pair, :pair_mg, :pair_eg},
    {:isolated, :isolated_mg, :isolated_eg},
    {:doubled, :doubled_mg, :doubled_eg},
    {:connected, :connected_mg, :connected_eg},
    {:passed_1, :passed_1_mg, :passed_1_eg},
    {:passed_2, :passed_2_mg, :passed_2_eg},
    {:passed_3, :passed_3_mg, :passed_3_eg},
    {:passed_4, :passed_4_mg, :passed_4_eg},
    {:passed_5, :passed_5_mg, :passed_5_eg},
    {:passed_6, :passed_6_mg, :passed_6_eg},
    {:open_file, :open_file_mg, :open_file_eg},
    {:semi_open, :semi_open_mg, :semi_open_eg}
  ]

  @king [:shield_far, :shield_gone, :king_open, :ring, :uncastled]

  def extract(board) do
    ctx = Context.build(board)
    pawns = Pawns.counts(board)
    king = KingSafety.counts(board, ctx)
    threats = Threats.counts(board, ctx)

    %{
      phase: ctx.phase,
      pawn: ctx.pawn,
      knight: ctx.knight,
      bishop: ctx.bishop,
      rook: ctx.rook,
      queen: ctx.queen,
      pst_mg: ctx.pst_mg,
      pst_eg: ctx.pst_eg,
      n_dest: ctx.n_dest,
      b_dest: ctx.b_dest,
      r_dest: ctx.r_dest,
      q_dest: ctx.q_dest,
      bishop_pair: ctx.bishop_pair,
      isolated: pawns.isolated,
      doubled: pawns.doubled,
      connected: pawns.connected,
      passed_1: pawns.passed_1,
      passed_2: pawns.passed_2,
      passed_3: pawns.passed_3,
      passed_4: pawns.passed_4,
      passed_5: pawns.passed_5,
      passed_6: pawns.passed_6,
      open_file: pawns.open_file,
      semi_open: pawns.semi_open,
      shield_far: king.shield_far,
      shield_gone: king.shield_gone,
      king_open: king.king_open,
      ring: king.ring,
      uncastled: king.uncastled,
      hang_p: threats.hang_p,
      hang_n: threats.hang_n,
      hang_b: threats.hang_b,
      hang_r: threats.hang_r,
      hang_q: threats.hang_q,
      fork_n: threats.fork_n,
      fork_b: threats.fork_b,
      fork_r: threats.fork_r,
      fork_q: threats.fork_q
    }
  end

  def dot(features, weights \\ Weights.current()) do
    phase = features.phase

    linear =
      Enum.reduce(@linear, 0, fn key, acc ->
        acc + Map.fetch!(weights, key) * Map.fetch!(features, key)
      end)

    {mg, eg} =
      Enum.reduce(@mg_eg, {0, 0}, fn {feat, wmg, weg}, {m, e} ->
        n = Map.fetch!(features, feat)
        {m + n * Map.fetch!(weights, wmg), e + n * Map.fetch!(weights, weg)}
      end)

    pst = Placement.interpolate(features.pst_mg * weights.pst_mg, features.pst_eg * weights.pst_eg, phase)
    structure = Placement.interpolate(mg, eg, phase)

    king =
      Enum.reduce(@king, 0, fn key, acc ->
        acc + Map.fetch!(weights, key) * Map.fetch!(features, key)
      end)

    linear + pst + structure + Placement.interpolate(king, 0, phase)
  end

  def static(board, weights \\ Weights.current()) do
    dot(extract(board), weights)
  end
end
