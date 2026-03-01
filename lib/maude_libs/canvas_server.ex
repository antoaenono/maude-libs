defmodule MaudeLibs.CanvasServer do
  @moduledoc """
  Global GenServer managing canvas circle positions.
  Runs a simple force simulation: repulsion between circles + weak center pull.
  Broadcasts updated positions every tick via PubSub.
  """
  use GenServer
  require Logger

  @tick_ms 1500
  @ideal_dist 20.0
  @damping 0.85
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
    k = @ideal_dist

    # Compute forces for each circle
    Enum.reduce(ids, circles, fn id, acc ->
      circle = acc[id]

      # Repulsion from every other circle: force = k^2 / dist, directed away
      {rx, ry} =
        Enum.reduce(ids, {0.0, 0.0}, fn other_id, {fx, fy} ->
          if other_id == id do
            {fx, fy}
          else
            other = acc[other_id]
            dx = circle.x - other.x
            dy = circle.y - other.y
            dist = max(:math.sqrt(dx * dx + dy * dy), 1.0)
            force = k * k / dist
            {fx + force * dx / dist, fy + force * dy / dist}
          end
        end)

      # Repulsion from the + button at center (phantom node)
      cdx = circle.x - @width / 2
      cdy = circle.y - @height / 2
      cdist = max(:math.sqrt(cdx * cdx + cdy * cdy), 1.0)
      cforce = k * k / cdist
      {prx, pry} = {cforce * cdx / cdist, cforce * cdy / cdist}

      # Attraction toward center: force = dist^2 / k, directed inward
      adist = cdist
      aforce = adist * adist / (k * 4.0)
      {ax, ay} = {-aforce * cdx / cdist, -aforce * cdy / cdist}

      # Sum forces
      fx = rx + prx + ax
      fy = ry + pry + ay

      # Apply with velocity and damping, cap displacement
      vx = (circle.vx + fx) * @damping
      vy = (circle.vy + fy) * @damping
      speed = max(:math.sqrt(vx * vx + vy * vy), 0.001)
      max_step = k * 0.5
      {vx, vy} = if speed > max_step, do: {vx * max_step / speed, vy * max_step / speed}, else: {vx, vy}

      x = clamp(circle.x + vx, 8.0, 92.0)
      y = clamp(circle.y + vy, 8.0, 92.0)

      Map.put(acc, id, %{circle | x: x, y: y, vx: vx, vy: vy})
    end)
  end

  defp clamp(val, min, max) do
    val |> max(min) |> min(max)
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_ms)
  end
end
