defmodule MaudeLibs.DecisionHelpersTest do
  use ExUnit.Case, async: true

  alias MaudeLibs.DecisionHelpers
  alias MaudeLibs.Decision.{Core, Stage}

  describe "unique_id/0" do
    test "returns a string" do
      assert is_binary(DecisionHelpers.unique_id())
    end

    test "returns unique values" do
      ids = for _ <- 1..10, do: DecisionHelpers.unique_id()
      assert length(Enum.uniq(ids)) == 10
    end
  end

  describe "at_lobby/2" do
    test "builds lobby with all users connected and joined" do
      d = DecisionHelpers.at_lobby(["alice", "bob"])
      assert %Core{} = d
      assert %Stage.Lobby{} = d.stage
      assert "alice" in d.connected
      assert "bob" in d.connected
      assert "alice" in d.stage.joined
      assert "bob" in d.stage.joined
      assert d.creator == "alice"
    end

    test "accepts topic option" do
      d = DecisionHelpers.at_lobby(["alice"], topic: "dinner?")
      assert d.topic == "dinner?"
    end

    test "accepts id option" do
      d = DecisionHelpers.at_lobby(["alice"], id: "custom-id")
      assert d.id == "custom-id"
    end
  end

  describe "at_scenario/2" do
    test "builds scenario stage with defaults" do
      d = DecisionHelpers.at_scenario(["alice"])
      assert %Stage.Scenario{} = d.stage
      assert d.topic == "Where should we eat?"
    end

    test "builds scenario stage with topic" do
      d = DecisionHelpers.at_scenario(["alice"], topic: "Where to eat?")
      assert %Stage.Scenario{} = d.stage
      assert d.topic == "Where to eat?"
    end

    test "accepts submissions option" do
      d = DecisionHelpers.at_scenario(["alice"], submissions: %{"alice" => "custom"})
      assert d.stage.submissions == %{"alice" => "custom"}
    end
  end

  describe "at_priorities/2" do
    test "builds priorities stage" do
      d = DecisionHelpers.at_priorities(["alice", "bob"])
      assert %Stage.Priorities{} = d.stage
    end

    test "accepts priorities and confirmed options" do
      d =
        DecisionHelpers.at_priorities(["alice"],
          priorities: %{"alice" => %{text: "speed", direction: "+"}},
          confirmed: ["alice"]
        )

      assert d.stage.priorities["alice"].text == "speed"
      assert "alice" in d.stage.confirmed
    end
  end

  describe "at_options/2" do
    test "builds options stage with default priorities" do
      d = DecisionHelpers.at_options(["alice"])
      assert %Stage.Options{} = d.stage
      assert length(d.priorities) == 2
    end

    test "accepts custom assigned_priorities" do
      d = DecisionHelpers.at_options(["alice"], assigned_priorities: [%{id: "~1", text: "x"}])
      assert length(d.priorities) == 1
    end
  end

  describe "at_scaffolding/2" do
    test "builds scaffolding stage" do
      d = DecisionHelpers.at_scaffolding(["alice"])
      assert %Stage.Scaffolding{} = d.stage
    end
  end

  describe "at_dashboard/2" do
    test "builds dashboard with default options" do
      d = DecisionHelpers.at_dashboard(["alice", "bob"])
      assert %Stage.Dashboard{} = d.stage
      assert length(d.stage.options) == 2
    end

    test "accepts votes option" do
      d = DecisionHelpers.at_dashboard(["alice"], votes: %{"alice" => ["Tacos"]})
      assert d.stage.votes["alice"] == ["Tacos"]
    end
  end

  describe "at_complete/2" do
    test "builds complete stage with winner" do
      d = DecisionHelpers.at_complete(["alice"], winner: "Tacos")
      assert %Stage.Complete{} = d.stage
      assert d.stage.winner == "Tacos"
    end

    test "why_statement defaults to nil" do
      d = DecisionHelpers.at_complete(["alice"])
      assert d.stage.why_statement == nil
    end
  end
end
