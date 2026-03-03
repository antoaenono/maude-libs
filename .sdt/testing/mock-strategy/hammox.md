---
author: @antoaenono
asked: 2026-03-02
decided: 2026-03-02
status: accepted
deciders: @antoaenono
tags: [testing, mocking, llm, elixir]
parent: null
children: []
---

# SDT: Test Mock Implementation Strategy

## Scenario

Which mock implementation strategy should we use for isolating external dependencies (LLM calls) in tests: hand-rolled mock modules or a library like Mox?

## Pressures

### More

1. [M1] Test isolation - each test should be able to define its own mock expectations independently, without global state leaking between tests
2. [M2] Verification confidence - mocks should verify that the correct functions were called with the correct arguments, not just return canned data
3. [M3] Idiomatic Elixir - follow established community patterns (Mox is Jose Valim's recommended approach for mocking in Elixir)
4. [M4] Async test support - mock strategy should work with async: true tests for faster test suite execution

### Less

1. [L1] Migration effort - switching mock strategy requires touching all existing test files and mock modules
2. [L2] Dependency count - adding a mock library means another hex dependency to maintain and keep updated
3. [L3] Setup boilerplate - per-test mock setup code (expect/verify calls) can be verbose compared to a simple module swap
4. [L4] Learning curve - team members need to learn a new API vs simple module pattern

## Chosen Option

Migrate to Hammox - Mox with automatic typespec validation on mock return values via `@callback` specs

## Why(not)

In the face of **choosing a mock implementation strategy for isolating LLM calls in tests**, instead of doing nothing (**tests call the real Anthropic API; every test run costs money, requires network access, and is non-deterministic**), we decided **to migrate to Hammox, a drop-in wrapper around Mox that additionally validates mock return values against `@callback` typespecs**, to achieve **per-test isolation, argument verification, async test execution, and runtime type safety on mock boundaries**, accepting **a one-time migration of all test files and the addition of two hex dependencies (Mox + Hammox)**.

## Points

### For

- [M1] Same per-process isolation as Mox via `$callers`; each test defines its own expectations
- [M2] Everything Mox provides (function/arity/argument verification) plus automatic validation that mock return values match `@callback` typespecs
- [M2] Catches a class of bugs Mox misses: mock returning wrong type silently (e.g., returning `{:ok, 42}` when callback spec says `{:ok, String.t()}`)
- [M3] Built on top of Mox; same idiomatic behaviour-based pattern
- [M4] Per-process isolation means all mock-dependent tests can run with `async: true`

### Against

- [L1] Same migration effort as Mox - every test file must be updated
- [L2] Adds two dependencies: `{:mox, "~> 1.0"}` and `{:hammox, "~> 0.7"}` (Hammox depends on Mox)
- [L3] Same boilerplate as Mox; Hammox adds no extra setup beyond swapping `Mox.expect` for `Hammox.expect`
- [L4] Same Mox API to learn, plus understanding that return values are now type-checked
- [L2] Hammox is a smaller community project compared to Mox; may lag behind Mox updates

## Artistic

Trust, but verify the types.

## Evidence

Hammox is a thin wrapper - the entire library is a few hundred lines that intercept `expect` and `stub` calls to validate return values against `@callback` typespecs using Erlang's `typespecs` module. Since we already define `@callback` specs on `MaudeLibs.LLM`, Hammox provides free runtime type checking at mock boundaries with zero additional annotation work. The migration from Mox to Hammox (or back) is a single find-and-replace: `Mox.expect` to `Hammox.expect`. This makes it a low-risk bridge until the gradual type system handles `@callback` validation at compile time (projected Elixir v1.21+, late 2026).

## Consequences

- [deps] Adds `{:hammox, "~> 0.7", only: :test}` to mix.exs (pulls in Mox as transitive dep)
- [migration] Remove `LLM.Mock`, `LLM.ErrorMock`; update all test files to use `Hammox.expect/3`
- [test-quality] Tests verify arguments and return type conformance against `@callback` specs
- [concurrency] All mock-dependent tests can run with `async: true`
- [cost] No API costs in tests

## How

```elixir
# test/support/mocks.ex (same as Mox - Hammox wraps, doesn't replace defmock)
Mox.defmock(MaudeLibs.LLM.MockBehaviour, for: MaudeLibs.LLM)

# config/test.exs
config :maude_libs, :llm_module, MaudeLibs.LLM.MockBehaviour

# test/support/conn_case.ex or data_case.ex
setup :verify_on_exit!
setup :set_mox_from_context

# In a test - swap Mox for Hammox
test "synthesis returns valid typespec" do
  Hammox.expect(MaudeLibs.LLM.MockBehaviour, :synthesize_scenario, fn _submissions ->
    {:ok, "Where should we eat?"}
  end)

  # This would FAIL with Hammox (but pass with plain Mox):
  # Hammox.expect(MockBehaviour, :synthesize_scenario, fn _ -> "bare string" end)
  # Because @callback says :: {:ok, String.t()} | {:error, term()}
end

# Alternatively, use Hammox.protect to wrap an existing implementation:
defn_mock = Hammox.protect({MaudeLibs.LLM.Anthropic, :synthesize_scenario, 1})
```

## Reconsider

- observe: Elixir's gradual type system (v1.21+) covers `@callback` type signatures at compile time
  respond: Drop Hammox, swap `Hammox.expect` back to `Mox.expect`; the compiler now catches return type mismatches before tests even run. Hammox was a bridge for the gap year before compiler-native type checking.
- observe: Hammox maintenance lags behind Mox releases
  respond: Fall back to plain Mox; lose typespec validation but keep all other benefits
- observe: `@callback` specs are being phased out in favor of new type signatures
  respond: Check if Hammox adapts to new type syntax; if not, plain Mox + compiler types is the path

## Historic

Hammox was created by Michał Szewczak to address the gap between Mox's behaviour-contract enforcement (correct functions exist) and typespec enforcement (return values match declared types). It validates against Erlang-era `@callback` typespecs at runtime, catching a class of bugs that neither Mox nor Dialyzer catch in tests.

## More Info

- [Hammox on Hex](https://hex.pm/packages/hammox)
- [Hammox GitHub](https://github.com/msz/hammox)
- [Mox on Hex](https://hex.pm/packages/mox)
