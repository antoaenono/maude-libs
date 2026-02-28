defmodule MaudeLibs.Decision.Supervisor do
  @moduledoc """
  Supervises Decision.Server processes via DynamicSupervisor.
  Each decision gets its own server process registered under its ID.
  """
  use DynamicSupervisor

  alias MaudeLibs.Decision.Server

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_decision(id, creator, topic) do
    spec = {Server, id: id, creator: creator, topic: topic}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_decision(id) do
    case Server.whereis(id) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
end
