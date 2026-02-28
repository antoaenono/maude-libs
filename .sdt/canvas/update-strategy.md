---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [canvas, realtime, pubsub]
parent: null
children: []
---

# SDT: Canvas Position Delivery to Client

## Scenario

How do updated circle positions (from the server-side physics tick) reach connected LiveView clients?

## Pressures

### More

1. [M1] Low latency - positions should update smoothly on client
2. [M2] Consistency with existing infrastructure - we already use PubSub for decision state

### Less

1. [L1] Implementation complexity - no new transport mechanism
2. [L2] Client-side JS - prefer minimal JS hooks

## Chosen Option

PubSub broadcast from CanvasServer tick; canvas_live.ex handle_info re-renders; CSS transitions smooth movement

## Why(not)

In the face of **delivering physics-tick position updates to canvas LiveView clients**, instead of doing nothing (**circles are static, no physics**), we decided **to broadcast updated positions via Phoenix PubSub from the CanvasServer tick and use CSS transitions on circle divs for smooth interpolation**, to achieve **consistent real-time updates using the same PubSub pattern used for decision state, with zero additional JS**, accepting **that position updates are batched per tick (1.5s) rather than frame-by-frame - smooth enough for slow organic movement**.

## Points

### For

- [M1] CSS `transition: transform 1.4s ease` makes 1.5s ticks appear smooth
- [M2] PubSub broadcast is already the pattern for decision state; canvas reuses it
- [L1] No SSE endpoint, no WebSocket channel, no polling loop - one PubSub topic
- [L2] Zero JS hooks needed; Phoenix.LiveView handles the WebSocket

### Against

- [M1] 1.5s tick means positions are always slightly stale; not an issue for slow decorative movement

## Artistic

<!-- author this yourself -->

## Consequences

- [transport] PubSub topic "canvas:positions", broadcast on each tick
- [client] CSS transitions handle interpolation; no requestAnimationFrame needed
- [consistency] Same PubSub pattern as decision state broadcasts

## How

```elixir
# CanvasServer tick
Phoenix.PubSub.broadcast(MaudeLibs.PubSub, "canvas:positions", {:positions, circles})

# canvas_live.ex
def handle_info({:positions, circles}, socket) do
  {:noreply, assign(socket, circles: circles)}
end
```

```heex
<div style={"transform: translate(#{circle.x}px, #{circle.y}px); transition: transform 1.4s ease"}>
```

## Reconsider

- observe: Circles stutter or jump (CSS transition too short for tick interval)
  respond: Adjust transition duration to match tick_ms - 100ms

## Historic

LiveView + PubSub is the idiomatic Phoenix pattern. SSE or polling would add complexity for no benefit at this update frequency.

## More Info

- [Phoenix PubSub docs](https://hexdocs.pm/phoenix_pubsub)
