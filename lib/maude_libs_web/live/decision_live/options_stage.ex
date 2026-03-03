defmodule MaudeLibsWeb.DecisionLive.OptionsStage do
  use Phoenix.Component

  import MaudeLibsWeb.DecisionLive.DecisionComponents,
    only: [claude_thinking: 1, mini_dots: 1, priority_badge_class: 1, modal_overlay: 1]

  import MaudeLibsWeb.DecisionLive.StageShell

  def options_stage(assigns) do
    s = assigns.decision.stage
    my_option = Map.get(s.proposals, assigns.username)
    my_name = if my_option, do: my_option.name, else: ""
    my_desc = if my_option, do: my_option.desc, else: ""
    is_confirmed = assigns.username in s.confirmed
    is_ready = assigns.username in s.ready

    all_confirmed =
      MapSet.subset?(assigns.decision.connected, s.confirmed) and
        MapSet.size(assigns.decision.connected) > 0

    waiting_count = MapSet.size(assigns.decision.connected) - MapSet.size(s.confirmed)

    other_users =
      MapSet.to_list(assigns.decision.connected) |> Enum.reject(&(&1 == assigns.username))

    assigns =
      assign(assigns,
        s: s,
        my_option: my_option,
        my_name: my_name,
        my_desc: my_desc,
        is_confirmed: is_confirmed,
        is_ready: is_ready,
        all_confirmed: all_confirmed,
        waiting_count: waiting_count,
        other_users: other_users
      )

    ~H"""
    <.stage_shell stage={@decision.stage}>
      <:header>
        <div class="bg-base-100/80 backdrop-blur border-b border-base-300 px-8 py-4 flex flex-col items-center gap-2">
          <span class="text-xs font-mono text-base-content/40 uppercase tracking-widest">
            Propose options
          </span>
           <span class="text-lg font-semibold text-base-content">{@decision.topic}</span>
          <%= if length(@decision.priorities) > 0 do %>
            <div class="flex flex-wrap justify-center gap-1.5">
              <%= for p <- @decision.priorities do %>
                <span class={"badge badge-sm badge-outline font-mono " <> priority_badge_class(p.direction)}>
                  {p.direction} {p.text}
                </span>
              <% end %>
            </div>
          <% end %>
          <span class="text-xs text-base-content/40">Each person enters one concrete option</span>
        </div>
      </:header>

      <div id="options-canvas" phx-hook="ScaleToFit" class="w-full h-full overflow-hidden relative">
        <div
          id="options-force"
          phx-hook="StageForce"
          data-testid="virtual-canvas"
          class="absolute select-none"
          style="width: 1000px; height: 900px;"
        >
          <%!-- Other participants' option cards --%>
          <%= for user <- @other_users do %>
            <% opt = Map.get(@s.proposals, user) %>
            <div
              data-node-id={user}
              data-node-role="other"
              class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
            >
              <div class={"card w-52 border-2 bg-base-100 shadow-md " <> if(user in @s.confirmed, do: "border-success", else: "border-base-300")}>
                <div class="card-body p-4 gap-2">
                  <div class="flex items-center justify-between">
                    <span class="badge badge-ghost badge-sm">{user}</span>
                    <%= if user in @s.confirmed do %>
                      <span class="text-xs text-success">confirmed ✓</span>
                    <% end %>
                  </div>

                  <%= if opt do %>
                    <p class="font-semibold text-sm">{opt.name}</p>

                    <p class="text-xs text-base-content/60">{opt.desc}</p>
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
            data-node-id="claude"
            data-node-role="claude"
            class={"absolute z-20 left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 " <> if(has_claude_content, do: "opacity-100", else: "opacity-0 pointer-events-none")}
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
                      phx-click="toggle_option_suggestion"
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
                      <span class="text-sm font-semibold">{suggestion.name}</span>
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
            data-node-id="you"
            data-node-role="you"
            class="absolute z-20 left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
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
                    phx-change="upsert_option"
                    phx-submit="confirm_option"
                    class="flex flex-col gap-2"
                  >
                    <input
                      type="text"
                      name="name"
                      value={@my_name}
                      placeholder="Short name (2-4 words)"
                      class="input input-bordered input-sm"
                      autocomplete="off"
                    />
                    <button
                      type="submit"
                      disabled={@my_name == "" or @is_ready}
                      class={"btn btn-sm flex-1 " <> if(@is_confirmed, do: "btn-success", else: "btn-outline btn-success")}
                    >
                      {if @is_confirmed, do: "Confirmed ✓", else: "Confirm"}
                    </button>
                  </form>

                  <%= if not @all_confirmed and @is_confirmed and @waiting_count > 0 do %>
                    <p class="text-xs text-base-content/40 text-center">
                      Waiting for {@waiting_count} {if @waiting_count == 1,
                        do: "person",
                        else: "people"}...
                    </p>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Tally (bottom right) --%>
          <div class="absolute bottom-4 right-4 text-xs text-base-content/40 font-mono">
            {MapSet.size(@s.confirmed)} / {MapSet.size(@decision.connected)} confirmed
          </div>
        </div>
      </div>

      <:footer>
        <%= if not @spectator do %>
          <div class="bg-base-100/80 backdrop-blur border-t border-base-300 px-8 py-3 flex justify-center">
            <button
              phx-click="ready_options"
              disabled={not @is_confirmed or @is_ready}
              class={"btn btn-sm " <>
              cond do
                @is_ready -> "btn-primary"
                @all_confirmed and @is_confirmed -> "btn-primary animate-pulse"
                true -> "btn-outline btn-primary"
              end}
            >
              {if @is_ready, do: "Ready ✓", else: "Ready up"}
            </button>
          </div>
        <% end %>
      </:footer>
    </.stage_shell>
    """
  end

  def options_modal(assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Propose Options</h3>

      <p>Each person enters one option - a concrete choice the group could make.</p>

      <ul class="list-disc list-inside text-sm text-base-content/70 gap-1 flex flex-col">
        <li>Give it a short name (2-4 words)</li>

        <li>Add a one-sentence description</li>

        <li>Edit freely - hit Confirm when done</li>
      </ul>

      <p class="text-sm text-base-content/60">
        Claude suggests extras once everyone confirms. Toggle them in or out. Ready up when satisfied.
      </p>
    </.modal_overlay>
    """
  end
end
