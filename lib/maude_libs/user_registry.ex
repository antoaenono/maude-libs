defmodule MaudeLibs.UserRegistry do
  @moduledoc """
  ETS-backed registry of known usernames.
  Stores usernames seen at join time for lobby autocomplete.
  No cleanup - stale usernames are fine for autocomplete purposes.
  """
  use GenServer

  @table :user_registry

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def register(username) do
    GenServer.cast(__MODULE__, {:register, username})
  end

  def list_usernames do
    :ets.tab2list(@table) |> Enum.map(fn {username, _ts} -> username end)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:register, username}, state) do
    :ets.insert(@table, {username, System.monotonic_time()})
    {:noreply, state}
  end
end
