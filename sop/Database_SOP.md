# Database SOP

> For the full development pipeline, see [method.md](../method.md).

**v4.0.0-rc5** — Last updated: 2026-06-20  *(new SOP — the schema-change *artifact* rule: every schema change lands as a tracked, reversible migration; schema-touching specs must carry a Migration Plan. Companion to the immutability rule in `.claude/rules/pipekit-migrations.md`.)*

**Source of truth:** Your project's CLAUDE.md and `method.config.md § Migration dir` define the migration tool and directory. This SOP provides the methodology that applies regardless of tool.

> **Note on stack:** Examples use Supabase (the most common Pipekit consumer DB), but the rules are tool-agnostic. Substitute your project's tool — Prisma `migrate`, Drizzle `kit`, Knex, Alembic, Rails — and the artifact rule holds: schema changes are reversible files tracked in git, applied through the tool, never hand-edited into a schema dump.

---

## The One Rule

**Every schema change lands as a migration file.** Not a direct `ALTER TABLE` against a live DB. Not a hand-edit of a committed schema dump. Not an MCP `apply_migration` call that races the disk chain (see `pipekit-migrations.md`). The change is authored as a reversible migration, tracked in git, and applied through the project's migration tool.

This is the **artifact** rule. Its sibling — once a migration is applied to *any* environment, the file is **frozen** (no rename, no edit, no delete) — is the **immutability** rule, and lives in `.claude/rules/pipekit-migrations.md`. This SOP is upstream of that: it governs how a schema change is born; the rule governs what happens to it after. Read both.

### The AI still does all the work

The point of this rule is **not** "the AI stays away from the schema." Pipekit consumers explicitly want the AI to do all database work, including writing SQL. The rule changes only the **artifact**, not the workload:

- The AI designs the schema change. ✅
- The AI writes the DDL. ✅
- The AI tests it against a local/branch DB. ✅
- The artifact it produces is a **migration file**, not a live `ALTER` or a schema-dump edit. ✅

If a session catches itself thinking *"I'll just run this one `ALTER` against dev to test the idea, then write the migration"* — that's the exact path that produces invisible schema drift (the history table has no record of the ad-hoc change). Author the migration first; apply it through the tool. The "test it live first" instinct is covered by the **MCP-applied migrations and disk drift** section of `pipekit-migrations.md` — the sanctioned way to preview a migration against a live env is `supabase db push` against a per-PR branch DB or a local reset, which uses the disk filename verbatim.

---

## The Migration Plan (spec contract)

A spec that touches schema is not planning-ready until it carries a **Migration Plan**. This is the artifact rule's enforcement point: the plan is where the spec commits to *which* migration(s) will be authored, so the planner and executor never have to guess whether a schema change is in scope or how it's reverted.

A Migration Plan must answer six questions. Anything unanswerable at spec time is a `[TBD]` that **blocks planning** if it would force the planner to guess a task boundary.

| # | Question | Why it's load-bearing |
|---|----------|----------------------|
| 1 | **What schema objects change?** Tables, columns, types, constraints, indexes, RLS policies, functions, triggers. | Defines the migration's surface and the regression-watch set. |
| 2 | **Which migration tool + dir?** Read from `method.config.md § Migration dir`. | The planner emits the migration to the right place with the right tool. |
| 3 | **Forward DDL intent.** What the migration asserts (in outcome terms, not literal SQL — the planner owns the HOW). | Confirms the change is expressible as forward DDL, not a manual step. |
| 4 | **Rollback intent.** How the change is undone — a reverting migration's DDL, or "irreversible, data-loss on revert" stated explicitly. | A migration with no reasoned rollback is a one-way door shipped silently. |
| 5 | **Data backfill / migration.** Does existing data need transforming, defaulting, or backfilling? Nullable-vs-NOT-NULL, default values, sentinel rows. | The silent-failure patterns in `pipekit-migrations.md` (nullable FKs, stale DEFAULTs, auto-create triggers) live here. |
| 6 | **Authorization impact.** New tables/columns: what RLS policy, GRANT, or access rule applies? Default is deny. | Per `pipekit-security.md` — every data-access path has auth at the point of query. A new table with no policy is a leak. |

A Migration Plan is **conditional**: specs that touch no schema omit it entirely (and the Spec Review Agent does not demand it). The trigger is "does this spec change the shape of the database?" — if yes, the plan is mandatory; if no, it's absent.

---

## Per-tool interface

The artifact rule is the same everywhere; the command surface differs. Read `method.config.md § Migration dir` and the project's lockfile to identify the tool, then:

| Tool | Create | Apply (local/branch) | Never do |
|------|--------|----------------------|----------|
| **Supabase** | `supabase migration new <name>` | `supabase db push` (branch DB) / `supabase db reset` (local) | `mcp.apply_migration` for code that also lives on disk; ad-hoc SQL editor DDL on a shared env |
| **Prisma** | `prisma migrate dev --name <name>` | `prisma migrate dev` (local) / `migrate deploy` (CI) | `prisma db push` to prod (skips the migration history) |
| **Drizzle** | `drizzle-kit generate` | `drizzle-kit migrate` | hand-editing `schema.ts` and calling `push` against prod with no generated migration |
| **Knex / Alembic / Rails** | `knex migrate:make` / `alembic revision` / `rails g migration` | the tool's `migrate` / `upgrade` | editing an applied migration in place |

In all cases: the **migration file is the artifact that ships in the PR**. Applying it to a live env happens through the tool (locally or in CI), never by pasting DDL into a console against a shared DB.

---

## How this is enforced

The artifact rule is enforced at three points in the pipeline, so a schema change can't slip through as an ad-hoc edit:

1. **Spec time** — `/light-spec` requires the Migration Plan section on any schema-touching spec (skill Phase 3.7). The **Spec Review Agent** (`templates/spec_review_skill.md` § Migration Rule) raises a **Blocking** issue if a schema-touching spec lacks a concrete plan. A spec without it does not reach Pass.
2. **Verify time** — `/verify` spawns a migration-review subagent when the diff touches `Migration dir`, applying the `/pr-security-review` M1–M8 rubric (+ RLS / SECURITY DEFINER / GRANT). The flag carries a **Hold/Approve verdict**, not a raw diff. A Hold pauses auto-ship.
3. **Review time** — `/pr-security-review` is the right tool for migrations, RLS, SECURITY DEFINER, GRANT/REVOKE, and auth surface. Use it on any PR whose Migration Plan touched policies or privileged tables.

The **immutability** invariant (frozen-file, hardening-during-review, parallel-branch coordination, MCP disk-drift, the three silent-failure patterns) is enforced by `.claude/rules/pipekit-migrations.md`, which auto-loads into every session. This SOP and that rule are complementary: the SOP is the *birth* of a migration (author it, plan it, apply it through the tool); the rule is its *life after apply* (it's frozen — fix forward, never edit back).

---

## Quick reference

- **Schema change?** → migration file. Always. The AI writes it; only the artifact is constrained.
- **Spec touches schema?** → Migration Plan section is mandatory (6 questions). No plan, no Pass.
- **Want to test a migration live before merge?** → `supabase db push` against a branch DB or a local reset — never `mcp.apply_migration` for on-disk code, never ad-hoc SQL on a shared env.
- **Migration already applied somewhere?** → it's frozen. Fix forward with a new migration. See `pipekit-migrations.md`.
- **New table or column?** → it needs an explicit RLS policy / GRANT. Default deny. See `pipekit-security.md`.
