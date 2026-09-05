defmodule Laveno.Evaluation.Evaluator do
  alias Laveno.Evaluation.Check
  alias Laveno.Evaluation.KingSafety
  alias Laveno.Evaluation.Material
  alias Laveno.Evaluation.Mobility
  alias Laveno.Evaluation.Pawns
  alias Laveno.Evaluation.Placement
  alias Laveno.Evaluation.Threats

  def eval(board) do
    static(board) + Check.eval(board)
  end

  @doc "Material + placement + structure + activity + threats, without the check/mate probe."
  def static(board) do
    Material.eval(board) + Placement.eval(board) + KingSafety.eval(board) +
      Mobility.eval(board) + Pawns.eval(board) + Threats.eval(board)
  end
end
