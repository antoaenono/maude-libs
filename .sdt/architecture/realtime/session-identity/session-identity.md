---
author: @antoaenono
asked: 2026-03-02
decided: 2026-03-02
status: accepted
deciders: @antoaenono
tags: [realtime, identity, session, authentication]
parent: null
children: []
---

# SDF: Session-Only Identity (No Authentication)

## Scenario

How do we identify participants across LiveView connections without building an authentication system?

## Pressures

### More

1. [M1] Zero auth overhead - no passwords, no OAuth, no email verification for a prototype
2. [M2] Immediate usability - a new user should go from landing page to decision in under 10 seconds

### Less

1. [L1] Identity spoofing - anyone can claim any username; no verification
2. [L2] Session loss - clearing cookies loses the identity; no recovery


### Non

1. [X1] Love

## Decision

Username stored in Plug session via POST /session; session cookie persists the identity; no database, no accounts, no passwords

## Why(not)


In the face of **needing to identify participants in a multiplayer LiveView app**,
instead of doing nothing
(**anonymous connections with no way to distinguish users**),
we decided **to store a self-chosen username in the Plug session via a simple /join form and POST /session endpoint**,
to achieve **instant identity with zero infrastructure**,
accepting **that usernames are not unique-enforced, sessions are cookie-bound, and there is no account recovery**.

## Points

### For

- [M1] No Ecto, no database, no OAuth provider, no email service needed
- [M2] /join page has one text field; submit stores username in session; redirect to /canvas
- [M1] LiveView reads `session["username"]` in mount; no auth plug pipeline needed

### Against

- [L1] Two users can pick the same username; first-come-first-served in practice
- [L2] Private browsing or cookie clear = new identity; no way to reclaim

## Artistic

<!-- author this yourself -->

## Consequences

- [routing] GET /join renders the username form; POST /session stores it and redirects
- [session] `put_session(conn, :username, username)` - standard Plug session
- [liveview] All LiveViews read `session["username"]` in mount/3
- [registry] UserRegistry (ETS) tracks all seen usernames for invite autocomplete; not for auth

## Implementation

```elixir
# join_live.ex
def mount(_params, session, socket) do
  {:ok, assign(socket, username: session["username"])}
end

# session_controller.ex
def create(conn, %{"username" => username}) do
  conn
  |> put_session(:username, String.trim(username))
  |> redirect(to: ~p"/canvas")
end
```

## Reconsider

- observe: Username collisions cause confusion in decisions
  respond: Add uniqueness check against UserRegistry; show error on /join if taken
- observe: Need to persist decisions across sessions (e.g., "my decisions" page)
  respond: Add lightweight auth (magic link email, or OAuth) and associate decisions with accounts

## Historic

Session-based pseudonymous identity is the standard pattern for hackathon prototypes, game jams, and demos. It's the lowest-cost identity model that still allows multiplayer coordination.

## More Info

- [Plug.Session docs](https://hexdocs.pm/plug/Plug.Session.html)
