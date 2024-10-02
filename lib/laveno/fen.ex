defmodule Laveno.Fen do
  alias Laveno.Board

  @column_list ["a", "b", "c", "d", "e", "f"]
  @rank_list ["1", "2", "3", "4", "5", "6", "7", "8"]

  def new_state() do
    %{
      step: 1,
      rank: 8,
      column: 1,
      square: "a8",
      active_color: "w",
      castlig: %{
        "K" => true,
        "Q" => true,
        "k" => true,
        "q" => true
      },
      en_passant_target_square: "-",
      col_passant: "",
      rank_passant: "",
      fullmove_number: 1,
      halfmove_clock: 0
    }
  end

  def load(fen_string) do
    fen_string
    |> String.graphemes()
    |> Enum.reduce(
      {new_state(), Board.new(:empty)},
      fn symbol, {fen_state, board} ->
        apply_symbol(symbol, {fen_state, board})
      end
    )
  end

  def apply_symbol(" ", {%{step: 1} = fen_state, board}) do
    {%{fen_state | step: 2}, board}
  end

  def apply_symbol(active_color, {%{step: 2} = fen_state, board})
      when active_color in ["w", "b"] do
    #    IO.inspect(active_color, label: "SETTING ACTIVE COLOR")

    {
      %{fen_state | step: 3, active_color: active_color},
      board |> Board.set_active_color(active_color)
    }
  end

  def apply_symbol(castle_letter, {%{step: step} = fen_state, board})
      when castle_letter in ["K", "Q", "k", "q"] and step in [3, 4] do
    #    IO.inspect(castle_letter, label: "SETTING A CASTLE")
    {%{fen_state | step: 4}, board |> Board.set_castle(castle_letter)}
  end

  def apply_symbol("-", {%{step: 4} = fen_state, board}) do
    #   IO.inspect("-", label: "NO EN PASSANT")
    {%{fen_state | step: 5}, board}
  end

  def apply_symbol(col_passant, {%{step: 4} = fen_state, board})
      when col_passant in @column_list do
    #  IO.inspect(col_passant, label: "COL PASSANT")
    {%{fen_state | col_passant: col_passant}, board}
  end

  def apply_symbol(rank_passant, {%{step: 4} = fen_state, board})
      when rank_passant in @rank_list do
    # IO.inspect(rank_passant, label: "RANK PASSANT")
    {%{fen_state | rank_passant: rank_passant, step: 5}, board}
  end

  def apply_symbol(" ", {%{step: 5} = fen_state, board}) do
    {fen_state, board}
  end

  def apply_symbol(halfmove_clock, {%{step: 5} = fen_state, board}) do
    #    IO.inspect(halfmove_clock, label: "HALFMOVE CLOCK")
    {%{fen_state | step: 6, halfmove_clock: halfmove_clock}, board}
  end

  def apply_symbol(" ", {%{step: 6} = fen_state, board}) do
    {fen_state, board}
  end

  def apply_symbol(fullmove_number, {%{step: 6} = fen_state, board}) do
    #   IO.inspect(fullmove_number, label: "FULLMOVE NUMBER")
    {%{fen_state | step: 7, fullmove_number: fullmove_number}, board}
  end

  def apply_symbol("/", {%{rank: rank} = fen_state, board}) do
    {%{fen_state | rank: rank - 1}, board}
  end

  def apply_symbol(symbol, {
        %{step: 1, square: square} = fen_state,
        board
      })
      when symbol in @rank_list do
    new_fen_state =
      Enum.reduce(
        1..String.to_integer(symbol),
        fen_state,
        fn _, fen_acc ->
          fen_acc |> next_square()
        end
      )

    {new_fen_state, board}
  end

  def apply_symbol(symbol, {
        %{step: 1, square: square} = fen_state,
        board
      }) do
    #  IO.inspect({symbol, square}, label: "PLACING PIECE")

    with updated_board <-
           board
           |> Board.place_piece(String.to_atom(symbol), square),
         updated_fen_state <-
           fen_state
           |> next_square() do
      {updated_fen_state, updated_board}
    end
  end

  def apply_symbol(symbol, states) do
    #    IO.inspect(symbol, label: "APPLYING")
    states
  end

  def next_square(%{square: <<c::size(8), r::size(8)>>} = fen_state) do
    case c do
      104 -> %{fen_state | square: <<97::8, r - 1::8>>}
      col -> %{fen_state | square: <<col + 1::8, r::8>>}
    end
  end
end
