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



## Decision

Do nothing - no coverage threshold enforcement.

## Why(not)


In the face of **choosing a line coverage enforcement level while dealing with cover tool blind spots**,
instead of doing nothing
(**no coverage gate; tests exist but nothing prevents shipping uncovered code; coverage drifts down over time as features are added without corresponding tests**),
we decided **to do nothing**,
to achieve **zero tooling overhead and maximum development velocity**,
accepting **coverage drift and the possibility of shipping entirely untested code paths**.

## Points

### For

- [M3] No configuration to maintain, no ignore_modules lists, no threshold values to adjust
- [L2] Zero workflow friction - no gate to fail, no workarounds needed
- [L3] No need to understand cover tool internals at all

### Against

- [M1] No regression gate - new code can ship without any test coverage and nothing catches it
- [M2] No signal at all - coverage isn't measured, so accuracy is moot
- [M4] No metrics to be honest about
- [L1] No confidence of any kind, false or otherwise
- [L4] No threshold to churn - but also no threshold to protect quality

## Artistic

<!-- author this yourself -->

## Consequences

- [gate] No precommit coverage check; `mix test --cover` is never run automatically
- [drift] Coverage percentage becomes unknown and trends downward over time
- [dx] Developers never blocked by coverage failures
- [quality] Untested code paths accumulate silently

## Evidence

<!-- optional epistemological layer -->

## Implementation

Remove the `test_coverage` key from `mix.exs` project config entirely. Remove `test --cover` from the precommit alias.

```elixir
# mix.exs - remove test_coverage config
def project do
  [
    app: :maude_libs,
    # ... no test_coverage key
  ]
end

# Remove --cover from precommit alias
precommit: [
  "compile --warnings-as-errors",
  "deps.unlock --unused",
  "format",
  "test.js",
  "test"  # no --cover
]
```

## Reconsider

- observe: A bug ships to production that would have been caught by even basic coverage enforcement
  respond: Revisit adding a threshold, even a low one like 80%
- observe: Test suite grows organically and maintains high coverage through culture alone
  respond: Status quo is working; formalize with a threshold only if drift appears

## Historic

Elixir's cover tool wraps Erlang's `:cover` module, which instruments compiled BEAM bytecode at the line level. It has known limitations: `defmodule` declarations, compile-time macro expansions, and Logger argument expressions (when short-circuited by log level) are marked as relevant lines but never execute at runtime.

## More Info

- [Elixir test coverage docs](https://hexdocs.pm/mix/Mix.Tasks.Test.html#module-coverage)
- [Erlang cover module](https://www.erlang.org/doc/apps/tools/cover.html)
