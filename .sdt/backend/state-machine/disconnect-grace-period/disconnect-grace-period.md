---
author: @antoaenono
asked: 2026-03-02
decided: 2026-03-02
status: accepted
deciders: @antoaenono
tags: [state-machine, presence, disconnect, reconnect, grace-period]
parent: backend/state-machine/drop-handling/drop-handling
children: []
---

# SDT: Disconnect Grace Period

## Scenario

When a participant's LiveView disconnects (page refresh, network hiccup, tab switch on mobile), should they be immediately removed from the connected set, or should there be a grace window for reconnection?

## Pressures

### More

1. [M1] Reconnect tolerance - page refreshes and brief network drops should not remove a participant from the decision
2. [M2] Non-blocking - if a user truly leaves, the remaining participants must not stay blocked indefinitely

### Less

1. [L1] Complexity - timer management adds state to the Server (pending disconnect timers per user)
2. [L2] Stale presence - during the grace window, a disconnected user appears "connected" even though they're gone

## Chosen Option

5-second grace period: Server schedules a `{:disconnect_timeout, user}` message on disconnect; reconnect within 5s cancels the timer; configurable via `disconnect_grace_ms`

## Why(not)

In the face of **participants disconnecting due to page refresh, network hiccup, or mobile tab switching**, instead of doing nothing (**immediate removal causes a participant to lose their place on every page refresh, triggering re-render and potentially advancing the stage**), we decided **to buffer disconnects with a 5-second grace period managed by `Process.send_after` in the Server**, to achieve **seamless reconnects where a page refresh doesn't disrupt the decision flow**, accepting **that during the grace window a disconnected user still counts as "connected" and their card remains visible**.

## Points

### For

- [M1] Page refresh round-trip is typically 1-2 seconds; 5 seconds covers even slow connections
- [M2] After 5 seconds, the user is definitively removed; ready-up checks unblock immediately
- [L1] Timer management is ~10 lines in the Server: store ref in a map, cancel on reconnect

### Against

- [L2] Brief ghost presence: other users see the card for up to 5 seconds after a real departure
- [L1] Must track `disconnect_timers: %{username => timer_ref}` in Server state

## Artistic

<!-- author this yourself -->

## Consequences

- [server] Server state includes `disconnect_timers: %{}` map of pending timer refs
- [config] `disconnect_grace_ms` configurable (default 5000, set to 0 in tests for instant disconnect)
- [reconnect] `{:connect, user}` and `{:join, user}` cancel any pending disconnect timer for that user
- [ux] Page refresh is invisible to other participants

## How

```elixir
# Server - disconnect triggers delayed removal
def handle_cast({:disconnect, user}, state) do
  ref = Process.send_after(self(), {:disconnect_timeout, user}, @disconnect_grace_ms)
  {:noreply, put_in(state, [:disconnect_timers, user], ref)}
end

# Grace period expired
def handle_info({:disconnect_timeout, user}, state) do
  state = update_in(state.disconnect_timers, &Map.delete(&1, user))
  case Core.handle(state.decision, {:disconnect, user}) do
    {:ok, d2, effects} ->
      new_state = Enum.reduce(effects, %{state | decision: d2}, &dispatch_effect/2)
      {:noreply, new_state}
  end
end

# Reconnect cancels pending disconnect
def handle_call({:message, {:connect, user}}, _from, state) do
  state = cancel_disconnect_timer(state, user)
  # proceed with connect...
end

defp cancel_disconnect_timer(state, user) do
  case state.disconnect_timers[user] do
    nil -> state
    ref ->
      Process.cancel_timer(ref)
      update_in(state.disconnect_timers, &Map.delete(&1, user))
  end
end
```

## Reconsider

- observe: 5 seconds feels too long; ghost presence confuses other participants
  respond: Reduce to 2-3 seconds; or add a visual "reconnecting..." indicator during grace period
- observe: 5 seconds feels too short; mobile users on slow networks time out
  respond: Increase to 10 seconds; consider exponential backoff for repeated disconnects

## Historic

WebSocket reconnect grace periods are standard in multiplayer apps. Slack uses ~30 seconds before showing "disconnected". Most gaming frameworks use 5-15 seconds. Phoenix LiveView's own reconnect mechanism retries with backoff, but doesn't notify the application until the connection is re-established.

## More Info

- [Phoenix LiveView reconnect behavior](https://hexdocs.pm/phoenix_live_view/js-interop.html#handling-server-pushed-events)
