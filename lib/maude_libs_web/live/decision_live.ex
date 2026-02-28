defmodule MaudeLibsWeb.DecisionLive do
  use MaudeLibsWeb, :live_view
  require Logger

  alias MaudeLibs.Decision.{Server, Supervisor, Stage}
  alias MaudeLibs.UserRegistry

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(%{"id" => "new"}, session, socket) do
    username = session["username"]

    if is_nil(username) do
      {:ok, push_navigate(socket, to: "/join")}
    else
      if connected?(socket) do
        id = generate_id()
        {:ok, _pid} = Supervisor.start_decision(id, username, "")
        Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{id}")
        decision = Server.get_state(id)
        {:ok, push_navigate(socket, to: "/d/#{id}", replace: true)}
      else
        {:ok, assign(socket, username: username, decision: nil, id: nil, modal_open: false, spectator: false)}
      end
    end
  end

  def mount(%{"id" => id}, session, socket) do
    username = session["username"]

    if is_nil(username) do
      {:ok, push_navigate(socket, to: "/join")}
    else
      case Server.whereis(id) do
        nil ->
          {:ok, push_navigate(socket, to: "/canvas")}

        _pid ->
          Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{id}")
          decision = Server.get_state(id)
          is_invited = match?(%Stage.Lobby{}, decision.stage) and username in decision.stage.invited
          is_participant = username in decision.connected or is_invited
          cond do
            username in decision.connected ->
              Server.handle_message(id, {:connect, username})
            is_invited ->
              Server.handle_message(id, {:join, username})
            true ->
              :ok
          end
          decision = Server.get_state(id)
          {:ok, assign(socket, username: username, decision: decision, id: id, modal_open: true, spectator: not is_participant)}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Terminate
  # ---------------------------------------------------------------------------

  @impl true
  def terminate(_reason, socket) do
    if id = socket.assigns[:id] do
      Server.disconnect(id, socket.assigns.username)
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:decision_updated, decision}, socket) do
    {:noreply, assign(socket, decision: decision)}
  end

  # ---------------------------------------------------------------------------
  # Modal
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal_open: false)}
  end

  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, modal_open: true)}
  end

  # ---------------------------------------------------------------------------
  # Lobby events
  # ---------------------------------------------------------------------------

  def handle_event("lobby_update", %{"topic" => topic, "invite" => invite_raw}, socket) do
    invited = invite_raw |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    Server.handle_message(socket.assigns.id, {:lobby_update, socket.assigns.username, topic, invited})
    {:noreply, socket}
  end

  def handle_event("lobby_ready", _params, socket) do
    Server.handle_message(socket.assigns.id, {:ready, socket.assigns.username})
    {:noreply, socket}
  end

  def handle_event("lobby_start", _params, socket) do
    Server.handle_message(socket.assigns.id, {:start, socket.assigns.username})
    {:noreply, socket}
  end

  def handle_event("lobby_join", _params, socket) do
    Server.handle_message(socket.assigns.id, {:join, socket.assigns.username})
    {:noreply, socket}
  end

  def handle_event("remove_participant", %{"user" => user}, socket) do
    Server.handle_message(socket.assigns.id, {:remove_participant, socket.assigns.username, user})
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Scenario events
  # ---------------------------------------------------------------------------

  def handle_event("submit_scenario", %{"text" => text}, socket) do
    Server.handle_message(socket.assigns.id, {:submit_scenario, socket.assigns.username, text})
    {:noreply, socket}
  end

  def handle_event("vote_scenario", %{"candidate" => candidate}, socket) do
    Server.handle_message(socket.assigns.id, {:vote_scenario, socket.assigns.username, candidate})
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Priorities events
  # ---------------------------------------------------------------------------

  def handle_event("upsert_priority", %{"text" => text, "direction" => direction}, socket) do
    priority = %{text: text, direction: direction}
    Server.handle_message(socket.assigns.id, {:upsert_priority, socket.assigns.username, priority})
    {:noreply, socket}
  end

  def handle_event("confirm_priority", _params, socket) do
    Server.handle_message(socket.assigns.id, {:confirm_priority, socket.assigns.username})
    {:noreply, socket}
  end

  def handle_event("toggle_priority_suggestion", %{"idx" => idx, "included" => included}, socket) do
    Server.handle_message(socket.assigns.id, {:toggle_priority_suggestion, String.to_integer(idx), included == "true"})
    {:noreply, socket}
  end

  def handle_event("ready_priority", _params, socket) do
    Server.handle_message(socket.assigns.id, {:ready_priority, socket.assigns.username})
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Options events
  # ---------------------------------------------------------------------------

  def handle_event("upsert_option", %{"name" => name, "desc" => desc}, socket) do
    option = %{name: name, desc: desc}
    Server.handle_message(socket.assigns.id, {:upsert_option, socket.assigns.username, option})
    {:noreply, socket}
  end

  def handle_event("confirm_option", _params, socket) do
    Server.handle_message(socket.assigns.id, {:confirm_option, socket.assigns.username})
    {:noreply, socket}
  end

  def handle_event("toggle_option_suggestion", %{"idx" => idx, "included" => included}, socket) do
    Server.handle_message(socket.assigns.id, {:toggle_option_suggestion, String.to_integer(idx), included == "true"})
    {:noreply, socket}
  end

  def handle_event("ready_options", _params, socket) do
    Server.handle_message(socket.assigns.id, {:ready_options, socket.assigns.username})
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Dashboard events
  # ---------------------------------------------------------------------------

  def handle_event("toggle_vote", %{"option" => option_name}, socket) do
    s = socket.assigns.decision.stage
    current_votes = Map.get(s.votes, socket.assigns.username, [])
    new_votes =
      if option_name in current_votes do
        List.delete(current_votes, option_name)
      else
        [option_name | current_votes]
      end
    if new_votes != [] do
      Server.handle_message(socket.assigns.id, {:vote, socket.assigns.username, new_votes})
    end
    {:noreply, socket}
  end

  def handle_event("ready_dashboard", _params, socket) do
    Server.handle_message(socket.assigns.id, {:ready_dashboard, socket.assigns.username})
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(%{decision: nil} = assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex items-center justify-center">
      <span class="loading loading-spinner loading-lg text-primary"></span>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 relative">
      <%!-- ? button always visible --%>
      <button
        phx-click="open_modal"
        class="fixed top-4 right-4 btn btn-circle btn-sm btn-ghost z-10 text-base-content/50 hover:text-base-content"
      >
        ?
      </button>

      <%!-- Stage modal --%>
      <%= if @modal_open do %>
        <.stage_modal stage={@decision.stage} />
      <% end %>

      <%!-- Route to correct stage component --%>
      <%= render_stage(assigns) %>
    </div>
    """
  end

  defp render_stage(%{decision: %{stage: %Stage.Lobby{}}} = assigns) do
    ~H"""
    <.lobby_stage decision={@decision} username={@username} spectator={@spectator} />
    """
  end

  defp render_stage(%{decision: %{stage: %Stage.Scenario{}}} = assigns) do
    ~H"""
    <.scenario_stage decision={@decision} username={@username} spectator={@spectator} />
    """
  end

  defp render_stage(%{decision: %{stage: %Stage.Priorities{}}} = assigns) do
    ~H"""
    <.priorities_stage decision={@decision} username={@username} spectator={@spectator} />
    """
  end

  defp render_stage(%{decision: %{stage: %Stage.Options{}}} = assigns) do
    ~H"""
    <.options_stage decision={@decision} username={@username} spectator={@spectator} />
    """
  end

  defp render_stage(%{decision: %{stage: %Stage.Scaffolding{}}} = assigns) do
    ~H"""
    <.scaffolding_stage />
    """
  end

  defp render_stage(%{decision: %{stage: %Stage.Dashboard{}}} = assigns) do
    ~H"""
    <.dashboard_stage decision={@decision} username={@username} spectator={@spectator} />
    """
  end

  defp render_stage(%{decision: %{stage: %Stage.Complete{}}} = assigns) do
    ~H"""
    <.complete_stage decision={@decision} />
    """
  end

  # ---------------------------------------------------------------------------
  # Lobby component
  # ---------------------------------------------------------------------------

  defp lobby_stage(assigns) do
    is_creator = not assigns.spectator and assigns.username == creator_of(assigns.decision)
    is_ready = assigns.username in assigns.decision.stage.ready
    all_ready = MapSet.subset?(assigns.decision.stage.joined, assigns.decision.stage.ready) and
                MapSet.size(assigns.decision.stage.joined) > 0
    all_usernames = UserRegistry.list_usernames()
    assigns = assign(assigns, is_creator: is_creator, is_ready: is_ready, all_ready: all_ready, all_usernames: all_usernames)

    ~H"""
    <div class="min-h-screen flex flex-col lg:flex-row p-8 gap-8 max-w-4xl mx-auto">
      <%!-- Left: topic + invite --%>
      <div class="flex-1 flex flex-col gap-6">
        <h2 class="text-2xl font-bold">New Decision</h2>

        <%= if @is_creator do %>
          <form phx-submit="lobby_update" phx-change="lobby_update" class="flex flex-col gap-4">
            <div class="form-control">
              <label class="label"><span class="label-text font-semibold">What are you deciding?</span></label>
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
                value={@decision.stage.invited |> MapSet.to_list() |> Enum.reject(&(&1 == @username)) |> Enum.join(", ")}
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
            <p class="text-xl font-semibold"><%= @decision.topic || "(waiting for creator...)" %></p>
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
                <span class={"font-mono #{if user == @username, do: "font-bold"}"}><%= user %></span>
              </div>
              <%= if @is_creator and user != @username and user not in @decision.stage.ready do %>
                <button phx-click="remove_participant" phx-value-user={user} class="btn btn-xs btn-ghost text-error">
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
                <%= if @is_ready, do: "Ready ✓", else: "Ready up" %>
              </button>
            <% end %>

            <%= if @is_creator and @all_ready do %>
              <button phx-click="lobby_start" class="btn btn-primary">Start</button>
            <% end %>
          </div>
        <% else %>
          <div class="mt-auto">
            <span class="badge badge-ghost">Spectating</span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Scenario component
  # ---------------------------------------------------------------------------

  # Spatial positions for other participants: {left%, top%}
  # "others" excludes self; Claude goes dead center (50%, 50%)
  # self always anchored at bottom center (50%, 85%)
  @other_positions %{
    1 => [{"50%", "15%"}],
    2 => [{"28%", "20%"}, {"72%", "20%"}],
    3 => [{"50%", "12%"}, {"22%", "35%"}, {"78%", "35%"}]
  }

  defp scenario_stage(assigns) do
    s = assigns.decision.stage
    my_vote = Map.get(s.votes, assigns.username)
    other_users = MapSet.to_list(assigns.decision.connected) |> Enum.reject(&(&1 == assigns.username))
    positions = Map.get(@other_positions, min(length(other_users), 3), [])
    others_with_pos = Enum.zip(other_users, positions)
    assigns = assign(assigns, s: s, my_vote: my_vote, other_users: other_users, others_with_pos: others_with_pos)

    ~H"""
    <div class="w-screen h-screen overflow-hidden relative select-none">
      <%!-- Sticky header --%>
      <div class="absolute top-0 left-0 right-0 z-10 bg-base-100/80 backdrop-blur border-b border-base-300 px-8 py-4 flex flex-col items-center gap-1">
        <span class="text-xs font-mono text-base-content/40 uppercase tracking-widest">Frame the scenario</span>
        <span class="text-lg font-semibold text-base-content"><%= @decision.topic %></span>
        <span class="text-xs text-base-content/40">Vote on a framing - everyone must agree to proceed</span>
      </div>

      <%!-- Other participants' cards --%>
      <%= for {user, {left, top}} <- @others_with_pos do %>
        <% text = Map.get(@s.submissions, user, "") %>
        <% voted = Map.get(@s.votes, user) %>
        <div
          class="absolute"
          style={"left: #{left}; top: #{top}; transform: translate(-50%, -50%);"}
        >
          <.candidate_card
            text={if text != "", do: text, else: nil}
            label={user}
            voted={voted != nil}
            selected={@my_vote != nil and @my_vote == text and text != ""}
            is_synthesis={false}
            spectator={@spectator}
            placeholder="thinking..."
          />
        </div>
      <% end %>

      <%!-- Claude synthesis (dead center) --%>
      <%= if @s.synthesis do %>
        <div class="absolute" style="left: 50%; top: 50%; transform: translate(-50%, -50%);">
          <.candidate_card
            text={@s.synthesis}
            label="Claude"
            voted={false}
            selected={@my_vote == @s.synthesis}
            is_synthesis={true}
            spectator={@spectator}
            placeholder={nil}
          />
        </div>
      <% end %>

      <%!-- Your card (bottom center) --%>
      <div class="absolute" style="left: 50%; top: 82%; transform: translate(-50%, -50%);">
        <% my_text = Map.get(@s.submissions, @username, "") %>
        <%= if @spectator do %>
          <.candidate_card
            text={if my_text != "", do: my_text, else: nil}
            label="you (spectating)"
            voted={@my_vote != nil}
            selected={false}
            is_synthesis={false}
            spectator={true}
            placeholder="spectating"
          />
        <% else %>
          <div class={"card w-72 border-2 bg-base-100 shadow-xl " <> if(@my_vote != nil, do: "border-primary", else: "border-base-300")}>
            <div class="card-body p-4 gap-3">
              <div class="flex items-center justify-between">
                <span class="badge badge-ghost badge-sm">you</span>
                <%= if @my_vote != nil do %>
                  <span class="text-xs text-primary font-semibold">voted ✓</span>
                <% end %>
              </div>
              <% my_sub = Map.get(@s.submissions, @username) %>
              <%= if my_sub && my_sub != "" do %>
                <p class="text-sm font-medium"><%= my_sub %></p>
                <button
                  phx-click="vote_scenario"
                  phx-value-candidate={my_sub}
                  class={"btn btn-xs " <> if(@my_vote == my_sub, do: "btn-primary", else: "btn-outline btn-primary")}
                >
                  <%= if @my_vote == my_sub, do: "Your vote ✓", else: "Vote for yours" %>
                </button>
              <% end %>
              <form phx-submit="submit_scenario" class="flex gap-2 mt-1">
                <input
                  type="text"
                  name="text"
                  value={my_sub || ""}
                  placeholder="Rephrase (optional)"
                  class="input input-bordered input-sm flex-1"
                  autocomplete="off"
                />
                <button type="submit" class="btn btn-sm btn-outline">Save</button>
              </form>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Vote tally (bottom right) --%>
      <div class="absolute bottom-4 right-4 text-xs text-base-content/40 font-mono">
        <%= map_size(@s.votes) %> / <%= MapSet.size(@decision.connected) %> voted
      </div>
    </div>
    """
  end

  defp candidate_card(assigns) do
    assigns = assign_new(assigns, :placeholder, fn -> nil end)
    ~H"""
    <div class={"card w-60 border-2 bg-base-100 shadow-md transition-all " <>
                 if(@selected, do: "border-primary bg-primary/10", else:
                   if(@is_synthesis, do: "border-dashed border-secondary", else: "border-base-300")) <>
                 if(@spectator or is_nil(@text), do: " cursor-default", else: " cursor-pointer hover:border-primary/60 hover:shadow-lg")}
    >
      <div class="card-body p-4 gap-2">
        <div class="flex items-center justify-between">
          <span class={"badge badge-sm " <> if(@is_synthesis, do: "badge-secondary", else: "badge-ghost")}>
            <%= @label %>
          </span>
          <%= if @voted do %>
            <span class="text-xs text-base-content/40">voted ✓</span>
          <% end %>
        </div>
        <%= if @text do %>
          <p class="text-sm"><%= @text %></p>
          <%= if not @spectator and @text do %>
            <button
              phx-click="vote_scenario"
              phx-value-candidate={@text}
              class={"btn btn-xs mt-1 " <> if(@selected, do: "btn-primary", else: "btn-outline btn-primary")}
            >
              <%= if @selected, do: "Your vote ✓", else: "Vote" %>
            </button>
          <% end %>
        <% else %>
          <p class="text-xs text-base-content/30 italic"><%= @placeholder || "..." %></p>
        <% end %>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Priorities component
  # ---------------------------------------------------------------------------

  defp priorities_stage(assigns) do
    s = assigns.decision.stage
    my_priority = Map.get(s.priorities, assigns.username)
    my_direction = if my_priority, do: my_priority.direction, else: "+"
    my_text = if my_priority, do: my_priority.text, else: ""
    is_confirmed = assigns.username in s.confirmed
    is_ready = assigns.username in s.ready
    all_confirmed = MapSet.subset?(assigns.decision.connected, s.confirmed) and MapSet.size(assigns.decision.connected) > 0
    waiting_count = MapSet.size(assigns.decision.connected) - MapSet.size(s.confirmed)
    other_users = MapSet.to_list(assigns.decision.connected) |> Enum.reject(&(&1 == assigns.username))

    assigns = assign(assigns,
      s: s,
      my_priority: my_priority,
      my_direction: my_direction,
      my_text: my_text,
      is_confirmed: is_confirmed,
      is_ready: is_ready,
      all_confirmed: all_confirmed,
      waiting_count: waiting_count,
      other_users: other_users,
      other_positions: @other_positions
    )

    ~H"""
    <div class="w-screen h-screen overflow-hidden relative select-none">
      <%!-- Sticky header --%>
      <div class="absolute top-0 left-0 right-0 z-10 bg-base-100/80 backdrop-blur border-b border-base-300 px-8 py-4 flex flex-col items-center gap-1">
        <span class="text-xs font-mono text-base-content/40 uppercase tracking-widest">Name your priorities</span>
        <span class="text-lg font-semibold text-base-content"><%= @decision.topic %></span>
        <span class="text-xs text-base-content/40">Name a dimension, not a directional statement - e.g. "cost" not "too expensive"</span>
      </div>

      <%!-- Other participants' priority cards --%>
      <%= for {user, {left, top}} <- Enum.zip(@other_users, Map.get(@other_positions, min(length(@other_users), 3), [])) do %>
        <% p = Map.get(@s.priorities, user) %>
        <div class="absolute" style={"left: #{left}; top: #{top}; transform: translate(-50%, -50%);"}>
          <div class={"card w-52 border-2 bg-base-100 shadow-md " <> if(user in @s.confirmed, do: "border-success", else: "border-base-300")}>
            <div class="card-body p-4 gap-2">
              <div class="flex items-center justify-between">
                <span class="badge badge-ghost badge-sm"><%= user %></span>
                <%= if user in @s.confirmed do %>
                  <span class="text-xs text-success">confirmed ✓</span>
                <% end %>
              </div>
              <%= if p do %>
                <div class="flex items-center gap-2">
                  <span class={direction_color(p.direction) <> " font-mono font-bold text-xl"}><%= p.direction %></span>
                  <span class="text-sm"><%= p.text %></span>
                </div>
              <% else %>
                <p class="text-xs text-base-content/30 italic">thinking...</p>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Claude suggestions (dead center, after all confirmed) --%>
      <%= if @all_confirmed and length(@s.suggestions) > 0 do %>
        <div class="absolute z-20" style="left: 50%; top: 50%; transform: translate(-50%, -50%);">
          <div class="card w-72 border-2 border-dashed border-secondary bg-base-100 shadow-lg">
            <div class="card-body p-4 gap-3">
              <span class="badge badge-secondary badge-sm">Claude - anyone can toggle</span>
              <%= for {suggestion, idx} <- Enum.with_index(@s.suggestions) do %>
                <label class={"flex items-center gap-3 px-3 py-2 rounded-lg border cursor-pointer transition-all select-none " <>
                              if(suggestion.included, do: "border-secondary bg-secondary/10", else: "border-base-300 hover:border-secondary/50")}>
                  <input
                    type="checkbox"
                    class="checkbox checkbox-secondary checkbox-sm"
                    checked={suggestion.included}
                    phx-click="toggle_priority_suggestion"
                    phx-value-idx={idx}
                    phx-value-included={not suggestion.included}
                  />
                  <span class={direction_color(suggestion.direction) <> " font-mono font-bold text-lg w-4"}><%= suggestion.direction %></span>
                  <span class="text-sm flex-1"><%= suggestion.text %></span>
                </label>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Your card (bottom center) --%>
      <div class="absolute" style="left: 50%; top: 82%; transform: translate(-50%, -50%);">
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
              <form phx-change="upsert_priority" phx-submit="upsert_priority" class="flex gap-2 items-center">
                <div class="flex gap-1">
                  <%= for dir <- ["+", "-", "~"] do %>
                    <button
                      type="button"
                      phx-click="upsert_priority"
                      phx-value-direction={dir}
                      phx-value-text={@my_text}
                      class={"btn btn-sm font-mono " <> direction_btn_class(dir, @my_direction)}
                    >
                      <%= dir %>
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
                  <%= if @is_confirmed, do: "Confirmed ✓", else: "Confirm" %>
                </button>
                <button
                  phx-click="ready_priority"
                  disabled={not @is_confirmed or @is_ready}
                  class={"btn btn-sm flex-1 " <> if(@is_ready, do: "btn-primary", else: "btn-outline btn-primary")}
                >
                  <%= if @is_ready, do: "Ready ✓", else: "Ready up" %>
                </button>
              </div>
              <%= if not @all_confirmed and @is_confirmed and @waiting_count > 0 do %>
                <p class="text-xs text-base-content/40 text-center">
                  Waiting for <%= @waiting_count %> <%= if @waiting_count == 1, do: "person", else: "people" %>...
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Vote tally (bottom right) --%>
      <div class="absolute bottom-4 right-4 text-xs text-base-content/40 font-mono">
        <%= MapSet.size(@s.confirmed) %> / <%= MapSet.size(@decision.connected) %> confirmed
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Options component
  # ---------------------------------------------------------------------------

  defp options_stage(assigns) do
    s = assigns.decision.stage
    my_option = Map.get(s.proposals, assigns.username)
    my_name = if my_option, do: my_option.name, else: ""
    my_desc = if my_option, do: my_option.desc, else: ""
    is_confirmed = assigns.username in s.confirmed
    is_ready = assigns.username in s.ready
    all_confirmed = MapSet.subset?(assigns.decision.connected, s.confirmed) and MapSet.size(assigns.decision.connected) > 0
    waiting_count = MapSet.size(assigns.decision.connected) - MapSet.size(s.confirmed)
    other_users = MapSet.to_list(assigns.decision.connected) |> Enum.reject(&(&1 == assigns.username))

    assigns = assign(assigns,
      s: s,
      my_option: my_option,
      my_name: my_name,
      my_desc: my_desc,
      is_confirmed: is_confirmed,
      is_ready: is_ready,
      all_confirmed: all_confirmed,
      waiting_count: waiting_count,
      other_users: other_users,
      other_positions: @other_positions
    )

    ~H"""
    <div class="w-screen h-screen overflow-hidden relative select-none">
      <%!-- Sticky header --%>
      <div class="absolute top-0 left-0 right-0 z-10 bg-base-100/80 backdrop-blur border-b border-base-300 px-8 py-4 flex flex-col items-center gap-1">
        <span class="text-xs font-mono text-base-content/40 uppercase tracking-widest">Propose options</span>
        <span class="text-lg font-semibold text-base-content"><%= @decision.topic %></span>
        <span class="text-xs text-base-content/40">Each person enters one concrete option</span>
      </div>

      <%!-- Other participants' option cards --%>
      <%= for {user, {left, top}} <- Enum.zip(@other_users, Map.get(@other_positions, min(length(@other_users), 3), [])) do %>
        <% opt = Map.get(@s.proposals, user) %>
        <div class="absolute" style={"left: #{left}; top: #{top}; transform: translate(-50%, -50%);"}>
          <div class={"card w-52 border-2 bg-base-100 shadow-md " <> if(user in @s.confirmed, do: "border-success", else: "border-base-300")}>
            <div class="card-body p-4 gap-2">
              <div class="flex items-center justify-between">
                <span class="badge badge-ghost badge-sm"><%= user %></span>
                <%= if user in @s.confirmed do %>
                  <span class="text-xs text-success">confirmed ✓</span>
                <% end %>
              </div>
              <%= if opt do %>
                <p class="font-semibold text-sm"><%= opt.name %></p>
                <p class="text-xs text-base-content/60"><%= opt.desc %></p>
              <% else %>
                <p class="text-xs text-base-content/30 italic">thinking...</p>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Claude suggestions (dead center, after all confirmed) --%>
      <%= if @all_confirmed and length(@s.suggestions) > 0 do %>
        <div class="absolute z-20" style="left: 50%; top: 50%; transform: translate(-50%, -50%);">
          <div class="card w-80 border-2 border-dashed border-secondary bg-base-100 shadow-lg">
            <div class="card-body p-4 gap-3">
              <span class="badge badge-secondary badge-sm">Claude - anyone can toggle</span>
              <%= for {suggestion, idx} <- Enum.with_index(@s.suggestions) do %>
                <label class={"flex items-start gap-3 px-3 py-2 rounded-lg border cursor-pointer transition-all select-none " <>
                              if(suggestion.included, do: "border-secondary bg-secondary/10", else: "border-base-300 hover:border-secondary/50")}>
                  <input
                    type="checkbox"
                    class="checkbox checkbox-secondary checkbox-sm mt-0.5"
                    checked={suggestion.included}
                    phx-click="toggle_option_suggestion"
                    phx-value-idx={idx}
                    phx-value-included={not suggestion.included}
                  />
                  <div class="flex flex-col gap-0.5">
                    <span class="text-sm font-semibold"><%= suggestion.name %></span>
                    <span class="text-xs text-base-content/60"><%= suggestion.desc %></span>
                  </div>
                </label>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Your card (bottom center) --%>
      <div class="absolute" style="left: 50%; top: 82%; transform: translate(-50%, -50%);">
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
              <form phx-change="upsert_option" phx-submit="upsert_option" class="flex flex-col gap-2">
                <input
                  type="text"
                  name="name"
                  value={@my_name}
                  placeholder="Short name (2-4 words)"
                  class="input input-bordered input-sm"
                  autocomplete="off"
                />
                <input
                  type="text"
                  name="desc"
                  value={@my_desc}
                  placeholder="One sentence description"
                  class="input input-bordered input-sm"
                  autocomplete="off"
                />
              </form>
              <div class="flex gap-2">
                <button
                  phx-click="confirm_option"
                  disabled={@my_name == "" or @is_ready}
                  class={"btn btn-sm flex-1 " <> if(@is_confirmed, do: "btn-success", else: "btn-outline btn-success")}
                >
                  <%= if @is_confirmed, do: "Confirmed ✓", else: "Confirm" %>
                </button>
                <button
                  phx-click="ready_options"
                  disabled={not @is_confirmed or @is_ready}
                  class={"btn btn-sm flex-1 " <> if(@is_ready, do: "btn-primary", else: "btn-outline btn-primary")}
                >
                  <%= if @is_ready, do: "Ready ✓", else: "Ready up" %>
                </button>
              </div>
              <%= if not @all_confirmed and @is_confirmed and @waiting_count > 0 do %>
                <p class="text-xs text-base-content/40 text-center">
                  Waiting for <%= @waiting_count %> <%= if @waiting_count == 1, do: "person", else: "people" %>...
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Tally (bottom right) --%>
      <div class="absolute bottom-4 right-4 text-xs text-base-content/40 font-mono">
        <%= MapSet.size(@s.confirmed) %> / <%= MapSet.size(@decision.connected) %> confirmed
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Scaffolding component
  # ---------------------------------------------------------------------------

  defp scaffolding_stage(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col items-center justify-center gap-6">
      <div class="loading loading-spinner loading-lg text-primary"></div>
      <p class="text-xl font-semibold text-base-content/70">
        Spelunking...
      </p>
      <p class="text-sm text-base-content/40">Claude is analysing your options against priorities</p>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Dashboard component
  # ---------------------------------------------------------------------------

  defp dashboard_stage(assigns) do
    s = assigns.decision.stage
    my_votes = Map.get(s.votes, assigns.username, [])
    is_ready = assigns.username in s.ready
    vote_counts = count_votes_ui(s)
    sorted_by_votes = Enum.sort_by(s.options, &(-Map.get(vote_counts, &1.name, 0)))
    participants = MapSet.to_list(assigns.decision.connected)

    assigns = assign(assigns,
      s: s,
      my_votes: my_votes,
      is_ready: is_ready,
      vote_counts: vote_counts,
      sorted_by_votes: sorted_by_votes,
      participants: participants,
      priorities: assigns.decision.priorities
    )

    ~H"""
    <div class="min-h-screen flex flex-col p-6 gap-6 max-w-6xl mx-auto">
      <%!-- Scenario + priorities header --%>
      <div class="flex flex-col gap-2">
        <p class="text-xs text-base-content/40 uppercase tracking-wide">Scenario</p>
        <p class="text-lg font-semibold"><%= @decision.topic %></p>
      </div>

      <%= if length(@priorities) > 0 do %>
        <div class="flex flex-wrap gap-2">
          <%= for p <- @priorities do %>
            <span class={"badge badge-outline font-mono " <> priority_badge_class(p.direction)}>
              <%= p.id %> <%= p.text %>
            </span>
          <% end %>
        </div>
      <% end %>

      <div class="divider my-0"></div>

      <%!-- Main content: ranking sidebar + options cards --%>
      <div class="flex gap-6">
        <%!-- Left sidebar: live ranking --%>
        <div class="w-40 flex-shrink-0 flex flex-col gap-2">
          <p class="text-xs text-base-content/40 uppercase tracking-wide">Ranking</p>
          <%= for {opt, rank} <- Enum.with_index(@sorted_by_votes, 1) do %>
            <div class="flex items-center gap-2">
              <span class="text-xs text-base-content/40 w-4"><%= rank %>.</span>
              <span class="text-xs font-mono truncate flex-1"><%= opt.name %></span>
              <span class="badge badge-sm"><%= Map.get(@vote_counts, opt.name, 0) %></span>
            </div>
          <% end %>
        </div>

        <%!-- Option cards --%>
        <div class="flex gap-4 overflow-x-auto pb-2 flex-1">
          <%= for opt <- @s.options do %>
            <% votes_for = Map.get(@vote_counts, opt.name, 0) %>
            <div class={"card w-72 flex-shrink-0 border-2 " <>
                        if(opt.name in @my_votes, do: "border-primary bg-primary/5", else: "border-base-300 bg-base-100")}>
              <div class="card-body p-4 gap-3">
                <%!-- Header --%>
                <div class="flex items-start justify-between gap-2">
                  <div>
                    <h3 class="font-bold text-sm"><%= opt.name %></h3>
                    <p class="text-xs text-base-content/60"><%= opt.desc %></p>
                  </div>
                  <span class="badge badge-sm flex-shrink-0"><%= votes_for %> votes</span>
                </div>

                <%!-- For points --%>
                <%= if length(opt.for) > 0 do %>
                  <div class="flex flex-col gap-1">
                    <p class="text-xs font-semibold text-success">For</p>
                    <%= for point <- opt.for do %>
                      <div class="flex gap-1 items-start">
                        <span class="badge badge-xs badge-outline text-success border-success font-mono flex-shrink-0 mt-0.5">
                          <%= point.priority_id %>
                        </span>
                        <p class="text-xs text-base-content/70"><%= point.text %></p>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%!-- Against points --%>
                <%= if length(opt.against) > 0 do %>
                  <div class="flex flex-col gap-1">
                    <p class="text-xs font-semibold text-error">Against</p>
                    <%= for point <- opt.against do %>
                      <div class="flex gap-1 items-start">
                        <span class="badge badge-xs badge-outline text-error border-error font-mono flex-shrink-0 mt-0.5">
                          <%= point.priority_id %>
                        </span>
                        <p class="text-xs text-base-content/70"><%= point.text %></p>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%!-- Participant vote checkboxes --%>
                <div class="flex flex-wrap gap-1 mt-auto pt-2 border-t border-base-200">
                  <%= for user <- @participants do %>
                    <% user_voted = opt.name in Map.get(@s.votes, user, []) %>
                    <button
                      phx-click={if user == @username, do: "toggle_vote", else: nil}
                      phx-value-option={opt.name}
                      class={"flex items-center gap-1 px-2 py-1 rounded text-xs font-mono transition-all " <>
                             if(user_voted, do: "bg-primary/20 text-primary", else: "bg-base-200 text-base-content/40") <>
                             if(user == @username, do: " cursor-pointer hover:bg-primary/30", else: " cursor-default")}
                    >
                      <%= if user_voted do %>
                        <span>✓</span>
                      <% end %>
                      <%= user %>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Ready button --%>
      <%= if not @spectator do %>
        <div class="flex justify-end">
          <button
            phx-click="ready_dashboard"
            disabled={@my_votes == [] or @is_ready}
            class={"btn btn-primary " <> if(@is_ready, do: "btn-disabled", else: "")}
          >
            <%= if @is_ready, do: "Ready ✓", else: "Ready up" %>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Complete component
  # ---------------------------------------------------------------------------

  defp complete_stage(assigns) do
    s = assigns.decision.stage
    assigns = assign(assigns, s: s, priorities: assigns.decision.priorities)

    ~H"""
    <div class="min-h-screen flex flex-col p-8 gap-8 max-w-3xl mx-auto">
      <%!-- Why statement --%>
      <div class="card bg-primary/10 border-2 border-primary/30">
        <div class="card-body gap-3">
          <div class="flex items-center gap-2">
            <span class="badge badge-primary">Decision</span>
            <h2 class="font-bold text-lg"><%= @s.winner %></h2>
          </div>
          <%= if @s.why_statement do %>
            <p class="text-base-content/80 leading-relaxed"><%= @s.why_statement %></p>
          <% else %>
            <div class="flex items-center gap-2 text-base-content/40">
              <span class="loading loading-dots loading-sm"></span>
              <span class="text-sm">Generating summary...</span>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Scenario --%>
      <div>
        <p class="text-xs text-base-content/40 uppercase tracking-wide mb-1">Scenario</p>
        <p class="font-semibold"><%= @decision.topic %></p>
      </div>

      <%!-- Priorities --%>
      <%= if length(@priorities) > 0 do %>
        <div>
          <p class="text-xs text-base-content/40 uppercase tracking-wide mb-2">Priorities</p>
          <div class="flex flex-wrap gap-2">
            <%= for p <- @priorities do %>
              <span class={"badge badge-outline font-mono " <> priority_badge_class(p.direction)}>
                <%= p.id %> <%= p.text %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>

      <%!-- Options sorted by vote count --%>
      <div class="flex flex-col gap-4">
        <p class="text-xs text-base-content/40 uppercase tracking-wide">Options</p>
        <%= for {opt, idx} <- Enum.with_index(@s.options) do %>
          <div class={"card border-2 " <> if(idx == 0, do: "border-primary bg-primary/5", else: "border-base-300 bg-base-100")}>
            <div class="card-body p-4 gap-3">
              <div class="flex items-center gap-2">
                <%= if idx == 0 do %>
                  <span class="badge badge-primary badge-sm">Winner</span>
                <% end %>
                <h3 class="font-bold"><%= opt.name %></h3>
                <span class="text-xs text-base-content/50 ml-auto"><%= opt.desc %></span>
              </div>

              <div class="grid grid-cols-2 gap-3">
                <div class="flex flex-col gap-1">
                  <p class="text-xs font-semibold text-success">For</p>
                  <%= for point <- opt.for do %>
                    <div class="flex gap-1 items-start">
                      <span class="badge badge-xs badge-outline text-success border-success font-mono flex-shrink-0 mt-0.5">
                        <%= point.priority_id %>
                      </span>
                      <p class="text-xs text-base-content/70"><%= point.text %></p>
                    </div>
                  <% end %>
                </div>
                <div class="flex flex-col gap-1">
                  <p class="text-xs font-semibold text-error">Against</p>
                  <%= for point <- opt.against do %>
                    <div class="flex gap-1 items-start">
                      <span class="badge badge-xs badge-outline text-error border-error font-mono flex-shrink-0 mt-0.5">
                        <%= point.priority_id %>
                      </span>
                      <p class="text-xs text-base-content/70"><%= point.text %></p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <div class="text-center">
        <a href="/canvas" class="btn btn-ghost btn-sm">Back to canvas</a>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Stage modals
  # ---------------------------------------------------------------------------

  defp stage_modal(%{stage: %Stage.Lobby{}} = assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Lobby</h3>
      <p>Set the decision topic and invite participants. Everyone must ready up before the creator can start.</p>
      <p class="text-sm text-base-content/60">Once started you'll frame the scenario together.</p>
    </.modal_overlay>
    """
  end

  defp stage_modal(%{stage: %Stage.Scenario{}} = assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Frame the Scenario</h3>
      <p>Everyone votes on the framing of the decision. You must all agree on the same framing to proceed.</p>
      <ul class="list-disc list-inside text-sm text-base-content/70 gap-1 flex flex-col">
        <li>The creator's topic is pre-filled as the default candidate</li>
        <li>Anyone can optionally submit a rephrase</li>
        <li>If there are multiple submissions, Claude synthesizes a bridge candidate</li>
        <li>Click a card to vote. All votes must match to advance.</li>
      </ul>
    </.modal_overlay>
    """
  end

  defp stage_modal(%{stage: %Stage.Priorities{}} = assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Name Your Priorities</h3>
      <p>Each person enters one priority - a dimension that matters for this decision.</p>
      <ul class="list-disc list-inside text-sm text-base-content/70 gap-1 flex flex-col">
        <li><span class="font-mono font-bold text-success">+</span> maximize - e.g. "speed", "simplicity"</li>
        <li><span class="font-mono font-bold text-error">-</span> minimize - e.g. "cost", "risk"</li>
        <li><span class="font-mono font-bold text-base-content/50">~</span> relevant but not deciding - e.g. "team familiarity"</li>
      </ul>
      <p class="text-sm text-base-content/60">Name the dimension, not a directional statement. "cost" not "too expensive".</p>
      <p class="text-sm text-base-content/60">Hit Confirm when done. Claude suggests extras once everyone confirms. Ready up when satisfied.</p>
    </.modal_overlay>
    """
  end

  defp stage_modal(%{stage: %Stage.Options{}} = assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Propose Options</h3>
      <p>Each person enters one option - a concrete choice the group could make.</p>
      <ul class="list-disc list-inside text-sm text-base-content/70 gap-1 flex flex-col">
        <li>Give it a short name (2-4 words)</li>
        <li>Add a one-sentence description</li>
        <li>Edit freely - hit Confirm when done</li>
      </ul>
      <p class="text-sm text-base-content/60">Claude suggests extras once everyone confirms. Toggle them in or out. Ready up when satisfied.</p>
    </.modal_overlay>
    """
  end

  defp stage_modal(%{stage: %Stage.Dashboard{}} = assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Vote</h3>
      <p>Read each option's for/against analysis, then check every option you'd be happy with.</p>
      <ul class="list-disc list-inside text-sm text-base-content/70 gap-1 flex flex-col">
        <li>Approval voting - select as many as you'd accept</li>
        <li>You must select at least one to ready up</li>
        <li>Other participants' votes appear live on each card</li>
        <li>Ranking on the left updates as people vote</li>
      </ul>
    </.modal_overlay>
    """
  end

  defp stage_modal(%{stage: %Stage.Complete{}} = assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Decision Record</h3>
      <p>The decision is complete. This is the full record - shareable and self-documenting.</p>
      <p class="text-sm text-base-content/60">The why-statement at the top summarises the winner and the reasoning.</p>
    </.modal_overlay>
    """
  end

  defp stage_modal(assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Stage instructions</h3>
      <p>Follow the on-screen prompts.</p>
    </.modal_overlay>
    """
  end

  defp modal_overlay(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black/40 z-20 flex items-center justify-center" phx-click="close_modal">
      <div class="bg-base-100 rounded-2xl shadow-2xl p-8 max-w-md w-full mx-4 flex flex-col gap-4"
           phx-click-away="close_modal">
        <div class="flex justify-between items-start">
          <div class="flex flex-col gap-4">
            <%= render_slot(@inner_block) %>
          </div>
          <button phx-click="close_modal" class="btn btn-sm btn-circle btn-ghost ml-4">✕</button>
        </div>
        <p class="text-xs text-base-content/40 text-right">Press Escape or click outside to close</p>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp creator_of(decision), do: decision.creator

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
  end

  defp direction_color("+"), do: "text-success"
  defp direction_color("-"), do: "text-error"
  defp direction_color(_), do: "text-base-content/50"

  defp direction_btn_class(dir, dir), do: "btn-primary"
  defp direction_btn_class(_, _), do: "btn-ghost"

  defp priority_badge_class("+"), do: "text-success border-success"
  defp priority_badge_class("-"), do: "text-error border-error"
  defp priority_badge_class(_), do: "text-base-content/50"

  defp count_votes_ui(%Stage.Dashboard{votes: votes, options: options}) do
    base = Map.new(options, &{&1.name, 0})
    Enum.reduce(votes, base, fn {_user, selected}, acc ->
      Enum.reduce(selected, acc, fn name, acc2 ->
        Map.update(acc2, name, 1, &(&1 + 1))
      end)
    end)
  end
end
