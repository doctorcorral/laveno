defmodule Laveno.Evaluation.Evaluator do
  alias Laveno.Evaluation.Check
  alias Laveno.Evaluation.KingSafety
  alias Laveno.Evaluation.Material
  alias Laveno.Evaluation.Placement

  def eval(board) do
    static(board) + Check.eval(board)
  end

  @doc "Material + placement + king safety, without the check/mate probe."
  def static(board) do
    Material.eval(board) + Placement.eval(board) + KingSafety.eval(board)
  end
end
