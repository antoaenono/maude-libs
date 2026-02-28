---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [llm, http, req]
parent: null
children: []
---

# SDT: LLM API HTTP Client

## Scenario

Which HTTP client should we use to call the Anthropic API from Elixir?

## Pressures

### More

1. [M1] Ease of use - JSON request/response with headers should be straightforward
2. [M2] Minimal deps - prototype timeline; no extra setup

### Less

1. [L1] Dependency count - every dep is a liability on a sprint timeline
2. [L2] Abstraction overhead - an SDK wrapping the API adds indirection we don't need

## Chosen Option

Req: modern Elixir HTTP client, declarative API, built-in JSON handling

## Why(not)

In the face of **making JSON HTTP calls to the Anthropic API from an Elixir app**, instead of doing nothing (**no LLM integration - all content is static**), we decided **to use Req as the HTTP client with manually constructed JSON payloads**, to achieve **a thin, explicit wrapper where the exact request/response shape is visible in the code without SDK magic**, accepting **that we maintain our own request construction and response parsing (trivial given the simple JSON contract)**.

## Points

### For

- [M1] `Req.post!(url, json: body, headers: headers)` - one line per call
- [M2] Req is already in the Phoenix ecosystem; no extra research needed
- [L1] One dep instead of an Anthropic SDK + its transitive deps
- [L2] Our LLM module directly controls the exact JSON shape; no SDK mapping layer

### Against

- [L2] We hand-write JSON construction and response parsing (~10 lines per call)

## Artistic

<!-- author this yourself -->

## Consequences

- [deps] {:req, "~> 0.5"} in mix.exs
- [llm] MaudeLibs.LLM wraps Req calls; each function builds its own JSON body
- [parsing] Jason.decode! on response body; pattern match on expected keys

## How

```elixir
def scaffold(scenario, priorities, options) do
  body = %{
    model: "claude-sonnet-4-6",
    max_tokens: 2048,
    messages: [%{role: "user", content: build_scaffold_prompt(scenario, priorities, options)}]
  }
  case Req.post(@base_url, json: body, headers: @headers) do
    {:ok, %{status: 200, body: %{"content" => [%{"text" => text}]}}} ->
      Jason.decode(text)
    {:ok, resp} -> {:error, {:unexpected_status, resp.status}}
    {:error, reason} -> {:error, reason}
  end
end
```

## Reconsider

- observe: Anthropic API changes (new models, new message format)
  respond: Thin wrapper means changes are localized to llm.ex; update in one place

## Historic

Httpoison was the old Elixir standard; Req (by Wojtek Mach, Elixir core team) replaced it with a cleaner API and better defaults. Used widely in the Elixir ecosystem since 2022.

## More Info

- [Req documentation](https://hexdocs.pm/req)
