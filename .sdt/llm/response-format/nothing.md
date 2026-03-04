---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: rejected
deciders: @antoaenono
tags: [llm, json, structured-output]
parent: null
children: []
---

# SDF: LLM Response Format

## Scenario

How do we ensure LLM responses are machine-parseable JSON that maps predictably to our Elixir structs?

## Pressures

### More

1. [M1] Reliability - response must parse without error on the happy path
2. [M2] Simplicity - format mechanism should not require complex client-side schema registration

### Less

1. [L1] Hallucinated fields - model adding extra keys we don't expect
2. [L2] Markdown wrapping - model wrapping JSON in ```json ... ``` fences

### Non

1. [X1] Love

## Decision

Do nothing - accept free-form text responses and parse them manually

## Why(not)

In the face of **getting structured JSON from Claude API calls**,
instead of doing nothing
(**free-form text responses that require regex extraction or brittle parsing**),
we decided **to do nothing**,
to achieve **zero prompt engineering overhead**,
accepting **that every LLM response requires ad-hoc regex or string parsing, with no structural guarantee**.

## Points

### For

- [M2] No prompt engineering, no schema specification, no format constraints to maintain

### Against

- [M1] Free-form text parsing is fragile; any change in model phrasing breaks extraction
- [L1] No guardrails against unexpected output structure
- [L2] No way to prevent markdown wrapping without explicit instruction

## Artistic

Roll the dice on every response.

## Evidence

Without structured output constraints, LLM responses vary in format across calls. Extraction relies on regex or string splitting, which breaks when the model rephrases or restructures its output.

## Consequences

- [prompts] No schema instructions in prompts
- [parsing] Ad-hoc regex or string extraction per response type
- [resilience] High failure rate on format changes; fragile pipeline

## Implementation

```elixir
# Parse synthesis from free-form text
case Regex.run(~r/synthesis[:\s]+(.+)/i, response_text) do
  [_, synthesis] -> {:ok, String.trim(synthesis)}
  nil -> {:error, :parse_failed}
end
```

## Reconsider

- observe: Never - this option was rejected at decision time
  respond: N/A

## Historic

Early LLM integrations commonly used free-form text with regex extraction. This approach was largely abandoned as prompt-based JSON coercion and tool use proved more reliable.

## More Info

- [Anthropic structured output docs](https://docs.anthropic.com/en/docs/build-with-claude/tool-use)
