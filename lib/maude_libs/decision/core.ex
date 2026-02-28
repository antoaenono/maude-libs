defmodule MaudeLibs.Decision.Core do
  @moduledoc """
  Pure state machine for decisions. No side effects.
  All functions return {:ok, decision, [effects]} or {:error, reason}.

  Effects are tuples the Server executes:
    {:broadcast, decision_id, decision}
    {:async_llm, call_spec}
    {:debounce, key, delay_ms, call_spec}
  """

  alias MaudeLibs.Decision.Stage

  defstruct id: nil,
            creator: nil,
            topic: nil,
            # Assigned priority list (populated when advancing Priorities -> Options)
            # [{id: "+1", text: "...", direction: "+"}, ...]
            priorities: [],
            connected: MapSet.new(),
            stage: %Stage.Lobby{}

  # ---------------------------------------------------------------------------
  # Lobby
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{stage: %Stage.Lobby{} = s} = d, {:lobby_update, _creator, topic, invited}) do
    s2 = %{s | invited: MapSet.new(invited)}
    d2 = %{d | topic: topic, stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  def handle(%__MODULE__{stage: %Stage.Lobby{} = s} = d, {:join, user}) do
    cond do
      user in s.joined ->
        {:error, :already_joined}

      user not in s.invited and user != d.id ->
        # Creator (d.id is the decision id, creator is whoever started it)
        # Creator is always allowed - we track creator as first in joined
        {:error, :not_invited}

      true ->
        s2 = %{s | joined: MapSet.put(s.joined, user)}
        d2 = %{d | connected: MapSet.put(d.connected, user), stage: s2}
        {:ok, d2, [{:broadcast, d2.id, d2}]}
    end
  end

  def handle(%__MODULE__{stage: %Stage.Lobby{} = s} = d, {:ready, user}) do
    if user not in s.joined do
      {:error, :not_joined}
    else
      s2 = %{s | ready: MapSet.put(s.ready, user)}
      {:ok, %{d | stage: s2}, [{:broadcast, d.id, %{d | stage: s2}}]}
    end
  end

  def handle(%__MODULE__{stage: %Stage.Lobby{} = s} = d, {:remove_participant, creator, user}) do
    cond do
      MapSet.size(s.joined) == 0 or creator not in s.joined ->
        {:error, :not_creator}

      user == creator ->
        {:error, :cannot_remove_self}

      true ->
        s2 = %{s |
          joined: MapSet.delete(s.joined, user),
          ready: MapSet.delete(s.ready, user),
          invited: MapSet.delete(s.invited, user)
        }
        d2 = %{d | connected: MapSet.delete(d.connected, user), stage: s2}
        {:ok, d2, [{:broadcast, d2.id, d2}]}
    end
  end

  def handle(%__MODULE__{stage: %Stage.Lobby{} = s} = d, {:start, creator}) do
    cond do
      creator not in s.joined ->
        {:error, :not_creator}

      not all_ready_lobby?(s) ->
        {:error, :not_all_ready}

      true ->
        scenario_stage = %Stage.Scenario{
          submissions: %{creator => d.topic || ""},
          votes: %{}
        }
        d2 = %{d | stage: scenario_stage}
        {:ok, d2, [{:broadcast, d2.id, d2}]}
    end
  end

  defp all_ready_lobby?(%Stage.Lobby{joined: joined, ready: ready}) do
    MapSet.size(joined) > 0 and MapSet.subset?(joined, ready)
  end

  # ---------------------------------------------------------------------------
  # Scenario
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{stage: %Stage.Scenario{} = s} = d, {:submit_scenario, user, text}) do
    s2 = %{s | submissions: Map.put(s.submissions, user, text)}
    d2 = %{d | stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}] ++ maybe_debounce_synthesis(s2)}
  end

  def handle(%__MODULE__{stage: %Stage.Scenario{} = s} = d, :synthesis_started) do
    s2 = %{s | synthesizing: true}
    d2 = %{d | stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  def handle(%__MODULE__{stage: %Stage.Scenario{} = s} = d, {:synthesis_result, text}) do
    s2 = %{s | synthesis: text, synthesizing: false}
    d2 = %{d | stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  def handle(%__MODULE__{stage: %Stage.Scenario{} = s} = d, {:vote_scenario, user, candidate}) do
    all_candidates = scenario_candidates(s)

    if candidate not in all_candidates do
      {:error, :invalid_candidate}
    else
      s2 = %{s | votes: Map.put(s.votes, user, candidate)}
      d2 = %{d | stage: s2}

      if unanimous?(d2) do
        winner = candidate
        priorities_stage = %Stage.Priorities{}
        d3 = %{d2 | stage: priorities_stage, topic: winner}
        {:ok, d3, [{:broadcast, d3.id, d3}]}
      else
        {:ok, d2, [{:broadcast, d2.id, d2}]}
      end
    end
  end

  defp scenario_candidates(%Stage.Scenario{submissions: subs, synthesis: synth}) do
    candidates = Map.values(subs)
    if synth, do: [synth | candidates], else: candidates
  end

  defp unanimous?(%__MODULE__{connected: connected, stage: %Stage.Scenario{votes: votes}}) do
    vote_values = Map.values(votes)
    MapSet.size(connected) > 0 and
      map_size(votes) == MapSet.size(connected) and
      length(Enum.uniq(vote_values)) == 1
  end

  defp maybe_debounce_synthesis(%Stage.Scenario{submissions: subs}) do
    # Synthesis only when >= 1 alternative exists (more than just creator's default)
    if map_size(subs) >= 2 do
      [{:debounce, :synthesis, 800, {:synthesize_scenario, Map.values(subs)}}]
    else
      []
    end
  end

  # ---------------------------------------------------------------------------
  # Priorities
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{stage: %Stage.Priorities{} = s} = d, {:upsert_priority, user, priority}) do
    s2 = %{s | priorities: Map.put(s.priorities, user, priority)}
    d2 = %{d | stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  def handle(%__MODULE__{stage: %Stage.Priorities{} = s} = d, {:confirm_priority, user}) do
    if not Map.has_key?(s.priorities, user) do
      {:error, :no_entry}
    else
      llm_effects = maybe_suggest_priorities(%{d | stage: %{s | confirmed: MapSet.put(s.confirmed, user)}})
      s2 = %{s | confirmed: MapSet.put(s.confirmed, user), suggesting: llm_effects != []}
      d2 = %{d | stage: s2}
      {:ok, d2, [{:broadcast, d2.id, d2}] ++ llm_effects}
    end
  end

  def handle(%__MODULE__{stage: %Stage.Priorities{} = s} = d, {:priority_suggestions_result, suggestions}) do
    s2 = %{s | suggestions: Enum.map(suggestions, &Map.put(&1, :included, false)), suggesting: false}
    d2 = %{d | stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  def handle(%__MODULE__{stage: %Stage.Priorities{} = s} = d, {:toggle_priority_suggestion, idx, included}) do
    if idx < 0 or idx >= length(s.suggestions) do
      {:error, :invalid_index}
    else
      suggestions = List.update_at(s.suggestions, idx, &Map.put(&1, :included, included))
      s2 = %{s | suggestions: suggestions}
      d2 = %{d | stage: s2}
      {:ok, d2, [{:broadcast, d2.id, d2}]}
    end
  end

  def handle(%__MODULE__{stage: %Stage.Priorities{} = s} = d, {:ready_priority, user}) do
    if not Map.has_key?(s.priorities, user) do
      {:error, :no_entry}
    else
      s2 = %{s | ready: MapSet.put(s.ready, user)}
      d2 = %{d | stage: s2}

      if all_ready?(d2.connected, s2.ready) do
        # Assign IDs to priorities: human proposals + included Claude suggestions
        claude_priorities = s2.suggestions |> Enum.filter(& &1.included) |> Enum.map(&Map.drop(&1, [:included]))
        assigned = assign_priority_ids(s2.priorities, claude_priorities)
        options_stage = %Stage.Options{}
        d3 = %{d2 | stage: options_stage, priorities: assigned}
        {:ok, d3, [{:broadcast, d3.id, d3}]}
      else
        {:ok, d2, [{:broadcast, d2.id, d2}]}
      end
    end
  end

  defp assign_priority_ids(priorities_map, extra \\ []) do
    # priorities_map: %{user => %{text: "...", direction: "+" | "-" | "~"}}
    # extra: [{text: "...", direction: "..."}] - included Claude suggestions
    # Returns [{id: "+1", text: "...", direction: "+"}, ...]
    all = Map.values(priorities_map) ++ extra
    groups = Enum.group_by(all, & &1.direction)

    Enum.flat_map(["+", "-", "~"], fn dir ->
      (groups[dir] || [])
      |> Enum.with_index(1)
      |> Enum.map(fn {p, i} -> %{id: "#{dir}#{i}", text: p.text, direction: dir} end)
    end)
  end

  defp maybe_suggest_priorities(%__MODULE__{connected: conn, stage: %Stage.Priorities{confirmed: confirmed, priorities: priorities}} = d) do
    if all_ready?(conn, confirmed) and map_size(priorities) > 0 do
      priority_list = Enum.map(priorities, fn {_user, p} -> p end)
      [{:async_llm, {:suggest_priorities, d.topic, priority_list}}]
    else
      []
    end
  end

  # ---------------------------------------------------------------------------
  # Options
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{stage: %Stage.Options{} = s} = d, {:upsert_option, user, option}) do
    s2 = %{s | proposals: Map.put(s.proposals, user, option)}
    d2 = %{d | stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  def handle(%__MODULE__{stage: %Stage.Options{} = s} = d, {:confirm_option, user}) do
    if not Map.has_key?(s.proposals, user) do
      {:error, :no_entry}
    else
      llm_effects = maybe_suggest_options(%{d | stage: %{s | confirmed: MapSet.put(s.confirmed, user)}})
      s2 = %{s | confirmed: MapSet.put(s.confirmed, user), suggesting: llm_effects != []}
      d2 = %{d | stage: s2}
      {:ok, d2, [{:broadcast, d2.id, d2}] ++ llm_effects}
    end
  end

  def handle(%__MODULE__{stage: %Stage.Options{} = s} = d, {:option_suggestions_result, suggestions}) do
    s2 = %{s | suggestions: Enum.map(suggestions, &Map.put(&1, :included, false)), suggesting: false}
    d2 = %{d | stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  def handle(%__MODULE__{stage: %Stage.Options{} = s} = d, {:toggle_option_suggestion, idx, included}) do
    if idx < 0 or idx >= length(s.suggestions) do
      {:error, :invalid_index}
    else
      suggestions = List.update_at(s.suggestions, idx, &Map.put(&1, :included, included))
      s2 = %{s | suggestions: suggestions}
      d2 = %{d | stage: s2}
      {:ok, d2, [{:broadcast, d2.id, d2}]}
    end
  end

  def handle(%__MODULE__{stage: %Stage.Options{} = s} = d, {:ready_options, user}) do
    if not Map.has_key?(s.proposals, user) do
      {:error, :no_entry}
    else
      s2 = %{s | ready: MapSet.put(s.ready, user)}
      d2 = %{d | stage: s2}

      if all_ready?(d2.connected, s2.ready) do
        # Collect all options: human proposals + included Claude suggestions
        human_options = Map.values(s2.proposals)
        claude_options = s2.suggestions |> Enum.filter(& &1.included) |> Enum.map(&Map.drop(&1, [:included]))
        all_options = human_options ++ claude_options

        # Assign priority IDs from priorities stage - stored in topic field temporarily
        priorities = get_priorities_with_ids(d2)

        scaffold_stage = %Stage.Scaffolding{}
        d3 = %{d2 | stage: scaffold_stage}
        {:ok, d3, [{:broadcast, d3.id, d3}, {:async_llm, {:scaffold, d3.topic, priorities, all_options}}]}
      else
        {:ok, d2, [{:broadcast, d2.id, d2}]}
      end
    end
  end

  defp maybe_suggest_options(%__MODULE__{connected: conn, stage: %Stage.Options{confirmed: confirmed, proposals: proposals}} = d) do
    if all_ready?(conn, confirmed) and map_size(proposals) > 0 do
      priorities = get_priorities_with_ids(d)
      option_list = Enum.map(proposals, fn {_user, o} -> o end)
      [{:async_llm, {:suggest_options, d.topic, priorities, option_list}}]
    else
      []
    end
  end

  # Gets priorities with assigned IDs from the stage - only relevant when called from Options
  # When advancing from Priorities -> Options, we store assigned priorities in a temp field
  # Actually priorities are re-derived; we need to pass them through. Let's store them on the decision.
  defp get_priorities_with_ids(%__MODULE__{} = d) do
    # Priorities were stored as %{user => %{text, direction}} in Stage.Priorities
    # They were assigned IDs when advancing to Options; we need them available in Options stage
    # We store the assigned priority list on the decision itself via the :priorities field
    Map.get(d, :priorities, [])
  end

  # ---------------------------------------------------------------------------
  # Scaffolding
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{stage: %Stage.Scaffolding{}} = d, {:scaffolding_result, options}) do
    dashboard_stage = %Stage.Dashboard{options: options}
    d2 = %{d | stage: dashboard_stage}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  # ---------------------------------------------------------------------------
  # Dashboard + Vote
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{stage: %Stage.Dashboard{} = s} = d, {:vote, user, option_names}) do
    valid_names = Enum.map(s.options, & &1.name)
    if Enum.all?(option_names, &(&1 in valid_names)) do
      s2 = %{s | votes: Map.put(s.votes, user, option_names)}
      d2 = %{d | stage: s2}
      {:ok, d2, [{:broadcast, d2.id, d2}]}
    else
      {:error, :invalid_option}
    end
  end

  def handle(%__MODULE__{stage: %Stage.Dashboard{} = s} = d, {:ready_dashboard, user}) do
    user_votes = Map.get(s.votes, user, [])

    if user_votes == [] do
      {:error, :no_vote}
    else
      s2 = %{s | ready: MapSet.put(s.ready, user)}
      d2 = %{d | stage: s2}

      if all_ready?(d2.connected, s2.ready) do
        # Sort options by vote count descending
        vote_counts = count_votes(s2)
        sorted_options = Enum.sort_by(s2.options, &(-Map.get(vote_counts, &1.name, 0)))
        winner = List.first(sorted_options)

        complete_stage = %Stage.Complete{
          options: sorted_options,
          winner: winner && winner.name,
          why_statement: nil
        }
        d3 = %{d2 | stage: complete_stage}
        effects = [
          {:broadcast, d3.id, d3},
          {:async_llm, {:why_statement, d3.topic, Map.get(d3, :priorities, []), winner && winner.name, vote_counts}}
        ]
        {:ok, d3, effects}
      else
        {:ok, d2, [{:broadcast, d2.id, d2}]}
      end
    end
  end

  defp count_votes(%Stage.Dashboard{votes: votes, options: options}) do
    base = Map.new(options, &{&1.name, 0})
    Enum.reduce(votes, base, fn {_user, selected}, acc ->
      Enum.reduce(selected, acc, fn name, acc2 ->
        Map.update(acc2, name, 1, &(&1 + 1))
      end)
    end)
  end

  # ---------------------------------------------------------------------------
  # Complete
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{stage: %Stage.Complete{} = s} = d, {:why_statement_result, text}) do
    s2 = %{s | why_statement: text}
    d2 = %{d | stage: s2}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  # ---------------------------------------------------------------------------
  # Connect / Disconnect (cross-stage, must come after all stage-specific clauses)
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{} = d, {:connect, user}) do
    {:ok, %{d | connected: MapSet.put(d.connected, user)}, [{:broadcast, d.id, d}]}
  end

  def handle(%__MODULE__{} = d, {:disconnect, user}) do
    d2 = %{d | connected: MapSet.delete(d.connected, user)}
    {:ok, d2, [{:broadcast, d2.id, d2}]}
  end

  # ---------------------------------------------------------------------------
  # Catch-all
  # ---------------------------------------------------------------------------

  def handle(%__MODULE__{stage: stage} = _d, msg) do
    {:error, {:wrong_stage_or_message, stage.__struct__, msg}}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp all_ready?(connected, ready) do
    MapSet.size(connected) > 0 and MapSet.subset?(connected, ready)
  end
end
