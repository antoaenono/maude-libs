defmodule MaudeLibsWeb.DecisionLive.BreadcrumbsTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

  describe "breadcrumbs" do
    @tag stage: :breadcrumbs
    test "lobby stage shows breadcrumbs with Lobby as current" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-testid=breadcrumbs]")
      assert has_element?(view, "[data-stage=lobby].text-base-content.font-semibold")
      assert has_element?(view, "[data-stage=scenario].text-base-content\\/30")
    end

    @tag stage: :breadcrumbs
    test "scenario stage shows Lobby done and Scenario current" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-stage=lobby].text-success\\/70")
      assert has_element?(view, "[data-stage=scenario].text-base-content.font-semibold")
      assert has_element?(view, "[data-stage=priorities].text-base-content\\/30")
    end

    @tag stage: :breadcrumbs
    test "priorities stage shows Lobby and Scenario done" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-stage=lobby].text-success\\/70")
      assert has_element?(view, "[data-stage=scenario].text-success\\/70")
      assert has_element?(view, "[data-stage=priorities].text-base-content.font-semibold")
      assert has_element?(view, "[data-stage=options].text-base-content\\/30")
    end

    @tag stage: :breadcrumbs
    test "options stage shows first three stages done" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-stage=lobby].text-success\\/70")
      assert has_element?(view, "[data-stage=scenario].text-success\\/70")
      assert has_element?(view, "[data-stage=priorities].text-success\\/70")
      assert has_element?(view, "[data-stage=options].text-base-content.font-semibold")
      assert has_element?(view, "[data-stage=dashboard].text-base-content\\/30")
    end

    @tag stage: :breadcrumbs
    test "dashboard stage shows first four stages done" do
      decision = seed_decision(:dashboard, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-stage=lobby].text-success\\/70")
      assert has_element?(view, "[data-stage=scenario].text-success\\/70")
      assert has_element?(view, "[data-stage=priorities].text-success\\/70")
      assert has_element?(view, "[data-stage=options].text-success\\/70")
      assert has_element?(view, "[data-stage=dashboard].text-base-content.font-semibold")
      assert has_element?(view, "[data-stage=complete].text-base-content\\/30")
    end

    @tag stage: :breadcrumbs
    test "complete stage shows all stages done except Complete is current" do
      decision =
        seed_decision(:complete, ["alice"],
          topic: "Where to eat?",
          winner: "Tacos",
          why_statement: "Because tacos"
        )

      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-stage=lobby].text-success\\/70")
      assert has_element?(view, "[data-stage=scenario].text-success\\/70")
      assert has_element?(view, "[data-stage=priorities].text-success\\/70")
      assert has_element?(view, "[data-stage=options].text-success\\/70")
      assert has_element?(view, "[data-stage=dashboard].text-success\\/70")
      assert has_element?(view, "[data-stage=complete].text-base-content.font-semibold")
    end

    @tag stage: :breadcrumbs
    test "scaffolding stage maps to dashboard in breadcrumbs" do
      decision = seed_decision(:scaffolding, ["alice"], topic: "Where to eat?")
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-stage=options].text-success\\/70")
      assert has_element?(view, "[data-stage=dashboard].text-base-content.font-semibold")
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs contain all six stage labels" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, _view, html} = mount_as("alice", decision.id)

      for label <- ["Lobby", "Scenario", "Priorities", "Options", "Dashboard", "Complete"] do
        assert html =~ label
      end
    end

    @tag stage: :breadcrumbs
    test "done stages show checkmark" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, _html} = mount_as("alice", decision.id)

      # Lobby is done, should have a checkmark
      lobby_el = element(view, "[data-stage=lobby]")
      lobby_html = render(lobby_el)
      assert lobby_html =~ "✓"
    end

    @tag stage: :breadcrumbs
    test "current stage does not show checkmark" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, _html} = mount_as("alice", decision.id)

      scenario_el = element(view, "[data-stage=scenario]")
      scenario_html = render(scenario_el)
      refute scenario_html =~ "✓"
    end

    @tag stage: :breadcrumbs
    test "upcoming stages do not show checkmark" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      scenario_el = element(view, "[data-stage=scenario]")
      refute render(scenario_el) =~ "✓"

      complete_el = element(view, "[data-stage=complete]")
      refute render(complete_el) =~ "✓"
    end

    @tag stage: :breadcrumbs
    test "separators appear between stages" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, _view, html} = mount_as("alice", decision.id)

      # 6 stages, 5 separators
      assert length(Regex.scan(~r/aria-hidden="true"/, html)) == 5
    end

    @tag stage: :breadcrumbs
    test "spectators see breadcrumbs" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, _html} = mount_as("charlie", decision.id)

      assert has_element?(view, "[data-testid=breadcrumbs]")
      assert has_element?(view, "[data-stage=scenario].text-base-content.font-semibold")
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs update live when stage advances from lobby to scenario" do
      decision = seed_decision(:lobby, ["alice", "bob"], topic: "Dinner?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      # Both at lobby
      assert has_element?(alice_view, "[data-stage=lobby].text-base-content.font-semibold")

      # Both ready, alice starts
      alice_view |> element("button", "Ready up") |> render_click()
      bob_view |> element("button", "Ready up") |> render_click()
      alice_view |> element("button", "Start") |> render_click()

      # Breadcrumbs should now show scenario as current
      assert has_element?(alice_view, "[data-stage=lobby].text-success\\/70")
      assert has_element?(alice_view, "[data-stage=scenario].text-base-content.font-semibold")
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs update live when stage advances from scenario to priorities" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "Where to eat?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      assert has_element?(alice_view, "[data-stage=scenario].text-base-content.font-semibold")

      # Both submit and vote unanimously
      alice_view |> element("form#scenario-input") |> render_submit(%{"text" => "How to pick?"})
      bob_view |> element("form#scenario-input") |> render_submit(%{"text" => "What to eat?"})

      alice_view
      |> element("button[phx-click=\"vote_scenario\"][phx-value-candidate=\"How to pick?\"]")
      |> render_click()

      bob_view
      |> element("button[phx-click=\"vote_scenario\"][phx-value-candidate=\"How to pick?\"]")
      |> render_click()

      # Breadcrumbs should now show priorities as current
      assert has_element?(alice_view, "[data-stage=scenario].text-success\\/70")
      assert has_element?(alice_view, "[data-stage=priorities].text-base-content.font-semibold")
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs update for both users via PubSub on stage transition" do
      decision = seed_decision(:lobby, ["alice", "bob"], topic: "Dinner?")
      {:ok, alice_view, _} = mount_as("alice", decision.id)
      {:ok, bob_view, _} = mount_as("bob", decision.id)

      alice_view |> element("button", "Ready up") |> render_click()
      bob_view |> element("button", "Ready up") |> render_click()
      alice_view |> element("button", "Start") |> render_click()

      # Bob's view should also update via PubSub
      assert has_element?(bob_view, "[data-stage=lobby].text-success\\/70")
      assert has_element?(bob_view, "[data-stage=scenario].text-base-content.font-semibold")
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs advance through options to dashboard via server messages" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "Where to eat?")
      {:ok, view, _} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-stage=options].text-base-content.font-semibold")

      # Drive through options -> scaffolding -> dashboard via server
      Server.handle_message(
        decision.id,
        {:upsert_option, "alice", %{name: "Tacos", desc: "Quick"}}
      )

      Server.handle_message(
        decision.id,
        {:upsert_option, "bob", %{name: "Pizza", desc: "Classic"}}
      )

      Server.handle_message(decision.id, {:confirm_option, "alice"})
      Server.handle_message(decision.id, {:confirm_option, "bob"})
      Server.handle_message(decision.id, {:ready_options, "alice"})
      Server.handle_message(decision.id, {:ready_options, "bob"})

      # Mock LLM resolves instantly
      :timer.sleep(20)

      # Should be at dashboard now
      assert has_element?(view, "[data-stage=options].text-success\\/70")
      assert has_element?(view, "[data-stage=dashboard].text-base-content.font-semibold")
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs show exactly six li elements with data-stage" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "Where to eat?")
      {:ok, _view, html} = mount_as("alice", decision.id)

      stage_count = length(Regex.scan(~r/data-stage=/, html))
      assert stage_count == 6
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs render inside a nav element" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "nav[data-testid=breadcrumbs]")
    end

    @tag stage: :breadcrumbs
    test "exactly one stage is current at any time" do
      for {stage, users, opts} <- [
            {:lobby, ["alice"], []},
            {:scenario, ["alice", "bob"], [topic: "T"]},
            {:priorities, ["alice", "bob"], [topic: "T"]},
            {:options, ["alice", "bob"], [topic: "T"]},
            {:scaffolding, ["alice"], [topic: "T"]},
            {:dashboard, ["alice", "bob"], [topic: "T"]},
            {:complete, ["alice"], [topic: "T", winner: "X", why_statement: "Y"]}
          ] do
        decision = seed_decision(stage, users, opts)
        {:ok, _view, html} = mount_as(hd(users), decision.id)

        # Scope to the nav to avoid font-semibold matches in stage content
        [nav_html] = Regex.run(~r/<nav[^>]*data-testid="breadcrumbs"[^>]*>.*?<\/nav>/s, html)
        nav_current = length(Regex.scan(~r/font-semibold/, nav_html))

        assert nav_current == 1,
               "Expected 1 current stage in breadcrumbs at #{stage}, got #{nav_current}"
      end
    end

    @tag stage: :breadcrumbs
    test "no future stage ever has a checkmark" do
      decision = seed_decision(:scenario, ["alice", "bob"], topic: "T")
      {:ok, _view, html} = mount_as("alice", decision.id)

      [nav_html] = Regex.run(~r/<nav[^>]*data-testid="breadcrumbs"[^>]*>.*?<\/nav>/s, html)

      # Split by data-stage, check that after the current stage, no checkmarks appear
      parts = Regex.split(~r/data-stage="scenario"/, nav_html)
      after_current = List.last(parts)
      refute after_current =~ "✓"
    end

    @tag stage: :breadcrumbs
    test "lobby has zero checkmarks since nothing is done yet" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, _view, html} = mount_as("alice", decision.id)

      [nav_html] = Regex.run(~r/<nav[^>]*data-testid="breadcrumbs"[^>]*>.*?<\/nav>/s, html)
      assert length(Regex.scan(~r/✓/, nav_html)) == 0
    end

    @tag stage: :breadcrumbs
    test "complete stage has five checkmarks" do
      decision = seed_decision(:complete, ["alice"], topic: "T", winner: "X", why_statement: "Y")
      {:ok, _view, html} = mount_as("alice", decision.id)

      [nav_html] = Regex.run(~r/<nav[^>]*data-testid="breadcrumbs"[^>]*>.*?<\/nav>/s, html)
      assert length(Regex.scan(~r/✓/, nav_html)) == 5
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs preserve stage order left to right" do
      decision = seed_decision(:dashboard, ["alice", "bob"], topic: "T")
      {:ok, _view, html} = mount_as("alice", decision.id)

      [nav_html] = Regex.run(~r/<nav[^>]*data-testid="breadcrumbs"[^>]*>.*?<\/nav>/s, html)

      labels = Regex.scan(~r/data-stage="(\w+)"/, nav_html) |> Enum.map(&List.last/1)
      assert labels == ["lobby", "scenario", "priorities", "options", "dashboard", "complete"]
    end

    @tag stage: :breadcrumbs
    test "current stage has aria-current=step" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "T")
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "[data-stage=priorities][aria-current=step]")
      refute has_element?(view, "[data-stage=lobby][aria-current]")
      refute has_element?(view, "[data-stage=options][aria-current]")
    end

    @tag stage: :breadcrumbs
    test "nav has aria-label for accessibility" do
      decision = seed_decision(:lobby, ["alice"])
      {:ok, view, _html} = mount_as("alice", decision.id)

      assert has_element?(view, "nav[aria-label]")
    end

    @tag stage: :breadcrumbs
    test "breadcrumbs are not clickable" do
      decision = seed_decision(:priorities, ["alice", "bob"], topic: "T")
      {:ok, _view, html} = mount_as("alice", decision.id)

      [nav_html] = Regex.run(~r/<nav[^>]*data-testid="breadcrumbs"[^>]*>.*?<\/nav>/s, html)
      refute nav_html =~ "phx-click"
    end
  end
end
