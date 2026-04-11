# Phase 2: Per-Repo Triage

All checks use `gh` CLI remotely — no local clone needed.

## 2a. Config Audit

```bash
gh api repos/{owner}/{repo}/contents/.github/dependabot.yml --jq '.content' | base64 -d
```

Check for: `groups:` block with `update-types: [minor, patch]`. Report status (configured / partial / missing / no file).

**GitHub Actions check:** If `.github/workflows/` exists, verify `package-ecosystem: "github-actions"` is in dependabot config. Actions without version tracking miss security patches — flag as warning if missing.

## 2b. PR Status Check

```bash
gh pr view {number} -R {owner}/{repo} --json number,title,mergeable,mergeStateStatus,statusCheckRollup,headRefName
```

| Emoji | Category | Condition |
|---|---|---|
| ✅ | Ready to merge | CI passed + `mergeable: MERGEABLE` |
| 🔄 | Needs rebase | CI passed + `CONFLICTING` or `BEHIND` |
| ❌ | CI failed | Any check failed |
| ⏳ | CI pending | Checks still running |
| ⚪ | No CI | No status checks configured |

## 2c. Triage Report

Present categorized results per repo with emoji prefix. For failed/rebase/no-CI items, include a detail line explaining the issue.
