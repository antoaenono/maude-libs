defmodule MaudeLibsWeb.DecisionLive.LobbyStage do
  use Phoenix.Component
  import MaudeLibsWeb.DecisionLive.DecisionComponents, only: [modal_overlay: 1]
  import MaudeLibsWeb.DecisionLive.StageShell

  alias MaudeLibs.UserRegistry

  def lobby_stage(assigns) do
    s = assigns.decision.stage
    is_creator = not assigns.spectator and assigns.username == assigns.decision.creator
    is_ready = assigns.username in s.ready

    all_ready =
      MapSet.subset?(s.joined, s.ready) and
        MapSet.size(s.joined) > 0

    all_usernames = UserRegistry.list_usernames()

    other_users =
      s.joined |> MapSet.to_list() |> Enum.reject(&(&1 == assigns.username))

    ghost_users =
      MapSet.difference(s.invited, s.joined) |> MapSet.to_list()

    assigns =
      assign(assigns,
        s: s,
        is_creator: is_creator,
        is_ready: is_ready,
        all_ready: all_ready,
        all_usernames: all_usernames,
        other_users: other_users,
        ghost_users: ghost_users
      )

    ~H"""
    <.stage_shell stage={@decision.stage}>
      <div class="h-full flex">
        <%!-- Sidebar --%>
        <div class="w-72 shrink-0 border-r border-base-300 bg-base-100/80 p-6 flex flex-col gap-6 overflow-y-auto">
          <%= if @is_creator do %>
            <h2 class="text-lg font-bold">New Decision</h2>

            <form phx-change="lobby_update" class="form-control">
              <label class="label">
                <span class="label-text font-semibold text-sm">What are you deciding?</span>
              </label>
              <input
                type="text"
                name="topic"
                value={@decision.topic || ""}
                placeholder="e.g. where should we go for dinner?"
                class="input input-bordered input-sm"
                autocomplete="off"
                phx-debounce="150"
              />
            </form>

            <div class="flex flex-col gap-2">
              <span class="label-text font-semibold text-sm">Invite participants</span>

              <form phx-submit="add_invite" class="flex gap-1">
                <input
                  type="text"
                  name="username"
                  placeholder="username"
                  class="input input-bordered input-sm flex-1"
                  list="known-usernames"
                  autocomplete="off"
                  phx-hook="ClearOnSubmit"
                  id="invite-input"
                />
                <button type="submit" class="btn btn-sm btn-ghost">+</button>
                <datalist id="known-usernames">
                  <%= for u <- @all_usernames, u != @username do %>
                    <option value={u} />
                  <% end %>
                </datalist>
              </form>

              <%!-- Participant list --%>
              <div class="flex flex-col gap-1">
                <%!-- Joined users (other than creator) --%>
                <%= for user <- @other_users do %>
                  <div class="flex items-center justify-between text-sm">
                    <div class="flex items-center gap-2">
                      <span class={"w-2 h-2 rounded-full " <> if(user in @s.ready, do: "bg-success", else: "bg-base-content/20")} />
                      <span class="font-mono">{user}</span>
                    </div>
                    <button
                      phx-click="remove_participant"
                      phx-value-user={user}
                      class="btn btn-xs btn-ghost text-error"
                    >
                      ×
                    </button>
                  </div>
                <% end %>
                <%!-- Invited but not yet joined --%>
                <%= for user <- @ghost_users do %>
                  <div class="flex items-center justify-between text-sm opacity-50">
                    <div class="flex items-center gap-2">
                      <span class="w-2 h-2 rounded-full bg-base-content/20" />
                      <span class="font-mono italic">{user}</span>
                    </div>
                    <button
                      phx-click="remove_invite"
                      phx-value-user={user}
                      class="btn btn-xs btn-ghost text-error"
                    >
                      ×
                    </button>
                  </div>
                <% end %>
              </div>
            </div>
          <% else %>
            <h2 class="text-lg font-bold">Lobby</h2>

            <div class="flex flex-col gap-2">
              <span class="text-xs text-base-content/50 uppercase tracking-wide">Topic</span>
              <p class="font-semibold">{@decision.topic || "(waiting for creator...)"}</p>
            </div>

            <div class="flex flex-col gap-2">
              <span class="text-xs text-base-content/50 uppercase tracking-wide">Participants</span>
              <%= for user <- MapSet.to_list(@s.joined) do %>
                <div class="flex items-center gap-2">
                  <span class={"w-2 h-2 rounded-full " <> if(user in @s.ready, do: "bg-success", else: "bg-base-content/20")} />
                  <span class={"font-mono text-sm " <> if(user == @username, do: "font-bold", else: "")}>
                    {user}
                  </span>
                </div>
              <% end %>
              <%= for user <- @ghost_users do %>
                <div class="flex items-center gap-2 opacity-40">
                  <span class="w-2 h-2 rounded-full bg-base-content/20" />
                  <span class="font-mono text-sm italic">{user} (invited)</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Canvas --%>
        <div id="lobby-canvas" phx-hook="ScaleToFit" class="flex-1 h-full overflow-hidden relative">
          <div
            id="lobby-force"
            phx-hook="StageForce"
            data-testid="virtual-canvas"
            class="absolute select-none"
            style="width: 1000px; height: 900px;"
          >
            <%!-- Invisible center anchor (keeps D3 layout consistent with other stages) --%>
            <div
              data-node-id="center"
              data-node-role="claude"
              class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 opacity-0 pointer-events-none"
            >
              <div style="width: 1px; height: 1px;"></div>
            </div>

            <%!-- Other joined users --%>
            <%= for user <- @other_users do %>
              <div
                data-node-id={user}
                data-node-role="other"
                class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
              >
                <div class="card w-44 border-2 bg-base-100 shadow-md border-base-300">
                  <div class="card-body p-4 gap-2">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-2">
                        <span class={"w-2 h-2 rounded-full " <> if(user in @s.ready, do: "bg-success", else: "bg-base-content/20")} />
                        <span class="font-mono text-sm">{user}</span>
                      </div>
                      <%= if @is_creator do %>
                        <button
                          phx-click="remove_participant"
                          phx-value-user={user}
                          class="btn btn-xs btn-ghost text-error"
                        >
                          ×
                        </button>
                      <% end %>
                    </div>
                    <%= if user in @s.ready do %>
                      <span class="text-xs text-success">ready ✓</span>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Ghost users (invited, not yet joined) --%>
            <%= for user <- @ghost_users do %>
              <div
                data-node-id={user}
                data-node-role="other"
                class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 transition-opacity duration-500"
              >
                <div class="card w-44 border-2 border-dashed bg-base-100/50 shadow-sm border-base-300 opacity-40">
                  <div class="card-body p-4 gap-2">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-2">
                        <span class="w-2 h-2 rounded-full bg-base-content/20" />
                        <span class="font-mono text-sm italic">{user}</span>
                      </div>
                      <%= if @is_creator do %>
                        <button
                          phx-click="remove_invite"
                          phx-value-user={user}
                          class="btn btn-xs btn-ghost text-error"
                        >
                          ×
                        </button>
                      <% end %>
                    </div>
                    <span class="text-xs text-base-content/30">invited</span>
                  </div>
                </div>
              </div>
            <% end %>

            <%!-- Your card --%>
            <div
              data-node-id="you"
              data-node-role="you"
              class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
            >
              <%= if @spectator do %>
                <div class="card w-44 border-2 border-dashed bg-base-100/50 shadow-sm border-base-300">
                  <div class="card-body p-4 gap-2">
                    <span class="font-mono text-sm">{@username}</span>
                    <span class="badge badge-ghost badge-sm">spectating</span>
                  </div>
                </div>
              <% else %>
                <div class={"card w-44 border-2 bg-base-100 shadow-xl " <> if(@is_ready, do: "border-success", else: "border-base-300")}>
                  <div class="card-body p-4 gap-2">
                    <div class="flex items-center gap-2">
                      <span class={"w-2 h-2 rounded-full " <> if(@is_ready, do: "bg-success", else: "bg-base-content/20")} />
                      <span class="font-mono text-sm font-bold">{@username}</span>
                    </div>
                    <%= if @is_ready do %>
                      <span class="text-xs text-success">ready ✓</span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>

            <%!-- Tally (bottom right) --%>
            <div class="absolute bottom-4 right-4 text-xs text-base-content/40 font-mono">
              {MapSet.size(@s.ready)} / {MapSet.size(@s.joined)} ready
            </div>
          </div>
        </div>
      </div>

      <:footer>
        <%= if not @spectator do %>
          <div class="bg-base-100/80 backdrop-blur border-t border-base-300 px-8 py-3 flex justify-center gap-2">
            <%= if @username not in @s.joined do %>
              <button phx-click="lobby_join" class="btn btn-outline btn-primary">Join</button>
            <% else %>
              <button
                phx-click="lobby_ready"
                class={"btn " <> if(@is_ready, do: "btn-success", else: "btn-outline btn-success")}
              >
                {if @is_ready, do: "Ready ✓", else: "Ready up"}
              </button>
            <% end %>

            <%= if @is_creator and @all_ready do %>
              <button phx-click="lobby_start" class="btn btn-primary">Start</button>
            <% end %>
          </div>
        <% else %>
          <div class="bg-base-100/80 backdrop-blur border-t border-base-300 px-8 py-3 flex justify-center">
            <span class="badge badge-ghost">Spectating</span>
          </div>
        <% end %>
      </:footer>
    </.stage_shell>
    """
  end

  def lobby_modal(assigns) do
    is_creator = Map.get(assigns, :is_creator, false)
    assigns = assign(assigns, :is_creator, is_creator)

    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Lobby</h3>

      <%= if @is_creator do %>
        <p>
          Set the decision topic and invite participants. Everyone must ready up before you can start.
        </p>

        <p class="text-sm text-base-content/60">Once started you'll frame the scenario together.</p>
      <% else %>
        <p>You've been invited to join this decision. Ready up when you're set to go.</p>

        <p class="text-sm text-base-content/60">
          Once everyone is ready the creator will start and you'll frame the scenario together.
        </p>
      <% end %>
    </.modal_overlay>
    """
  end
end
