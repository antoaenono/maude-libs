---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [state-machine, presence, drop-handling]
parent: null
children: []
---

# SDT: Participant Drop Handling

## Scenario

How do we handle a participant's LiveView disconnecting mid-decision without blocking the remaining participants?

## Pressures

### More

1. [M1] Non-blocking - dropped users must never block ready-up or stage advance
2. [M2] Simplicity - no per-stage drop logic, no reconnection flows

### Less

1. [L1] State complexity - tracking presence separately from submissions adds a second truth
2. [L2] Surprise - remaining users should clearly see who is still present

## Chosen Option

connected: MapSet on Decision struct; terminate/2 removes user; all ready-up checks use connected

## Why(not)

In the face of **participants dropping from a live decision**, instead of doing nothing (**dropped users permanently block stage advancement - decision is stuck**), we decided **to maintain a top-level `connected: MapSet.t()` on the Decision struct, update it in LiveView terminate/2, and gate all ready-up/advance checks on connected set membership**, to achieve **automatic unblocking when a user drops, with zero per-stage logic**, accepting **that dropped users cannot rejoin and their submission slots silently disappear on re-render**.

## Points

### For

- [M1] `all_ready?(decision)` = `MapSet.subset?(connected, ready_set)` - always unblocks on drop
- [M2] No special case in Lobby, Scenario, Priorities, Options, Dashboard - the connected check is universal

### Against

- [L2] Other users see the slot vanish on next broadcast - could be startling without a visual indicator

## Artistic

<!-- author this yourself -->

## Consequences

- [data] Decision.connected: MapSet.t() maintained by Server on join/terminate
- [logic] All stage advance predicates check connected, not joined or all participants
- [ux] Dropped user's slot disappears on next broadcast re-render

## How

```elixir
# decision_live.ex
def terminate(_reason, socket) do
  Decision.Server.disconnect(socket.assigns.decision_id, socket.assigns.username)
end

# Core.handle
def handle(d, {:disconnect, user}) do
  {:ok, %{d | connected: MapSet.delete(d.connected, user)}, [{:broadcast, d.id, d}]}
end

# ready check helper
defp all_ready?(%Decision{connected: connected, stage: %Stage.Priorities{ready: ready}}) do
  MapSet.subset?(connected, ready)
end
```

## Reconsider

- observe: A decision gets stuck because all participants disconnected
  respond: Add a timeout or allow the last connected user to auto-advance after N minutes

## Historic

Phoenix Presence tracks this at the framework level for general apps. We opted out of Presence to keep the stack minimal and because our connected set needs to affect business logic (advance checks), not just UI indicators.

## More Info

- [Phoenix Presence docs](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
