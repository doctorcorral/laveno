defmodule Laveno.Board.Render do
  alias Laveno.Board
  alias Laveno.Board.Utils

  def print_rank(pieces, rank_num, theme, wrap \\ " ") do
    offset = rem(rank_num, 2)

    Enum.zip([(1 + offset)..(8 + offset), pieces])
    |> Enum.map(fn {n, piece} ->
      case rem(n, 2) do
        0 ->
          IO.ANSI.format_fragment(
            [theme.b, wrap <> piece <> wrap],
            true
          ) ++ IO.ANSI.reset()

        _ ->
          IO.ANSI.format_fragment(
            [theme.w, wrap <> piece <> wrap],
            true
          ) ++ IO.ANSI.reset()
      end
    end)
  end

  def print_board() do
    Board.new()
    |> print_board
  end

  def print_board(board, theme \\ :red) do
    Enum.each(8..1, fn row_number ->
      Utils.board_to_unicode_row(board, row_number)
      |> print_rank(row_number, board_color(theme))
      |> IO.puts()
    end)
  end

  def board_color(:bw) do
    %{b: :black_background, w: :light_black_background}
  end

  def board_color(:yellow) do
    %{b: :yellow_background, w: :light_yellow_background}
  end

  def board_color(:blue) do
    %{b: [:blue_background, :black], w: [:light_blue_background, :black]}
  end

  def board_color(:green) do
    %{b: [:green_background, :black], w: [:light_green_background, :black]}
  end

  def board_color(:red) do
    %{b: [:red_background, :black], w: [:light_red_background, :black]}
  end
end
