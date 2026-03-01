---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [canvas, physics, force-layout, hybrid]
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

Use d3-force via a Node.js port/NIF called from the server, broadcasting final positions via PubSub; client only animates

## Why(not)

In the face of **needing non-overlapping, center-clustered circle positions on the canvas**, instead of doing nothing (**continued oscillation and convergence failures**), we decided **to call d3-force from the server via a Node.js port, computing positions server-side and broadcasting them via PubSub**, to achieve **proven d3-force convergence while keeping positions authoritative on the server**, accepting **a Node.js runtime dependency, port communication overhead, and operational complexity of managing a sidecar process**.

## Points

### For

- [M1] d3-force convergence is battle-tested; server computes it so all clients get the same result
- [M3] Uses the industry-standard algorithm without reimplementing it
- [M2] d3-force collision detection handles overlap natively

### Against

- [L2] Requires Node.js runtime alongside the BEAM; port/NIF communication adds moving parts
- [L2] Deployment now requires Node.js on the fly.io machine - different buildpack or multi-stage Docker
- [L3] d3-force API is simple, but the Elixir-to-Node bridge adds its own tuning surface (timeouts, encoding)
- [L1] Port communication adds latency on top of simulation time; may not be faster than native Elixir for 20 nodes

## Artistic

<!-- author this yourself -->

## Consequences

- [deps] Node.js runtime required; d3-force npm package; Elixir port/NIF wrapper module
- [convergence] Guaranteed by d3-force, but round-trip adds latency
- [dx] Must maintain both Elixir and JS code; port lifecycle management
- [ux] Positions are server-authoritative (good for spectators); animation via CSS transitions as before

<!-- evidence -->

## How

```elixir
# lib/maude_libs/d3_port.ex
defmodule MaudeLibs.D3Port do
  use GenServer

  def layout(nodes) do
    GenServer.call(__MODULE__, {:layout, nodes}, 5000)
  end

  # Opens a persistent Node.js process
  # Sends JSON: {nodes: [{id, x, y}]}
  # Receives JSON: {nodes: [{id, x, y}]} after simulation completes
end
```

```javascript
// priv/d3_layout/worker.js
const { forceSimulation, forceCenter, forceManyBody, forceCollide } = require("d3-force");
process.stdin.on("data", (buf) => {
  const { nodes } = JSON.parse(buf);
  const sim = forceSimulation(nodes)
    .force("charge", forceManyBody().strength(-200))
    .force("center", forceCenter(50, 50))
    .force("collide", forceCollide(7))
    .stop();
  for (let i = 0; i < 300; i++) sim.tick();
  process.stdout.write(JSON.stringify({ nodes }) + "\n");
});
```

## Reconsider

- observe: Port communication latency exceeds the 1500ms tick budget
  respond: Move to client-side d3-force; server only tracks circle metadata
- observe: Node.js process crashes or hangs
  respond: Add supervision and restart logic; consider fallback to simple grid layout

## Historic

Erlang ports are a well-established mechanism for calling external programs. The Elixir community uses them for ImageMagick, Pandoc, and other CLI tools. For computational tasks, ports add overhead but provide isolation.

## More Info

- [Elixir Port documentation](https://hexdocs.pm/elixir/Port.html)
- [d3-force documentation](https://d3js.org/d3-force)
