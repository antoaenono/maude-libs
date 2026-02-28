---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [canvas, layout, circles]
parent: null
children: []
---

# SDT: Canvas Circle Spawn Position

## Scenario

Where do new decision circles appear when created, and how are they initially positioned on the canvas?

## Pressures

### More

1. [M1] Immediate visibility - new circle should be easy to find
2. [M2] Non-overlap with existing circles - spawning on top of another is confusing

### Less

1. [L1] Complexity - spawning logic should be a few lines

## Chosen Option

Spawn at canvas center + small random offset (±50px); physics spreads them from there

## Why(not)

In the face of **positioning newly created decision circles on a shared canvas**, instead of doing nothing (**all circles pile up at 0,0**), we decided **to spawn at center with a small random jitter and let the repulsion physics spread them naturally**, to achieve **a visible "birth" moment at the center of attention followed by organic drift**, accepting **brief overlap when multiple decisions are created quickly (resolved in 2-3 ticks)**.

## Points

### For

- [M1] Center is always in view; users see the new circle immediately
- [M2] Random jitter + repulsion resolves overlap within ~3 seconds
- [L1] Two lines: x = canvas_width/2 + :rand.uniform(100) - 50

### Against

- [M2] Brief overlap possible if two decisions created within one tick window (~1.5s)

## Artistic

<!-- author this yourself -->

## Consequences

- [spawn] New circles at center ± 50px random offset
- [physics] Repulsion handles spreading; no explicit placement algorithm needed

## How

```elixir
def spawn_circle(id, title) do
  %{
    x: @canvas_width / 2 + :rand.uniform(100) - 50,
    y: @canvas_height / 2 + :rand.uniform(100) - 50,
    vx: 0.0, vy: 0.0,
    title: title, tagline: nil, stage: :lobby
  }
end
```

## Reconsider

- observe: Many decisions created at once cause a tight cluster that takes too long to spread
  respond: Increase initial random offset range or apply one-time strong repulsion burst on spawn

## Historic

Most graph tools spawn at cursor position or grid. Center-with-jitter is simpler and works well for a small canvas where the + button is fixed at center.

## More Info

- [relevant link](https://example.com)
