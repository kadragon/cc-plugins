---
name: dependabot-manager
version: 0.2.0
description: >
  This skill should be used when the user asks to "manage dependabot PRs",
  "merge dependabot PRs", "clean up dependabot", "consolidate dependency PRs",
  "batch update dependencies", "too many dependabot PRs", "configure grouped updates",
  "audit dependabot config", "review dependency PRs", "check dependabot status",
  "dependabot rebase", or describes multiple open dependency-update PRs across repos
  — even without saying "dependabot" explicitly.
---

# Dependabot Manager

Manage dependabot PRs across all repos owned by the authenticated GitHub user in three phases: **Discovery → Triage → Action**.

Spawn one subagent per repo when multiple repos have open PRs. Phases 1-2 operate entirely via `gh` CLI (no clone). Phase 3 actions may require local clone for config edits and consolidation.

## Subagent Model Selection

Most tasks are structured CLI execution + simple classification. Use the `model` parameter when spawning subagents:

| Task | Model | Rationale |
|------|-------|-----------|
| Phase 2 triage (config audit + PR status) | `haiku` | Pattern matching on gh CLI output |
| Batch merge (`gh pr merge`) | `haiku` | Repetitive command execution |
| `@dependabot rebase` comments | `haiku` | Single-command execution |
| CI wait + merge (polling loop) | `haiku` | Simple polling + conditional merge |
| CI failure analysis (log reading) | `sonnet` | Reading logs and reasoning about root cause |
| Config fix PR creation (clone + edit + push) | `sonnet` | File editing + multi-step git workflow |
| PR consolidation / major bump handling | `sonnet` | Multi-step workflow with judgment calls |

Reserve `opus` (default, no model param) only for tasks requiring complex architectural reasoning — most dependabot tasks do not.

## Phase 1: Discovery

```bash
gh search prs --author app/dependabot --state open --owner @me --json repository,number,title,url --limit 200
```

Group by repo, present count summary. If none found, exit early.

## Phase 2: Per-Repo Triage

All checks use `gh` CLI remotely — no local clone needed.

For each repo, audit dependabot config (check for `groups:` block and `github-actions` ecosystem), then categorize each PR by CI status and mergeability into one of five categories: ready to merge, needs rebase, CI failed, CI pending, or no CI.

Present categorized results per repo with emoji prefix.

For detailed triage procedures, consult **`references/triage.md`**.

## Phase 3: Action

Offer actions in order of safety. Confirm before all destructive actions.

| Priority | Action | When |
|----------|--------|------|
| 1 | Batch merge ready PRs | CI passed + mergeable |
| 2 | Handle major PRs | Major version bumps detected |
| 3 | Rebase stale PRs | CI passed but conflicting/behind |
| 4 | Analyze CI failures | Any check failed |
| 5 | Warn about no-CI PRs | No status checks configured |
| 6 | Configure grouped updates | Missing or partial config |
| 7 | Consolidate ungrouped PRs | 3+ individual PRs, no groups |

For detailed action procedures, consult **`references/actions.md`**.

## Interaction Rules

- Respond in the user's language; keep technical artifacts (commits, PRs, branches) in English.
- Confirm before destructive actions; default to report-only.
- Errors: unauthenticated → suggest `gh auth login`; rate-limited → reduce scope; permission denied → report which repos.

## Scripts

Bundled consolidation scripts for repos with many ungrouped PRs:

- **`scripts/consolidate-deps.cjs`** — npm/Node.js projects. Updates `package.json`, runs `npm install` and `npm test`.
- **`scripts/consolidate-deps.py`** — Python projects. Supports uv, poetry, pip-tools, and requirements.txt.

Both scripts: fetch dependabot PRs → parse versions → create branch → apply bumps → test → commit → push → create consolidated PR → close originals.

Invoke via:
```bash
node ${CLAUDE_PLUGIN_ROOT}/skills/dependabot-manager/scripts/consolidate-deps.cjs
python3 ${CLAUDE_PLUGIN_ROOT}/skills/dependabot-manager/scripts/consolidate-deps.py
```
