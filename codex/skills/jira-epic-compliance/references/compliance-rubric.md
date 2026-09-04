# Epic compliance rubric

## Readiness ladder

Each rung is independent and should be reported separately:

1. **Hierarchy (H):** the epic has a Feature parent.
2. **Content quality (C):** the epic describes an announceable outcome and has a sufficient description.
3. **Metadata (M):** both Effort and Roadmap Visibility are filled.

An epic is fully ready only when all three are complete. Work in priority order: hierarchy, content, metadata.

## Axis 1: value delivered

A container, KTLO, cleanup, or product-quality epic may pass when it names a bounded scope and the value delivered. Fail only for these shapes:

- **Slice:** one technical layer of a larger outcome. The slice delivers no standalone value to an internal or external customer.
- **Task:** a single to-do that belongs inside an epic.
- **Cannot assess:** empty or near-empty content. A plausible title does not make an epic announceable.
- **Borderline:** real value exists, but the epic is framed as work to perform rather than an outcome someone receives.

## Corrections

- **OK — add acceptance criteria:** the outcome and scope are sound; add observable completion criteria.
- **Rewrite:** preserve the epic and tickets, but restructure the description around problem, outcome, value recipient, scope, and acceptance criteria.
- **Reshape:** reframe the epic around an outcome; some tickets may need to move.
- **Dissolve / merge:** move surviving work to the epic carrying the actual value, then close the invalid epic.
- **Structural:** shorthand for reshape plus dissolve/merge work.

Do not treat a rewrite as sufficient for a true task or technical slice. Conversely, do not dissolve a useful bounded container merely because its children are heterogeneous.

## Description template

Use the sections that help; do not add filler to satisfy a template.

```markdown
## Problem

Who is affected, what is difficult today, and why it matters.

## Outcome

Who receives what observable value when the epic ships.

## Included scope

- Bounded deliverable or workflow.
- Bounded deliverable or workflow.

## Acceptance criteria

- Observable behavior or result that must be true.
- Relevant permissions, reliability, compatibility, or failure behavior.
- Remaining work is completed, explicitly descoped, or moved appropriately.

## Non-goals

Optional boundaries when adjacent work could cause ambiguity.
```

Acceptance criteria describe what is observably true for the customer or team, not merely implementation tasks. The description should contain enough information to draft a ship announcement. The historical 200-character signal is only a warning; never pad a weak epic to cross it.

## Metadata values

Effort (`customfield_12865`) options:

- `XS: <1 eng-week`
- `S: >1–3 eng-weeks`
- `M: >3–6 eng-weeks`
- `L: >6–12 eng-weeks`
- `XL: >12 eng-weeks`

Roadmap Visibility (`customfield_10234`) options:

- `Customer Facing`
- `Technical (Internal)`

Roadmap Visibility describes the nature of the roadmap item, not whether a customer might indirectly notice it. Existing-behavior performance, bug fixes, refactors, reliability, security hardening, documentation, and operational work normally remain `Technical (Internal)`. Use `Customer Facing` for net-new or materially expanded external capabilities.
