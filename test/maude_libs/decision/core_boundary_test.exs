defmodule MaudeLibs.Decision.CoreBoundaryTest do
  use ExUnit.Case, async: true

  alias MaudeLibs.Decision.Core
  alias MaudeLibs.Decision.Stage

  # Helper to build a fresh decision
  defp decision(opts) do
    id = Keyword.get(opts, :id, "test-boundary")
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
  # Lobby boundary
  # ---------------------------------------------------------------------------

  describe "lobby_update" do
    test "updates topic and invited list" do
      stage = lobby_with(joined: ["alice"])
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:lobby_update, "alice", "new topic", ["bob", "charlie"]})
      assert d2.topic == "new topic"
      assert "bob" in d2.stage.invited
      assert "charlie" in d2.stage.invited
    end

    test "replaces existing invited set entirely" do
      stage = lobby_with(invited: ["bob"], joined: ["alice"])
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:lobby_update, "alice", "topic", ["charlie"]})
      refute "bob" in d2.stage.invited
      assert "charlie" in d2.stage.invited
    end
  end

  describe "lobby: remove also cleans invited" do
    test "removed user is removed from invited, joined, and ready" do
      stage = lobby_with(invited: ["alice", "bob"], joined: ["alice", "bob"], ready: ["bob"])
      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:remove_participant, "alice", "bob"})
      refute "bob" in d2.stage.invited
      refute "bob" in d2.stage.joined
      refute "bob" in d2.stage.ready
      refute "bob" in d2.connected
    end
  end

  describe "lobby: creator is decision.id user (first joiner)" do
    test "non-joined user cannot start" do
      stage = lobby_with(joined: ["alice"], ready: ["alice"])
      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :not_creator} = Core.handle(d, {:start, "bob"})
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario boundary
  # ---------------------------------------------------------------------------

  describe "scenario: synthesis_started flag" do
    test "synthesis_started sets synthesizing to true" do
      stage = %Stage.Scenario{submissions: %{"alice" => "A", "bob" => "B"}}
      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, :synthesis_started)
      assert d2.stage.synthesizing == true
    end

    test "synthesis_result clears synthesizing flag" do
      stage = %Stage.Scenario{
        submissions: %{"alice" => "A", "bob" => "B"},
        synthesizing: true
      }

      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:synthesis_result, "synthesized"})
      assert d2.stage.synthesizing == false
      assert d2.stage.synthesis == "synthesized"
    end
  end

  describe "scenario: topic propagation on unanimous vote" do
    test "winning scenario text becomes the new topic" do
      stage = %Stage.Scenario{
        submissions: %{"alice" => "where to eat?"},
        votes: %{}
      }

      d = decision(connected: connected(["alice"]), stage: stage, topic: "old topic")
      {:ok, d2, _} = Core.handle(d, {:vote_scenario, "alice", "where to eat?"})
      assert %Stage.Priorities{} = d2.stage
      assert d2.topic == "where to eat?"
    end
  end

  describe "scenario: user can change vote" do
    test "user changes vote before unanimity" do
      stage = %Stage.Scenario{
        submissions: %{"alice" => "A", "bob" => "B"},
        votes: %{"alice" => "A"}
      }

      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:vote_scenario, "alice", "B"})
      assert d2.stage.votes["alice"] == "B"
      # Still in scenario since bob hasn't voted
      assert %Stage.Scenario{} = d2.stage
    end
  end

  # ---------------------------------------------------------------------------
  # Priorities boundary
  # ---------------------------------------------------------------------------

  describe "priorities: toggle out-of-bounds index" do
    test "negative index rejected" do
      stage = %Stage.Priorities{
        suggestions: [%{text: "speed", direction: "+", included: false}]
      }

      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :invalid_index} = Core.handle(d, {:toggle_priority_suggestion, -1, true})
    end

    test "index equal to list length rejected" do
      stage = %Stage.Priorities{
        suggestions: [%{text: "speed", direction: "+", included: false}]
      }

      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :invalid_index} = Core.handle(d, {:toggle_priority_suggestion, 1, true})
    end

    test "index beyond list length rejected" do
      stage = %Stage.Priorities{suggestions: []}
      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :invalid_index} = Core.handle(d, {:toggle_priority_suggestion, 0, true})
    end
  end

  describe "priorities: multiple same-direction priorities get sequential IDs" do
    test "two + priorities get +1 and +2" do
      stage = %Stage.Priorities{
        priorities: %{
          "alice" => %{text: "speed", direction: "+"},
          "bob" => %{text: "quality", direction: "+"}
        },
        ready: MapSet.new(["bob"])
      }

      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:ready_priority, "alice"})
      assert %Stage.Options{} = d2.stage
      ids = Enum.map(d2.priorities, & &1.id)
      assert "+1" in ids
      assert "+2" in ids
    end

    test "mixed directions get correct IDs" do
      stage = %Stage.Priorities{
        priorities: %{
          "alice" => %{text: "speed", direction: "+"},
          "bob" => %{text: "cost", direction: "-"}
        },
        ready: MapSet.new(["bob"])
      }

      d = decision(connected: connected(["alice", "bob"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:ready_priority, "alice"})
      plus = Enum.find(d2.priorities, &(&1.direction == "+"))
      minus = Enum.find(d2.priorities, &(&1.direction == "-"))
      assert plus.id == "+1"
      assert minus.id == "-1"
    end

    test "included claude suggestions get IDs too" do
      stage = %Stage.Priorities{
        priorities: %{
          "alice" => %{text: "speed", direction: "+"}
        },
        suggestions: [
          %{text: "reliability", direction: "+", included: true},
          %{text: "cost", direction: "-", included: true},
          %{text: "ignored", direction: "~", included: false}
        ]
      }

      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:ready_priority, "alice"})

      plus_ids = d2.priorities |> Enum.filter(&(&1.direction == "+")) |> Enum.map(& &1.id)
      assert "+1" in plus_ids
      assert "+2" in plus_ids

      minus_ids = d2.priorities |> Enum.filter(&(&1.direction == "-")) |> Enum.map(& &1.id)
      assert ["-1"] = minus_ids

      # excluded suggestion should not appear
      tilde_ids = d2.priorities |> Enum.filter(&(&1.direction == "~")) |> Enum.map(& &1.id)
      assert tilde_ids == []
    end
  end

  describe "priorities: suggesting flag" do
    test "suggesting set to true when suggestions LLM effect fires" do
      d =
        decision(
          connected: connected(["alice"]),
          stage: %Stage.Priorities{
            priorities: %{"alice" => %{text: "cost", direction: "-"}}
          }
        )

      {:ok, d2, effects} = Core.handle(d, {:confirm_priority, "alice"})

      assert Enum.any?(effects, fn
               {:async_llm, {:suggest_priorities, _, _}} -> true
               _ -> false
             end)

      assert d2.stage.suggesting == true
    end

    test "suggesting cleared when suggestions result arrives" do
      d =
        decision(
          connected: connected(["alice"]),
          stage: %Stage.Priorities{suggesting: true}
        )

      {:ok, d2, _} =
        Core.handle(d, {:priority_suggestions_result, [%{text: "x", direction: "+"}]})

      assert d2.stage.suggesting == false
    end
  end

  # ---------------------------------------------------------------------------
  # Options boundary
  # ---------------------------------------------------------------------------

  describe "options: toggle out-of-bounds index" do
    test "negative index rejected" do
      stage = %Stage.Options{
        suggestions: [%{name: "pizza", desc: "y", included: false}]
      }

      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :invalid_index} = Core.handle(d, {:toggle_option_suggestion, -1, true})
    end

    test "index beyond list length rejected" do
      stage = %Stage.Options{suggestions: []}
      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :invalid_index} = Core.handle(d, {:toggle_option_suggestion, 0, true})
    end
  end

  describe "options: suggesting flag" do
    test "suggesting set to true when suggestions LLM effect fires" do
      d =
        decision(
          connected: connected(["alice"]),
          stage: %Stage.Options{
            proposals: %{"alice" => %{name: "tacos", desc: "x"}}
          },
          priorities: [%{id: "+1", text: "speed", direction: "+"}]
        )

      {:ok, d2, effects} = Core.handle(d, {:confirm_option, "alice"})

      assert Enum.any?(effects, fn
               {:async_llm, {:suggest_options, _, _, _}} -> true
               _ -> false
             end)

      assert d2.stage.suggesting == true
    end

    test "suggesting cleared when suggestions result arrives" do
      d =
        decision(
          connected: connected(["alice"]),
          stage: %Stage.Options{suggesting: true}
        )

      {:ok, d2, _} =
        Core.handle(d, {:option_suggestions_result, [%{name: "pizza", desc: "y"}]})

      assert d2.stage.suggesting == false
    end
  end

  describe "options: scaffold effect includes priorities" do
    test "scaffold effect carries priorities from decision" do
      assigned_priorities = [
        %{id: "+1", text: "speed", direction: "+"},
        %{id: "-1", text: "cost", direction: "-"}
      ]

      d =
        decision(
          connected: connected(["alice"]),
          stage: %Stage.Options{
            proposals: %{"alice" => %{name: "tacos", desc: "x"}}
          },
          priorities: assigned_priorities
        )

      {:ok, _d2, effects} = Core.handle(d, {:ready_options, "alice"})

      {:async_llm, {:scaffold, _topic, priorities, _options}} =
        Enum.find(effects, fn
          {:async_llm, {:scaffold, _, _, _}} -> true
          _ -> false
        end)

      assert priorities == assigned_priorities
    end
  end

  # ---------------------------------------------------------------------------
  # Dashboard boundary
  # ---------------------------------------------------------------------------

  describe "dashboard: vote for all options (approval voting)" do
    test "user can vote for every option" do
      options = [
        %{name: "tacos", desc: "x", for: [], against: []},
        %{name: "pizza", desc: "y", for: [], against: []},
        %{name: "sushi", desc: "z", for: [], against: []}
      ]

      stage = %Stage.Dashboard{options: options, votes: %{}}
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:vote, "alice", ["tacos", "pizza", "sushi"]})
      assert length(d2.stage.votes["alice"]) == 3
    end
  end

  describe "dashboard: mixed valid and invalid votes" do
    test "vote rejected if any option name is invalid" do
      options = [
        %{name: "tacos", desc: "x", for: [], against: []},
        %{name: "pizza", desc: "y", for: [], against: []}
      ]

      stage = %Stage.Dashboard{options: options, votes: %{}}
      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :invalid_option} = Core.handle(d, {:vote, "alice", ["tacos", "fake"]})
    end
  end

  describe "dashboard: vote count correctness" do
    test "winner has highest vote count" do
      options = [
        %{name: "tacos", desc: "x", for: [], against: []},
        %{name: "pizza", desc: "y", for: [], against: []}
      ]

      stage = %Stage.Dashboard{
        options: options,
        votes: %{
          "alice" => ["tacos"],
          "bob" => ["tacos"],
          "charlie" => ["pizza"]
        }
      }

      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:ready_dashboard, "alice"})
      assert %Stage.Complete{} = d2.stage
      assert d2.stage.winner == "tacos"
      assert hd(d2.stage.options).name == "tacos"
    end

    test "why_statement effect includes vote counts" do
      options = [
        %{name: "tacos", desc: "x", for: [], against: []},
        %{name: "pizza", desc: "y", for: [], against: []}
      ]

      stage = %Stage.Dashboard{
        options: options,
        votes: %{"alice" => ["tacos", "pizza"]}
      }

      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, _d2, effects} = Core.handle(d, {:ready_dashboard, "alice"})

      {:async_llm, {:why_statement, _topic, _priorities, winner, vote_counts}} =
        Enum.find(effects, fn
          {:async_llm, {:why_statement, _, _, _, _}} -> true
          _ -> false
        end)

      assert winner == "tacos"
      assert vote_counts["tacos"] == 1
      assert vote_counts["pizza"] == 1
    end
  end

  describe "dashboard: ready with empty list (cleared votes)" do
    test "ready rejected after clearing votes to empty" do
      options = [%{name: "tacos", desc: "x", for: [], against: []}]

      stage = %Stage.Dashboard{
        options: options,
        votes: %{"alice" => []}
      }

      d = decision(connected: connected(["alice"]), stage: stage)
      assert {:error, :no_vote} = Core.handle(d, {:ready_dashboard, "alice"})
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-stage connect/disconnect
  # ---------------------------------------------------------------------------

  describe "connect during non-lobby stages" do
    test "connect works during scenario stage" do
      stage = %Stage.Scenario{submissions: %{"alice" => "test"}}
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, d2, _} = Core.handle(d, {:connect, "bob"})
      assert "bob" in d2.connected
    end

    test "connect works during priorities stage" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Priorities{})
      {:ok, d2, _} = Core.handle(d, {:connect, "bob"})
      assert "bob" in d2.connected
    end

    test "connect works during dashboard stage" do
      options = [%{name: "tacos", desc: "x", for: [], against: []}]
      d = decision(connected: connected(["alice"]), stage: %Stage.Dashboard{options: options})
      {:ok, d2, _} = Core.handle(d, {:connect, "bob"})
      assert "bob" in d2.connected
    end

    test "connect works during complete stage" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Complete{})
      {:ok, d2, _} = Core.handle(d, {:connect, "bob"})
      assert "bob" in d2.connected
    end
  end

  describe "disconnect during non-lobby stages" do
    test "disconnect during scaffolding does not crash" do
      d = decision(connected: connected(["alice", "bob"]), stage: %Stage.Scaffolding{})
      {:ok, d2, _} = Core.handle(d, {:disconnect, "bob"})
      refute "bob" in d2.connected
    end
  end

  # ---------------------------------------------------------------------------
  # Broadcast effects
  # ---------------------------------------------------------------------------

  describe "every mutation emits broadcast" do
    test "lobby join emits broadcast" do
      stage = lobby_with(invited: ["bob"])
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, _, effects} = Core.handle(d, {:join, "bob"})
      assert Enum.any?(effects, &match?({:broadcast, _, _}, &1))
    end

    test "scenario submission emits broadcast" do
      stage = %Stage.Scenario{submissions: %{}}
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, _, effects} = Core.handle(d, {:submit_scenario, "alice", "test"})
      assert Enum.any?(effects, &match?({:broadcast, _, _}, &1))
    end

    test "priority upsert emits broadcast" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Priorities{})

      {:ok, _, effects} =
        Core.handle(d, {:upsert_priority, "alice", %{text: "x", direction: "+"}})

      assert Enum.any?(effects, &match?({:broadcast, _, _}, &1))
    end

    test "option upsert emits broadcast" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Options{})
      {:ok, _, effects} = Core.handle(d, {:upsert_option, "alice", %{name: "x", desc: "y"}})
      assert Enum.any?(effects, &match?({:broadcast, _, _}, &1))
    end

    test "dashboard vote emits broadcast" do
      options = [%{name: "tacos", desc: "x", for: [], against: []}]
      d = decision(connected: connected(["alice"]), stage: %Stage.Dashboard{options: options})
      {:ok, _, effects} = Core.handle(d, {:vote, "alice", ["tacos"]})
      assert Enum.any?(effects, &match?({:broadcast, _, _}, &1))
    end

    test "why_statement_result emits broadcast" do
      stage = %Stage.Complete{options: [], winner: "tacos", why_statement: nil}
      d = decision(connected: connected(["alice"]), stage: stage)
      {:ok, _, effects} = Core.handle(d, {:why_statement_result, "Because tacos."})
      assert Enum.any?(effects, &match?({:broadcast, _, _}, &1))
    end
  end

  # ---------------------------------------------------------------------------
  # Guard: wrong stage messages
  # ---------------------------------------------------------------------------

  describe "wrong stage messages" do
    test "lobby message during scenario" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Scenario{})
      assert {:error, _} = Core.handle(d, {:join, "bob"})
    end

    test "scenario message during priorities" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Priorities{})
      assert {:error, _} = Core.handle(d, {:submit_scenario, "alice", "text"})
    end

    test "priorities message during options" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Options{})

      assert {:error, _} =
               Core.handle(d, {:upsert_priority, "alice", %{text: "x", direction: "+"}})
    end

    test "options message during scaffolding" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Scaffolding{})
      assert {:error, _} = Core.handle(d, {:upsert_option, "alice", %{name: "x", desc: "y"}})
    end

    test "dashboard vote during complete" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Complete{})
      assert {:error, _} = Core.handle(d, {:vote, "alice", ["tacos"]})
    end

    test "scaffolding_result during lobby" do
      d = decision(connected: connected(["alice"]), stage: %Stage.Lobby{})
      assert {:error, _} = Core.handle(d, {:scaffolding_result, []})
    end
  end
end
