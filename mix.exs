defmodule Laveno.MixProject do
  use Mix.Project

  def project do
    [
      app: :laveno,
      version: "0.2.1",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "l a v e n o  ♜",
      homepage_url: "https://laveno.one",
      docs: [main: "l a v e n o ♟"],
      escript: escript(),
      releases: releases()
    ]
  end

  defp escript do
    [main_module: Laveno.UCI]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Laveno.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:burrito, "~> 1.0"}
    ]
  end

  def releases do
    [
      laveno_uci_app: [
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            macos: [os: :darwin, cpu: :x86_64],
            linux: [os: :linux, cpu: :x86_64],
            windows: [os: :windows, cpu: :x86_64]
          ]
        ]
      ]
    ]
  end
end
