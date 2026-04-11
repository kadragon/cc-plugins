---
name: harness-init
version: 0.2.0
description: |
  This skill should be used when the user asks to "set up a harness", "initialize agent infrastructure", "bootstrap AGENTS.md", "create agent rules", "set up Claude Code for a new repo", "하네스 초기화", "에이전트 설정", or wants to make a repository agent-ready. This skill should also be used when the user mentions wanting consistent AI-assisted development, delegation to sub-agents, automated code quality checks, or structured agent workflows for a codebase. This skill is repo-scoped — it does NOT modify global ~/.claude/CLAUDE.md.
---

# Harness Init

Set up a complete harness system for a repository so that Claude Code (and other AI agents) can do reliable, consistent work. The harness is the full environment of scaffolding, constraints, feedback loops, and documentation that surrounds an agent.

## Core Philosophy

Three sources inform this harness design:

1. **Anthropic** — Generator-Evaluator separation, context reset over compaction, every harness component encodes a model-limitation assumption that should be periodically re-examined
2. **OpenAI** — AGENTS.md is a map not an encyclopedia (~100 lines), repository is the system of record, golden principles enforced mechanically, automated garbage collection
3. **Practical experience** — Progressive disclosure (INDEX -> detail), agent-readable lint errors, sub-agent context manifests

The key insight: **if the agent struggles, that's a harness defect**, not an agent defect. Fix the environment, not the prompt.

## When to Use

- Setting up a new repository for AI-assisted development
- Retrofitting an existing codebase with agent infrastructure
- After cloning a repo that has no AGENTS.md or docs/ structure
- When the user reports that AI agents keep making mistakes or forgetting context

## Prerequisites

Before starting, gather project information (ask the user if not obvious from the repo):

1. **Tech stack** — Language(s), framework(s), database, frontend
2. **Project type** — Greenfield, legacy, monorepo, library
3. **Team size** — Solo dev, small team, large org
4. **Existing tooling** — Linters, CI, test frameworks, build tools
5. **Pain points** — What goes wrong when agents work on this repo?

## Execution Steps

Work through these steps in order. Each step produces concrete artifacts.

### Step 1: Analyze the Repository

Before creating anything, understand what exists.

```
Scan the repo for:
- README.md, CLAUDE.md, AGENTS.md (existing agent config)
- docs/ directory (existing documentation)
- Build/CI config (package.json, Cargo.toml, pom.xml, Makefile, etc.)
- Lint config (.eslintrc, checkstyle, rustfmt, etc.)
- Test infrastructure (test directories, test config)
- Source structure (how code is organized)
- Git history (commit message patterns, branch strategy)
```

Record findings — these shape every artifact created downstream. If existing AGENTS.md or docs/ exist, read them and decide what to keep vs. replace.

### Step 2: Define Golden Principles

Golden principles are the 3-7 invariants that, if violated, cause the most damage. They must be:
- **Mechanically enforceable** (via lint, test, or hook — not verbal agreement)
- **Specific to this project** (not generic "write clean code")
- **Grounded in real pain** (past bugs, security issues, consistency problems)

Read `references/golden-principles-guide.md` for examples across different tech stacks.

Ask the user: "What are the rules that, if broken, cause the most pain in this codebase?" The answer seeds the golden principles.

### Step 3: Create AGENTS.md

AGENTS.md is a **map, not an encyclopedia**. Target ~80-100 lines. It should fit in the agent's context window without crowding out actual work.

See `examples/agents-md-example.md` for a complete reference.

**Structure:**

```markdown
# {Project Name} Agent Rules

{One-line description of the project and its tech stack.}

## Docs Index (read on demand)

| File | When to read |
|------|--------------|
| `docs/architecture.md` | {when} |
| `docs/conventions.md` | {when} |
| `docs/workflows.md` | {when} |
| `docs/delegation.md` | {when} |
| `docs/eval-criteria.md` | {when} |
| `docs/runbook.md` | {when} |

## Golden Principles

## Delegation

## Working with Existing Code

## Language Policy
```

**What NOT to put in AGENTS.md:** workflow details, delegation details, evaluation criteria, architecture deep dives, API references. These belong in `docs/`.

### Step 4: Create docs/ Knowledge Base

Create these files. Each one is read **on demand**, not loaded every session.

#### `docs/architecture.md`
Project structure, layer rules, module boundaries, dependency directions. Read `references/architecture-template.md` for structure and a concrete example.

#### `docs/conventions.md`
Naming patterns, coding standards, framework-specific rules. Only include conventions that agents frequently get wrong — do not duplicate the linter. Read `references/conventions-template.md` for the template.

