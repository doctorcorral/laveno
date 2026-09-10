defmodule Mix.Tasks.Laveno.Texel do
  @shortdoc "Fit eval feature weights to quiet positions with WDL labels"

  @moduledoc """
  Reads `priv/texel.jsonl` lines `{fen, result}` (result is white's score:
  1.0 / 0.5 / 0.0), skips checks, and coordinate-descends the feature
  coefficients so the sigmoid of `Features.static` matches the results.
  Starts from `Weights.current/0` and stays within a band of `Weights.default/0`.
  """

  use Mix.Task

  alias Laveno.Board.Utils
  alias Laveno.Evaluation.Features
  alias Laveno.Evaluation.Weights
  alias Laveno.Fen

  @path "priv/texel.jsonl"
  @k_lo 0.2
  @k_hi 3.0
  @clamp_lo 0.35
  @clamp_hi 2.4

  def run(args) do
    Mix.Task.run("app.start")
    path = List.first(args) || @path
    samples = load_samples(path)
    IO.puts("loaded #{length(samples)} quiet positions from #{path}")

    weights = Weights.current()
    k = fit_k(samples, weights)
    IO.puts("K=#{Float.round(k, 4)}  err=#{Float.round(mse(samples, weights, k), 6)}")

    {fitted, k} = descend(samples, weights, k)
    IO.puts("\nfitted weights (K=#{Float.round(k, 4)}):")

    Enum.each(Enum.sort(Weights.keys()), fn key ->
      before = Map.fetch!(weights, key)
      now = Map.fetch!(fitted, key)

      if now != before do
        IO.puts("  #{key}: #{fmt(before)} -> #{fmt(now)}")
      end
    end)

    IO.puts("err=#{Float.round(mse(samples, fitted, k), 6)}")
    write_snippet(fitted)
  end

  defp fmt(v), do: Float.round(v * 1.0, 4)

  defp parse_line(line) do
    fen =
      case Regex.run(~r/"fen"\s*:\s*"([^"]+)"/, line) do
        [_, fen] -> fen
        _ -> raise "missing fen in #{line}"
      end

    result =
      case Regex.run(~r/"result"\s*:\s*([0-9.]+)/, line) do
        [_, r] -> String.to_float(float_literal(r))
        _ -> raise "missing result in #{line}"
      end

    {fen, result}
  end

  defp float_literal(r) do
    if String.contains?(r, "."), do: r, else: r <> ".0"
  end

  defp load_samples(path) do
    path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&parse_line/1)
    |> Stream.map(fn {fen, result} ->
      {_s, board} = Fen.load(fen)
      {board, result}
    end)
    |> Stream.reject(fn {board, _} -> Utils.in_check?(board) end)
    |> Stream.map(fn {board, result} ->
      {Features.extract(board), result}
    end)
    |> Enum.to_list()
  end

  defp sigmoid(eval, k) do
    1.0 / (1.0 + :math.pow(10.0, -k * eval / 400.0))
  end

  defp mse(samples, weights, k) do
    n = max(length(samples), 1)

    err =
      Enum.reduce(samples, 0.0, fn {features, result}, acc ->
        p = sigmoid(Features.dot(features, weights), k)
        d = result - p
        acc + d * d
      end)

    err / n
  end

  defp fit_k(samples, weights) do
    Enum.reduce(1..24, {@k_lo, @k_hi}, fn _, {lo, hi} ->
      a = lo + (hi - lo) / 3
      b = hi - (hi - lo) / 3
      if mse(samples, weights, a) < mse(samples, weights, b), do: {lo, b}, else: {a, hi}
    end)
    |> then(fn {lo, hi} -> (lo + hi) / 2 end)
  end

  defp descend(samples, weights, k) do
    Enum.reduce(1..24, {weights, k}, fn round, {w, k} ->
      w =
        Enum.reduce(Weights.keys(), w, fn key, w ->
          step(samples, w, k, key)
        end)

      k = fit_k(samples, w)

      if rem(round, 6) == 0 do
        IO.puts("round #{round}  err=#{Float.round(mse(samples, w, k), 6)}")
      end

      {w, k}
    end)
  end

  defp step(samples, weights, k, key) do
    base = mse(samples, weights, k)
    cur = Map.fetch!(weights, key)
    raw = Map.fetch!(Weights.default(), key)
    step0 = max(abs(raw) * 0.08, 0.02)

    Enum.reduce([1.0, 0.5, 0.25], weights, fn frac, w ->
      delta = step0 * frac
      up = put_clamped(w, key, cur + delta)
      down = put_clamped(w, key, cur - delta)
      eu = mse(samples, up, k)
      ed = mse(samples, down, k)

      cond do
        eu + 1.0e-8 < base and eu <= ed -> up
        ed + 1.0e-8 < base -> down
        true -> w
      end
    end)
  end

  defp put_clamped(weights, key, value) do
    raw = Map.fetch!(Weights.default(), key)
    lo = min(raw * @clamp_lo, raw * @clamp_hi)
    hi = max(raw * @clamp_lo, raw * @clamp_hi)
    Map.put(weights, key, min(hi, max(lo, value)))
  end

  defp write_snippet(weights) do
    body =
      weights
      |> Enum.sort_by(fn {k, _} -> Atom.to_string(k) end)
      |> Enum.map(fn {k, v} -> "    #{k}: #{Float.round(v * 1.0, 4)}" end)
      |> Enum.join(",\n")

    File.write!("priv/texel_weights.exs", "%{\n#{body}\n}\n")
    IO.puts("wrote priv/texel_weights.exs")
  end
end
