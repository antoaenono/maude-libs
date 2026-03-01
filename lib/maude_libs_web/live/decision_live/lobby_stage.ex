defmodule MaudeLibsWeb.DecisionLive.LobbyStage do
  use Phoenix.Component
  import MaudeLibsWeb.DecisionLive.DecisionComponents, only: [modal_overlay: 1]

  alias MaudeLibs.UserRegistry

  def lobby_stage(assigns) do
    is_creator = not assigns.spectator and assigns.username == assigns.decision.creator
    is_ready = assigns.username in assigns.decision.stage.ready

    all_ready =
      MapSet.subset?(assigns.decision.stage.joined, assigns.decision.stage.ready) and
        MapSet.size(assigns.decision.stage.joined) > 0

    all_usernames = UserRegistry.list_usernames()

    assigns =
      assign(assigns,
        is_creator: is_creator,
        is_ready: is_ready,
        all_ready: all_ready,
        all_usernames: all_usernames
      )

    ~H"""
    <div class="min-h-screen flex flex-col lg:flex-row p-8 gap-8 max-w-4xl mx-auto">
      <%!-- Left: topic + invite --%>
      <div class="flex-1 flex flex-col gap-6">
        <h2 class="text-2xl font-bold">New Decision</h2>

        <%= if @is_creator do %>
          <form phx-submit="lobby_update" phx-change="lobby_update" class="flex flex-col gap-4">
            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">What are you deciding?</span>
              </label>
              <input
                type="text"
                name="topic"
                value={@decision.topic || ""}
                placeholder="e.g. where should we go for dinner?"
                class="input input-bordered"
                autocomplete="off"
              />
            </div>

            <div class="form-control">
              <label class="label">
                <span class="label-text font-semibold">Invite participants</span>
                <span class="label-text-alt text-base-content/50">comma-separated usernames</span>
              </label>
              <input
                type="text"
                name="invite"
                value={
                  @decision.stage.invited
                  |> MapSet.to_list()
                  |> Enum.reject(&(&1 == @username))
                  |> Enum.join(", ")
                }
                placeholder="bob, charlie"
                class="input input-bordered"
                list="known-usernames"
                autocomplete="off"
              />
              <datalist id="known-usernames">
                <%= for u <- @all_usernames, u != @username do %>
                  <option value={u} />
                <% end %>
              </datalist>
            </div>
          </form>
        <% else %>
          <div class="flex flex-col gap-2">
            <p class="text-base-content/70">Decision topic:</p>

            <p class="text-xl font-semibold">{@decision.topic || "(waiting for creator...)"}</p>
          </div>
        <% end %>
      </div>
       <%!-- Right: participant list --%>
      <div class="w-64 flex flex-col gap-4">
        <h3 class="font-semibold text-base-content/70">Participants</h3>

        <div class="flex flex-col gap-2">
          <%= for user <- MapSet.to_list(@decision.stage.joined) do %>
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <span class={"w-2 h-2 rounded-full #{if user in @decision.stage.ready, do: "bg-success", else: "bg-base-content/20"}"} />
                <span class={"font-mono #{if user == @username, do: "font-bold"}"}>{user}</span>
              </div>

              <%= if @is_creator and user != @username and user not in @decision.stage.ready do %>
                <button
                  phx-click="remove_participant"
                  phx-value-user={user}
                  class="btn btn-xs btn-ghost text-error"
                >
                  ×
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
         <%!-- Actions --%>
        <%= if not @spectator do %>
          <div class="flex flex-col gap-2 mt-auto">
            <%= if @username not in @decision.stage.joined do %>
              <button phx-click="lobby_join" class="btn btn-outline btn-primary">Join</button>
            <% else %>
              <button
                phx-click="lobby_ready"
                class={"btn #{if @is_ready, do: "btn-success", else: "btn-outline btn-success"}"}
              >
                {if @is_ready, do: "Ready ✓", else: "Ready up"}
              </button>
            <% end %>

            <%= if @is_creator and @all_ready do %>
              <button phx-click="lobby_start" class="btn btn-primary">Start</button>
            <% end %>
          </div>
        <% else %>
          <div class="mt-auto"><span class="badge badge-ghost">Spectating</span></div>
        <% end %>
      </div>
    </div>
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
