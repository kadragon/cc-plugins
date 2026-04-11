# Delegation Template

The orchestrator plans, routes, and verifies. It does NOT do the heavy lifting itself.

## Routing Table Structure

Organize into three tiers:

### Mandatory Gates (blocking)

Tasks that must complete before the workflow can proceed. These are **hard stops**, not suggestions — skipping a mandatory gate is a golden principle violation.

**Critical: All triggers must be objective and measurable.** Never use subjective conditions like "unfamiliar module" or "complex change" — agents systematically overestimate their own understanding and will rationalize skipping delegation every time. See `references/golden-principles-guide.md` → "Delegation Discipline" for why.

```markdown
| Trigger (objective) | Delegate to | Context to pass |
|---------------------|-------------|-----------------|
| Target module has >N files or >M LOC | Analysis agent | Module path, related docs |
| Change touches ≥3 directories | Architecture analysis agent | Changed paths, architecture.md |
| First edit in directory this session | Explore agent | Directory path, architecture.md |
| File matches critical path pattern (auth/billing/migration) | Analysis agent | File path, golden principles |
| Implementation task from backlog | Implementation agent | Spec, conventions, reference files |
| After implementation (always) | QA/verification agent | Modified files list, conventions |
| Feature complete | Product evaluator | Done-when criteria, eval-criteria.md |
```

**Adapting thresholds:** The `>N files` and `>M LOC` values depend on the project. For a small repo, N=3/M=200 might be right. For a monorepo, N=8/M=1000. Choose values that capture "this is a non-trivial module" for your specific codebase, and write them as concrete numbers in the routing table.

### Background Gates (non-blocking)

Fire-and-forget tasks that improve quality but don't block progress.

```markdown
| Trigger | Delegate to | Context to pass |
|---------|-------------|-----------------|
| Every commit | Code reviewer (background) | Commit hash, changed files |
| Periodic | Sweep agent (background) | tasks.md path |
```

### Escalation

When the orchestrator gets stuck.

```markdown
| Trigger | Delegate to |
|---------|-------------|
| Same failure x2 | Deep investigation agent (blocking) |
| Large refactor needed | Refactor agent (background) |
| Design decision needed | Design exploration agent (blocking) |
```

## Context Manifest

For each delegation target, specify exactly what context it needs. Pass via **file paths**, not inline content. This is critical — sub-agents start with zero context.

### Template per Agent

```markdown
### {Agent Name}

**Purpose:** {one sentence}

**Required context:**
- `{file path}` — {why this file is needed}
- `{file path}` — {why}
- {any other inputs}

**Expected output:** {what the agent should produce}
```

## Choosing Delegation Targets

Map these to the tools available in your environment:

| Need | Claude Code option | Alternative |
|------|-------------------|-------------|
| Code analysis | `Explore` subagent, custom analyzer | Inline analysis by orchestrator |
| Implementation | `general-purpose` subagent | Orchestrator implements directly |
| QA verification | Custom QA subagent | Lint + manual review |
| Code review | `code-reviewer` subagent, `/codex:review` | `pr-review-toolkit:code-reviewer` |
| Deep debugging | `/codex:rescue`, `general-purpose` subagent | Orchestrator debugs directly |
| Product evaluation | Custom evaluator with Playwright MCP | Manual testing + review |

For projects without specialized sub-agents, the `general-purpose` Agent subagent with a well-crafted prompt is sufficient. The key is separation of concerns — the agent that generates should not be the agent that evaluates.

## Model Selection per Role

Not all sub-agent tasks need the most powerful (and expensive) model. Match the model to the cognitive complexity of the task:

| Role | Recommended Model | Reasoning |
|------|------------------|-----------|
| **Structural grading** (file exists? line count?) | `haiku` | Mechanical checks, no judgment needed |
| **Code review** (bugs, style) | `sonnet` | Solid reasoning at lower cost, good for pattern matching |
| **Implementation** (write code) | `sonnet` | Standard coding tasks, follows patterns well |
| **Codebase exploration** | `sonnet` | Searching and reading, summarizing findings |
| **Architecture analysis** | `opus` | Complex multi-file reasoning, design tradeoffs |
| **Product evaluation** | `opus` | Subjective judgment, skeptical assessment, calibration needed |
| **Deep debugging** (2nd attempt) | `opus` | Root cause analysis after simpler approaches failed |
| **Sweep / garbage collection** | `haiku` or `sonnet` | Mostly grep + pattern matching, light judgment |

**Rules of thumb:**
- If the task is **checking known criteria**, use `haiku` — it's fast and cheap.
- If the task is **following instructions to produce output**, use `sonnet` — good balance of quality and cost.
- If the task requires **judgment, creativity, or multi-step reasoning**, use `opus` — worth the cost for high-stakes decisions.
- When in doubt, start with `sonnet` and escalate to `opus` only if quality is insufficient.

In Claude Code, specify the model when spawning a sub-agent:
```
Agent({
  description: "...",
  prompt: "...",
  model: "sonnet"  // or "haiku", "opus"
})
```

## Objective Trigger Design

When writing triggers for the routing table, follow these rules:

1. **Countable over judgmental** — "≥3 directories" not "large change"
2. **Path-based over knowledge-based** — "file in `src/auth/`" not "security-related code"
3. **Session-scoped over lifetime-scoped** — "first edit in this directory this session" not "haven't worked here before"
4. **Threshold-based over binary** — Set concrete numbers (LOC, file count, directory count) rather than yes/no assessments

**Anti-patterns to reject during harness init:**

| Anti-pattern | Why it fails | Replace with |
|---|---|---|
| "unfamiliar module" | Agent always thinks it knows enough | "first edit in directory this session" or ">N files in module" |
| "complex change" | Agent underestimates complexity | "touches ≥3 directories" or ">M lines changed" |
| "if unsure" | Agent is rarely unsure | Remove self-assessment; use objective proxy |
| "significant refactor" | Subjective threshold | ">N files modified in one commit" |

## Workflow → Delegation Mapping

These delegations are **embedded as named steps in `docs/workflows.md`**, not just cross-referenced. The workflow itself enforces delegation — an agent following the `code` workflow cannot skip these steps because they are the workflow.

```markdown
| Workflow | Step | Delegate | Gate type |
|----------|------|----------|-----------|
| `code` | Step 1: Scope check | Analysis agent (if objective trigger met) | Mandatory |
| `code` | Step 3: Implementation | Implementation agent (or orchestrator for ≤2 files) | Conditional |
| `code` | Step 4: Post-implementation | QA agent | Mandatory (always) |
| `code` | Step 5: Feature complete | Product evaluator | Mandatory (always) |
| `plan` | Domain research | Analysis agent | Optional |
| `draft` | Context gathering | Analysis agent | Optional |
| `sweep` | Large scan | Sweep agent (background) | Background |
```

## Applying Sub-Agent Output

- **Structural fix** (typo, missing import) → apply in current cycle.
- **Behavioral change** (new feature, changed logic) → add to `backlog.md`. Never apply directly.
- **Contradicts design doc** → report both options to user. Do not choose.
