---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [input-stages, llm, suggestions]
parent: null
children: []
---

# SDT: Claude Suggestion Integration Model

## Scenario

How should Claude's suggested priorities and options be presented and adopted by participants?

## Pressures

### More

1. [M1] Human agency - Claude suggestions should be optional additions, not defaults
2. [M2] Frictionless acceptance - if a suggestion is good, it should be one click to include
3. [M3] Group coordination - toggling a suggestion should be visible to all participants immediately

### Less

1. [L1] Coordination overhead - participants voting on each suggestion adds a mini-decision within the decision
2. [L2] Confusion - suggestions appearing before all humans have confirmed is noisy

## Chosen Option

Toggle model: anyone can include/exclude a suggestion; last write wins; broadcast immediately

## Why(not)

In the face of **integrating Claude suggestions into human-driven input stages**, instead of doing nothing (**no suggestions - humans must think of everything themselves**), we decided **to show Claude suggestions (up to 3) only after all humans have confirmed their entries, with per-suggestion toggle buttons visible to all participants where last write wins**, to achieve **lightweight group decision on each suggestion without a formal vote, while keeping Claude visually distinct (center position)**,  accepting **that "last write wins" may cause brief flicker if two people toggle simultaneously - acceptable at 2-4 participants**.

## Points

### For

- [M1] Suggestions are visually in the center (distinct from human entries at the edges); not defaults
- [M2] One click to toggle; included suggestions flow into the next stage with human entries
- [M3] Toggle state broadcasts via PubSub; all see the current included/excluded state live
- [L1] No per-suggestion vote required; the group can discuss verbally and toggle as agreed

### Against

- [L2] Suggestions only appear after all confirmed - no noise during active entry

## Artistic

<!-- author this yourself -->

## Consequences

- [data] suggestions: [{text, direction, included: bool}] in stage struct
- [trigger] LLM suggestion call fires when MapSet.subset?(connected, confirmed)
- [ux] Suggestions rendered in center with visual distinction (dashed border, "Claude" label)

## How

```elixir
# Core.handle
def handle(d, {:toggle_suggestion, index, included}) do
  suggestions = List.update_at(d.stage.suggestions, index, &%{&1 | included: included})
  {:ok, %{d | stage: %{d.stage | suggestions: suggestions}},
   [{:broadcast, d.id, d}]}
end
```

## Reconsider

- observe: Last-write-wins causes confusion when two users rapidly toggle the same suggestion
  respond: Add optimistic locking or switch to majority vote (2/4 participants = include)

## Historic

Google Docs-style "last write wins" is the simplest CRDT approach. At 2-4 participants in the same room, conflicts are resolved verbally; the UI just needs to reflect the agreed state.

## More Info

- [relevant link](https://example.com)
