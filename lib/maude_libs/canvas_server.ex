defmodule MaudeLibs.CanvasServer do
  @moduledoc """
  Global GenServer managing canvas circle metadata.
  No physics - just tracks which circles exist and their properties.
  D3-force on the client handles layout.
  """
  use GenServer
  require Logger

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def add_circle(id, title) do
    GenServer.cast(__MODULE__, {:add_circle, id, title})
  end

  def update_circle(id, attrs) do
    GenServer.cast(__MODULE__, {:update_circle, id, attrs})
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:add_circle, id, title}, state) do
    if Map.has_key?(state, id) do
      {:noreply, state}
    else
      circle = %{title: title, tagline: nil, stage: :lobby}
      Logger.metadata(component: :canvas)
      Logger.info("circle spawned", decision_id: id)
      new_state = Map.put(state, id, circle)
      broadcast(new_state)
      {:noreply, new_state}
    end
  end

  def handle_cast({:update_circle, id, attrs}, state) do
    case Map.fetch(state, id) do
      {:ok, circle} ->
        new_state = Map.put(state, id, Map.merge(circle, attrs))
        broadcast(new_state)
        {:noreply, new_state}

      :error ->
        {:noreply, state}
    end
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(MaudeLibs.PubSub, "canvas", {:canvas_updated, state})
  end
end
