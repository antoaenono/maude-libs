defmodule MaudeLibsWeb.DecisionLive do
  use MaudeLibsWeb, :live_view
  require Logger

  alias MaudeLibs.Decision.{Server, Supervisor, Stage}

  import MaudeLibsWeb.DecisionLive.DecisionComponents
  import MaudeLibsWeb.DecisionLive.LobbyStage
  import MaudeLibsWeb.DecisionLive.ScenarioStage
  import MaudeLibsWeb.DecisionLive.PrioritiesStage
  import MaudeLibsWeb.DecisionLive.OptionsStage
  import MaudeLibsWeb.DecisionLive.ScaffoldingStage
  import MaudeLibsWeb.DecisionLive.DashboardStage
  import MaudeLibsWeb.DecisionLive.CompleteStage

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
        _decision = Server.get_state(id)
        {:ok, push_navigate(socket, to: "/d/#{id}", replace: true)}
      else
        {:ok,
         assign(socket,
           username: username,
           decision: nil,
           id: nil,
           modal_open: false,
           spectator: false
         )}
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

          is_invited =
            match?(%Stage.Lobby{}, decision.stage) and username in decision.stage.invited

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

          {:ok,
           assign(socket,
             username: username,
             decision: decision,
             id: id,
             modal_open: true,
             spectator: not is_participant
           )}
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
    invited =
      invite_raw |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    Server.handle_message(
      socket.assigns.id,
      {:lobby_update, socket.assigns.username, topic, invited}
    )

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

    Server.handle_message(
      socket.assigns.id,
      {:upsert_priority, socket.assigns.username, priority}
    )

    {:noreply, socket}
  end

  def handle_event("confirm_priority", _params, socket) do
    Server.handle_message(socket.assigns.id, {:confirm_priority, socket.assigns.username})
    {:noreply, socket}
  end

  def handle_event("toggle_priority_suggestion", %{"idx" => idx}, socket) do
    s = socket.assigns.decision.stage
    idx_int = String.to_integer(idx)
    current = Enum.at(s.suggestions, idx_int)

    if current do
      Server.handle_message(
        socket.assigns.id,
        {:toggle_priority_suggestion, idx_int, not current.included}
      )
    end

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

  def handle_event("toggle_option_suggestion", %{"idx" => idx}, socket) do
    s = socket.assigns.decision.stage
    idx_int = String.to_integer(idx)
    current = Enum.at(s.suggestions, idx_int)

    if current do
      Server.handle_message(
        socket.assigns.id,
        {:toggle_option_suggestion, idx_int, not current.included}
      )
    end

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

    Server.handle_message(socket.assigns.id, {:vote, socket.assigns.username, new_votes})
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
    <%!-- ? button always visible (fixed, above stage_shell) --%>
    <button
      phx-click="open_modal"
      class="fixed top-4 right-4 btn btn-circle btn-sm btn-ghost z-30 text-base-content/50 hover:text-base-content"
    >
      ?
    </button>
    <%!-- Stage modal --%>
    <%= if @modal_open do %>
      <.stage_modal stage={@decision.stage} is_creator={creator_of(@decision) == @username} />
    <% end %>
    <%!-- Route to correct stage component (each renders its own stage_shell with breadcrumbs) --%>
    {render_stage(assigns)}
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
    <.scaffolding_stage decision={@decision} />
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
  # Stage modals
  # ---------------------------------------------------------------------------

  defp stage_modal(%{stage: %Stage.Lobby{}} = assigns) do
    ~H"<.lobby_modal {assigns} />"
  end

  defp stage_modal(%{stage: %Stage.Scenario{}} = assigns) do
    ~H"<.scenario_modal {assigns} />"
  end

  defp stage_modal(%{stage: %Stage.Priorities{}} = assigns) do
    ~H"<.priorities_modal {assigns} />"
  end

  defp stage_modal(%{stage: %Stage.Options{}} = assigns) do
    ~H"<.options_modal {assigns} />"
  end

  defp stage_modal(%{stage: %Stage.Dashboard{}} = assigns) do
    ~H"<.dashboard_modal {assigns} />"
  end

  defp stage_modal(%{stage: %Stage.Complete{}} = assigns) do
    ~H"<.complete_modal {assigns} />"
  end

  defp stage_modal(assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Stage instructions</h3>

      <p>Follow the on-screen prompts.</p>
    </.modal_overlay>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp creator_of(decision), do: decision.creator

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
  end
end
