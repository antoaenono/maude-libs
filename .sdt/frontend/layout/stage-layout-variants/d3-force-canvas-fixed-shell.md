---
author: @antoaenono
asked: 2026-03-01
decided: 2026-03-01
status: rejected
deciders: @antoaenono
tags: [layout, viewport, navigation, canvas, d3, force-layout]
parent: null
children: []
---

# SDT: Stage Layout

## Scenario

How should we structure the viewport layout for decision stages so that navigation (breadcrumbs, header) and action controls (ready-up) remain persistently visible while the central canvas area dynamically fills the remaining viewport for rendering participant cards, user inputs, and Claude suggestions?

## Pressures

### More

1. **M1: Persistent navigation** - breadcrumbs and header always visible regardless of scroll position
2. **M2: Viewport awareness** - canvas area dynamically sizes to fill remaining space after fixed elements
3. **M3: Content density** - maximize usable canvas space for participant cards and suggestions
4. **M4: Layout consistency** - same structural shell across all interactive stages (scenario, priorities, options)

### Less

1. **L1: Layout shift** - avoid content jumping when elements enter/leave the viewport
2. **L2: JavaScript complexity** - minimize JS hooks and client-side layout logic
3. **L3: Scroll confusion** - users should not accidentally scroll past navigation or lose context
4. **L4: CSS rigidity** - avoid hardcoded pixel values that break across screen sizes

## Chosen Option

Use the CSS fixed shell (flex column with shrink-0 header/footer) for the persistent frame, but replace the current server-side physics positioning with a D3 force-directed layout running in a LiveView JS hook inside the canvas region. Cards are rendered as HTML elements positioned by D3 forces, with user input fields as regular DOM nodes.

## Why(not)

