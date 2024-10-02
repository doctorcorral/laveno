defmodule Laveno.Evaluation.Placement do
  @piece_values %{Q: 10, q: 10, P: 1, p: 1, N: 3, n: 3, B: 4, b: 4, R: 5, r: 5}

  @w_pieces [:Q, :R, :N, :B, :P]
  @b_pieces [:q, :r, :n, :b, :p]
  @board_center [26, 27, 28, 29, 34, 35, 36, 37]

  alias Laveno.Board
  alias Laveno.Board.Utils

  def eval(board) do
    eval(board, :w) - eval(board, :b)
  end

  def eval(board, :w), do: centered_piece_contributions(board, @w_pieces)
  def eval(board, :b), do: centered_piece_contributions(board, @b_pieces)

  def centered_piece_contributions(board, pieces) do
    Enum.reduce(pieces, 0, fn piece, val ->
      val +
        Enum.reduce(Utils.where_is(board, piece), 0, fn place, pvs ->
          case place in @board_center do
            true ->
              # Board.Render.print_board(board)
              # IO.inspect(Utils.which_piece?(board, place), label: "centered")
              #              IO.inspect(pvs + @piece_values[piece] / 4.2, label: "pvs")
              pvs + @piece_values[piece] / 3.3

            false ->
              pvs
          end
        end)
    end)
  end
end
