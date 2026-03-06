---
author: @antoaenono
asked: 2026-03-04
decided: 2026-03-04
status: accepted
deciders: @antoaenono
tags: [sdt, traceability, code-mapping, globs, xref, validation, discovery]
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

Manual globs in frontmatter with bidirectional xref verification: author `touches` globs manually, then use `mix xref` to both validate existing globs (flag stale paths) and discover missing files (suggest additions)

## Why(not)

In the face of **mapping SDT decisions to the source files they affect**,
instead of doing nothing
(**decisions and code exist in parallel with no explicit link; finding which decisions shaped a file requires manual search through the SDT corpus**),
we decided **to combine manual `touches` globs in YAML frontmatter with automated bidirectional xref verification that validates globs against reality and discovers files the author missed**,
to achieve **explicit, human-authored traceability that stays honest through automated validation and grows through automated discovery**,
accepting **custom tooling investment to bridge sdt.py and `mix xref`, and incomplete coverage for non-Elixir files where xref cannot help**.

## Points

### For

- [M1] Manual globs provide the authored mapping; xref discovery finds files the author missed by walking the call graph from modules mentioned in the Implementation section
- [M2] Bidirectional verification: (a) validate - flag globs that resolve to no files or files that no longer import the expected modules; (b) discover - `mix xref graph --sink Module` reveals callers the author did not list
- [M3] LLM agents get both the authored globs (fast, always available) and can run xref discovery for deeper context when needed
- [L1] Automated validation catches drift before it misleads; stale globs are flagged, not silently trusted
- [L3] Xref discovery suggests files at the right granularity - actual callers, not guessed globs

### Against

- [L2] Same authoring friction as manual-globs for initial `touches` lists, plus building the xref bridge tooling
- [L1] Custom tooling (~100-200 lines in sdt.py) that must be maintained; shells out to `mix xref` which requires a compiled project
- [L3] Xref only covers Elixir (.ex/.exs); JS hooks, CSS, config files, Dockerfiles cannot be discovered or validated this way
- [L1] Discovery can be noisy: `mix xref graph --sink MaudeLibs.Decision.Core` may surface test helpers, support modules, and other files that are related but not meaningfully "touched" by the decision

## Consequences

- [authoring] Same `touches` field as manual-globs variant; authors write globs, tooling augments them
- [tooling] sdt.py gains three subcommands: `resolve` (glob -> files), `stale-check` (validate globs exist), `discover` (xref -> suggested additions); requires `mix xref` available in PATH
- [traceability] Three layers: authored globs (fast lookup), validation (catch drift), discovery (find gaps)
- [dx] Workflow: author globs during scaffolding, run `sdt.py discover` periodically or in CI to surface missing mappings

## Evidence

