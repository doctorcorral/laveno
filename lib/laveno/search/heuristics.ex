defmodule Laveno.Search.Heuristics do
  @moduledoc """
  Quiet-move ordering: two killers per depth and a from-to history table.

  Search still generates legal moves; this only reorders the quiet tail
  so LMR reduces the moves that historically fail low.
  """

  @killers :laveno_killer
  @history :laveno_history
  @hist_max 10_000

  def ensure do
    ensure_table(@killers)
    ensure_table(@history)
    :ok
  end

  def clear do
    ensure()

    for table <- [@killers, @history] do
      :ets.delete_all_objects(table)
    end

    :ok
  end

  @doc "Record a quiet that caused a beta cutoff."
  def record_cutoff(depth, move) when is_integer(depth) and is_binary(move) and byte_size(move) == 4 do
    ensure()
    bump_history(move, depth)

    case :ets.lookup(@killers, depth) do
      [{^depth, ^move, _k2}] ->
        :ok

      [{^depth, k1, _k2}] ->
        :ets.insert(@killers, {depth, move, k1})

      _ ->
        :ets.insert(@killers, {depth, move, nil})
    end

    :ok
  end

  def record_cutoff(_depth, _move), do: :ok

  def killers(depth) do
    ensure()

    case :ets.lookup(@killers, depth) do
      [{^depth, k1, k2}] -> {k1, k2}
      [{^depth, k1}] -> {k1, nil}
      _ -> {nil, nil}
    end
  end

  def history(move) when is_binary(move) do
    ensure()

    case :ets.lookup(@history, move) do
      [{^move, score}] -> score
      _ -> 0
    end
  end

  def history(_), do: 0

  @doc "Killers first (k1 then k2), then remaining quiets by history."
  def sort_quiets(moves, depth) when is_list(moves) do
    {k1, k2} = killers(depth)

    Enum.sort_by(
      moves,
      fn mv ->
        cond do
          mv == k1 -> {2, 0}
          mv == k2 -> {1, 0}
          true -> {0, history(mv)}
        end
      end,
      :desc
    )
  end

  defp bump_history(move, depth) do
    bonus = depth * depth
    old = history(move)
    :ets.insert(@history, {move, old + bonus - div(old * bonus, @hist_max)})
  end

  defp ensure_table(name) do
    case :ets.info(name) do
      :undefined ->
        :ets.new(name, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

      _ ->
        :ok
    end
  end
end
