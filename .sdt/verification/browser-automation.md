---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [verification, testing, browser, e2e]
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

Use Wallaby (or Playwright via ports) to drive real browser sessions through the full multi-user UI workflow.

## Why(not)

In the face of **needing to test multi-user, multi-stage decision workflows during development**, instead of doing nothing (**re-clicking through every stage after each restart**), we decided **to automate real browser sessions with Wallaby/Playwright**, to achieve **true end-to-end coverage including JS hooks, canvas rendering, and visual behavior**, accepting **slower test execution, ChromeDriver dependency, and higher test maintenance burden from CSS/DOM coupling**.

## Points

### For

- [M3] Can spawn multiple real browser sessions - tests exactly what users experience, including WebSocket reconnects and JS hooks
- [M4] Highest fidelity: catches CSS issues, JS errors, canvas rendering bugs, and LiveView client-server desync
- [L1] Fully automated - no manual clicking needed for covered flows

### Against

- [M1] Slow: each test spawns browser processes, waits for page loads, animates - seconds per test vs milliseconds for LiveViewTest
- [M2] Cannot easily jump to a stage without either replaying all prior stages in the browser or combining with seed routes
- [L2] Extremely brittle: tests break when CSS classes change, elements move, animations alter timing, or DOM structure shifts
- [L3] Debugging browser test failures is harder than in-process LiveView test failures - screenshots, timeouts, flaky selectors

## Artistic

<!-- author this yourself -->

## Consequences

- [dx] CI pipeline slows significantly; local test runs require ChromeDriver/Playwright installed
- [coverage] Highest coverage fidelity - JS, CSS, WebSocket, canvas all exercised
- [iteration] Test writing is slower; maintaining selectors against UI changes is ongoing work
- [overhead] New deps (wallaby or playwright), ChromeDriver binary, CI browser setup, potential Docker image changes
- [deps] Adds wallaby ~> 0.30 or custom Playwright port wrapper to mix.exs

## Evidence

<!-- optional epistemological layer -->

## How

```elixir
# mix.exs
{:wallaby, "~> 0.30", only: :test, runtime: false}

# test/support/wallaby_case.ex
defmodule MaudeLibsWeb.WallabyCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.DSL
    end
  end

  setup do
    {:ok, session1} = Wallaby.start_session()
    {:ok, session2} = Wallaby.start_session()
    {:ok, alice: session1, bob: session2}
  end
end

# test/e2e/decision_flow_test.exs
defmodule MaudeLibsWeb.E2E.DecisionFlowTest do
  use MaudeLibsWeb.WallabyCase

  test "two users complete full decision flow", %{alice: alice, bob: bob} do
    alice
    |> visit("/join")
    |> fill_in(Query.text_field("username"), with: "alice")
    |> click(Query.button("Join"))
    |> visit("/canvas")
    |> click(Query.button("+"))

    # bob joins via /join, navigates to decision
    bob
    |> visit("/join")
    |> fill_in(Query.text_field("username"), with: "bob")
    |> click(Query.button("Join"))
    # ... continue through stages
  end
end
```

## Reconsider

- observe: Browser tests take >30s and block CI
  respond: Move to a separate "e2e" CI job that runs on merge only, not on every push
- observe: Tests break on every UI change despite behavior being correct
  respond: Switch to data-testid selectors and consider replacing with LiveViewTest for non-visual assertions

## Historic

Wallaby is the standard Elixir browser testing library, wrapping ChromeDriver. Playwright (via Node or Rust bindings) is newer and faster but lacks a mature Elixir wrapper. Browser automation for testing has a long history of being high-fidelity but high-maintenance.

## More Info

- [Wallaby docs](https://hexdocs.pm/wallaby/readme.html)
- [Playwright](https://playwright.dev/)
- [ChromeDriver](https://chromedriver.chromium.org/)
