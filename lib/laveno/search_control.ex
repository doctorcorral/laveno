defmodule Laveno.SearchControl do
  @moduledoc """
  Shared search control for tournament play: stop flag, deadline, node count,
  and transposition-table reset. Cute Chess / TCEC / CCC send `stop` and
  `ucinewgame` and expect the engine to honor the clock.
  """

  @table :laveno_search_ctrl
  @tt :laveno_tt
  @killers :laveno_killer
  @history :laveno_history

  def ensure do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :set,
          :public,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        :ok
    end
  end

  def start_search(budget_ms) when is_integer(budget_ms) and budget_ms > 0 do
    ensure()
    now = System.monotonic_time(:millisecond)
    :ets.insert(@table, {:stop, false})
    :ets.insert(@table, {:nodes, 0})
    :ets.insert(@table, {:started, now})
    :ets.insert(@table, {:deadline, now + budget_ms})
    :ets.insert(@table, {:depth, 0})
  end

  def start_search(_), do: start_search(60_000)

  def set_depth(d) when is_integer(d) do
    ensure()
    :ets.insert(@table, {:depth, d})
  end

  def depth do
    case :ets.lookup(@table, :depth) do
      [{:depth, d}] -> d
      _ -> 0
    end
  end

  def request_stop do
    ensure()
    :ets.insert(@table, {:stop, true})
  end

  def stopped? do
    case :ets.lookup(@table, :stop) do
      [{:stop, true}] -> true
      _ -> false
    end
  end

  def timed_out? do
    case :ets.lookup(@table, :deadline) do
      [{:deadline, t}] -> System.monotonic_time(:millisecond) >= t
      _ -> false
    end
  end

  def aborting?, do: stopped?() or timed_out?()

  def inc_nodes do
    ensure()
    :ets.update_counter(@table, :nodes, {2, 1}, {:nodes, 0})
  end

  def nodes do
    case :ets.lookup(@table, :nodes) do
      [{:nodes, n}] -> n
      _ -> 0
    end
  end

  def elapsed_ms do
    case :ets.lookup(@table, :started) do
      [{:started, t}] -> max(System.monotonic_time(:millisecond) - t, 0)
      _ -> 0
    end
  end

  def clear_hash do
    for table <- [@tt, @killers, @history] do
      case :ets.info(table) do
        :undefined -> :ok
        _ -> :ets.delete_all_objects(table)
      end
    end

    :ok
  end
end
