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

# SDT: Type Checking Strategy

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

## Chosen Option

Lean into the compiler's gradual type system - let `mix compile` catch type errors, skip Dialyzer entirely

## Why(not)

In the face of **utilizing Elixir's type system to improve code quality**, instead of doing nothing (**we continue with `@callback` on the LLM behaviour and no other type annotations or checking; bugs that types would catch are found at runtime or in tests; no compile-time type feedback beyond pattern match warnings**), we decided **to rely on Elixir's built-in gradual type system, which infers types from existing code and checks them during `mix compile`**, to achieve **zero-config, compiler-native type checking that improves with each Elixir release**, accepting **that the current coverage (v1.19) is incomplete - no guard inference, no cross-dependency inference, no user-facing type signatures yet**.

## Points

### For

- [M1] The compiler already catches type mismatches within modules and against stdlib calls - no setup required
- [M3] Type inference runs on every `mix compile`; refactoring gets immediate feedback
- [L2] No fragmentation - one source of truth (the compiler), no separate tool
- [L3] No `@spec` annotations to write or later migrate - the compiler infers types from code

### Against

- [M1] Coverage is incomplete in v1.19: no guard inference, no cross-dependency checking
- [M2] No user-facing type annotation syntax yet - types are inferred but not documented
- [M4] Cross-module and cross-dependency type checking not available until v1.20+
- [L1] May produce false positives as the type system matures; new releases may surface new warnings

## Artistic

The compiler will catch up.

## Evidence

As of Elixir 1.19, the gradual type system infers types from all constructs except guards, within the same module and Elixir stdlib. Cross-dependency inference and guard types are coming in v1.20 (mid-2026). User-facing type signatures and typed structs are projected for v1.21-1.22 (late 2026-mid 2027). The system is already active on every `mix compile` with no configuration needed. Coverage improves automatically with each Elixir upgrade.

## Consequences

- [deps] No new dependencies - built into the compiler
- [coverage] Type inference within same module and stdlib; gaps at dependency boundaries
- [dx] Type errors surface during `mix compile` automatically; no separate tool to run
- [migration] No annotation work; coverage improves automatically with Elixir upgrades

## How

Already active. Elixir 1.17+ performs type inference during compilation. No configuration needed.

To see type warnings, ensure `--warnings-as-errors` is set (already in our precommit):

```elixir
precommit: [
  "compile --warnings-as-errors",
  # ...
]
```

As the type system matures, add type signatures when the syntax is available (v1.21+):

```elixir
# Future syntax (not yet available)
def handle(decision :: Decision.t(), message :: message()) :: {:ok, Decision.t(), [effect()]} | {:error, term()}
```

## Reconsider

- observe: v1.20 adds cross-dependency inference and guard types
  respond: Review warnings on upgrade; may surface new type issues in existing code
- observe: v1.21+ adds user-facing type signatures
  respond: Begin annotating public APIs with the new syntax for documentation and enforcement
- observe: The gradual type system misses bugs that Dialyzer would catch
  respond: Consider adding Dialyzer as a supplement until the gradual system reaches parity

## Historic

Elixir's gradual type system was introduced in v1.17 (2024), based on set-theoretic type theory developed by Giuseppe Castagna, Guillaume Duboc, and Jose Valim. It represents a fundamental shift from the Erlang-era optional `@spec` system to compiler-native type inference. Each release expands coverage, with full type signatures and typed structs projected for v1.21-1.22.

## More Info

- [Gradual set-theoretic types - Elixir v1.19](https://hexdocs.pm/elixir/gradual-set-theoretic-types.html)
- [Type inference of all constructs and the next 15 months](http://elixir-lang.org/blog/2026/01/09/type-inference-of-all-and-next-15/)
