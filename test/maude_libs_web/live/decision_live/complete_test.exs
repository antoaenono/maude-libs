defmodule MaudeLibsWeb.DecisionLive.CompleteTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

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
end
