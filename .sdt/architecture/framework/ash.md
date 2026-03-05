---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [architecture, framework, domain-layer, ash, resources, actions, declarative]
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

Adopt Ash Framework: declarative resource definitions with domains, actions, policies, and derived APIs; coexists with the existing GenServer-based decision flow

## Why(not)

In the face of **choosing an application framework layer for resource and action management**,
instead of doing nothing
(**all domain logic is hand-written Phoenix contexts and Ecto queries; authorization is ad-hoc; no declarative resource modeling; each new resource requires manual CRUD, policy checks, and API wiring**),
we decided **to adopt Ash Framework for the resource/action layer, using Ash domains for resource grouping, Ash policies for authorization, and AshJsonApi/AshGraphql for API generation, while keeping the real-time decision flow in GenServers**,
to achieve **declarative domain modeling, unified authorization policies, automatic API derivation, and built-in multitenancy for org-scoped resources**,
accepting **significant learning curve, DSL complexity, framework lock-in, and the need to maintain two paradigms (Ash resources for CRUD, GenServers for real-time state)**.

## Points

### For

- [M1] Resources are declared, not hand-written: `use Ash.Resource` with `actions`, `attributes`, `relationships` blocks; CRUD operations generated automatically
- [M2] AshAuthentication provides user/account management; Ash policies provide declarative authorization (`authorize_if`, `forbid_if`) evaluated per-action
- [M3] Resource definitions are the domain model: attributes, relationships, validations, and policies in one place; serves as living documentation
- [M4] AshJsonApi and AshGraphql derive APIs from resource definitions; admin dashboards via AshAdmin
- [L2] Ash and GenServers coexist: Ash handles persistent resources (users, orgs, personas), GenServers handle real-time decision state; they interact at well-defined boundaries

### Against

- [L1] Ash's DSL is extensive; the learning curve is steep, and debugging requires understanding macro expansion and the Ash engine's internals
- [L1] Framework lock-in: migrating away from Ash would require rewriting every resource as a Phoenix context + Ecto schema
- [L2] Two paradigms in one codebase: Ash resources for CRUD, GenServers for real-time; developers must know when to use which
- [L3] The current prototype has ~2 resources; Ash's benefits materialize at ~5+ resources with policies and relationships
- [L1] Ash's macro-heavy approach can feel unlike writing Elixir; some community members find the DSL a departure from the language's philosophy

## Artistic

Declare the domain; derive the rest.

## Evidence

Ash Framework ranked #4 in the 2025 Elixir community survey (behind Phoenix, LiveView, Absinthe). It is designed for incremental adoption - Ash resources can coexist with plain Phoenix contexts in the same codebase. AshAuthentication provides user management, AshPolicies provides authorization, and AshAdmin provides admin dashboards - all derived from resource definitions. The key architectural question for this project is coexistence: the real-time decision flow (Core + Server GenServer pattern) is fundamentally stateful and event-driven, not CRUD. Ash would handle the surrounding infrastructure (users, orgs, personas, persistent decision records) while the GenServer handles the live decision process. The boundary between them is well-defined: Ash persists decisions after completion, GenServers manage decisions in progress.

## Consequences

- [deps] Add `{:ash, "~> 3.0"}`, `{:ash_postgres, "~> 2.0"}`, `{:ash_authentication, "~> 4.0"}`, `{:ash_json_api, "~> 1.0"}` plus related packages
- [domain] Resources declared via Ash DSL; domains group related resources; actions define operations
- [auth] Ash policies for authorization; AshAuthentication for user accounts
- [api] REST/GraphQL derived from resource definitions; AshAdmin for admin UI
- [migration] Existing hand-written contexts replaced incrementally with Ash resources

## Implementation

### Coexistence architecture

```
+---------------------------+    +---------------------------+
|  Ash Layer (CRUD)         |    |  GenServer Layer (live)    |
|                           |    |                           |
|  Users, Orgs, Personas    |    |  Decision.Core            |
|  Persistent Decisions     |    |  Decision.Server          |
|  Reconsideration Triggers |    |  Real-time state machine  |
|  Scoring Schemes          |    |                           |
+------------+--------------+    +------------+--------------+
             |                                |
             v                                v
        Ash.DataLayer                   GenServer state
        (PostgreSQL)                    (in-memory)
```

### Resource example

```elixir
defmodule MaudeLibs.Accounts.User do
  use Ash.Resource,
    domain: MaudeLibs.Accounts,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :username, :string, allow_nil?: false
    attribute :org_id, :uuid
  end

  relationships do
    belongs_to :org, MaudeLibs.Accounts.Org
    has_many :personas, MaudeLibs.Decisions.Persona
  end

  actions do
    defaults [:read, :destroy]
    create :register do
      accept [:username, :org_id]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end
    policy action_type(:destroy) do
      authorize_if relates_to_actor_via(:id)
    end
  end
end
```

### Domain grouping

```elixir
defmodule MaudeLibs.Accounts do
  use Ash.Domain

  resources do
    resource MaudeLibs.Accounts.User
    resource MaudeLibs.Accounts.Org
  end
end

defmodule MaudeLibs.Decisions do
  use Ash.Domain

  resources do
    resource MaudeLibs.Decisions.Persona
    resource MaudeLibs.Decisions.ReconsiderationTrigger
    resource MaudeLibs.Decisions.PersistentDecision
  end
end
```

### Bridge: Ash <-> GenServer

```elixir
# When a live decision completes, persist it via Ash
def handle_info({:decision_completed, decision}, state) do
  MaudeLibs.Decisions.PersistentDecision
  |> Ash.Changeset.for_create(:from_live, %{data: decision})
  |> Ash.create!()

  {:noreply, state}
end

# When loading a decision for review, read from Ash
Ash.read!(MaudeLibs.Decisions.PersistentDecision, filter: [id: id])
```

## Reconsider

- observe: The resource count stays under 5 and Ash feels like overhead
  respond: Remove Ash; revert to plain Phoenix contexts; the prototype didn't need a framework
- observe: Ash's DSL makes it harder for LLM agents to generate correct code
  respond: Evaluate whether Ash's official LLM tooling guidance resolves this; if not, plain Elixir may be more agent-friendly
- observe: The GenServer + Ash boundary creates confusion about where logic lives
  respond: Clarify the boundary explicitly: Ash for persistence and CRUD, GenServers for real-time state only
- observe: Ash 4.0 introduces breaking changes that require a large migration
  respond: Evaluate migration cost vs. benefits; framework lock-in is real

## Historic

Ash Framework was created by Zach Daniel and has grown into the most comprehensive application framework in the Elixir ecosystem. It takes inspiration from Ember Data (JavaScript), Active Record (Ruby), and Django's ORM, but applies Elixir's declarative, functional approach. Ash 3.0 (2024) renamed APIs to Domains and stabilized the DSL. The framework has received ongoing financial support since August 2025. It occupies a unique position in the Elixir ecosystem as the only framework that sits between Phoenix (web) and Ecto (database) to provide a full domain layer.

## More Info

- [Ash Framework documentation](https://hexdocs.pm/ash/get-started.html)
- [Ash Framework for Phoenix Developers](https://leanpub.com/ash-phoenix)
- [Ash official LLM development tooling](https://elixirforum.com/t/ash-framework-official-llm-development-tooling-and-guidance/70980)
- [Streamlining Development With Ash: A Real-World Adoption Story](https://www.elixirconf.eu/talks/streamlining-development-with-ash-a-real-world-adoption-story/)
