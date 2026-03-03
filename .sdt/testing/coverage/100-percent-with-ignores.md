---
author: @antoaenono
asked: 2026-03-03
decided: 2026-03-03
status: rejected
deciders: @antoaenono
tags: [testing, coverage, elixir, precommit]
parent: null
children: []
---

# SDF: Line Coverage Enforcement Strategy

## Scenario

What level of line coverage enforcement should we adopt for our test suite, and how should we handle coverage tool limitations that make 100% unachievable without workarounds?

## Pressures

### More

1. [M1] Regression confidence - coverage threshold catches new uncovered code before it merges
2. [M2] Signal accuracy - coverage numbers reflect actual testable code, not tool artifacts
3. [M3] Maintenance simplicity - coverage workflow should be set-and-forget, not require per-module bookkeeping
4. [M4] Honest metrics - the number we report matches reality, no hidden carve-outs or asterisks

### Less

1. [L1] False confidence - a green 100% badge that hides ignored modules can mask real gaps
2. [L2] Workflow friction - having to unignore/re-ignore modules when editing them slows development
3. [L3] Cognitive overhead - developers shouldn't need to understand cover tool internals to pass the gate
4. [L4] Threshold churn - lowering the threshold to accommodate tool quirks weakens the gate over time


### Non

1. [X1] Love

## Decision

Set threshold to 100% and add stage component modules to `ignore_modules`, unignoring them temporarily when modifying their code.

## Why(not)


In the face of **choosing a line coverage enforcement level while dealing with cover tool blind spots**,
instead of doing nothing
(**no coverage gate; tests exist but nothing prevents shipping uncovered code; coverage drifts down over time as features are added without corresponding tests**),
we decided **to enforce 100% line coverage by adding the 8 stage component modules (whose only uncovered line is the compile-time `defmodule` declaration) to `ignore_modules`**,
to achieve **zero tolerance for uncovered code with zero headroom for regressions**,
accepting **that modifying a stage component requires temporarily removing it from ignore_modules to verify its coverage, then re-adding it**.

## Points

### For

- [M1] Zero headroom - any single uncovered line anywhere in any non-ignored module fails the gate immediately
- [M2] The 100% number accurately reflects that all coverable lines are covered (the `defmodule` lines genuinely cannot execute at runtime)
- [L4] Threshold never needs to change - 100% is the ceiling, it stays there permanently

### Against

- [M3] Requires per-module bookkeeping: when editing a stage component, remove from ignore_modules, run coverage, verify, re-add
- [M4] The headline number (100%) is technically honest but the ignore_modules list is doing work behind the scenes
- [L1] Ignored modules could accumulate real uncovered code between check-ins; the ignore_modules list becomes a blind spot
- [L2] Workflow friction on every stage component edit: forget to unignore and you miss a real gap; forget to re-ignore and the gate fails
- [L3] Developers need to understand why specific modules are ignored and the unignore/re-ignore dance
- [L1] If a developer adds a new function to a stage component and doesn't unignore it, the new function ships untested and the gate still shows 100%

## Artistic

<!-- author this yourself -->

## Consequences

- [gate] Precommit enforces 100% threshold via `mix test --cover`; any uncovered line in a non-ignored module fails
- [ignore-list] 8 stage component modules added to ignore_modules alongside existing Phoenix boilerplate
- [dx] Editing stage components requires a 3-step dance: remove from ignore_modules, verify coverage, re-add
- [risk] New functions in ignored modules bypass the coverage gate entirely until someone remembers to unignore
- [ops] ignore_modules list grows with each new component module that has a `defmodule` line

## Evidence

<!-- optional epistemological layer -->

## Implementation

```elixir
# mix.exs
test_coverage: [
  summary: [threshold: 100],
  ignore_modules: [
    # Phoenix-generated boilerplate with no meaningful runtime logic
    MaudeLibsWeb.PageHTML,
    MaudeLibsWeb.ErrorHTML,
    MaudeLibsWeb.CoreComponents,
    MaudeLibsWeb.Layouts,
    MaudeLibsWeb.Router,
    MaudeLibsWeb.Telemetry,
    MaudeLibsWeb.Gettext,
    MaudeLibs.Application,
    # Dev-only seeding controller, gated behind Mix.env() == :dev
    MaudeLibsWeb.Dev.SeedController,
    # Real Anthropic API wrapper, replaced by Hammox mock in tests
    MaudeLibs.LLM,
    # Stage components whose functions and templates are fully covered
    # by tests, but whose `defmodule` declaration line is a compile-time
    # construct that Elixir's :cover tool marks as relevant yet never
    # sees executed at runtime. Ignored solely to reach 100% threshold.
    MaudeLibsWeb.DecisionLive.ScaffoldingStage,
    MaudeLibsWeb.DecisionLive.CompleteStage,
    MaudeLibsWeb.DecisionLive.ScenarioStage,
    MaudeLibsWeb.DecisionLive.DecisionComponents,
    MaudeLibsWeb.DecisionLive.DashboardStage,
    MaudeLibsWeb.DecisionLive.LobbyStage,
    MaudeLibsWeb.DecisionLive.OptionsStage,
    MaudeLibsWeb.DecisionLive.PrioritiesStage
  ]
]
```

When modifying a stage component:
1. Remove the module from `ignore_modules`
2. Run `mix test --cover` and verify the only uncovered line is `defmodule`
3. Re-add the module to `ignore_modules`

## Reconsider

- observe: Elixir's cover tool fixes the `defmodule` counting
  respond: Remove stage components from ignore_modules; 100% is achievable natively
- observe: Developers keep forgetting the unignore/re-ignore step and real gaps slip through
  respond: Drop to 99% threshold and remove stage components from ignore_modules
- observe: New stage components are added and the ignore_modules list keeps growing
  respond: Evaluate whether the bookkeeping cost outweighs the benefit of the 100% headline number
- observe: A CI script could automate the unignore check (run coverage once without ignore for each changed module)
  respond: Build the automation; this eliminates L2 workflow friction and L1 blind spot risk

## Historic

Elixir's cover tool wraps Erlang's `:cover` module, which instruments compiled BEAM bytecode at the line level. It has known limitations: `defmodule` declarations, compile-time macro expansions, and Logger argument expressions (when short-circuited by log level) are marked as relevant lines but never execute at runtime. The `ignore_modules` config is Elixir's escape hatch for modules that don't participate meaningfully in runtime coverage.

## More Info

- [Elixir test coverage docs](https://hexdocs.pm/mix/Mix.Tasks.Test.html#module-coverage)
- [Erlang cover module](https://www.erlang.org/doc/apps/tools/cover.html)
