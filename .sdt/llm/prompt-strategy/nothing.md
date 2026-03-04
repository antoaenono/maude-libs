---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: rejected
deciders: @antoaenono
tags: [llm, scaffolding, prompts]
parent: null
children: []
---

# SDF: Scaffolding Call Strategy

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

### Non

1. [X1] Love

## Decision

Do nothing - no LLM scaffolding; users write their own for/against points

## Why(not)

In the face of **generating for/against analysis for each decision option**,
instead of doing nothing
(**no scaffolding - users must write their own for/against points**),
we decided **to do nothing**,
to achieve **zero LLM dependency during the scaffolding stage**,
accepting **that users must manually author all for/against points, which is slower and may miss considerations**.

## Points

### For

- [L1] Zero token usage - no LLM calls at all
- [L2] No error handling needed - nothing to fail

### Against

- [M1] Users write points in isolation per option; no cross-option consistency
- [M2] Slower scaffolding stage; users must think through every point manually
- [M3] Users may miss non-obvious arguments that the model would surface

## Artistic

Do all the thinking yourself.

## Evidence

Without LLM scaffolding, decision quality depends entirely on the participants' domain knowledge and analytical thoroughness. In practice, groups tend to anchor on obvious points and miss second-order considerations.

## Consequences

- [llm] No LLM calls during scaffolding
- [output] Empty for/against sections that users fill manually
- [error] No error states to handle

## Implementation

```elixir
# No LLM call - transition directly to editing stage
def handle(d, :begin_scaffolding) do
  d2 = %{d | stage: %Scaffolding{options: d.stage.options, points: %{}}}
  {:ok, d2, [{:broadcast, d.id, d2}]}
end
```

## Reconsider

- observe: Never - this option was rejected at decision time
  respond: N/A

## Historic

Early decision tools (pros/cons lists, decision matrices) were entirely manual. LLM-assisted scaffolding is a recent pattern enabled by reliable structured output from large language models.

## More Info

- [relevant link](https://example.com)
