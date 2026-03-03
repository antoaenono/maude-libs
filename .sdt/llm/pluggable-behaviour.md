---
author: @antoaenono
asked: 2026-03-02
decided: 2026-03-02
status: accepted
deciders: @antoaenono
tags: [llm, testing, behaviour, mock, dependency-injection]
parent: llm/api-wrapper
children: []
---

# SDT: LLM Pluggable Behaviour with Mock

## Scenario

How do we test decision flows that trigger LLM calls without making real API requests, while keeping the LLM integration swappable?

## Pressures

### More

1. [M1] Test isolation - tests must not hit the Anthropic API (cost, speed, flakiness)
2. [M2] Determinism - test outputs must be predictable for assertion

### Less

1. [L1] Indirection - behaviour + config lookup adds a layer vs direct module calls
2. [L2] Mock drift - mock responses can diverge from real API shape over time

## Chosen Option

Elixir `@behaviour` on the LLM module; `MaudeLibs.LLM.Mock` implements canned responses; Server reads the module from application config at startup

## Why(not)

In the face of **needing to test LLM-dependent flows without real API calls**, instead of doing nothing (**skip LLM tests or hit the real API in CI**), we decided **to define `MaudeLibs.LLM` as a behaviour with callbacks for each LLM function, implement `MaudeLibs.LLM.Mock` with deterministic canned responses, and configure the module via `Application.get_env(:maude_libs, :llm_module)`**, to achieve **fully isolated tests that exercise the complete decision flow including LLM-triggered stage transitions**, accepting **a small indirection cost and the responsibility to keep Mock response shapes in sync with real API responses**.

## Points

### For

- [M1] Tests use `config :maude_libs, llm_module: MaudeLibs.LLM.Mock`; no HTTP calls, no API key needed
- [M2] Mock returns hardcoded values: `synthesize_scenario/1` always returns "Synthesized: ..."
- [L1] One `Application.get_env` call in Server.init; behaviour callbacks match the real module's public API

### Against

- [L2] If the real LLM module adds a new function, Mock must be updated or tests crash (good failure mode)

## Artistic

<!-- author this yourself -->

## Consequences

- [arch] `MaudeLibs.LLM` defines `@callback` for each function; real module and Mock both `@impl` them
- [config] `config/test.exs` sets `llm_module: MaudeLibs.LLM.Mock`; `config/dev.exs` and `config/runtime.exs` set `MaudeLibs.LLM`
- [server] Server reads module once in init: `@llm Application.compile_env(:maude_libs, :llm_module, MaudeLibs.LLM)`
- [testing] All decision flow tests exercise LLM-triggered transitions (suggestions, scaffolding, why-statement) with deterministic data

## How

```elixir
# lib/maude_libs/llm.ex
defmodule MaudeLibs.LLM do
  @callback synthesize_scenario(list()) :: {:ok, String.t()} | {:error, term()}
  @callback suggest_priorities(String.t(), list()) :: {:ok, list()} | {:error, term()}
  @callback suggest_options(String.t(), list(), list()) :: {:ok, list()} | {:error, term()}
  @callback scaffold(String.t(), list(), list()) :: {:ok, list()} | {:error, term()}
  @callback why_statement(String.t(), list(), String.t(), list()) :: {:ok, String.t()} | {:error, term()}
  @callback tagline(String.t()) :: {:ok, String.t()} | {:error, term()}

  @behaviour __MODULE__
  # ... real implementation using Req
end

# lib/maude_libs/llm/mock.ex
defmodule MaudeLibs.LLM.Mock do
  @behaviour MaudeLibs.LLM

  @impl true
  def synthesize_scenario(_submissions), do: {:ok, "Synthesized scenario"}

  @impl true
  def suggest_priorities(_scenario, _priorities) do
    {:ok, [%{"text" => "Mock suggestion", "direction" => "+"}]}
  end
  # ... etc
end
```

## Reconsider

- observe: Need to test error paths (LLM returns {:error, ...})
  respond: Add Mock variants or make Mock configurable per-test via process dictionary or Agent
- observe: Mock responses are too simplistic; don't exercise JSON parsing edge cases
  respond: Make Mock responses match exact API response shape, including nested structures

## Historic

The `@behaviour` + compile-time config pattern is standard Elixir dependency injection. Libraries like Swoosh (email), ExAws, and Tesla all use this approach. Mox is an alternative for stricter mock verification, but simple `@behaviour` modules are sufficient when you want canned responses rather than expectation-based mocking.

## More Info

- [Elixir @behaviour docs](https://hexdocs.pm/elixir/typespecs.html#behaviours)
- [Jose Valim: Mocks and explicit contracts](https://dashbit.co/blog/mocks-and-explicit-contracts)
