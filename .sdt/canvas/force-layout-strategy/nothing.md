---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [canvas, physics, force-layout, convergence]
parent: canvas/physics
children: []
---

# SDT: Canvas Force Layout Strategy

## Scenario

Which approach should we use to compute non-overlapping, center-clustered positions for decision circles on the canvas homepage, given that the current hand-rolled server-side simulation oscillates and fails to converge at 8+ nodes?

## Pressures

### More

1. [M1] Convergence reliability - layout must settle to a stable state regardless of node count (4-20)
2. [M2] Visual quality - circles should be evenly spaced, clustered near center, no overlaps
3. [M3] Implementation confidence - use a proven algorithm, not hand-tuned magic constants

### Less

1. [L1] Settling time - layout should reach equilibrium within 1-2 ticks, not 10+
2. [L2] Architectural complexity - avoid introducing new runtimes, build steps, or JS interop layers
3. [L3] Tuning surface - fewer knobs to fiddle with

## Chosen Option

Do nothing - keep the current hand-rolled server-side force simulation

## Why(not)

In the face of **needing non-overlapping, center-clustered circle positions on the canvas**, instead of choosing a different approach, we decided **to do nothing**, to achieve **no disruption to the current architecture**, accepting **continued oscillation, convergence failures at 8+ nodes, and unpredictable settling times that degrade the user experience**.

## Points

### For

- [L2] No new dependencies, runtimes, or architectural changes required
- [L3] Already familiar with the current codebase

### Against

- [M1] Current simulation oscillates and fails to converge with 8+ nodes
- [M2] Circles get pushed to canvas edges at higher counts; overlaps persist
- [M3] Multiple tuning attempts have failed - the algorithm is fundamentally unstable for this use case
- [L1] Settling takes 10+ ticks (15+ seconds) when it converges at all

## Artistic

<!-- author this yourself -->

## Consequences

- [deps] No change
- [convergence] Circles continue to oscillate or sit at edges with 8+ nodes
- [dx] Continued debugging and tuning attempts with no guarantee of resolution
- [ux] Users see jittery, unsettled circles for extended periods

<!-- evidence -->

## How

Continue with `canvas_server.ex` as-is. Accept the limitations.

## Reconsider

- observe: A simple constant tweak finally produces stable behavior at 12+ nodes
  respond: Keep current approach; document the working constants

## Historic

The current implementation has gone through 5+ iterations of constant tuning, algorithm changes (inverse-square to Fruchterman-Reingold to spring-electrical), and structural rewrites (velocity-based to displacement-based). None have produced reliable convergence.

## More Info

- [Fruchterman-Reingold paper](https://doi.org/10.1002/spe.4380211102)
