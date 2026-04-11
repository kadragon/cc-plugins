# TaskFlow Agent Rules

A Next.js 14 SaaS task management app with PostgreSQL, Prisma ORM, and Tailwind CSS.

## Docs Index (read on demand)

| File | When to read |
|------|--------------|
| `docs/architecture.md` | Before modifying source structure or adding new modules |
| `docs/conventions.md` | Before writing new components, API routes, or DB queries |
| `docs/workflows.md` | When starting any implementation cycle |
| `docs/delegation.md` | Before delegating to sub-agents |
| `docs/eval-criteria.md` | When evaluating completed features |
| `docs/runbook.md` | For build, test, deploy commands and troubleshooting |

## Golden Principles

Invariants enforced mechanically. Violations block commits.

1. **No raw Prisma outside `lib/db/`** — All database access goes through typed query functions. Enforced by ESLint `no-restricted-imports` rule.
2. **Input validation at API boundary** — Every API route and server action validates input with Zod schemas from `lib/validators/`. Enforced by custom ESLint rule.
3. **No `any` type** — TypeScript strict mode with `noImplicitAny`. Enforced by `tsconfig.json` + CI type check.
4. **Server components by default** — `"use client"` only when the component needs browser APIs or event handlers. Enforced by PR review checklist.
5. **Audit fields on all mutations** — Every INSERT/UPDATE includes `createdAt`/`updatedAt` via Prisma middleware. Enforced by Prisma middleware (automatic).

## Delegation

Read `docs/delegation.md` for full routing table. Summary:

| Trigger | Delegate |
|---------|----------|
| Every commit | Code reviewer (background, sonnet) |
| Before unfamiliar module | Explore agent (blocking, sonnet) |
| After implementation | QA verification (blocking, sonnet) |
| Feature complete | Product evaluator (blocking, opus) |
| Same failure x2 | Deep investigation (blocking, opus) |

## Working with Existing Code

- Components in `src/components/ui/` are shadcn/ui primitives — modify via `npx shadcn-ui add`, never edit directly
- Database schema changes require a Prisma migration (`npx prisma migrate dev --name {desc}`)
- Server actions live alongside their page in `app/`, not in a shared actions file
- Test with `npm test` before every commit; integration tests need `DATABASE_URL` pointing to test DB
- Styling uses Tailwind utility classes only — no CSS modules, no styled-components

## Language Policy

- Code, commits, docs: English
- User-facing strings: i18n via `next-intl` (English + Korean)
