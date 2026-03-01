defmodule MaudeLibsWeb.DecisionLive.OptionsTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

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
end
