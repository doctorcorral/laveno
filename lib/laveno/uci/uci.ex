defmodule Laveno.UCI do
  alias Laveno.Board
  alias Laveno.Fen
  alias Laveno.Finders.MinimaxABPruning, as: Finder

  @depth 4

  @best_move "a2a4"

  def main(_args) do
    IO.puts("laveno.one by Corral")
    loop(Board.new())
  end

  def loop(board) do
    command = IO.gets("")

    new_board =
      case command do
        "\n" ->
          board

        "uci" <> _ ->
          handle(:uci, board)

        "isready" <> _ ->
          handle(:isready, board)

        "help" <> _ ->
          handle(:help, board)

        "go" <> _ ->
          handle(:go, board)

        "stop" <> _ ->
          handle(:stop, board)

        "position startpos" <> _ ->
          handle(:startpos, board)

        "position fen " <> <<fenstring::56*8>> <> " moves " <> moves ->
          handle(:fen, :binary.encode_unsigned(fenstring), String.trim(moves), board)

        "position fen " <> fenstring ->
          handle(:fen, fenstring, board)

        _ ->
          # IO.puts("unknown option")
          board
      end

    loop(new_board)
  end

  def handle(:uci, board) do
    IO.puts("id name laveno.one 0.1.1")
    IO.puts("id author Corral-Corral, Ricardo")
    IO.puts("uciok")
    board
  end

  def handle(:isready, board) do
    IO.puts("readyok")
    board
  end

  def handle(:startpos, _board) do
    board = Board.new()
    Board.Render.print_board(board)
    board
  end

  def handle(:go, board) do
    {eval, eval_board} = Finder.find(board, @depth, -90, 90)
    delta_moves = 2 * board.fullmove_number + board.halfmove_clock
    IO.puts("bestmove " <> hd(Enum.slice(eval_board.moves, delta_moves..-1)))

    board
  end

  def handle(:go, board, custom_depth) do
    {eval, eval_board} = Finder.find(board, custom_depth, -90, 90)
    delta_moves = 2 * board.fullmove_number + board.halfmove_clock
    IO.puts("bestmove " <> hd(Enum.slice(eval_board.moves, delta_moves..-1)))

    board
  end

  def handle(:stop, board) do
    [{_eval, evaluation, moves}] =
      case board.active_color do
        <<0::1>> -> :ets.lookup(:laveno_search, "eval_w")
        <<1::1>> -> :ets.lookup(:laveno_search, "eval_b")
      end
    IO.inspect(moves, label: "MOVES")
    delta_moves = 2 * board.fullmove_number + board.halfmove_clock
    move = hd(Enum.slice(moves, delta_moves..-1))
    IO.puts("bestmove " <> move)
    board
  end

  def handle(:fen, fenstring, moves, _board) do
    {_fenstate, board} = Fen.load(fenstring)

    board_with_moves =
      Enum.reduce(String.split(moves, " "), board, fn move, bacc ->
        bacc
        |> Board.move(move)
      end)

    Board.Render.print_board(board_with_moves)
    board_with_moves
  end

  def handle(:fen, fenstring, _board) do
    {_fenstate, board} = Fen.load(fenstring)
    Board.Render.print_board(board)
    board
  end

  def handle(:help, board) do
    IO.puts("""
    laveno.one (laveno) is a chess engine written in Elixir.
    laveno can be used with a graphical user interface (GUI)
    through the Universal Chess Interface (UCI) protocol.
    Visit http://laveno.one
    """)

    board
  end
end
