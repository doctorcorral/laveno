defmodule Laveno.UCI do
  @moduledoc """
  Universal Chess Interface for TCEC and Chess.com CCC.

  Implements the UCI subset used by Cute Chess (TCEC 4K subset plus the
  options those tournaments actually set: Hash, Threads, Ponder, SyzygyPath)
  and tolerates every other command the GUI may send.
  """
  alias Laveno.Board
  alias Laveno.Fen
  alias Laveno.Finders.MinimaxABPruningNegamaxETS, as: Finder
  alias Laveno.SearchControl

  defmodule State do
    @moduledoc false
    defstruct board: nil,
              hash_mb: 16,
              threads: 1,
              ponder: false,
              move_overhead: 80,
              syzygy_path: "",
              debug: false
  end

  @engine_name "Laveno"
  @max_search_depth 64
  @min_budget_ms 20

  def main(args) do
    Process.flag(:trap_exit, true)
    _ = Application.ensure_all_started(:laveno)
    SearchControl.ensure()

    {opts, _rest, _} =
      OptionParser.parse(args, switches: [finder: :string], aliases: [f: :finder])

    _finder = opts[:finder]
    loop(%State{board: Board.new()})
  end

  def loop(%State{} = state) do
    case IO.gets("") do
      nil ->
        System.halt(0)

      :eof ->
        System.halt(0)

      raw ->
        debug_log(state, raw)

        cmd =
          raw
          |> to_string()
          |> String.trim()
          |> String.replace("\r", "")

        new_state =
          try do
            dispatch(cmd, state)
          rescue
            e ->
              debug_crash(e)
              state
          end

        if new_state == :halt do
          System.halt(0)
        else
          loop(new_state)
        end
    end
  end

  # --- dispatch --------------------------------------------------------------

  def dispatch("", state), do: state
  def dispatch("quit", _state), do: :halt
  def dispatch("exit", _state), do: :halt
  def dispatch("uci", state), do: handle_uci(state)
  def dispatch("isready", state), do: handle_isready(state)
  def dispatch("ucinewgame", state), do: handle_newgame(state)
  def dispatch("stop", state), do: handle_stop(state)
  def dispatch("ponderhit", state), do: state
  def dispatch("help", state), do: handle_help(state)
  def dispatch("bench", state), do: handle_bench(state)

  def dispatch("position startpos", state) do
    %{state | board: Board.new()}
  end

  def dispatch(<<"position startpos moves ", rest::binary>>, state) do
    %{state | board: apply_moves(Board.new(), rest)}
  end

  def dispatch(<<"position fen ", rest::binary>>, state) do
    {fen_str, moves_str} = split_fen_and_moves(rest)
    {_fenstate, board} = Fen.load(fen_str)
    board = if moves_str == "", do: board, else: apply_moves(board, moves_str)
    %{state | board: board}
  end

  def dispatch(<<"setoption ", rest::binary>>, state), do: handle_setoption(rest, state)
  def dispatch(<<"go", rest::binary>>, state), do: handle_go(String.trim(rest), state)
  def dispatch(<<"debug ", rest::binary>>, state), do: %{state | debug: String.trim(rest) == "on"}

  def dispatch(_unknown, state), do: state

  # --- handlers --------------------------------------------------------------

  defp handle_uci(state) do
    version = engine_version()
    safe_puts("id name #{@engine_name} #{version}")
    safe_puts("id author Corral-Corral, Ricardo")
    safe_puts("option name Hash type spin default 16 min 1 max 262144")
    safe_puts("option name Threads type spin default 1 min 1 max 512")
    safe_puts("option name Ponder type check default false")
    safe_puts("option name Move Overhead type spin default 80 min 0 max 5000")
    safe_puts("option name SyzygyPath type string default <empty>")
    safe_puts("option name OwnBook type check default false")
    safe_puts("option name Clear Hash type button")
    safe_puts("uciok")
    state
  end

  defp handle_isready(state) do
    SearchControl.ensure()
    safe_puts("readyok")
    state
  end

  defp handle_newgame(state) do
    SearchControl.clear_hash()
    %{state | board: Board.new()}
  end

  defp handle_stop(state) do
    SearchControl.request_stop()
    state
  end

  defp handle_help(state) do
    safe_puts("Laveno is a UCI chess engine. Visit https://github.com/doctorcorral/laveno")
    state
  end

  defp handle_bench(state) do
    SearchControl.start_search(5_000)
    start = System.monotonic_time(:millisecond)
    {eval, new_board} = Finder.find(Board.new(), 4, -1_000_000, 1_000_000, threads: 1)
    elapsed = max(System.monotonic_time(:millisecond) - start, 1)
    move = List.last(new_board.moves) || "0000"
    nodes = SearchControl.nodes()
    safe_puts("info string bench depth 4 score cp #{round(eval)} nodes #{nodes} time #{elapsed} pv #{move}")
    state
  end

  defp handle_setoption(rest, state) do
    {name, value} = parse_setoption(rest)

    case String.downcase(name) do
      "hash" ->
        %{state | hash_mb: parse_int(value, state.hash_mb)}

      "threads" ->
        threads = parse_int(value, state.threads) |> clamp(1, 512)
        %{state | threads: threads}

      "ponder" ->
        %{state | ponder: truthy?(value)}

      "move overhead" ->
        %{state | move_overhead: parse_int(value, state.move_overhead) |> clamp(0, 5000)}

      "syzgygpath" ->
        %{state | syzygy_path: value}

      "syzygypath" ->
        %{state | syzygy_path: value}

      "ownbook" ->
        state

      "clear hash" ->
        SearchControl.clear_hash()
        state

      _ ->
        state
    end
  end

  defp handle_go(args, state) do
    params = parse_go_args(args)
    board = state.board || Board.new()
    legal = Laveno.Board.Utils.generate_moves(board)

    if legal == [] do
      safe_puts("info string no legal moves")
      safe_puts("bestmove 0000")
      state
    else
      budget = think_time_ms(params, board, state)
      depth = Map.get(params, :depth, @max_search_depth)
      SearchControl.start_search(budget)
      parent = self()
      threads = state.threads

      task =
        Task.async(fn ->
          result = Finder.find(board, depth, -1_000_000, 1_000_000, threads: threads)
          send(parent, {:search_done, result})
          result
        end)

      reader = spawn_link(fn -> send(parent, {:uci_line, IO.gets("")}) end)
      wait_search(task, reader, state, legal)
    end
  end

  defp wait_search(task, reader, state, legal) do
    receive do
      {:search_done, {eval, new_board}} ->
        if Process.alive?(reader), do: Process.exit(reader, :kill)
        _ = Task.shutdown(task, :brutal_kill)
        move = List.last(new_board.moves) || List.first(legal) || "0000"
        emit_info(eval, move)
        safe_puts("bestmove #{move}")
        %{state | board: new_board}

      {:uci_line, :eof} ->
        await_search_result(task, state, legal)

      {:uci_line, nil} ->
        await_search_result(task, state, legal)

      {:uci_line, raw} ->
        cmd =
          raw
          |> to_string()
          |> String.trim()
          |> String.replace("\r", "")

        cond do
          cmd in ["stop", "quit", "exit"] ->
            SearchControl.request_stop()
            new_state = await_search_result(task, state, legal)
            if cmd == "stop", do: new_state, else: :halt

          cmd == "isready" ->
            safe_puts("readyok")
            parent = self()
            next_reader = spawn_link(fn -> send(parent, {:uci_line, IO.gets("")}) end)
            wait_search(task, next_reader, state, legal)

          true ->
            parent = self()
            next_reader = spawn_link(fn -> send(parent, {:uci_line, IO.gets("")}) end)
            wait_search(task, next_reader, state, legal)
        end
    end
  end

  defp await_search_result(task, state, legal) do
    {eval, new_board} = Task.await(task, :infinity)
    move = List.last(new_board.moves) || List.first(legal) || "0000"
    emit_info(eval, move)
    safe_puts("bestmove #{move}")
    %{state | board: new_board}
  end

  defp engine_version do
    case Application.spec(:laveno, :vsn) do
      nil -> "0.4.0"
      vsn -> to_string(vsn)
    end
  end

  # --- time management -------------------------------------------------------

  # TCEC classical: 30'+3", 60'+6", 120'+12". CCC rapid: 15'+5" and similar.
  # Budget a slice of remaining clock plus most of the increment, always
  # leaving Move Overhead so Cute Chess does not flag us.
  defp think_time_ms(%{movetime: mt}, _board, state) when is_integer(mt) do
    max(mt - state.move_overhead, @min_budget_ms)
  end

  defp think_time_ms(%{infinite: true}, _board, _state), do: 24 * 60 * 60 * 1000

  defp think_time_ms(params, board, state) do
    white? = board.active_color == <<0::1>>
    our_time = if white?, do: Map.get(params, :wtime), else: Map.get(params, :btime)
    our_inc = if white?, do: Map.get(params, :winc), else: Map.get(params, :binc)
    our_inc = our_inc || 0

    cond do
      is_integer(our_time) ->
        moves_left = Map.get(params, :movestogo) || 30
        usable = max(our_time - state.move_overhead, @min_budget_ms)
        slice = div(usable, max(moves_left, 8)) + div(our_inc * 3, 4)
        cap = div(usable, 4)
        clamp(slice, @min_budget_ms, max(cap, @min_budget_ms))

      is_integer(Map.get(params, :depth)) ->
        60 * 60 * 1000

      true ->
        1_000
    end
  end

  defp emit_info(eval, move) do
    score_int = round(eval)

    score_str =
      cond do
        score_int >= 9_000 -> "mate #{max(div(10_000 - score_int, 2), 1)}"
        score_int <= -9_000 -> "mate -#{max(div(10_000 + score_int, 2), 1)}"
        true -> "cp #{score_int}"
      end

    nodes = SearchControl.nodes()
    time = max(SearchControl.elapsed_ms(), 1)
    nps = div(nodes * 1000, time)
    depth = max(SearchControl.depth(), 1)
    safe_puts("info depth #{depth} score #{score_str} nodes #{nodes} nps #{nps} time #{time} pv #{move}")
  end

  # --- parsing ---------------------------------------------------------------

  defp parse_go_args(args) do
    tokens = String.split(args, ~r/\s+/, trim: true)
    consume_go(tokens, %{})
  end

  defp consume_go([], acc), do: acc

  defp consume_go(["wtime", v | rest], acc), do: consume_go(rest, Map.put(acc, :wtime, parse_int(v, 0)))
  defp consume_go(["btime", v | rest], acc), do: consume_go(rest, Map.put(acc, :btime, parse_int(v, 0)))
  defp consume_go(["winc", v | rest], acc), do: consume_go(rest, Map.put(acc, :winc, parse_int(v, 0)))
  defp consume_go(["binc", v | rest], acc), do: consume_go(rest, Map.put(acc, :binc, parse_int(v, 0)))
  defp consume_go(["movestogo", v | rest], acc), do: consume_go(rest, Map.put(acc, :movestogo, parse_int(v, 30)))
  defp consume_go(["depth", v | rest], acc), do: consume_go(rest, Map.put(acc, :depth, parse_int(v, @max_search_depth)))
  defp consume_go(["nodes", v | rest], acc), do: consume_go(rest, Map.put(acc, :nodes, parse_int(v, 0)))
  defp consume_go(["movetime", v | rest], acc), do: consume_go(rest, Map.put(acc, :movetime, parse_int(v, 0)))
  defp consume_go(["infinite" | rest], acc), do: consume_go(rest, Map.put(acc, :infinite, true))
  defp consume_go(["ponder" | rest], acc), do: consume_go(rest, Map.put(acc, :ponder, true))
  defp consume_go([_ | rest], acc), do: consume_go(rest, acc)

  defp parse_setoption(rest) do
    # `name Hash value 4096` or `name Clear Hash` (button, no value)
    case Regex.run(~r/^name\s+(.+?)(?:\s+value\s+(.*))?$/i, rest) do
      [_, name, value] -> {String.trim(name), String.trim(value)}
      [_, name] -> {String.trim(name), ""}
      _ -> {rest, ""}
    end
  end

  defp split_fen_and_moves(rest) do
    case String.split(rest, ~r/\s+moves\s+/, parts: 2) do
      [fen] -> {String.trim(fen), ""}
      [fen, moves] -> {String.trim(fen), String.trim(moves)}
    end
  end

  defp apply_moves(board, moves_str) do
    moves_str
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce(board, fn mv, acc ->
      mv2 = normalize_san(acc, mv)

      case Board.move(acc, mv2) do
        %Board{} = b -> b
        _ -> acc
      end
    end)
  end

  defp normalize_san(board, mv) do
    case mv do
      "O-O" -> if board.active_color == <<0::1>>, do: "e1g1", else: "e8g8"
      "0-0" -> if board.active_color == <<0::1>>, do: "e1g1", else: "e8g8"
      "O-O-O" -> if board.active_color == <<0::1>>, do: "e1c1", else: "e8c8"
      "0-0-0" -> if board.active_color == <<0::1>>, do: "e1c1", else: "e8c8"
      other -> other
    end
  end

  defp parse_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(v, _default) when is_integer(v), do: v
  defp parse_int(_, default), do: default

  defp truthy?(v) when is_binary(v) do
    String.downcase(String.trim(v)) in ["true", "1", "yes", "on"]
  end

  defp truthy?(_), do: false

  defp clamp(n, lo, hi) when is_integer(n), do: max(lo, min(hi, n))
  defp clamp(_, lo, _), do: lo

  defp safe_puts(msg) when is_binary(msg) do
    try do
      IO.puts(msg)
    rescue
      _ -> :ok
    catch
      _kind, _ -> :ok
    end
  end

  defp debug_log(%State{debug: true}, raw) do
    if System.get_env("LAVENO_DEBUG") in ["1", "true"] do
      File.write("commands.log", "#{System.os_time(:second)} #{inspect(raw)}\n", [:append])
    end
  end

  defp debug_log(_, _), do: :ok

  defp debug_crash(e) do
    if System.get_env("LAVENO_DEBUG") in ["1", "true"] do
      File.write(
        "crash.log",
        "[LOOP_ERROR] #{inspect(e)}\n#{Exception.format_stacktrace()}\n",
        [:append]
      )
    end
  end
end
