# Claude Code Rules

Files in this directory are **auto-loaded into every Claude Code session** via the `.claude/rules/` convention. Keep rules short and load-bearing — every line costs input tokens on every turn.

## Hub-and-spoke model

```
CLAUDE.md            — project hub + routing pointers (~200 lines)
  .claude/rules/*    — auto-loaded enforceable constraints (per-topic files)
  pipekit/sop/*       — demand-loaded deep reference (SQL templates, walkthroughs)
```

CLAUDE.md points to rules for "how do I build correctly here?" Rules point to SOPs for "how do I do this specific complex thing?"

## What goes in rules/

- **Enforceable constraints** — "must / must not" guidance the AI should refuse to violate
- **Invariants** — things true across every feature (e.g., "RLS enabled on every table")
- **Cross-cutting patterns** — naming, file structure, package manager, auth flow
- **Domain pitfalls** — counter-intuitive API behaviors that have caused regressions

## What does NOT go in rules/

- Feature-specific documentation — that's SOPs or inline docs
- Historical context or decision logs — that's `pipekit/decisions/` ADRs
- Tutorial-style guides — that's SOPs
- Anything longer than ~100 lines — split by topic

## Canonical rules shipped by Pipekit

Canonical files use a `pipekit-` prefix so they never collide with project-specific rule filenames.

| File | Topic | Portable |
|------|-------|----------|
| `pipekit-discipline.md` | AI coding discipline: Red Flags, Ad-hoc Plan Gate, scope hygiene | ✅ |
| `pipekit-tooling.md` | Verify installed library APIs, pin package manager, pre-deploy gate | ✅ |
| `pipekit-security.md` | Secrets, boundary validation, OWASP, auth must be explicit | ✅ |
| `pipekit-migrations.md` | Frozen-file invariant, hardening discipline, parallel-branch coordination, drift recovery | ✅ |
| `pipekit-cmux.md` | cmux discipline: identify-before-split, send-not-rpc, read-screen verify, track by PID | ✅ |

These are synced by `scripts/sync-method.sh` from Pipekit on every run. Changes must round-trip through pipekit — local edits to `pipekit-*.md` files will be overwritten on next sync. If you need to override a canonical rule, create a companion file (e.g., `security.md`) whose content takes precedence per your CLAUDE.md Routing Pointers ordering.

## Adding project-specific rules

Create new files directly in this directory — `sync-method.sh` won't touch anything outside the six canonical names above. Common project-specific patterns:

- `security.md` — project-specific auth, RLS, secrets; sits alongside `pipekit-security.md` baseline
- `tooling.md` — project-specific commands, monorepo filters, pre-deploy gate; sits alongside `pipekit-tooling.md` baseline
- `patterns.md` — data-layer patterns, component conventions, state management
- `naming.md` — file and code naming conventions
- `file-structure.md` — directory layout, import alias rules
- `{library}-pitfalls.md` — counter-intuitive API behaviors (e.g., `ag-grid-pitfalls.md`, `react-query-pitfalls.md`)

Reference CLAUDE.md's routing table so both canonical and project-specific rules are discoverable.
