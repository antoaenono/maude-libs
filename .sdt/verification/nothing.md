---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [verification, testing, dev-workflow]
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

Do nothing; continue with manual browser testing and existing Core unit tests.

## Why(not)

In the face of **needing to test multi-user, multi-stage decision workflows during development**, we decided **to do nothing**, to achieve **no additional maintenance burden or infrastructure**, accepting **continued slow manual testing, low confidence in LiveView integration, and state loss on every server restart**.

## Points

### For

- [M1] No setup time - can start testing immediately (just open tabs)
- [L2] No test infrastructure to go stale or break

### Against

- [M1] Each manual test cycle takes minutes of clicking through stages
- [M2] Cannot jump to a specific stage; must replay from Lobby every time
- [M3] Two-tab manual testing is error-prone and doesn't scale to 3+ users
- [M4] Core unit tests cover business logic but not LiveView rendering or PubSub integration
- [L1] Server restart wipes all state, forcing full replay of every stage
- [L3] Mentally tracking two browser contexts and their respective users is taxing

## Artistic

<!-- author this yourself -->

## Consequences

- [dx] Developer continues hand-navigating tabs for every test scenario
- [coverage] LiveView layer and PubSub integration remain untested by automation
- [iteration] Speed of iteration stays slow; confidence in the program remains low
- [overhead] Zero additional infrastructure to maintain

## Evidence

<!-- optional epistemological layer -->

## How

No implementation needed. Continue the current workflow:
1. Open browser tab, register user A
2. Open incognito tab, register user B
3. Navigate both through Lobby -> Scenario -> Priorities -> ... manually
4. Repeat after every server restart

## Reconsider

- observe: Time spent manually testing exceeds time you'd spend writing test infrastructure
  respond: Adopt one of the other variants
- observe: A regression ships that automated tests would have caught
  respond: Prioritize automated coverage

## Historic

Manual browser testing is the default starting point for any LiveView app. It works for simple flows but breaks down as multi-user stage complexity grows.

## More Info

- [Phoenix.LiveViewTest docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html)
