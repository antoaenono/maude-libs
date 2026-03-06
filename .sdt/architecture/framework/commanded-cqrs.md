---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [architecture, framework, domain-layer, commanded, cqrs, event-sourcing]
parent: null
children: []
---

# SDF: Application Framework Layer


## Scenario

Which application framework layer, if any, should sit between Phoenix and the domain logic to manage resources, actions, authorization, and domain boundaries?

## Pressures

### More

1. [M1] Resource management - as the app grows to include users, personas, orgs, persistent decisions, and reconsideration triggers, a structured resource/action layer reduces boilerplate
2. [M2] Authorization - multi-user features (invites, org-scoped personas, account-level defaults) need policy enforcement that scales beyond ad-hoc checks
3. [M3] Domain modeling - declarative resource definitions serve as living documentation of the domain and its relationships
4. [M4] API generation - future needs (REST, GraphQL, admin dashboards) benefit from a framework that derives APIs from resource definitions

### Less

1. [L1] Adoption cost - a framework layer adds learning curve, DSL complexity, and potential lock-in
2. [L2] Architectural mismatch - the real-time decision flow (Pure Core + GenServer Shell) is stateful and event-driven, not CRUD; a resource framework must coexist without replacing it
3. [L3] Premature abstraction - the current prototype has minimal resources; adopting a framework now may optimize for a future that doesn't arrive

## Decision

Adopt Commanded for CQRS/ES: commands and events as the domain layer, with event sourcing for decision history and projections for read models

## Why(not)

In the face of **choosing an application framework layer for resource and action management**,
instead of doing nothing
(**all domain logic is hand-written Phoenix contexts and Ecto queries; authorization is ad-hoc; no declarative resource modeling; each new resource requires manual CRUD, policy checks, and API wiring**),
we decided **to adopt Commanded, an Elixir CQRS/ES framework, using commands for write operations, domain events for state transitions, and projections for read models**,
to achieve **a natural fit with the event-driven decision flow, full audit trail via event sourcing, and temporal querying of decision history**,
accepting **significant complexity overhead, event store management, eventual consistency in read models, and a paradigm that is unfamiliar to most Elixir developers**.

## Points

### For

- [M1] Commands and events provide a structured resource/action layer: `CreateDecision`, `InviteParticipant`, `AdvanceStage` as explicit command structs
- [M3] Domain events serve as living documentation: the event log describes every state transition the system has ever made
- [L2] CQRS/ES is a natural fit for the existing event-driven architecture; the Pure Core + GenServer Shell pattern already emits effect tuples that resemble domain events
- [M1] Full audit trail: event sourcing records every mutation; decision history is first-class, supporting the thesis's reconsideration triggers and temporal analysis

### Against

- [L1] CQRS/ES is one of the most complex architectural patterns; the learning curve is steep even for experienced developers
- [L3] Massively premature for a prototype with ~2 resources; event sourcing adds infrastructure (event store, projections, process managers) before any business value
- [M2] Commanded does not provide built-in authorization; policies must be implemented separately in command handlers
- [M4] No API generation; REST/GraphQL endpoints must be built manually on top of read projections
- [L1] Event store management (EventStore or Postgres-backed) adds operational complexity

## Consequences

- [deps] Add `{:commanded, "~> 1.4"}`, `{:commanded_eventstore_adapter, "~> 1.4"}`, `{:eventstore, "~> 1.4"}`
- [domain] Commands, events, and aggregates replace contexts; read models via projections
- [auth] No built-in authorization; must be implemented in command handlers or middleware
- [api] No generated APIs; manual endpoint implementation on top of projections
- [migration] Existing code restructured into commands, events, aggregates, and projections

## Evidence

Commanded is an established Elixir library for CQRS/ES, maintained by Ben Smith. It provides command dispatch, aggregate roots, event handlers, and projections. The pattern fits naturally with the decision lifecycle described in the PrePR thesis: each decision mutation is an event, and the event log enables temporal analysis, reconsideration trigger evaluation, and "what happened and when" queries. However, CQRS/ES is widely regarded as one of the most over-applied patterns in software engineering. For this project, the event-driven nature of the decision flow is already captured by the Core + Server pattern with effect tuples; adding a full event sourcing layer on top would provide audit trail benefits but at significant complexity cost.

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

### Command and event example

```elixir
defmodule MaudeLibs.Commands.CreateDecision do
  defstruct [:decision_id, :creator, :scenario]
end

defmodule MaudeLibs.Events.DecisionCreated do
  defstruct [:decision_id, :creator, :scenario, :created_at]
end

defmodule MaudeLibs.Aggregates.Decision do
  defstruct [:id, :creator, :scenario, :stage]

  def execute(%__MODULE__{id: nil}, %CreateDecision{} = cmd) do
    %DecisionCreated{
      decision_id: cmd.decision_id,
      creator: cmd.creator,
      scenario: cmd.scenario,
      created_at: DateTime.utc_now()
    }
  end

  def apply(%__MODULE__{} = state, %DecisionCreated{} = event) do
    %{state | id: event.decision_id, creator: event.creator, scenario: event.scenario}
  end
end
```

### Coexistence with GenServer flow

The live decision GenServer emits events to the event store as side effects; projections build read models for historical queries:

```elixir
# In Server effect dispatch
defp dispatch_effect({:broadcast, id, decision}, state) do
  # Existing: PubSub broadcast
  Phoenix.PubSub.broadcast(...)
  # New: emit domain event to event store
  Commanded.dispatch(%DecisionStateChanged{...})
  state
end
```

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: The audit trail provided by event sourcing is not actually needed; no one queries historical decision state
  respond: Remove Commanded; the complexity is not justified by usage
- observe: Eventual consistency in projections causes confusion in the UI
  respond: Switch to synchronous projections or abandon CQRS/ES for a simpler approach
- observe: The event store becomes a maintenance burden (migrations, upgrades, backups)
  respond: Evaluate whether Ash with standard Ecto provides sufficient history tracking via timestamps and soft deletes

## Artistic

Every action leaves a trace.

## Historic

CQRS (Command Query Responsibility Segregation) was formalized by Greg Young in 2010. Event Sourcing stores state as a sequence of events rather than a current snapshot. Commanded brings these patterns to Elixir, built on top of EventStore. The pattern has been both praised for its audit trail and temporal query capabilities and criticized for its complexity overhead. Martin Fowler has cautioned that CQRS should only be applied to specific portions of a system, not used as a top-level architecture.

## More Info

- [Commanded on GitHub](https://github.com/commanded/commanded)
- [Commanded documentation](https://hexdocs.pm/commanded/getting-started.html)
- [Martin Fowler on CQRS](https://martinfowler.com/bliki/CQRS.html)