`mix xref` produces machine-readable output in multiple formats. `mix xref graph --sink Module --format plain` lists all files that depend on a module, one per line. `mix xref callers Module` lists callers with file and line number. Both can be parsed by sdt.py to compare against `touches` globs. The key insight is that xref works in both directions: given a module (extracted from a decision's Implementation section), find all files that use it (discovery); given a file (from a `touches` glob), verify it actually references the expected modules (validation). This closes the loop that pure manual globs leave open.

## Diagram

<!-- no diagram needed for this decision -->

## Implementation

### Frontmatter (same as manual-globs)

```yaml
---
touches:
  - lib/maude_libs/decision/core.ex
  - lib/maude_libs/decision/server.ex
  - test/maude_libs/decision/*_test.exs
---
```

### Validation direction: globs -> xref

"Do my globs still make sense?"

```bash
# Check that touched files actually reference modules from the decision
python3 ~/.claude/skills/sdt/sdt.py validate-touches --sdt-root .sdt

# Output:
# state-machine/core-architecture:
#   OK: lib/maude_libs/decision/core.ex references Decision, Stage.Lobby
#   OK: lib/maude_libs/decision/server.ex references Decision.Core
#   STALE: lib/maude_libs/old_helper.ex - file not found
#   WEAK: config/config.exs - exists but does not reference any decision modules
```

Implementation in sdt.py:

```python
def validate_touches(sdt_root):
    for decision in load_accepted_decisions(sdt_root):
        modules = extract_modules_from_implementation(decision)
        for glob_pattern in decision.frontmatter.get("touches", []):
            matched_files = expand_glob(glob_pattern)
            if not matched_files:
                warn(f"STALE: {glob_pattern} matches no files")
                continue
            for f in matched_files:
                # Shell out to mix xref to check if file references expected modules
                xref_deps = run(f"mix xref graph --source {f} --format plain")
                if not any(mod in xref_deps for mod in modules):
                    warn(f"WEAK: {f} does not reference {modules}")
```

### Discovery direction: xref -> globs

"What files did I miss?"

```bash
# Discover files related to a decision via xref that aren't in touches
python3 ~/.claude/skills/sdt/sdt.py discover --decision state-machine/core-architecture

# Output:
# Files referencing Decision.Core not in touches:
#   lib/maude_libs/decision/effects.ex (calls Core.handle/2)
#   lib/maude_libs_web/live/decision_live.ex (calls Server.message/2)
#   test/support/decision_helpers.ex (calls Core.handle/2)
# Suggest adding to touches? [y/n]
```

Implementation in sdt.py:

```python
def discover(decision_path):
    decision = load_decision(decision_path)
    modules = extract_modules_from_implementation(decision)
    current_touches = expand_all_globs(decision.frontmatter.get("touches", []))

    discovered = set()
    for mod in modules:
        # mix xref graph --sink Module --format plain
        # returns all files that depend on Module
        callers = run(f"mix xref graph --sink {mod} --format plain")
        for caller_file in parse_xref_output(callers):
            if caller_file not in current_touches:
                discovered.add(caller_file)

    return discovered
```

### Module extraction from Implementation

The `extract_modules_from_implementation` function parses the Implementation section's code blocks for Elixir module references:

```python
def extract_modules_from_implementation(decision):
    """Extract module names from ```elixir code blocks in ## Implementation."""
    modules = set()
    # Match defmodule declarations
    modules.update(re.findall(r'defmodule\s+([\w.]+)', decision.implementation))
    # Match module references in function calls (Module.function)
    modules.update(re.findall(r'([A-Z][\w.]+)\.\w+', decision.implementation))
    return modules
```

### Non-Elixir files

Xref cannot validate or discover JS, CSS, or config files. For these, the workflow remains manual-globs-only:

```yaml
touches:
  # Elixir files - validated and augmented by xref
  - lib/maude_libs/decision/core.ex
  - lib/maude_libs/decision/server.ex
  # Non-Elixir files - manual only, validated by stale-check (file exists?)
  - assets/js/hooks/force_layout_hook.js
  - config/test.exs
```

### CI integration

```yaml
# In CI pipeline
- name: Validate SDT touches
  run: python3 ~/.claude/skills/sdt/sdt.py validate-touches --sdt-root .sdt --strict
```

## Exceptions

<!-- no exceptions -->

## Reconsider

- observe: Discovery produces too many false positives (test helpers, support modules, indirect callers)
  respond: Add an `ignore` list to frontmatter or a global `.sdt/touchignore` file to suppress known noise
- observe: `mix xref` output format changes between Elixir versions
  respond: Pin the expected output format; use `--format plain` which is the most stable
- observe: The `boundary` library (see `sdt/boundary-viz`) provides a cleaner module grouping that maps to SDT decisions
  respond: Use boundary group names instead of raw module extraction; boundary groups are the authoritative module-to-decision mapping
- observe: Non-Elixir discovery is needed (JS hooks calling specific LiveView events)
  respond: Add a lightweight JS import parser for `assets/js/hooks/`; or accept manual-only for non-Elixir

## Artistic

Author the map; let the compiler check the territory.

## Historic

The pattern of combining manual declarations with automated verification is common in infrastructure: Terraform plans show drift between declared state and actual state; Kubernetes admission controllers validate manifests against policies. In code, linters like ESLint and Credo combine authored rules with automated checking. The xref bridge applies the same principle to decision-code traceability: humans declare intent (touches), machines verify reality (xref).

## More Info

- [mix xref documentation](https://hexdocs.pm/mix/Mix.Tasks.Xref.html)
- [mix xref graph options](https://hexdocs.pm/mix/Mix.Tasks.Xref.html#module-graph)
- [GitHub CODEOWNERS documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
