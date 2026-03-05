# MaudeLibs

A collaborative decision-making tool built with Phoenix LiveView.

## Local Development

```bash
mix setup          # install and setup dependencies
mix phx.server     # start the server
```

Visit [localhost:4000](http://localhost:4000).

## Deployment (Fly.io)

The app is deployed to [maude-libs.fly.dev](https://maude-libs.fly.dev/) on Fly.io.

### Deploy

```bash
fly deploy
```

The Dockerfile handles the full build: Elixir compilation, Node.js asset bundling (d3-force, etc.), and release packaging.
Only the compiled release makes it into the final image.

### Deployment Behavior

The app is configured to sleep when idle and wake on demand:

```toml
auto_stop_machines = "stop"    # stops machine when no connections
auto_start_machines = true     # wakes on incoming request
min_machines_running = 0       # allows all machines to sleep
```

LiveView keeps a WebSocket open, so the machine stays alive as long as anyone has a tab open.

### Stop / Start

To manually stop machines (they'll still auto-start on the next request):

```bash
fly machine stop        # stop all machines
fly machine start       # start all machines
```

### Suspend / Resume

To fully take the app offline (no machines, no traffic served).
Note: `fly apps suspend` is deprecated in favor of this:

```bash
fly scale count 0 --yes
```

To bring it back:

```bash
fly scale count 1 --yes
```

### Useful Commands

```bash
fly status          # check machine state
fly logs            # tail production logs
fly ssh console     # shell into a running machine
```
