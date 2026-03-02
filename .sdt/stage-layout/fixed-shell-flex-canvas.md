---
author: @antoaenono
asked: 2026-03-01
decided: 2026-03-01
status: rejected
deciders: @antoaenono
tags: [layout, viewport, navigation, canvas, css]
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

Use a full-viewport flex column with a fixed shell: header and breadcrumbs pinned to the top, ready-up footer pinned to the bottom, and a `flex-1 overflow-hidden` canvas region in the middle. Pure CSS/Tailwind, no JavaScript.

## Why(not)

In the face of **needing persistent navigation and a viewport-aware canvas**, instead of doing nothing (**you can scroll and the header and breadcrumbs go out of view, the canvas has elements which are underneath the header... it's a mess**), we decided **to use a full-viewport flex column with fixed shell regions**, to achieve **persistent navigation, a dynamically-sized canvas, and a consistent stage structure**, accepting **that the canvas area is slightly smaller due to fixed header/footer space**.

## Points

### For

- [M1] Header and breadcrumbs are `shrink-0` flex children at the top - they never scroll away
- [M2] Canvas region is `flex-1` and automatically fills remaining viewport height
- [M3] Canvas gets maximum available space after subtracting header and footer heights
- [M4] Single wrapper component (`stage_shell`) used by all interactive stages
- [L1] No layout shift - all regions are statically sized by flexbox, no dynamic insertion/removal
- [L2] Zero JavaScript - pure CSS flexbox handles all sizing
- [L3] `overflow-hidden` on the root prevents any scroll on the page body
- [L4] No pixel values - flexbox distributes space proportionally

### Against

- [M3] Fixed header + footer consume vertical space, reducing canvas area (roughly 100-120px total)
- [L4] If header content wraps on small screens, it pushes the canvas down further

## Artistic

A picture frame. The moulding (header, breadcrumbs, footer) is bolted to the wall,
rigid and always visible. The canvas inside stretches to fill whatever the frame
allows. You can rearrange what's on the canvas, but the frame itself never moves.
Simple, structural, and the kind of thing you stop noticing because it just works.

## Consequences

- [structure] One shared `stage_shell` component wraps all interactive stages
- [css] Root element uses `h-screen flex flex-col overflow-hidden` to lock the viewport
- [scroll] Body scroll is eliminated entirely for stage views
- [refactor] Each stage component drops its own `w-screen h-screen` wrapper and renders only its canvas content
- [footer] Ready-up button moves from inline card content to a dedicated `shrink-0` footer region

## How

Layout structure:

```heex
<%!-- stage_shell component --%>
<div class="h-dvh flex flex-col overflow-hidden">
  <%!-- Fixed top: breadcrumbs --%>
  <nav class="shrink-0 bg-base-100/60 backdrop-blur border-b border-base-300/50 px-4 py-2">
    <.breadcrumbs ... />
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
  <div class="flex-1 relative overflow-hidden">
    {render_slot(@inner_block)}
  </div>

  <%!-- Fixed bottom: ready-up footer --%>
  <div class="shrink-0 bg-base-100/80 backdrop-blur border-t border-base-300 px-8 py-3
              flex justify-center">
    {render_slot(@footer)}
  </div>
</div>
```

Each stage component uses the shell:

```heex
<.stage_shell stage_label="Priorities" topic={@decision.topic}
              instruction="Add your dimensions" breadcrumbs={...}>
  <%!-- Canvas content: absolutely-positioned cards --%>
  <div class="absolute ..." style={"left: #{x}%; top: #{y}%;"}>
    ...card...
  </div>

  <:footer>
    <button phx-click="ready_priority" class="btn btn-primary">
      Ready up
    </button>
  </:footer>
</.stage_shell>
```

Key CSS properties:
- `h-dvh` - uses dynamic viewport height (accounts for mobile browser chrome)
- `flex flex-col` - vertical stack
- `shrink-0` - header/footer don't compress
- `flex-1` - canvas takes remaining space
- `overflow-hidden` - prevents scroll on all regions
- `relative` on canvas - positioning context for absolute children

## Reconsider

- observe: Header or footer content grows beyond ~60px each, squeezing the canvas too much
  respond: Collapse header details behind a toggle or move breadcrumbs into the header row
- observe: Stages need internal scrolling (e.g., dashboard with many options)
  respond: Allow `overflow-y-auto` on the canvas region for specific stages
- observe: Mobile viewport is too constrained for fixed header + footer + canvas
  respond: Consider collapsible header or bottom-sheet pattern for mobile

## Historic

This is the standard "app shell" pattern used by most single-page applications (Gmail, Slack, Figma). The flex column with shrink-0 header/footer and flex-1 content is the canonical CSS approach for fixed-region layouts without JavaScript. Phoenix LiveView's component slots map cleanly to this pattern.

## More Info

- [CSS Tricks: Full-Height App Layouts](https://css-tricks.com/fun-viewport-units/)
- [Tailwind: Flex Shrink](https://tailwindcss.com/docs/flex-shrink)
- [dvh units](https://developer.mozilla.org/en-US/docs/Web/CSS/length#dynamic_viewport_units)
