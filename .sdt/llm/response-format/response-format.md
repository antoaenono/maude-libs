---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [llm, json, structured-output]
parent: null
children: []
---

# SDT: LLM Response Format

## Scenario

How do we ensure LLM responses are machine-parseable JSON that maps predictably to our Elixir structs?

## Pressures

### More

1. [M1] Reliability - response must parse without error on the happy path
2. [M2] Simplicity - format mechanism should not require complex client-side schema registration

### Less

1. [L1] Hallucinated fields - model adding extra keys we don't expect
2. [L2] Markdown wrapping - model wrapping JSON in ```json ... ``` fences

## Chosen Option

Prompt coercion: system prompt instructs model to return only raw JSON matching the specified schema; no tool use

## Why(not)

In the face of **getting structured JSON from Claude API calls**, instead of doing nothing (**free-form text responses that require regex extraction or brittle parsing**), we decided **to use prompt-based JSON coercion: a system instruction that says "respond only with valid JSON matching this schema: {...}" plus a concrete example in the prompt**, to achieve **predictable JSON responses without the complexity of tool use or JSON mode API parameters**, accepting **that we rely on prompt adherence and must handle occasional non-JSON responses gracefully with {:error, :parse_failed}**.

## Points

### For

- [M1] Claude reliably follows "respond only with JSON" instructions for well-defined schemas
- [M2] No tool registration, no API-level schema parameter, no SDK needed
- [L1] Explicit schema in prompt limits hallucinated fields; we pattern-match on expected keys only

### Against

- [L2] Occasional ```json fences require a strip step before Jason.decode!
- [M1] Non-JSON response requires error handling; Server must not crash on bad parse

## Artistic

<!-- author this yourself -->

## Consequences

- [prompts] Each LLM function includes "respond only with valid JSON: {schema}" in system prompt
- [parsing] Strip possible ``` fences, then Jason.decode; return {:error, :parse_failed} on failure
- [resilience] Server handles {:error, _} from LLM gracefully - logs and does not transition stage

## How

```elixir
@system_prompt """
You are a decision assistant. Respond ONLY with valid JSON matching exactly this schema:
{"synthesis": "string"}
No markdown, no explanation, no code fences. Just the JSON object.
"""
```

## Reconsider

- observe: Parse failures become frequent (>5% of calls)
  respond: Switch to Anthropic tool use / function calling for guaranteed JSON schema enforcement

## Historic

Prompt coercion for JSON has been the pragmatic approach since GPT-3. Anthropic's models are particularly reliable at following structured output instructions. Tool use is more robust but adds API complexity.

## More Info

- [Anthropic structured output docs](https://docs.anthropic.com/en/docs/build-with-claude/tool-use)
