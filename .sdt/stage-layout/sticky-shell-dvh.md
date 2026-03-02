---
author: @antoaenono
asked: 2026-03-01
decided: 2026-03-01
status: rejected
deciders: @antoaenono
tags: [layout, viewport, navigation, canvas, css, sticky]
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

Use `position: sticky` for the header/breadcrumbs and footer, with `dvh` viewport units to size the overall container. The canvas area scrolls independently if content overflows.

## Why(not)

In the face of **needing persistent navigation and a viewport-aware canvas**, instead of doing nothing (**you can scroll and the header and breadcrumbs go out of view, the canvas has elements which are underneath the header... it's a mess**), we decided **to use sticky positioning with dynamic viewport units**, to achieve **persistent navigation that still participates in document flow**, accepting **that sticky positioning has edge cases with nested scroll containers and older browser support for dvh**.

## Points

### For

- [M1] Sticky header stays visible at the top of the scroll container
- [M2] `dvh` units account for dynamic browser chrome (mobile address bar)
- [M4] Same sticky wrapper can be reused across stages
- [L2] No JavaScript needed - pure CSS
- [L4] `dvh` units are responsive to actual viewport, no pixel values

### Against

- [M1] Sticky positioning fails inside `overflow: hidden` ancestors - requires careful container nesting
- [M2] `dvh` units need a scroll container to be meaningful, but the canvas stages don't want scroll
- [M3] Sticky elements still occupy flow space but can overlap content during scroll, causing visual confusion
- [L1] Sticky-to-fixed transition can cause a subtle visual "jump" as the element attaches
- [L3] If the body is scrollable, users can still scroll past the sticky region's scroll container boundary
- [L4] `dvh` browser support is good but not universal (Safari 15.4+, Chrome 108+)

## Artistic

Sticky notes on a whiteboard. They stay where you put them - until someone bumps
the board and they peel off at the edges. Sticky positioning is the CSS equivalent:
it works until it doesn't, and when it breaks it breaks subtly, leaving you
debugging invisible scroll containers and wondering why the footer floats away.

## Consequences

- [structure] Root container needs explicit height (`h-[100dvh]`) to establish scroll context
- [css] Sticky elements require `top: 0` / `bottom: 0` and a scrollable parent
- [compat] Older browsers fall back to `vh`, which doesn't account for mobile browser chrome
- [scroll] Canvas stages would need `overflow: hidden` while dashboard stages use `overflow: auto`
- [footer] Sticky footer at bottom requires the container to be at least viewport height

## How

```heex
<div class="h-[100dvh] overflow-y-auto">
  <%!-- Sticky header --%>
  <nav class="sticky top-0 z-10 bg-base-100/60 backdrop-blur border-b border-base-300/50 px-4 py-2">
    <.breadcrumbs ... />
  </nav>

  <div class="sticky top-[40px] z-10 bg-base-100/80 backdrop-blur border-b border-base-300 px-8 py-4
              flex flex-col items-center gap-1">
    ...header content...
  </div>

  <%!-- Canvas content --%>
  <div class="h-[calc(100dvh-160px)] relative overflow-hidden">
    {render_slot(@inner_block)}
  </div>

  <%!-- Sticky footer --%>
  <div class="sticky bottom-0 z-10 bg-base-100/80 backdrop-blur border-t border-base-300 px-8 py-3
              flex justify-center">
    {render_slot(@footer)}
  </div>
</div>
```

Problems with this approach:
- Multiple sticky elements at different offsets (`top-0`, `top-[40px]`) require knowing header heights
- Canvas height uses `calc(100dvh - 160px)` which reintroduces pixel assumptions
- Sticky bottom footer in a scroll container only works when content exceeds viewport

## Reconsider

- observe: Only canvas-type stages are used (no scrollable stages)
  respond: Switch to the simpler flex column approach since sticky's scroll flexibility isn't needed
- observe: Browser support for dvh becomes universal
  respond: Simplify fallback rules
- observe: Multiple stacked sticky elements cause z-index or overlap issues
  respond: Collapse to a single sticky header bar

## Historic

Sticky positioning was introduced in CSS as a hybrid between `static` and `fixed`. It's designed for elements that should scroll with content until they reach a boundary, then "stick." It's well-suited for long scrollable pages with section headers, but less ideal for app-shell layouts where nothing should scroll at the page level.

## More Info

- [MDN: position sticky](https://developer.mozilla.org/en-US/docs/Web/CSS/position#sticky)
- [Can I Use: dvh units](https://caniuse.com/viewport-unit-variants)
