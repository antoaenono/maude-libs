---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: rejected
deciders: @antoaenono
tags: [sdt, traceability, code-mapping, globs, frontmatter]
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

Manual globs in frontmatter: add a `touches` field to variant file YAML frontmatter containing a list of file globs relative to the project root

## Why(not)

In the face of **mapping SDT decisions to the source files they affect**,
instead of doing nothing
(**decisions and code exist in parallel with no explicit link; finding which decisions shaped a file requires manual search through the SDT corpus**),
we decided **to add a `touches` list of file globs to the YAML frontmatter of each accepted variant**,
to achieve **explicit, queryable traceability between decisions and code that LLMs and tooling can resolve automatically**,
accepting **manual maintenance of glob lists and the risk of drift if paths are not updated during refactors**.

## Points

### For

- [M1] `touches: ["lib/maude_libs/decision/core.ex", "lib/maude_libs/decision/server.ex"]` makes the mapping explicit and queryable; tooling can invert it to answer "which decisions touch this file?"
- [M2] When reconsidering a decision, the `touches` list is the starting point for impact analysis
- [M3] An LLM editing a file can glob-match it against all decisions' `touches` fields to auto-load relevant SDT context
- [L2] Globs reduce authoring friction vs. listing every file: `test/**/*` covers the entire test directory
- [L3] Globs at the right granularity (directory-level for broad decisions, file-level for precise ones) balance specificity and resilience

### Against

- [L1] Glob lists must be manually updated when files are renamed, moved, or deleted; this is a maintenance tax
- [L1] No automated check that globs still resolve to existing files (without additional tooling)
- [L3] Choosing the right granularity is a judgment call: `lib/**/*` is too broad; `lib/maude_libs/decision/core.ex:42` is too narrow

## Consequences

- [authoring] New `touches` field in YAML frontmatter of accepted variants; optional for proposed variants
- [tooling] sdt.py gains a `resolve` subcommand: given a file path, returns all decisions whose `touches` globs match it
- [traceability] Bidirectional: decision -> files (expand globs) and file -> decisions (match against all globs)
- [dx] LLM agents and IDE plugins can use the resolve command to surface relevant decisions contextually

## Evidence

The convention of listing affected files is common in changelogs (CHANGELOG.md) and migration guides. Terraform and Pulumi track which resources each module manages. In the SDT context, a rough mapping is already implicit in the Implementation section's code examples - the `touches` field makes it explicit and machine-readable. LLMs can both generate and maintain these glob lists during scaffolding and refactoring, reducing the manual burden. A glob like `test/maude_libs/decision/*_test.exs` is resilient to new test files being added while still capturing the right scope.

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

### Frontmatter addition

```yaml
---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: accepted
deciders: @antoaenono
tags: [state-machine, architecture]
parent: null
children: [state-machine/debounced-calls]
touches:
  - lib/maude_libs/decision/core.ex
  - lib/maude_libs/decision/server.ex
  - lib/maude_libs/decision.ex
  - test/maude_libs/decision/core_test.exs
  - test/maude_libs/decision/server_test.exs
---
```

### Glob patterns supported

```yaml
touches:
  # Exact file
  - config/test.exs
  # Directory glob
  - test/**/*
  # Wildcard within a directory
  - lib/maude_libs/decision/*_test.exs
  # Multiple extensions
  - assets/js/hooks/*.js
```

### sdt.py resolve subcommand

```bash
# Given a file, find all touching decisions
python3 ~/.claude/skills/sdt/sdt.py resolve --file lib/maude_libs/decision/core.ex

# Output:
# state-machine/core-architecture/core-architecture.md (touches: lib/maude_libs/decision/core.ex)
# state-machine/stage-representation/stage-representation.md (touches: lib/maude_libs/decision/*.ex)
```

### sdt.py stale-check subcommand

```bash
# Check all touches globs resolve to at least one existing file
python3 ~/.claude/skills/sdt/sdt.py stale-check --sdt-root .sdt

# Output:
# WARNING: state-machine/core-architecture touches "lib/maude_libs/decision/core.ex" - file not found
# OK: 27/28 decisions have valid touches
```

### LLM integration

When an LLM agent is editing a file, the workflow is:
1. Resolve the file against all SDT `touches` globs
2. Load the matched SDT files as context
3. The LLM now knows which architectural decisions constrain the code it is modifying

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: Glob lists are frequently stale after refactors despite LLM assistance
  respond: Build automated analysis (AST/xref) to generate or validate touches lists; see sibling decision `sdt/boundary-viz`
- observe: Most decisions touch only 1-3 files; the glob syntax is overkill
  respond: Simplify to plain file paths without glob support; globs add complexity for little benefit at small scale
- observe: Developers forget to update touches when adding new files
  respond: Add a CI check or pre-commit hook that warns when new files match no decision's touches list

## Artistic

Name what you touch.

## Historic

File-to-decision traceability has roots in requirements traceability matrices (RTMs) from traditional software engineering. Modern infrastructure-as-code tools (Terraform, Pulumi) track which resources each module manages. The concept of "code ownership" files (GitHub CODEOWNERS) is a related pattern that maps file globs to responsible teams.

## More Info

- [GitHub CODEOWNERS documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [Terraform resource management](https://developer.hashicorp.com/terraform/language/resources)
