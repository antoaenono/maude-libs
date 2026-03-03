---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [realtime, ux, invite, lobby]
parent: null
children: [realtime/invite-mechanism/user-registry]
---

# SDT: Invite and Discovery Mechanism

## Scenario

How do invited participants discover and navigate to a decision they've been invited to join?

## Pressures

### More

1. [M1] Low friction - invited users should reach the decision in one click
2. [M2] No out-of-band coordination - the app should surface the invite without needing a separate message

### Less

1. [L1] Infrastructure complexity - push notifications, email, or SMS are out of scope
2. [L2] Polling overhead - canvas shouldn't need to poll for invites

## Chosen Option

Per-user PubSub topic (`"user:#{username}"`) delivers invite notifications; canvas shows a modal; creator uses add/remove list UI with UserRegistry autocomplete

## Why(not)

In the face of **notifying invited participants about a new decision**, instead of doing nothing (**invited users must manually navigate to /d/:id - requires out-of-band sharing of the URL**), we decided **to broadcast invites via per-user PubSub topics (`"user:#{username}"`) so only the invited user receives the notification, with creator-side add/remove list UI backed by UserRegistry autocomplete**, to achieve **targeted in-app invite delivery that requires no external messaging**, accepting **that offline users will miss the invite and must navigate directly via URL**.

## Points

### For

- [M1] Server broadcasts `{:invited, id, topic}` to `"user:#{username}"` topic; canvas_live subscribes on mount; shows modal with Join button
- [M2] No email, no SMS, no external service needed; all within the LiveView WebSocket
- [M1] Creator uses add/remove list UI with `UserRegistry.list_usernames()` autocomplete; each invite is a single `add_invite` event

### Against

- [L2] Canvas subscribes to both `"canvas"` (circle updates) and `"user:#{username}"` (invites) - two topics

## Artistic

<!-- author this yourself -->

## Consequences

- [ux] Modal on canvas when invited; one click to join the lobby
- [transport] Per-user topic `"user:#{username}"` carries invite events; `"canvas"` topic carries circle metadata updates
- [creator-ux] Add/remove list with autocomplete from ETS-backed UserRegistry
- [limitation] Offline users miss the live invite; must join via direct URL

## How

```elixir
# Server broadcasts invite to per-user topic
for username <- MapSet.to_list(decision.stage.invited) do
  if username not in decision.stage.joined do
    Phoenix.PubSub.broadcast(MaudeLibs.PubSub, "user:#{username}", {:invited, id, decision.topic})
  end
end

# canvas_live.ex subscribes on mount
Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "user:#{username}")

def handle_info({:invited, id, topic}, socket) do
  {:noreply, assign(socket, invite: %{id: id, topic: topic})}
end

# Creator adds invites via add/remove list UI
def handle_event("add_invite", %{"username" => username}, socket) do
  Server.handle_message(socket.assigns.id, {:lobby_update, creator, topic, new_invited})
end
```

## Reconsider

- observe: Users miss invites because they're not on /canvas
  respond: Add a persistent "pending invites" badge visible from /d/:id

## Historic

In-app notification via WebSocket is the standard SPA pattern. We get it for free with PubSub - no polling, no push service needed.

## More Info

- [relevant link](https://example.com)
