defmodule Laveno.Evaluation.Check do
  @moduledoc """
  Check evaluator: adds a bonus for delivering check and a larger bonus for checkmate.
  """
  alias Laveno.Board.Utils

  @check_bonus 1
  @checkmate_bonus 10_000

  @doc """
  Returns a bonus for check or checkmate:
  - positive for white if black is in check or checkmated,
  - negative for white if white is in check or checkmated,
  - zero otherwise.
  """
  def eval(board) do
    # generate_moves is expensive; only expand when the king is already in check
    if Utils.in_check?(board) do
      if Utils.generate_moves(board) == [] do
        if board.active_color == <<0::1>>, do: -@checkmate_bonus, else: @checkmate_bonus
      else
        if board.active_color == <<0::1>>, do: -@check_bonus, else: @check_bonus
      end
    else
      0
    end
  end
end
