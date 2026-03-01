---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [canvas, physics, force-layout, elixir, tdd]
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

Rewrite the pure Elixir force layout as a tested, idempotent pure function using the spring-electrical model with adaptive step size and early termination

## Why(not)

In the face of **needing non-overlapping, center-clustered circle positions on the canvas**, instead of doing nothing (**continued oscillation and convergence failures**), we decided **to rewrite the layout as a pure, tested Elixir function with no temperature schedule, fixed step size, and convergence detection**, to achieve **reliable convergence with no new dependencies or architectural changes**, accepting **the risk of hitting the same tuning issues again, and O(n^2) computation that must complete within a single tick**.

## Points

### For

- [L2] No new dependencies, no JS, no build step changes - stays entirely server-side
- [L2] Fits naturally into the existing GenServer tick architecture
- [M1] TDD approach with explicit convergence tests catches oscillation before deployment
- [L3] Fixed step size + convergence detection replaces temperature schedule (fewer knobs)

### Against

- [M3] Still a custom implementation - not a proven library; we've failed at this 5 times already
- [M1] Spring-electrical equilibrium is mathematically tricky; may still oscillate at certain force ratios
- [L1] Must run enough iterations to converge within a single 1500ms tick; O(n^2) at 20 nodes = 400 pairs * iterations
- [M2] Overlap resolution as a post-pass can fight the force layout, creating instability

## Artistic

<!-- author this yourself -->

## Consequences

- [deps] No change - pure Elixir, no new dependencies
- [convergence] Depends on getting the force balance right; tests provide a safety net but don't guarantee the physics
- [dx] Existing architecture unchanged; ForceLayout module is a pure function callable from CanvasServer
- [ux] If convergence works: instant settled layout. If it doesn't: back to square one

<!-- evidence -->

## How

```elixir
defmodule MaudeLibs.ForceLayout do
  @step_size 0.05

  def layout(nodes) do
    # Fixed step: displacement = net_force * step_size
    # No temperature, no velocity - forces balance at equilibrium
    # Convergence detection: stop when total movement < threshold
    Enum.reduce_while(1..500, nodes, fn _, acc ->
      next = step(acc)
      if total_movement(acc, next) < 0.01, do: {:halt, next}, else: {:cont, next}
    end)
    |> resolve_overlaps()
  end

  # Forces: repulsion (k^2/dist^2) + center gravity (linear spring)
  # Step size is fixed and small enough to prevent oscillation
end
```

Key insight: no temperature means the function is idempotent. `layout(layout(x)) == layout(x)` because at equilibrium, forces net to zero, so `force * step_size == 0`.

## Reconsider

- observe: Tests pass but visual result looks wrong (clumped, uneven)
  respond: The force balance is wrong for this aesthetic goal; switch to d3-force client-side
- observe: O(n^2) computation exceeds tick budget at 20+ nodes
  respond: Reduce iterations or switch to client-side computation
- observe: Convergence tests are flaky due to floating point edge cases
  respond: Increase convergence threshold or use approximate equality

## Historic

Spring-electrical models for graph layout were formalized by Fruchterman and Reingold (1991). The key to convergence is simulated annealing (temperature cooling), but this makes the function non-idempotent. Using a fixed small step size instead trades convergence speed for stability, which is acceptable when we can run many iterations cheaply.

## More Info

- [Fruchterman-Reingold paper](https://doi.org/10.1002/spe.4380211102)
- [Graph Drawing by Force-directed Placement (Kobourov survey)](https://arxiv.org/abs/1201.3011)
