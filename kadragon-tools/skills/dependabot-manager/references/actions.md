# Phase 3: Actions

Offer actions in order of safety. Confirm before all destructive actions.

## 3a. Batch Merge Ready PRs

Offer: merge all / select / skip. Merge with:

```bash
gh pr merge {number} -R {owner}/{repo} --squash --delete-branch
```

## 3b. Handle Multiple Major PRs

Detect major PRs by title (major version number differs). Merging one makes others go behind, creating a serial bottleneck.

- **2 or fewer major PRs** — sequential merge + `@dependabot rebase` on remaining
- **3+ major PRs** — offer consolidated branch (`chore/major-dependency-updates`): apply all bumps together, create single PR, close originals with `gh pr close --comment "Included in #{consolidated_pr}"`

## 3c. Handle Rebase-Needed PRs (non-major)

Offer to comment `@dependabot rebase` on each.

## 3d. Analyze Failed PRs

```bash
gh pr checks {number} -R {owner}/{repo} --json name,state,detailsUrl --jq '.[] | select(.state == "FAILURE")'
```

Analyze and suggest fix. Common failure patterns:

| Pattern | Likely cause |
|---------|-------------|
| Type errors | Breaking API change in dependency |
| Test failures | Behavioral change in dependency |
| Build failures | Peer dependency mismatch |
| Lint failures | New rules introduced by dependency |

## 3e. Handle No-CI PRs

Warn that merging without CI is risky. If user proceeds, confirm per PR (not batch).

## 3f. Configure Grouped Updates

For repos missing grouped updates or `github-actions` ecosystem, offer to configure. Create branch `chore/configure-dependabot-grouped-updates`, add config:

```yaml
groups:
  dependencies:
    patterns: ["*"]
    update-types: ["minor", "patch"]
```

If repo uses Actions but lacks `github-actions` ecosystem, also add:

```yaml
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns: ["*"]
        update-types: ["minor", "patch"]
```

## 3g. Consolidate Ungrouped PRs (Fallback)

For repos with 3+ individual PRs and no grouped updates, offer consolidation using bundled scripts:

- **npm**: `${CLAUDE_PLUGIN_ROOT}/skills/dependabot-manager/scripts/consolidate-deps.cjs`
- **Python**: `${CLAUDE_PLUGIN_ROOT}/skills/dependabot-manager/scripts/consolidate-deps.py`
- **Other ecosystems**: Manual workflow via Edit tool. Requires local clone.

### Consolidation Script Workflow

Both scripts follow the same flow:

1. Fetch open dependabot PRs via `gh pr list`
2. Parse package names and versions from PR titles
3. Create `chore/deps-combined-update` branch
4. Apply all version bumps to dependency files
5. Run tests to verify compatibility
6. Commit, push, and create consolidated PR
7. Close individual dependabot PRs with cross-reference
