defmodule MaudeLibs.DecisionHelpers do
  @moduledoc """
  Shared stage builders for tests and dev seed routes.
  Builds Decision.Core structs at any stage with configurable users.
  """

  alias MaudeLibs.Decision.{Core, Stage, Supervisor}

  def unique_id, do: "test-#{:erlang.unique_integer([:positive])}"

  # ---------------------------------------------------------------------------
  # Stage builders - return %Core{} structs
  # ---------------------------------------------------------------------------

  def at_lobby(users, opts \\ []) do
    [creator | _] = users
    topic = Keyword.get(opts, :topic, "")
    id = Keyword.get(opts, :id, unique_id())

    %Core{
      id: id,
      creator: creator,
      topic: topic,
      connected: MapSet.new(users),
      stage: %Stage.Lobby{
        invited: MapSet.new(users),
        joined: MapSet.new(users),
        ready: MapSet.new()
      }
    }
  end

  def at_scenario(users, opts \\ []) do
    topic = Keyword.get(opts, :topic, "Where should we eat?")
    submissions = Keyword.get(opts, :submissions, %{})

    %{
      at_lobby(users, opts)
      | topic: topic,
        stage: %Stage.Scenario{submissions: submissions, votes: %{}}
    }
  end

  def at_priorities(users, opts \\ []) do
    topic = Keyword.get(opts, :topic, "Where should we eat?")

    %{
      at_lobby(users, opts)
      | topic: topic,
        stage: %Stage.Priorities{
          priorities: Keyword.get(opts, :priorities, %{}),
          confirmed: MapSet.new(Keyword.get(opts, :confirmed, [])),
          suggestions: Keyword.get(opts, :suggestions, []),
          suggesting: false,
          ready: MapSet.new()
        }
    }
  end

  def at_options(users, opts \\ []) do
    topic = Keyword.get(opts, :topic, "Where should we eat?")

    priorities =
      Keyword.get(opts, :assigned_priorities, [
        %{id: "+1", text: "speed", direction: "+"},
        %{id: "-1", text: "cost", direction: "-"}
      ])

    %{
      at_lobby(users, opts)
      | topic: topic,
        priorities: priorities,
        stage: %Stage.Options{
          proposals: Keyword.get(opts, :proposals, %{}),
          confirmed: MapSet.new(Keyword.get(opts, :confirmed, [])),
          suggestions: Keyword.get(opts, :suggestions, []),
          suggesting: false,
          ready: MapSet.new()
        }
    }
  end

  def at_scaffolding(users, opts \\ []) do
    topic = Keyword.get(opts, :topic, "Where should we eat?")

    %{
      at_lobby(users, opts)
      | topic: topic,
        priorities: Keyword.get(opts, :assigned_priorities, []),
        stage: %Stage.Scaffolding{}
    }
  end

  def at_dashboard(users, opts \\ []) do
    topic = Keyword.get(opts, :topic, "Where should we eat?")

    options =
      Keyword.get(opts, :options, [
        %{
          name: "Tacos",
          desc: "Quick Mexican",
          for: [%{priority_id: "+1", text: "Fast service"}],
          against: [%{priority_id: "-1", text: "Expensive"}]
        },
        %{
          name: "Pizza",
          desc: "Classic Italian",
          for: [%{priority_id: "-1", text: "Cheap"}],
          against: [%{priority_id: "+1", text: "Slow delivery"}]
        }
      ])

    priorities =
      Keyword.get(opts, :assigned_priorities, [
        %{id: "+1", text: "speed", direction: "+"},
        %{id: "-1", text: "cost", direction: "-"}
      ])

    %{
      at_lobby(users, opts)
      | topic: topic,
        priorities: priorities,
        stage: %Stage.Dashboard{
          options: options,
          votes: Keyword.get(opts, :votes, %{}),
          ready: MapSet.new()
        }
    }
  end

  def at_complete(users, opts \\ []) do
    topic = Keyword.get(opts, :topic, "Where should we eat?")

    options =
      Keyword.get(opts, :options, [
        %{name: "Tacos", desc: "Quick Mexican", for: [], against: []},
        %{name: "Pizza", desc: "Classic Italian", for: [], against: []}
      ])

    %{
      at_lobby(users, opts)
      | topic: topic,
        priorities: Keyword.get(opts, :assigned_priorities, []),
        stage: %Stage.Complete{
          options: options,
          winner: Keyword.get(opts, :winner, "Tacos"),
          why_statement: Keyword.get(opts, :why_statement, nil)
        }
    }
  end

  # ---------------------------------------------------------------------------
  # Server helpers - start a GenServer with pre-built state
  # ---------------------------------------------------------------------------

  def seed_decision(stage, users, opts \\ []) do
    decision = build(stage, users, opts)
    {:ok, _pid} = Supervisor.start_with_state(decision)
    decision
  end

  defp build(:lobby, users, opts), do: at_lobby(users, opts)
  defp build(:scenario, users, opts), do: at_scenario(users, opts)
  defp build(:priorities, users, opts), do: at_priorities(users, opts)
  defp build(:options, users, opts), do: at_options(users, opts)
  defp build(:scaffolding, users, opts), do: at_scaffolding(users, opts)
  defp build(:dashboard, users, opts), do: at_dashboard(users, opts)
  defp build(:complete, users, opts), do: at_complete(users, opts)
end
