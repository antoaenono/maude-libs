defmodule MaudeLibsWeb.StageLayout do
  @moduledoc """
  Computes physics-based positions for stage cards.
  Claude is fixed at origin (0,0). Your card and other participants
  are simulated with forces. Your card has a strong downward bias
  and strong horizontal centering to keep it below Claude on the y-axis.
  Internal physics in -50..+50 space, output mapped to virtual pixel coordinates.
  """

  @iterations 50
  @repulsion 5_000.0
  @damping 0.75
  @gap 4.0

  @virtual_w 1000
  @virtual_h 700

  # Claude is fixed at the origin
  @claude_pos {0.0, 0.0}

  # Your card starts below Claude, but is simulated
  @your_initial {0.0, 30.0}
  @your_r 16.0

  def virtual_size, do: {@virtual_w, @virtual_h}
  def claude_pos, do: to_virtual(@claude_pos)

  @doc """
  Returns {your_pos, others_map}.
  your_pos is {x, y} in virtual pixels.
  others_map is %{username => {x, y}} in virtual pixels.
  """
  def compute(other_usernames, stage_context) do
    claude_r = claude_radius(stage_context)
    other_r = 10.0

    others = initial_positions(other_usernames)
    your_node = %{x: elem(@your_initial, 0), y: elem(@your_initial, 1), vx: 0.0, vy: 0.0}

    {final_your, final_others} = relax(your_node, others, claude_r, other_r)

    your_pos = to_virtual({final_your.x, final_your.y})
    others_map = Map.new(final_others, fn {username, node} -> {username, to_virtual({node.x, node.y})} end)

    {your_pos, others_map}
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
      # Spread in an arc above Claude (negative y = above center)
      angle =
        if n == 1 do
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

  defp relax(your_node, others, claude_r, other_r) do
    Enum.reduce(1..@iterations, {your_node, others}, fn _i, {your, acc} ->
      # Update other nodes
      new_others =
        Enum.map(acc, fn {username, node} ->
          {cx, cy} = @claude_pos

          # Repulsion from Claude
          {f1x, f1y} = point_repulsion(node, cx, cy, claude_r + other_r + @gap)
          # Repulsion from your card
          {f2x, f2y} = point_repulsion(node, your.x, your.y, @your_r + other_r + @gap)
          # Repulsion from other nodes
          {f3x, f3y} =
            Enum.reduce(acc, {0.0, 0.0}, fn
              {other_name, other_node}, {fx, fy} when other_name != username ->
                {rx, ry} = point_repulsion(node, other_node.x, other_node.y, other_r * 2 + @gap)
                {fx + rx, fy + ry}

              _, acc_inner ->
                acc_inner
            end)

          # Pull toward horizontal center
          pull_x = (0.0 - node.x) * 0.03

          vx = (node.vx + f1x + f2x + f3x + pull_x) * @damping
          vy = (node.vy + f1y + f2y + f3y) * @damping
          x = clamp(node.x + vx, -42.0, 42.0)
          y = clamp(node.y + vy, -45.0, 22.0)

          {username, %{node | x: x, y: y, vx: vx, vy: vy}}
        end)

      # Update your node
      {cx, cy} = @claude_pos

      # Repulsion from Claude
      {yf1x, yf1y} = point_repulsion(your, cx, cy, claude_r + @your_r + @gap)
      # Repulsion from other nodes
      {yf2x, yf2y} =
        Enum.reduce(new_others, {0.0, 0.0}, fn {_name, other_node}, {fx, fy} ->
          {rx, ry} = point_repulsion(your, other_node.x, other_node.y, @your_r + other_r + @gap)
          {fx + rx, fy + ry}
        end)

      # Strong horizontal centering - keeps your card on the y-axis
      your_pull_x = (0.0 - your.x) * 0.15
      # Gentle downward bias - prefers being below Claude
      your_pull_y = if your.y < 15.0, do: 2.0, else: 0.0

      yvx = (your.vx + yf1x + yf2x + your_pull_x) * @damping
      yvy = (your.vy + yf1y + yf2y + your_pull_y) * @damping
      yx = clamp(your.x + yvx, -20.0, 20.0)
      yy = clamp(your.y + yvy, 10.0, 32.0)

      new_your = %{your | x: yx, y: yy, vx: yvx, vy: yvy}

      {new_your, new_others}
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

  # Map from centered coords (-50..+50) to virtual pixels (0..virtual_w/h)
  defp to_virtual({x, y}) do
    {(x + 50.0) * @virtual_w / 100.0, (y + 50.0) * @virtual_h / 100.0}
  end

  defp clamp(val, min_v, max_v), do: val |> max(min_v) |> min(max_v)
end
