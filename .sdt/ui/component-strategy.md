---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [ui, components, liveview]
parent: null
children: []
---

# SDT: LiveView Component Strategy

## Scenario

How should we structure UI components across the decision stages - reusable LiveComponents, inline function components, or duplication?

## Pressures

### More

1. [M1] Iteration speed - prototype requires rapid UI changes; overhead should be minimal
2. [M2] Shared structure - the three input stages (scenario, priorities, options) share the same spatial layout

### Less

1. [L1] Premature abstraction - extracting components too early creates wrong abstractions
2. [L2] State complexity - stateful LiveComponents have their own assigns, adding another layer

## Chosen Option

Inline function components (attr + slot, no stateful LiveComponent) for shared layout; per-stage inline heex for unique mechanics

## Why(not)

In the face of **structuring UI components for a 7-stage decision flow where 3 stages share layout**, instead of doing nothing (**duplicate heex everywhere - inconsistent and hard to update**), we decided **to use Phoenix function components (def component(assigns) with @doc) for the shared spatial layout skeleton and inline heex for per-stage mechanics**, to achieve **layout reuse without the stateful LiveComponent overhead**, accepting **that function components require passing all assigns explicitly (verbose but explicit)**.

## Points

### For

- [M1] Function components compile away; no GenServer, no handle_event routing indirection
- [M2] `<.input_stage_layout>` used in scenario, priorities, options - one place to update the 3-column geometry
- [L1] No premature abstraction; stateful LiveComponents only if a component needs its own event handling

### Against

- [L2] All assigns must be explicitly passed; no shared state between function component invocations

## Artistic

<!-- author this yourself -->

## Consequences

- [structure] Shared spatial layout as function component; per-stage content as slots or inline heex
- [stateful] Only decision_live.ex is stateful; no child LiveComponents
- [dx] All heex in decision_live.ex or co-located function components

## How

```elixir
# Shared layout component
defp input_stage_layout(assigns) do
  ~H"""
  <div class="relative h-full">
    <div class="absolute top-1/2 left-1/2"><%= render_slot(@center) %></div>
    <%= for {participant, pos} <- @participants do %>
      <div style={position_style(pos)}><%= render_slot(@participant_slot, participant) %></div>
    <% end %>
    <div class="absolute bottom-8 left-1/2"><%= render_slot(@your_input) %></div>
  </div>
  """
end
```

## Reconsider

- observe: A component needs its own event handling (e.g., inline modal with close button)
  respond: Promote to stateful LiveComponent at that point only

## Historic

Phoenix LiveComponents were designed for stateful, independently updatable UI chunks. Function components are the right tool when the parent LiveView owns all state - which is true here since Decision.Server is the source of truth.

## More Info

- [Phoenix LiveComponent docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html)
