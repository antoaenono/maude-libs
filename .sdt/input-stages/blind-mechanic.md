---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [input-stages, ux, reveal]
parent: null
children: []
---

# SDT: Input Reveal Mechanic

## Scenario

When multiple participants submit priorities or options, when should each participant's input become visible to the others?

## Pressures

### More

1. [M1] Authentic inputs - participants should not anchor to others' submissions before forming their own view
2. [M2] Transparency - visible live inputs build trust and reduce anxiety about what others are doing
3. [M3] Simplicity - reveal logic should not complicate the stage flow

### Less

1. [L1] Groupthink - seeing others' inputs before submitting may anchor your own
2. [L2] Implementation complexity - rolling reveal requires tracking "has submitted" state per user

## Chosen Option

All inputs visible live as you type; confirm button separates "I'm done" from "I'm ready to advance"

## Why(not)

In the face of **multiple participants simultaneously entering priorities and options**, instead of doing nothing (**no visibility until advance - participants have no idea if others are done**), we decided **to show all participants' inputs live as they type, with a separate Confirm button to signal completion and a Ready button to advance**, to achieve **radical transparency that builds trust and lets people see convergence naturally**, accepting **the mild anchoring risk (mitigated by the ? modal framing which encourages independent thinking first)**.

## Points

### For

- [M2] Seeing others type in real time signals activity and reduces "is this thing on?" anxiety
- [M3] No hidden state, no reveal moment to engineer; just live assigns
- [M2] Confirm button provides a clear "I'm done" signal without gating visibility

### Against

- [L1] Some anchoring risk; mitigated by modal framing that asks for your dimension first

## Artistic

<!-- author this yourself -->

## Consequences

- [ux] All inputs render live via PubSub as participants type
- [flow] Confirm = done with entry (triggers Claude suggestions when all confirm); Ready = advance
- [complexity] No hidden/revealed state tracking needed in Core

## How

```elixir
# On every keystroke (debounced 300ms):
Core.handle(decision, {:upsert_priority, user, %{text: text, direction: dir}})
# -> broadcasts updated stage to all LiveViews

# On confirm:
Core.handle(decision, {:confirm_priority, user})
# -> if MapSet.subset?(connected, confirmed): emit {:async_llm, :suggest_priorities}
```

## Reconsider

- observe: Users complain of anchoring - their inputs are shaped by seeing others first
  respond: Switch to rolling reveal: hide inputs until user has confirmed their own entry

## Historic

Rolling blind reveals are common in estimation poker (Planning Poker, Fibonnaci voting). We considered it but the added implementation complexity and the "trust the modal framing" argument tilted us toward always-visible.

## More Info

- [Planning Poker: why simultaneous reveal matters](https://www.mountaingoatsoftware.com/agile/planning-poker)
