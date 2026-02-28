defmodule MaudeLibsWeb.StageLayout do
  @moduledoc """
  Computes physics-based positions for stage cards.
  Claude at center, your card at bottom, others float deterministically.
  All coordinates in 0-100 percentage space.
  """

  @iterations 50
  @repulsion 5_000.0
  @damping 0.75
  @gap 4.0

  @claude_pos {50.0, 45.0}
  @your_pos {50.0, 88.0}

  def claude_pos, do: @claude_pos
  def your_pos, do: @your_pos

  @doc """
  Returns a map of positions for other participants.
  Keys are usernames, values are {x, y} tuples.
  Claude and your card are fixed - not returned here.
  """
  def compute(other_usernames, stage_context) do
    claude_r = claude_radius(stage_context)
    your_r = 16.0
    other_r = 10.0

    nodes = initial_positions(other_usernames)
    final = relax(nodes, claude_r, your_r, other_r)
    Map.new(final, fn {username, node} -> {username, {node.x, node.y}} end)
  end

  defp claude_radius(%{has_content: true, suggestion_count: n}) when n > 0, do: 12.0 + n * 3.0
  defp claude_radius(%{has_content: true}), do: 12.0
  defp claude_radius(%{is_thinking: true}), do: 10.0
  defp claude_radius(_), do: 5.0

  defp initial_positions(usernames) do
    n = length(usernames)
    sorted = Enum.sort(usernames)

    sorted
    |> Enum.with_index()
    |> Enum.map(fn {username, i} ->
      # Spread in upper arc
      angle = if n == 1 do
        :math.pi() * 0.5
      else
        :math.pi() * (0.2 + 0.6 * i / (n - 1))
      end

      r = 22.0 + rem(:erlang.phash2(username, 1000), 8) * 1.0
      {cx, cy} = @claude_pos
      x = cx + :math.cos(angle) * r
      y = cy - :math.sin(angle) * r
      {username, %{x: x, y: y, vx: 0.0, vy: 0.0}}
    end)
  end

  defp relax(nodes, claude_r, your_r, other_r) do
    Enum.reduce(1..@iterations, nodes, fn _i, acc ->
      Enum.map(acc, fn {username, node} ->
        {cx, cy} = @claude_pos
        {yx, yy} = @your_pos

        # Repulsion from Claude
        {f1x, f1y} = point_repulsion(node, cx, cy, claude_r + other_r + @gap)
        # Repulsion from your card
        {f2x, f2y} = point_repulsion(node, yx, yy, your_r + other_r + @gap)
        # Repulsion from other nodes
        {f3x, f3y} = Enum.reduce(acc, {0.0, 0.0}, fn
          {other_name, other_node}, {fx, fy} when other_name != username ->
            {rx, ry} = point_repulsion(node, other_node.x, other_node.y, other_r * 2 + @gap)
            {fx + rx, fy + ry}
          _, acc_inner -> acc_inner
        end)

        # Gentle pull toward center-ish area
        {pull_x, pull_y} = {(50.0 - node.x) * 0.015, (40.0 - node.y) * 0.01}

        vx = (node.vx + f1x + f2x + f3x + pull_x) * @damping
        vy = (node.vy + f1y + f2y + f3y + pull_y) * @damping
        x = clamp(node.x + vx, 8.0, 92.0)
        y = clamp(node.y + vy, 5.0, 72.0)

        {username, %{node | x: x, y: y, vx: vx, vy: vy}}
      end)
    end)
  end

  defp point_repulsion(node, ox, oy, min_dist) do
    dx = node.x - ox
    dy = node.y - oy
    dist = max(:math.sqrt(dx * dx + dy * dy), min_dist * 0.3)

    if dist < min_dist * 2.5 do
      force = @repulsion / (dist * dist)
      {force * dx / dist, force * dy / dist}
    else
      {0.0, 0.0}
    end
  end

  defp clamp(val, min_v, max_v), do: val |> max(min_v) |> min(max_v)
end
