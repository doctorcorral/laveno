defmodule Laveno.Finders.MinimaxABPruningNegamaxETS do
  @moduledoc """
  Alpha-beta negamax with ETS transposition table, iterative deepening,
  null-move pruning, quiescence search, and optional root-split SMP.
  """
  alias Laveno.Board
  alias Laveno.Board.See
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Material
  alias Laveno.Evaluation.Placement
  alias Laveno.SearchControl

  @neg_inf -1_000_000
  @pos_inf 1_000_000
  @table :laveno_tt
  @killer_table :laveno_killer
  @null_r 2
  @default_max_depth 64
  @qsearch_max_ply 8
  @delta_margin 200

  @spec find(Board.t(), integer(), integer(), integer()) :: {integer(), Board.t()}
  def find(board, max_depth, alpha, beta) do
    find(board, max_depth, alpha, beta, [])
  end

  @spec find(Board.t(), integer(), integer(), integer(), keyword()) :: {integer(), Board.t()}
  def find(board, max_depth, _alpha, _beta, opts) do
    ensure_table()
    ensure_killer_table()
    SearchControl.ensure()

    threads = max(1, Keyword.get(opts, :threads, 1))
    cap = if is_integer(max_depth) and max_depth > 0, do: max_depth, else: @default_max_depth

    Enum.reduce_while(1..cap, {0, board}, fn depth, {prev_eval, prev_board} ->
      if SearchControl.aborting?() do
        {:halt, {prev_eval, prev_board}}
      else
        {eval, new_board} = root_search(board, depth, threads)

        if SearchControl.aborting?() do
          {:halt, {prev_eval, prev_board}}
        else
          SearchControl.set_depth(depth)
          {:cont, {eval, new_board}}
        end
      end
    end)
  end

  defp root_search(board, depth, 1) do
    negamax_tt(board, depth, @neg_inf, @pos_inf)
  end

  defp root_search(board, depth, threads) do
    moves = ordered_moves(board, depth)

    cond do
      moves == [] ->
        quiesce(board, @neg_inf, @pos_inf)

      true ->
        workers = max(1, min(threads, length(moves)))
        chunks = split_round_robin(moves, workers)

        {best_score, best_move} =
          chunks
          |> Enum.map(fn chunk ->
            Task.async(fn -> search_root_moves(board, chunk, depth) end)
          end)
          |> Task.await_many(:infinity)
          |> Enum.max_by(fn {score, _move} -> score end)

        {best_score, apply_move(board, best_move)}
    end
  end

  defp search_root_moves(board, moves, depth) do
    Enum.reduce(moves, {@neg_inf, hd(moves)}, fn mv, {best_score, best_move} ->
      if SearchControl.aborting?() do
        {best_score, best_move}
      else
        case Board.move(board, mv) do
          %Board{} = nb ->
            {s, _} = negamax_tt(nb, depth - 1, @neg_inf, @pos_inf)
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

  defp ensure_killer_table do
    case :ets.info(@killer_table) do
      :undefined -> :ets.new(@killer_table, [:named_table, :set, :public])
      _ -> :ok
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
        [{^key, stored_depth, stored_eval, best_move}] when stored_depth >= depth ->
          {stored_eval, apply_move(board, best_move)}

        _ ->
          negamax(board, depth, alpha, beta)
      end
    end
  end

  defp negamax(board, depth, alpha, beta) do
    cond do
      SearchControl.aborting?() ->
        {alpha, board}

      null_move_cutoff?(board, depth, beta) ->
        {beta, board}

      true ->
        legal = Utils.generate_moves(board)

        if depth <= 0 or legal == [] do
          quiesce(board, alpha, beta)
        else
          search_moves(board, depth, alpha, beta)
        end
    end
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

  defp search_moves(board, depth, alpha, beta) do
    moves = ordered_moves(board, depth)

    {best_score, best_move, _a} =
      Enum.reduce_while(moves, {@neg_inf, nil, alpha}, fn mv, {bs, bm, a} ->
        if SearchControl.aborting?() do
          {:halt, {bs, bm, a}}
        else
          case Board.move(board, mv) do
            %Board{} = nb ->
              {s, _} = negamax_tt(nb, depth - 1, -beta, -a)
              s = -s
              new_bs = max(bs, s)
              new_bm = if s > bs, do: mv, else: bm
              new_a = max(a, s)

              if new_a >= beta do
                :ets.insert(@killer_table, {depth, mv})
                {:halt, {new_bs, new_bm, new_a}}
              else
                {:cont, {new_bs, new_bm, new_a}}
              end

            _ ->
              {:cont, {bs, bm, a}}
          end
        end
      end)

    if is_binary(best_move) do
      :ets.insert(@table, {position_key(board), depth, best_score, best_move})
    end

    {best_score, apply_move(board, best_move)}
  end

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
    score = Material.eval(board) + Placement.eval(board)
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
            %Board{} = nb ->
              {score, _} = quiesce(nb, -beta, -a, ply + 1)
              score = -score

              cond do
                score >= beta -> {:halt, {score, nb}}
                score > a -> {:cont, {score, nb}}
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

  defp ordered_moves(board, depth) do
    ensure_table()
    ensure_killer_table()
    base = Utils.generate_moves(board)

    base =
      case :ets.lookup(@table, position_key(board)) do
        [{_, _, _, bm}] when bm != nil -> [bm | List.delete(base, bm)]
        _ -> base
      end

    {captures, others} = Enum.split_with(base, &capture_move?(board, &1))

    captures_sorted =
      Enum.sort_by(
        captures,
        fn <<_::16, c2::8, r2::8, _::binary>> ->
          case Utils.which_piece?(board, <<c2, r2>>) do
            nil -> 0
            piece -> Material.piece_value(piece)
          end
        end,
        &>=/2
      )

    killer =
      case :ets.lookup(@killer_table, depth) do
        [{^depth, mv}] -> mv
        _ -> nil
      end

    others = if killer in others, do: [killer | List.delete(others, killer)], else: others
    captures_sorted ++ others
  end

  defp position_key(board) do
    {board.bb, board.castles, board.active_color, board.en_passant}
  end
end
