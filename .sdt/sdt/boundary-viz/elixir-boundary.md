---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: accepted
deciders: @antoaenono
tags: [sdt, visualization, boundaries, dependencies, elixir, boundary-lib]
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

Adopt the `boundary` library: define module boundaries that mirror SDT decision categories, with compile-time cross-boundary call enforcement and `mix boundary.visualize` for dependency diagrams

## Why(not)

In the face of **adopting tooling to automatically visualize code boundaries and dependencies**,
instead of doing nothing
(**architectural understanding comes only from reading code and SDT prose; no automated way to see the dependency graph or detect structural drift**),
we decided **to adopt Sasa Juric's `boundary` library to define module groups that mirror SDT decision categories, enforce cross-boundary dependency rules at compile time, and generate Graphviz visualizations with `mix boundary.visualize`**,
to achieve **compile-time architectural enforcement, auto-generated boundary diagrams grounded in real code, and explicit dependency declarations that serve as living documentation**,
accepting **a new dependency, annotation overhead in boundary modules, and no coverage for non-Elixir files**.

## Points

### For

- [M1] `mix boundary.visualize` generates Graphviz dot files from the actual module graph; diagrams are always accurate
- [M2] Boundary definitions (`use Boundary, deps: [...], exports: [...]`) make module dependencies explicit and visible in source code
- [M3] Compile-time warnings fire when code violates boundary rules; architectural drift is caught before merge
- [M4] Generated boundary diagrams provide a visual overview for new contributors; `mix boundary.visualize.mods` shows module-level detail
- [L2] Boundaries are layered by design: top-level boundaries show coarse structure, nested boundaries show fine detail; prevents information overload

### Against

- [L1] New dependency (`{:boundary, "~> 0.10"}`) plus `use Boundary` annotations in ~5-8 boundary-defining modules
- [L3] Only covers .ex/.exs files; JS hooks (assets/js/hooks/), CSS (assets/css/), config files, and Dockerfiles are invisible to boundary analysis
- [L1] Boundary rules must be maintained as modules are added; incorrect `deps` or `exports` cause false warnings
- [L2] At the current codebase size (~20 modules), boundary definitions may feel like ceremony; the value increases with scale

## Artistic

Walls make good neighbors; compilers make good walls.

## Evidence

The `boundary` library is maintained by Sasa Juric, author of "Elixir in Action" and a core contributor to the Elixir ecosystem. It integrates as a mix compiler, checking boundary rules during `mix compile` with zero runtime overhead. The library has been used in production at Very Big Things (now Citadel) and other Elixir shops. It produces Graphviz dot files that can be rendered to SVG/PNG. For this project, the natural boundary mapping is:

- `MaudeLibs` boundary: Decision, Core, Server, Stage structs (maps to state-machine/ SDTs)
- `MaudeLibs.LLM` boundary: LLM module, behaviours (maps to llm/ SDTs)
- `MaudeLibsWeb` boundary: LiveViews, controllers, components (maps to interface/ SDTs)
- `MaudeLibs.Realtime` boundary: PubSub, UserRegistry, invites (maps to realtime/ SDTs)

## Consequences

- [tooling] Add `{:boundary, "~> 0.10"}` to mix.exs; annotate ~5-8 modules with `use Boundary`
- [visualization] `mix boundary.visualize` generates Graphviz dot files; renderable to SVG for inclusion in tree.html or SDT diagrams
- [enforcement] Compile-time warnings for cross-boundary calls; CI catches architectural violations
- [dx] Boundary definitions serve as living documentation of architectural intent; LLMs can read them to understand system structure

## Implementation

### Dependency

```elixir
# mix.exs
defp deps do
  [
    {:boundary, "~> 0.10", runtime: false}
  ]
end

# mix.exs compilers
def project do
  [
    compilers: [:boundary] ++ Mix.compilers()
  ]
end
```

### Boundary definitions

```elixir
# lib/maude_libs.ex
defmodule MaudeLibs do
  use Boundary, deps: [], exports: [Decision, Decision.Core, Decision.Server]
end

# lib/maude_libs/llm.ex
defmodule MaudeLibs.LLM do
  use Boundary, deps: [], exports: [LLM]
end

# lib/maude_libs_web.ex
defmodule MaudeLibsWeb do
  use Boundary, deps: [MaudeLibs, MaudeLibs.LLM], exports: []
end
```

### Visualization

```bash
# Generate boundary-level Graphviz dot file
mix boundary.visualize

# Generate module-level dot file
mix boundary.visualize.mods

# Render to SVG
dot -Tsvg boundary.dot -o boundary.svg
```

### SDT integration

Boundary groups are named to mirror SDT categories. The `sdt.py` indexer can cross-reference boundary definitions with SDT decision paths:

```bash
# Map SDT decisions to boundary groups
# state-machine/* -> MaudeLibs boundary
# llm/* -> MaudeLibs.LLM boundary
# interface/* -> MaudeLibsWeb boundary
# realtime/* -> MaudeLibs boundary (Realtime sub-boundary)
```

## Reconsider

- observe: Boundary warnings are noisy and developers disable or ignore them
  respond: Reduce boundary granularity; use fewer, coarser boundaries that match the natural architecture
- observe: Non-Elixir files (JS hooks, CSS) are a significant source of architectural coupling
  respond: Supplement boundary with a custom tool that maps JS/CSS dependencies; or use manual globs (see sibling decision `sdt/code-mapping`) for non-Elixir files
- observe: The `boundary` library becomes unmaintained or incompatible with new Elixir versions
  respond: Fall back to `mix xref` with custom analysis scripts; lose compile-time enforcement but retain dependency graph extraction

## Historic

The `boundary` library was created by Sasa Juric in 2020 to address a gap in Elixir's tooling: while `mix xref` can answer "who calls whom," it cannot enforce architectural rules like "the web layer should not call the infrastructure layer directly." This is similar to ArchUnit (Java), go-arch-lint (Go), and Dependency Cruiser (JavaScript). The concept of enforcing architectural boundaries at compile time traces back to the layered architecture pattern and the Dependency Inversion Principle.

## More Info

- [boundary library on GitHub](https://github.com/sasa1977/boundary)
- [boundary documentation on HexDocs](https://hexdocs.pm/boundary/Boundary.html)
- [Sasa Juric: Towards Maintainable Elixir - Boundaries](https://medium.com/very-big-things/towards-maintainable-elixir-boundaries-ba013c731c0a)
- [mix xref documentation](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)
