---
author: @antoaenono
asked: 2026-03-01
decided: 2026-03-02
status: accepted
deciders: @antoaenono
tags: [layout, d3, force-layout, scale-to-fit, js-hooks, virtual-canvas, viewport]
parent: null
children: []
supersedes: [layout/force-layout-strategy/d3-force-client-side, layout/stage-layout-variants/virtual-canvas-scale-to-fit]
---

# SDF: Client-Side D3 Force Layout with Scale-to-Fit Virtual Canvas


## Scenario

How do we position decision circles on the lobby canvas and participant cards on stage views so that layouts are non-overlapping, visually balanced, responsive to viewport size, and work within LiveView's DOM patching model?

## Pressures

### More

1. [M1] Convergence reliability - layout must settle to a stable state regardless of node count (4-20 on lobby, 2-5 on stages)
2. [M2] Visual quality - elements should be evenly spaced, centered, no overlaps
3. [M3] Implementation confidence - use a proven algorithm, not hand-tuned magic constants
4. [M4] Persistent navigation - breadcrumbs/header always visible; canvas fills remaining viewport
5. [M5] Layout consistency - same structural shell and coordinate system across all interactive stages

### Less

1. [L1] Settling time - layout should reach equilibrium sub-second
2. [L2] JavaScript complexity - minimize hooks and client-side logic
3. [L3] CSS rigidity - avoid hardcoded pixel values that break across screen sizes
4. [L4] LiveView interop friction - hooks must coexist with LiveView's DOM patching

## Decision

Three-layer architecture: (1) CSS fixed shell for persistent navigation, (2) D3 force simulation in JS hooks for position computation, (3) scale-to-fit transform on a virtual canvas for viewport adaptation. Two distinct D3 hooks serve the lobby canvas and stage views respectively.

## Why(not)


In the face of **needing non-overlapping layouts on both the lobby canvas and stage views, responsive to any viewport size, within LiveView's rendering model**,
instead of doing nothing
(**server-side physics that oscillated and failed to converge, plus hardcoded CSS percentage positions that broke at different participant counts**),
we decided **to use d3-force client-side in LiveView JS hooks for position computation, rendered onto a fixed virtual canvas (1000x900) that scales to fit the viewport**,
to achieve **battle-tested force simulation, guaranteed viewport fit, and clean separation where LiveView owns the DOM and D3 only computes positions**,
accepting **d3-force as a JS dependency, three hooks to maintain, and a conceptual gap between virtual coordinates and screen coordinates**.

## Points

### For

- [M1] d3-force convergence is battle-tested via alpha decay; `CanvasForce` uses `forceManyBody` + `forceCollide`, `StageForce` uses `forceX`/`forceY` to deterministic targets
- [M2] Lobby: circles repel from center node and each other. Stages: cards pulled to pre-computed arc positions by role (claude=center, you=below, others=arc above)
- [M3] No custom physics to debug; d3-force is the industry standard
- [M4] CSS flex column shell: `shrink-0` header/footer, `flex-1` canvas region with `overflow-hidden`
- [M5] Same `stage_shell` component and 1000x900 virtual canvas across all interactive stages
- [L1] Sub-second settling on both lobby and stage views
- [L2] Three hooks total: `CanvasForce` (~80 lines), `StageForce` (~90 lines), `ScaleToFit` (~25 lines)
- [L3] Virtual canvas dimensions are design constants; `ScaleToFit` adapts to any viewport
- [L4] LiveView owns all card DOM via HEEx; hooks only read `data-node-id`/`data-node-role` attributes and write `style.left`/`style.top` or `style.transform`

### Against

- [L2] Three JS hooks + a simulation module is more JS than a pure CSS approach
- [L3] Virtual canvas 1000x900 is a hardcoded design constant (though it scales to any viewport)
- [L4] StageForce `updated()` callback must re-sync DOM nodes after LiveView patches; brief position flash possible

## Consequences

- [deps] `d3-force` as npm dependency (~30KB tree-shakeable)
- [hooks] Three registered hooks: `CanvasForce`, `StageForce`, `ScaleToFit`
- [server] `CanvasServer` is metadata-only (title, tagline, stage); no server-side physics
- [dom] Stage cards use `data-node-id` and `data-node-role` attributes as the contract between LiveView and JS
- [input] All phx-change, phx-submit, phx-click events work normally; LiveView owns the DOM
- [testing] Position logic testable in JS (Vitest); card content testable in LiveViewTest; only visual accuracy requires browser

## Evidence

d3-force is the canonical JS force-directed layout library with 10+ years of production use. The virtual canvas + scale-to-fit pattern is the foundation of every presentation tool (Slides, Keynote) and whiteboarding app (Miro, FigJam). CSS `transform: scale()` is hardware-accelerated on the compositor thread. This three-layer approach emerged after iterating through server-side physics (oscillation failures), pure CSS positioning (inflexible), and D3-manages-DOM (conflicts with LiveView patching).

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

### Architecture overview

