---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [realtime, pubsub, architecture]
parent: null
children: []
---

# SDT: Decision State Broadcast Model

## Scenario

How does the Decision.Server broadcast state changes to all connected LiveViews for a given decision?

## Pressures

### More

1. [M1] Simplicity - broadcast mechanism should require minimal setup
2. [M2] Full state delivery - LiveViews should always re-render from complete decision state, not patches

### Less

1. [L1] Stale renders - a LiveView should never show state older than the last broadcast
2. [L2] Over-engineering - diff/patch protocols add complexity we don't need at prototype scale

## Chosen Option

Broadcast full Decision struct on every state change; LiveViews assign and re-render

## Why(not)

In the face of **delivering decision state changes to all connected LiveViews**, instead of doing nothing (**LiveViews pull state on demand - possible stale reads, no real-time updates**), we decided **to broadcast the full Decision struct via PubSub on every mutation and have LiveViews re-assign and re-render**, to achieve **guaranteed consistency with zero diff logic - every LiveView always has the latest complete state**, accepting **that the full Decision struct is sent on every change (fine at prototype scale with small structs and <= 4 participants)**.

## Points

### For

- [M1] One PubSub topic per decision: "decision:{id}"; subscribe in mount, handle_info re-assigns
- [M2] No patch logic; LiveView's own diffing handles efficient DOM updates

### Against

- [L2] Full struct broadcast is slightly wasteful; irrelevant for <20 decisions with small payloads

## Artistic

<!-- author this yourself -->

## Consequences

- [transport] Topic: "decision:{id}", payload: {:decision_updated, decision}
- [liveview] mount/2 subscribes; handle_info updates socket assigns
- [consistency] All LiveViews for the same decision are always in sync after each broadcast

## How

```elixir
# Server effect dispatch
defp dispatch_effect({:broadcast, id, decision}) do
  Phoenix.PubSub.broadcast(MaudeLibs.PubSub, "decision:#{id}", {:decision_updated, decision})
end

# decision_live.ex mount
Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{id}")

def handle_info({:decision_updated, decision}, socket) do
  {:noreply, assign(socket, decision: decision)}
end
```

## Reconsider

- observe: Broadcast payload becomes large (many options with long for/against text)
  respond: Switch to broadcasting only the changed stage field or a diff

## Historic

Full-state broadcast is the standard Phoenix LiveView pattern for multiplayer apps at this scale. Shopify, Fly.io internal tools, and most LiveView demos use this approach.

## More Info

- [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub)
