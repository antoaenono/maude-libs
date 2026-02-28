---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [architecture, state-machine, genserver]
parent: null
children: []
---

# SDT: Decision State Machine Architecture

## Scenario

How do we structure the decision state machine so it is testable, predictable, and easy to reason about under concurrent LiveView connections?

## Pressures

### More

1. [M1] Testability - pure functions are trivially testable without process setup
2. [M2] Predictability - concurrent LiveView messages must not corrupt state
3. [M3] Separation of concerns - business logic separate from I/O (PubSub, LLM, filesystem)

### Less

1. [L1] Boilerplate - two layers (Core + Server) instead of one
2. [L2] Indirection - tracing a bug requires looking in two modules

## Chosen Option

Pure Core + GenServer Shell: Core.handle/2 returns {:ok, decision, [effects]}, Server GenServer executes effects

## Why(not)

In the face of **structuring concurrent decision state management with LLM side effects**, instead of doing nothing (**inline GenServer handle_call with direct PubSub and LLM calls - hard to test, easy to corrupt**), we decided **to split into a pure Core module (no side effects, returns effect tuples) and a thin GenServer Shell that owns state and executes effects**, to achieve **a fully testable state machine where Core tests need no process setup and all concurrency is handled by the single-process GenServer mailbox**, accepting **an extra module and the overhead of threading effects through return values**.

## Points

### For

- [M1] Core tests: `Core.handle(decision, msg)` - no async, no mocking, just pure functions
- [M2] All state mutations flow through one GenServer process; BEAM serializes the mailbox
- [M3] Core has no imports of PubSub, Req, or Task; Shell has no business logic

### Against

- [L1] Two files instead of one; effect tuples add ceremony to every transition
- [L2] Debugging requires checking both Core (did the transition happen?) and Server (was the effect dispatched?)

## Artistic

<!-- author this yourself -->

## Consequences

- [arch] Core module: pure functions only, returns effect lists
- [arch] Server GenServer: owns state, pattern-matches effects, spawns Tasks for LLM
- [testing] Layer 1 tests call Core directly, no process setup needed

## How

```elixir
# Core.handle/2 - pure
def handle(%Decision{stage: %Lobby{}} = d, {:join, user}) do
  {:ok, %{d | stage: %{d.stage | joined: MapSet.put(d.stage.joined, user)}},
   [{:broadcast, d.id, d}]}
end

# Server - shell
def handle_call({:message, msg}, _from, %{decision: d} = state) do
  case Core.handle(d, msg) do
    {:ok, d2, effects} ->
      Enum.each(effects, &dispatch_effect/1)
      {:reply, :ok, %{state | decision: d2}}
    {:error, reason} ->
      {:reply, {:error, reason}, state}
  end
end
```

## Reconsider

- observe: Effect list grows complex (debounce + async_llm + broadcast in one transition)
  respond: Add effect priority ordering or a dedicated effect pipeline module

## Historic

The Elm architecture and Redux both popularized pure reducer + effect pattern. In Elixir, the GenServer provides the "store" and the Core provides the "reducer". This pattern is common in well-tested Phoenix applications.

## More Info

- [Saša Jurić: To spawn or not to spawn](https://www.theerlangelist.com/article/spawn_or_not)
