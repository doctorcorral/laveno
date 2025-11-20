defmodule Laveno.UCI do
  @moduledoc false
  alias Laveno.Board
  alias Laveno.Fen
  alias Laveno.Finders.MinimaxABPruning, as: Finder

  # Wrap IO.puts to swallow broken-pipe errors
  defp safe_puts(msg) when is_binary(msg) do
    try do
      IO.puts(msg)
    rescue
      _ -> :ok
    catch
      _kind, _ -> :ok
    end
  end

  @depth 2
  @correspondence_depth 3
  @correspondence_movetime 60_000  # Correspondence games use 60 seconds (60000ms)

  def main(args) do
    # Trap unexpected exceptions and write to crash.log
    Process.flag(:trap_exit, true)
    try do
      # Entry point for UCI: engine will reply only after receiving 'uci'
      # Parse a --finder option (random|minimax|alphabeta|alphabeta-simple)
      {opts, _rest, _} = OptionParser.parse(args, switches: [finder: :string], aliases: [f: :finder])
      finder = case opts[:finder] do
        "random"             -> Laveno.Finders.Random
        "minimax"            -> Laveno.Finders.Minimax
        "alphabeta"          -> Laveno.Finders.MinimaxABPruning
        "alphabeta-simple"   -> Laveno.Finders.MinimaxABPruningSimple
        "alphabeta-simple-parallel" -> Laveno.Finders.MinimaxABPruningSimpleParallel
        "alphabeta-ets"      -> Laveno.Finders.MinimaxABPruningETS
        "alphabeta-negamax-ets" -> Laveno.Finders.MinimaxABPruningNegamaxETS
        _ -> Laveno.Finders.MinimaxABPruningNegamaxETS
      end
      loop(Board.new(), finder)
    rescue
      e ->
        File.write!("crash.log", "[CRASH] #{inspect(e)}\n#{Exception.format_stacktrace()}\n", [:append])
        System.halt(1)
    end
  end

  def loop(board, finder) do
    try do
      case IO.gets("") do
        # end-of-input: halt
        nil ->
          System.halt(0)
        :eof ->
          System.halt(0)
        raw ->
          # Debug: write each incoming UCI line to a file
          try do
            File.write!("commands.log", "#{:erlang.system_time(:second)} #{inspect raw}\n", [:append])
          rescue
            _ -> :ok
          end
          cmd = String.trim(raw)
          {new_board, new_finder} =
            cond do
              cmd in ["quit", "exit"] ->
                System.halt(0)
              cmd == "" ->
                {board, finder}
              cmd == "uci" ->
                {handle(:uci, board), finder}
              cmd == "isready" ->
                {handle(:isready, board), finder}
              cmd == "help" ->
                {handle(:help, board), finder}
              String.starts_with?(cmd, "go") ->
                parse_go(cmd, board, finder)
              String.starts_with?(cmd, "stop") ->
                {handle(:stop, board), finder}
              String.starts_with?(cmd, "ucinewgame") ->
                {Board.new(), finder}
              String.starts_with?(cmd, "position startpos moves ") ->
                moves_str = String.replace_prefix(cmd, "position startpos moves ", "")
                board2 =
                  moves_str
                  |> String.trim()
                  |> String.split(" ")
                  |> Enum.reduce(Board.new(), fn mv, acc ->
                       case Board.move(acc, mv) do
                         %Board{} = b -> b
                         _ -> acc
                       end
                     end)
                {board2, finder}
              String.starts_with?(cmd, "moves ") ->
                moves_str = String.replace_prefix(cmd, "moves ", "")
                board2 =
                  moves_str
                  |> String.trim()
                  |> String.split(" ")
                  |> Enum.reduce(board, fn mv, acc ->
                       mv2 = normalize_san(acc, mv)
                       case Board.move(acc, mv2) do
                         %Board{} = b -> b
                         _ -> acc
                       end
                     end)
                {board2, finder}
              cmd == "position startpos" ->
                {handle(:startpos, board), finder}
              String.starts_with?(cmd, "position fen ") && String.contains?(cmd, " moves ") ->
                [fenpart, moves_str] = String.split(cmd, " moves ", parts: 2)
                fenstr = String.replace_prefix(fenpart, "position fen ", "")
                {handle(:fen, fenstr, moves_str, board), finder}
              String.starts_with?(cmd, "position fen ") ->
                fenstr = String.replace_prefix(cmd, "position fen ", "")
                {handle(:fen, fenstr, board), finder}
              true ->
                {board, finder}
            end
          loop(new_board, new_finder)
      end
    rescue
      e ->
        File.write!("crash.log", "[LOOP_ERROR] #{inspect(e)}\n#{Exception.format_stacktrace()}\n", [:append])
        System.halt(1)
    end
  end

  def handle(:uci, board) do
    # UCI handshake: report engine name and version
    version = Application.spec(:laveno, :vsn) |> to_string()
    safe_puts("id name laveno.one #{version}")
    safe_puts("id author Corral-Corral, Ricardo")
    safe_puts("uciok")
    board
  end

  def handle(:isready, board) do
    safe_puts("readyok")
    board
  end

  def handle(:startpos, _board) do
    # UCI 'position startpos' should not emit ascii board
    Board.new()
  end

  def handle(:go, board, finder) do
    do_go(board, finder, @depth)
  end

  # Handle go depth N
  def handle({:go_depth, depth}, board, finder) do
    do_go(board, finder, depth)
  end

  # Handle go movetime with dynamic depth based on time
  def handle({:go_movetime, movetime_ms}, board, finder) do
    # Use correspondence depth for correspondence games (exact match for 60 seconds)
    # Use default depth for faster games
    depth = if movetime_ms == @correspondence_movetime, do: @correspondence_depth, else: @depth
    do_go(board, finder, depth)
  end

  # Unified go execution: detect no legal moves or perform search
  defp do_go(board, finder, depth) do
    legal = Board.Utils.generate_moves(board)
    if legal == [] do
      safe_puts("info string no legal moves")
      safe_puts("bestmove 0000")
      board
    else
      {eval, new_board} = finder.find(board, depth, -90, 90)
      # Always take the last move the engine made
      move = List.last(new_board.moves) || ""
      # UCI requires integer centipawns; round fractional evaluations
      score_int = round(eval)
      score_str = if abs(score_int) >= 10000, do: "mate 0", else: "cp #{score_int}"
      safe_puts("info depth #{depth} score #{score_str} nodes 0 time 0 pv #{move}")
      safe_puts("bestmove #{move}")
      new_board
    end
  end

  # Parse go commands for depth, movetime, or infinite
  defp parse_go(cmd, board, finder) do
    parts = String.split(cmd)
    case parts do
      # support 'go depth N' with additional parameters
      ["go", "depth", depth_str | _] ->
        {handle({:go_depth, String.to_integer(depth_str)}, board, finder), finder}
      ["go", "movetime", movetime_str | _] ->
        movetime_ms = String.to_integer(movetime_str)
        {handle({:go_movetime, movetime_ms}, board, finder), finder}
      ["go", "infinite" | _] ->
        {handle(:go, board, finder), finder}
      _ ->
        {handle(:go, board, finder), finder}
    end
  end

  # Ignore stop for depth-limited searches to avoid duplicate bestmove
  def handle(:stop, board), do: board

  def handle(:fen, fenstring, moves, _board) do
    # UCI 'position fen' should not emit ascii board
    {_fenstate, board} = Fen.load(fenstring)
    # Apply moves with SAN normalization and safe apply
    Enum.reduce(String.split(moves, " "), board, fn mv, acc ->
      mv2 = normalize_san(acc, mv)
      case Board.move(acc, mv2) do
        %Board{} = b -> b
        _ -> acc
      end
    end)
  end

  def handle(:fen, fenstring, _board) do
    # UCI 'position fen' without moves silent
    {_fenstate, board} = Fen.load(fenstring)
    board
  end

  def handle(:help, board) do
    safe_puts("""
    laveno.one (laveno) is a chess engine written in Elixir.
    laveno can be used with a graphical user interface (GUI)
    through the Universal Chess Interface (UCI) protocol.
    Visit http://laveno.one
    """)

    board
  end

  # Convert SAN castling notation to coordinate moves
  defp normalize_san(board, mv) do
    case mv do
      "O-O"  -> if board.active_color == <<0::1>>, do: "e1g1", else: "e8g8"
      "0-0"  -> if board.active_color == <<0::1>>, do: "e1g1", else: "e8g8"
      "O-O-O"-> if board.active_color == <<0::1>>, do: "e1c1", else: "e8c8"
      "0-0-0"-> if board.active_color == <<0::1>>, do: "e1c1", else: "e8c8"
      other   -> other
    end
  end
end
