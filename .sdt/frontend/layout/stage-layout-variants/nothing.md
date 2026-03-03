---
author: @antoaenono
asked: 2026-03-01
decided: 2026-03-01
status: rejected
deciders: @antoaenono
tags: [layout, viewport, navigation, canvas]
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

Do nothing. Keep the current inline flex layout.

## Why(not)

In the face of **needing persistent navigation and a viewport-aware canvas**, instead of doing nothing (**you can scroll and the header and breadcrumbs go out of view, the canvas has elements which are underneath the header... it's a mess**), we decided **to do nothing**, to achieve **no additional implementation effort**, accepting **continued layout problems and poor UX**.

## Points

### For

- [M4] No code changes means no risk of breaking existing stage rendering
- [L2] Zero JavaScript additions
- [L1] No new layout mechanics that could introduce shift

### Against

- [M1] Breadcrumbs and header scroll out of view - users lose navigation context
- [M2] Canvas area is not constrained to remaining viewport - cards overlap header
- [M3] No guarantee of usable canvas space, elements render under fixed-position elements
- [L3] Users can scroll past everything and lose orientation
- [L4] Current layout already has implicit pixel assumptions in absolute positioning

## Artistic

A piece of paper taped to a wall with masking tape that's losing its stick.
The header peels away as you look down, the breadcrumbs curl up and vanish.
You're left staring at cards scattered on a desk with no frame around them,
reaching for a navigation bar that already slid off the top of the screen.

## Consequences

- [ux] Users continue losing navigation context when scrolling
- [overlap] Canvas elements render underneath header and breadcrumbs
- [debt] Layout problems accumulate as more stages are added
- [onboarding] New users confused by disappearing navigation

## Evidence

<!-- optional epistemological layer -->

## How

No changes. Current implementation:
- Breadcrumbs and header are inline in a `flex flex-col` container
- Canvas uses `flex-1 relative overflow-hidden` but isn't viewport-constrained
- Ready-up button is embedded within each stage's card content
- Cards use absolute positioning with percentage-based coordinates within the unconstrained flex area

## Reconsider

- observe: Users report confusion about where they are in the flow
  respond: Revisit this decision
- observe: Cards consistently render behind header elements
  respond: Revisit this decision

## Historic

The current layout was built incrementally as stages were added. Each stage manages its own full-viewport container (`w-screen h-screen`) but the parent flex column doesn't enforce fixed regions, so the breadcrumbs and header participate in the normal document flow.

## More Info

- [Phoenix LiveView Layouts](https://hexdocs.pm/phoenix_live_view/live-layouts.html)
