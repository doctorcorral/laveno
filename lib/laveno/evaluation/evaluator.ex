defmodule Laveno.Evaluation.Evaluator do
  alias Laveno.Evaluation.Check
  alias Laveno.Evaluation.Context
  alias Laveno.Evaluation.KingSafety
  alias Laveno.Evaluation.Pawns
  alias Laveno.Evaluation.Threats

  def eval(board) do
    static(board) + Check.eval(board)
  end

  @doc "Material + placement + structure + activity + threats, without the check/mate probe."
  def static(board) do
    ctx = Context.build(board)

    ctx.material + ctx.placement + KingSafety.eval(board, ctx) + ctx.mobility +
      Pawns.eval(board, ctx.phase) + Threats.eval(board, ctx)
  end
end