#### `docs/workflows.md`
How work gets done. Read `references/workflows-template.md` for the standard six workflows (plan/code/draft/constrain/sweep/explore) and adapt to the project.

#### `docs/delegation.md`
Sub-agent routing table and context manifest. Read `references/delegation-template.md` for the full template including model selection per role.

#### `docs/eval-criteria.md`
Product-level evaluation criteria with the Generator-Evaluator separation principle. Read `references/eval-criteria-template.md` for the template.

#### `docs/runbook.md`
Build, test, deploy commands. Common failure modes and fixes. Environment setup. Read `references/runbook-template.md` for the template.

### Step 5: Set Up Sweep Automation

Copy `scripts/sweep.sh` into the target project's `tools/` directory and adapt the `# ADAPT:` sections. Read `references/sweep-template.md` for ecosystem-specific adaptation guidance.

The sweep script performs five checks: lint scan, doc drift, golden principle violations, harness freshness, and finding report.

### Step 6: Improve Lint for Agent Readability

If the project has linters, improve error messages for agent consumption:

**Before (human-oriented):**
```
ERROR: Line 42 — violation of rule X
```

**After (agent-readable):**
```
ERROR: Line 42 — violation of rule X
  FIX: {what to change and how}
  REF: {which doc or config file explains this rule}
```

Each error message becomes a micro-instruction that tells the agent exactly how to fix the issue.

### Step 7: Build the Enforcement Chain

Build a multi-layer enforcement chain so golden principles are mechanically guaranteed. Read `references/enforcement-template.md` for detailed templates per layer.

**Four layers (defense in depth):**
1. **Real-time hooks** (`.claude/settings.json`) — Catch violations at edit time
2. **Pre-commit checks** — Block commits with unfixed violations
3. **CI gate** — Block merges on failure
4. **PR template** (optional) — Checklist derived from golden principles

Match enforcement depth to team size and risk tolerance. Not every project needs all 4 layers.

**Performance rule for hook scripts:** Hooks fire on every edit, so avoid `echo | grep` inside loops — each call forks a subprocess. Use bash builtin `[[ =~ ]]` (available since bash 3.0) for pattern matching instead. See the "Performance" section in `references/enforcement-template.md` for migration patterns.

### Step 8: Create CLAUDE.md Pointer

Create `CLAUDE.md` in the repo root with a single line:

```markdown
@AGENTS.md
```

This keeps the loading chain clean: Claude loads `CLAUDE.md` -> `AGENTS.md` (the map) -> `docs/` (read on demand).

### Step 9: Validate

Run `scripts/validate-harness.sh` against the target project to verify all artifacts are complete and consistent.

Manual checklist for items the script cannot verify:
- [ ] Golden principles are enforceable (each has a lint rule, test, or hook)
- [ ] Delegation table specifies model per role (haiku/sonnet/opus)
- [ ] Eval criteria are concrete and gradeable (not vague)
- [ ] `docs/` files do not duplicate each other

### Step 10: Explain to the User

After setup, walk the user through what was created. Key points:

- AGENTS.md is the entry point — keep it short, point to docs/
- Run sweep periodically (between features, or automate with CronCreate)
- Update docs/ after implementing features — stale docs are worse than no docs
- Golden principles should evolve — add new ones when new pain points emerge, remove when model capability makes them unnecessary

## Additional Resources

### Reference Files

Detailed templates and guides in `references/`:
- **`references/golden-principles-guide.md`** — Discovery questions, tech-stack examples, principle-to-enforcement mapping
- **`references/architecture-template.md`** — Architecture doc structure with a concrete Next.js example
- **`references/conventions-template.md`** — Naming, code style, framework-specific rules, API and git conventions
- **`references/runbook-template.md`** — Build/test/deploy commands, common failures, environment variables
- **`references/workflows-template.md`** — Six workflows (plan/code/draft/constrain/sweep/explore) with permitted side-effects
- **`references/delegation-template.md`** — 3-tier routing table, context manifests, model selection per role
- **`references/eval-criteria-template.md`** — Grading rubrics, calibration examples, evaluator execution protocol
- **`references/enforcement-template.md`** — 4-layer enforcement chain with CI/hook/pre-commit templates
- **`references/sweep-template.md`** — Ecosystem-specific adaptation guide for the sweep script

### Scripts

Utility scripts in `scripts/`:
- **`scripts/sweep.sh`** — Base sweep script to copy and adapt per project
- **`scripts/validate-harness.sh`** — Validates harness completeness (file existence, AGENTS.md size, reference integrity)

### Examples

Working examples in `examples/`:
- **`examples/agents-md-example.md`** — Complete AGENTS.md for a Next.js SaaS project
