---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [verification, testing, dev-workflow, seeds]
parent: null
children: []
---

# SDT: Verification & Dev Workflow Feedback

## Scenario

How can we increase verification feedback and reduce the cost of testing multi-user, multi-stage decision workflows during development?

## Pressures

### More

1. [M1] Feedback speed - time from code change to knowing it works should be minimal
2. [M2] Stage-specific testability - ability to jump directly to any decision stage without replaying prior stages
3. [M3] Multi-user coverage - ability to verify interactions between 2+ concurrent participants
4. [M4] Confidence after refactoring - automated checks that catch regressions when changing Core, Server, or LiveView code

### Less

1. [L1] Manual repetition - having to re-click through Lobby -> Scenario -> Priorities every time the server restarts
2. [L2] Test brittleness - tests that break from minor UI changes rather than actual behavior changes
3. [L3] Cognitive load - mental overhead of maintaining multiple browser tabs and remembering where you left off

## Chosen Option

Dev-only seed routes that programmatically create decisions pre-advanced to any stage with fake users already joined.

## Why(not)

In the face of **needing to test multi-user, multi-stage decision workflows during development**, instead of doing nothing (**re-clicking through every stage after each restart**), we decided **to add dev-only routes that spawn decisions at any target stage with fake users pre-joined**, to achieve **instant access to any stage for manual UI testing**, accepting **no automated regression coverage - this is a dev productivity tool, not a test suite**.

## Points

### For

- [M1] One URL hit puts you at the exact stage you need - seconds instead of minutes
- [M2] Direct stage access via query param (e.g. `?stage=priorities&users=alice,bob`)
- [L1] Eliminates the restart-replay cycle entirely
- [L3] No more juggling multiple incognito windows to set up state

### Against

- [M3] Still requires manually opening separate tabs for each user to test real-time interactions
- [M4] No automated assertions - regressions can still slip through
- [L2] Not applicable (no tests to break), but seed route itself could drift from real stage shapes

## Artistic

<!-- author this yourself -->

## Consequences

- [dx] Developer can jump to any stage in one URL; massive iteration speed boost
- [coverage] No new automated test coverage; LiveView integration still untested
- [iteration] Manual testing is still manual, just much faster to set up
- [overhead] Small: one dev-only controller + route behind a `:dev` pipeline guard

## Evidence

<!-- optional epistemological layer -->

## How

```elixir
# router.ex - dev only
if Mix.env() == :dev do
  scope "/dev", MaudeLibsWeb.Dev do
    pipe_through :browser
    get "/seed/:stage", SeedController, :create
  end
end

# dev/seed_controller.ex
def create(conn, %{"stage" => stage} = params) do
  users = String.split(params["users"] || "alice,bob", ",")
  id = MaudeLibs.Decision.Seeder.create_at_stage(stage, users)
  redirect(conn, to: ~p"/d/#{id}")
end

# decision/seeder.ex - builds decision state directly
def create_at_stage("priorities", users) do
  id = generate_id()
  decision = %Core{
    id: id, creator: hd(users), topic: "Test scenario",
    connected: MapSet.new(users),
    stage: %Stage.Priorities{
      priorities: %{},
      confirmed: MapSet.new(),
      suggestions: [], suggesting: false,
      ready: MapSet.new()
    }
  }
  # Start server with pre-built state
  DynamicSupervisor.start_child(MaudeLibs.Decision.Supervisor,
    {MaudeLibs.Decision.Server, id: id, state: decision})
  id
end
```

## Reconsider

- observe: You find yourself manually testing the same flow repeatedly even with seeds
  respond: Add LiveView integration tests for that flow
- observe: Seed routes drift from real stage shapes after a Core refactor
  respond: Share builders between seeds and tests

## Historic

Dev seed routes are a common pattern in Rails (db:seed) and Phoenix apps with databases. For in-memory GenServer state, the equivalent is a factory function that builds decision structs at target stages.

## More Info

- [Phoenix dev-only routes pattern](https://hexdocs.pm/phoenix/routing.html)
