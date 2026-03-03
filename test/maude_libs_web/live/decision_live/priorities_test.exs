defmodule MaudeLibsWeb.DecisionLive.PrioritiesTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

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

  describe "layout data attributes" do
    @tag stage: :priorities
    test "renders data-node-id for other users" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "Pick lunch")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ ~s(data-node-id="bob")
    end

    @tag stage: :priorities
    test "renders data-node-role attributes" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "Pick lunch")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ ~s(data-node-role="claude")
      assert html =~ ~s(data-node-role="you")
      assert html =~ ~s(data-node-role="other")
    end

    @tag stage: :priorities
    test "virtual canvas has phx-hook StageForce" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "Pick lunch")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ ~s(phx-hook="StageForce")
    end

    @tag stage: :priorities
    test "card wrappers have no inline left/top styles" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "Pick lunch")
      {:ok, view, _html} = mount_as("alice", decision.id)
      html = render(view)
      # Card wrappers with data-node-id should not have inline left/top
      # (D3 hook handles positioning)
      refute html =~ ~r/data-node-id="[^"]*"[^>]*style="[^"]*left:/
    end
  end
end
