defmodule Laveno.Finders.MinimaxABPruningNegamaxETS do
  @moduledoc """
  Alpha-beta negamax with ETS transposition table, iterative deepening,
  null-move pruning, and quiescence search.
  """
  alias Laveno.Board
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Evaluator
  alias Laveno.Evaluation.Material

  @neg_inf -1_000_000
  @pos_inf 1_000_000
  @table :laveno_tt
  @killer_table :laveno_killer
  @null_r 2 # reduction for null-move pruning

  @spec find(Board.t(), integer(), integer(), integer()) :: {integer(), Board.t()}
  def find(board, max_depth, _alpha, _beta) do
    ensure_table()
    ensure_killer_table()
    1..max_depth
    |> Enum.reduce({0, board}, fn depth, {_prev_eval, _prev_board} ->
      negamax_tt(board, depth, @neg_inf, @pos_inf)
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

  @doc "Ensure the killer-move ETS table exists as a named table"
  defp ensure_killer_table do
    case :ets.info(@killer_table) do
      :undefined -> :ets.new(@killer_table, [:named_table, :set, :public])
      _ -> :ok
    end
  end

  # Transposition table lookup and delegate to negamax/4
  defp negamax_tt(board, depth, alpha, beta) do
    ensure_table()
    key = position_key(board)
    case :ets.lookup(@table, key) do
      [{^key, stored_depth, stored_eval, best_move}] when stored_depth >= depth ->
        {stored_eval, Board.move(board, best_move) || board}
      _ ->
        negamax(board, depth, alpha, beta)
    end
  end

  # Negamax with null-move pruning and quiescence
  defp negamax(board, depth, alpha, beta) do
    # null-move pruning
    if depth > @null_r and not Utils.in_check?(board) do
      nm_board = Board.flip_active_color(board)
      {eval_nm, _} = negamax_tt(nm_board, depth - @null_r - 1, -beta, -beta + 1)
      score_nm = -eval_nm
      if score_nm >= beta do
        return_prune(score_nm, board)
      end
    end

    # leaf or terminal -> quiescence
    legal = Utils.generate_moves(board)
    if depth <= 0 or legal == [] do
      quiesce(board, alpha, beta)
    else
      moves = ordered_moves(board, depth)
      {best_score, best_move, _a} =
        Enum.reduce_while(moves, {@neg_inf, nil, alpha}, fn mv, {bs, bm, a} ->
          case Board.move(board, mv) do
            %Board{} = nb ->
              {s, _} = negamax_tt(nb, depth - 1, -beta, -a)
              s = -s
              new_bs = max(bs, s)
              new_bm = if s > bs, do: mv, else: bm
              new_a = max(a, s)
              if new_a >= beta do
                # Record killer move for this depth
                :ets.insert(@killer_table, {depth, mv})
                {:halt, {new_bs, new_bm, new_a}}
              else
                {:cont, {new_bs, new_bm, new_a}}
              end
            _ -> {:cont, {bs, bm, a}}
          end
        end)
      :ets.insert(@table, {position_key(board), depth, best_score, best_move})
      {best_score, Board.move(board, best_move) || board}
    end
  end

  # Proper negamax-style quiescence search
  defp quiesce(board, alpha, beta) do
    # Static evaluation oriented to the side to move
    stand0 = Evaluator.eval(board)
    stand = if board.active_color == <<0::1>>, do: stand0, else: -stand0
    if stand >= beta, do: {stand, board}, else: do_quiesce(board, stand, alpha, beta)
  end

  defp do_quiesce(board, stand, alpha, beta) do
    alpha = max(alpha, stand)
    # Only consider capture moves
    captures = Utils.generate_moves(board) |> Enum.filter(&capture_move?(board, &1))
    Enum.reduce_while(captures, {alpha, board}, fn mv, {a, _b_board} ->
      case Board.move(board, mv) do
        %Board{} = nb ->
          {score, _} = quiesce(nb, -beta, -a)
          score = -score
          cond do
            score >= beta -> {:halt, {score, nb}}
            score > a -> {:cont, {score, nb}}
            true -> {:cont, {a, board}}
          end
        _ -> {:cont, {a, board}}
      end
    end)
  end

  # Determine if a move is a capture, handling 4-byte and 5-byte moves (promotions)
  defp capture_move?(board, <<_::16, c2::8, r2::8, _::binary>>) do
    Utils.which_piece?(board, <<c2, r2>>) != nil
  end

  defp return_prune(score, board), do: {score, board}

  # Move ordering: transposition, MVV-LVA, then killer moves per depth
  defp ordered_moves(board, depth) do
    ensure_table()
    ensure_killer_table()
    base = Utils.generate_moves(board)
    base = case :ets.lookup(@table, position_key(board)) do
      [{_, _, _, bm}] when bm != nil -> [bm | List.delete(base, bm)]
      _ -> base
    end
    # MVV-LVA: sort captures by victim value descending
    {captures, others} = Enum.split_with(base, &capture_move?(board, &1))
    captures_sorted = Enum.sort_by(captures, fn <<_::16, c2::8, r2::8, _::binary>> ->
      case Utils.which_piece?(board, <<c2, r2>>) do
        nil -> 0
        piece -> Material.piece_value(piece)
      end
    end, &>=/2)
    # Insert killer move ahead of other quiet moves
    killer = case :ets.lookup(@killer_table, depth) do
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
