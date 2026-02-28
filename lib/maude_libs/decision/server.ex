defmodule MaudeLibs.Decision.Server do
  @moduledoc """
  GenServer shell wrapping Decision.Core.
  Owns state, executes effects returned by Core.handle/2.

  Effects:
    {:broadcast, id, decision}         - PubSub broadcast to all LiveViews
    {:async_llm, call_spec}            - spawn Task to call LLM, result sent back to server
    {:debounce, key, delay_ms, spec}   - cancel previous timer for key, schedule new one
  """
  use GenServer
  require Logger

  alias MaudeLibs.Decision.Core
  alias MaudeLibs.Decision.Stage

  @registry MaudeLibs.Decision.Registry

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via(id))
  end

  def child_spec(opts) do
    id = Keyword.fetch!(opts, :id)
    %{
      id: {__MODULE__, id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :temporary
    }
  end

  def whereis(id) do
    case Registry.lookup(@registry, id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  def get_state(id) do
    GenServer.call(via(id), :get_state)
  end

  def handle_message(id, msg) do
    GenServer.call(via(id), {:message, msg})
  end

  def disconnect(id, user) do
    case whereis(id) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:disconnect, user})
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer init
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    creator = Keyword.fetch!(opts, :creator)
    topic = Keyword.fetch!(opts, :topic)

    Logger.metadata(decision_id: id)
    Logger.info("decision started", creator: creator, topic: topic)

    # Build initial decision: creator is invited + auto-joined
    decision = %Core{
      id: id,
      topic: topic,
      connected: MapSet.new([creator]),
      stage: %Stage.Lobby{
        invited: MapSet.new([creator]),
        joined: MapSet.new([creator]),
        ready: MapSet.new()
      }
    }

    {:ok, %{decision: decision, timers: %{}}}
  end

  # ---------------------------------------------------------------------------
  # GenServer call/cast
  # ---------------------------------------------------------------------------

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.decision, state}
  end

  @impl true
  def handle_call({:message, msg}, _from, %{decision: d} = state) do
    Logger.metadata(decision_id: d.id, stage: stage_name(d.stage))
    Logger.debug("message received", action: elem(msg, 0))

    case Core.handle(d, msg) do
      {:ok, d2, effects} ->
        state2 = %{state | decision: d2}
        state3 = dispatch_effects(effects, state2)
        {:reply, :ok, state3}

      {:error, reason} ->
        Logger.warning("message rejected", reason: inspect(reason))
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:disconnect, user}, %{decision: d} = state) do
    Logger.metadata(decision_id: d.id, stage: stage_name(d.stage))
    Logger.info("user disconnected", user: user, connected_remaining: MapSet.size(d.connected) - 1)

    case Core.handle(d, {:disconnect, user}) do
      {:ok, d2, effects} ->
        state2 = %{state | decision: d2}
        state3 = dispatch_effects(effects, state2)
        {:noreply, state3}

      {:error, _} ->
        {:noreply, state}
    end
  end

  # Receive LLM result from async Task
  @impl true
  def handle_info({:llm_result, msg}, %{decision: d} = state) do
    Logger.metadata(decision_id: d.id, stage: stage_name(d.stage))
    Logger.info("llm result received", msg_type: elem(msg, 0))

    case Core.handle(d, msg) do
      {:ok, d2, effects} ->
        state2 = %{state | decision: d2}
        state3 = dispatch_effects(effects, state2)
        {:noreply, state3}

      {:error, reason} ->
        Logger.warning("llm result rejected by core", reason: inspect(reason))
        {:noreply, state}
    end
  end

  # Debounce timer fired
  @impl true
  def handle_info({:debounce_fire, key, call_spec}, %{timers: timers} = state) do
    state2 = %{state | timers: Map.delete(timers, key)}
    spawn_llm_task(call_spec, self())
    {:noreply, state2}
  end

  # ---------------------------------------------------------------------------
  # Effect dispatch
  # ---------------------------------------------------------------------------

  defp dispatch_effects(effects, state) do
    Enum.reduce(effects, state, &dispatch_effect/2)
  end

  defp dispatch_effect({:broadcast, id, decision}, state) do
    Logger.debug("broadcasting state", decision_id: id, stage: stage_name(decision.stage))
    Phoenix.PubSub.broadcast(MaudeLibs.PubSub, "decision:#{id}", {:decision_updated, decision})
    state
  end

  defp dispatch_effect({:async_llm, call_spec}, state) do
    Logger.info("llm call started", call: elem(call_spec, 0))
    spawn_llm_task(call_spec, self())
    state
  end

  defp dispatch_effect({:debounce, key, delay_ms, call_spec}, %{timers: timers} = state) do
    # Cancel previous timer for this key if it exists
    if prev = Map.get(timers, key) do
      Process.cancel_timer(prev)
    end

    ref = Process.send_after(self(), {:debounce_fire, key, call_spec}, delay_ms)
    %{state | timers: Map.put(timers, key, ref)}
  end

  defp spawn_llm_task(call_spec, server_pid) do
    Task.start(fn ->
      result_msg = execute_llm_call(call_spec)
      send(server_pid, {:llm_result, result_msg})
    end)
  end

  # Maps LLM call specs to MaudeLibs.LLM calls and converts results to Core messages
  defp execute_llm_call({:synthesize_scenario, submissions}) do
    case MaudeLibs.LLM.synthesize_scenario(submissions) do
      {:ok, text} -> {:synthesis_result, text}
      {:error, reason} ->
        Logger.error("llm call failed", call: :synthesize_scenario, reason: inspect(reason))
        {:synthesis_result, nil}
    end
  end

  defp execute_llm_call({:suggest_priorities, scenario, priorities}) do
    case MaudeLibs.LLM.suggest_priorities(scenario, priorities) do
      {:ok, suggestions} -> {:priority_suggestions_result, suggestions}
      {:error, reason} ->
        Logger.error("llm call failed", call: :suggest_priorities, reason: inspect(reason))
        {:priority_suggestions_result, []}
    end
  end

  defp execute_llm_call({:suggest_options, scenario, priorities, options}) do
    case MaudeLibs.LLM.suggest_options(scenario, priorities, options) do
      {:ok, suggestions} -> {:option_suggestions_result, suggestions}
      {:error, reason} ->
        Logger.error("llm call failed", call: :suggest_options, reason: inspect(reason))
        {:option_suggestions_result, []}
    end
  end

  defp execute_llm_call({:scaffold, scenario, priorities, options}) do
    case MaudeLibs.LLM.scaffold(scenario, priorities, options) do
      {:ok, scaffolded_options} -> {:scaffolding_result, scaffolded_options}
      {:error, reason} ->
        Logger.error("llm call failed", call: :scaffold, reason: inspect(reason))
        {:scaffolding_result, []}
    end
  end

  defp execute_llm_call({:why_statement, scenario, priorities, winner, vote_counts}) do
    case MaudeLibs.LLM.why_statement(scenario, priorities, winner, vote_counts) do
      {:ok, text} -> {:why_statement_result, text}
      {:error, reason} ->
        Logger.error("llm call failed", call: :why_statement, reason: inspect(reason))
        {:why_statement_result, nil}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp via(id), do: {:via, Registry, {@registry, id}}

  defp stage_name(stage), do: stage.__struct__ |> Module.split() |> List.last()
end
