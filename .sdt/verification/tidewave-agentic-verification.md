---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: proposed
deciders: @antoaenono
tags: [verification, testing, dev-workflow, tidewave, agentic]
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

Use Tidewave's MCP tools (project_eval, browser_eval, get_logs) as a live agentic verification layer during Claude Code sessions, complementing automated tests and seed routes.

## Why(not)

In the face of **needing to test multi-user, multi-stage decision workflows during development**, instead of doing nothing (**re-clicking through every stage after each restart**), we decided **to leverage Tidewave's runtime introspection tools as an interactive verification layer during agentic coding sessions**, to achieve **instant state setup, live browser verification, and log inspection without leaving the conversation**, accepting **this only works during active Claude Code sessions and doesn't provide persistent automated regression coverage**.

## Points

### For

- [M1] Zero latency: project_eval creates decision state in milliseconds, browser_eval navigates and snapshots in under a second, no test runner to invoke
- [M2] Any stage, any state: project_eval calls DecisionHelpers.seed_decision(:priorities, ["alice", "bob"]) and the decision exists immediately, navigable in the shared browser
- [M2] Can also mutate mid-flow: inject LLM results, toggle suggestions, advance stages, all from the conversation without touching the UI
- [M3] Can create decisions with multiple users pre-connected, then browser_eval to verify what each user's view renders
- [L1] No restart penalty: since project_eval runs in the live BEAM, state is created on demand without replaying anything
- [L3] The agent handles all the tab-juggling and state management - you describe what you want to verify and it happens

### Against

- [M4] No persistent regression suite: Tidewave verification is conversational and ephemeral - it doesn't replace mix test for catching regressions after the session ends
- [L2] browser_eval snapshots can be sensitive to HTML structure changes, though less so than CSS-selector-based tests since snapshots use semantic ARIA roles
- [M3] True multi-browser-session testing (two real WebSocket connections) is limited - project_eval manipulates state but doesn't simulate two concurrent LiveView mounts the way Phoenix.LiveViewTest does

## Artistic

<!-- author this yourself -->

## Consequences

- [dx] During agentic sessions: the agent can verify any change immediately after writing it, creating a tight code-verify loop
- [coverage] Fills the gap between "wrote code" and "ran mix test" - the agent catches obvious issues before you even run the suite
- [iteration] Pairs naturally with seed routes and LiveView tests: Tidewave for live exploratory verification, mix test for automated regression, /dev/seed for manual UI exploration
- [overhead] Zero additional deps or infrastructure - Tidewave is already a dev dependency
- [ops] Only available when Claude Code is connected; vanishes between sessions

## Evidence

<!-- optional epistemological layer -->

## How

Tidewave provides three MCP tools that form a verification triad:

### 1. project_eval - Runtime state manipulation

```elixir
# Create a decision at any stage
d = MaudeLibs.DecisionHelpers.seed_decision(:dashboard, ["alice", "bob"],
  topic: "Should we use TypeScript?",
  options: [
    %{name: "Yes", desc: "Adopt TS", for: [...], against: [...]},
    %{name: "No", desc: "Stay with JS", for: [...], against: [...]}
  ]
)

# Inspect live server state
MaudeLibs.Decision.Server.get_state(d.id)

# Inject LLM results to advance stages
MaudeLibs.Decision.Server.handle_message(d.id, {:scaffolding_result, scaffolded_options})
MaudeLibs.Decision.Server.handle_message(d.id, {:why_statement_result, "Because ..."})

# Verify state transitions
state = MaudeLibs.Decision.Server.get_state(d.id)
state.stage.__struct__  # => MaudeLibs.Decision.Stage.Dashboard
```

### 2. browser_eval - UI verification

```javascript
// Navigate to the seeded decision
await browser.reload("http://localhost:4000/d/" + decisionId);

// Take accessibility snapshot to verify rendered content
console.log(await browser.snapshot(browser.locator("body"), { limit: 30 }));

// Click elements, fill forms, verify state changes
await browser.click(browser.locator("[phx-click='toggle_vote']", { hasText: "Tacos" }));

// Verify the vote registered
console.log(await browser.snapshot(browser.locator(".badge", { hasText: "votes" })));
```

### 3. get_logs - Server-side verification

```
// Check for errors after a state transition
get_logs(tail: 10, level: "error")

// Verify LLM calls were triggered
get_logs(tail: 20, grep: "llm")

// Check broadcast effects fired
get_logs(tail: 10, grep: "broadcast")
```

### Typical agent verification workflow

After writing code that changes a stage's behavior:

1. **project_eval**: Seed a decision at the relevant stage
2. **browser_eval**: Navigate to it, take snapshot, verify the rendered output matches expectations
3. **project_eval**: Send events through the server to trigger the changed code path
4. **browser_eval**: Verify the UI updated correctly
5. **get_logs**: Check no errors were logged
6. If all good, run `mix test` for full regression

## Reconsider

- observe: You find yourself re-doing the same Tidewave verification steps across sessions
  respond: Encode those steps as LiveView integration tests so they persist
- observe: Tidewave snapshots become the only verification and tests are neglected
  respond: Tidewave is complementary, not a replacement. Run mix test before committing.
- observe: A new team member can't reproduce verification steps from a previous session
  respond: Document common verification patterns in a dev guide, or encode as tests

## Historic

Tidewave is an Elixir-native MCP (Model Context Protocol) server that connects AI coding assistants to a running Phoenix application. It launched in 2025 as part of the broader trend of agentic development tools. The project_eval tool is conceptually similar to IEx.pry or remote_console, but accessible to AI agents. browser_eval is similar to Playwright/Wallaby but operates through the shared browser context between agent and developer.

## More Info

- [Tidewave GitHub](https://github.com/tidewave-ai/tidewave)
- [Tidewave HexDocs](https://hexdocs.pm/tidewave)
- [Model Context Protocol](https://modelcontextprotocol.io/)
