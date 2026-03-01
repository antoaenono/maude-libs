defmodule MaudeLibsWeb.DecisionLive.LobbyTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

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
end
