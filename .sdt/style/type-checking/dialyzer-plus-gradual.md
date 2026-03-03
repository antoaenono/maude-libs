---
author: @antoaenono
asked: 2026-03-03
decided: 2026-03-03
status: accepted
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

Use both Dialyzer and the gradual type system during the transition period - maximum coverage now, converge to compiler-only when gradual types mature

## Why(not)

In the face of **utilizing Elixir's type system to improve code quality**, instead of doing nothing (**we continue with `@callback` on the LLM behaviour and no other type annotations or checking; bugs that types would catch are found at runtime or in tests; no compile-time type feedback beyond pattern match warnings**), we decided **to use both Dialyzer (with `@spec` annotations) and the compiler's gradual type system simultaneously**, to achieve **maximum type coverage during the transition period where neither tool alone catches everything**, accepting **the ecosystem fragmentation of maintaining two type checking approaches and the eventual need to migrate `@spec` syntax to gradual type signatures**.

## Points

### For

- [M1] Maximum bug detection: Dialyzer catches cross-dependency type issues the gradual system can't yet; gradual types catch within-module issues Dialyzer's success typing misses
- [M2] `@spec` annotations provide documentation now; gradual type signatures will provide documentation later
- [M3] Two layers of type safety during refactors
- [M4] Dialyzer validates `@callback` specs across module boundaries; gradual types validate within modules

### Against

- [L1] Two type checkers means two sources of potential false positives to manage
- [L2] Must reason about what each tool checks and where they overlap or conflict
- [L3] `@spec` annotations will need migration to new type syntax when it lands; double the transition work
- [L2] Developers must understand both systems and their respective coverage gaps

## Artistic

Every layer of defense counts.

## Evidence

In agentic code generation workflows, automated verification is critical - the more invariants the compiler and tools can check, the less you rely on the agent "just knowing" the right types. Dialyzer catches cross-dependency type issues and validates `@callback` specs today. The gradual type system catches within-module type mismatches at compile time. Together they provide the broadest type safety net available in the current Elixir ecosystem. The overhead of maintaining two tools is negligible with agentic tooling handling annotation generation. When the gradual type system reaches parity with Dialyzer (projected v1.21+), the transition to compiler-only is straightforward: drop Dialyxir, migrate `@spec` to new syntax.

## Consequences

- [deps] Adds `{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}`
- [coverage] Dialyzer covers cross-dependency and `@callback` specs; gradual types cover within-module inference
- [dx] Both `mix compile` and `mix dialyzer` provide type feedback; two tools to run
- [migration] Write `@spec` annotations now; migrate to gradual type syntax when available (v1.21+); eventually drop Dialyxir

## How

```elixir
# mix.exs
{:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}

# precommit runs both
precommit: [
  "compile --warnings-as-errors",  # gradual types checked here
  "dialyzer",                       # Dialyzer checked here
  # ...
]
```

Add `@spec` to public functions for Dialyzer. The gradual type system infers types automatically from the same code.

```elixir
@spec handle(Decision.t(), message()) :: {:ok, Decision.t(), [effect()]} | {:error, term()}
def handle(decision, message), do: ...
```

Both tools run on every precommit. As the gradual type system expands coverage, Dialyzer's value diminishes.

## Reconsider

- observe: Gradual type system (v1.21+) covers cross-dependency inference and typed structs
  respond: Dialyzer is now redundant; drop Dialyxir, migrate `@spec` to new type signatures
- observe: The two tools produce conflicting or confusing feedback on the same code
  respond: Prioritize compiler warnings; Dialyzer becomes supplementary
- observe: Maintaining `@spec` annotations for Dialyzer while the gradual system infers types feels like double work
  respond: Stop adding new `@spec` annotations; let existing ones serve Dialyzer until it's dropped

## Historic

Running both Dialyzer and the gradual type system simultaneously is a transitional pattern unique to 2024-2027 Elixir. Before the gradual type system, Dialyzer was the only option. After the gradual system matures, Dialyzer becomes unnecessary. This variant explicitly embraces the overlap period for maximum coverage.

## More Info

- [Dialyxir on Hex](https://hex.pm/packages/dialyxir)
- [Gradual set-theoretic types - Elixir v1.19](https://hexdocs.pm/elixir/gradual-set-theoretic-types.html)
- [Type inference of all constructs and the next 15 months](http://elixir-lang.org/blog/2026/01/09/type-inference-of-all-and-next-15/)
