---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [deployment, state, genserver]
parent: null
children: []
---

# SDT: Decision State Persistence

## Scenario

Should decision state be persisted to a database, ETS, or live only in GenServer memory?

## Pressures

### More

1. [M1] Demo reliability - a server restart during the demo would be embarrassing
2. [M2] Simplicity - no DB means no migrations, no Ecto, no connection pooling

### Less

1. [L1] Setup time - Postgres on fly.io requires a volume and Ecto config
2. [L2] State loss risk - ephemeral GenServers lose all decisions on restart

## Chosen Option

Ephemeral GenServers: all decision state in memory; accept state loss on restart for prototype scope

## Why(not)

In the face of **deciding where decision state lives**, instead of doing nothing (**no persistence strategy - deploy blindly and hope for the best**), we decided **to keep all state in GenServer memory with no persistence layer**, to achieve **zero database setup, zero migration overhead, and the fastest possible deployment**, accepting **that a server restart (deploy, crash) loses all in-flight decisions - mitigated by deploying before the demo and not deploying during it**.

## Points

### For

- [M2] No Ecto, no Postgres, no migrations; `mix phx.new --no-ecto` keeps the stack minimal
- [L1] fly.io deployment is ~5 minutes with no database; with Postgres it's ~15+ and requires volume config
- [M1] As long as we deploy before the demo and don't crash, state is safe for the session duration

### Against

- [L2] One crash or deploy during the demo = all decisions gone; mitigate by demoing on stable build

## Artistic

<!-- author this yourself -->

## Consequences

- [deps] No Ecto, no database dependency
- [risk] Decision state lost on restart; acceptable for hackathon demo
- [ops] Deploy once before demo; do not redeploy during the event

## How

```bash
mix phx.new maude_libs --live --no-dashboard --no-mailer --no-ecto
```

All state lives in Decision.Server GenServer processes supervised by DynamicSupervisor.

## Reconsider

- observe: Demo requires state to survive deploys (multi-day event)
  respond: Add ETS persistence with :ets.tab2file on terminate and reload on start; or add Postgres/Ecto

## Historic

Hackathon apps and demos routinely skip persistence. The tradeoff is well-understood: simplicity vs durability. For a same-day demo, in-memory is the right call.

## More Info

- [relevant link](https://example.com)
