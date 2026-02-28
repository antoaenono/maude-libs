defmodule MaudeLibs.Decision.Stage do
  defmodule Lobby do
    @moduledoc "Creator sets topic, invites participants, everyone readies up."
    defstruct invited: MapSet.new(),
              joined: MapSet.new(),
              ready: MapSet.new()
  end

  defmodule Scenario do
    @moduledoc "Participants submit scenario rephrases; unanimous vote picks one."
    defstruct submissions: %{},
              synthesis: nil,
              votes: %{}
  end

  defmodule Priorities do
    @moduledoc """
    Participants submit 1 priority each (text + direction +/-/~).
    confirmed: MapSet of users who clicked Confirm (triggers Claude suggestions when all confirm).
    suggestions: [{text, direction, included}] - Claude-suggested priorities, toggleable.
    ready: MapSet of users ready to advance.
    """
    defstruct priorities: %{},
              confirmed: MapSet.new(),
              suggestions: [],
              ready: MapSet.new()
  end

  defmodule Options do
    @moduledoc """
    Participants submit 1 option each (name + desc).
    Same confirm/suggestions/ready pattern as Priorities.
    """
    defstruct proposals: %{},
              confirmed: MapSet.new(),
              suggestions: [],
              ready: MapSet.new()
  end

  defmodule Scaffolding do
    @moduledoc "LLM scaffold call in flight. No user input at this stage."
    defstruct []
  end

  defmodule Dashboard do
    @moduledoc """
    All options shown with for/against. Approval voting (min 1).
    votes: %{username => [option_name]}.
    ready: MapSet of users ready to advance.
    options: [%{name, desc, for, against}] populated from scaffolding result.
    """
    defstruct options: [],
              votes: %{},
              ready: MapSet.new()
  end

  defmodule Complete do
    @moduledoc "Decision complete. why_statement is LLM-generated, nil until it arrives."
    defstruct why_statement: nil,
              options: [],
              winner: nil
  end
end
