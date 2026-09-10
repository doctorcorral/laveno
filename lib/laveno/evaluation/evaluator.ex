defmodule Laveno.Evaluation.Evaluator do
  alias Laveno.Evaluation.Check
  alias Laveno.Evaluation.Features

  def eval(board) do
    static(board) + Check.eval(board)
  end

  @doc "Material + placement + structure + activity + threats, without the check/mate probe."
  def static(board) do
    Features.static(board)
  end
end

