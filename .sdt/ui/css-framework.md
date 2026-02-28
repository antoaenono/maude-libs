---
author: @antoaenono
asked: 2026-02-28
decided: 2026-02-28
status: accepted
deciders: @antoaenono
tags: [ui, css, tailwind]
parent: null
children: []
---

# SDT: CSS Framework

## Scenario

Which CSS approach should we use for styling the Phoenix LiveView app?

## Pressures

### More

1. [M1] Development speed - utility classes ship UI faster than writing custom CSS
2. [M2] Consistency - a design system prevents ad-hoc style decisions slowing the sprint

### Less

1. [L1] Build complexity - Tailwind requires a build step (postcss/esbuild integration)
2. [L2] Bundle size - purging unused utilities must be configured correctly

## Chosen Option

Tailwind CSS: Phoenix 1.7+ ships with it by default; zero additional setup

## Why(not)

In the face of **choosing a CSS approach for a prototype Phoenix LiveView app**, instead of doing nothing (**plain browser CSS - slower iteration, no design system**), we decided **to use Tailwind CSS via Phoenix's built-in integration**, to achieve **fast utility-class-driven UI without any additional tooling configuration**, accepting **that utility class HTML can be verbose and hard to scan at first glance**.

## Points

### For

- [M1] `mix phx.new` with Tailwind is the default; zero extra setup
- [M2] Tailwind's utility system enforces a consistent spacing/color scale
- [L1] Phoenix esbuild + Tailwind integration is pre-configured in a new project

### Against

- [L2] Purging requires content paths in tailwind.config.js to be correct (Phoenix default handles this)

## Artistic

<!-- author this yourself -->

## Consequences

- [deps] Tailwind included via `mix phx.new` default; no extra deps
- [build] postcss/esbuild pipeline pre-configured by Phoenix generator
- [dx] Utility classes in heex templates; component patterns via @apply sparingly

## How

```bash
# Default Phoenix 1.7+ command includes Tailwind:
mix phx.new maude_libs --live --no-dashboard --no-mailer
# Do NOT add --no-tailwind
```

## Reconsider

- observe: Tailwind class names become unwieldy on complex components
  respond: Extract to Phoenix LiveComponents with @apply in component CSS files

## Historic

Phoenix adopted Tailwind as the default CSS framework in Phoenix 1.7 (2023). Previous versions used plain CSS. The shift reflects the broader Elixir community consensus.

## More Info

- [Tailwind + Phoenix setup](https://hexdocs.pm/phoenix/asset_management.html)
