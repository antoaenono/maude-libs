---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [verification, testing, dev-workflow, seeds, liveview, integration]
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

Dev seed routes for instant manual stage access + LiveView integration tests for automated multi-user regression coverage. Skip browser automation to avoid brittleness.

## Why(not)

In the face of **needing to test multi-user, multi-stage decision workflows during development**, instead of doing nothing (**re-clicking through every stage after each restart**), we decided **to combine dev-only seed routes with Phoenix.LiveViewTest integration tests**, to achieve **both instant manual access to any stage and automated regression coverage across the full LiveView stack**, accepting **no visual/JS-hook coverage (add browser automation later if needed) and upfront time building shared stage builders**.

## Points

### For

- [M1] LiveView tests run in milliseconds; seed routes give instant manual access - both are fast
- [M2] Seed routes let you hit `/dev/seed/priorities?users=alice,bob` and land directly in the Priorities stage in your browser
- [M3] LiveViewTest can mount multiple connections as different users and assert they see each other's PubSub broadcasts
- [M4] Integration tests cover mount, handle_event, handle_info, and rendered HTML - catches regressions the Core tests miss
- [L1] `mix test` replaces manual replay for regressions; seed routes replace manual replay for exploratory UI work
- [L2] LiveViewTest asserts on rendered content, not CSS selectors - resilient to design changes
- [L3] No more juggling tabs for setup; seed route handles state, test suite handles assertions

### Against

- [M4] JS hooks and canvas animations remain untested (acceptable tradeoff for now; add Wallaby later if needed)
- [L2] Seed routes could drift from real stage shapes if builders aren't shared with tests

## Artistic

<!-- author this yourself -->

## Consequences

- [dx] Two new feedback loops: `mix test` for automated verification, `/dev/seed/:stage` for manual exploratory UI work
- [coverage] Core (unit) + LiveView (integration) + manual (seeds) covers three layers; JS/canvas remains manual-only
- [iteration] Restart-to-testing time drops from minutes to seconds for both automated and manual paths
- [overhead] Shared stage builder module used by both seeds and tests - one source of truth for stage construction
- [deps] Zero new deps; Phoenix.LiveViewTest is built into phoenix_live_view, seed routes use existing router

## Evidence

<!-- optional epistemological layer -->

## How

### Shared stage builders

```elixir
# lib/maude_libs/decision/builders.ex (or test/support/ if test-only)
defmodule MaudeLibs.Decision.Builders do
  alias MaudeLibs.Decision.Core
  alias MaudeLibs.Decision.Stage

  def at_lobby(users) do
    %Core{
      id: generate_id(),
      creator: hd(users),
      topic: "Test decision",
      connected: MapSet.new(users),
      stage: %Stage.Lobby{
        invited: MapSet.new(users),
        joined: MapSet.new(users),
        ready: MapSet.new()
      }
    }
  end

  def at_scenario(users) do
    %{at_lobby(users) | stage: %Stage.Scenario{submissions: %{}, votes: %{}}}
  end

  def at_priorities(users, opts \\ []) do
    topic = Keyword.get(opts, :topic, "How should we pick lunch?")
    %{at_lobby(users) | topic: topic, stage: %Stage.Priorities{
      priorities: %{}, confirmed: MapSet.new(),
      suggestions: [], suggesting: false, ready: MapSet.new()
    }}
  end

  def at_options(users, opts \\ []) do
    topic = Keyword.get(opts, :topic, "How should we pick lunch?")
    %{at_lobby(users) | topic: topic, stage: %Stage.Options{
      proposals: %{}, confirmed: MapSet.new(),
      suggestions: [], suggesting: false, ready: MapSet.new()
    }}
  end

  def at_dashboard(users, opts \\ []) do
    options = Keyword.get(opts, :options, [
      %{name: "Option A", desc: "First option", for: ["Fast", "Simple"], against: ["Limited"]},
      %{name: "Option B", desc: "Second option", for: ["Thorough"], against: ["Slow"]}
    ])
    %{at_lobby(users) | stage: %Stage.Dashboard{
      options: options, votes: %{}, ready: MapSet.new()
    }}
  end

  defp generate_id, do: :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
end
```

### Dev seed routes

```elixir
# router.ex
if Mix.env() == :dev do
  scope "/dev", MaudeLibsWeb.Dev do
    pipe_through :browser
    get "/seed/:stage", SeedController, :create
  end
end

# controllers/dev/seed_controller.ex
defmodule MaudeLibsWeb.Dev.SeedController do
  use MaudeLibsWeb, :controller
  alias MaudeLibs.Decision.{Builders, Server}

  def create(conn, %{"stage" => stage} = params) do
    users = String.split(params["users"] || "alice,bob", ",")
    decision = build_stage(stage, users)
    {:ok, _pid} = start_server_with_state(decision)
    redirect(conn, to: ~p"/d/#{decision.id}")
  end

  defp build_stage("lobby", users), do: Builders.at_lobby(users)
  defp build_stage("scenario", users), do: Builders.at_scenario(users)
  defp build_stage("priorities", users), do: Builders.at_priorities(users)
  defp build_stage("options", users), do: Builders.at_options(users)
  defp build_stage("dashboard", users), do: Builders.at_dashboard(users)
end
```

### LiveView integration tests

```elixir
# test/maude_libs_web/live/decision_live_test.exs
defmodule MaudeLibsWeb.DecisionLiveTest do
  use MaudeLibsWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "two users advance through scenario to priorities" do
    # Mount as alice
    alice_conn = build_conn() |> init_test_session(%{"username" => "alice"})
    # alice creates decision, bob joins, both submit + vote
    # ... assert both views show "Priorities" stage
  end

  test "user lands directly at priorities stage via seeded decision" do
    decision = Builders.at_priorities(["alice", "bob"])
    start_server_with_state(decision)

    conn = build_conn() |> init_test_session(%{"username" => "alice"})
    {:ok, view, html} = live(conn, ~p"/d/#{decision.id}")
    assert html =~ "priority"
  end
end
```

## Reconsider

- observe: JS hook or canvas bugs keep slipping through
  respond: Add targeted Wallaby tests for JS-heavy features only (not full flow coverage)
- observe: Seed route state shapes drift from reality after Core refactors
  respond: Add a test that validates each builder produces a state that Core.handle/2 accepts
- observe: Builder module grows complex with many stage permutations
  respond: Consider a pipeline API: `Builders.new(users) |> Builders.advance_to(:priorities)`

## Historic

This is the "boring technology" approach: Phoenix.LiveViewTest has been the idiomatic LiveView testing tool since LiveView 0.x, and dev seed data is a pattern as old as Rails. Combining them covers the two distinct needs (automated regression vs manual exploration) without introducing heavy infrastructure.

## More Info

- [Phoenix.LiveViewTest docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html)
- [Testing LiveView - official guide](https://hexdocs.pm/phoenix_live_view/testing.html)
- [LiveView testing multiple clients](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#module-testing-live-components)
