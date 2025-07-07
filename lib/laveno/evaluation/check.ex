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
    legal_moves = Utils.generate_moves(board)

    cond do
      legal_moves == [] and Utils.in_check?(board) ->
        # side to move is in checkmate
        if board.active_color == <<0::1>>, do: -@checkmate_bonus, else: @checkmate_bonus

      Utils.in_check?(board) ->
        # side to move is in check
        if board.active_color == <<0::1>>, do: -@check_bonus, else: @check_bonus

      true ->
        0
    end
  end
end
