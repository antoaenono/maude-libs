defmodule MaudeLibsWeb.DecisionLiveTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  # ---------------------------------------------------------------------------
  # Helper: mount a LiveView as a specific user for a given decision
  # ---------------------------------------------------------------------------

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
  end

  # ---------------------------------------------------------------------------
  # Lobby Stage
  # ---------------------------------------------------------------------------

  describe "lobby stage" do
    @tag stage: :lobby
    test "creator sees topic and invite form" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, html} = mount_as("alice", decision.id)
      assert html =~ "What are you deciding?"
      assert html =~ "Invite participants"
      assert has_element?(view, "input[name=\"topic\"]")
      assert has_element?(view, "input[name=\"invite\"]")
    end

    @tag stage: :lobby
    test "non-creator participant does not see topic form" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, _view, html} = mount_as("bob", decision.id)
      refute html =~ "What are you deciding?"
      assert html =~ "Decision topic:"
    end

    @tag stage: :lobby
    test "lobby_update changes topic" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view
      |> element("form[phx-submit=\"lobby_update\"]")
      |> render_submit(%{"topic" => "Where to eat?", "invite" => ""})

      # State updated via PubSub broadcast
      html = render(view)
      assert html =~ "Where to eat?"
    end

    @tag stage: :lobby
    test "lobby_ready marks user as ready" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view |> element("button", "Ready up") |> render_click()

      html = render(view)
      assert html =~ "Ready ✓"
    end

    @tag stage: :lobby
    test "lobby_start advances to scenario when all ready" do
      decision = seed_decision(:lobby, ["alice", "bob"], topic: "Dinner?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      # Both ready up
      alice_view |> element("button", "Ready up") |> render_click()
      bob_view |> element("button", "Ready up") |> render_click()

      # Alice starts
      alice_view |> element("button", "Start") |> render_click()

      # Both should see scenario stage
      assert render(alice_view) =~ "Frame the scenario"
      assert render(bob_view) =~ "Frame the scenario"
    end

    @tag stage: :lobby
    test "remove_participant removes user from lobby" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      view
      |> element("button[phx-click=\"remove_participant\"][phx-value-user=\"bob\"]")
      |> render_click()

      html = render(view)
      refute html =~ ">bob<"
    end

    @tag stage: :lobby
    test "multi-user: bob joins and both see each other" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, _bob_view, _} = mount_as("bob", decision.id)

      # Alice should see bob in participant list
      html = render(alice_view)
      assert html =~ "alice"
      assert html =~ "bob"
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario Stage
  # ---------------------------------------------------------------------------

  describe "scenario stage" do
    @tag stage: :scenario
    test "renders scenario submission form" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, html} = mount_as("alice", decision.id)
      assert html =~ "Frame the scenario"
      assert html =~ "Where to eat?"
      assert has_element?(view, "form#scenario-input")
    end

    @tag stage: :scenario
    test "submit_scenario stores submission" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)

      alice_view
      |> element("form#scenario-input")
      |> render_submit(%{"text" => "How about picking a restaurant?"})

      html = render(alice_view)
      assert html =~ "How about picking a restaurant?"
    end

    @tag stage: :scenario
    test "other user sees submission via PubSub" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      alice_view
      |> element("form#scenario-input")
      |> render_submit(%{"text" => "How about picking a restaurant?"})

      # Bob sees alice's submission
      html = render(bob_view)
      assert html =~ "How about picking a restaurant?"
    end

    @tag stage: :scenario
    test "unanimous vote advances to priorities" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      # Both submit
      alice_view
      |> element("form#scenario-input")
      |> render_submit(%{"text" => "How do we pick lunch?"})

      bob_view |> element("form#scenario-input") |> render_submit(%{"text" => "What restaurant?"})

      # Both vote for alice's submission
      alice_view
      |> element(
        "button[phx-click=\"vote_scenario\"][phx-value-candidate=\"How do we pick lunch?\"]"
      )
      |> render_click()

      bob_view
      |> element(
        "button[phx-click=\"vote_scenario\"][phx-value-candidate=\"How do we pick lunch?\"]"
      )
      |> render_click()

      # Both should see priorities stage (check for direction selector or priority input)
      alice_html = render(alice_view)
      bob_html = render(bob_view)
      # Priorities stage has direction buttons +/-/~
      assert alice_html =~ "phx-click=\"confirm_priority\"" or
               alice_html =~ "phx-click=\"upsert_priority\""

      assert bob_html =~ "phx-click=\"confirm_priority\"" or
               bob_html =~ "phx-click=\"upsert_priority\""
    end

    @tag stage: :scenario
    test "split vote stays in scenario" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      alice_view |> element("form#scenario-input") |> render_submit(%{"text" => "Option A"})
      bob_view |> element("form#scenario-input") |> render_submit(%{"text" => "Option B"})

      # Each votes for their own
      alice_view
      |> element("button[phx-click=\"vote_scenario\"][phx-value-candidate=\"Option A\"]")
      |> render_click()

      bob_view
      |> element("button[phx-click=\"vote_scenario\"][phx-value-candidate=\"Option B\"]")
      |> render_click()

      # Still in scenario stage
      assert render(alice_view) =~ "Frame the scenario"
    end
  end

  # ---------------------------------------------------------------------------
  # Priorities Stage
  # ---------------------------------------------------------------------------

  describe "priorities stage" do
    @tag stage: :priorities
    test "renders priority input with direction selector" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "How do we pick lunch?")
      {:ok, view, html} = mount_as("alice", decision.id)
      assert html =~ "How do we pick lunch?"
      # Direction buttons
      assert has_element?(view, "button[phx-value-direction=\"+\"]") or html =~ "upsert_priority"
    end

    @tag stage: :priorities
    test "upsert_priority stores and displays priority" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "How do we pick lunch?")
      {:ok, view, _} = mount_as("alice", decision.id)

      # Submit a priority via the form change event
      view |> render_hook("upsert_priority", %{"text" => "speed", "direction" => "+"})

      state = Server.get_state(decision.id)
      assert state.stage.priorities["alice"] == %{text: "speed", direction: "+"}
    end

    @tag stage: :priorities
    test "confirm_priority marks user confirmed" do
      decision =
        seed_decision(:priorities, ["alice", "bob"],
          topic: "How do we pick lunch?",
          priorities: %{"alice" => %{text: "speed", direction: "+"}}
        )

      {:ok, view, _} = mount_as("alice", decision.id)

      # Confirm via server message (event handler calls Server.handle_message)
      Server.handle_message(decision.id, {:confirm_priority, "alice"})

      # Wait for PubSub
      :timer.sleep(20)
      html = render(view)
      # Confirmed users get green border
      assert html =~ "border-success" or
               Server.get_state(decision.id).stage.confirmed |> MapSet.member?("alice")
    end

    @tag stage: :priorities
    test "both confirm and ready advances to options" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "How do we pick lunch?")

      # Set up priorities via server
      Server.handle_message(
        decision.id,
        {:upsert_priority, "alice", %{text: "speed", direction: "+"}}
      )

      Server.handle_message(
        decision.id,
        {:upsert_priority, "bob", %{text: "cost", direction: "-"}}
      )

      Server.handle_message(decision.id, {:confirm_priority, "alice"})
      Server.handle_message(decision.id, {:confirm_priority, "bob"})

      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      # Both ready
      Server.handle_message(decision.id, {:ready_priority, "alice"})
      Server.handle_message(decision.id, {:ready_priority, "bob"})

      # Wait for PubSub
      :timer.sleep(20)

      # Should be in Options stage now
      state = Server.get_state(decision.id)
      assert %MaudeLibs.Decision.Stage.Options{} = state.stage

      alice_html = render(alice_view)
      bob_html = render(bob_view)
      assert alice_html =~ "confirm_option" or alice_html =~ "upsert_option"
      assert bob_html =~ "confirm_option" or bob_html =~ "upsert_option"
    end

    @tag stage: :priorities
    test "toggle_priority_suggestion works after injecting suggestions" do
      decision = seed_decision(:priorities, ["alice"], topic: "How do we pick lunch?")

      # Inject suggestions as if LLM returned them
      Server.handle_message(
        decision.id,
        {:upsert_priority, "alice", %{text: "speed", direction: "+"}}
      )

      Server.handle_message(
        decision.id,
        {:priority_suggestions_result,
         [
           %{text: "freshness", direction: "+"},
           %{text: "distance", direction: "-"}
         ]}
      )

      state = Server.get_state(decision.id)
      assert length(state.stage.suggestions) == 2
      refute Enum.at(state.stage.suggestions, 0).included

      # Toggle first suggestion on
      Server.handle_message(decision.id, {:toggle_priority_suggestion, 0, true})
      state = Server.get_state(decision.id)
      assert Enum.at(state.stage.suggestions, 0).included
    end
  end

  # ---------------------------------------------------------------------------
  # Options Stage
  # ---------------------------------------------------------------------------

  describe "options stage" do
    @tag stage: :options
    test "renders option input form" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "How do we pick lunch?")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "How do we pick lunch?"
    end

    @tag stage: :options
    test "upsert_option and confirm_option work" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "How do we pick lunch?")

      Server.handle_message(
        decision.id,
        {:upsert_option, "alice", %{name: "Tacos", desc: "Quick Mexican"}}
      )

      Server.handle_message(decision.id, {:confirm_option, "alice"})

      state = Server.get_state(decision.id)
      assert state.stage.proposals["alice"] == %{name: "Tacos", desc: "Quick Mexican"}
      assert "alice" in state.stage.confirmed
    end

    @tag stage: :options
    test "all ready advances through scaffolding to dashboard (mock LLM resolves instantly)" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "How do we pick lunch?")

      Server.handle_message(
        decision.id,
        {:upsert_option, "alice", %{name: "Tacos", desc: "Quick Mexican"}}
      )

      Server.handle_message(
        decision.id,
        {:upsert_option, "bob", %{name: "Pizza", desc: "Classic Italian"}}
      )

      Server.handle_message(decision.id, {:confirm_option, "alice"})
      Server.handle_message(decision.id, {:confirm_option, "bob"})
      Server.handle_message(decision.id, {:ready_options, "alice"})
      Server.handle_message(decision.id, {:ready_options, "bob"})

      # Mock LLM resolves instantly, so scaffolding transitions straight to dashboard
      :timer.sleep(20)
      state = Server.get_state(decision.id)
      assert %MaudeLibs.Decision.Stage.Dashboard{} = state.stage
      assert length(state.stage.options) == 2
    end

    @tag stage: :options
    test "toggle_option_suggestion works after injecting suggestions" do
      decision = seed_decision(:options, ["alice"], topic: "How do we pick lunch?")

      Server.handle_message(
        decision.id,
        {:upsert_option, "alice", %{name: "Tacos", desc: "Quick"}}
      )

      Server.handle_message(
        decision.id,
        {:option_suggestions_result,
         [
           %{name: "Sushi", desc: "Fresh fish"},
           %{name: "Burgers", desc: "American classic"}
         ]}
      )

      state = Server.get_state(decision.id)
      assert length(state.stage.suggestions) == 2

      Server.handle_message(decision.id, {:toggle_option_suggestion, 0, true})
      state = Server.get_state(decision.id)
      assert Enum.at(state.stage.suggestions, 0).included
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard Stage
  # ---------------------------------------------------------------------------

  describe "dashboard stage" do
    @tag stage: :dashboard
    test "renders option cards with for/against analysis" do
      decision = seed_decision(:dashboard, ["alice", "bob"], topic: "How do we pick lunch?")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Tacos"
      assert html =~ "Pizza"
      assert html =~ "Ranking"
      assert html =~ "Scenario"
    end

    @tag stage: :dashboard
    test "toggle_vote adds and removes votes" do
      decision = seed_decision(:dashboard, ["alice", "bob"], topic: "How do we pick lunch?")
      {:ok, view, _} = mount_as("alice", decision.id)

      # Vote for Tacos
      view
      |> element("div.card[phx-click=\"toggle_vote\"][phx-value-option=\"Tacos\"]")
      |> render_click()

      state = Server.get_state(decision.id)
      assert "Tacos" in Map.get(state.stage.votes, "alice", [])

      # Toggle off
      view
      |> element("div.card[phx-click=\"toggle_vote\"][phx-value-option=\"Tacos\"]")
      |> render_click()

      state = Server.get_state(decision.id)
      refute "Tacos" in Map.get(state.stage.votes, "alice", [])
    end

    @tag stage: :dashboard
    test "ready_dashboard with all voted and ready advances to complete" do
      decision = seed_decision(:dashboard, ["alice", "bob"], topic: "How do we pick lunch?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      # Both vote
      Server.handle_message(decision.id, {:vote, "alice", ["Tacos"]})
      Server.handle_message(decision.id, {:vote, "bob", ["Tacos", "Pizza"]})

      # Both ready
      Server.handle_message(decision.id, {:ready_dashboard, "alice"})
      Server.handle_message(decision.id, {:ready_dashboard, "bob"})

      :timer.sleep(20)

      state = Server.get_state(decision.id)
      assert %MaudeLibs.Decision.Stage.Complete{} = state.stage
      assert state.stage.winner == "Tacos"

      # Both views should show complete stage
      assert render(alice_view) =~ "Decision"
      assert render(bob_view) =~ "Decision"
    end

    @tag stage: :dashboard
    test "multi-user voting updates ranking for both" do
      decision = seed_decision(:dashboard, ["alice", "bob"], topic: "How do we pick lunch?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      # Alice votes Tacos
      alice_view
      |> element("div.card[phx-click=\"toggle_vote\"][phx-value-option=\"Tacos\"]")
      |> render_click()

      # Bob should see the vote count update
      :timer.sleep(20)
      bob_html = render(bob_view)
      assert bob_html =~ "1"
    end
  end

  # ---------------------------------------------------------------------------
  # Complete Stage
  # ---------------------------------------------------------------------------

  describe "complete stage" do
    @tag stage: :complete
    test "renders winner" do
      decision =
        seed_decision(:complete, ["alice", "bob"],
          topic: "How do we pick lunch?",
          winner: "Tacos",
          options: [
            %{name: "Tacos", desc: "Quick Mexican", for: [], against: []},
            %{name: "Pizza", desc: "Classic Italian", for: [], against: []}
          ]
        )

      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Tacos"
      assert html =~ "Decision"
      assert html =~ "Winner"
    end

    @tag stage: :complete
    test "shows generating message before why_statement arrives" do
      decision =
        seed_decision(:complete, ["alice"],
          topic: "How do we pick lunch?",
          winner: "Tacos",
          why_statement: nil
        )

      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Generating summary"
    end

    @tag stage: :complete
    test "displays why_statement after injection" do
      decision =
        seed_decision(:complete, ["alice"],
          topic: "How do we pick lunch?",
          winner: "Tacos",
          why_statement: nil
        )

      {:ok, view, _} = mount_as("alice", decision.id)

      Server.handle_message(
        decision.id,
        {:why_statement_result, "Tacos won because everyone loves Mexican food"}
      )

      :timer.sleep(20)
      html = render(view)
      assert html =~ "Tacos won because everyone loves Mexican food"
    end

    @tag stage: :complete
    test "back to canvas link present" do
      decision =
        seed_decision(:complete, ["alice"],
          topic: "Test",
          winner: "Tacos",
          why_statement: "Because tacos"
        )

      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Back to canvas"
    end
  end

  # ---------------------------------------------------------------------------
  # Scaffolding Stage
  # ---------------------------------------------------------------------------

  describe "scaffolding stage" do
    @tag stage: :scaffolding
    test "renders loading state" do
      decision = seed_decision(:scaffolding, ["alice"], topic: "How do we pick lunch?")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ "Spelunking"
    end

    @tag stage: :scaffolding
    test "transitions to dashboard on scaffolding result" do
      decision = seed_decision(:scaffolding, ["alice"], topic: "How do we pick lunch?")
      {:ok, view, _} = mount_as("alice", decision.id)

      scaffolded = [
        %{name: "Tacos", desc: "Quick Mexican", for: [], against: []},
        %{name: "Pizza", desc: "Classic Italian", for: [], against: []}
      ]

      Server.handle_message(decision.id, {:scaffolding_result, scaffolded})

      :timer.sleep(20)
      html = render(view)
      assert html =~ "Tacos"
      assert html =~ "Pizza"
      assert html =~ "Ranking"
    end
  end

  # ---------------------------------------------------------------------------
  # Full End-to-End Flow
  # ---------------------------------------------------------------------------

  describe "full flow: lobby to complete" do
    @tag stage: :e2e
    test "two users complete entire decision flow" do
      # 1. Start at lobby
      decision = seed_decision(:lobby, ["alice", "bob"], topic: "Where to eat?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      # 2. Both ready, alice starts -> Scenario
      alice_view |> element("button", "Ready up") |> render_click()
      bob_view |> element("button", "Ready up") |> render_click()
      alice_view |> element("button", "Start") |> render_click()
      assert render(alice_view) =~ "Frame the scenario"

      # 3. Both submit scenarios, both vote same -> Priorities
      alice_view
      |> element("form#scenario-input")
      |> render_submit(%{"text" => "How do we pick lunch?"})

      bob_view
      |> element("form#scenario-input")
      |> render_submit(%{"text" => "Where to eat together?"})

      alice_view
      |> element(
        "button[phx-click=\"vote_scenario\"][phx-value-candidate=\"How do we pick lunch?\"]"
      )
      |> render_click()

      bob_view
      |> element(
        "button[phx-click=\"vote_scenario\"][phx-value-candidate=\"How do we pick lunch?\"]"
      )
      |> render_click()

      # Now in priorities - drive via server messages for speed
      state = Server.get_state(decision.id)
      assert %MaudeLibs.Decision.Stage.Priorities{} = state.stage

      # 4. Both submit priorities, confirm, ready -> Options
      Server.handle_message(
        decision.id,
        {:upsert_priority, "alice", %{text: "speed", direction: "+"}}
      )

      Server.handle_message(
        decision.id,
        {:upsert_priority, "bob", %{text: "cost", direction: "-"}}
      )

      Server.handle_message(decision.id, {:confirm_priority, "alice"})
      Server.handle_message(decision.id, {:confirm_priority, "bob"})
      Server.handle_message(decision.id, {:ready_priority, "alice"})
      Server.handle_message(decision.id, {:ready_priority, "bob"})

      state = Server.get_state(decision.id)
      assert %MaudeLibs.Decision.Stage.Options{} = state.stage

      # 5. Both submit options, confirm, ready -> Scaffolding
      Server.handle_message(
        decision.id,
        {:upsert_option, "alice", %{name: "Tacos", desc: "Quick Mexican"}}
      )

      Server.handle_message(
        decision.id,
        {:upsert_option, "bob", %{name: "Pizza", desc: "Classic Italian"}}
      )

      Server.handle_message(decision.id, {:confirm_option, "alice"})
      Server.handle_message(decision.id, {:confirm_option, "bob"})
      Server.handle_message(decision.id, {:ready_options, "alice"})
      Server.handle_message(decision.id, {:ready_options, "bob"})

      # 6. Mock LLM resolves scaffold instantly, so we skip straight to Dashboard
      :timer.sleep(20)
      state = Server.get_state(decision.id)
      assert %MaudeLibs.Decision.Stage.Dashboard{} = state.stage

      # 7. Both vote + ready -> Complete
      Server.handle_message(decision.id, {:vote, "alice", ["Tacos"]})
      Server.handle_message(decision.id, {:vote, "bob", ["Tacos", "Pizza"]})
      Server.handle_message(decision.id, {:ready_dashboard, "alice"})
      Server.handle_message(decision.id, {:ready_dashboard, "bob"})

      state = Server.get_state(decision.id)
      assert %MaudeLibs.Decision.Stage.Complete{} = state.stage
      assert state.stage.winner == "Tacos"

      # 8. Mock LLM's why_statement fires automatically on completion
      :timer.sleep(20)
      alice_html = render(alice_view)
      assert alice_html =~ "Tacos"
      assert alice_html =~ "We decided on Tacos"
      assert alice_html =~ "Winner"
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

      # Disconnect bob
      Server.handle_message(decision.id, {:disconnect, "bob"})

      state = Server.get_state(decision.id)
      refute "bob" in state.connected
    end
  end
end
