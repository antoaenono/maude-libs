---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [realtime, ux, invite, lobby]
parent: null
children: []
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

Canvas shows a toast/modal when a new decision appears that lists your username in invited; clicking joins

## Why(not)

In the face of **notifying invited participants about a new decision**, instead of doing nothing (**invited users must manually navigate to /d/:id - requires out-of-band sharing of the URL**), we decided **to broadcast the new decision to all canvas LiveViews via PubSub and show a prompt to users whose username is in the invited list**, to achieve **in-app invite discovery that requires no external messaging and works as long as the invitee is on /canvas**, accepting **that offline users will miss the invite and must ask the creator to add them later or navigate directly**.

## Points

### For

- [M1] PubSub broadcast to "canvas:decisions" topic; canvas_live checks if username in invited; renders toast
- [M2] No email, no SMS, no external service needed; all within the LiveView WebSocket

### Against

- [L2] Canvas subscribes to "canvas:decisions" for invite notifications + position updates - two topics or one combined

## Artistic

<!-- author this yourself -->

## Consequences

- [ux] Toast/modal on canvas when invited; one click to join the lobby
- [transport] "canvas:decisions" PubSub topic carries new decision events
- [limitation] Offline users miss the live invite; must join via direct URL or creator re-invite

## How

```elixir
# canvas_live.ex handle_info
def handle_info({:decision_created, decision}, socket) do
  if socket.assigns.username in decision.stage.invited do
    {:noreply, assign(socket, invite_prompt: decision)}
  else
    {:noreply, socket}
  end
end
```

## Reconsider

- observe: Users miss invites because they're not on /canvas
  respond: Add a persistent "pending invites" badge visible from /d/:id

## Historic

In-app notification via WebSocket is the standard SPA pattern. We get it for free with PubSub - no polling, no push service needed.

## More Info

- [relevant link](https://example.com)
