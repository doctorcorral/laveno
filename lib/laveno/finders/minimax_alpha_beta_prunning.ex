defmodule Laveno.Finders.MinimaxABPruning do
  alias Laveno.Board
  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Evaluator

  @infinity_plus 100
  @infinity_minus -100

  def find(board, 0, _alpha, _beta) do
    {Evaluator.eval(board), board}
  end

  def find(board = %{checkmate: true}, _depth, _alpha, _beta), do: Evaluator.eval(board)

  def find(board = %{active_color: <<0::1>>}, depth, init_alpha, init_beta) do
    moves = Utils.generate_moves(board) |> Enum.shuffle()

    {total_eval, local_moves, _alpha, _bheta} =
      Enum.reduce_while(
        moves,
        {@infinity_minus, "", init_alpha, init_beta},
        fn move, {maxeval, _pmove, alpha, beta} ->
          with {eval, moves_path} <- board |> Board.move(move) |> find(depth - 1, alpha, beta),
               local_maxeval <- max(maxeval, eval),
               alpha <- max(alpha, eval) do
            case beta < alpha do
              true -> {:halt, {local_maxeval, moves_path, alpha, beta}}
              false -> {:cont, {local_maxeval, moves_path, alpha, beta}}
            end
          end
        end
      )

    [{"eval_w", evaluation, moves}] = :ets.lookup(:laveno_search, "eval_w")

    if evaluation < total_eval do
      :ets.insert(:laveno_search, {"eval_w", total_eval, local_moves.moves})
    end

    :ets.insert(:laveno_search, {"eval", total_eval, local_moves.moves})
    :ets.update_counter(:laveno_search, :nodes, {2, 1})

    [nodes: nds] = :ets.lookup(:laveno_search, :nodes)

    delta_moves = 2 * board.fullmove_number + board.halfmove_clock

    IO.puts(
      "info multipv 1 depth 2 score cp " <>
        to_string(total_eval * 100) <>
        " time 1 nodes #{to_string(nds)}  hashfull 0 pv " <>
        (Enum.slice(local_moves.moves, delta_moves..-1)
         |> Enum.join(" "))
    )

    IO.puts(
      "info depth 24 currmove " <>
        hd(Enum.slice(local_moves.moves, delta_moves..-1)) <>
        " currmovenumber 0"
    )

    [{"eval", evaluation, board}] = :ets.lookup(:laveno_search, "eval")
    {total_eval, local_moves}
  end

  def find(board = %{active_color: <<1::1>>}, depth, init_alpha, init_beta) do
    moves = Utils.generate_moves(board) |> Enum.shuffle()

    {total_eval, local_moves, _alpha, _bheta} =
      Enum.reduce_while(
        moves,
        {@infinity_plus, "", init_alpha, init_beta},
        fn move, {mineval, _pmove, alpha, beta} ->
          with {eval, moves_path} <- board |> Board.move(move) |> find(depth - 1, alpha, beta),
               local_mineval <- min(mineval, eval),
               beta <- min(beta, eval) do
            case beta < alpha do
              true -> {:halt, {local_mineval, moves_path, alpha, beta}}
              false -> {:cont, {local_mineval, moves_path, alpha, beta}}
            end
          end
        end
      )

    [{"eval_b", evaluation, moves}] = :ets.lookup(:laveno_search, "eval_b")

    if evaluation > total_eval do
      :ets.insert(:laveno_search, {"eval_b", total_eval, local_moves.moves})
    end
    :ets.insert(:laveno_search, {"eval", total_eval, local_moves.moves})
    :ets.update_counter(:laveno_search, :nodes, {2, 1})

    [nodes: nds] = :ets.lookup(:laveno_search, :nodes)

    delta_moves = 2 * board.fullmove_number + board.halfmove_clock

    IO.puts(
      "info multipv 1 depth 2 score cp " <>
        to_string(total_eval * 100) <>
        " time 1 nodes #{to_string(nds)}  hashfull 0 pv " <>
        (Enum.slice(local_moves.moves, delta_moves..-1)
         |> Enum.join(" "))
    )

    #    IO.puts("info depth 24 currmove " <> hd(local_moves.moves) <> " currmovenumber 0")
    IO.puts(
      "info depth 24 currmove " <>
        hd(Enum.slice(local_moves.moves, delta_moves..-1)) <>
        " currmovenumber 0"
    )

    {total_eval, local_moves}
  end
end
