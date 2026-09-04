---
name: jira-epic-compliance
description: Review and remediate Jira epics against the Vanta hierarchy, content-quality, and metadata readiness ladder. Use when the user pastes an epic migration Markdown report or asks to make PEX Jira epics compliant with Feature parents, outcome-focused descriptions, acceptance criteria, Effort, and Roadmap Visibility.
---

# Jira Epic Compliance

Turn the pasted migration report into an interactive, one-epic-at-a-time remediation session. Treat the report as a worklist and the live Jira issue as authoritative because the report may be stale.

Before acting, read:

- [references/compliance-rubric.md](references/compliance-rubric.md) for grading and shaping decisions.
- [references/jira-operations.md](references/jira-operations.md) for ACLI, Markdown-description, REST, authentication, and verification procedures.

## Working agreement

- Process epics in the pasted order unless the user redirects or skips one.
- Inspect the live epic, its Feature parent, all children, and both metadata fields before recommending action.
- Only use Features in the `PEX` project as parents. Never recommend or assign a cross-project parent.
- Use ACLI for Jira discovery, issue inspection, child searches, Feature creation, and description edits. Use the Jira REST helper only where ACLI 1.3.17 lacks support: changing an existing parent and setting custom metadata fields.
- Do not change an epic until the user confirms the proposed parent, content change, structural action, or metadata values. A confirmed proposal authorizes only those named mutations.
- Never infer that review feedback or a tracker verdict authorizes edits.
- If a live epic and all its children are `Won't Do`, or it is otherwise clearly dissolved with no active work, report it as handled and do not add description or metadata merely to make a dead epic score.
- Verify every write from Jira. Do not claim compliance from a successful command alone.

## User-facing cadence

For every epic, including already handled or dissolved epics, begin with a level-three linked heading in exactly this shape:

```markdown
### [PEX-123 — Current live Jira summary](https://vanta.atlassian.net/browse/PEX-123)
```

The heading must contain both the key and the current live summary. Never use a bare epic key as the heading. If recommending a rename, keep the current summary in the heading and show `Current summary` and `Proposed summary` as separate labeled lines in the recommendation.

For each actionable epic, then provide:

1. The linked heading above.
2. A one- or two-sentence **TL;DR** explaining the delivered outcome in plain language.
3. Current hierarchy/content state and the smallest correction needed.
4. Recommended parent, Effort, and Roadmap Visibility, with brief reasoning.
5. One concise confirmation question covering the exact proposed changes.

After approval, apply and verify the changes, state the resulting `H/C/M` rungs, and continue to the next epic. Do not ask the user to re-confirm already approved values.

## Decision defaults

- Prefer the smallest correction that makes the epic honest and announceable.
- Preserve meaningful container epics when their bounded contents and delivered value can be stated.
- Recommend `Technical (Internal)` for architecture, maintenance, reliability, performance improvements to existing behavior, defect correction, process, and engineering enablement unless the work introduces a genuinely new externally meaningful capability.
- Recommend `Customer Facing` for a new or materially expanded capability that customers, auditors, partners, or external API consumers receive.
- Base Effort on the expected engineering work, not ticket count alone. State uncertainty and ask when the live scope does not support a responsible estimate.
- When no suitable PEX Feature exists, propose creating a bounded PEX Feature. Do not create it until the user confirms.
