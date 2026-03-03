---
author: @antoaenono
asked: 2026-03-02
decided: 2026-03-02
status: accepted
deciders: @antoaenono
tags: [realtime, identity, ets, autocomplete, invite]
parent: architecture/realtime/invite-mechanism/pubsub-invite
children: []
---

# SDF: ETS-Backed User Registry for Invite Autocomplete

## Scenario

How does the invite UI know which usernames exist in the system so the creator can autocomplete when inviting participants?

## Pressures

### More

1. [M1] Discoverability - creator should see available usernames without memorizing them
2. [M2] Zero-database constraint - no Ecto/Postgres available for a user table

### Less

1. [L1] Staleness - usernames from hours ago may never return; no cleanup needed for prototype
2. [L2] Memory - ETS table grows monotonically; fine for demo scale (< 100 users)


### Non

1. [X1] Love

## Decision

ETS-backed GenServer that registers every username on /join; `list_usernames/0` feeds an HTML `<datalist>` for autocomplete

## Why(not)


In the face of **needing username autocomplete for the invite UI without a database**,
instead of doing nothing
(**creator must type exact usernames from memory**),
we decided **to maintain an ETS table of all seen usernames via a GenServer, populated on every /join, and exposed as a datalist in the invite form**,
to achieve **instant autocomplete with zero database overhead**,
accepting **that stale usernames accumulate and there's no uniqueness enforcement**.

## Points

### For

- [M1] HTML `<datalist>` provides native browser autocomplete from `UserRegistry.list_usernames()`
- [M2] ETS table in a GenServer; no Ecto, no migrations, no connection pool
- [L1] Stale entries are harmless; inviting a user who never returns just produces a ghost card

### Against

- [L2] No cleanup mechanism; acceptable for demo scale

## Artistic

<!-- author this yourself -->

## Consequences

- [data] ETS table `:user_registry` stores `{username, timestamp}`
- [api] `register(username)` on every join; `list_usernames()` returns all known usernames
- [ui] Lobby invite input uses `<datalist id="known-usernames">` populated from `list_usernames()`

## Implementation

```elixir
defmodule MaudeLibs.UserRegistry do
  use GenServer

  def register(username) do
    GenServer.cast(__MODULE__, {:register, username})
  end

  def list_usernames do
    :ets.tab2list(@table) |> Enum.map(fn {name, _ts} -> name end)
  end

  def handle_cast({:register, username}, state) do
    :ets.insert(@table, {username, System.system_time()})
    {:noreply, state}
  end
end
```

```heex
<input type="text" name="username" list="known-usernames" autocomplete="off" />
<datalist id="known-usernames">
  <%= for u <- @all_usernames, u != @username do %>
    <option value={u} />
  <% end %>
</datalist>
```

## Reconsider

- observe: Stale usernames clutter autocomplete after many sessions
  respond: Add TTL-based cleanup (e.g., discard entries older than 24 hours)
- observe: Need to associate persistent data with users (history, preferences)
  respond: Graduate to a real user table with Ecto

## Historic

ETS-backed registries are a common Elixir pattern for lightweight in-memory lookups. Phoenix.Tracker and Registry both use ETS internally. For a prototype without persistence, a simple GenServer + ETS is the minimum viable approach.

## More Info

- [ETS documentation](https://www.erlang.org/doc/apps/stdlib/ets)
