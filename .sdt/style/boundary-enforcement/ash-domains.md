---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [style, boundaries, architecture, enforcement, ash, domains]
parent: null
children: []
---

# SDF: Module Boundary Enforcement


## Scenario

How should we enforce architectural boundaries between module groups to prevent cross-layer coupling and dependency violations?

## Pressures

### More

1. [M1] Architectural integrity - prevent the web layer from reaching into state machine internals, or LLM modules from depending on LiveView
2. [M2] Compile-time feedback - catch boundary violations before merge, not in code review or production
3. [M3] Living documentation - boundary declarations in source code document the intended architecture alongside the code itself
4. [M4] Refactoring safety - explicit boundaries make it safe to restructure internals without accidentally breaking dependents

### Less

1. [L1] Annotation overhead - boundary declarations add ceremony to module definitions
2. [L2] False constraints - overly strict boundaries can block legitimate cross-cutting concerns and require workarounds
3. [L3] Scale mismatch - at ~20 modules, the codebase may not be large enough to justify formal boundary enforcement

## Decision

Ash Framework domains: organize resources into Ash Domains that serve as boundary modules, with resources only accessible through their domain's public API

## Why(not)

In the face of **enforcing architectural boundaries between module groups**,
instead of doing nothing
(**boundaries are implicit conventions; nothing prevents a LiveView from calling Decision.Core directly or an LLM module from importing web helpers; violations are caught only in code review if at all**),
we decided **to adopt Ash Framework and organize resources into Domains, where each domain registers its resources and serves as the exclusive API surface for that module group**,
to achieve **framework-enforced boundaries where resources must be registered to a domain and callers interact through the domain's API rather than calling resources directly**,
accepting **a major framework adoption that reshapes the entire application architecture far beyond boundary enforcement alone**.

## Points

### For

- [M1] Resources must be registered to a domain; calling a resource outside its domain's API is a convention violation that Ash tooling can flag
- [M3] Domain modules with `resources do ... end` blocks explicitly declare what belongs to each boundary - living documentation by design
- [M4] Domain APIs are the public surface; internal resource implementation can change freely as long as the domain API is stable
- [L2] Ash domains are more flexible than `boundary` - resources can be shared across domains via explicit configuration

### Against

- [M2] Ash domains do not produce compile-time warnings for boundary violations; enforcement is convention-based, similar to Phoenix contexts
- [L1] Ash introduces significant annotation overhead beyond boundary declarations: resource DSLs, action definitions, changeset logic
- [L3] Adopting an entire framework for boundary enforcement is disproportionate to the problem; Ash solves many problems this project does not have
- [L1] The existing Pure Core + GenServer Shell architecture (see `state-machine/core-architecture`) would need substantial reworking to fit Ash's resource/action model
- [M1] Ash's boundary enforcement is weaker than `boundary` - nothing prevents a module from calling a resource's functions directly, bypassing the domain

## Consequences

- [deps] Add `{:ash, "~> 3.0"}` plus related packages; significant dependency footprint
- [enforcement] Convention-based via domain registration; no compile-time violation detection
- [dx] Ash's domain/resource structure provides clear boundaries but requires learning the Ash DSL and resource patterns
- [onboarding] Steep learning curve; Ash is a full framework with its own conventions for actions, changesets, and queries

## Evidence

Ash Framework organizes applications into Domains (renamed from APIs in Ash 3.0). Each domain registers resources and exposes actions through `Ash.read/2`, `Ash.create/2`, etc. This provides structural boundaries: resources belong to domains, and the domain module is the intended entry point. However, unlike the `boundary` library, Ash does not emit compile-time warnings when code bypasses a domain and calls a resource directly. The boundary enforcement is architectural (resources are grouped) rather than enforced (violations are caught). Adopting Ash for this project would also require rethinking the core-architecture decision, since Ash has its own patterns for state management, actions, and side effects that differ from the Pure Core + GenServer Shell pattern currently in use.

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

### Domain structure

```elixir
# lib/maude_libs/decisions.ex
defmodule MaudeLibs.Decisions do
  use Ash.Domain

  resources do
    resource MaudeLibs.Decision
    resource MaudeLibs.Decision.Stage
  end
end

# lib/maude_libs/llm.ex
defmodule MaudeLibs.LLM do
  use Ash.Domain

  resources do
    resource MaudeLibs.LLM.Call
  end
end
```

### Resource definition

```elixir
defmodule MaudeLibs.Decision do
  use Ash.Resource, domain: MaudeLibs.Decisions

  actions do
    action :join, :struct do
      argument :user, :string, allow_nil?: false
      run fn input, _context ->
        # replaces Core.handle(decision, {:join, user})
      end
    end
  end
end
```

### Calling through domains

```elixir
# Callers use Ash API through the domain
Ash.run_action(MaudeLibs.Decision, :join, %{user: "alice"})

# NOT direct resource calls (convention, not enforced)
```

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: The project needs Ash's other features (data layer, authorization, API generation)
  respond: Ash adoption makes sense as a holistic decision, not just for boundaries; scaffold a separate SDT for framework choice
- observe: Ash's boundary enforcement remains convention-only with no compile-time checking
  respond: Layer `boundary` library on top of Ash domains for compile-time enforcement
- observe: The Pure Core + GenServer Shell architecture works well and Ash adoption would require a rewrite
  respond: Do not adopt Ash solely for boundaries; the architectural cost is too high

## Artistic

Bring a framework to a boundary fight.

## Historic

Ash Framework was created by Zach Daniel and has grown into a comprehensive application framework for Elixir. Domains (formerly APIs) were introduced as a way to group related resources and provide a public API surface. The concept draws from Domain-Driven Design's bounded contexts but implements them as a framework convention rather than a compiler-enforced boundary. Ash 3.0 (2024) renamed APIs to Domains to better align with DDD terminology.

## More Info

- [Ash Framework documentation](https://hexdocs.pm/ash/get-started.html)
- [Ash Domains documentation](https://hexdocs.pm/ash/Ash.Domain.html)
- [Ash Framework on GitHub](https://github.com/ash-project/ash)
