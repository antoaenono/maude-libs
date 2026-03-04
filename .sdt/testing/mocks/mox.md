---
author: @antoaenono
asked: 2026-03-02
decided: 2026-03-02
status: rejected
deciders: @antoaenono
tags: [testing, mocking, llm, elixir]
parent: null
children: []
---

# SDF: Test Mock Implementation Strategy

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


### Non

1. [X1] Love

## Decision

Migrate to Mox - define a Mox mock from the LLM behaviour, use per-test expectations, remove hand-rolled mock modules

## Why(not)


In the face of **choosing a mock implementation strategy for isolating LLM calls in tests**,
instead of doing nothing
(**tests call the real Anthropic API; every test run costs money, requires network access, and is non-deterministic**),
we decided **to migrate to Mox with per-test expectations defined via `Mox.expect/3`**,
to achieve **per-test isolation, argument verification, and async-compatible test execution**,
accepting **a one-time migration of all test files and the addition of a hex dependency**.

## Points

### For

- [M1] Mox supports per-process isolation via `$callers`; however, our OTP architecture (test -> DynamicSupervisor -> GenServer -> Task) breaks the `$callers` chain at the Supervisor boundary, requiring `set_mox_global` initially
- [M2] `Mox.expect/3` verifies function name, arity, and allows assertions on arguments inside the expectation function
- [M3] Mox is Jose Valim's recommended mocking library; the behaviour-based approach is the idiomatic Elixir pattern
- [M4] Per-process isolation would enable `async: true`, but requires refactoring GenServer startup in tests; deferred to future work
- [L3] `Mox.stub/3` provides a default for tests that don't care about specific calls, reducing boilerplate for common cases

### Against

- [L1] Every test file using LLM.Mock or LLM.ErrorMock must be updated to use `Mox.expect/3` or `Mox.stub/3`
- [L2] Adds `{:mox, "~> 1.0", only: :test}` as a new dependency
- [L3] Each test must explicitly set up expectations; no shared default mock module to fall back on without `Mox.stub`
- [L4] Team must learn Mox API: `expect`, `stub`, `verify_on_exit!`, `set_mox_from_context`

## Artistic

Mock the behaviour, not the module.

## Evidence

Mox is the most widely adopted mocking library in the Elixir ecosystem. Jose Valim's 2015 blog post "Mocks and explicit contracts" established the pattern of defining behaviours for external dependencies and mocking at that boundary. Mox implements this pattern with per-process isolation via `$callers`, which is battle-tested across thousands of production Elixir projects. The migration from hand-rolled mocks is mechanical: replace `Application.put_env` swaps with `Mox.expect` calls.

## Consequences

- [deps] Adds `{:mox, "~> 1.0", only: :test}` to mix.exs
- [migration] Remove `LLM.Mock`, `LLM.ErrorMock`; update all test files to use `Mox.expect/3`
- [test-quality] Tests can verify exact arguments passed to LLM calls
- [concurrency] Server tests use `set_mox_global` and remain `async: false` due to Supervisor breaking `$callers` chain; per-process isolation deferred
- [cost] No API costs in tests

## Implementation

```elixir
# test/support/mocks.ex
Mox.defmock(MaudeLibs.LLM.MockBehaviour, for: MaudeLibs.LLM)

# config/test.exs
config :maude_libs, :llm_module, MaudeLibs.LLM.MockBehaviour

# test/support/conn_case.ex or data_case.ex
setup :verify_on_exit!
setup :set_mox_from_context

# In a test
test "synthesis calls LLM with submissions" do
  submissions = [%{text: "lunch"}, %{text: "dinner"}]

  Mox.expect(MaudeLibs.LLM.MockBehaviour, :synthesize_scenario, fn ^submissions ->
    {:ok, "Where should we eat?"}
  end)

  # ... trigger the code path
end

# For error cases (replaces ErrorMock)
Mox.expect(MaudeLibs.LLM.MockBehaviour, :synthesize_scenario, fn _submissions ->
  {:error, :api_down}
end)
```

## Reconsider

- observe: Only one external dependency (LLM) needs mocking; Mox overhead not justified
  respond: If a second external dependency appears (e.g., email, storage), Mox pays for itself immediately
- observe: Mox expectations make tests brittle by coupling to internal call structure
  respond: Use `Mox.stub/3` for tests that only care about output, `expect` for tests that verify integration

## Historic

Mox was published by Jose Valim in 2017 as the recommended replacement for hand-rolled mocks in Elixir. It enforces the "mock the behaviour, not the module" pattern. The library uses `$callers` process dictionary for per-test isolation, making it safe for concurrent test execution.

## More Info

- [Mox on Hex](https://hex.pm/packages/mox)
- [Mocks and explicit contracts (Jose Valim)](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
