---
author: @antoaenono
asked: 2026-03-03
decided: 2026-03-03
status: rejected
deciders: @antoaenono
tags: [style, types, elixir, tooling]
parent: null
children: []
---

# SDF: Type Checking Strategy

## Scenario

How should we utilize Elixir's type system to improve code quality and catch bugs?

## Pressures

### More

1. [M1] Bug detection - catch type-related bugs before they reach production
2. [M2] Code documentation - type annotations serve as living documentation of function contracts
3. [M3] Refactoring confidence - type checking makes large refactors safer by catching breakage at compile time
4. [M4] API boundary safety - enforce correct types at module boundaries (behaviours, public APIs)

### Less

1. [L1] False positive noise - type checkers may flag correct code, requiring workarounds or suppressions
2. [L2] Ecosystem fragmentation - Dialyzer specs, gradual types, and Hammox all read different things; unclear which source of truth to invest in
3. [L3] Premature commitment - investing heavily in `@spec` annotations that may be replaced by new type syntax in v1.21+



## Decision

Add `@type` and `@spec` annotations to public functions for documentation, without running any enforcement tool

## Why(not)


In the face of **utilizing Elixir's type system to improve code quality**,
instead of doing nothing
(**we continue with `@callback` on the LLM behaviour and no other type annotations or checking; bugs that types would catch are found at runtime or in tests; no compile-time type feedback beyond pattern match warnings**),
we decided **to add `@type` and `@spec` annotations to public module APIs as living documentation**,
to achieve **self-documenting function contracts readable by developers and tooling (ExDoc, IDE hover)**,
accepting **that no tool enforces these specs, so they may drift from reality over time**.

## Points

### For

- [M2] `@spec` annotations document input/output types directly in the source code; picked up by ExDoc and IDE tooling
- [M4] Public API boundaries are explicitly typed even without enforcement
- [L1] No enforcement tool means no false positives to manage

### Against

- [M1] Specs are not checked - type bugs still only caught at runtime or in tests
- [M3] Unenforced specs can drift from actual code, giving false confidence during refactors
- [L3] `@spec` syntax may be superseded by gradual type syntax in v1.21+; annotations would need rewriting
- [L2] Specs are useful to Dialyzer and Hammox but we're not running either in this variant

## Artistic

Documentation that lies.

## Evidence

Unenforced `@spec` annotations are a known problem in the Elixir community. Without Dialyzer or another enforcement tool, specs drift from reality as code evolves. They provide value for IDE tooling (ElixirLS hover, ExDoc) but can mislead developers who trust them as guarantees. The gradual type system does not currently read `@spec` annotations - it infers types independently.

## Consequences

- [deps] No new dependencies
- [coverage] Public functions annotated with `@spec`; `@type` for custom types
- [dx] Better IDE hover and ExDoc output; no compile-time enforcement
- [migration] Moderate annotation effort; specs may need rewriting for gradual type syntax later

## Implementation

Add `@spec` to public functions in core modules:

```elixir
defmodule MaudeLibs.Decision.Core do
  @spec handle(Decision.t(), message()) :: {:ok, Decision.t(), [effect()]} | {:error, term()}
  def handle(decision, message) do
    # ...
  end
end
```

Define custom types with `@type`:

```elixir
@type effect() :: {:broadcast, String.t(), Decision.t()} | {:async_llm, term()}
@type message() :: {:submit_scenario, String.t(), String.t()} | ...
```

## Reconsider

- observe: Specs drift from actual code because nothing enforces them
  respond: Add Dialyzer to catch spec violations
- observe: Gradual type system (v1.21+) introduces new type signature syntax
  respond: Migrate `@spec` annotations to the new syntax; specs-only approach makes this straightforward

## Historic

`@spec` and `@type` annotations have been part of Elixir since 1.0, inherited from Erlang's `-spec`/`-type`. They're widely used for documentation even in projects that don't run Dialyzer.

## More Info

- [Typespecs - Elixir docs](https://hexdocs.pm/elixir/typespecs.html)
