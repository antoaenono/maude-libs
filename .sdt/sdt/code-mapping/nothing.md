---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [sdt, traceability, code-mapping, globs]
parent: null
children: []
---

# SDF: Decision-to-Code Traceability


## Scenario

How should each SDT decision map to the source files it touches, so that decisions are traceable to code and vice versa?

## Pressures

### More

1. [M1] Bidirectional traceability - given a decision, find all affected code; given a file, find all decisions that shaped it
2. [M2] Impact analysis - when reconsidering a decision, know exactly which files would need to change
3. [M3] LLM context loading - an LLM working on code can load the relevant decisions automatically by matching file paths to decision mappings

### Less

1. [L1] Maintenance overhead - path mappings that drift from reality become misleading
2. [L2] Authoring friction - adding file paths to every decision increases scaffolding cost
3. [L3] False precision - overly specific paths break on refactors; overly broad globs are useless

## Decision

Do nothing: decisions exist only in `.sdt/` with no explicit mapping to source files

## Why(not)

In the face of **mapping SDT decisions to the source files they affect**,
instead of doing nothing
(**decisions and code exist in parallel with no explicit link; finding which decisions shaped a file requires manual search through the SDT corpus**),
we decided **to do nothing**,
to achieve **no change to the existing authoring workflow**,
accepting **that traceability between decisions and code remains implicit and manual**.

## Points

### For

- [L1] No mappings to maintain; no risk of stale paths
- [L2] Zero additional authoring effort per decision

### Against

- [M1] No way to answer "which decisions shaped this file?" without manually reading every SDT
- [M2] Reconsidering a decision requires manually auditing the codebase to find affected files
- [M3] LLMs working on a file have no automatic way to discover relevant architectural context

## Consequences

- [authoring] No change to variant file format
- [tooling] No path resolution or glob matching needed
- [traceability] Decisions and code remain disconnected; grep is the only discovery mechanism
- [dx] Developers must know which decisions exist to consult them

## Evidence

The current SDT corpus has 28 decisions. Some have clear code affinity (e.g., testing/mocks maps obviously to test/ and config/test.exs), but the mapping is implicit. A developer modifying lib/maude_libs/decision/core.ex would need to know to check state-machine/core-architecture - this knowledge lives only in people's heads. As the codebase and decision count grow, this implicit mapping becomes increasingly fragile.

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

No changes. Variant files continue without file path metadata.

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: A decision is reconsidered but the author cannot find all affected files
  respond: Add file mappings to prevent this class of oversight
- observe: LLM agents are given SDT context but cannot match it to the code they are editing
  respond: File path mappings would let tooling auto-load relevant decisions

## Artistic

The code knows nothing of its reasons.

## Historic

Traceability between design decisions and code is a well-studied problem in software engineering. Most ADR systems leave it implicit. Some organizations use code comments (e.g., `// ADR-042`) to link back to decisions, but this scales poorly and creates a maintenance burden in both directions.

## More Info

- [ADR tools and traceability discussion](https://adr.github.io/)
