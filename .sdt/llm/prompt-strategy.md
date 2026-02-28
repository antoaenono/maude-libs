---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [llm, scaffolding, prompts]
parent: null
children: []
---

# SDT: Scaffolding Call Strategy

## Scenario

Should the scaffolding LLM call (generating for/against points per option) be one call for all options or one call per option?

## Pressures

### More

1. [M1] Consistency - for/against points across options should be comparable (same framing, same priorities)
2. [M2] Speed - fewer LLM calls means faster scaffolding stage
3. [M3] Context utilization - a single call can see all options simultaneously and avoid redundancy

### Less

1. [L1] Token usage - one big call uses more tokens than small targeted calls
2. [L2] Error handling complexity - if one option's points are malformed in a batch, we lose all

## Chosen Option

Single call: all options + priorities in one request; output array of {name, for, against} per option

## Why(not)

In the face of **generating for/against analysis for each decision option**, instead of doing nothing (**no scaffolding - users must write their own for/against points**), we decided **to make a single LLM call with all options and priorities, returning a JSON array with for/against points per option**, to achieve **cross-option consistency (the model sees the full picture and can avoid redundant points) and minimum API calls**, accepting **that a malformed response affects all options at once (mitigated by graceful error handling that shows an error state and retries)**.

## Points

### For

- [M1] Single context window sees all options simultaneously; avoids saying the same thing twice
- [M2] One round-trip instead of N (where N = 3-7 options); scaffolding stage resolves faster
- [M3] Model can write points that distinguish options against each other

### Against

- [L2] If JSON is malformed, all options lose their points; retry the whole call
- [L1] Prompt grows with each option; at 6 options + 6 priorities the prompt is ~1KB - fine

## Artistic

<!-- author this yourself -->

## Consequences

- [llm] One scaffold call per decision, fires on Options->Scaffolding transition
- [output] JSON array, one entry per option (including "do nothing")
- [error] Server retries once on parse failure; shows error state if second attempt fails

## How

Input JSON shape:
```json
{
  "scenario": "where should we go for dinner?",
  "priorities": [{"id": "+1", "text": "quick turnaround"}, {"id": "-1", "text": "cost"}],
  "options": [
    {"name": "tacos", "desc": "quick cheap tacos down the street"},
    {"name": "do nothing", "desc": "do not make this decision right now - defer it"}
  ]
}
```

Output JSON shape:
```json
{"options": [
  {"name": "tacos", "for": [{"text": "...", "priority_id": "+1"}], "against": [{"text": "...", "priority_id": "-1"}]},
  {"name": "do nothing", "for": [...], "against": [...]}
]}
```

## Reconsider

- observe: One call times out due to large option count
  respond: Split into N parallel calls (one per option) and merge results

## Historic

Single-call batch prompting is standard for LLM-assisted analysis tasks. Per-option calls add latency and lose cross-option context. GPT-4 and Claude both handle multi-item JSON arrays reliably.

## More Info

- [relevant link](https://example.com)
