defmodule Laveno.Evaluation.Evaluator do
  alias Laveno.Evaluation.Material
  alias Laveno.Evaluation.Placement

  def eval(board) do
    evaluators = [
      &Material.eval/1,
      &Placement.eval/1
    ]

    Enum.reduce(evaluators, 0, fn evaluator, acc_eval ->
      acc_eval + evaluator.(board)
    end)
  end
end
