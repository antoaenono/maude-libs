defmodule MaudeLibs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MaudeLibsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:maude_libs, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MaudeLibs.PubSub},
      {Registry, keys: :unique, name: MaudeLibs.Decision.Registry},
      MaudeLibs.Decision.Supervisor,
      MaudeLibs.UserRegistry,
      MaudeLibsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MaudeLibs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MaudeLibsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
