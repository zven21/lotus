defmodule Lotus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LotusWeb.Telemetry,
      Lotus.Repo,
      {DNSCluster, query: Application.get_env(:lotus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Lotus.PubSub},
      # Ensure CMS placeholders at boot (domain, GraphQL aggregator, resolver)
      Lotus.CMS.PublisherServer,
      # Config Monitor for hot reload
      # Lotus.CMS.ConfigMonitor,
      # Start a worker by calling: Lotus.Worker.start_link(arg)
      # {Lotus.Worker, arg},
      # Start to serve requests, typically the last entry
      LotusWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lotus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LotusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
