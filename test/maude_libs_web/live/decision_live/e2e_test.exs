defmodule MaudeLibsWeb.DecisionLive.E2ETest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

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
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{decision.id}")
      Server.handle_message(decision.id, {:ready_options, "alice"})
      Server.handle_message(decision.id, {:ready_options, "bob"})

      # 6. Wait for async LLM Task to resolve scaffolding -> dashboard
      assert_receive {:decision_updated, %{stage: %MaudeLibs.Decision.Stage.Dashboard{}}}, 500

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

      # Wait for async LLM why_statement Task to resolve
      assert_receive {:decision_updated,
                      %{stage: %MaudeLibs.Decision.Stage.Complete{why_statement: ws}}}
                     when is_binary(ws),
                     500

      alice_html = render(alice_view)
      assert alice_html =~ "Tacos"
      assert alice_html =~ "We decided on Tacos"
      assert alice_html =~ "Winner"
    end
  end
end
