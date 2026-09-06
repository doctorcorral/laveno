defmodule Laveno.LegalMovesTest do
  use ExUnit.Case, async: true

  alias Laveno.Board
  alias Laveno.Board.Attacks
  alias Laveno.Board.Utils
  alias Laveno.Fen

  @positions [
    {"startpos", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"},
    {"e4e5", "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"},
    {"kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"},
    {"pin rook", "4k3/8/8/4r3/8/4R3/8/4K3 w - - 0 1"},
    {"pin bishop", "4k3/8/8/b7/8/8/3B4/4K3 w - - 0 1"},
    {"double check", "4k3/8/8/8/8/5n2/8/r3K3 w - - 0 1"},
    {"block check", "4k3/8/8/8/8/4N3/8/4K2r w - - 0 1"},
    {"castle open", "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"},
    {"in check no castle", "r3k2r/8/8/8/8/8/4r3/R3K2R w KQkq - 0 1"},
    {"ep legal", "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1"},
    {"ep rank pin", "8/8/8/K2pP2r/8/8/8/4k3 w - d6 0 1"},
    {"promotion check", "3k4/2P5/8/8/8/8/8/4K3 w - - 0 1"},
    {"discovered", "4k3/8/8/8/8/b7/3N4/4K3 w - - 0 1"}
  ]

  test "pin-aware lists match make-and-test on known positions" do
    Enum.each(@positions, fn {name, fen} ->
      {_s, board} = Fen.load(fen)
      assert_same_moves(board, name)
    end)
  end

  test "pin-aware noisy lists match make-and-test captures" do
    Enum.each(@positions, fn {name, fen} ->
      {_s, board} = Fen.load(fen)
      legal = MapSet.new(Utils.generate_moves_by_make(board))

      expected =
        board
        |> Utils.generate_pseudo_noisy()
        |> Enum.filter(&MapSet.member?(legal, &1))
        |> Enum.sort()

      assert Enum.sort(Utils.generate_noisy(board)) == expected, name
    end)
  end

  test "walked children stay equal to the make-and-test list" do
    Enum.each([
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
    ], fn fen ->
      {_s, board} = Fen.load(fen)
      walk_equal(board, 2)
    end)
  end

  test "pinned rook cannot leave its file" do
    {_s, board} = Fen.load("4k3/8/8/4r3/8/4R3/8/4K3 w - - 0 1")
    moves = Utils.generate_moves(board)
    refute "e3d3" in moves
    refute "e3f3" in moves
    refute "e3a3" in moves
    assert "e3e4" in moves
    assert "e3e5" in moves
  end

  test "double check only allows king moves" do
    {_s, board} = Fen.load("4k3/8/8/8/8/5n2/8/r3K3 w - - 0 1")
    moves = Utils.generate_moves(board)
    assert moves != []
    assert Enum.all?(moves, &String.starts_with?(&1, "e1"))
  end

  test "check must be captured or blocked" do
    {_s, board} = Fen.load("4k3/8/8/8/8/4N3/8/4K2r w - - 0 1")
    moves = Utils.generate_moves(board)
    assert "e3f1" in moves
    refute "e3d5" in moves
    refute "e3c4" in moves
  end

  test "en passant that opens the king is illegal" do
    {_s, board} = Fen.load("8/8/8/K2pP2r/8/8/8/4k3 w - d6 0 1")
    refute "e5d6" in Utils.generate_moves(board)
    assert "e5d6" in Utils.generate_pseudo(board)
  end

  test "castling is omitted while the king is in check" do
    {_s, board} = Fen.load("r3k2r/8/8/8/8/8/4r3/R3K2R w KQkq - 0 1")
    moves = Utils.generate_moves(board)
    refute "e1g1" in moves
    refute "e1c1" in moves
  end

  test "between is empty for knights and adjacent sliders" do
    # e1=59, e8=3, e2=51; knight e1-d3=44
    assert Attacks.between(59, 3) != 0
    assert Attacks.between(59, 51) == 0
    assert Attacks.between(59, 44) == 0
  end

  defp assert_same_moves(board, name) do
    got = Enum.sort(Utils.generate_moves(board))
    expected = Enum.sort(Utils.generate_moves_by_make(board))
    assert got == expected, "#{name}: #{inspect(got)} != #{inspect(expected)}"
  end

  defp walk_equal(_board, 0), do: :ok

  defp walk_equal(board, depth) do
    assert_same_moves(board, "depth #{depth}")

    Enum.each(Utils.generate_moves(board), fn mv ->
      case Board.move(board, mv) do
        %Board{} = child -> walk_equal(child, depth - 1)
        _ -> flunk("legal move rejected by Board.move: #{mv}")
      end
    end)
  end
end
