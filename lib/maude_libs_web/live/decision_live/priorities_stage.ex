defmodule MaudeLibsWeb.DecisionLive.PrioritiesStage do
  use Phoenix.Component
  import MaudeLibsWeb.DecisionLive.DecisionComponents, only: [claude_thinking: 1, mini_dots: 1, modal_overlay: 1]

  alias MaudeLibsWeb.StageLayout

  def priorities_stage(assigns) do
    s = assigns.decision.stage
    my_priority = Map.get(s.priorities, assigns.username)
    my_direction = if my_priority, do: my_priority.direction, else: "+"
    my_text = if my_priority, do: my_priority.text, else: ""
    is_confirmed = assigns.username in s.confirmed
    is_ready = assigns.username in s.ready

    all_confirmed =
      MapSet.subset?(assigns.decision.connected, s.confirmed) and
        MapSet.size(assigns.decision.connected) > 0

    waiting_count = MapSet.size(assigns.decision.connected) - MapSet.size(s.confirmed)

    other_users =
      MapSet.to_list(assigns.decision.connected) |> Enum.reject(&(&1 == assigns.username))

    stage_context = %{
      has_content: all_confirmed and length(s.suggestions) > 0,
      is_thinking: s.suggesting,
      suggestion_count: length(s.suggestions)
    }

    positions = StageLayout.compute(other_users, stage_context)
    {claude_x, claude_y} = StageLayout.claude_pos()
    {your_x, your_y} = StageLayout.your_pos()

    assigns =
      assign(assigns,
        s: s,
        my_priority: my_priority,
        my_direction: my_direction,
        my_text: my_text,
        is_confirmed: is_confirmed,
        is_ready: is_ready,
        all_confirmed: all_confirmed,
        waiting_count: waiting_count,
        other_users: other_users,
        positions: positions,
        claude_x: claude_x,
        claude_y: claude_y,
        your_x: your_x,
        your_y: your_y
      )

    ~H"""
    <div class="w-screen h-screen overflow-hidden flex flex-col select-none">
      <%!-- Header --%>
      <div class="shrink-0 bg-base-100/80 backdrop-blur border-b border-base-300 px-8 py-4 flex flex-col items-center gap-1">
        <span class="text-xs font-mono text-base-content/40 uppercase tracking-widest">
          Name your priorities
        </span> <span class="text-lg font-semibold text-base-content">{@decision.topic}</span>
        <span class="text-xs text-base-content/40">
          Name a dimension, not a directional statement - e.g. "cost" not "too expensive"
        </span>
      </div>
       <%!-- Canvas area --%>
      <div class="flex-1 relative overflow-hidden">
        <%!-- Other participants' priority cards --%>
        <%= for user <- @other_users do %>
          <% {x, y} = Map.get(@positions, user, {50.0, 30.0}) %> <% p = Map.get(@s.priorities, user) %>
          <div
            class="absolute transition-all duration-700 ease-in-out"
            style={"left: #{x}%; top: #{y}%; transform: translate(-50%, -50%);"}
          >
            <div class={"card w-52 border-2 bg-base-100 shadow-md " <> if(user in @s.confirmed, do: "border-success", else: "border-base-300")}>
              <div class="card-body p-4 gap-2">
                <div class="flex items-center justify-between">
                  <span class="badge badge-ghost badge-sm">{user}</span>
                  <%= if user in @s.confirmed do %>
                    <span class="text-xs text-success">confirmed ✓</span>
                  <% end %>
                </div>

                <%= if p do %>
                  <div class="flex items-center gap-2">
                    <span class={direction_color(p.direction) <> " font-mono font-bold text-xl"}>
                      {p.direction}
                    </span> <span class="text-sm">{p.text}</span>
                  </div>
                <% else %>
                  <p class="text-xs text-base-content/30 italic">thinking...</p>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Claude suggestions (always at center, invisible when empty) --%> <% has_claude_content =
          (@all_confirmed and length(@s.suggestions) > 0) or @s.suggesting %>
        <div
          class={"absolute z-20 transition-all duration-700 ease-in-out " <> if(has_claude_content, do: "opacity-100", else: "opacity-0 pointer-events-none")}
          style={"left: #{@claude_x}%; top: #{@claude_y}%; transform: translate(-50%, -50%);"}
        >
          <%= if @all_confirmed and length(@s.suggestions) > 0 do %>
            <div class="card w-72 border-2 border-dashed border-secondary bg-base-100 shadow-lg">
              <div class="card-body p-4 gap-3">
                <div class="flex items-center gap-1.5">
                  <span class="badge badge-secondary badge-sm">Claude - anyone can toggle</span>
                  <%= if @s.suggesting do %>
                    <.mini_dots />
                  <% end %>
                </div>

                <%= for {suggestion, idx} <- Enum.with_index(@s.suggestions) do %>
                  <button
                    phx-click="toggle_priority_suggestion"
                    phx-value-idx={idx}
                    class={"flex items-center gap-3 px-3 py-2 rounded-lg border w-full text-left transition-all " <>
                         if(suggestion.included, do: "border-secondary bg-secondary/10", else: "border-base-300 hover:border-secondary/50")}
                  >
                    <div class={"w-4 h-4 rounded border-2 flex items-center justify-center flex-shrink-0 " <>
                               if(suggestion.included, do: "border-secondary bg-secondary", else: "border-base-300")}>
                      <%= if suggestion.included do %>
                        <svg
                          class="w-2.5 h-2.5 text-secondary-content"
                          fill="currentColor"
                          viewBox="0 0 12 12"
                        >
                          <path
                            d="M10 3L5 8.5 2 5.5"
                            stroke="currentColor"
                            stroke-width="2"
                            fill="none"
                            stroke-linecap="round"
                          />
                        </svg>
                      <% end %>
                    </div>

                    <span class={direction_color(suggestion.direction) <> " font-mono font-bold text-lg w-4"}>
                      {suggestion.direction}
                    </span> <span class="text-sm flex-1">{suggestion.text}</span>
                  </button>
                <% end %>
              </div>
            </div>
          <% else %>
            <.claude_thinking label="Claude" />
          <% end %>
        </div>
         <%!-- Your card (bottom center) --%>
        <div
          class="absolute z-20 transition-all duration-700 ease-in-out"
          style={"left: #{@your_x}%; top: #{@your_y}%; transform: translate(-50%, -50%);"}
        >
          <%= if @spectator do %>
            <span class="badge badge-ghost">Spectating</span>
          <% else %>
            <div class={"card w-80 border-2 bg-base-100 shadow-xl " <> if(@is_confirmed, do: "border-success", else: "border-base-300")}>
              <div class="card-body p-4 gap-3">
                <div class="flex items-center justify-between">
                  <span class="badge badge-ghost badge-sm">you</span>
                  <%= if @is_confirmed do %>
                    <span class="text-xs text-success">confirmed ✓</span>
                  <% end %>
                </div>

                <form
                  phx-change="upsert_priority"
                  phx-submit="upsert_priority"
                  class="flex gap-2 items-center"
                >
                  <div class="flex gap-1">
                    <%= for dir <- ["+", "-", "~"] do %>
                      <button
                        type="button"
                        phx-click="upsert_priority"
                        phx-value-direction={dir}
                        phx-value-text={@my_text}
                        class={"btn btn-sm font-mono " <> direction_btn_class(dir, @my_direction)}
                      >
                        {dir}
                      </button>
                    <% end %>
                  </div>
                   <input type="hidden" name="direction" value={@my_direction} />
                  <input
                    type="text"
                    name="text"
                    value={@my_text}
                    placeholder="e.g. cost, speed"
                    class="input input-bordered input-sm flex-1"
                    autocomplete="off"
                  />
                </form>

                <div class="flex gap-2">
                  <button
                    phx-click="confirm_priority"
                    disabled={@my_text == "" or @is_ready}
                    class={"btn btn-sm flex-1 " <> if(@is_confirmed, do: "btn-success", else: "btn-outline btn-success")}
                  >
                    {if @is_confirmed, do: "Confirmed ✓", else: "Confirm"}
                  </button>
                  <button
                    phx-click="ready_priority"
                    disabled={not @is_confirmed or @is_ready}
                    class={"btn btn-sm flex-1 " <>
                    cond do
                      @is_ready -> "btn-primary"
                      @all_confirmed and @is_confirmed -> "btn-primary animate-pulse"
                      true -> "btn-outline btn-primary"
                    end}
                  >
                    {if @is_ready, do: "Ready ✓", else: "Ready up"}
                  </button>
                </div>

                <%= if not @all_confirmed and @is_confirmed and @waiting_count > 0 do %>
                  <p class="text-xs text-base-content/40 text-center">
                    Waiting for {@waiting_count} {if @waiting_count == 1, do: "person", else: "people"}...
                  </p>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
         <%!-- Vote tally (bottom right) --%>
        <div class="absolute bottom-4 right-4 text-xs text-base-content/40 font-mono">
          {MapSet.size(@s.confirmed)} / {MapSet.size(@decision.connected)} confirmed
        </div>
      </div>
    </div>
    """
  end

  def priorities_modal(assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Name Your Priorities</h3>

      <p>Each person enters one priority - a dimension that matters for this decision.</p>

      <ul class="list-disc list-inside text-sm text-base-content/70 gap-1 flex flex-col">
        <li>
          <span class="font-mono font-bold text-success">+</span>
          maximize - e.g. "speed", "simplicity"
        </li>

        <li><span class="font-mono font-bold text-error">-</span> minimize - e.g. "cost", "risk"</li>

        <li>
          <span class="font-mono font-bold text-base-content/50">~</span>
          relevant but not deciding - e.g. "team familiarity"
        </li>
      </ul>

      <p class="text-sm text-base-content/60">
        Name the dimension, not a directional statement. "cost" not "too expensive".
      </p>

      <p class="text-sm text-base-content/60">
        Hit Confirm when done. Claude suggests extras once everyone confirms. Ready up when satisfied.
      </p>
    </.modal_overlay>
    """
  end

  defp direction_color("+"), do: "text-success"
  defp direction_color("-"), do: "text-error"
  defp direction_color(_), do: "text-base-content/50"

  defp direction_btn_class(dir, dir), do: "btn-primary"
  defp direction_btn_class(_, _), do: "btn-ghost"
end