| Layer | Responsibility | Key file |
|-------|---------------|----------|
| CSS flex shell | Fixed header/footer, viewport containment | `stage_shell.ex` |
| ScaleToFit hook | Scale virtual canvas to viewport | `scale_to_fit.js` |
| StageForce hook | D3 force layout for stage cards | `stage_force.js` + `stage_simulation.js` |
| CanvasForce hook | D3 force layout for lobby circles | `canvas_force.js` |

### Stage shell (CSS fixed shell)

```heex
<div class="h-dvh flex flex-col overflow-hidden bg-base-200">
  <.breadcrumbs stage={@decision.stage} />
  <div class="shrink-0">...stage header...</div>
  <div id="stage-canvas" phx-hook="ScaleToFit" class="flex-1 min-h-0 relative overflow-hidden">
    <div id="stage-force" phx-hook="StageForce" data-testid="virtual-canvas"
         class="absolute select-none" style="width: 1000px; height: 900px;">
      {render_slot(@inner_block)}
    </div>
  </div>
  <div class="shrink-0">...footer (ready-up)...</div>
</div>
```

### ScaleToFit hook

```javascript
const ScaleToFit = {
  mounted() {
    this.inner = this.el.querySelector("[data-testid='virtual-canvas']");
    this.observer = new ResizeObserver(() => this.rescale());
    this.observer.observe(this.el);
    this.rescale();
  },
  updated() { this.rescale(); },
  rescale() {
    const cW = this.el.clientWidth, cH = this.el.clientHeight;
    const vW = this.inner.offsetWidth, vH = this.inner.offsetHeight;
    const scale = Math.max(Math.min(cW / vW, cH / vH), 0.5);
    const offX = (cW - vW * scale) / 2, offY = (cH - vH * scale) / 2;
    this.inner.style.transform = `translate(${offX}px, ${offY}px) scale(${scale})`;
    this.inner.style.transformOrigin = "0 0";
  },
  destroyed() { this.observer.disconnect(); }
};
```

### StageForce hook (position computation)

Cards are rendered by LiveView as normal HEEx with `data-node-id` and `data-node-role` attributes. The hook scans for these, computes target positions by role, and applies via `style.left`/`style.top`:

```javascript
// stage_simulation.js - target computation
function computeTargets(nodes, canvasW, canvasH) {
  const cx = canvasW / 2, cy = canvasH / 2;  // 500, 450
  // claude: fixed at center (cx, cy)
  // you: below center (cx, cy + 300)
  // others: arc above center, radius 250, angle range 0.2pi-0.8pi
}

// D3 simulation: forceX + forceY pulling to targets, no forceCollide
const sim = forceSimulation(nodes)
  .force("x", forceX(d => targets[d.id].x).strength(1))
  .force("y", forceY(d => targets[d.id].y).strength(1))
  .alphaDecay(0.1).velocityDecay(0.6);
```

### CanvasForce hook (lobby circles)

Lobby canvas uses origin-centered coordinates with `forceManyBody` (repulsion) + `forceCollide` (collision). A fixed center node at (0,0) acts as the + button anchor. Circles are created as DOM elements by the hook.

```javascript
this.sim = forceSimulation()
  .force("charge", forceManyBody().strength(-300))
  .force("collide", forceCollide(d => d.size + 6).strength(1))
  .alphaDecay(0.02);
```

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: LiveView morphdom patches cause visible position flicker despite StageForce.updated()
  respond: Add CSS transitions to card wrappers, or debounce re-apply
- observe: Stage participant count exceeds 6-8 and arc placement gets crowded
  respond: Switch stage simulation to use forceCollide in addition to forceX/forceY
- observe: Text becomes unreadable below 0.5x scale on small viewports
  respond: Add mobile-specific layout that stacks cards vertically instead of scaling
- observe: Want server-authoritative positions (e.g., screenshots)
  respond: Add periodic position sync from client back to server

## Artistic

A map. The territory doesn't change shape when you fold it smaller - it just
zooms out. The roads, the towns, the distances between them all stay proportional.
The frame (header, breadcrumbs, footer) is the map case - bolted to the wall.
The magnets (D3 forces) keep the cards from piling up. LiveView draws the cards;
the magnets move them; the frame holds everything steady.

## Historic

d3-force is the canonical JS force-directed layout library, extracted from D3.js v4. The virtual canvas + scale-to-fit pattern is the foundation of every presentation tool (Slides, Keynote), design tool (Figma, Canva), and whiteboarding app (Miro, FigJam). CSS `transform: scale()` is hardware-accelerated on the compositor thread. This three-layer approach (CSS shell + JS hooks + scale transform) emerged from iterating through server-side physics (oscillation failures), pure CSS positioning (inflexible), and D3-manages-DOM (conflicts with LiveView patching).

## More Info

- [d3-force documentation](https://d3js.org/d3-force)
- [LiveView JS hooks guide](https://hexdocs.pm/phoenix_live_view/js-interop.html)
- [CSS transform: scale() - MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/transform-function/scale)
- [ResizeObserver - MDN](https://developer.mozilla.org/en-US/docs/Web/API/ResizeObserver)
