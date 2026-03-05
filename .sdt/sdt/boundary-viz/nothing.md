---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [sdt, visualization, boundaries, dependencies, architecture]
parent: null
children: []
---

# SDF: Automated Boundary and Dependency Visualization

## Scenario

Should we adopt tooling to automatically discover and visualize code boundaries, module dependencies, and how the program uses its dependencies, so that architectural diagrams stay grounded in the actual codebase?

## Pressures

### More

1. [M1] Architectural grounding - generated diagrams reflect the real dependency graph, not a human's mental model of it
2. [M2] Dependency awareness - developers and LLMs can see how modules depend on each other and where boundaries exist
3. [M3] Drift detection - automatically detect when code structure diverges from the architecture described in SDT decisions
4. [M4] Onboarding - new contributors can understand the system's structure from generated visualizations without reading every file

### Less

1. [L1] Tooling investment - building or integrating analysis tools requires development effort and ongoing maintenance
2. [L2] Noise - dependency graphs for non-trivial systems are large and overwhelming without careful filtering and layering
3. [L3] Elixir coupling - Elixir-specific tools (mix xref, boundary) do not cover JS hooks, CSS, or infrastructure files


## Decision

Do nothing: no automated boundary or dependency visualization; architecture is understood through code reading and SDT prose

## Why(not)

In the face of **adopting tooling to automatically visualize code boundaries and dependencies**,
instead of doing nothing
(**architectural understanding comes only from reading code and SDT prose; no automated way to see the dependency graph or detect structural drift**),
we decided **to do nothing**,
to achieve **no additional tooling complexity or maintenance burden**,
accepting **that architectural understanding remains manual and dependent on individual knowledge**.

## Points

### For

- [L1] Zero tooling investment; no new dependencies or mix tasks to maintain
- [L2] No risk of overwhelming developers with noisy auto-generated graphs

### Against

- [M1] Architecture diagrams (if any) are hand-drawn and may not reflect reality
- [M2] No visibility into cross-module dependencies without manually running `mix xref`
- [M3] No automated detection of architectural drift; violations are caught only in code review
- [M4] New contributors must read code to understand structure; no visual overview available

## Artistic

Read the code, all of it.

## Evidence

The current project has approximately 20 Elixir modules organized under lib/maude_libs/ and lib/maude_libs_web/. At this scale, a developer can hold the full architecture in their head. However, as the codebase grows and more decisions are made, the implicit understanding becomes fragile. Elixir already ships `mix xref` which can answer basic dependency questions, but it requires manual invocation and produces raw output that is not linked to SDT decisions.

## Consequences

- [tooling] No new tools, dependencies, or mix tasks
- [visualization] No generated diagrams; architecture lives in prose and code
- [enforcement] No compile-time boundary checks; cross-boundary calls are uncaught
- [dx] Developers rely on IDE navigation and grep to understand structure

## Implementation

No changes. Developers can manually run `mix xref graph` when needed.

## Reconsider

- observe: Cross-boundary calls proliferate and architectural layers erode
  respond: Adopt the `boundary` library for compile-time enforcement
- observe: The module count exceeds ~40 and new contributors struggle to understand the system
  respond: Generate dependency visualizations to provide an architectural overview
- observe: SDT decisions describe an architecture that no longer matches the code
  respond: Automated analysis would detect this drift

## Historic

Dependency visualization has been part of software engineering tooling since the 1990s (Graphviz, Doxygen call graphs). Language-specific tools emerged later: Java's Jdeps, Go's module graph, Rust's cargo-depgraph. Elixir's contribution is `mix xref` (built-in since 1.3) and Sasa Juric's `boundary` library (2020) which adds higher-level architectural enforcement.

## More Info

- [mix xref documentation](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)
- [boundary library](https://github.com/sasa1977/boundary)
