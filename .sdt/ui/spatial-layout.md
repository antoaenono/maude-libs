---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [ui, layout, css]
parent: null
children: []
---

# SDT: Input Stage Participant Card Geometry

## Scenario

How do we position participant input cards spatially on the three input stages (scenario, priorities, options) to communicate the shared spatial model?

## Pressures

### More

1. [M1] Learnable layout - users learn the spatial model once and apply it across all three stages
2. [M2] Clarity - "your input" vs "others' inputs" vs "Claude suggestion" must be visually distinct

### Less

1. [L1] Responsive complexity - desktop only; no need for mobile layout variants
2. [L2] Dynamic positioning - calculating card positions at runtime adds JS or complex CSS

## Chosen Option

Absolute positioning with hardcoded percentage-based CSS classes per participant count (1, 2, 3 others)

## Why(not)

In the face of **arranging participant input cards and Claude suggestion on a shared stage canvas**, instead of doing nothing (**linear list - loses spatial metaphor that distinguishes the app**), we decided **to use absolute positioning with three hardcoded CSS layout variants (for 1, 2, or 3 other participants) and fix Claude suggestion at center, your input at bottom**, to achieve **a consistent spatial vocabulary across all three input stages with zero runtime layout calculation**, accepting **that layouts are hardcoded for exactly 1-3 others (matching max 4 participants constraint)**.

## Points

### For

- [M1] Same positions across scenario/priorities/options; users internalize "center = Claude, bottom = me"
- [M2] Three CSS classes (`layout-1-other`, `layout-2-others`, `layout-3-others`) cover all cases
- [L2] No JS, no requestAnimationFrame; pure CSS absolute positioning

### Against

- [L1] Three hardcoded layouts cover exactly max-4-participant constraint; adding a 5th participant breaks the layout (fine - we cap at 4)

## Artistic

<!-- author this yourself -->

## Consequences

- [css] Three layout utility classes for 1/2/3 other participants
- [positions] Others: top-center (1), upper-left + upper-right (2), top + upper-left + upper-right (3)
- [fixed] Claude suggestion: always dead center; your input: always bottom-center

## How

```css
/* 1 other participant */
.layout-1-other .participant-0 { top: 10%; left: 50%; transform: translateX(-50%); }

/* 2 other participants */
.layout-2-others .participant-0 { top: 15%; left: 25%; }
.layout-2-others .participant-1 { top: 15%; right: 25%; }

/* 3 other participants */
.layout-3-others .participant-0 { top: 8%; left: 50%; transform: translateX(-50%); }
.layout-3-others .participant-1 { top: 20%; left: 15%; }
.layout-3-others .participant-2 { top: 20%; right: 15%; }

/* Fixed positions */
.claude-center { top: 45%; left: 50%; transform: translate(-50%, -50%); }
.your-input { bottom: 2rem; left: 50%; transform: translateX(-50%); }
```

## Reconsider

- observe: Layout breaks with 5+ participants
  respond: Already capped at 4; if cap is raised, add a layout-4-others CSS class

## Historic

Spatial card layouts are used in remote collaboration tools like Miro and FigJam for ideation activities. The "your card at bottom, others around the circle" metaphor maps to how people sit around a table.

## More Info

- [relevant link](https://example.com)
