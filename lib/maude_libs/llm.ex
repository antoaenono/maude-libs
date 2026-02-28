defmodule MaudeLibs.LLM do
  @moduledoc """
  Thin wrapper around the Anthropic API. All functions are synchronous and
  called from async Tasks in Decision.Server.

  All calls use prompt-based JSON coercion per .sdt/llm/response-format.md.
  Each function strips possible ``` fences before parsing.
  """

  require Logger

  @model "claude-sonnet-4-6"
  @base_url "https://api.anthropic.com/v1/messages"
  @max_tokens 2048

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Synthesize multiple scenario submissions into one framing."
  def synthesize_scenario(submissions) when is_list(submissions) do
    prompt = """
    You are helping a group agree on a decision framing.

    These are the submitted scenario framings from different participants:
    #{Jason.encode!(%{submissions: submissions})}

    Synthesize these into a single neutral scenario framing that bridges all perspectives.
    Keep it concise (one sentence, question form preferred).

    Respond ONLY with valid JSON matching exactly this schema:
    {"synthesis": "string"}
    No markdown, no explanation, no code fences.
    """

    call(prompt, :synthesize_scenario)
    |> parse_field("synthesis")
  end

  @doc "Generate a short tagline for a canvas circle once scenario is agreed."
  def tagline(scenario) when is_binary(scenario) do
    prompt = """
    Generate a very short tagline (max 6 words) for this decision scenario:
    #{Jason.encode!(%{scenario: scenario})}

    Respond ONLY with valid JSON matching exactly this schema:
    {"tagline": "string"}
    No markdown, no explanation, no code fences.
    """

    call(prompt, :tagline)
    |> parse_field("tagline")
  end

  @doc "Suggest up to 3 additional priorities the group may have missed."
  def suggest_priorities(scenario, priorities) do
    prompt = """
    A group is making a decision. Here is their scenario and the priorities they've identified:
    #{Jason.encode!(%{scenario: scenario, priorities: priorities})}

    Suggest up to 3 additional priorities they may have missed.
    Each priority has:
    - text: the dimension name (e.g. "cost", "speed", "reliability") - NOT a directional statement
    - direction: "+" to maximize, "-" to minimize, "~" if relevant but not deciding

    Respond ONLY with valid JSON matching exactly this schema:
    {"suggestions": [{"text": "string", "direction": "+"|"-"|"~"}]}
    Return at most 3 suggestions. No markdown, no explanation, no code fences.
    """

    case call(prompt, :suggest_priorities) do
      {:ok, body} ->
        case body do
          %{"suggestions" => suggestions} when is_list(suggestions) ->
            parsed = Enum.map(suggestions, fn s ->
              %{text: s["text"], direction: s["direction"]}
            end)
            {:ok, parsed}
          _ ->
            {:error, :unexpected_shape}
        end
      err -> err
    end
  end

  @doc "Suggest up to 3 additional options the group may have missed."
  def suggest_options(scenario, priorities, options) do
    prompt = """
    A group is making a decision. Here is their context:
    #{Jason.encode!(%{scenario: scenario, priorities: priorities, options: options})}

    Suggest up to 3 additional options they may have missed.
    Each option has:
    - name: short name (2-4 words)
    - desc: one sentence description

    Respond ONLY with valid JSON matching exactly this schema:
    {"suggestions": [{"name": "string", "desc": "string"}]}
    Return at most 3 suggestions. No markdown, no explanation, no code fences.
    """

    case call(prompt, :suggest_options) do
      {:ok, body} ->
        case body do
          %{"suggestions" => suggestions} when is_list(suggestions) ->
            parsed = Enum.map(suggestions, fn s ->
              %{name: s["name"], desc: s["desc"]}
            end)
            {:ok, parsed}
          _ ->
            {:error, :unexpected_shape}
        end
      err -> err
    end
  end

  @doc """
  Generate for/against analysis for each option.
  The nothing option should already be included in the options list by the caller.
  """
  def scaffold(scenario, priorities, options) do
    prompt = """
    A group is making a decision. Analyze each option against the priorities.

    Context:
    #{Jason.encode!(%{scenario: scenario, priorities: priorities, options: options})}

    For each option, generate:
    - for: a list of reasons it addresses the priorities (tag each with the priority_id it addresses)
    - against: a list of concerns (tag each with the priority_id it conflicts with)

    Rules:
    - Only tag points with "+" or "-" priority IDs (e.g. "+1", "-2"). Do NOT tag "~" priorities.
    - 2-4 points for and 2-4 points against per option.
    - Each point must be a short phrase (5-10 words), not a full sentence.

    Respond ONLY with valid JSON matching exactly this schema:
    {
      "options": [
        {
          "name": "option name (must match input exactly)",
          "for": [{"text": "reason sentence", "priority_id": "+1"}],
          "against": [{"text": "concern sentence", "priority_id": "-1"}]
        }
      ]
    }
    No markdown, no explanation, no code fences.
    """

    case call(prompt, :scaffold) do
      {:ok, body} ->
        case body do
          %{"options" => scaffolded} when is_list(scaffolded) ->
            parsed = Enum.map(scaffolded, fn opt ->
              %{
                name: opt["name"],
                desc: find_desc(opt["name"], options),
                for: parse_points(opt["for"]),
                against: parse_points(opt["against"])
              }
            end)
            {:ok, parsed}
          _ ->
            {:error, :unexpected_shape}
        end
      err -> err
    end
  end

  @doc "Generate a why-statement paragraph summarizing the decision."
  def why_statement(scenario, priorities, winner, vote_counts) do
    prompt = """
    A group has completed a decision. Write a 2-3 sentence why-statement paragraph.

    Context:
    #{Jason.encode!(%{scenario: scenario, priorities: priorities, winner: winner, vote_counts: vote_counts})}

    The paragraph should:
    - Name the winner and explain why it was chosen relative to the priorities
    - Mention the vote counts briefly
    - Be written in past tense, first-person plural ("we decided...")

    Respond ONLY with valid JSON matching exactly this schema:
    {"why_statement": "2-3 sentence paragraph"}
    No markdown, no explanation, no code fences.
    """

    call(prompt, :why_statement)
    |> parse_field("why_statement")
  end

  # ---------------------------------------------------------------------------
  # Private: HTTP call
  # ---------------------------------------------------------------------------

  defp call(prompt, call_name) do
    api_key = Application.get_env(:maude_libs, :anthropic_api_key) ||
              System.get_env("ANTHROPIC_API_KEY")

    if is_nil(api_key) do
      Logger.error("anthropic_api_key not configured", call: call_name)
      {:error, :no_api_key}
    else
      Logger.info("llm call", call: call_name)

      body = %{
        model: @model,
        max_tokens: @max_tokens,
        messages: [%{role: "user", content: prompt}]
      }

      headers = [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ]

      case Req.post(@base_url, json: body, headers: headers) do
        {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
          Logger.info("llm call ok", call: call_name)
          parse_json(text)

        {:ok, %{status: status, body: body}} ->
          Logger.error("llm call failed", call: call_name, status: status, body: inspect(body))
          {:error, {:api_error, status}}

        {:error, reason} ->
          Logger.error("llm call error", call: call_name, reason: inspect(reason))
          {:error, reason}
      end
    end
  end

  defp parse_json(text) do
    # Strip possible ``` fences
    cleaned = text
    |> String.trim()
    |> strip_code_fences()

    case Jason.decode(cleaned) do
      {:ok, map} -> {:ok, map}
      {:error, _} ->
        Logger.warning("failed to parse llm json response", text: text)
        {:error, :parse_failed}
    end
  end

  defp strip_code_fences(text) do
    text
    |> String.replace(~r/^```(?:json)?\n?/, "")
    |> String.replace(~r/\n?```$/, "")
    |> String.trim()
  end

  defp parse_field({:ok, body}, field) do
    case body do
      %{^field => value} -> {:ok, value}
      _ -> {:error, :unexpected_shape}
    end
  end

  defp parse_field(err, _field), do: err

  defp parse_points(nil), do: []
  defp parse_points(points) when is_list(points) do
    Enum.map(points, fn p ->
      %{text: p["text"], priority_id: p["priority_id"]}
    end)
  end

  defp find_desc(name, options) do
    option = Enum.find(options, &(Map.get(&1, :name) == name or Map.get(&1, "name") == name))
    if option, do: Map.get(option, :desc) || Map.get(option, "desc") || "", else: ""
  end
end
