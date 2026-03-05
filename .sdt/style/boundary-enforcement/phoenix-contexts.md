---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [style, boundaries, architecture, enforcement, phoenix, contexts]
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

Phoenix contexts only: rely on Phoenix's context module pattern to group related functions behind a public API, enforced by convention and code review

## Why(not)

In the face of **enforcing architectural boundaries between module groups**,
instead of doing nothing
(**boundaries are implicit conventions; nothing prevents a LiveView from calling Decision.Core directly or an LLM module from importing web helpers; violations are caught only in code review if at all**),
we decided **to use Phoenix's context pattern, grouping related functions behind context modules that serve as the public API for each domain**,
to achieve **a conventional boundary structure that follows the idiomatic Phoenix approach without additional dependencies**,
accepting **no compile-time enforcement; boundaries are still conventions, just better-organized ones**.

## Points

### For

- [M1] Context modules (e.g., `MaudeLibs.Decisions`) provide a public API; internal modules are "private by convention"
- [M3] The context module's public functions document the available operations for each domain
- [L1] No annotations, no dependencies; just a naming and organization convention
- [L3] Appropriate for the current codebase size; contexts add structure without ceremony

### Against

- [M2] No compile-time enforcement; a LiveView can still call `Decision.Core.handle/2` directly with no warning
- [M4] Refactoring internals has no compiler guarantee that no caller coupled to internal functions
- [M1] Convention enforcement depends entirely on code review discipline; LLM agents may not follow conventions
- [L2] Phoenix contexts can become "god modules" that expose too many functions, diluting the boundary

## Artistic

Convention over configuration, for better and worse.

## Evidence

Phoenix contexts are the idiomatic Elixir approach to grouping related functionality. The `mix phx.gen.context` generator scaffolds context modules with CRUD operations. However, contexts provide no enforcement - they are a naming convention. The Phoenix documentation explicitly notes that contexts are "not a hard boundary" and that developers are free to call internal modules directly. For a project using LLM agents to generate code, convention-only boundaries are risky because agents optimize for "make it work" over "follow the architecture."

## Consequences

- [deps] No new dependencies
- [enforcement] Convention only; no compile-time or runtime checks
- [dx] Context modules serve as API surfaces; internals are "private by naming"
- [onboarding] Standard Phoenix pattern; no new concepts to learn

## Implementation

### Context module structure

```elixir
# lib/maude_libs/decisions.ex - context module
defmodule MaudeLibs.Decisions do
  @moduledoc "Public API for decision operations"

  alias MaudeLibs.Decision.Server

  def create(params), do: Server.create(params)
  def message(id, msg), do: Server.message(id, msg)
  def get(id), do: Server.get(id)
end

# LiveViews call the context, not internals
defmodule MaudeLibsWeb.DecisionLive do
  # Good: MaudeLibs.Decisions.message(id, msg)
  # Bad:  MaudeLibs.Decision.Core.handle(decision, msg)
end
```

### Convention rules (enforced by review)

1. LiveViews call context modules only, never internal modules
2. Context modules delegate to Server; Server delegates to Core
3. Internal modules (Core, Stage structs) are not called from outside their context

## Reconsider

- observe: LLM agents bypass context modules and call Core directly
  respond: Convention is insufficient for automated contributors; adopt `boundary` for compile-time enforcement
- observe: Context modules grow large with many delegated functions
  respond: Split into sub-contexts or adopt `boundary` for more granular boundary definitions
- observe: Code review repeatedly catches the same boundary violations
  respond: Automated enforcement would eliminate this review burden

## Historic

Phoenix contexts were introduced in Phoenix 1.3 (2017) by Chris McCord as a way to organize application logic into domain-specific groups. They were inspired by Domain-Driven Design's bounded context concept but implemented as a lightweight convention rather than a strict boundary. The Phoenix community has debated the effectiveness of contexts as boundaries; some teams find them sufficient, while others adopt stricter tools like `boundary`.

## More Info

- [Phoenix contexts documentation](https://hexdocs.pm/phoenix/contexts.html)
- [Chris McCord on Phoenix 1.3 contexts](https://www.youtube.com/watch?v=tMO28ar0lW8)
