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

Do nothing - continue with `@callback` on the LLM behaviour and no other type annotations or checking

## Why(not)

In the face of **utilizing Elixir's type system to improve code quality**, instead of doing nothing (**we continue with `@callback` on the LLM behaviour and no other type annotations or checking; bugs that types would catch are found at runtime or in tests; no compile-time type feedback beyond pattern match warnings**), we decided **to do nothing**, to achieve **zero overhead and no ecosystem commitment**, accepting **that type-related bugs are only caught at runtime or by tests, and we get no compile-time type feedback**.

## Points

### For

- [L2] No investment in tooling that may fragment or be superseded
- [L3] No annotations to rewrite when the type syntax changes

### Against

- [M1] Type bugs are only caught at runtime or by tests, not at compile time
- [M2] No documentation of function contracts beyond `@callback` on one module
- [M3] Refactors have no type safety net
- [M4] Only the LLM behaviour boundary has any type enforcement

## Artistic

Ship it and see what breaks.

## Evidence

The current codebase has exactly one type boundary: `@callback` specs on `MaudeLibs.LLM`. Every other function has no type annotation. The gradual type system (active since Elixir 1.17) performs some inference during `mix compile`, but without explicit annotations or Dialyzer, the coverage is minimal. Type bugs are caught by tests or at runtime.

## Consequences

- [deps] No new dependencies
- [coverage] Only `@callback` on `MaudeLibs.LLM` provides any type contract
- [dx] No compile-time type feedback
- [migration] No work needed; no future migration debt

## How

Status quo. The only type annotations are `@callback` specs on the `MaudeLibs.LLM` behaviour. No `@spec` or `@type` elsewhere. No type checking tools.

## Reconsider

- observe: A type-related bug reaches production that specs or the compiler would have caught
  respond: Adopt at least `@spec` annotations on public APIs
- observe: Elixir's gradual type system reaches maturity (v1.21+)
  respond: Adopt it with minimal migration cost since there's nothing to convert

## Historic

Elixir projects have historically been dynamically typed with optional `@spec` annotations. Many production Elixir codebases run without Dialyzer or type annotations beyond behaviours.

## More Info

- [relevant link](https://example.com)
