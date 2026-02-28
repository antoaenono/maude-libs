defmodule MaudeLibs.CanvasServer do
  @moduledoc """
  Global GenServer managing canvas circle positions.
  Runs a simple force simulation: repulsion between circles + weak center pull.
  Broadcasts updated positions every tick via PubSub.
  """
  use GenServer
  require Logger

  @tick_ms 1500
  @repulsion 8_000.0
  @center_pull 0.03
  @damping 0.85
  @min_dist 80.0
  # Canvas bounds (logical units, mapped to % in CSS)
  @width 100.0
  @height 100.0

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
    schedule_tick()
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
      # Spawn offset from center so it doesn't sit on the + button
      angle = :rand.uniform() * 2 * :math.pi()
      radius = 15.0 + :rand.uniform() * 10.0
      x = @width / 2 + :math.cos(angle) * radius
      y = @height / 2 + :math.sin(angle) * radius
      vx = :math.cos(angle) * 2.0
      vy = :math.sin(angle) * 2.0
      circle = %{x: x, y: y, vx: vx, vy: vy, title: title, tagline: nil, stage: :lobby}
      Logger.metadata(component: :canvas)
      Logger.info("circle spawned", decision_id: id)
      {:noreply, Map.put(state, id, circle)}
    end
  end

  def handle_cast({:update_circle, id, attrs}, state) do
    case Map.fetch(state, id) do
      {:ok, circle} ->
        {:noreply, Map.put(state, id, Map.merge(circle, attrs))}
      :error ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    schedule_tick()

    if map_size(state) == 0 do
      {:noreply, state}
    else
      new_state = simulate(state)
      Logger.metadata(component: :canvas)
      Logger.debug("tick", circle_count: map_size(new_state))
      Phoenix.PubSub.broadcast(MaudeLibs.PubSub, "canvas", {:canvas_updated, new_state})
      {:noreply, new_state}
    end
  end

  # ---------------------------------------------------------------------------
  # Physics
  # ---------------------------------------------------------------------------

  defp simulate(circles) do
    ids = Map.keys(circles)

    Enum.reduce(ids, circles, fn id, acc ->
      circle = acc[id]
      {fx, fy} = repulsion_force(id, circle, acc, ids)
      {cx, cy} = center_force(circle)

      ax = fx + cx
      ay = fy + cy

      vx = (circle.vx + ax) * @damping
      vy = (circle.vy + ay) * @damping

      x = clamp(circle.x + vx, 5.0, 95.0)
      y = clamp(circle.y + vy, 5.0, 95.0)

      Map.put(acc, id, %{circle | x: x, y: y, vx: vx, vy: vy})
    end)
  end

  defp repulsion_force(id, circle, circles, ids) do
    # Phantom repulsion from the fixed + button at canvas center
    {fx0, fy0} = point_repulsion(circle, @width / 2, @height / 2)

    Enum.reduce(ids, {fx0, fy0}, fn other_id, {fx, fy} ->
      if other_id == id do
        {fx, fy}
      else
        other = circles[other_id]
        {rx, ry} = point_repulsion(circle, other.x, other.y)
        {fx + rx, fy + ry}
      end
    end)
  end

  defp point_repulsion(circle, ox, oy) do
    dx = circle.x - ox
    dy = circle.y - oy
    dist = max(:math.sqrt(dx * dx + dy * dy), @min_dist)
    force = @repulsion / (dist * dist)
    {force * dx / dist, force * dy / dist}
  end

  defp center_force(circle) do
    cx = (@width / 2 - circle.x) * @center_pull
    cy = (@height / 2 - circle.y) * @center_pull
    {cx, cy}
  end

  defp clamp(val, min, max) do
    val |> max(min) |> min(max)
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_ms)
  end
end