In the face of **needing persistent navigation and a viewport-aware canvas**, instead of doing nothing (**you can scroll and the header and breadcrumbs go out of view, the canvas has elements which are underneath the header... it's a mess**), we decided **to combine a CSS fixed shell with a D3 force-directed canvas**, to achieve **persistent navigation plus battle-tested force layout positioning that adapts to canvas dimensions**, accepting **significant JavaScript complexity and a coupling between D3's layout engine and LiveView's DOM patching**.

## Points

### For

- [M1] Fixed shell via CSS flex column - header/breadcrumbs never scroll
- [M2] D3 force simulation reads canvas container dimensions and constrains nodes within bounds
- [M3] Force layout automatically distributes cards to maximize use of available space
- [M4] Same shell component across stages; D3 hook adapts to container size
- [L1] D3 handles repositioning smoothly via force simulation ticks
- [L4] D3 reads container dimensions at runtime, no hardcoded sizes

### Against

- [L2] Significant JavaScript: D3 hook, force simulation config, DOM element positioning, resize observers, LiveView interop via push_event/handleEvent
- [L2] D3's DOM manipulation conflicts with LiveView's morphdom patching - requires careful `phx-update="ignore"` boundaries or foreignObject workarounds
- [M3] `<foreignObject>` in SVG has inconsistent rendering across browsers for form inputs
- [L1] Resize events trigger force simulation restarts, causing brief card movement
- [M4] D3 hook configuration may differ per stage (different forces, constraints)

## Artistic

Hiring a puppeteer to arrange index cards on a table. The puppeteer (D3) is
brilliant at making things float and settle, but insists on controlling every
string. You can't write on the cards while the puppeteer is holding them -
you'd have to ask permission first, and the puppeteer speaks a different language
than your pen (LiveView). The frame around the table is solid, but the cards
themselves are caught between two masters.

## Consequences

- [deps] Adds d3-force (or full d3) as a JavaScript dependency
- [interop] Requires a LiveView JS hook with push_event for server-to-client data flow
- [dom] Canvas region must use `phx-update="ignore"` to prevent LiveView from clobbering D3-managed DOM
- [structure] Same CSS fixed shell as the flex-canvas option, plus D3 hook wiring
- [input] User input fields inside D3-positioned nodes need special handling (foreignObject in SVG, or absolutely-positioned HTML divs managed by D3)
- [footer] Ready-up button in the fixed footer, same as flex-canvas option
- [testing] D3 layout behavior is not testable via LiveView integration tests - requires browser automation

## How

Shell structure (identical to fixed-shell-flex-canvas):

```heex
<div class="h-dvh flex flex-col overflow-hidden">
  <nav class="shrink-0 ..."><.breadcrumbs .../></nav>
  <div class="shrink-0 ...">...header...</div>

  <%!-- D3-managed canvas --%>
  <div id="stage-canvas" class="flex-1 relative overflow-hidden"
       phx-hook="ForceCanvas"
       phx-update="ignore"
       data-participants={Jason.encode!(@participants)}
       data-suggestions={Jason.encode!(@suggestions)}>
    <%!-- D3 hook creates and positions child elements --%>
  </div>

  <div class="shrink-0 ...">
    <button phx-click="ready" class="btn btn-primary">Ready up</button>
  </div>
</div>
```

JS hook:

```javascript
// force_canvas.js
import { forceSimulation, forceCenter, forceManyBody, forceCollide } from "d3-force";

export const ForceCanvas = {
  mounted() {
    this.sim = forceSimulation()
      .force("center", forceCenter(this.width() / 2, this.height() / 2))
      .force("charge", forceManyBody().strength(-200))
      .force("collide", forceCollide(80))
      .on("tick", () => this.updatePositions());

    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(this.el);

    this.updateNodes(JSON.parse(this.el.dataset.participants));
  },

  updated() {
    // LiveView pushed new data
    this.updateNodes(JSON.parse(this.el.dataset.participants));
  },

  updateNodes(participants) {
    // Create/update HTML div elements for each participant
    // Position them absolutely within the container
    this.sim.nodes(participants).alpha(0.3).restart();
  },

  updatePositions() {
    // Move DOM elements to simulation-computed positions
    this.sim.nodes().forEach(node => {
      const el = document.getElementById(`card-${node.id}`);
      if (el) {
        el.style.left = `${node.x}px`;
        el.style.top = `${node.y}px`;
      }
    });
  },

  width() { return this.el.clientWidth; },
  height() { return this.el.clientHeight; },

  resize() {
    this.sim.force("center", forceCenter(this.width() / 2, this.height() / 2));
    this.sim.alpha(0.3).restart();
  },

  destroyed() {
    this.observer.disconnect();
    this.sim.stop();
  }
};
```

Key challenge: User input fields (`<input>`, `<textarea>`) inside D3-positioned divs. Since we use HTML divs (not SVG), form elements work natively. But the `phx-update="ignore"` boundary means LiveView won't patch these elements, so phx-change events must be wired manually or the input elements must live outside the D3-managed region.

## Reconsider

- observe: Only 3-5 participants per decision (small node count)
  respond: D3 force is overkill for small counts - the CSS flex-canvas approach with percentage positioning is simpler and sufficient
- observe: LiveView morphdom conflicts cause input focus loss or stale renders
  respond: Isolate D3-managed region more carefully or switch to server-side positioning
- observe: User input fields inside D3 nodes cause form submission issues
  respond: Move input fields outside the D3 region or use a hybrid approach

## Historic

D3-force is the gold standard for graph/network visualization layout. It was designed for SVG node positioning in data visualizations. Using it for app UI layout (with form inputs, buttons, text areas) is unconventional. Most apps that need "canvas-like" positioning of interactive elements use CSS (absolute/grid) rather than D3, reserving D3 for pure visualization. The `foreignObject` approach for embedding HTML in SVG has a history of browser inconsistencies, particularly with form elements.

## More Info

- [D3 Force Simulation](https://d3js.org/d3-force/simulation)
- [LiveView JS Hooks](https://hexdocs.pm/phoenix_live_view/js-interop.html)
- [phx-update="ignore"](https://hexdocs.pm/phoenix_live_view/dom-patching.html)
