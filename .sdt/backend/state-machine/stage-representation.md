---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [state-machine, data-structures, stages]
parent: null
children: []
---

# SDT: Decision Stage Representation

## Scenario

How do we represent the current stage of a decision and its stage-specific data in Elixir?

## Pressures

### More

1. [M1] Pattern matching ergonomics - stages should be easy to dispatch on
2. [M2] Type clarity - stage data fields should be obvious from the struct definition
3. [M3] Compiler assistance - wrong stage should be caught at the match site

### Less

1. [L1] Runtime overhead - stage transitions happen frequently
2. [L2] Verbosity - we have 7 stages; struct per stage adds module boilerplate

## Chosen Option

Tagged struct per stage: %Stage.Lobby{}, %Stage.Scenario{}, etc., stored in Decision.stage

## Why(not)

In the face of **representing 7 distinct decision stages with different fields**, instead of doing nothing (**one big map with a :stage key and all possible fields - confusing, untyped**), we decided **to define one plain Elixir struct per stage module, stored in the Decision.stage field**, to achieve **pattern matching on `%Stage.Lobby{}` in Core.handle/2 guards, clear field documentation per module, and compiler warnings on incomplete matches**, accepting **7 small modules that are mostly boilerplate structs**.

## Points

### For

- [M1] `def handle(%Decision{stage: %Stage.Lobby{}} = d, msg)` - unambiguous dispatch
- [M2] Each struct documents its own fields; no shared blob where half the fields are nil
- [M3] Exhaustive case/function clause matching catches unhandled stage+message combos

### Against

- [L2] 7 modules each with defstruct - ~10 lines per module = ~70 lines of boilerplate in stages.ex

## Artistic

<!-- author this yourself -->

## Consequences

- [data] One defstruct per stage in lib/maude_libs/decision/stages.ex
- [dispatch] Core.handle/2 pattern-matches on stage struct type in function head
- [clarity] Stage fields are explicit; nil fields are impossible

## How

```elixir
defmodule MaudeLibs.Decision.Stage do
  defmodule Lobby do
    defstruct invited: MapSet.new(), joined: MapSet.new(), ready: MapSet.new()
  end
  defmodule Scenario do
    defstruct submissions: %{}, synthesis: nil, votes: %{}
  end
  defmodule Priorities do
    defstruct priorities: %{}, confirmed: MapSet.new(), suggestions: [], ready: MapSet.new()
  end
  # ... etc
end
```

## Reconsider

- observe: Stage structs need versioning for live deploys
  respond: Add a vsn field or use a registry-based approach

## Historic

Elixir structs as tagged unions is idiomatic; Ecto changesets use the same pattern. Alternative would be a single map with a :type key (more dynamic, less safe).

## More Info

- [Elixir structs documentation](https://hexdocs.pm/elixir/structs.html)
