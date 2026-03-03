---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [state-machine, presence, drop-handling]
parent: null
children: [backend/state-machine/disconnect-grace-period]
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

connected + participants MapSets on Decision struct; terminate/2 triggers a 5-second grace period before removal; all ready-up checks use connected; participants persists across reconnects

## Why(not)

In the face of **participants dropping from a live decision**, instead of doing nothing (**dropped users permanently block stage advancement - decision is stuck**), we decided **to maintain `connected: MapSet.t()` and `participants: MapSet.t()` on the Decision struct, with a 5-second grace period between disconnect and removal from connected**, to achieve **automatic unblocking when a user drops, with zero per-stage logic, while allowing brief reconnects (e.g., page refresh) without losing the user**, accepting **that after the grace period, dropped users are removed from `connected` but remain in `participants` for spectator/rejoin detection**.

## Points

### For

- [M1] `all_ready?(decision)` = `MapSet.subset?(connected, ready_set)` - always unblocks on drop
- [M2] No special case in Lobby, Scenario, Priorities, Options, Dashboard - the connected check is universal

### Against

- [L2] Other users see the slot vanish on next broadcast - could be startling without a visual indicator

## Artistic

<!-- author this yourself -->

## Consequences

- [data] Decision.connected: MapSet.t() - currently active users. Decision.participants: MapSet.t() - all users who ever joined (persists across disconnects)
- [logic] All stage advance predicates check connected, not joined or participants
- [grace] 5-second window (configurable via `disconnect_grace_ms`) allows reconnects without removal
- [ux] Dropped user's slot disappears after grace period on next broadcast

## How

```elixir
# decision_live.ex
def terminate(_reason, socket) do
  Decision.Server.disconnect(socket.assigns.id, socket.assigns.username)
end

# Server - schedules disconnect with grace period
def handle_cast({:disconnect, user}, state) do
  ref = Process.send_after(self(), {:disconnect_timeout, user}, @disconnect_grace_ms)
  {:noreply, %{state | disconnect_timers: Map.put(state.disconnect_timers, user, ref)}}
end

def handle_info({:disconnect_timeout, user}, state) do
  # Grace period expired, now actually disconnect
  case Core.handle(state.decision, {:disconnect, user}) do
    {:ok, d2, effects} -> # dispatch effects, update state
  end
end

# Reconnect cancels pending disconnect
def handle_call({:message, {:connect, user}}, _from, state) do
  if timer = state.disconnect_timers[user] do
    Process.cancel_timer(timer)
  end
  # proceed with connect
end

# Core.handle - pure
def handle(d, {:disconnect, user}) do
  {:ok, %{d | connected: MapSet.delete(d.connected, user)}, [{:broadcast, d.id, d}]}
end
```

## Reconsider

- observe: A decision gets stuck because all participants disconnected
  respond: Add a timeout or allow the last connected user to auto-advance after N minutes

## Historic

Phoenix Presence tracks this at the framework level for general apps. We opted out of Presence to keep the stack minimal and because our connected set needs to affect business logic (advance checks), not just UI indicators.

## More Info

- [Phoenix Presence docs](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
