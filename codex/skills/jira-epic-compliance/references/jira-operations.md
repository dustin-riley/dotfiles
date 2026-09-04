# Jira operations

## Boundaries and authentication

Use the installed `acli` command for normal Jira operations. The target site is `vanta.atlassian.net`.

ACLI credentials are stored in macOS Keychain. A sandboxed `acli jira auth status` may incorrectly report `unauthorized` even though the user's interactive CLI is logged in. Retry the ACLI command with the normal sandbox escalation/approval mechanism. Do not start `acli jira auth login --web` merely because the sandbox cannot see Keychain; that may switch the active profile from API-token authentication to OAuth.

Never print, log, paste, or persist the token. Do not enable shell tracing around credential commands.

## Inspect an epic

Use ACLI and trim JSON with `jq` so descriptions and child lists remain readable:

```bash
acli jira workitem view PEX-123 \
  --fields 'key,summary,status,description,parent,assignee,reporter' --json \
  | jq '{key, fields: {summary: .fields.summary, status: .fields.status.name, description: .fields.description, parent: {key: .fields.parent.key, summary: .fields.parent.fields.summary}, assignee: .fields.assignee.displayName, reporter: .fields.reporter.displayName}}'

acli jira workitem search \
  --jql 'parent = PEX-123' \
  --fields 'key,issuetype,summary,status' --limit 100 --json \
  | jq '[.[] | {key, type: .fields.issuetype.name, summary: .fields.summary, status: .fields.status.name}]'
```

Search parent candidates only in PEX:

```bash
acli jira workitem search \
  --jql 'project = PEX AND issuetype = Feature ORDER BY updated DESC' \
  --fields 'key,summary,status' --paginate --json \
  | jq '[.[] | {key, summary: .fields.summary, status: .fields.status.name}]'
```

Do not request `parent` or `project` in `acli jira workitem search --fields`; ACLI 1.3.17 rejects them. `parent` works with `workitem view`.

## Edit a description through a Markdown file

Draft the approved description in a uniquely named `.md` file in a writable workspace or temporary directory. Use `apply_patch` to create and edit the file; do not use shell redirection or `cat` as a file-writing shortcut.

```bash
acli jira workitem edit \
  --key PEX-123 \
  --description-file /absolute/path/PEX-123-description.md \
  --yes --json
```

ACLI accepts the file as plain text/ADF input. Keep the Markdown structurally simple: headings, paragraphs, and bullets. After the edit, retrieve the issue through ACLI and verify the actual description. Remove the temporary file with `apply_patch` after successful verification.

Summary edits use ACLI as well:

```bash
acli jira workitem edit --key PEX-123 --summary 'Outcome-focused title' --yes --json
```

## Create a PEX Feature

Only after user confirmation:

```bash
acli jira workitem create \
  --project PEX --type Feature \
  --summary 'Bounded outcome title' \
  --description-file /absolute/path/feature-description.md \
  --json
```

Give the Feature a clear outcome, included scope, exclusions, and success criteria. Capture the new PEX key from the response and verify it before parenting epics.

## REST helper for unsupported fields

ACLI 1.3.17 cannot update the parent of an existing issue and rejects `parent` in its JSON edit input. It also does not expose arbitrary custom-field edits. For these operations, use the bundled helper:

```bash
JIRA_SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills/jira-epic-compliance"
"$JIRA_SKILL_DIR/scripts/jira_rest.sh" \
  PUT '/rest/api/3/issue/PEX-123' /absolute/path/payload.json
```

Create payload files with `apply_patch`, use them for one bounded write, verify the result, then remove them with `apply_patch`.

Parent payload:

```json
{
  "fields": {
    "parent": { "key": "PEX-456" }
  }
}
```

Metadata payload:

```json
{
  "fields": {
    "customfield_12865": { "value": "M: >3–6 eng-weeks" },
    "customfield_10234": { "value": "Technical (Internal)" }
  }
}
```

Parent and metadata may be combined in one confirmed update. The helper reads the active ACLI profile and prefers `JIRA_API_TOKEN` when it is available. On macOS it can instead locate the saved API-token credential in Keychain, remove the `go-keyring-base64:` wrapper, and decode it. It calls the site REST API without printing the token. Run it with the normal sandbox escalation/approval mechanism because it accesses the network and may access Keychain.

If neither `JIRA_API_TOKEN` nor the macOS API-token Keychain entry is available, stop and ask the user to provide `JIRA_API_TOKEN` through their environment or secret manager. Do not fall back to scraping or exposing OAuth credentials.

## Verify

Verify hierarchy and descriptions with ACLI. Verify custom fields with the REST helper:

```bash
JIRA_SKILL_DIR="${CODEX_HOME:-$HOME/.codex}/skills/jira-epic-compliance"
"$JIRA_SKILL_DIR/scripts/jira_rest.sh" \
  GET '/rest/api/3/issue/PEX-123?fields=summary,parent,description,customfield_12865,customfield_10234' \
  | jq '{key, summary: .fields.summary, parent: .fields.parent.key, effort: .fields.customfield_12865.value, roadmap_visibility: .fields.customfield_10234.value}'
```

Treat HTTP `204` as success for Jira issue updates, but still verify the resulting fields. On any 4xx/5xx response, report the Jira body without retrying a mutation blindly.
