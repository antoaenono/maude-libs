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
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{decision.id}")
      Server.handle_message(decision.id, {:ready_options, "alice"})
      Server.handle_message(decision.id, {:ready_options, "bob"})

      # Wait for async LLM Task to resolve scaffolding -> dashboard
      assert_receive {:decision_updated, %{stage: %MaudeLibs.Decision.Stage.Dashboard{}}}, 500

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

  describe "layout data attributes" do
    @tag stage: :options
    test "renders data-node-id for other users" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "Pick lunch")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ ~s(data-node-id="bob")
    end

    @tag stage: :options
    test "renders data-node-role attributes" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "Pick lunch")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ ~s(data-node-role="claude")
      assert html =~ ~s(data-node-role="you")
      assert html =~ ~s(data-node-role="other")
    end

    @tag stage: :options
    test "virtual canvas has phx-hook StageForce" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "Pick lunch")
      {:ok, _view, html} = mount_as("alice", decision.id)
      assert html =~ ~s(phx-hook="StageForce")
    end

    @tag stage: :options
    test "card wrappers have no inline left/top styles" do
      decision = seed_decision(:options, ["alice", "bob"], topic: "Pick lunch")
      {:ok, view, _html} = mount_as("alice", decision.id)
      html = render(view)
      refute html =~ ~r/data-node-id="[^"]*"[^>]*style="[^"]*left:/
    end
  end
end
