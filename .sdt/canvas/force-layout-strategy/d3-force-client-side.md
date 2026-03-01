---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [canvas, physics, force-layout, d3, javascript, libgraph]
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

Use d3-force in a LiveView JS hook for layout computation, with libgraph as the server-side graph data structure. Server sends node metadata (size, visibility, fixed position) via push_event; D3 handles physics and rendering.

## Why(not)

In the face of **needing non-overlapping, center-clustered circle positions on the canvas**, instead of doing nothing (**continued oscillation and convergence failures after 5+ tuning attempts**), we decided **to delegate layout computation to d3-force running client-side in a LiveView JS hook, backed by libgraph on the server**, to achieve **battle-tested force simulation with native support for fixed nodes, variable sizing, and visibility filtering**, accepting **a JS dependency and hook-based interop between LiveView and D3**.

## Points

### For

- [M1] d3-force has been used in production for 10+ years; convergence is solved via alpha decay
- [M1] Native `fx`/`fy` support pins our center + button without custom code
- [M2] Built-in `forceCollide()` handles overlap using node radius - no post-pass hacks
- [M2] `forceManyBody()` repulsion + `forceCenter()` naturally clusters nodes near center
- [M3] No custom physics to debug - d3-force is the industry standard for exactly this problem
- [L1] d3-force converges in ~300 ticks at 60fps, meaning sub-second visual settling
- [L3] Declarative API: `forceCenter()`, `forceCollide(r)`, `forceManyBody().strength(n)` - three knobs total

### Against

- [L2] Adds d3-force JS dependency (~30KB) and a LiveView hook
- [L2] Positions live client-side; late-joining spectators see a fresh simulation run (acceptable - settles in <1s)
- [L2] Must coordinate LiveView assigns with hook lifecycle (mounted/updated/destroyed)

## Artistic

<!-- author this yourself -->

## Consequences

- [deps] Add d3-force as npm dependency; optionally add libgraph hex package for server-side graph structure
- [convergence] Guaranteed by d3-force alpha decay; no hand-tuning required
- [dx] LiveView hook pattern is well-documented; hook manages its own simulation lifecycle
- [ux] 60fps smooth animation during settling; circles spread naturally; fixed center node stays pinned
- [migration] Remove CanvasServer physics simulation; server becomes a pure data source (which circles exist, their metadata)

<!-- evidence -->

## How

**Server side** - CanvasServer (or libgraph) tracks circle metadata:

```elixir
# Node data sent to client via push_event
%{
  id: "decision-123",
  size: 15,           # radius in px, maps to forceCollide
  visible: true,
  fx: nil, fy: nil,   # nil = free, set = pinned
  title: "Where to eat?",
  stage: :lobby
}

# Center + button is a fixed node
%{id: "+", size: 20, visible: true, fx: 400, fy: 300}
```

**Client side** - LiveView hook:

```javascript
// assets/js/hooks/canvas_force.js
import { forceSimulation, forceCenter, forceManyBody, forceCollide } from "d3-force";

export const CanvasForce = {
  mounted() {
    this.sim = forceSimulation()
      .force("charge", forceManyBody().strength(-200))
      .force("center", forceCenter(this.cx(), this.cy()))
      .force("collide", forceCollide(d => d.size + 4))
      .on("tick", () => this.render());

    this.handleEvent("circles_updated", ({ nodes }) => {
      const visible = nodes.filter(n => n.visible !== false);
      this.sim.nodes(visible);
      this.sim.alpha(0.3).restart();
    });
  },
  render() {
    // Update positioned div elements from simulation node.x/node.y
    // D3 respects fx/fy automatically - center + node stays pinned
  }
};
```

**Migration path:**
1. Add d3-force npm dep
2. Create CanvasForce hook
3. Simplify CanvasServer: remove simulate/resolve_overlaps, keep only circle metadata tracking + PubSub broadcast of metadata changes (not positions)
4. canvas_live.ex: render a hook container, push_event on circle changes instead of positioning via server assigns

## Reconsider

- observe: LiveView hook lifecycle issues cause layout glitches on reconnect
  respond: Push full node list on mounted; hook re-runs simulation from scratch (fast - sub-second)
- observe: Need server-authoritative positions for a feature (e.g., server-side screenshot)
  respond: Add a periodic position sync from client back to server, or accept that screenshots show initial positions
- observe: Want to add edges between decisions later (e.g., dependencies)
  respond: libgraph on server models edges; pass links array to D3; add `forceLink()` to simulation

## Historic

d3-force is the canonical JS force-directed layout library, extracted from D3.js v4. It implements velocity Verlet integration with configurable forces. The `fx`/`fy` pinning mechanism was added specifically to support mixed fixed/free node layouts. Used by GitHub's dependency graph, Observable notebooks, and thousands of data visualizations. libgraph is the standard Elixir graph data structure library, providing efficient vertex/edge storage with metadata labels.

## More Info

- [d3-force documentation](https://d3js.org/d3-force)
- [D3 fx/fy fixed nodes](https://d3js.org/d3-force/simulation#simulation_nodes)
- [LiveView JS hooks guide](https://hexdocs.pm/phoenix_live_view/js-interop.html)
- [libgraph on Hex](https://hex.pm/packages/libgraph)
