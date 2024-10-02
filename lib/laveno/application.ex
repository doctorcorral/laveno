defmodule Laveno.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Laveno.Worker.start_link(arg)
      # {Laveno.Worker, arg}
    ]

    :ets.new(:laveno_search, [:set, :public, :named_table])
    :ets.insert(:laveno_search, {:nodes, 0})
    :ets.insert(:laveno_search, {"eval_w", 0, []})
    :ets.insert(:laveno_search, {"eval_b", 0, []})
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Laveno.Supervisor]
    Supervisor.start_link(children, opts)
    # Laveno.UCI.main([])
  end
end
