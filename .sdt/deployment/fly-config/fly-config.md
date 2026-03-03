---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [deployment, fly.io, clustering]
parent: null
children: []
---

# SDT: fly.io Deployment Configuration

## Scenario

How many machines should we run on fly.io, and do we need BEAM clustering for LiveView state?

## Pressures

### More

1. [M1] Simplicity - single machine requires no distributed state coordination
2. [M2] WebSocket reliability - LiveView requires sticky sessions if using multiple machines without clustering

### Less

1. [L1] Cost - single machine is cheapest
2. [L2] Distributed complexity - BEAM clustering for a hackathon demo is overkill

## Chosen Option

Single machine on fly.io (sjc region); auto-stop/auto-start; no clustering needed; all GenServer state on one node

## Why(not)

In the face of **configuring fly.io for a Phoenix LiveView app with server-side GenServer state**, instead of doing nothing (**deploy with defaults - might spin up 2 machines and break LiveView state distribution**), we decided **to configure fly.io with a single auto-start/auto-stop machine (min_machines_running = 0) in the sjc region**, to achieve **zero distributed state complexity - all Decision.Server GenProcesses on one BEAM node, all LiveView WebSockets to the same node**, accepting **that if the single machine goes down, all in-progress decisions are lost (acceptable for demo scale)**.

## Points

### For

- [M1] All state on one BEAM node; no distributed ETS, no libcluster, no Horde needed
- [M2] All WebSockets naturally hit the same machine; no sticky session config required
- [L1] Smallest fly.io machine tier (~$5/month) is more than sufficient for a demo

### Against

- [L2] Single point of failure; mitigated by not deploying during the demo

## Artistic

<!-- author this yourself -->

## Consequences

- [ops] fly.toml: min_machines_running = 0 with auto_stop/auto_start; single machine scales to zero when idle
- [state] All GenServers on one node; no clustering configuration
- [cost] Minimum fly.io tier; scales to zero when not in use

## How

```toml
# fly.toml
app = "maude-libs"
primary_region = "sjc"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 0

  [http_service.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 500

[[vm]]
  memory = "512mb"
  cpu_kind = "shared"
  cpus = 1
```

```bash
fly launch --no-deploy
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set PHX_HOST=maude-libs.fly.dev
fly secrets set ANTHROPIC_API_KEY=sk-ant-...
fly deploy
```

## Reconsider

- observe: Demo requires high availability or multiple concurrent groups
  respond: Add libcluster + Horde for distributed GenServer registry; configure fly.io with 2+ machines and BEAM clustering

## Historic

Single-machine deploys are the standard starting point for Phoenix apps on fly.io. The fly.io documentation explicitly recommends starting with one machine and scaling when needed.

## More Info

- [fly.io Phoenix deployment guide](https://fly.io/docs/elixir/getting-started/)
- [Phoenix clustering on fly.io](https://fly.io/docs/elixir/the-basics/clustering/)
