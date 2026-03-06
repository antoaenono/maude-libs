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

## Decision

Hand-rolled mock modules - `LLM.Mock` and `LLM.ErrorMock` implement the LLM behaviour, swapped via `Application.get_env` config

## Why(not)


In the face of **choosing a mock implementation strategy for isolating LLM calls in tests**,
instead of doing nothing
(**tests call the real Anthropic API; every test run costs money, requires network access, and is non-deterministic**),
we decided **to use hand-rolled mock modules (`LLM.Mock`, `LLM.ErrorMock`) swapped via `Application.put_env` in test setup**,
to achieve **deterministic, offline, free test execution**,
accepting **that we cannot verify mock call arguments, tests share global mock state, and each new mock behavior requires a new module**.

## Points

### For

- [M1] Tests no longer hit real API; deterministic responses from mock modules
- [M2] Mock modules implement the `@behaviour`, so at least the function signatures are enforced
- [L1] Already in place - no migration needed from current state
- [L2] No new dependencies
- [L4] Simple pattern: swap module via Application config, mock module returns canned data

### Against

- [M1] Global `Application.put_env` mock config leaks between tests; `async: false` required
- [M2] Mock modules return canned data regardless of input arguments - no call verification
- [M3] Hand-rolled mocks are not the idiomatic Elixir testing pattern
- [M4] Cannot run mock-dependent tests with `async: true` due to shared global config
- [L3] Adding a new mock behavior (e.g., partial failure) requires creating a whole new module

## Consequences

- [deps] No new dependencies
- [migration] Already implemented; no work needed
- [test-quality] Tests verify behavior but not mock call arguments
- [concurrency] Tests using mocks must remain `async: false`
- [cost] No API costs in tests

## Evidence

The current hand-rolled approach works: 295 tests pass, the suite runs in seconds, and no API costs are incurred. The pain points are theoretical for now - global mock state hasn't caused a real test isolation bug yet because the suite is small and runs with `async: false`. The risk grows as more tests are added and the `async: false` constraint becomes a bottleneck. We already hit the "new module per behavior" friction when adding `LLM.ErrorMock` for the error handling feature.

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

`LLM.Mock` and `LLM.ErrorMock` implement `@behaviour MaudeLibs.LLM`. Tests swap the module via `Application.put_env(:maude_libs, :llm_module, MockModule)` in setup blocks.

```elixir
# lib/maude_libs/llm/mock.ex
defmodule MaudeLibs.LLM.Mock do
  @behaviour MaudeLibs.LLM

  @impl true
  def synthesize_scenario(_submissions), do: {:ok, "Where should we eat?"}

  @impl true
  def scaffold(_scenario, _priorities, _options), do: {:ok, %{...}}
  # ... all callbacks return canned {:ok, ...} data
end

# lib/maude_libs/llm/error_mock.ex
defmodule MaudeLibs.LLM.ErrorMock do
  @behaviour MaudeLibs.LLM

  @impl true
  def synthesize_scenario(_submissions), do: {:error, :api_down}
  # ... all callbacks return {:error, ...}
end

# In test setup
setup do
  Application.put_env(:maude_libs, :llm_module, MaudeLibs.LLM.Mock)
  on_exit(fn -> Application.delete_env(:maude_libs, :llm_module) end)
end
```

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: Test suite grows large enough that `async: false` becomes a bottleneck
  respond: Revisit Mox migration to enable async test execution
- observe: A bug slips through because a mock returned data for the wrong input
  respond: Mox expectations would have caught the argument mismatch
- observe: Need a third mock behavior (e.g., partial success)
  respond: Creating yet another module is a sign the hand-rolled approach doesn't scale

## Artistic

Good enough until it isn't.

## Historic

Hand-rolled mocks are the simplest approach and were the standard in early Elixir projects before Mox was published in 2017. They work well for small projects with few external dependencies.

## More Info

- [relevant link](https://example.com)
