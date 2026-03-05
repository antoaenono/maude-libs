---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [sdt, diagrams, visualization, documentation]
parent: null
children: []
---

# SDF: Visual Diagrams in SDT Variant Files

## Scenario

Should SDT variant files include visual diagrams, and if so, in what format (Mermaid, ASCII, or both)? Diagrams must remain coherent across parent-child decision trees so that zooming into a child decision shows a consistent slice of the parent's diagram.

## Pressures

### More

1. [M1] LLM comprehension - diagrams in a structured format let LLMs parse and reason about architectural relationships when reading SDT files
2. [M2] Human scannability - a visual diagram communicates structure faster than prose, especially for complex multi-component decisions
3. [M3] Tree coherence - parent and child diagrams should zoom in/out consistently; a child diagram is a subgraph of the parent's diagram
4. [M4] GitHub renderability - diagrams should render natively in GitHub markdown preview without external tooling

### Less

1. [L1] Authoring friction - adding diagrams to every variant increases the cost of scaffolding and maintaining decisions
2. [L2] Staleness - diagrams that drift from the prose or implementation become misleading rather than helpful
3. [L3] Format lock-in - choosing one diagram format constrains future tooling and rendering pipelines


## Decision

Do nothing: variant files contain only prose, code snippets, and the existing Implementation section

## Why(not)

In the face of **deciding whether SDT variant files should include visual diagrams**,
instead of doing nothing
(**prose-only Implementation sections require readers to mentally reconstruct architecture from code snippets and bullet points**),
we decided **to do nothing**,
to achieve **no change to the existing authoring workflow**,
accepting **that architectural understanding remains locked in prose and readers must reconstruct structure mentally**.

## Points

### For

- [L1] Zero additional authoring effort; current workflow unchanged
- [L2] No diagram maintenance burden; prose is already the single source of truth

### Against

- [M1] LLMs reading SDT files must infer structure from prose and code snippets, which is less reliable than parsing a structured diagram
- [M2] Complex decisions like layout or state-machine architecture are hard to scan without a visual
- [M3] No mechanism for coherent parent-child visual drilling; each file is an island

## Artistic

Words are enough, if you read them all.

## Evidence

The current SDT corpus has 28 decisions with no diagrams. The Implementation sections use Elixir code blocks and prose descriptions. For simpler decisions (e.g., testing/coverage), prose is sufficient. For complex architectural decisions (e.g., interface/layout with its three-layer architecture, or state-machine/core-architecture with its Pure Core + Shell pattern), readers must mentally reconstruct the component relationships from scattered code snippets.

## Consequences

- [authoring] No change to variant file structure or scaffolding workflow
- [tooling] No diagram parser or renderer needed
- [coherence] No parent-child diagram consistency mechanism
- [readability] Complex decisions remain prose-heavy; reader constructs mental models from text

## Implementation

No changes. Variant files continue to use the current format with `## Implementation` containing prose and code blocks only.

## Reconsider

- observe: Contributors consistently misunderstand multi-component decisions because they cannot visualize the relationships
  respond: Revisit this decision; diagrams may be necessary for complex architectural SDTs
- observe: LLM agents struggle to reason about SDT files when generating code
  respond: Structured diagrams (Mermaid) would give LLMs explicit relationship data

## Historic

The SDT system was designed as a text-first documentation format. The Implementation section was always prose + code, following the tradition of ADRs (Architecture Decision Records) which are pure markdown. Most ADR frameworks (Michael Nygard's original, adr-tools, MADR) do not include diagrams as a standard section.

## More Info

- [Michael Nygard's ADR format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [MADR - Markdown Any Decision Records](https://adr.github.io/madr/)
