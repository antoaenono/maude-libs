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

Add `@spec`/`@type` annotations and run Dialyxir (`mix dialyzer`) for static type analysis

## Why(not)


In the face of **utilizing Elixir's type system to improve code quality**,
instead of doing nothing
(**we continue with `@callback` on the LLM behaviour and no other type annotations or checking; bugs that types would catch are found at runtime or in tests; no compile-time type feedback beyond pattern match warnings**),
we decided **to add `@spec` annotations and run Dialyxir for static type checking**,
to achieve **compile-time bug detection across module boundaries with zero false positives (success typing)**,
accepting **that Dialyzer is conservative and misses some bugs, PLT builds are slow on first run, and `@spec` syntax may be superseded by the gradual type system**.

## Points

### For

- [M1] Dialyzer catches type mismatches, unreachable code, and impossible pattern matches at analysis time
- [M2] `@spec` annotations document function contracts and are enforced by Dialyzer
- [M3] Dialyzer validates specs across module boundaries and into dependencies
- [M4] `@callback` specs (which we already have) are checked against implementations
- [L1] Success typing guarantees zero false positives - Dialyzer only reports definite bugs

### Against

- [L1] Success typing is conservative: many real bugs slip through because Dialyzer errs on the side of silence
- [L2] Dialyzer reads `@spec`/`@type` annotations; the gradual type system will use a different syntax - two systems to reason about
- [L3] `@spec` annotations invested now may need rewriting when gradual type signatures land (v1.21+)
- [M1] First PLT build is slow (minutes); subsequent runs are incremental

## Consequences

- [deps] Adds `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}` to mix.exs
- [coverage] All public functions annotated with `@spec`; Dialyzer checks entire project
- [dx] `mix dialyzer` provides static analysis feedback; first run builds PLT cache
- [migration] Moderate annotation effort now; specs may need syntax migration for gradual types later

## Evidence

Dialyzer's success typing approach guarantees zero false positives - if it reports an error, it is a real bug. The tradeoff is that it misses bugs that a more aggressive type checker would catch. First PLT build takes 2-3 minutes but is cached; incremental runs take seconds. Dialyxir is the most downloaded Elixir dev tool on Hex. However, the gradual type system is explicitly designed to replace Dialyzer, with `@spec`/`@type` annotations planned for deprecation once the new type signature syntax lands in v1.21+.

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

```elixir
# mix.exs
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}

# Add to precommit alias
precommit: [
  "compile --warnings-as-errors",
  "dialyzer",
  # ... existing steps
]
```

Add `@spec` to public functions:

```elixir
@spec handle(Decision.t(), message()) :: {:ok, Decision.t(), [effect()]} | {:error, term()}
def handle(decision, message), do: ...
```

First run builds the PLT (Persistent Lookup Table):

```bash
mix dialyzer --plt  # ~2-3 minutes first time, cached after
mix dialyzer        # seconds on subsequent runs
```

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: Gradual type system (v1.21+) covers everything Dialyzer does at compile time
  respond: Drop Dialyxir dependency, migrate `@spec` to new type signature syntax, rely on compiler
- observe: Dialyzer misses a bug that the gradual type system would have caught
  respond: Accept the limitation or supplement with the gradual type system in parallel
- observe: PLT builds slow down the development workflow
  respond: Only run Dialyzer in precommit/CI, not on every save

## Artistic

No false positives, no excuses.

## Historic

Dialyzer (DIscrepancy AnaLYZer for ERlang) was created by Kostis Sagonas at Uppsala University in the mid-2000s. It introduced "success typing," a novel approach that guarantees no false positives. Dialyxir is the Elixir wrapper that integrates it with Mix. It has been the standard static analysis tool for BEAM languages for nearly 20 years.

## More Info

- [Dialyxir on Hex](https://hex.pm/packages/dialyxir)
- [Typespecs - Elixir docs](https://hexdocs.pm/elixir/typespecs.html)
