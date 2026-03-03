---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [realtime, ux, spectator]
parent: null
children: []
---

# SDT: Spectator / Read-Only View

## Scenario

How do non-participants (observers, dropped users) view a decision in progress without disrupting it?

## Pressures

### More

1. [M1] Zero disruption - spectators must not be able to accidentally send messages or trigger effects
2. [M2] Implementation simplicity - separate LiveView vs param on same LiveView

### Less

1. [L1] Code duplication - separate LiveView duplicates all rendering logic
2. [L2] Route complexity - a separate /d/:id/watch route adds another entry to the router

## Chosen Option

Same decision_live.ex; check `username in decision.connected` to gate input controls; spectators see all but can't interact

## Why(not)

In the face of **rendering a read-only decision view for non-participants**, instead of doing nothing (**no spectator support - only participants can see the decision**), we decided **to reuse decision_live.ex and conditionally render input controls based on whether the current user is in `decision.connected`**, to achieve **zero code duplication and a single LiveView that handles both participant and spectator modes**, accepting **that a bug in the gate condition could accidentally expose inputs to spectators (mitigated by the Core rejecting messages from non-connected users)**.

## Points

### For

- [M2] No separate module, no router entry; just `if @username in @decision.connected` in heex
- [L1] All rendering logic lives once; spectator mode is purely a UI rendering difference

### Against

- [M1] If the input gate fails, a spectator could submit a form - but Core.handle rejects non-connected users anyway (defense in depth)

## Artistic

<!-- author this yourself -->

## Consequences

- [ux] Spectators see all stage content live via PubSub but have no input controls rendered
- [routing] Same /d/:id route serves both participants and spectators
- [security] Core rejects messages from users not in connected set (backup guard)

## How

```heex
<%= if @username in @decision.connected do %>
  <.priority_input form={@form} />
  <.confirm_button />
<% end %>
<!-- All participants' entries always visible to everyone -->
<.priorities_list priorities={@decision.stage.priorities} />
```

## Reconsider

- observe: Spectators want to interact (e.g., ask to join)
  respond: Add a "request to join" mechanic that creator can approve

## Historic

Most LiveView multiplayer apps use the same pattern: one LiveView, role-gated rendering. Phoenix Presence-based examples typically do this with presence metadata flags.

## More Info

- [relevant link](https://example.com)
