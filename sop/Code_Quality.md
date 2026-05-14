# Code Quality SOP

> For the full development pipeline, see [method.md](../method.md).

**v2.4.3.2** — Last updated: 2026-05-14  *(doc-polish release — stack-agnostic clarification + `/verify` cross-ref)*

**Source of truth:** Your project's CLAUDE.md defines authoritative coding conventions. This SOP provides the day-to-day procedures.

> **Note on stack:** This SOP uses TypeScript/React example commands and naming conventions because that's what most Pipekit consumers ship on, but the underlying principles (strict types where the language supports them, meaningful names, locally-runnable gate, fast feedback) are stack-agnostic. Adapt the specifics — `pnpm turbo run check-types` becomes `cargo check`, `go vet`, `pytest --type`, etc. — to your project's stack. Pipekit itself is stack-agnostic; your `method.config.md § Pre-Deploy Gate` is authoritative for *your* gate.

---

## Pre-Deploy Gate

Every PR must pass all checks before merge. The exact commands are defined in your project's `method.config.md` under "Pre-Deploy Gate". Typical example for a TS monorepo:

```bash
pnpm turbo run check-types   # strict TypeScript (or your stack's type-check)
pnpm turbo run lint           # ESLint (or your stack's linter)
pnpm turbo run test           # Unit + integration tests
```

**Canonical runner:** `/verify` (or `pk verify`) reads `method.config.md § Pre-Deploy Gate` and runs the configured commands locally, returning `Pass / Partial / Fail` with a per-AC table. Run it before `pk ship`. CI runs the same gate on every PR — if `/verify` passes locally and CI fails, that's drift between your local toolchain and CI worth investigating.

---

## Daily Workflow

### Before Opening a PR

Run the full pre-deploy gate locally. Fix all errors before pushing. Warnings should be addressed but won't block.

### After Writing New Code

Run the type checker and linter to catch issues early. Filter to the relevant package for speed.

---

## General Conventions

- **Strict mode** TypeScript everywhere (`strict: true` in tsconfig)
- Named exports only — no default exports
- **kebab-case** for all filenames
- **camelCase** for function names
- **UPPER_SNAKE_CASE** for constants
- **PascalCase** for React components and TypeScript types/interfaces
- Prefix booleans with `is`/`has`/`can`/`should`

---

## Shared Component Structure

If your project uses a shared component library, follow this pattern:

```
packages/ui/src/{kebab-name}/
├── {kebab-name}.tsx           <- Component with TypeScript props interface
├── {kebab-name}.test.tsx      <- Co-located test file
└── index.ts                   <- Barrel export
```

Use `/component` to scaffold new components (if available in your project).

---

## Troubleshooting

### Type errors after pulling changes

Re-run with cache bypass:
```bash
pnpm turbo run check-types --force
```

### Tests failing locally but passing in CI

Ensure you're running from the repo root (not a worktree with stale deps):
```bash
pnpm install
pnpm turbo run test --force
```
