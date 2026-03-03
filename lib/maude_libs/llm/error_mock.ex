defmodule MaudeLibs.LLM.ErrorMock do
  @moduledoc """
  Mock LLM module that always returns errors.
  Used in tests to verify error handling paths.
  """

  @behaviour MaudeLibs.LLM

  @impl true
  def synthesize_scenario(_submissions), do: {:error, :api_down}

  @impl true
  def tagline(_scenario), do: {:error, :api_down}

  @impl true
  def suggest_priorities(_scenario, _priorities), do: {:error, :api_down}

  @impl true
  def suggest_options(_scenario, _priorities, _options), do: {:error, :api_down}

  @impl true
  def scaffold(_scenario, _priorities, _options), do: {:error, :api_down}

  @impl true
  def why_statement(_scenario, _priorities, _winner, _vote_counts), do: {:error, :api_down}
end
