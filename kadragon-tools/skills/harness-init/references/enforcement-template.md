# Enforcement Chain Template

Documentation alone does not prevent violations. Build a multi-layer enforcement chain so golden principles are mechanically guaranteed, not just documented.

## Defense in Depth

```
Agent edits a file
  -> PostToolUse hook warns immediately        (Layer 1: Real-time)
  -> Pre-commit blocks the commit if unfixed   (Layer 2: Pre-commit)
  -> CI blocks the merge                       (Layer 3: CI gate)
  -> PR reviewer confirms via checklist        (Layer 4: PR template)
```

Not every project needs all 4 layers. Match enforcement depth to team size and risk tolerance.

## Layer 1: Real-time Hooks (`.claude/settings.json`)

Create `.claude/settings.json` with hooks that fire during agent editing:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/pre-edit-guard.sh"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash .claude/hooks/post-edit-lint.sh"}]
      }
    ]
  }
}
```

Design hooks that catch golden principle violations **at edit time**, before commit. The hook's error message should tell the agent exactly what is wrong and how to fix it.

### Hook Script Pattern

```bash
#!/bin/bash
# .claude/hooks/post-edit-lint.sh
# Runs lint on the file that was just edited

FILE="$CLAUDE_TOOL_ARG_FILE_PATH"
[[ -z "$FILE" ]] && exit 0

# ADAPT: Replace with project's lint command targeting the specific file
# npm run lint -- "$FILE"
# ruff check "$FILE"
# cargo clippy -- "$FILE"

# On failure, output includes:
#   1. What rule was violated
#   2. How to fix it
#   3. Which doc explains the rule
```

### Performance: Use `[[ =~ ]]` Instead of `grep` in Hooks

Hooks fire on every edit. If a hook reads a file line-by-line and calls `echo "$line" | grep` per line, it forks a subprocess per check. At scale (e.g., 35 Java files × 15 checks/line), this means thousands of forks and becomes the dominant bottleneck.

**`[[ =~ ]]` is a bash builtin (since bash 3.0) — no fork, no subprocess.** Replace all `echo | grep` patterns with `[[ =~ ]]` in hook scripts.

```bash
# BAD: forks a subprocess per line — O(lines × checks) forks
while IFS= read -r line; do
    if echo "$line" | grep -qP 'TODO|FIXME|HACK'; then
        violations+=("$line")
    fi
done < "$FILE"

# GOOD: bash builtin, zero forks — same O(lines × checks) comparisons but in-process
while IFS= read -r line; do
    if [[ "$line" =~ TODO|FIXME|HACK ]]; then
        violations+=("$line")
    fi
done < "$FILE"
```

**Pattern migration reference:**

| grep pattern | `[[ =~ ]]` equivalent | Notes |
|---|---|---|
| `echo "$x" \| grep -q 'pat'` | `[[ "$x" =~ pat ]]` | No quoting the regex |
| `grep -qP '^\d+\.'` | `[[ "$x" =~ ^[0-9]+\. ]]` | ERE, not PCRE — use `[0-9]` for `\d` |
| `grep -oP '(pat)' \| ...` | `[[ "$x" =~ (pat) ]]; echo "${BASH_REMATCH[1]}"` | Captures via `BASH_REMATCH` |
| `grep -c 'pat' file` | Loop + counter: `[[ "$line" =~ pat ]] && ((count++))` | Single pass through file |
| `cmd \| grep -v '^$'` | `[[ -n "$line" ]]` in a while-read loop | Filter empty lines |

**When grep is still fine:** Single invocations on whole files (`grep -q 'pattern' file.txt`) fork once — no performance concern. The problem is grep *inside loops*.

## Layer 2: Pre-commit Checks

Wire golden principle checks into git pre-commit hooks or the project's existing pre-commit framework.

### Using pre-commit framework (Python ecosystem)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: golden-principles
        name: Golden Principle Check
        entry: bash tools/check-principles.sh
        language: system
        pass_filenames: true
```

### Using Husky (Node ecosystem)

```bash
# .husky/pre-commit
npx lint-staged
```

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.sql": ["bash tools/check-sql-safety.sh"]
  }
}
```

### Plain git hook

```bash
# .git/hooks/pre-commit
#!/bin/bash
bash tools/check-principles.sh $(git diff --cached --name-only)
```

## Layer 3: CI Gate

Add golden principle enforcement to the CI pipeline.

### GitHub Actions example

```yaml
# .github/workflows/principles.yml
name: Golden Principles
on: [pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash tools/check-principles.sh
```

### GitLab CI example

```yaml
golden-principles:
  stage: test
  script:
    - bash tools/check-principles.sh
  rules:
    - if: $CI_MERGE_REQUEST_ID
```

## Layer 4: PR Template (optional)

Create a PR template with a checklist derived from golden principles:

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE.md -->
## Checklist

- [ ] Golden principle 1: {description}
- [ ] Golden principle 2: {description}
- [ ] Golden principle 3: {description}
- [ ] Tests pass locally
- [ ] Lint passes
- [ ] Docs updated if applicable
```

## Choosing Layers

| Team size | Recommended layers |
|-----------|-------------------|
| Solo dev | Layer 1 (hooks) + Layer 2 (pre-commit) |
| Small team (2-5) | Layer 1 + Layer 2 + Layer 3 (CI) |
| Large team (5+) | All 4 layers |

| Risk level | Recommended layers |
|------------|-------------------|
| Low (docs site, internal tool) | Layer 1 + Layer 2 |
| Medium (SaaS, API service) | Layer 1 + Layer 2 + Layer 3 |
| High (fintech, healthcare, auth) | All 4 layers |
