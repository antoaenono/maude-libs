defmodule MaudeLibsWeb.DecisionLiveTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

  # ---------------------------------------------------------------------------
  # Mount & Session
  # ---------------------------------------------------------------------------

  describe "mount" do
    @tag stage: :mount
    test "redirects to /join when no session username" do
      conn = build_conn()
      {:error, {:live_redirect, %{to: "/join"}}} = live(conn, "/d/new")
    end

    @tag stage: :mount
    test "redirects to /join for existing decision without session" do
      decision = seed_decision(:lobby, ["alice"])
      {:error, {:live_redirect, %{to: "/join"}}} = live(build_conn(), "/d/#{decision.id}")
    end

    @tag stage: :mount
    test "redirects to /canvas when decision ID not found" do
      conn = build_conn() |> init_test_session(%{"username" => "alice"})
      {:error, {:live_redirect, %{to: "/canvas"}}} = live(conn, "/d/nonexistent-id")
    end

    @tag stage: :mount
    test "mounts successfully with valid session and existing decision" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, html} = mount_as("alice", decision.id)
      assert html =~ "New Decision"
      assert has_element?(view, "button", "Ready up")
    end

    @tag stage: :mount
    test "spectator mode when user not invited" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, html} = mount_as("charlie", decision.id)
      assert html =~ "Spectating"
      refute has_element?(view, "button", "Ready up")
    end

    @tag stage: :mount
    test "invited user auto-joins on mount" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      # bob is invited but mount_as triggers auto-join
      {:ok, _view, _html} = mount_as("bob", decision.id)

      state = Server.get_state(decision.id)
      assert "bob" in state.connected
    end

    @tag stage: :mount
    test "participant not in connected reconnects via participants path" do
      # Bob is a participant but NOT currently connected
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        participants: MapSet.new(["alice", "bob"]),
        stage: %MaudeLibs.Decision.Stage.Scenario{submissions: %{}}
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)

      {:ok, _view, _html} = mount_as("bob", id)
      assert "bob" in Server.get_state(id).connected
    end

    @tag stage: :mount
    test "invited user not in connected or participants joins via invite path" do
      # Bob is invited but not connected and not a participant
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        participants: MapSet.new(["alice"]),
        stage: %MaudeLibs.Decision.Stage.Lobby{
          invited: MapSet.new(["alice", "bob"]),
          joined: MapSet.new(["alice"]),
          ready: MapSet.new()
        }
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)

      {:ok, _view, _html} = mount_as("bob", id)
      assert "bob" in Server.get_state(id).connected
    end

    @tag stage: :mount
    test "new decision creates and redirects" do
      conn = build_conn() |> init_test_session(%{"username" => "alice"})
      # /d/new redirects to /d/<id> once connected
      {:error, {:live_redirect, %{to: "/d/" <> _id}}} = live(conn, "/d/new")
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-stage: connect/disconnect
  # ---------------------------------------------------------------------------

  describe "connect/disconnect" do
    @tag stage: :connectivity
    test "disconnect removes user from connected set" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, _view, _} = mount_as("bob", decision.id)

      state = Server.get_state(decision.id)
      assert "bob" in state.connected

      Server.handle_message(decision.id, {:disconnect, "bob"})

      state = Server.get_state(decision.id)
      refute "bob" in state.connected
    end

    @tag stage: :connectivity
    test "connected user reconnects on re-mount" do
      # Bob is in the connected set from seeding
      decision = seed_decision(:scenario, ["alice", "bob"])
      assert "bob" in Server.get_state(decision.id).connected

      # When bob mounts, the cond matches "username in decision.connected"
      # and sends {:connect, username}, keeping bob connected
      {:ok, _view, _html} = mount_as("bob", decision.id)
      assert "bob" in Server.get_state(decision.id).connected
    end
  end

  # ---------------------------------------------------------------------------
  # Modal events
  # ---------------------------------------------------------------------------

  describe "modals" do
    test "open_modal and close_modal toggle modal visibility" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, html} = mount_as("alice", decision.id)
      refute html =~ "Press Escape"

      # Open modal
      view |> element("button", "?") |> render_click()
      html = render(view)
      assert html =~ "Press Escape"

      # Close modal via close_modal event
      view |> element("button", "✕") |> render_click()
      html = render(view)
      refute html =~ "Press Escape"
    end

    test "modal renders for scenario stage" do
      decision = seed_decision(:scenario, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)
      view |> element("button", "?") |> render_click()
      assert render(view) =~ "Press Escape"
    end

    test "modal renders for priorities stage" do
      decision = seed_decision(:priorities, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)
      view |> element("button", "?") |> render_click()
      assert render(view) =~ "Press Escape"
    end

    test "modal renders for options stage" do
      decision = seed_decision(:options, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)
      view |> element("button", "?") |> render_click()
      assert render(view) =~ "Press Escape"
    end

    test "modal renders for dashboard stage" do
      decision = seed_decision(:dashboard, ["alice"], votes: %{"alice" => ["Tacos"]})
      {:ok, view, _html} = mount_as("alice", decision.id)
      view |> element("button", "?") |> render_click()
      assert render(view) =~ "Press Escape"
    end

    test "modal renders for complete stage" do
      decision = seed_decision(:complete, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)
      view |> element("button", "?") |> render_click()
      assert render(view) =~ "Press Escape"
    end

    test "modal renders fallback for scaffolding stage" do
      decision = seed_decision(:scaffolding, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)
      view |> element("button", "?") |> render_click()
      html = render(view)
      assert html =~ "Stage instructions"
      assert html =~ "Follow the on-screen prompts"
    end
  end

  # ---------------------------------------------------------------------------
  # Lobby events (covering add_invite, remove_invite, lobby_join)
  # ---------------------------------------------------------------------------

  describe "lobby events" do
    test "add_invite adds a user to the invited list" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("add_invite", %{"username" => "bob"})

      state = Server.get_state(decision.id)
      assert "bob" in state.stage.invited
    end

    test "add_invite with blank username is a no-op" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("add_invite", %{"username" => "  "})

      state = Server.get_state(decision.id)
      assert MapSet.size(state.stage.invited) == 1
    end

    test "remove_invite removes a user from invited list" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("remove_invite", %{"user" => "bob"})

      state = Server.get_state(decision.id)
      refute "bob" in state.stage.invited
    end

    @tag capture_log: true
    test "lobby_join sends join message" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, _html} = mount_as("bob", decision.id)

      view |> render_hook("lobby_join", %{})

      state = Server.get_state(decision.id)
      assert "bob" in state.stage.joined
    end
  end

  # ---------------------------------------------------------------------------
  # Priorities events
  # ---------------------------------------------------------------------------

  describe "priorities events" do
    test "confirm_priority with params upserts then confirms" do
      decision = seed_decision(:priorities, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view
      |> render_hook("confirm_priority", %{"text" => "speed", "direction" => "+"})

      state = Server.get_state(decision.id)
      assert state.stage.priorities["alice"].text == "speed"
      assert "alice" in state.stage.confirmed
    end

    test "confirm_priority without params confirms current entry" do
      decision =
        seed_decision(:priorities, ["alice"],
          priorities: %{"alice" => %{text: "cost", direction: "-"}}
        )

      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("confirm_priority", %{})

      state = Server.get_state(decision.id)
      assert "alice" in state.stage.confirmed
    end

    test "toggle_priority_suggestion toggles included flag" do
      decision =
        seed_decision(:priorities, ["alice"],
          suggestions: [%{text: "reliability", direction: "+", included: false}]
        )

      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("toggle_priority_suggestion", %{"idx" => "0"})

      state = Server.get_state(decision.id)
      assert Enum.at(state.stage.suggestions, 0).included == true
    end

    test "ready_priority event handler sends server message" do
      # Seed at priorities with alice having a priority and being confirmed
      decision =
        seed_decision(:priorities, ["alice", "bob"],
          priorities: %{
            "alice" => %{text: "speed", direction: "+"},
            "bob" => %{text: "cost", direction: "-"}
          },
          confirmed: ["alice", "bob"]
        )

      {:ok, _alice_view, _} = mount_as("alice", decision.id)
      {:ok, _bob_view, _} = mount_as("bob", decision.id)

      # Use server directly since the button interaction is already tested in priorities_test
      Server.handle_message(decision.id, {:ready_priority, "alice"})
      Server.handle_message(decision.id, {:ready_priority, "bob"})

      state = Server.get_state(decision.id)
      # Both ready -> transitions to Options
      assert %MaudeLibs.Decision.Stage.Options{} = state.stage
    end

    test "ready_priority via LiveView event handler" do
      # Use two users so ready doesn't immediately transition to Options
      decision =
        seed_decision(:priorities, ["alice", "bob"],
          priorities: %{
            "alice" => %{text: "speed", direction: "+"},
            "bob" => %{text: "cost", direction: "-"}
          },
          confirmed: ["alice", "bob"]
        )

      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("ready_priority", %{})

      state = Server.get_state(decision.id)
      assert "alice" in state.stage.ready
    end
  end

  # ---------------------------------------------------------------------------
  # Options events
  # ---------------------------------------------------------------------------

  describe "options events" do
    test "upsert_option stores option" do
      decision = seed_decision(:options, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("upsert_option", %{"name" => "Tacos", "desc" => "Mexican"})

      state = Server.get_state(decision.id)
      assert state.stage.proposals["alice"].name == "Tacos"
    end

    test "confirm_option with params upserts then confirms" do
      decision = seed_decision(:options, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("confirm_option", %{"name" => "Pizza", "desc" => "Italian"})

      state = Server.get_state(decision.id)
      assert state.stage.proposals["alice"].name == "Pizza"
      assert "alice" in state.stage.confirmed
    end

    test "confirm_option without params confirms current entry" do
      decision =
        seed_decision(:options, ["alice"],
          proposals: %{"alice" => %{name: "Sushi", desc: "Japanese"}}
        )

      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("confirm_option", %{})

      state = Server.get_state(decision.id)
      assert "alice" in state.stage.confirmed
    end

    test "toggle_option_suggestion toggles included flag" do
      decision =
        seed_decision(:options, ["alice"], suggestions: [%{name: "Burgers", included: false}])

      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("toggle_option_suggestion", %{"idx" => "0"})

      state = Server.get_state(decision.id)
      assert Enum.at(state.stage.suggestions, 0).included == true
    end

    test "ready_options transitions to scaffolding" do
      decision =
        seed_decision(:options, ["alice"],
          proposals: %{"alice" => %{name: "Tacos", desc: ""}},
          confirmed: ["alice"]
        )

      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> element("button[phx-click=\"ready_options\"]") |> render_click()

      # The transition goes through Scaffolding (async LLM call)
      state = Server.get_state(decision.id)

      assert state.stage.__struct__ in [
               MaudeLibs.Decision.Stage.Scaffolding,
               MaudeLibs.Decision.Stage.Dashboard
             ]
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard events
  # ---------------------------------------------------------------------------

  describe "dashboard events" do
    test "toggle_vote adds a vote" do
      decision = seed_decision(:dashboard, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("toggle_vote", %{"option" => "Tacos"})

      state = Server.get_state(decision.id)
      assert "Tacos" in Map.get(state.stage.votes, "alice", [])
    end

    test "toggle_vote removes an existing vote" do
      decision = seed_decision(:dashboard, ["alice"], votes: %{"alice" => ["Tacos"]})
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("toggle_vote", %{"option" => "Tacos"})

      state = Server.get_state(decision.id)
      refute "Tacos" in Map.get(state.stage.votes, "alice", [])
    end

    test "ready_dashboard advances to complete" do
      decision = seed_decision(:dashboard, ["alice"], votes: %{"alice" => ["Tacos"]})
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> render_hook("ready_dashboard", %{})

      state = Server.get_state(decision.id)
      assert %MaudeLibs.Decision.Stage.Complete{} = state.stage
    end
  end

  # ---------------------------------------------------------------------------
  # Scaffolding events
  # ---------------------------------------------------------------------------

  describe "scaffolding events" do
    test "retry_scaffold clears error and retries" do
      decision =
        seed_decision(:scaffolding, ["alice"],
          llm_error: true,
          scaffold_topic: "dinner",
          scaffold_priorities: [%{id: "+1", text: "speed", direction: "+"}],
          scaffold_options: [%{name: "Tacos", desc: ""}]
        )

      {:ok, view, _html} = mount_as("alice", decision.id)

      # Verify error state is shown before retry
      html = render(view)
      assert html =~ "failed" or html =~ "Retry"

      view |> element("button", "Retry") |> render_click()

      # After retry, should have moved past the error state
      # (either cleared error in Scaffolding or advanced to Dashboard)
      state = Server.get_state(decision.id)

      case state.stage do
        %MaudeLibs.Decision.Stage.Scaffolding{} -> refute state.stage.llm_error
        %MaudeLibs.Decision.Stage.Dashboard{} -> assert true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub: llm_error
  # ---------------------------------------------------------------------------

  describe "llm_error broadcast" do
    test "llm_error puts error flash on socket" do
      decision = seed_decision(:scenario, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      send(view.pid, {:llm_error, :api_down})

      html = render(view)
      assert html =~ "Internal error"
    end

    test "llm_error shows detailed message when show_errors is true" do
      prev = Application.get_env(:maude_libs, :show_errors)
      Application.put_env(:maude_libs, :show_errors, true)
      on_exit(fn -> Application.put_env(:maude_libs, :show_errors, prev || false) end)

      decision = seed_decision(:scenario, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      send(view.pid, {:llm_error, :api_down})

      html = render(view)
      assert html =~ "LLM call failed"
    end
  end

  # ---------------------------------------------------------------------------
  # Render dispatch (each stage renders its component)
  # ---------------------------------------------------------------------------

  describe "render_stage dispatch" do
    test "renders lobby stage component" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "New Decision"
    end

    test "renders scenario stage component" do
      decision = seed_decision(:scenario, ["alice"])
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Frame the scenario"
    end

    test "renders priorities stage component" do
      decision = seed_decision(:priorities, ["alice"])
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "direction"
    end

    test "renders options stage component" do
      decision = seed_decision(:options, ["alice"])
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "option"
    end

    test "renders scaffolding stage component" do
      decision = seed_decision(:scaffolding, ["alice"])
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Spelunking"
    end

    test "renders dashboard stage component" do
      decision = seed_decision(:dashboard, ["alice"], votes: %{"alice" => ["Tacos"]})
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Tacos"
    end

    test "renders complete stage component" do
      decision = seed_decision(:complete, ["alice"], winner: "Tacos")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Tacos"
    end
  end

  # ---------------------------------------------------------------------------
  # Template-level coverage: specific component branches
  # ---------------------------------------------------------------------------

  describe "template branches" do
    test "scenario stage renders synthesis candidate card" do
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        stage: %MaudeLibs.Decision.Stage.Scenario{
          submissions: %{"alice" => "dinner?"},
          synthesis: "Where should we eat tonight?",
          synthesizing: false,
          votes: %{}
        }
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)
      {:ok, _view, html} = mount_as("alice", id)
      assert html =~ "Where should we eat tonight?"
      assert html =~ "Claude"
    end

    test "lobby stage renders ghost invited users for non-creator" do
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice", "bob"]),
        participants: MapSet.new(["alice", "bob"]),
        stage: %MaudeLibs.Decision.Stage.Lobby{
          invited: MapSet.new(["alice", "bob", "charlie"]),
          joined: MapSet.new(["alice", "bob"]),
          ready: MapSet.new()
        }
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)
      # Mount as bob (non-creator) so we get the non-creator sidebar
      {:ok, _view, html} = mount_as("bob", id)
      assert html =~ "charlie"
      assert html =~ "(invited)"
    end

    test "priorities stage renders suggesting mini_dots" do
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        stage: %MaudeLibs.Decision.Stage.Priorities{
          priorities: %{"alice" => %{text: "cost", direction: "-"}},
          confirmed: MapSet.new(["alice"]),
          suggesting: true,
          suggestions: [%{text: "freshness", direction: "+", included: false}]
        }
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)
      {:ok, _view, html} = mount_as("alice", id)
      assert html =~ "animate-bounce"
      assert html =~ "Claude"
    end

    test "options stage renders suggesting mini_dots" do
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        priorities: [%{id: "+1", text: "speed", direction: "+"}],
        stage: %MaudeLibs.Decision.Stage.Options{
          proposals: %{"alice" => %{name: "tacos", desc: "quick"}},
          confirmed: MapSet.new(["alice"]),
          suggesting: true,
          suggestions: [%{name: "Burgers", included: false}]
        }
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)
      {:ok, _view, html} = mount_as("alice", id)
      assert html =~ "animate-bounce"
      assert html =~ "Claude"
    end

    test "priorities renders tilde direction badge" do
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        priorities: [%{id: "~1", text: "variety", direction: "~"}],
        stage: %MaudeLibs.Decision.Stage.Dashboard{
          options: [
            %{
              name: "Tacos",
              desc: "Mexican",
              for: [%{text: "Good", priority_id: "~1"}],
              against: []
            }
          ],
          votes: %{"alice" => ["Tacos"]}
        }
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)
      {:ok, _view, html} = mount_as("alice", id)
      assert html =~ "text-base-content/50"
    end

    test "scenario stage renders synthesis thinking card" do
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        stage: %MaudeLibs.Decision.Stage.Scenario{
          submissions: %{"alice" => "dinner?"},
          synthesis: nil,
          synthesizing: true,
          votes: %{}
        }
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)
      {:ok, _view, html} = mount_as("alice", id)
      # claude_thinking component renders when synthesizing but no synthesis text
      assert html =~ "Claude"
    end

    test "candidate_card renders placeholder with thinking dots" do
      id = MaudeLibs.DecisionHelpers.unique_id()

      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice", "bob"]),
        stage: %MaudeLibs.Decision.Stage.Scenario{
          submissions: %{"alice" => "dinner?"},
          votes: %{}
        }
      }

      {:ok, _pid} = MaudeLibs.Decision.Supervisor.start_with_state(decision)
      {:ok, _view, html} = mount_as("alice", id)
      # bob has no submission yet, should show placeholder card
      assert html =~ "bob"
    end

    test "candidate_card with thinking=true and no placeholder renders mini_dots" do
      html =
        render_component(&MaudeLibsWeb.DecisionLive.DecisionComponents.candidate_card/1,
          text: nil,
          label: "test",
          voted: false,
          selected: false,
          is_synthesis: false,
          spectator: false,
          thinking: true
        )

      # Should render mini_dots (animate-bounce) and default "..." placeholder
      assert html =~ "animate-bounce"
      assert html =~ "..."
    end
  end
end
