---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [input-stages, scenario, consensus]
parent: null
children: []
---

# SDT: Scenario Consensus Mechanism

## Scenario

How do participants agree on the final scenario framing before advancing to priorities?

## Pressures

### More

1. [M1] Genuine agreement - the scenario framing must reflect what all participants actually want to decide
2. [M2] Friction as a feature - forcing real consensus on the scenario frames the rest of the decision correctly
3. [M3] Transparency - all candidates should be visible to everyone before voting

### Less

1. [L1] Deadlock risk - unanimous requirement could stall if participants disagree indefinitely
2. [L2] Implementation complexity of voting - tracking votes, detecting unanimity, handling ties

## Chosen Option

Unanimous vote: all connected participants must select the same candidate to advance

## Why(not)

In the face of **reaching agreement on the scenario framing before the decision proceeds**, instead of doing nothing (**creator's topic is automatically the scenario - others have no say**), we decided **to require unanimous selection of the same candidate (creator's default, optional rephrases, or LLM synthesis)**, to achieve **the maximum pressure on participants to genuinely discuss and align before investing time in the rest of the decision**, accepting **the risk of deadlock if participants cannot agree (they should discuss out of band and try again)**.

## Points

### For

- [M1] Unanimity means no participant feels their framing was overridden
- [M2] The friction is intentional - if you can't agree on the scenario, you can't run the decision
- [M3] All candidates visible from start; LLM synthesis added if divergence exists

### Against

- [L1] Two stubborn participants could deadlock; no timeout mechanism
- [L2] Unanimity detection: count unique vote values, check == 1 and count == connected size

## Artistic

<!-- author this yourself -->

## Consequences

- [logic] Advance predicate: map_size(votes) == connected_count and all values equal
- [ux] Votes visible to all; when unanimous the stage auto-advances
- [llm] Synthesis only triggered when >= 1 alternative submission (bridging divergence)

## How

```elixir
defp unanimous?(%Decision{connected: c, stage: %Stage.Scenario{votes: votes}}) do
  vote_values = Map.values(votes)
  MapSet.size(c) > 0 and
  map_size(votes) == MapSet.size(c) and
  length(Enum.uniq(vote_values)) == 1
end
```

## Reconsider

- observe: Participants are stuck and can't reach unanimity
  respond: Add a "creator override" escape hatch or a majority vote fallback after N minutes

## Historic

Unanimous consent is used in Robert's Rules of Order for time-sensitive procedural matters. For a scenario framing, unanimity is appropriate because the entire rest of the decision depends on it being right.

## More Info

- [relevant link](https://example.com)
