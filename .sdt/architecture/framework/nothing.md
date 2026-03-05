---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: accepted
deciders: @antoaenono
tags: [architecture, framework, domain-layer, resources, actions]
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

### Non

1. [X1] Love

## Decision

Do nothing: Phoenix + Ecto directly, with hand-written contexts and ad-hoc authorization as needed

## Why(not)

In the face of **choosing an application framework layer for resource and action management**,
instead of doing nothing
(**all domain logic is hand-written Phoenix contexts and Ecto queries; authorization is ad-hoc; no declarative resource modeling; each new resource requires manual CRUD, policy checks, and API wiring**),
we decided **to do nothing and continue with plain Phoenix + Ecto**,
to achieve **minimal abstraction, full control over domain logic, and no framework learning curve**,
accepting **increasing boilerplate as resources multiply, ad-hoc authorization that doesn't scale, and manual API wiring for each new endpoint**.

## Points

### For

- [L1] Zero adoption cost; the team already knows Phoenix + Ecto
- [L2] The real-time decision flow (Core + Server) remains untouched; no framework compatibility concerns
- [L3] Appropriate for the current prototype scope; resources are minimal (sessions, decisions)
- [L1] Full control over every query, changeset, and policy; no DSL indirection

### Against

- [M1] Every new resource (users, personas, orgs, triggers) requires manual context modules, changesets, and controller/LiveView wiring
- [M2] Authorization logic will be scattered across controllers and LiveViews with no unified policy layer
- [M3] Domain structure is implicit in code organization; no declarative overview of resources and relationships
- [M4] Adding a REST API or admin dashboard requires building each endpoint from scratch

## Artistic

Build it yourself, until you can't.

## Evidence

The current prototype has two main "resources": session identity (cookie-based, no persistence) and decisions (ephemeral GenServer state). At this scale, Phoenix + Ecto is more than sufficient. However, the thesis (PrePR/ADR-SIMULATION) envisions a significantly larger domain: user accounts with org membership, static and dynamic personas with per-account default pressures, persistent decision records, executable reconsideration triggers, per-persona scoring schemes, and multi-tenant org configurations. That domain is resource-heavy, policy-heavy, and relationship-heavy - the kind of application where a framework layer pays for itself. The question is timing: adopt now and pay the learning cost before it's needed, or wait until the pain of hand-writing resources justifies the migration.

## Consequences

- [deps] No new dependencies
- [domain] Resources are hand-written Phoenix contexts with Ecto schemas
- [auth] Authorization is ad-hoc (inline checks in LiveViews and controllers)
- [api] No generated APIs; each endpoint is manually implemented
- [migration] When/if a framework is adopted later, existing contexts and schemas must be migrated

## Implementation

No changes. The current architecture continues:

```elixir
# Hand-written context
defmodule MaudeLibs.Decisions do
  def create(params), do: ...
  def get(id), do: ...
end

# Ad-hoc authorization in LiveView
def handle_event("advance", _, socket) do
  if socket.assigns.username in socket.assigns.decision.connected do
    # allowed
  end
end
```

## Reconsider

- observe: Adding users/accounts requires writing auth, registration, password reset, session management from scratch
  respond: A framework with built-in auth (e.g., Ash + AshAuthentication) would eliminate this boilerplate
- observe: Three or more resources need CRUD + policies + API endpoints and the hand-written code is mostly identical boilerplate
  respond: The pattern has emerged; a declarative framework would reduce it to resource definitions
- observe: Multi-tenancy (org-scoped data, per-org personas) requires pervasive query scoping
  respond: A framework with built-in multitenancy support would handle this systematically
- observe: The PrePR thesis features (personas, reconsideration triggers, dynamic scoring) move from theory to implementation
  respond: These are resource-heavy features that would benefit from a declarative framework layer

## Historic

Phoenix deliberately stays un-opinionated about the domain layer. Chris McCord has stated that Phoenix is a web framework, not an application framework - it handles HTTP, WebSockets, and rendering, but leaves domain logic to the developer. This is a deliberate design choice that prioritizes flexibility. Application frameworks like Ash, Ruby on Rails, Django, and Laravel take the opposite approach: they provide conventions and generators for the domain layer, trading flexibility for productivity.

## More Info

- [Phoenix contexts documentation](https://hexdocs.pm/phoenix/contexts.html)
- [Chris McCord on Phoenix philosophy](https://www.youtube.com/watch?v=tMO28ar0lW8)
