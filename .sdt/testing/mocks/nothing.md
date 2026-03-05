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

Do nothing - no mocking; tests call the real Anthropic API

## Why(not)


In the face of **choosing a mock implementation strategy for isolating LLM calls in tests**,
instead of doing nothing
(**tests call the real Anthropic API; every test run costs money, requires network access, and is non-deterministic**),
we decided **to do nothing**,
to achieve **zero abstraction layer between tests and production code**,
accepting **that tests are slow, expensive, flaky, and cannot run offline or in CI without API credentials**.

## Points

### For

- [L1] Zero effort - no mock modules, no config swapping, no library to set up
- [L2] No dependencies of any kind
- [L3] No mock boilerplate - tests call real code directly
- [L4] Nothing to learn

### Against

- [M1] Every test shares the same real API; no isolation, no control over responses
- [M2] Cannot verify what arguments were passed - just observe real side effects
- [M3] Testing against real external services is explicitly discouraged in the Elixir community
- [M4] Tests are inherently serial due to shared external state; async would cause race conditions against the API

## Artistic

Pay per test run.

## Evidence

Without mocking, every test invocation hits the Anthropic API. At current Claude Haiku pricing, a typical test suite run exercising all 6 LLM callbacks costs roughly $0.01-0.05 per run. This adds up during TDD workflows where tests run dozens of times per hour. More critically, tests become non-deterministic: the same input may produce different LLM outputs across runs, making assertions fragile and failures hard to reproduce.

## Consequences

- [deps] No dependencies
- [migration] No migration work
- [test-quality] Tests exercise real API but are non-deterministic and slow
- [concurrency] Tests must be serial; real API calls cannot safely overlap
- [cost] Every test run incurs Anthropic API costs

## Implementation

Tests call `MaudeLibs.LLM` directly with no module swap. The real implementation hits the Anthropic API on every invocation. Requires `ANTHROPIC_API_KEY` set in test environment.

## Reconsider

- observe: This is the starting point before any mocking exists
  respond: Any project with external API calls should introduce mocking early

## Historic

Testing against real external services was common before mocking patterns matured. It remains useful for integration/smoke tests but is impractical as the primary test strategy for services with cost-per-call pricing.

## More Info

- [relevant link](https://example.com)
