defmodule Laveno.UCIProtocolTest do
  use ExUnit.Case, async: false

  alias Laveno.UCI
  alias Laveno.UCI.State
  alias Laveno.Board
  alias Laveno.Board.Utils
  alias Laveno.SearchControl

  setup do
    SearchControl.ensure()
    {:ok, state: %State{board: Board.new()}}
  end

  test "uci handshake advertises tournament options", %{state: state} do
    {output, _new_state} = capture_uci(fn -> UCI.dispatch("uci", state) end)

    assert output =~ "id name Laveno"
    assert output =~ "id author Corral-Corral, Ricardo"
    assert output =~ "option name Hash type spin"
    assert output =~ "option name Threads type spin"
    assert output =~ "option name Ponder type check default false"
    assert output =~ "option name SyzygyPath type string"
    assert output =~ "uciok"
  end

  test "isready replies readyok", %{state: state} do
    {output, _} = capture_uci(fn -> UCI.dispatch("isready", state) end)
    assert output =~ "readyok"
  end

  test "setoption Threads and Hash are accepted", %{state: state} do
    state = UCI.dispatch("setoption name Threads value 8", state)
    state = UCI.dispatch("setoption name Hash value 4096", state)
    state = UCI.dispatch("setoption name Ponder value false", state)
    assert state.threads == 8
    assert state.hash_mb == 4096
    refute state.ponder
  end

  test "position fen with TCEC-style book exit and g-file en passant", %{state: state} do
    fen = "rnbqkbnr/pppppppp/8/8/6P1/8/PPPPPP1P/RNBQKBNR b KQkq g3 0 1"
    state = UCI.dispatch("position fen #{fen}", state)
    assert Utils.which_piece?(state.board, "g4") == :P
    assert state.board.en_passant == "g3"
  end

  test "position fen with no castling rights", %{state: state} do
    fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1"
    state = UCI.dispatch("position fen #{fen}", state)
    refute "e1g1" in Utils.generate_moves(state.board)
    refute "e1c1" in Utils.generate_moves(state.board)
  end

  test "go depth 1 returns a legal bestmove", %{state: state} do
    state = UCI.dispatch("position startpos", state)
    {output, _} = capture_uci(fn -> UCI.dispatch("go depth 1", state) end)

    assert output =~ "bestmove "
    [_, move] = Regex.run(~r/bestmove (\S+)/, output)
    assert move in Utils.generate_moves(Board.new())
  end

  test "go wtime/btime/winc/binc is accepted and returns bestmove", %{state: state} do
    state = UCI.dispatch("position startpos", state)

    {output, _} =
      capture_uci(fn ->
        UCI.dispatch("go wtime 2000 btime 2000 winc 100 binc 100", state)
      end)

    assert output =~ "bestmove "
    assert output =~ "info depth"
    assert output =~ "score cp"
  end

  test "ucinewgame and unknown commands are tolerated", %{state: state} do
    state = UCI.dispatch("ucinewgame", state)
    state = UCI.dispatch("stop", state)
    state = UCI.dispatch("ponderhit", state)
    assert %State{} = UCI.dispatch("this-is-not-uci", state)
  end

  defp capture_uci(fun) do
    parent = self()

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        send(parent, {:uci_result, fun.()})
      end)

    result =
      receive do
        {:uci_result, r} -> r
      after
        30_000 -> flunk("UCI dispatch did not return")
      end

    {output, result}
  end
end
