defmodule MaudeLibsWeb.DecisionLive.ScenarioTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

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
end
