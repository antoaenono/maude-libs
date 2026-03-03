---
author: @antoaenono
asked: 2026-03-01
decided: 2026-03-01
status: superseded
deciders: @antoaenono
tags: [layout, viewport, navigation, canvas, scale, zoom-to-fit]
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

CSS fixed shell (flex column) for the persistent frame. Cards are positioned by the server in a fixed virtual coordinate space (e.g., 1000x700 "design pixels"). A single CSS `transform: scale()` applied to the canvas container shrinks or grows the entire layout to fit the actual remaining viewport. A minimal JS hook (ResizeObserver) computes the scale factor. LiveView renders all cards normally with full event handling.

## Why(not)

In the face of **needing persistent navigation and a viewport-aware canvas**, instead of doing nothing (**you can scroll and the header and breadcrumbs go out of view, the canvas has elements which are underneath the header... it's a mess**), we decided **to position cards in a fixed virtual coordinate space and scale the whole canvas to fit the viewport**, to achieve **guaranteed fit regardless of viewport size, deterministic server-computed positions, and uniform graceful degradation on small screens**, accepting **that everything shrinks uniformly on small viewports, which may make text small on very constrained screens**.

## Points

### For

- [M1] Fixed shell via CSS flex column - header/breadcrumbs/footer never scroll away
- [M2] Scale factor is computed as `min(containerW / virtualW, containerH / virtualH)`, guaranteeing the canvas fits any viewport
- [M3] On large viewports, the canvas scales up to fill available space; on small ones, it scales down uniformly rather than overlapping or clipping
- [M4] Same `stage_shell` component and same virtual coordinate space across all interactive stages
- [L1] No layout shift - scale transform doesn't trigger reflow; positions are static within the virtual space
- [L2] JS hook is ~15 lines: one ResizeObserver, one scale computation, one CSS variable update. No physics, no simulation, no tick loops
- [L3] `overflow-hidden` on root prevents scroll; fixed shell keeps navigation locked
- [L4] Card positions are in virtual pixels (deterministic, testable); the scale transform adapts to any container size without hardcoded values

### Against

- [M3] On very small viewports (e.g., phone in portrait), uniform scaling makes everything tiny rather than reflowing to use available space
- [L2] Still requires a JS hook for the ResizeObserver, not pure CSS (container query units could reduce this but can't fully replace it for scale transforms)
- [M2] Scale factor introduces a conceptual gap between "design coordinates" and "screen coordinates" that developers must keep in mind
- [L4] The virtual canvas dimensions (1000x700) are themselves a hardcoded value, though they're a design constant rather than a viewport assumption

## Artistic

A map. The territory doesn't change shape when you fold it smaller - it just
zooms out. The roads, the towns, the distances between them all stay proportional.
You can read the map at arm's length or squint at it folded in your pocket, but
the geography is always the same. The frame (header, breadcrumbs, footer) is the
map case - it holds the edges steady while the map scales inside it.

Server-side positioning is cartography: measure once, draw the map, done.
The zoom level is the only thing that changes, and that's just one number.

## Consequences

- [structure] One shared `stage_shell` component wraps all interactive stages with header, canvas, and footer slots
- [positioning] Server computes all card positions in a fixed virtual coordinate space (e.g., 1000x700); `StageLayout` returns `{x, y}` in virtual pixels
- [css] Canvas container uses `transform: scale(var(--canvas-scale))` and `transform-origin: center center`
- [js] One ResizeObserver hook (~15 lines) sets `--canvas-scale` CSS variable on the canvas element
- [testing] Card positions are deterministic and testable in ExUnit - no browser needed to verify layout logic
- [input] All phx-change, phx-submit, phx-click events work normally - LiveView owns the entire DOM
- [footer] Ready-up button in the fixed `shrink-0` footer, outside the scaled canvas
- [zoom] On small viewports, cards shrink uniformly. Text remains proportional and legible down to ~0.6x scale; below that, a minimum scale floor prevents unusability

## How

### Shell structure (same as fixed-shell-flex-canvas)

```heex
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

  <%!-- Scaled canvas: fills remaining space --%>
  <div id="stage-canvas"
       class="flex-1 relative overflow-hidden flex items-center justify-center"
       phx-hook="ScaleToFit">
    <div class="absolute"
         style={"width: #{@virtual_width}px; height: #{@virtual_height}px; transform: scale(var(--canvas-scale, 1)); transform-origin: center center;"}>
      {render_slot(@inner_block)}
    </div>
  </div>

  <%!-- Fixed bottom: ready-up footer --%>
  <div class="shrink-0 bg-base-100/80 backdrop-blur border-t border-base-300 px-8 py-3
              flex justify-center">
    {render_slot(@footer)}
  </div>
</div>
```

### Card rendering (LiveView-owned, virtual coordinates)

```heex
<%!-- Your input card --%>
<div class="absolute" style={"left: #{@my_pos.x}px; top: #{@my_pos.y}px; transform: translate(-50%, -50%);"}>
  <div class="card w-80 border-2 bg-base-100 shadow-md">
    <div class="card-body p-4 gap-2">
      <form phx-change="upsert_priority" phx-submit="upsert_priority">
        <input type="text" name="text" value={@my_text}
               class="input input-bordered input-sm w-full" />
      </form>
      <button phx-click="confirm_priority" class="btn btn-sm btn-primary">Confirm</button>
    </div>
  </div>
</div>

<%!-- Other participants --%>
<%= for {user, pos} <- @other_positions do %>
  <div class="absolute" style={"left: #{pos.x}px; top: #{pos.y}px; transform: translate(-50%, -50%);"}>
    <div class="card w-52 border-2 bg-base-100/80 shadow-md">
      <div class="card-body p-3 gap-1">
        <span class="font-mono text-xs"><%= user %></span>
        <p class="text-sm"><%= format_entry(user, @s) %></p>
      </div>
    </div>
  </div>
<% end %>

<%!-- Claude suggestion card --%>
<div class="absolute" style={"left: #{@claude_pos.x}px; top: #{@claude_pos.y}px; transform: translate(-50%, -50%);"}>
  ...claude content...
</div>
```

### JS Hook (~15 lines)

```javascript
// scale_to_fit.js
export const ScaleToFit = {
  mounted() {
    this.inner = this.el.querySelector("[style*='--canvas-scale']") || this.el.firstElementChild;
    this.virtualW = this.inner.offsetWidth;
    this.virtualH = this.inner.offsetHeight;

    this.observer = new ResizeObserver(() => this.rescale());
    this.observer.observe(this.el);
    this.rescale();
  },

  rescale() {
    const containerW = this.el.clientWidth;
    const containerH = this.el.clientHeight;
    const scale = Math.min(containerW / this.virtualW, containerH / this.virtualH);
    const clamped = Math.max(scale, 0.5); // minimum scale floor
    this.el.style.setProperty("--canvas-scale", clamped);
  },

  destroyed() {
    this.observer.disconnect();
  }
};
```

### Server-side positioning (deterministic, testable)

```elixir
defmodule MaudeLibsWeb.StageLayout do
  @virtual_width 1000
  @virtual_height 700

  def virtual_dimensions, do: {@virtual_width, @virtual_height}

  @doc "Returns {x, y} in virtual pixels for the current user's card."
  def your_pos, do: %{x: 500, y: 600}

  @doc "Returns {x, y} in virtual pixels for Claude's card."
  def claude_pos, do: %{x: 500, y: 300}

  @doc """
  Computes positions for other participants in virtual coordinates.
  Deterministic: same inputs always produce same outputs.
  """
  def compute_positions(other_users) do
    count = length(other_users)
    other_users
    |> Enum.with_index()
    |> Enum.map(fn {user, i} ->
      {user, position_for(i, count)}
    end)
  end

  defp position_for(index, count) do
    # Distribute evenly in an arc across the top half
    angle = :math.pi() * (index + 1) / (count + 1)
    %{
      x: round(500 + 300 * :math.cos(angle)),
      y: round(200 - 100 * :math.sin(angle) + 150)
    }
  end
end
```

This is fully testable:

```elixir
test "positions are deterministic" do
  pos1 = StageLayout.compute_positions(["alice", "bob"])
  pos2 = StageLayout.compute_positions(["alice", "bob"])
  assert pos1 == pos2
end

test "all positions within virtual bounds" do
  positions = StageLayout.compute_positions(["a", "b", "c", "d"])
  for {_user, %{x: x, y: y}} <- positions do
    assert x >= 0 and x <= 1000
    assert y >= 0 and y <= 700
  end
end
```

### Scale behavior at different viewports

| Viewport remaining | Scale factor | Effect |
|--------------------|-------------|--------|
| 1000x700 (exact match) | 1.0 | Pixel-perfect, no scaling |
| 1200x800 (larger) | 1.0 (capped) or 1.14 | Fills space, slight zoom in |
| 800x500 (laptop) | 0.71 | Everything 71% size, still legible |
| 500x400 (small) | 0.50 | Floor hit, minimum usable size |
| 375x300 (phone) | 0.50 | Floor, may need mobile-specific layout |

## Reconsider

- observe: Participants exceed 6-8 and deterministic arc placement gets crowded even in virtual space
  respond: Introduce server-side repulsion/spacing algorithm within virtual coordinates, or switch to d3-force position calculator
- observe: Text becomes unreadable below 0.5x scale on small viewports
  respond: Add a mobile-specific layout that stacks cards vertically instead of scaling
- observe: Need interactive features on the canvas itself (pan, zoom, drag cards)
  respond: Consider adding pan/zoom controls, which this approach supports naturally by adjusting transform scale and translate
- observe: Virtual dimensions (1000x700) don't match the aspect ratio of most real viewports, leaving dead space
  respond: Use multiple virtual aspect ratios (16:9, 4:3) and pick closest match, or let virtual height flex based on container aspect ratio
- observe: The /canvas hub page (D3 force circles) would also benefit from a fixed shell and scale-to-fit
  respond: Apply the same pattern to canvas_live.ex - the ScaleToFit hook and shell component are reusable

## Historic

The virtual canvas + scale-to-fit pattern is the foundation of every presentation tool (PowerPoint, Google Slides, Keynote), design tool (Figma, Sketch, Canva), and whiteboarding app (Miro, FigJam). They all define content in a fixed coordinate space and apply a view transform to map it to the screen. The CSS `transform: scale()` property is hardware-accelerated (runs on the compositor thread), making it effectively free in terms of rendering performance. This pattern predates responsive web design - it's how print layout has worked for centuries (design at a fixed size, scale to the paper).

## More Info

- [CSS transform: scale() - MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/transform-function/scale)
- [Scaled/Proportional Content with CSS and JavaScript - CSS-Tricks](https://css-tricks.com/scaled-proportional-blocks-with-css-and-javascript/)
- [CSS zoom property - MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/zoom)
- [ResizeObserver - MDN](https://developer.mozilla.org/en-US/docs/Web/API/ResizeObserver)
