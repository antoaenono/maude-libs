---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [verification, testing, liveview, integration]
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

Use Phoenix.LiveViewTest to mount LiveViews in-process, simulate multi-user flows, and assert stage transitions without a real browser.

## Why(not)

In the face of **needing to test multi-user, multi-stage decision workflows during development**, instead of doing nothing (**re-clicking through every stage after each restart**), we decided **to write LiveView integration tests using Phoenix.LiveViewTest**, to achieve **automated multi-user workflow coverage that runs in milliseconds with no browser**, accepting **no visual/JS hook coverage and upfront time investment writing test helpers**.

## Points

### For

- [M1] Tests run in milliseconds - no browser startup, no HTTP overhead, in-process Elixir
- [M3] Can mount multiple LiveView connections in one test, each as a different user, and assert they see each other's updates via PubSub
- [M4] Full LiveView stack tested: mount, handle_event, handle_info, rendering - catches regressions at the integration layer
- [L1] Tests are the replay; run `mix test` and every stage transition is verified automatically
- [L2] Tests assert on rendered HTML content and assigns, not CSS selectors or pixel positions - resilient to UI redesigns

### Against

- [M2] Tests exercise full flows, but don't provide ad-hoc "jump to stage X" during dev (still need manual browser for exploratory UI work)
- [L3] Writing the initial test suite has a learning curve, though Phoenix.LiveViewTest is well-documented

## Artistic

<!-- author this yourself -->

## Consequences

- [dx] `mix test` becomes the primary verification feedback loop for multi-user workflows
- [coverage] LiveView rendering, PubSub broadcast reception, and stage transitions all covered
- [iteration] Regressions caught before manual testing; manual testing reserved for visual/UX work
- [overhead] Test helpers needed: session builders, multi-user mount helpers, stage assertion macros

## Evidence

<!-- optional epistemological layer -->

## How

```elixir
# test/support/decision_case.ex - shared helpers
defmodule MaudeLibsWeb.DecisionCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.LiveViewTest
      import MaudeLibsWeb.DecisionCase.Helpers
    end
  end

  defmodule Helpers do
    import Phoenix.ConnTest
    import Phoenix.LiveViewTest

    # Mount a LiveView as a specific user
    def mount_as(user) do
      conn = build_conn() |> init_test_session(%{"username" => user})
      {:ok, view, _html} = live(conn, ~p"/canvas")
      view
    end

    # Create a decision and advance to a target stage
    def create_decision_at(stage, opts \\ []) do
      users = Keyword.get(opts, :users, ["alice", "bob"])
      # Use Core directly to build state, start server
      # ...
    end
  end
end

# test/maude_libs_web/live/decision_live_test.exs
defmodule MaudeLibsWeb.DecisionLiveTest do
  use MaudeLibsWeb.DecisionCase, async: false

  test "two users complete scenario stage" do
    alice_view = mount_as("alice")
    # alice creates decision
    alice_view |> element("#new-decision") |> render_click()

    bob_view = mount_as("bob")
    # bob joins via invite

    # Both submit scenario rephrases
    alice_view |> form("#scenario-form", %{text: "How to pick lunch"}) |> render_submit()
    bob_view |> form("#scenario-form", %{text: "How to pick lunch"}) |> render_submit()

    # Both vote for same scenario
    alice_view |> element("[data-vote=alice]") |> render_click()
    bob_view |> element("[data-vote=alice]") |> render_click()

    # Assert both views advanced to priorities stage
    assert render(alice_view) =~ "Priorities"
    assert render(bob_view) =~ "Priorities"
  end
end
```

## Reconsider

- observe: JS hooks or canvas interactions cause bugs that LiveViewTest can't catch
  respond: Add targeted Wallaby/Playwright tests for JS-heavy features only
- observe: Test setup for multi-user flows is too verbose
  respond: Extract shared builder/helper modules (similar to existing `decision()` helpers in core_test)

## Historic

Phoenix.LiveViewTest was introduced alongside LiveView and is the idiomatic way to test LiveView applications. It renders HTML server-side, simulates events, and supports multiple concurrent connections - all without a browser. This is one of the key advantages of the LiveView architecture over SPA frameworks.

## More Info

- [Phoenix.LiveViewTest docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html)
- [Testing LiveView - official guide](https://hexdocs.pm/phoenix_live_view/testing.html)
- [fly.io LiveView testing guide](https://fly.io/phoenix-files/testing-liveview/)
