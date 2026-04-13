---
name: harness-sync
version: 0.1.0
description: |
  This skill should be used when the user asks to "sync harness", "harness sync", "harness 동기화",
  "AGENTS.md 정리", "AGENTS.md 업데이트", "CLAUDE.md 동기화", "backlog 정리", "tasks 정리",
  "세션 시작 루틴", "하네스 유지보수", or when starting work in a repo that has AGENTS.md,
  backlog.md, or tasks.md. Also use proactively and silently at the start of any session in a repo
  with agent infrastructure (any of: AGENTS.md, CLAUDE.md pointing to AGENTS.md, backlog.md,
  tasks.md) — execute sections C through E before the user's first task and report only if
  something changed or errored.
---

# Harness Sync

Maintain the repository's agent instruction files under a **minimal-noise policy**.
Run at session start (silently) or on explicit request.

**Primary goal:**
- `AGENTS.md` — canonical, minimal operational log
- `CLAUDE.md` — must contain exactly one line: `@AGENTS.md`

## Execution Order

Run A → B → C → D → E in sequence. Each section is independent; skip gracefully if files
don't exist. Silent unless an action is taken or an error occurs.

---

## A) AGENTS.md Update Rules

Update `AGENTS.md` **only** when ALL of the following are true:

1. The information is not directly discoverable from code / config / manifests / docs
2. It is operationally significant — affects build, test, deploy, or runtime safety
3. It would likely cause mistakes if left undocumented
4. It is stable and not task-specific

**Never add:**
- Architecture summaries or tech stack descriptions
- Directory structure overviews
- Style conventions already enforced by tooling
- Anything already visible in the repo
- Temporary or task-specific instructions

Keep edits minimal. Prefer modifying or removing outdated entries over appending.
When unsure, add a short inline `TODO:` comment rather than inventing guidance.

---

## B) CLAUDE.md Deterministic Sync

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/harness-sync/scripts/sync-claude-md.sh
```

Exit codes:
- `0` — Already contains exactly `@AGENTS.md`. Stop.
- `1` — Did not exist → script created it with `@AGENTS.md`. Done.
- `2` — Exists but differs → script printed the original content to stdout.

**If exit code 2:**
1. Read the extracted content from stdout.
2. Filter each instruction using the A) acceptance criteria above.
3. Merge qualifying items into `AGENTS.md`.
4. Rewrite `CLAUDE.md` to contain exactly (no extra text, no blank lines):
   ```
   @AGENTS.md
   ```

---

## C) Harness Reconciliation

Run silently. The script syncs `tasks.md` status into `backlog.md` and prints one status line.

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/harness-sync/scripts/reconcile-harness.py
```

Output:
- `Sprint active: <title>` — tasks.md is active or evaluating; leave intact
- `Backlog: N queued, M active` — backlog has pending items
- `Backlog clear.` — nothing pending

---

## D) Harness Docs & Skills Refresh

Run after C. Requires judgment — not scripted.

### D-1) Docs structure check

Verify the **schema** (not the content) of harness-related docs:

- `backlog.md` items must follow `[ ]` / `[>]` / `[x]` checkbox pattern under headings
- `tasks.md` must have these fields: `Scope`, `Acceptance Criteria`, `Evaluator Feedback`, `status`

If structural drift is detected, fix the schema in-place. Do **not** rewrite content.

### D-2) Skills refresh

```bash
find .claude/skills -name "SKILL.md" 2>/dev/null
```

For each `SKILL.md` found:
- Verify frontmatter is parseable (must have `name` and `description` fields)
- Flag stale skills: not referenced in `backlog.md` or `tasks.md` for 5+ sprints

Print stale list to stdout if any. Do **not** auto-delete — human decides.

---

## E) Skills Symlink Guard

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/harness-sync/scripts/symlink-guard.sh
```

Ensures `.agents/skills` is a symlink pointing to `../.claude/skills`.
Silent on success; prints one line on change.

---

## Bundled Scripts

| Script | Section | Purpose |
|--------|---------|---------|
| `scripts/sync-claude-md.sh` | B | Check CLAUDE.md state; exit 0/1/2 |
| `scripts/reconcile-harness.py` | C | Sync tasks.md → backlog.md |
| `scripts/symlink-guard.sh` | E | Ensure .agents/skills symlink |

All scripts are run from the repo root and operate on files in the current working directory.
