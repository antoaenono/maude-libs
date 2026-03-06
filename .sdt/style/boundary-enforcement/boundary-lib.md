---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: accepted
deciders: @antoaenono
tags: [style, boundaries, architecture, enforcement, elixir, boundary-lib]
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

Adopt the `boundary` library: annotate top-level modules with `use Boundary` to define allowed dependencies and exports, enforced at compile time

## Why(not)

In the face of **enforcing architectural boundaries between module groups**,
instead of doing nothing
(**boundaries are implicit conventions; nothing prevents a LiveView from calling Decision.Core directly or an LLM module from importing web helpers; violations are caught only in code review if at all**),
we decided **to adopt Sasa Juric's `boundary` library, annotating ~5 top-level modules with `use Boundary` declarations that define allowed dependencies and public exports**,
to achieve **compile-time enforcement of architectural layering, where violations produce warnings that CI treats as errors**,
accepting **a new dependency, annotation overhead in boundary-defining modules, and the need to update boundary declarations when adding new module groups**.

## Points

### For

- [M1] `use Boundary, deps: [MaudeLibs], exports: []` on `MaudeLibsWeb` makes it a compile error for web modules to call LLM directly; they must go through `MaudeLibs`
- [M2] `mix compile` emits warnings for every cross-boundary violation; CI with `--warnings-as-errors` prevents merge
- [M3] The `use Boundary` declaration at the top of a module is living documentation: "this module group depends on X and exposes Y"
- [M4] Changing a module's internals is safe if its exports remain unchanged; the compiler guarantees no external caller coupled to unexported functions
- [L3] Even at ~20 modules, boundary enforcement catches LLM agent mistakes that code review might miss

### Against

- [L1] ~5 modules need `use Boundary` annotations; each requires specifying `deps` and `exports` lists
- [L2] Legitimate cross-cutting concerns (e.g., a test helper that touches multiple boundaries) may need `check: [in: false, out: false]` escape hatches
- [L3] The codebase is small enough that a developer can verify boundaries manually; the tool adds structure that may feel like overhead
- [L1] New module groups require updating boundary declarations; forgetting causes false warnings

## Consequences

- [deps] Add `{:boundary, "~> 0.10", runtime: false}` to mix.exs
- [enforcement] Compile-time warnings for cross-boundary calls; CI treats warnings as errors
- [dx] Boundary declarations serve as living architecture documentation in source code
- [onboarding] New contributors see allowed dependencies at the top of each boundary module

## Evidence

The `boundary` library integrates as a mix compiler with zero runtime overhead. It has been used in production at Very Big Things (now Citadel) and is maintained by Sasa Juric, author of "Elixir in Action." The library reads `use Boundary` declarations and cross-references them against `mix xref` data to detect violations. For this project, the natural boundaries align with existing module naming:

| Boundary | Modules | Deps | Maps to SDTs |
|----------|---------|------|-------------|
| `MaudeLibs` | Decision, Core, Server, Stage.* | none | state-machine/* |
| `MaudeLibs.LLM` | LLM, LLM.MockBehaviour | none | llm/* |
| `MaudeLibsWeb` | LiveViews, controllers, components | MaudeLibs | interface/* |
| `MaudeLibs.Realtime` | PubSub helpers, UserRegistry | MaudeLibs | realtime/* |

The boundary structure mirrors the SDT decision tree, reinforcing the connection between architectural decisions and code structure.

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

### Dependency

```elixir
# mix.exs
defp deps do
  [
    {:boundary, "~> 0.10", runtime: false}
  ]
end

def project do
  [
    compilers: [:boundary] ++ Mix.compilers()
  ]
end
```

### Boundary declarations

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
  use Boundary, deps: [MaudeLibs], exports: []
end

# lib/maude_libs/realtime.ex (if introduced as a separate boundary)
defmodule MaudeLibs.Realtime do
  use Boundary, deps: [MaudeLibs], exports: [UserRegistry, CanvasServer]
end
```

### Key rules enforced

- `MaudeLibsWeb` can call `MaudeLibs` exports but not `MaudeLibs.LLM` directly
- `MaudeLibs` cannot call `MaudeLibsWeb` (no reverse dependency)
- `MaudeLibs.LLM` is standalone; only `MaudeLibs` (via Server's effect dispatch) calls it
- Internal modules (e.g., `Decision.Core`) are only accessible if listed in `exports`

### CI integration

```bash
# In CI pipeline - boundary violations fail the build
mix compile --warnings-as-errors
```

### Visualization (bonus)

```bash
# Generate boundary-level Graphviz dot file
mix boundary.visualize
dot -Tsvg boundary.dot -o boundary.svg

# Module-level detail
mix boundary.visualize.mods
```

As decided in `sdt/boundary-viz`, the Graphviz output provides auto-generated architecture diagrams grounded in actual code dependencies.

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: Boundary warnings are noisy for test support modules that legitimately cross boundaries
  respond: Add `check: [in: false, out: false]` to test support modules or define a `MaudeLibs.TestSupport` boundary with broad deps
- observe: The `boundary` library becomes incompatible with a future Elixir version
  respond: Fall back to `mix xref`-based custom checks; lose compile-time integration but retain boundary validation
- observe: Module count stays under 30 and no violations are ever caught
  respond: The overhead is minimal (5 annotations); keep it as a safety net even if it rarely fires
- observe: Elixir's gradual type system adds module-level visibility controls
  respond: Evaluate whether compiler-native visibility replaces the need for `boundary`; if so, migrate

## Artistic

The compiler is the best code reviewer.

## Historic

Module boundary enforcement has equivalents across ecosystems: Java's module system (Jigsaw, Java 9+), Go's internal packages, Rust's `pub(crate)` visibility, and ArchUnit for Java test-time enforcement. The `boundary` library brings this pattern to Elixir, operating at compile time via the mix compiler pipeline. It was created in 2020 to address the lack of module visibility controls in Elixir, where all public functions are callable from anywhere.

## More Info

- [boundary library on GitHub](https://github.com/sasa1977/boundary)
- [boundary documentation on HexDocs](https://hexdocs.pm/boundary/Boundary.html)
- [Sasa Juric: Towards Maintainable Elixir - Boundaries](https://medium.com/very-big-things/towards-maintainable-elixir-boundaries-ba013c731c0a)
