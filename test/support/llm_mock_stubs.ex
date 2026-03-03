defmodule MaudeLibs.LLM.MockStubs do
  @moduledoc """
  Default Hammox stubs for the LLM behaviour. Provides the same
  deterministic canned responses as the old hand-rolled LLM.Mock module.

  Call `stub_all/0` in test setup to give all tests happy-path defaults.
  Individual tests can override with `Hammox.expect/3`.
  """

  @mock MaudeLibs.LLM.MockBehaviour

  def stub_all do
    Hammox.stub(@mock, :synthesize_scenario, fn submissions ->
      text =
        case submissions do
          [first | _] -> first
          _ -> "How should we decide?"
        end

      {:ok, text}
    end)

    Hammox.stub(@mock, :tagline, fn _scenario ->
      {:ok, "Decision Time"}
    end)

    Hammox.stub(@mock, :suggest_priorities, fn _scenario, _priorities ->
      {:ok,
       [
         %{text: "freshness", direction: "+"},
         %{text: "distance", direction: "-"},
         %{text: "variety", direction: "~"}
       ]}
    end)

    Hammox.stub(@mock, :suggest_options, fn _scenario, _priorities, _options ->
      {:ok,
       [
         %{name: "Sushi"},
         %{name: "Burgers"},
         %{name: "Salad"}
       ]}
    end)

    Hammox.stub(@mock, :scaffold, fn _scenario, _priorities, options ->
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
    end)

    Hammox.stub(@mock, :why_statement, fn _scenario, _priorities, winner, vote_counts ->
      total = vote_counts |> Map.values() |> Enum.sum()

      {:ok,
       "We decided on #{winner} after careful consideration of all priorities. " <>
         "With #{total} total votes cast, #{winner} best aligned with what the group valued most."}
    end)
  end
end
