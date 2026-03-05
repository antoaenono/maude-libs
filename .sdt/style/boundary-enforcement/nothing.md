---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [style, boundaries, architecture, enforcement, elixir]
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

Do nothing: module boundaries are implicit, enforced only by convention and code review

## Why(not)

In the face of **enforcing architectural boundaries between module groups**,
instead of doing nothing
(**boundaries are implicit conventions; nothing prevents a LiveView from calling Decision.Core directly or an LLM module from importing web helpers; violations are caught only in code review if at all**),
we decided **to do nothing**,
to achieve **no additional annotation overhead or tooling complexity**,
accepting **that architectural boundaries remain conventions enforced only by discipline and review**.

## Points

### For

- [L1] Zero annotation overhead; modules are defined normally
- [L3] At ~20 modules, developers can hold the full architecture in their head; formal enforcement may be premature

### Against

- [M1] Nothing prevents `MaudeLibsWeb.DecisionLive` from calling `MaudeLibs.Decision.Core.handle/2` directly, bypassing the Server
- [M2] Boundary violations are invisible to the compiler; only caught if a reviewer notices
- [M3] The intended architecture exists only in SDT prose and developers' heads
- [M4] Refactoring a module's internals has no compiler-checked guarantee that external callers haven't coupled to internal functions

## Artistic

Trust the team; trust the review.

## Evidence

The current codebase uses an informal layered architecture: MaudeLibsWeb (web layer) calls MaudeLibs (business logic) which uses MaudeLibs.LLM (external service). This layering is maintained by convention. No violations have been observed yet, but the codebase is young. As the module count grows and more contributors (including LLM agents) write code, implicit boundaries become harder to maintain.

## Consequences

- [deps] No new dependencies
- [enforcement] None; boundaries exist only as conventions
- [dx] No compile-time feedback on architectural violations
- [onboarding] New contributors must learn boundaries from SDT docs or code review feedback

## Implementation

No changes. The existing module structure continues without boundary annotations.

## Reconsider

- observe: An LLM agent generates code that bypasses the Server and calls Core directly from a LiveView
  respond: This is exactly the class of violation boundaries would catch; adopt enforcement
- observe: Module count exceeds ~40 and cross-layer calls appear in PRs regularly
  respond: Formal boundaries would prevent these at compile time
- observe: A refactor of Core internals breaks a LiveView that was directly coupled to an internal function
  respond: Boundaries would have flagged the coupling before merge

## Historic

Implicit architectural boundaries are the default in most Elixir projects. The community relies on naming conventions (e.g., `MyApp` vs `MyAppWeb`), Phoenix contexts, and code review to maintain layering. This works well for small teams and small codebases but scales poorly.

## More Info

- [Phoenix contexts](https://hexdocs.pm/phoenix/contexts.html)
