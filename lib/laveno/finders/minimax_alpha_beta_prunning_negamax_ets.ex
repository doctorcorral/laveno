defmodule Laveno.Finders.MinimaxABPruningNegamaxETS do
  @moduledoc """
  Alpha-beta negamax with ETS transposition table, iterative deepening,
  aspiration windows, PVS, null-move pruning, LMR, futility, quiescence,
  two killers, history, and optional root-split SMP.
  """
  alias Laveno.Board
  alias Laveno.Board.See
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Evaluator
  alias Laveno.Search.Heuristics
  alias Laveno.SearchControl

  @neg_inf -1_000_000
  @pos_inf 1_000_000
  @table :laveno_tt
  @null_r 2
  @default_max_depth 64
  @qsearch_max_ply 8
  @delta_margin 200
  @lmr_min_depth 3
  @lmr_min_move 3
  @futility_margin 175
  @rfp_margin 90
  @asp_window 50

  @spec find(Board.t(), integer(), integer(), integer()) :: {integer(), Board.t()}
  def find(board, max_depth, alpha, beta) do
    find(board, max_depth, alpha, beta, [])
  end

  @spec find(Board.t(), integer(), integer(), integer(), keyword()) :: {integer(), Board.t()}
  def find(board, max_depth, _alpha, _beta, opts) do
    ensure_table()
    Heuristics.ensure()
    SearchControl.ensure()

    threads = max(1, Keyword.get(opts, :threads, 1))
    cap = if is_integer(max_depth) and max_depth > 0, do: max_depth, else: @default_max_depth

    Enum.reduce_while(1..cap, {0, board}, fn depth, {prev_eval, prev_board} ->
      if SearchControl.aborting?() do
        {:halt, {prev_eval, prev_board}}
      else
        {eval, new_board} = aspirated_root(board, depth, threads, prev_eval)

        if SearchControl.aborting?() do
          {:halt, {prev_eval, prev_board}}
        else
          SearchControl.set_depth(depth)
          {:cont, {eval, new_board}}
        end
      end
    end)
  end

  defp aspirated_root(board, 1, threads, _prev_eval) do
    root_search(board, 1, threads, @neg_inf, @pos_inf)
  end

  defp aspirated_root(board, depth, threads, prev_eval) do
    alpha = prev_eval - @asp_window
    beta = prev_eval + @asp_window
    {eval, new_board} = root_search(board, depth, threads, alpha, beta)

    cond do
      SearchControl.aborting?() ->
        {eval, new_board}

      eval <= alpha or eval >= beta ->
        root_search(board, depth, threads, @neg_inf, @pos_inf)

      true ->
        {eval, new_board}
    end
  end

  defp root_search(board, depth, 1, alpha, beta) do
    negamax_tt(board, depth, alpha, beta)
  end

  defp root_search(board, depth, threads, alpha, beta) do
    moves = ordered_moves(board, depth)

    cond do
      moves == [] ->
        quiesce(board, alpha, beta)

      true ->
        workers = max(1, min(threads, length(moves)))
        chunks = split_round_robin(moves, workers)

        {best_score, best_move} =
          chunks
          |> Enum.map(fn chunk ->
            Task.async(fn -> search_root_moves(board, chunk, depth, alpha, beta) end)
          end)
          |> Task.await_many(:infinity)
          |> Enum.max_by(fn {score, _move} -> score end)

        {best_score, apply_move(board, best_move)}
    end
  end

  defp search_root_moves(board, moves, depth, alpha, beta) do
    Enum.reduce(moves, {@neg_inf, hd(moves)}, fn mv, {best_score, best_move} ->
      if SearchControl.aborting?() do
        {best_score, best_move}
      else
        case Board.move(board, mv) do
          %Board{} = nb ->
            {s, _} = negamax_tt(nb, depth - 1, -beta, -alpha)
            s = -s
            if s > best_score, do: {s, mv}, else: {best_score, best_move}

          _ ->
            {best_score, best_move}
        end
      end
    end)
  end

  defp split_round_robin(moves, n) when n <= 1, do: [moves]

  defp split_round_robin(moves, n) do
    buckets = List.duplicate([], n)

    moves
    |> Enum.with_index()
    |> Enum.reduce(buckets, fn {mv, i}, acc ->
      List.update_at(acc, rem(i, n), &(&1 ++ [mv]))
    end)
    |> Enum.reject(&(&1 == []))
  end

  defp ensure_table do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

      _ ->
        :ok
    end
  end

  defp negamax_tt(board, depth, alpha, beta) do
    SearchControl.inc_nodes()

    if SearchControl.aborting?() do
      {alpha, board}
    else
      ensure_table()
      key = position_key(board)

      case :ets.lookup(@table, key) do
        [{^key, stored_depth, stored_eval, best_move, flag}] when stored_depth >= depth ->
          cond do
            flag == :exact ->
              {stored_eval, apply_move(board, best_move)}

            flag == :lower and stored_eval >= beta ->
              {stored_eval, apply_move(board, best_move)}

            flag == :upper and stored_eval <= alpha ->
              {stored_eval, apply_move(board, best_move)}

            true ->
              negamax(board, depth, alpha, beta)
          end

        _ ->
          negamax(board, depth, alpha, beta)
      end
    end
  end

  defp negamax(board, depth, alpha, beta) do
    cond do
      SearchControl.aborting?() ->
        {alpha, board}

      reverse_futile?(board, depth, beta) ->
        {stand_pat(board), board}

      null_move_cutoff?(board, depth, beta) ->
        {beta, board}

      true ->
        if depth <= 0 do
          quiesce(board, alpha, beta)
        else
          case Utils.generate_moves(board) do
            [] -> quiesce(board, alpha, beta)
            legal -> search_moves(board, depth, alpha, beta, legal)
          end
        end
    end
  end

  # If even a quiet stand-pat is a fail-high, skip the remaining tree.
  defp reverse_futile?(board, depth, beta) do
    depth in 1..2 and beta < 9_000 and not Utils.in_check?(board) and
      stand_pat(board) - @rfp_margin * depth >= beta
  end

  defp null_move_cutoff?(board, depth, beta) do
    if depth > @null_r and not Utils.in_check?(board) and not SearchControl.aborting?() do
      nm_board = Board.flip_active_color(board)
      {eval_nm, _} = negamax_tt(nm_board, depth - @null_r - 1, -beta, -beta + 1)
      -eval_nm >= beta
    else
      false
    end
  end

  defp search_moves(board, depth, alpha, beta, legal) do
    alpha_orig = alpha
    moves = ordered_moves(board, depth, legal)
    in_check? = Utils.in_check?(board)
    stand = if in_check?, do: nil, else: stand_pat(board)

    {best_score, best_move, _a, _} =
      Enum.reduce_while(moves, {@neg_inf, nil, alpha, 0}, fn mv, {bs, bm, a, idx} ->
        if SearchControl.aborting?() do
          {:halt, {bs, bm, a, idx}}
        else
          if futile_quiet?(board, mv, depth, a, in_check?, stand) do
            {:cont, {bs, bm, a, idx + 1}}
          else
            search_one(board, mv, depth, beta, bs, bm, a, idx, in_check?)
          end
        end
      end)

    if is_binary(best_move) and not SearchControl.aborting?() do
      flag =
        cond do
          best_score <= alpha_orig -> :upper
          best_score >= beta -> :lower
          true -> :exact
        end

      :ets.insert(@table, {position_key(board), depth, best_score, best_move, flag})
    end

    {best_score, apply_move(board, best_move)}
  end

  defp search_one(board, mv, depth, beta, bs, bm, a, idx, in_check?) do
    case Board.move(board, mv) do
      %Board{} = nb ->
        gives_check? = Utils.in_check?(nb)
        reduced = child_depth(depth, idx, mv, board, in_check?, gives_check?)
        pv? = bm == nil
        scout_depth = if pv?, do: depth - 1, else: reduced
        scout_beta = if pv? or beta <= a + 1, do: beta, else: a + 1

        {s, _} = negamax_tt(nb, scout_depth, -scout_beta, -a)
        s = -s

        s =
          if not pv? and s > a and not SearchControl.aborting?() do
            {s2, _} = negamax_tt(nb, depth - 1, -beta, -a)
            -s2
          else
            s
          end

        new_bs = max(bs, s)
        new_bm = if s > bs, do: mv, else: bm
        new_a = max(a, s)

        if new_a >= beta do
          if quiet_move?(board, mv), do: Heuristics.record_cutoff(depth, mv)
          {:halt, {new_bs, new_bm, new_a, idx + 1}}
        else
          {:cont, {new_bs, new_bm, new_a, idx + 1}}
        end

      _ ->
        {:cont, {bs, bm, a, idx + 1}}
    end
  end

  defp child_depth(depth, idx, mv, board, in_check?, gives_check?) do
    base = depth - 1

    if reduce_late?(depth, idx, mv, board, in_check?, gives_check?) do
      max(base - 1, 0)
    else
      base
    end
  end

  defp reduce_late?(depth, idx, mv, board, in_check?, gives_check?) do
    depth >= @lmr_min_depth and idx >= @lmr_min_move and not in_check? and not gives_check? and
      byte_size(mv) == 4 and not capture_move?(board, mv)
  end

  defp futile_quiet?(_board, _mv, _depth, _alpha, true, _stand), do: false
  defp futile_quiet?(_board, <<_::32, _::8>>, _depth, _alpha, _in_check?, _stand), do: false

  defp futile_quiet?(board, mv, depth, alpha, false, stand) when depth <= 1 and is_number(stand) do
    not capture_move?(board, mv) and stand + @futility_margin < alpha
  end

  defp futile_quiet?(_, _, _, _, _, _), do: false

  defp apply_move(board, move) when is_binary(move) do
    case Board.move(board, move) do
      %Board{} = b -> b
      _ -> board
    end
  end

  defp apply_move(board, _), do: board

  defp quiesce(board, alpha, beta), do: quiesce(board, alpha, beta, 0)

  defp quiesce(board, alpha, beta, ply) do
    SearchControl.inc_nodes()

    cond do
      SearchControl.aborting?() ->
        {alpha, board}

      ply >= @qsearch_max_ply ->
        {stand_pat(board), board}

      Utils.in_check?(board) ->
        case Utils.generate_moves(board) do
          [] ->
            {-10_000, board}

          evasions ->
            qsearch_moves(board, evasions, alpha, beta, ply, false, nil)
        end

      true ->
        stand = stand_pat(board)

        if stand >= beta do
          {stand, board}
        else
          alpha = max(alpha, stand)

          noisy =
            Utils.generate_noisy(board)
            |> Enum.sort_by(&noisy_order(board, &1), :desc)

          qsearch_moves(board, noisy, alpha, beta, ply, true, stand)
        end
    end
  end

  defp stand_pat(board) do
    score = Evaluator.static(board)
    if board.active_color == <<0::1>>, do: score, else: -score
  end

  defp qsearch_moves(board, moves, alpha, beta, ply, prune?, stand) do
    Enum.reduce_while(moves, {alpha, board}, fn mv, {a, b_board} ->
      if SearchControl.aborting?() do
        {:halt, {a, b_board}}
      else
        if prune? and prune_noisy?(board, mv, a, stand) do
          {:cont, {a, b_board}}
        else
          case Board.move(board, mv) do
            %Board{} = child ->
              {score, _} = quiesce(child, -beta, -a, ply + 1)
              score = -score

              cond do
                score >= beta -> {:halt, {score, child}}
                score > a -> {:cont, {score, child}}
                true -> {:cont, {a, board}}
              end

            _ ->
              {:cont, {a, board}}
          end
        end
      end
    end)
  end

  defp prune_noisy?(_board, <<_::32, _promo::8>>, _alpha, _stand), do: false

  defp prune_noisy?(board, move, alpha, stand) do
    victim = capture_value(board, move)
    stand + victim + @delta_margin < alpha or See.of(board, move) < 0
  end

  defp capture_value(board, <<_::16, c2::8, r2::8, _::binary>>) do
    See.value(Utils.which_piece?(board, <<c2, r2>>))
  end

  defp noisy_order(board, move) do
    See.value(moved_piece(board, move))
    |> then(fn att -> capture_value(board, move) * 16 - att end)
  end

  defp moved_piece(board, <<c1::8, r1::8, _::binary>>) do
    Utils.which_piece?(board, <<c1, r1>>)
  end

  defp capture_move?(board, <<_::16, c2::8, r2::8, _::binary>>) do
    Utils.which_piece?(board, <<c2, r2>>) != nil
  end

  defp quiet_move?(board, mv) do
    byte_size(mv) == 4 and not capture_move?(board, mv)
  end

  defp ordered_moves(board, depth) do
    ordered_moves(board, depth, Utils.generate_moves(board))
  end

  defp ordered_moves(board, depth, base) do
    ensure_table()
    Heuristics.ensure()

    base =
      case :ets.lookup(@table, position_key(board)) do
        [{_, _, _, bm, _} | _] when is_binary(bm) ->
          if bm in base, do: [bm | List.delete(base, bm)], else: base

        [{_, _, _, bm} | _] when is_binary(bm) ->
          if bm in base, do: [bm | List.delete(base, bm)], else: base

        _ ->
          base
      end

    {promos, rest} = Enum.split_with(base, &(byte_size(&1) == 5))
    {captures, others} = Enum.split_with(rest, &capture_move?(board, &1))

    captures_sorted =
      Enum.sort_by(
        captures,
        fn mv ->
          see = See.of(board, mv)
          {if(see >= 0, do: 1, else: 0), see, capture_value(board, mv)}
        end,
        :desc
      )

    promos ++ captures_sorted ++ Heuristics.sort_quiets(others, depth)
  end

  defp position_key(board) do
    {board.bb, board.castles, board.active_color, board.en_passant}
  end
end
