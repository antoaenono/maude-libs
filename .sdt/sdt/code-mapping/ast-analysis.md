---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [sdt, traceability, code-mapping, ast, xref, automation]
parent: null
children: []
---

# SDF: Decision-to-Code Traceability

## Scenario

How should each SDT decision map to the source files it touches, so that decisions are traceable to code and vice versa?

## Pressures

### More

1. [M1] Bidirectional traceability - given a decision, find all affected code; given a file, find all decisions that shaped it
2. [M2] Impact analysis - when reconsidering a decision, know exactly which files would need to change
3. [M3] LLM context loading - an LLM working on code can load the relevant decisions automatically by matching file paths to decision mappings

### Less

1. [L1] Maintenance overhead - path mappings that drift from reality become misleading
2. [L2] Authoring friction - adding file paths to every decision increases scaffolding cost
3. [L3] False precision - overly specific paths break on refactors; overly broad globs are useless


## Decision

Automated AST/xref analysis: build tooling that parses the Elixir codebase (via `mix xref`, AST walking, or the `boundary` library) to automatically discover which files are affected by each decision

## Why(not)

In the face of **mapping SDT decisions to the source files they affect**,
instead of doing nothing
(**decisions and code exist in parallel with no explicit link; finding which decisions shaped a file requires manual search through the SDT corpus**),
we decided **to build automated analysis tooling that uses Elixir's AST, `mix xref graph`, and/or the `boundary` library to discover and maintain decision-to-file mappings**,
to achieve **always-accurate traceability that cannot drift from reality because it is computed from the code itself**,
accepting **significant tooling investment, heuristic imprecision in mapping decisions to code boundaries, and dependency on Elixir-specific analysis tools**.

## Points

### For

- [M1] Automated analysis produces mappings from code structure, not human memory; the mapping is always current
- [M2] `mix xref graph --source lib/maude_libs/decision/core.ex` reveals transitive dependencies; impact analysis follows the actual call graph, not a manually curated list
- [M3] LLM agents can run the analysis tool to get fresh mappings before editing; no stale globs
- [L1] Zero manual maintenance; mappings are recomputed on demand
- [L3] Analysis operates at the actual granularity of the code: modules, functions, call sites

### Against

- [L2] Significant upfront investment to build the analysis tooling; much more complex than adding a frontmatter field
- [L1] The mapping from "SDT decision" to "code boundary" requires heuristics; not every decision maps cleanly to a set of modules (e.g., "css-framework" affects assets/ and templates, which `mix xref` does not cover)
- [L3] Different decisions operate at different granularities: some are module-level (core-architecture), some are line-level (debounced-calls), some are cross-cutting (type-checking); a single analysis approach cannot capture all of them
- [M1] Elixir-specific tooling does not cover non-Elixir files (JS hooks, CSS, config files, Dockerfiles)

## Artistic

Let the compiler tell you what you touched.

## Evidence

Elixir ships with `mix xref` which can produce module-level and function-level dependency graphs. The `boundary` library by Sasa Juric adds compile-time boundary enforcement and visualization (`mix boundary.visualize`). Both tools operate on the Elixir AST and can produce machine-readable output. However, neither tool knows about SDT decisions - the gap is mapping from "a decision about debouncing" to "the modules that implement debouncing." This requires either: (a) annotations in code linking modules to decisions, (b) heuristics based on module names/paths matching SDT directory names, or (c) a manually seeded mapping that the tool validates and extends. Option (b) works well when SDT paths mirror code paths (state-machine/ -> lib/maude_libs/decision/) but breaks for cross-cutting decisions.

## Consequences

- [authoring] No manual path maintenance; tooling generates mappings automatically
- [tooling] New mix task or sdt.py subcommand that shells out to `mix xref` and parses output; significant development effort
- [traceability] Accurate for Elixir modules; incomplete for JS, CSS, config, and cross-cutting concerns
- [dx] Developers and LLMs get computed mappings; always fresh but may miss non-Elixir files

## Implementation

### Architecture

```
SDT Decision          Mapping Layer              Codebase
+----------------+    +-------------------+      +------------------+
| core-arch.md   | -> | Heuristic Mapper  | <--- | mix xref graph   |
| touches: auto  |    | sdt-path -> module|      | boundary.visualize|
+----------------+    | + manual overrides|      | AST walk         |
                      +-------------------+      +------------------+
```

### Heuristic mapping

SDT paths are converted to likely module prefixes:

```elixir
# sdt_path_to_modules("state-machine/core-architecture")
# => [MaudeLibs.Decision.Core, MaudeLibs.Decision.Server]

# sdt_path_to_modules("testing/mocks")
# => [MaudeLibs.LLM, MaudeLibs.LLM.MockBehaviour] + test/**/*_test.exs

# sdt_path_to_modules("interface/layout")
# => [MaudeLibsWeb.*, assets/js/hooks/*]
```

### mix xref integration

```bash
# Get all callers of a module
mix xref graph --sink MaudeLibs.Decision.Core --format stats

# Get all dependencies of a module
mix xref graph --source lib/maude_libs/decision/core.ex
```

### boundary library integration

```elixir
# In lib/maude_libs.ex
use Boundary, deps: [], exports: [Decision, Decision.Core, Decision.Server]

# mix boundary.visualize generates a graphviz dot file showing module boundaries
```

### Hybrid approach

Start with manual `touches` globs in frontmatter (see sibling variant `manual-globs`), then validate and extend them using `mix xref`:

```bash
# Validate that manual touches match xref reality
python3 ~/.claude/skills/sdt/sdt.py xref-validate --sdt-root .sdt

# Output:
# state-machine/core-architecture: manual touches match xref graph
# state-machine/core-architecture: MISSING from touches: lib/maude_libs/decision/effects.ex (called by Core)
```

## Reconsider

- observe: The heuristic mapper produces too many false positives or false negatives
  respond: Fall back to manual globs with periodic xref validation; accept manual maintenance
- observe: Non-Elixir files (JS, CSS, config) are a significant portion of decision scope
  respond: Use manual globs for non-Elixir files; automated analysis only covers .ex/.exs
- observe: The `boundary` library is adopted project-wide
  respond: Use boundary definitions as the primary mapping mechanism; SDT decisions align with boundary groups

## Historic

Static analysis for dependency tracking is a mature field. Java has Jdeps, Go has `go vet` and module graphs, Rust has `cargo tree`. Elixir's `mix xref` was added in Elixir 1.3 and expanded significantly in later versions. Sasa Juric's `boundary` library (2020) added higher-level architectural boundary enforcement on top of `mix xref`. The idea of connecting architectural decisions to code boundaries automatically is less common - most ADR systems treat this as out of scope.

## More Info

- [mix xref documentation](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)
- [boundary library](https://github.com/sasa1977/boundary)
- [Sasa Juric: Towards Maintainable Elixir](https://medium.com/very-big-things/towards-maintainable-elixir-boundaries-ba013c731c0a)
