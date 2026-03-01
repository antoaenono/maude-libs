defmodule MaudeLibs.LLM.Mock do
  @moduledoc """
  Mock LLM module for tests. Returns deterministic canned responses
  so integration tests never hit the real Anthropic API.
  """

  @behaviour MaudeLibs.LLM

  @impl true
  def synthesize_scenario(submissions) do
    # Pick the first submission as the synthesis, or a default
    text =
      case submissions do
        [first | _] -> first
        _ -> "How should we decide?"
      end

    {:ok, text}
  end

  @impl true
  def tagline(_scenario) do
    {:ok, "Decision Time"}
  end

  @impl true
  def suggest_priorities(_scenario, _priorities) do
    {:ok,
     [
       %{text: "freshness", direction: "+"},
       %{text: "distance", direction: "-"},
       %{text: "variety", direction: "~"}
     ]}
  end

  @impl true
  def suggest_options(_scenario, _priorities, _options) do
    {:ok,
     [
       %{name: "Sushi"},
       %{name: "Burgers"},
       %{name: "Salad"}
     ]}
  end

  @impl true
  def scaffold(_scenario, _priorities, options) do
    scaffolded =
      Enum.map(options, fn opt ->
        name = Map.get(opt, :name) || Map.get(opt, "name") || "Unknown"
        desc = Map.get(opt, :desc) || Map.get(opt, "desc") || ""

        %{
          name: name,
          desc: desc,
          for: [%{text: "Solid choice for the group", priority_id: "+1"}],
          against: [%{text: "May not suit everyone", priority_id: "-1"}]
        }
      end)

    {:ok, scaffolded}
  end

  @impl true
  def why_statement(_scenario, _priorities, winner, vote_counts) do
    total = vote_counts |> Map.values() |> Enum.sum()

    {:ok,
     "We decided on #{winner} after careful consideration of all priorities. " <>
       "With #{total} total votes cast, #{winner} best aligned with what the group valued most."}
  end
end
