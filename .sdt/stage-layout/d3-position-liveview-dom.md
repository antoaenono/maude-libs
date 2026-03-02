---
author: @antoaenono
asked: 2026-03-01
decided: 2026-03-01
status: rejected
deciders: @antoaenono
tags: [layout, viewport, navigation, canvas, d3, force-layout, liveview]
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

CSS fixed shell (flex column) for the persistent frame. LiveView renders all cards as normal HEEx with full phx-change/phx-submit/phx-click event handling. A lightweight JS hook runs d3-force purely as a position calculator and applies computed positions as CSS transforms to LiveView-rendered card wrapper elements. LiveView owns the DOM; D3 only does math.

## Why(not)

In the face of **needing persistent navigation and a viewport-aware canvas**, instead of doing nothing (**you can scroll and the header and breadcrumbs go out of view, the canvas has elements which are underneath the header... it's a mess**), we decided **to use a CSS fixed shell with D3-force as a position-only calculator while LiveView owns all DOM rendering**, to achieve **persistent navigation, viewport-aware force layout positioning, and fully functional LiveView form inputs**, accepting **a JS hook dependency for position calculation and the need to re-apply positions after LiveView patches**.

## Points

### For

- [M1] Fixed shell via CSS flex column - header/breadcrumbs never scroll away
- [M2] D3 reads canvas container dimensions via ResizeObserver and constrains node positions within bounds
- [M3] Force layout automatically distributes cards to fill available canvas space, adapting as participants join/leave
- [M4] Same `stage_shell` component across all interactive stages; hook adapts to container size
- [L1] D3 smoothly transitions card positions via force ticks; no layout jumps
- [L2] JS hook is thin - just d3-force math + applying transform styles. No DOM creation, no event wiring, no `phx-update="ignore"`. LiveView handles all interactivity.
- [L3] `overflow-hidden` on root prevents scroll; fixed shell keeps navigation locked
- [L4] D3 reads container dimensions at runtime; positions are computed in pixels relative to actual canvas size

### Against

- [L2] Still requires a JS hook, ResizeObserver, and d3-force dependency - more JS than pure CSS approach
- [L1] After LiveView morphdom patches, hook must re-apply positions in `updated()` callback - brief flash possible if not handled carefully
- [M4] Hook configuration (force strengths, collision radius) may need per-stage tuning
- [L2] Need to coordinate between LiveView re-renders and D3 simulation state - e.g., when a participant joins, new node data must flow to the hook

## Artistic

The current approach feels like pinning index cards to a corkboard that keeps falling
off the wall. What we actually want is a magnetic whiteboard: the frame stays put
(header, breadcrumbs, footer bolted to the wall), the surface fills whatever space
you give it, and the cards drift apart from each other like they're repelling magnets.
You can still write on each card freely - the magnets move the card, not the pen.

D3-force is the magnet physics. LiveView is the pen. CSS flexbox is the wall mount.
Each layer does one thing well and doesn't interfere with the others.

## Consequences

- [deps] Adds d3-force as a JS dependency (small, tree-shakeable - ~15KB)
- [structure] One shared `stage_shell` component wraps all interactive stages with slots for canvas content and footer
- [interop] JS hook reads node data from element data attributes, computes positions, applies CSS transforms
- [dom] No `phx-update="ignore"` - LiveView fully owns the card DOM, including form inputs
- [input] All phx-change, phx-submit, phx-click events work exactly as they do today
- [footer] Ready-up button moves to a dedicated `shrink-0` footer slot
- [testing] Card content and events fully testable via LiveViewTest; only position accuracy requires browser tests
- [refactor] Each stage drops its own `w-screen h-screen` wrapper and renders cards as children of the shell's canvas slot

## How

### Shell structure

```heex
<%!-- stage_shell component --%>
<div class="h-dvh flex flex-col overflow-hidden">
  <%!-- Fixed top: breadcrumbs --%>
  <nav class="shrink-0 bg-base-100/60 backdrop-blur border-b border-base-300/50 px-4 py-2">
    <.breadcrumbs {stage_breadcrumb_assigns} />
  </nav>

  <%!-- Fixed top: stage header --%>
  <div class="shrink-0 bg-base-100/80 backdrop-blur border-b border-base-300 px-8 py-4
              flex flex-col items-center gap-1">
    <span class="text-xs font-mono text-base-content/40 uppercase tracking-widest">
      {@stage_label}
    </span>
    <span class="text-lg font-semibold text-base-content">{@topic}</span>
    <span class="text-xs text-base-content/40">{@instruction}</span>
  </div>

  <%!-- Dynamic canvas: fills remaining space --%>
  <div id="stage-canvas"
       class="flex-1 relative overflow-hidden"
       phx-hook="ForceLayout"
       data-nodes={Jason.encode!(@node_data)}>
    {render_slot(@inner_block)}
  </div>

  <%!-- Fixed bottom: ready-up footer --%>
  <div class="shrink-0 bg-base-100/80 backdrop-blur border-t border-base-300 px-8 py-3
              flex justify-center">
    {render_slot(@footer)}
  </div>
</div>
```

### Card rendering (LiveView-owned)

Cards are rendered by LiveView as normal HEEx. Each card wrapper has a `data-node-id`
that the hook uses to apply position transforms:

```heex
<%!-- Your input card - fully interactive --%>
<div id={"card-#{@username}"} data-node-id={@username}
     class="absolute transition-all duration-500 ease-out will-change-transform">
  <div class="card w-80 border-2 bg-base-100 shadow-md">
    <div class="card-body p-4 gap-2">
      <form phx-change="upsert_priority" phx-submit="upsert_priority">
        <input type="text" name="text" value={@my_text}
               class="input input-bordered input-sm w-full" />
      </form>
      <button phx-click="confirm_priority" class="btn btn-sm btn-primary">
        Confirm
      </button>
    </div>
  </div>
</div>

<%!-- Other participant cards - read-only, live-updating --%>
<%= for {user, pos} <- @other_positions do %>
  <div id={"card-#{user}"} data-node-id={user}
       class="absolute transition-all duration-500 ease-out will-change-transform">
    <div class="card w-52 border-2 bg-base-100/80 shadow-md">
      <div class="card-body p-3 gap-1">
        <span class="font-mono text-xs"><%= user %></span>
        <p class="text-sm"><%= Map.get(@s.priorities, user) |> format() %></p>
      </div>
    </div>
  </div>
<% end %>
```

### JS Hook (position-only)

```javascript
// force_layout.js
import { forceSimulation, forceCenter, forceManyBody, forceCollide } from "d3-force";

export const ForceLayout = {
  mounted() {
    this.positions = new Map();
    this.initSimulation();
    this.observer = new ResizeObserver(() => this.handleResize());
    this.observer.observe(this.el);
    this.syncNodes();
  },

  updated() {
    // LiveView patched the DOM - re-sync nodes and re-apply positions
    this.syncNodes();
    this.applyPositions();
  },

  initSimulation() {
    this.sim = forceSimulation()
      .force("center", forceCenter(this.cx(), this.cy()))
      .force("charge", forceManyBody().strength(-300))
      .force("collide", forceCollide(100).strength(0.8))
      .force("bounds", this.boundsForce())
      .alphaDecay(0.05)
      .on("tick", () => this.applyPositions());
  },

  syncNodes() {
    const raw = JSON.parse(this.el.dataset.nodes || "[]");
    // Preserve existing positions for nodes that haven't changed
    const nodes = raw.map(n => {
      const existing = this.positions.get(n.id);
      return existing
        ? { ...n, x: existing.x, y: existing.y, vx: existing.vx, vy: existing.vy }
        : { ...n, x: this.cx() + (Math.random() - 0.5) * 100,
                   y: this.cy() + (Math.random() - 0.5) * 100 };
    });
    this.sim.nodes(nodes).alpha(0.3).restart();
  },

  applyPositions() {
    this.sim.nodes().forEach(node => {
      this.positions.set(node.id, { x: node.x, y: node.y, vx: node.vx, vy: node.vy });
      const el = this.el.querySelector(`[data-node-id="${node.id}"]`);
      if (el) {
        el.style.transform = `translate(${node.x}px, ${node.y}px) translate(-50%, -50%)`;
      }
    });
  },

  boundsForce() {
    const self = this;
    return function(alpha) {
      const w = self.el.clientWidth;
      const h = self.el.clientHeight;
      const pad = 80;
      for (const node of self.sim.nodes()) {
        if (node.x < pad) node.vx += alpha * 10;
        if (node.x > w - pad) node.vx -= alpha * 10;
        if (node.y < pad) node.vy += alpha * 10;
        if (node.y > h - pad) node.vy -= alpha * 10;
      }
    };
  },

  handleResize() {
    this.sim.force("center", forceCenter(this.cx(), this.cy()));
    this.sim.alpha(0.3).restart();
  },

  cx() { return this.el.clientWidth / 2; },
  cy() { return this.el.clientHeight / 2; },

  destroyed() {
    this.observer.disconnect();
    this.sim.stop();
  }
};
```

### Key design: separation of concerns

| Layer | Responsibility | Owns DOM? |
|-------|---------------|-----------|
| CSS flexbox | Fixed shell (header, footer, canvas region sizing) | Yes (structure) |
| LiveView HEEx | Card content, forms, events, real-time updates | Yes (content) |
| D3-force hook | Position computation, applying CSS transforms | No (style only) |

The hook never creates or destroys DOM elements. It only reads `data-nodes` and writes
`style.transform` on elements that LiveView already rendered. This means:

- `phx-change` fires normally on every keystroke (priorities, options)
- `phx-submit` fires normally on Enter (scenario)
- `phx-click` fires normally for confirm/ready/vote buttons
- PubSub broadcasts trigger LiveView re-renders as usual
- Other participants' cards update in real-time via assigns
- The `updated()` callback re-applies positions after every LiveView patch

### Migration from current StageLayout

Replace `StageLayout.compute()` calls with `data-nodes` attribute generation:

```elixir
defp node_data(decision, username) do
  others = decision.connected
    |> MapSet.delete(username)
    |> Enum.map(fn user -> %{id: user, type: "participant"} end)

  claude = if has_claude_content?(decision),
    do: [%{id: "claude", type: "claude"}], else: []

  you = [%{id: username, type: "self"}]

  Jason.encode!(others ++ claude ++ you)
end
```

## Reconsider

- observe: Participant count stays consistently at 3-5 and positions feel natural with fixed percentage placement
  respond: Drop D3 and use the simpler fixed-shell-flex-canvas with server-computed percentage positions
- observe: LiveView morphdom patches cause visible position flicker despite re-applying in updated()
  respond: Add `phx-update="ignore"` to card position wrappers only (not card content), or debounce re-apply
- observe: D3-force simulation doesn't settle quickly enough, cards feel "floaty"
  respond: Increase alphaDecay, reduce force strengths, or switch to a spring model with critical damping
- observe: Need to animate card entry/exit (e.g., participant joins/leaves)
  respond: Add CSS transition classes and coordinate with D3 node add/remove

## Historic

This approach - using a physics engine purely for position computation while a framework owns the DOM - is common in game UI (Unity's physics + UI toolkit) and React visualization libraries (react-force-graph renders React components at d3-computed positions). The pattern avoids the "two masters" problem where both D3 and the framework fight over DOM mutations. LiveView's `updated()` hook callback is the explicit coordination point, similar to React's `useEffect` re-applying positions after renders.

## More Info

- [D3 Force Simulation](https://d3js.org/d3-force/simulation)
- [LiveView JS Hooks](https://hexdocs.pm/phoenix_live_view/js-interop.html)
- [will-change CSS property](https://developer.mozilla.org/en-US/docs/Web/CSS/will-change)
