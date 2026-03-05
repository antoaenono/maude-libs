---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [sdt, diagrams, visualization, ascii, documentation]
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

ASCII diagrams: add a `## Diagram` section using plain-text box-and-arrow art in fenced code blocks

## Why(not)

In the face of **deciding whether SDT variant files should include visual diagrams**,
instead of doing nothing
(**prose-only Implementation sections require readers to mentally reconstruct architecture from code snippets and bullet points**),
we decided **to use ASCII box-and-arrow diagrams in fenced code blocks within a `## Diagram` section**,
to achieve **universal rendering in any text viewer, terminal, or editor without external dependencies**,
accepting **limited expressiveness, harder maintenance, and poor machine-parseability compared to structured formats**.

## Points

### For

- [M2] ASCII art is immediately visible in any context: terminal, cat output, email, plain-text diff, code comments
- [M4] Renders identically everywhere; no dependency on GitHub's Mermaid renderer or any JS library
- [L3] No format lock-in; ASCII is the lowest common denominator, portable to any future system

### Against

- [M1] LLMs cannot reliably parse ASCII art into structured relationships; the spatial layout is ambiguous and tokenization destroys alignment
- [M3] Parent-child coherence is very difficult in ASCII; there is no subgraph ID convention, only visual resemblance which breaks as diagrams grow
- [L1] ASCII diagrams are tedious to author and painful to modify; adding a box requires reflowing surrounding whitespace
- [L2] ASCII diagrams are the most brittle to edit; a one-character change can misalign the entire diagram
- [M4] While ASCII renders everywhere, it looks worse than Mermaid SVG on GitHub and lacks interactivity

## Artistic

If it fits in 80 columns, it fits in your head.

## Evidence

ASCII diagrams have a long history in software documentation (RFC documents, Linux kernel comments, Go standard library). They excel in contexts where no rendering pipeline exists. However, they are increasingly uncommon in modern documentation systems that support Mermaid, PlantUML, or embedded SVG. The key weakness for the SDT use case is M1: LLMs struggle to extract meaning from ASCII art because tokenizers fragment the spatial layout. A Mermaid flowchart like `A --> B` is unambiguous; an ASCII arrow like `[A] ----> [B]` requires spatial reasoning that current LLMs handle unreliably.

## Consequences

- [authoring] New `## Diagram` section with fenced code block; manual ASCII drawing per variant
- [tooling] No parser or renderer needed; sdt.py only checks that the section exists
- [coherence] No automated parent-child consistency check; coherence is a visual convention only
- [readability] Universally readable but limited in expressiveness; complex architectures become unwieldy

## Implementation

### Variant file addition

```markdown
## Diagram

`` `
+------------------+     {:ok, d, effects}     +------------------+
|   Core (pure)    | --------------------------> |  Server (shell)  |
|  Core.handle/2   |                            | dispatch_effect  |
+------------------+                            +--------+---------+
                                                         |
                                          +--------------+---------------+
                                          |              |               |
                                     broadcast      async_llm       debounce
                                          |              |               |
                                       PubSub          Task           Timer
`` `
```

### Convention for parent-child diagrams

Parent diagrams use labeled boxes. Child diagrams reproduce the parent box they belong to and expand its internals:

Parent (`state-machine/core-architecture`):
```
+------------------+     +------------------+     +------------------+
|      Core        | --> |     Server       | --> |     Effects      |
+------------------+     +------------------+     +------------------+
```

Child (`state-machine/debounced-calls`):
```
+------------------------------------------------------------------+
|  Effects                                                         |
|  +------------------+     +------------------+     +----------+  |
|  | Debounce Timer   | --> | Cancel Previous  | --> | Fire LLM |  |
|  +------------------+     +------------------+     +----------+  |
+------------------------------------------------------------------+
```

### Scaffolding

The SDT scaffolding skill does not auto-generate ASCII diagrams (too error-prone). It inserts a placeholder:

```markdown
## Diagram

`` `
<!-- draw architecture here -->
`` `
```

## Reconsider

- observe: Nobody authors ASCII diagrams because they are too tedious
  respond: Switch to Mermaid; the authoring friction of ASCII defeats the purpose
- observe: Diagrams are only read in GitHub or VS Code where Mermaid renders natively
  respond: ASCII provides no advantage over Mermaid in these contexts; switch to Mermaid
- observe: Terminal-only workflow becomes important (SSH servers, CI logs)
  respond: ASCII remains the only option for these contexts; consider dual-format (Mermaid primary, ASCII generated)

## Historic

ASCII art diagrams were the standard for technical documentation before rich rendering was available. RFC documents (IETF) still use ASCII diagrams exclusively. The Linux kernel and Go standard library include ASCII architecture diagrams in source comments. The practice declined as GitHub, GitLab, and documentation tools added support for structured diagram formats (Mermaid, PlantUML, Graphviz).

## More Info

- [RFC 9293 - TCP specification (ASCII diagrams)](https://www.rfc-editor.org/rfc/rfc9293)
- [asciiflow.com - ASCII diagram editor](https://asciiflow.com/)
