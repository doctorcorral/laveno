defmodule Laveno.Finders.Minimax do
  alias Laveno.Board
  alias Laveno.Board.Utils
  alias Laveno.Evaluation
  alias Laveno.Evaluation.Evaluator

  @infinity_plus 1_000
  @infinity_minus -1_000

  def find(board, 0), do: Evaluator.eval(board)

  def find(board = %{active_color: <<0::1>>}, depth) do
    moves = Utils.generate_moves(board)

    evals =
      Enum.map(moves, fn move ->
        board
        |> Board.move(move)
        |> find(depth - 1)
      end)

    Enum.reduce(
      evals,
      @infinity_minus,
      fn eval, maxeval -> max(maxeval, eval) end
    )
  end

  def find(board = %{active_color: <<1::1>>}, depth) do
    moves = Utils.generate_moves(board)

    evals =
      Enum.map(moves, fn move ->
        board
        |> Board.move(move)
        |> find(depth - 1)
      end)

    Enum.reduce(
      evals,
      @infinity_plus,
      fn eval, maxeval -> min(maxeval, eval) end
    )
  end

  @spec find(Board.t(), integer(), any(), any()) :: {integer(), Board.t()}
  def find(board, depth, _alpha, _beta) do
    # Base case: depth 0 or terminal position -> composite eval
    if depth == 0 or Utils.generate_moves(board) == [] do
      {Evaluator.eval(board), board}
    else
      moves = Utils.generate_moves(board)
      # Evaluate each candidate move
      results =
        Enum.reduce(moves, [], fn move, acc ->
          case Board.move(board, move) do
            %Board{} = b ->
              # recurse for deeper eval
              eval = find(b, depth - 1)
              [{eval, move} | acc]
            _ -> acc
          end
        end)
      # Determine best move based on active color
      {best_eval, best_move} =
        case board.active_color do
          <<0::1>> -> Enum.max_by(results, fn {e, _m} -> e end)
          <<1::1>> -> Enum.min_by(results, fn {e, _m} -> e end)
        end
      # Apply best move
      new_board =
        case Board.move(board, best_move) do
          %Board{} = b -> b
          _ -> board
        end
      {best_eval, new_board}
    end
  end
end
