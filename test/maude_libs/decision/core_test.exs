defmodule MaudeLibs.Decision.CoreTest do
  use ExUnit.Case, async: true

  alias MaudeLibs.Decision.Core
  alias MaudeLibs.Decision.Stage

  # Helper to build a fresh decision with given connected users and stage
  defp decision(opts \\ []) do
    id = Keyword.get(opts, :id, "test-1")
    connected = Keyword.get(opts, :connected, MapSet.new())
    stage = Keyword.get(opts, :stage, %Stage.Lobby{})
    topic = Keyword.get(opts, :topic, "test topic")
    priorities = Keyword.get(opts, :priorities, [])

    %Core{
      id: id,
      topic: topic,
      connected: connected,
      priorities: priorities,
      stage: stage
    }
  end

  defp lobby_with(opts) do
    invited = MapSet.new(Keyword.get(opts, :invited, []))
    joined = MapSet.new(Keyword.get(opts, :joined, []))
    ready = MapSet.new(Keyword.get(opts, :ready, []))
    %Stage.Lobby{invited: invited, joined: joined, ready: ready}
  end

  defp connected(users), do: MapSet.new(users)

  # ---------------------------------------------------------------------------
  # Connect / Disconnect
  # ---------------------------------------------------------------------------

  describe "connect" do
    test "adds user to connected" do
      d = decision()
      {:ok, d2, _effects} = Core.handle(d, {:connect, "alice"})
      assert "alice" in d2.connected
    end
  end

  describe "disconnect" do
    test "removes user from connected" do
      d = decision(connected: connected(["alice", "bob"]))
      {:ok, d2, _} = Core.handle(d, {:disconnect, "alice"})
      refute "alice" in d2.connected
      assert "bob" in d2.connected
    end
  end

  # ---------------------------------------------------------------------------
  # Lobby
  # ---------------------------------------------------------------------------

  describe "lobby: join" do
    test "join adds user to joined set" do
      stage = lobby_with(invited: ["bob"])
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:join, "bob"})
      assert "bob" in d2.stage.joined
    end

    test "join rejects uninvited user" do
      stage = lobby_with(invited: ["bob"])
      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :not_invited} = Core.handle(d, {:join, "charlie"})
    end

    test "join rejects already-joined user" do
      stage = lobby_with(invited: ["bob"], joined: ["bob"])
      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      assert {:error, :already_joined} = Core.handle(d, {:join, "bob"})
    end
  end

  describe "lobby: ready" do
    test "ready marks user as ready" do
      stage = lobby_with(joined: ["alice"])
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:ready, "alice"})
      assert "alice" in d2.stage.ready
    end

    test "ready rejects unjoined user" do
      stage = lobby_with(joined: [])
      d = decision(stage: stage)
      assert {:error, :not_joined} = Core.handle(d, {:ready, "alice"})
    end
  end

  describe "lobby: remove_participant" do
    test "creator can remove unready participant" do
      stage = lobby_with(invited: ["alice", "bob"], joined: ["alice", "bob"])
      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:remove_participant, "alice", "bob"})
      refute "bob" in d2.stage.joined
    end

    test "creator cannot remove themselves" do
      stage = lobby_with(joined: ["alice"])
      d = decision(connected: connected(["alice"]), stage: stage)

      assert {:error, :cannot_remove_self} =
               Core.handle(d, {:remove_participant, "alice", "alice"})
    end
  end

  describe "lobby: start" do
    test "start transitions to Scenario when all ready" do
      stage = lobby_with(joined: ["alice"], ready: ["alice"])
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:start, "alice"})
      assert %Stage.Scenario{} = d2.stage
    end

    test "start rejected if not all ready" do
      stage = lobby_with(joined: ["alice", "bob"], ready: ["alice"])
      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      assert {:error, :not_all_ready} = Core.handle(d, {:start, "alice"})
    end

    test "solo decision: start allowed when creator ready" do
      stage = lobby_with(joined: ["alice"], ready: ["alice"])
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:start, "alice"})
      assert %Stage.Scenario{} = d2.stage
    end

    test "max decision: all must ready before start" do
      stage =
        lobby_with(
          joined: ["a", "b", "c", "d"],
          ready: ["a", "b", "c"]
        )

      d = decision(connected: connected(["a", "b", "c", "d"]), stage: stage)
      assert {:error, :not_all_ready} = Core.handle(d, {:start, "a"})
    end

    test "creator topic pre-filled as scenario submission" do
      stage = lobby_with(joined: ["alice"], ready: ["alice"])
      d = decision(connected: connected(["alice"]), stage: stage, topic: "dinner?")
      {:ok, d2, _} = Core.handle(d, {:start, "alice"})
      assert d2.stage.submissions["alice"] == "dinner?"
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario
  # ---------------------------------------------------------------------------

  describe "scenario" do
    defp scenario_decision(opts \\ []) do
      users = Keyword.get(opts, :users, ["alice", "bob"])
      subs = Keyword.get(opts, :submissions, %{})
      votes = Keyword.get(opts, :votes, %{})
      synth = Keyword.get(opts, :synthesis, nil)
      stage = %Stage.Scenario{submissions: subs, synthesis: synth, votes: votes}
      decision(connected: connected(users), stage: stage, topic: "dinner?")
    end

    test "submit_scenario stores submission for user" do
      d = scenario_decision()
      {:ok, d2, _} = Core.handle(d, {:submit_scenario, "alice", "where to eat?"})
      assert d2.stage.submissions["alice"] == "where to eat?"
    end

    test "submit_scenario replaces existing submission" do
      d = scenario_decision(submissions: %{"alice" => "old"})
      {:ok, d2, _} = Core.handle(d, {:submit_scenario, "alice", "new"})
      assert d2.stage.submissions["alice"] == "new"
    end

    test "synthesis_result stores synthesis candidate" do
      d = scenario_decision()
      {:ok, d2, _} = Core.handle(d, {:synthesis_result, "synthesized framing"})
      assert d2.stage.synthesis == "synthesized framing"
    end

    test "vote_scenario records user vote" do
      d = scenario_decision(submissions: %{"alice" => "dinner?", "bob" => "dinner?"})
      {:ok, d2, _} = Core.handle(d, {:vote_scenario, "alice", "dinner?"})
      assert d2.stage.votes["alice"] == "dinner?"
    end

    test "vote_scenario transitions to Priorities on unanimity" do
      d =
        scenario_decision(
          users: ["alice"],
          submissions: %{"alice" => "dinner?"}
        )

      {:ok, d2, _} = Core.handle(d, {:vote_scenario, "alice", "dinner?"})
      assert %Stage.Priorities{} = d2.stage
    end

    test "vote_scenario does not advance if votes differ" do
      d =
        scenario_decision(
          submissions: %{"alice" => "A", "bob" => "B"},
          votes: %{"bob" => "B"}
        )

      {:ok, d2, _} = Core.handle(d, {:vote_scenario, "alice", "A"})
      assert %Stage.Scenario{} = d2.stage
    end

    test "vote_scenario does not advance if not all users have voted" do
      d =
        scenario_decision(
          users: ["alice", "bob"],
          submissions: %{"alice" => "dinner?"}
        )

      {:ok, d2, _} = Core.handle(d, {:vote_scenario, "alice", "dinner?"})
      assert %Stage.Scenario{} = d2.stage
    end

    test "vote on non-existent candidate is rejected" do
      d = scenario_decision(submissions: %{"alice" => "dinner?"})

      assert {:error, :invalid_candidate} =
               Core.handle(d, {:vote_scenario, "alice", "nonexistent"})
    end

    test "unanimous vote with 1 participant advances immediately" do
      d = scenario_decision(users: ["alice"], submissions: %{"alice" => "solo?"})
      {:ok, d2, _} = Core.handle(d, {:vote_scenario, "alice", "solo?"})
      assert %Stage.Priorities{} = d2.stage
    end

    test "synthesis candidate is valid vote target" do
      d =
        scenario_decision(
          users: ["alice"],
          submissions: %{"alice" => "original"},
          synthesis: "synthesized"
        )

      {:ok, d2, _} = Core.handle(d, {:vote_scenario, "alice", "synthesized"})
      assert %Stage.Priorities{} = d2.stage
    end

    test "debounce effect emitted when >= 2 submissions" do
      d = scenario_decision(submissions: %{"alice" => "A"})
      {:ok, _d2, effects} = Core.handle(d, {:submit_scenario, "bob", "B"})

      assert Enum.any?(effects, fn
               {:debounce, :synthesis, _, _} -> true
               _ -> false
             end)
    end

    test "no debounce effect with only 1 submission" do
      d = scenario_decision(submissions: %{})
      {:ok, _d2, effects} = Core.handle(d, {:submit_scenario, "alice", "A"})

      refute Enum.any?(effects, fn
               {:debounce, :synthesis, _, _} -> true
               _ -> false
             end)
    end
  end

  # ---------------------------------------------------------------------------
  # Priorities
  # ---------------------------------------------------------------------------

  describe "priorities" do
    defp priorities_decision(opts \\ []) do
      users = Keyword.get(opts, :users, ["alice", "bob"])
      prios = Keyword.get(opts, :priorities, %{})
      confirmed = MapSet.new(Keyword.get(opts, :confirmed, []))
      suggestions = Keyword.get(opts, :suggestions, [])
      ready = MapSet.new(Keyword.get(opts, :ready, []))

      stage = %Stage.Priorities{
        priorities: prios,
        confirmed: confirmed,
        suggestions: suggestions,
        ready: ready
      }

      decision(connected: connected(users), stage: stage, topic: "dinner?")
    end

    test "upsert_priority stores priority for user" do
      d = priorities_decision()
      {:ok, d2, _} = Core.handle(d, {:upsert_priority, "alice", %{text: "cost", direction: "-"}})
      assert d2.stage.priorities["alice"] == %{text: "cost", direction: "-"}
    end

    test "upsert_priority replaces existing for same user" do
      d = priorities_decision(priorities: %{"alice" => %{text: "old", direction: "+"}})
      {:ok, d2, _} = Core.handle(d, {:upsert_priority, "alice", %{text: "new", direction: "-"}})
      assert d2.stage.priorities["alice"].text == "new"
    end

    test "confirm_priority marks user as confirmed" do
      d = priorities_decision(priorities: %{"alice" => %{text: "cost", direction: "-"}})
      {:ok, d2, _} = Core.handle(d, {:confirm_priority, "alice"})
      assert "alice" in d2.stage.confirmed
    end

    test "confirm_priority rejected if user has no entry yet" do
      d = priorities_decision()
      assert {:error, :no_entry} = Core.handle(d, {:confirm_priority, "alice"})
    end

    test "claude suggestions effect emitted once all users have confirmed" do
      d =
        priorities_decision(
          users: ["alice"],
          priorities: %{"alice" => %{text: "cost", direction: "-"}}
        )

      {:ok, _d2, effects} = Core.handle(d, {:confirm_priority, "alice"})

      assert Enum.any?(effects, fn
               {:async_llm, {:suggest_priorities, _, _}} -> true
               _ -> false
             end)
    end

    test "claude suggestions effect NOT emitted if not all confirmed" do
      d =
        priorities_decision(
          users: ["alice", "bob"],
          priorities: %{"alice" => %{text: "cost", direction: "-"}}
        )

      {:ok, _d2, effects} = Core.handle(d, {:confirm_priority, "alice"})

      refute Enum.any?(effects, fn
               {:async_llm, {:suggest_priorities, _, _}} -> true
               _ -> false
             end)
    end

    test "priority_suggestions_result stores suggestions with included: false" do
      d = priorities_decision()
      suggestions = [%{text: "speed", direction: "+"}]
      {:ok, d2, _} = Core.handle(d, {:priority_suggestions_result, suggestions})
      assert [%{text: "speed", direction: "+", included: false}] = d2.stage.suggestions
    end

    test "toggle_priority_suggestion sets included: true" do
      d = priorities_decision(suggestions: [%{text: "speed", direction: "+", included: false}])
      {:ok, d2, _} = Core.handle(d, {:toggle_priority_suggestion, 0, true})
      assert Enum.at(d2.stage.suggestions, 0).included == true
    end

    test "toggle_priority_suggestion sets included: false (last write wins)" do
      d = priorities_decision(suggestions: [%{text: "speed", direction: "+", included: true}])
      {:ok, d2, _} = Core.handle(d, {:toggle_priority_suggestion, 0, false})
      assert Enum.at(d2.stage.suggestions, 0).included == false
    end

    test "ready_priority marks user ready" do
      d = priorities_decision(priorities: %{"alice" => %{text: "cost", direction: "-"}})
      {:ok, d2, _} = Core.handle(d, {:ready_priority, "alice"})
      assert "alice" in d2.stage.ready
    end

    test "ready_priority rejected if user has no entry" do
      d = priorities_decision()
      assert {:error, :no_entry} = Core.handle(d, {:ready_priority, "alice"})
    end

    test "all ready transitions to Options with assigned priority IDs" do
      d =
        priorities_decision(
          users: ["alice"],
          priorities: %{"alice" => %{text: "cost", direction: "-"}}
        )

      {:ok, d2, _} = Core.handle(d, {:ready_priority, "alice"})
      assert %Stage.Options{} = d2.stage
      assert [%{id: "-1", text: "cost", direction: "-"}] = d2.priorities
    end

    test "priority IDs assigned correctly: + gets +1/+2, - gets -1/-2, ~ gets ~1/~2" do
      d =
        priorities_decision(
          users: ["alice"],
          priorities: %{"alice" => %{text: "speed", direction: "+"}}
        )

      {:ok, d2, _} = Core.handle(d, {:ready_priority, "alice"})
      assert [%{id: "+1"}] = d2.priorities
    end

    test "~ direction priority gets ~1" do
      d =
        priorities_decision(
          users: ["alice"],
          priorities: %{"alice" => %{text: "familiarity", direction: "~"}}
        )

      {:ok, d2, _} = Core.handle(d, {:ready_priority, "alice"})
      assert [%{id: "~1"}] = d2.priorities
    end

    test "dropped user does not block ready-up" do
      # alice and bob both in priorities, but bob disconnected (not in connected)
      d =
        priorities_decision(
          users: ["alice"],
          priorities: %{
            "alice" => %{text: "cost", direction: "-"},
            "bob" => %{text: "speed", direction: "+"}
          }
        )

      {:ok, d2, _} = Core.handle(d, {:ready_priority, "alice"})
      assert %Stage.Options{} = d2.stage
    end
  end

  # ---------------------------------------------------------------------------
  # Options
  # ---------------------------------------------------------------------------

  describe "options" do
    defp options_decision(opts \\ []) do
      users = Keyword.get(opts, :users, ["alice", "bob"])
      proposals = Keyword.get(opts, :proposals, %{})
      confirmed = MapSet.new(Keyword.get(opts, :confirmed, []))
      suggestions = Keyword.get(opts, :suggestions, [])
      ready = MapSet.new(Keyword.get(opts, :ready, []))

      stage = %Stage.Options{
        proposals: proposals,
        confirmed: confirmed,
        suggestions: suggestions,
        ready: ready
      }

      priorities = Keyword.get(opts, :priorities, [%{id: "+1", text: "speed", direction: "+"}])

      decision(
        connected: connected(users),
        stage: stage,
        topic: "dinner?",
        priorities: priorities
      )
    end

    test "upsert_option stores option for user" do
      d = options_decision()

      {:ok, d2, _} =
        Core.handle(d, {:upsert_option, "alice", %{name: "tacos", desc: "quick tacos"}})

      assert d2.stage.proposals["alice"] == %{name: "tacos", desc: "quick tacos"}
    end

    test "upsert_option replaces existing for same user" do
      d = options_decision(proposals: %{"alice" => %{name: "old", desc: ""}})
      {:ok, d2, _} = Core.handle(d, {:upsert_option, "alice", %{name: "new", desc: "x"}})
      assert d2.stage.proposals["alice"].name == "new"
    end

    test "confirm_option marks user as confirmed" do
      d = options_decision(proposals: %{"alice" => %{name: "tacos", desc: "x"}})
      {:ok, d2, _} = Core.handle(d, {:confirm_option, "alice"})
      assert "alice" in d2.stage.confirmed
    end

    test "confirm_option rejected if user has no entry yet" do
      d = options_decision()
      assert {:error, :no_entry} = Core.handle(d, {:confirm_option, "alice"})
    end

    test "after all confirmed: claude suggestions effect emitted" do
      d =
        options_decision(
          users: ["alice"],
          proposals: %{"alice" => %{name: "tacos", desc: "x"}}
        )

      {:ok, _d2, effects} = Core.handle(d, {:confirm_option, "alice"})

      assert Enum.any?(effects, fn
               {:async_llm, {:suggest_options, _, _, _}} -> true
               _ -> false
             end)
    end

    test "toggle_claude_suggestion sets included: true" do
      d = options_decision(suggestions: [%{name: "pizza", desc: "y", included: false}])
      {:ok, d2, _} = Core.handle(d, {:toggle_option_suggestion, 0, true})
      assert Enum.at(d2.stage.suggestions, 0).included == true
    end

    test "toggle_claude_suggestion sets included: false (last write wins)" do
      d = options_decision(suggestions: [%{name: "pizza", desc: "y", included: true}])
      {:ok, d2, _} = Core.handle(d, {:toggle_option_suggestion, 0, false})
      assert Enum.at(d2.stage.suggestions, 0).included == false
    end

    test "ready_options marks user ready" do
      d = options_decision(proposals: %{"alice" => %{name: "tacos", desc: "x"}})
      {:ok, d2, _} = Core.handle(d, {:ready_options, "alice"})
      assert "alice" in d2.stage.ready
    end

    test "ready_options rejected if user has no entry" do
      d = options_decision()
      assert {:error, :no_entry} = Core.handle(d, {:ready_options, "alice"})
    end

    test "all ready transitions to Scaffolding" do
      d =
        options_decision(
          users: ["alice"],
          proposals: %{"alice" => %{name: "tacos", desc: "x"}}
        )

      {:ok, d2, _} = Core.handle(d, {:ready_options, "alice"})
      assert %Stage.Scaffolding{} = d2.stage
    end

    test "all ready emits scaffold async_llm effect" do
      d =
        options_decision(
          users: ["alice"],
          proposals: %{"alice" => %{name: "tacos", desc: "x"}}
        )

      {:ok, _d2, effects} = Core.handle(d, {:ready_options, "alice"})

      assert Enum.any?(effects, fn
               {:async_llm, {:scaffold, _, _, _}} -> true
               _ -> false
             end)
    end

    test "0 claude suggestions included: scaffolding fires with only human options" do
      d =
        options_decision(
          users: ["alice"],
          proposals: %{"alice" => %{name: "tacos", desc: "x"}},
          suggestions: [%{name: "pizza", desc: "y", included: false}]
        )

      {:ok, _d2, effects} = Core.handle(d, {:ready_options, "alice"})

      scaffold_effect =
        Enum.find(effects, fn
          {:async_llm, {:scaffold, _, _, _}} -> true
          _ -> false
        end)

      {:async_llm, {:scaffold, _scenario, _priorities, options}} = scaffold_effect
      assert length(options) == 1
      assert hd(options).name == "tacos"
    end

    test "all 3 claude suggestions included go into scaffolding" do
      suggestions = [
        %{name: "pizza", desc: "a", included: true},
        %{name: "sushi", desc: "b", included: true},
        %{name: "ramen", desc: "c", included: true}
      ]

      d =
        options_decision(
          users: ["alice"],
          proposals: %{"alice" => %{name: "tacos", desc: "x"}},
          suggestions: suggestions
        )

      {:ok, _d2, effects} = Core.handle(d, {:ready_options, "alice"})

      {:async_llm, {:scaffold, _, _, options}} =
        Enum.find(effects, fn
          {:async_llm, {:scaffold, _, _, _}} -> true
          _ -> false
        end)

      assert length(options) == 4
    end

    test "dropped user does not block ready-up" do
      d =
        options_decision(
          users: ["alice"],
          proposals: %{
            "alice" => %{name: "tacos", desc: "x"},
            "bob" => %{name: "pizza", desc: "y"}
          }
        )

      {:ok, d2, _} = Core.handle(d, {:ready_options, "alice"})
      assert %Stage.Scaffolding{} = d2.stage
    end
  end

  # ---------------------------------------------------------------------------
  # Scaffolding
  # ---------------------------------------------------------------------------

  describe "scaffolding" do
    defp scaffolding_decision do
      decision(
        connected: connected(["alice"]),
        stage: %Stage.Scaffolding{}
      )
    end

    test "scaffolding_result transitions to Dashboard with populated options" do
      d = scaffolding_decision()
      options = [%{name: "tacos", desc: "x", for: [], against: []}]
      {:ok, d2, _} = Core.handle(d, {:scaffolding_result, options})
      assert %Stage.Dashboard{} = d2.stage
      assert d2.stage.options == options
    end

    test "scaffolding_result with empty options list still transitions" do
      d = scaffolding_decision()
      {:ok, d2, _} = Core.handle(d, {:scaffolding_result, []})
      assert %Stage.Dashboard{} = d2.stage
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard + Vote
  # ---------------------------------------------------------------------------

  describe "dashboard" do
    defp dashboard_decision(opts \\ []) do
      users = Keyword.get(opts, :users, ["alice", "bob"])

      options =
        Keyword.get(opts, :options, [
          %{name: "tacos", desc: "x", for: [], against: []},
          %{name: "pizza", desc: "y", for: [], against: []}
        ])

      votes = Keyword.get(opts, :votes, %{})
      ready = MapSet.new(Keyword.get(opts, :ready, []))
      stage = %Stage.Dashboard{options: options, votes: votes, ready: ready}
      decision(connected: connected(users), stage: stage, topic: "dinner?")
    end

    test "vote records user's option selections" do
      d = dashboard_decision()
      {:ok, d2, _} = Core.handle(d, {:vote, "alice", ["tacos"]})
      assert d2.stage.votes["alice"] == ["tacos"]
    end

    test "vote replaces previous selections" do
      d = dashboard_decision(votes: %{"alice" => ["tacos"]})
      {:ok, d2, _} = Core.handle(d, {:vote, "alice", ["pizza"]})
      assert d2.stage.votes["alice"] == ["pizza"]
    end

    test "vote with empty list clears user selections" do
      d = dashboard_decision()
      {:ok, d2, _} = Core.handle(d, {:vote, "alice", ["tacos"]})
      assert Map.get(d2.stage.votes, "alice") == ["tacos"]

      {:ok, d3, _} = Core.handle(d2, {:vote, "alice", []})
      assert Map.get(d3.stage.votes, "alice") == []
    end

    test "vote for non-existent option ID rejected" do
      d = dashboard_decision()
      assert {:error, :invalid_option} = Core.handle(d, {:vote, "alice", ["nonexistent"]})
    end

    test "ready_dashboard rejected if user has 0 selections" do
      d = dashboard_decision()
      assert {:error, :no_vote} = Core.handle(d, {:ready_dashboard, "alice"})
    end

    test "ready_dashboard marks user ready" do
      d = dashboard_decision(votes: %{"alice" => ["tacos"], "bob" => ["tacos"]})
      {:ok, d2, _} = Core.handle(d, {:ready_dashboard, "alice"})
      assert "alice" in d2.stage.ready
    end

    test "all ready transitions to Complete with options sorted by vote count descending" do
      d =
        dashboard_decision(
          users: ["alice"],
          votes: %{"alice" => ["pizza"]}
        )

      {:ok, d2, _} = Core.handle(d, {:ready_dashboard, "alice"})
      assert %Stage.Complete{} = d2.stage
      assert hd(d2.stage.options).name == "pizza"
    end

    test "winner is set on complete stage" do
      d =
        dashboard_decision(
          users: ["alice"],
          votes: %{"alice" => ["tacos"]}
        )

      {:ok, d2, _} = Core.handle(d, {:ready_dashboard, "alice"})
      assert d2.stage.winner == "tacos"
    end

    test "tie in vote count preserves stable ordering" do
      d =
        dashboard_decision(
          users: ["alice"],
          votes: %{"alice" => ["tacos", "pizza"]}
        )

      {:ok, d2, _} = Core.handle(d, {:ready_dashboard, "alice"})
      assert %Stage.Complete{} = d2.stage
      assert length(d2.stage.options) == 2
    end

    test "all ready emits why_statement async_llm effect" do
      d =
        dashboard_decision(
          users: ["alice"],
          votes: %{"alice" => ["tacos"]}
        )

      {:ok, _d2, effects} = Core.handle(d, {:ready_dashboard, "alice"})

      assert Enum.any?(effects, fn
               {:async_llm, {:why_statement, _, _, _, _}} -> true
               _ -> false
             end)
    end

    test "dropped user does not block ready-up" do
      d =
        dashboard_decision(
          users: ["alice"],
          votes: %{"alice" => ["tacos"], "bob" => ["pizza"]}
        )

      {:ok, d2, _} = Core.handle(d, {:ready_dashboard, "alice"})
      assert %Stage.Complete{} = d2.stage
    end
  end

  # ---------------------------------------------------------------------------
  # Complete
  # ---------------------------------------------------------------------------

  describe "complete" do
    test "why_statement_result stored on complete stage" do
      stage = %Stage.Complete{options: [], winner: "tacos", why_statement: nil}
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:why_statement_result, "We chose tacos because..."})
      assert d2.stage.why_statement == "We chose tacos because..."
    end
  end

  # ---------------------------------------------------------------------------
  # Connected set
  # ---------------------------------------------------------------------------

  describe "connected set" do
    test "connect adds user to decision.connected" do
      d = decision()
      {:ok, d2, _} = Core.handle(d, {:connect, "alice"})
      assert "alice" in d2.connected
    end

    test "disconnect removes user from decision.connected" do
      d = decision(connected: connected(["alice"]))
      {:ok, d2, _} = Core.handle(d, {:disconnect, "alice"})
      refute "alice" in d2.connected
    end
  end

  # ---------------------------------------------------------------------------
  # Guards / catch-all
  # ---------------------------------------------------------------------------

  describe "guards" do
    test "handle returns error for message sent to wrong stage" do
      d = decision(stage: %Stage.Lobby{})
      assert {:error, _} = Core.handle(d, {:vote_scenario, "alice", "x"})
    end

    test "handle returns error for unknown message type" do
      d = decision(stage: %Stage.Lobby{})
      assert {:error, _} = Core.handle(d, {:totally_unknown, "foo"})
    end
  end
end
