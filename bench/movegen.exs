# Timing harness for move generation / search.
# Usage: mix run bench/movegen.exs
#
# Baseline (binary bitboards, 0..63 scan, make-move legality, opponent movegen check)
# recorded 2026-09-04 before the integer/bitscan/attack-table work:
#   generate_moves startpos: 20 legal  2.680 ms/call
#   generate_moves e4e5:     20 legal  3.896 ms/call
#   generate_moves kiwipete: 50 legal  6.783 ms/call
#   in_check? startpos:                102.15 us/call
#   search d2 kiwipete: 60000ms time-slice (TT-polluted / qsearch blow-up)

alias Laveno.Board
alias Laveno.Board.Utils
alias Laveno.Fen
alias Laveno.Finders.MinimaxABPruningNegamaxETS, as: Finder
alias Laveno.SearchControl

Application.ensure_all_started(:laveno)
SearchControl.ensure()

positions = [
  {"startpos", Board.new()},
  {"e4e5",
   (fn ->
      {_s, b} = Fen.load("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
      b
    end).()},
  {"kiwipete",
   (fn ->
      {_s, b} =
        Fen.load("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

      b
    end).()}
]

baseline = %{
  {"generate_moves", "startpos"} => {20, 2.680},
  {"generate_moves", "e4e5"} => {20, 3.896},
  {"generate_moves", "kiwipete"} => {50, 6.783},
  {"in_check?", "startpos"} => {nil, 102.15}
}

time_ms = fn fun, n ->
  fun.()
  {us, _} = :timer.tc(fn -> Enum.each(1..n, fn _ -> fun.() end) end)
  us / 1000
end

IO.puts("=== Laveno movegen / search bench ===")
IO.puts("elixir #{System.version()}  otp #{:erlang.system_info(:otp_release)}")
IO.puts("")

Enum.each(positions, fn {name, board} ->
  moves = Utils.generate_moves(board) |> Enum.sort()
  n = 300
  ms = time_ms.(fn -> Utils.generate_moves(board) end, n)
  per = ms / n
  {base_legal, base_ms} = baseline[{"generate_moves", name}]
  speedup = base_ms / per
  IO.puts(
    "generate_moves #{name}: #{length(moves)} legal (was #{base_legal})  #{n}x in #{Float.round(ms, 1)}ms  (#{Float.round(per, 3)} ms/call)  #{Float.round(speedup, 1)}x vs baseline #{base_ms} ms/call"
  )
end)

IO.puts("")

{start_name, start_board} = hd(positions)
n_check = 3000
ms_check = time_ms.(fn -> Utils.in_check?(start_board) end, n_check)
per_us = ms_check / n_check * 1000
{_n, base_us} = baseline[{"in_check?", "startpos"}]
IO.puts(
  "in_check? #{start_name}: #{n_check}x in #{Float.round(ms_check, 1)}ms  (#{Float.round(per_us, 2)} us/call)  in_check=#{Utils.in_check?(start_board)}  #{Float.round(base_us / per_us, 1)}x vs baseline #{base_us} us/call"
)

IO.puts("")

search = fn board, depth, budget ->
  SearchControl.clear_hash()
  SearchControl.start_search(budget)
  Finder.find(board, depth, -1_000_000, 1_000_000, threads: 1)
end

Enum.each([{2, 15_000}], fn {depth, budget} ->
  Enum.each(positions, fn {name, board} ->
    {ms, {eval, new_board}} = :timer.tc(fn -> search.(board, depth, budget) end)
    ms = ms / 1000
    move = List.last(new_board.moves)
    nodes = SearchControl.nodes()
    nps = if ms > 0, do: round(nodes / (ms / 1000)), else: 0
    aborted = SearchControl.aborting?()
    IO.puts(
      "search d#{depth} #{name}: #{Float.round(ms, 1)}ms  nodes=#{nodes} nps=#{nps} aborted=#{aborted} eval=#{inspect(eval)} pv=#{inspect(move)}"
    )
  end)
end)

IO.puts("")
IO.puts("move lists (sorted) for equality checks:")

Enum.each(positions, fn {name, board} ->
  moves = Utils.generate_moves(board) |> Enum.sort()
  IO.puts("#{name}: #{Enum.join(moves, " ")}")
end)
