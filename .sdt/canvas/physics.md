---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [canvas, physics, simulation]
parent: null
children: [canvas/force-layout-strategy]
---

# SDT: Canvas Repulsion Model

## Scenario

How do we animate decision circles on the canvas so they spread out visibly without overwhelming the implementation?

## Pressures

### More

1. [M1] Visual liveliness - circles should visibly move and feel alive
2. [M2] Implementation simplicity - prototype timeline, no physics lib budget
3. [M3] Predictable behavior - circles shouldn't fly off screen or stack

### Less

1. [L1] CPU/server load - tick runs server-side on every connected LiveView
2. [L2] Complexity of tuning - spring constants, damping factors should have obvious defaults

## Chosen Option

Custom minimal repulsion: 1/r^2 repulsion between pairs, weak center attraction, velocity damping 0.85 per tick

## Why(not)

In the face of **animating decision circles on a shared canvas**, instead of doing nothing (**circles pile up at origin and don't communicate spatial separation**), we decided **to implement a minimal custom force simulation with pairwise repulsion, center attraction, and per-tick velocity damping**, to achieve **organic spreading behavior that reads as "alive" without any physics library dependency**, accepting **hand-tuned constants that may need adjustment and O(n^2) pair calculations (fine at <= 20 circles)**.

## Points

### For

- [M1] Circles visibly drift apart over 2-3 ticks, creating organic feel
- [M2] ~40 lines of math in a GenServer tick - no library to install or learn
- [M3] Center attraction acts as a soft boundary; velocity cap prevents runaway

### Against

- [L1] Tick runs every 1500ms server-side; at 10 decisions that's 45 pair calculations per tick - trivial
- [L2] Three magic numbers (repulsion_strength, attraction_strength, damping) - document in comments

## Artistic

<!-- author this yourself -->

## Consequences

- [physics] Custom 1/r^2 repulsion + center pull + 0.85 damping, 1500ms tick
- [scope] No external physics library needed
- [tuning] Three constants in canvas_server.ex to adjust feel

## How

```elixir
# Per tick, for each pair {a, b}:
dx = a.x - b.x; dy = a.y - b.y
dist = max(sqrt(dx*dx + dy*dy), 50)  # min distance cap
force = repulsion_strength / (dist * dist)
# apply to both velocities in opposite directions

# Center attraction
a.vx += -attraction_strength * a.x
a.vy += -attraction_strength * a.y

# Damping
a.vx *= 0.85; a.vy *= 0.85
a.x += a.vx; a.y += a.vy
```

## Reconsider

- observe: Circles overlap or shake at small counts
  respond: Increase min_distance cap or repulsion_strength
- observe: Circles drift to edges at large counts
  respond: Increase attraction_strength or add hard boundary clamp

## Historic

Force-directed graph layouts (D3-force, etc.) use the same principle at larger scale. We're just doing it server-side with a simplified model since we don't need full graph layout - just gentle spreading.

## More Info

- [D3 force simulation concepts](https://d3js.org/d3-force)
