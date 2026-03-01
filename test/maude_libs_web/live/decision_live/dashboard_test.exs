defmodule MaudeLibsWeb.DecisionLive.DashboardTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

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
end
