defmodule Laveno.Finders.MinimaxABPruningETS do
  @moduledoc """
  Alpha-beta minimax with ETS transposition table and iterative deepening.
  """
  alias Laveno.Board
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Evaluator

  @neg_inf -1_000_000
  @pos_inf 1_000_000
  @table :laveno_tt
  @null_r 2     # Reduction constant for null-move pruning

  @spec find(Board.t(), integer(), integer(), integer()) :: {integer(), Board.t()}
  def find(board, max_depth, _alpha, _beta) do
    ensure_table()
    1..max_depth
    |> Enum.reduce({0, board}, fn depth, {_prev_eval, _prev_board} ->
      ab_search(board, depth, @neg_inf, @pos_inf)
    end)
  end

  @doc "Ensure the ETS transposition table exists as a named table"
  defp ensure_table do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])
      _ ->
        :ok
    end
  end

  defp ab_search(board, depth, alpha, beta) do
    ensure_table()
    key = position_key(board)
    case :ets.lookup(@table, key) do
      [{^key, stored_depth, stored_eval, best_move}] when stored_depth >= depth ->
        new_board = Board.move(board, best_move) || board
        {stored_eval, new_board}
      _ ->
        do_ab_search(board, depth, alpha, beta)
    end
  end

  defp do_ab_search(board, depth, alpha, beta) do
    # Null-move pruning: if depth>R and not in check, do a reduced-depth search
    prune =
      if depth > @null_r and not Utils.in_check?(board) do
        nm_board = Board.flip_active_color(board)
        {eval_nm, _} = ab_search(nm_board, depth - @null_r - 1, alpha, beta)
        cond do
          board.active_color == <<0::1>> and eval_nm >= beta -> {:prune, eval_nm}
          board.active_color == <<1::1>> and eval_nm <= alpha -> {:prune, eval_nm}
          true -> :keep
        end
      else
        :keep
      end
    case prune do
      {:prune, ev} ->
        {ev, board}
      :keep ->
        # Quiescence at leaf or no legal moves
        legal = Utils.generate_moves(board)
        if depth <= 0 or legal == [] do
          quiesce(board, alpha, beta)
        else
          moves = ordered_moves(board)
          # Branch on side to move: white maximizes, black minimizes
          {best_eval, best_move} =
            case board.active_color do
              <<0::1>> ->
                # White to move: maximize
                Enum.reduce_while(moves, {@neg_inf, nil, alpha, beta}, fn mv, {bev, bmv, a, b} ->
                  case Board.move(board, mv) do
                    %Board{} = nb ->
                      {eval, _} = ab_search(nb, depth - 1, a, b)
                      if eval > bev do
                        new_a = max(a, eval)
                        if new_a >= b do
                          {:halt, {eval, mv, new_a, b}}
                        else
                          {:cont, {eval, mv, new_a, b}}
                        end
                      else
                        {:cont, {bev, bmv, a, b}}
                      end
                    _ -> {:cont, {bev, bmv, a, b}}
                  end
                end)
                |> (fn {ev, mv, _a, _b} -> {ev, mv} end).()
              <<1::1>> ->
                # Black to move: minimize
                Enum.reduce_while(moves, {@pos_inf, nil, alpha, beta}, fn mv, {bev, bmv, a, b} ->
                  case Board.move(board, mv) do
                    %Board{} = nb ->
                      {eval, _} = ab_search(nb, depth - 1, a, b)
                      if eval < bev do
                        new_b = min(b, eval)
                        if a >= new_b do
                          {:halt, {eval, mv, a, new_b}}
                        else
                          {:cont, {eval, mv, a, new_b}}
                        end
                      else
                        {:cont, {bev, bmv, a, b}}
                      end
                    _ -> {:cont, {bev, bmv, a, b}}
                  end
                end)
                |> (fn {ev, mv, _a, _b} -> {ev, mv} end).()
            end
          # Store in transposition table
          :ets.insert(@table, {position_key(board), depth, best_eval, best_move})
          new_board = if best_move, do: Board.move(board, best_move), else: board
          {best_eval, new_board}
        end
    end
  end

  defp ordered_moves(board) do
    ensure_table()
    base = Utils.generate_moves(board)
    case :ets.lookup(@table, position_key(board)) do
      [{_pos_key, _d, _e, bm}] when not is_nil(bm) ->
        [bm | List.delete(base, bm)]
      _ ->
        base
    end
  end

  defp position_key(board) do
    {board.bb, board.castles, board.active_color, board.en_passant}
  end

  # Quiescence search on capture moves to avoid horizon effect
  defp quiesce(board, alpha, beta) do
    stand = Evaluator.eval(board)
    if stand >= beta do
      {stand, board}
    else
      alpha2 = max(alpha, stand)
      # only capture moves
      captures =
        Utils.generate_moves(board)
        |> Enum.filter(fn mv ->
          <<_::16, c2::8, r2::8>> = mv
          Utils.which_piece?(board, <<c2, r2>>) != nil
        end)
      quiesce_loop(captures, board, alpha2, beta, stand)
    end
  end

  defp quiesce_loop([], board, alpha, _beta, stand), do: {stand, board}
  defp quiesce_loop([mv | rest], board, alpha, beta, stand) do
    case Board.move(board, mv) do
      %Board{} = nb ->
        {eval, _} = quiesce(nb, alpha, beta)
        cond do
          eval >= beta -> {eval, nb}
          eval > alpha -> quiesce_loop(rest, board, eval, beta, stand)
          true -> quiesce_loop(rest, board, alpha, beta, stand)
        end
      _ -> quiesce_loop(rest, board, alpha, beta, stand)
    end
  end
end
