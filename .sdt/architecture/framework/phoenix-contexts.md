---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [architecture, framework, domain-layer, phoenix, contexts]
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

Phoenix contexts with structured conventions: organize domain logic into context modules with consistent patterns for CRUD, authorization, and Ecto queries, using no additional framework

## Why(not)

In the face of **choosing an application framework layer for resource and action management**,
instead of doing nothing
(**all domain logic is hand-written Phoenix contexts and Ecto queries; authorization is ad-hoc; no declarative resource modeling; each new resource requires manual CRUD, policy checks, and API wiring**),
we decided **to use Phoenix's built-in context pattern with team-enforced conventions for consistent CRUD, policy checks, and query composition across all domain modules**,
to achieve **a structured domain layer using idiomatic Phoenix patterns without any additional framework dependency**,
accepting **that conventions are enforced by discipline and review, not by tooling, and that boilerplate grows linearly with resource count**.

## Points

### For

- [L1] Zero new dependencies; contexts are built into Phoenix and understood by all Elixir developers
- [L2] Contexts coexist naturally with the GenServer layer; the decision flow is already organized this way informally
- [M1] Context modules provide a public API surface for each domain area; internal modules are private by convention
- [M3] Well-organized contexts with consistent patterns serve as readable domain documentation
- [L3] Scales incrementally; add contexts as resources emerge, no upfront commitment

### Against

- [M1] Every new resource requires hand-writing a full context module with CRUD functions, changesets, and queries; boilerplate scales linearly
- [M2] No built-in authorization framework; policies are ad-hoc checks inside context functions or LiveViews, with no unified policy language
- [M3] Domain structure is implicit in code organization, not declarative; no way to query "what resources exist and how do they relate?" from the code itself
- [M4] No API generation; REST and GraphQL endpoints must be hand-built on top of contexts
- [M2] As policy complexity grows (org scoping, role-based access, persona permissions), scattered `if` checks in contexts become unmaintainable

## Artistic

The framework you already have.

## Evidence

Phoenix contexts are the standard Elixir approach to domain organization. The `mix phx.gen.context` generator scaffolds context modules with CRUD operations, Ecto schemas, and query functions. For small-to-medium applications, contexts provide sufficient structure. The pattern breaks down when authorization policy becomes complex (contexts accumulate policy checks that duplicate across functions), when multiple API surfaces are needed (each requires manual wiring), or when resource count exceeds ~10 (boilerplate becomes a maintenance burden). The Phoenix documentation explicitly positions contexts as a starting point, not a complete domain layer.

## Consequences

- [deps] No new dependencies
- [domain] Context modules group related Ecto schemas, changesets, and query functions behind a public API
- [auth] Authorization implemented as functions within contexts (e.g., `authorize_action/3`); no unified policy DSL
- [api] Manual endpoint implementation; no generation
- [migration] If a framework is adopted later, contexts provide a clean boundary for incremental migration

## Implementation

### Context structure

```elixir
# lib/maude_libs/accounts.ex - context module
defmodule MaudeLibs.Accounts do
  alias MaudeLibs.Accounts.{User, Org}
  alias MaudeLibs.Repo

  # CRUD
  def create_user(attrs), do: %User{} |> User.changeset(attrs) |> Repo.insert()
  def get_user!(id), do: Repo.get!(User, id)
  def list_users_for_org(org_id), do: Repo.all(from u in User, where: u.org_id == ^org_id)

  # Authorization
  def authorize(:delete_user, %User{} = actor, %User{} = target) do
    if actor.id == target.id or actor.role == :admin, do: :ok, else: {:error, :unauthorized}
  end
end
```

### Schema

```elixir
defmodule MaudeLibs.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :role, Ecto.Enum, values: [:member, :admin]
    belongs_to :org, MaudeLibs.Accounts.Org
    has_many :personas, MaudeLibs.Decisions.Persona
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :role, :org_id])
    |> validate_required([:username])
    |> unique_constraint(:username)
  end
end
```

### Convention: consistent context shape

All contexts follow the same function naming pattern:
- `create_<resource>(attrs)` - insert with changeset
- `get_<resource>!(id)` - fetch or raise
- `list_<resources>(filters)` - filtered queries
- `update_<resource>(resource, attrs)` - update with changeset
- `delete_<resource>(resource)` - delete
- `authorize(action, actor, target)` - policy check

### Coexistence with GenServer flow

```elixir
# GenServer handles live decisions
# Contexts handle persistence and CRUD for everything else
defmodule MaudeLibs.Decisions do
  # Persistent decision records (after completion)
  def persist_decision(decision_struct), do: ...
  def list_completed_decisions(user), do: ...

  # Personas, triggers, scoring - all context CRUD
  def create_persona(attrs), do: ...
  def list_personas_for_org(org_id), do: ...
end
```

## Reconsider

- observe: Authorization logic is duplicated across 4+ contexts with inconsistent patterns
  respond: Adopt a policy framework (BodyGuard, or move to Ash which includes policies)
- observe: Adding a REST API requires writing 20+ controller actions that mirror context functions
  respond: A framework with API generation (Ash) would eliminate this duplication
- observe: Context modules exceed 500 lines with many similar CRUD functions
  respond: The boilerplate has reached the threshold where a declarative framework pays for itself

## Historic

Phoenix contexts were introduced in Phoenix 1.3 (2017) by Chris McCord. They replaced the flat `web/models` directory with domain-grouped modules, inspired by Domain-Driven Design's bounded context concept. The community has debated their effectiveness - some find them sufficient for all project sizes, while others outgrow them and adopt frameworks like Ash. The generator (`mix phx.gen.context`) produces idiomatic starting points but does not enforce architectural rules.

## More Info

- [Phoenix contexts documentation](https://hexdocs.pm/phoenix/contexts.html)
- [Phoenix generators](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Context.html)
