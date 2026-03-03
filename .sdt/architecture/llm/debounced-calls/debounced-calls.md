---
author: @antoaenono
asked: 2026-03-02
decided: 2026-03-02
status: accepted
deciders: @antoaenono
tags: [llm, debounce, state-machine, ux]
parent: architecture/state-machine/core-architecture/core-architecture
children: []
---

# SDF: Debounced LLM Calls

## Scenario

When multiple participants submit scenario reframings in rapid succession, should each submission trigger a separate LLM synthesis call, or should we debounce?

## Pressures

### More

1. [M1] API cost - each synthesis call costs tokens; rapid-fire submissions would waste them
2. [M2] UX coherence - the synthesis should reflect all current submissions, not an outdated partial set
3. [M3] Responsiveness - users should see "Claude is thinking..." feedback promptly

### Less

1. [L1] Latency - debounce adds a delay before the LLM call fires
2. [L2] Complexity - timer management in the Server adds state (debounce timer refs)


### Non

1. [X1] Love

## Decision

800ms debounce: each new submission resets the timer; LLM call fires only after 800ms of quiet; managed via `{:debounce, key, delay_ms, call_spec}` effect

## Why(not)


In the face of **multiple participants submitting scenario text within seconds of each other**,
instead of doing nothing
(**fire an LLM call on every keystroke/submission, wasting tokens and producing stale results**),
we decided **to debounce synthesis calls with an 800ms quiet window, where each new submission resets the timer**,
to achieve **a single LLM call that sees all current submissions, fired only after participants pause**,
accepting **an 800ms delay before Claude starts thinking (imperceptible to users who are still typing)**.

## Points

### For

- [M1] One LLM call per quiet period instead of one per submission; saves tokens when 3 users submit within 2 seconds
- [M2] The call that fires sees all submissions, not just the first one
- [M3] `suggesting: true` flag set immediately on submission; "thinking" animation shows while timer counts down and LLM runs
- [L1] 800ms is shorter than the time it takes to read another participant's submission; feels instant

### Against

- [L2] Server tracks `debounce_timers: %{key => timer_ref}`; `Process.cancel_timer` + `Process.send_after` per debounce

## Artistic

<!-- author this yourself -->

## Consequences

- [effect] Core returns `{:debounce, :synthesis, 800, {:synthesize_scenario, submissions}}` on each scenario submission
- [server] Server cancels previous timer for the key, schedules new one; on expiry, dispatches the LLM call
- [config] `synthesis_debounce_ms` configurable (default 800, set to 0 in tests)
- [ux] "Claude is thinking" animation plays during both debounce wait and actual LLM call

## Implementation

```elixir
# Core - returns debounce effect
def handle(d, {:submit_scenario, user, text}) do
  d2 = %{d | stage: %{d.stage | submissions: Map.put(d.stage.submissions, user, text), synthesizing: true}}
  {:ok, d2, [
    {:broadcast, d.id, d2},
    {:debounce, :synthesis, @synthesis_debounce_ms,
     {:synthesize_scenario, Map.values(d2.stage.submissions)}}
  ]}
end

# Server - debounce dispatch
defp dispatch_effect({:debounce, key, delay_ms, call_spec}, state) do
  # Cancel previous timer for this key
  if ref = state.debounce_timers[key] do
    Process.cancel_timer(ref)
  end
  ref = Process.send_after(self(), {:debounce_fire, key, call_spec}, delay_ms)
  put_in(state, [:debounce_timers, key], ref)
end

def handle_info({:debounce_fire, _key, call_spec}, state) do
  # Spawn async LLM task
  dispatch_effect({:async_llm, call_spec}, state)
end
```

## Reconsider

- observe: 800ms feels sluggish when only one participant is submitting
  respond: Reduce to 300-500ms; or fire immediately if only one connected user has submitted
- observe: Debounce timer accumulates across stages (key collision)
  respond: Namespace keys by stage or clear all debounce timers on stage transition

## Historic

Debouncing is a standard UI pattern from mechanical switch engineering (hardware debounce). In software, it's ubiquitous for search-as-you-type, autosave, and API rate limiting. The 800ms value is in the range of typical search debounce (300-1000ms).

## More Info

- [Debounce and throttle explained](https://css-tricks.com/debouncing-throttling-explained-examples/)
