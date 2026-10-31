# Rules SOP

**v5.2.0** — Last updated: 2026-10-24  *(**v5.2.0 — new:** how `.claude/rules/` works, how to write a rule, the word budget, and the incidents behind the canonical rules.)*

## The model

```
CLAUDE.md            — project hub + routing pointers
  .claude/rules/*    — auto-loaded enforceable constraints, one topic per file
  pipekit/sop/*      — demand-loaded reference (walkthroughs, templates, anchors)
```

Every file in `.claude/rules/` loads into every session, and every line is paid for on every turn — and competes for attention with the rule that matters right now. So rules carry the rule and nothing else.

**What goes in rules/:** enforceable must / must-not constraints, invariants true across every feature, cross-cutting conventions (naming, structure, package manager, auth flow), and counter-intuitive API pitfalls that have caused regressions.

**What doesn't:** feature docs (SOPs or inline), history and decision logs (`pipekit/decisions/` ADRs), tutorials (SOPs), and the incident that earned a rule (§ Anchors below, or the project's own SOP).

**Scope a rule to files when you can.** A rule only relevant to some paths takes `paths:` frontmatter and loads only when matching files are touched — e.g. a database rule on `supabase/**`.

## Canonical rules

| File | Topic |
|------|-------|
| `pipekit-discipline.md` | Red Flags, Plan Gate, scope hygiene, completion claims, commit format |
| `pipekit-tooling.md` | Verify installed APIs, enumerate the surface, checks that can see the failure, MCP payloads |
| `pipekit-security.md` | Secrets, secrets managers, boundary validation, explicit authorization |
| `pipekit-migrations.md` | Frozen-file invariant, branch coordination, MCP drift, silent-failure patterns |
| `pipekit-cmux.md` | Identify before split, CLI not RPC, read-screen verify, track by PID |
| `README.md` | What the model must know about the directory itself |

`scripts/sync-method.sh` writes these on every run, so local edits to them are overwritten. To change a canonical rule for one project, write a companion file (`security.md` beside `pipekit-security.md`) and order it in CLAUDE.md's routing pointers. To drop a rule that doesn't apply, set `Skip rules: pipekit-cmux, pipekit-migrations` in `method.config.md`; the next sync removes the files, and clearing the key restores them. `README.md` is not skippable.

## Writing a rule

- **Earn it.** A rule exists because a session made the mistake, ideally more than once — not because it might.
- **One in, one out.** The canonical rules have a word budget, enforced by `tests/pk-smoke.sh` (`RULES_WORD_BUDGET`). A new rule that would breach it displaces or tightens an old one; raising the budget is a decision, not a side effect.
- **Rule inline, incident here.** Write the rule as an instruction. Put the anchor (ID, date, what happened) under § Anchors with the rule's heading, so the rule can't be argued away from memory of why it exists and doesn't cost tokens every turn.
- **Generalize project-specific lessons.** A canonical rule loads into every consumer: state the general rule, and keep the vendor-specific example in the anchor.
- **Keep headings stable.** Skills and SOPs cite rules as `pipekit-x.md § Heading`; renaming one breaks those pointers.

## Anchors

The incident that earned each canonical rule, read on demand: when a rule seems not to apply to your case, read its anchor before deciding it doesn't. If an anchor no longer describes reality, change the rule in Pipekit — don't route around it.

Sections mirror the rule files and their headings. Migration narratives live in `Database_SOP.md` (§ Silent-Failure Patterns, § MCP-applied migrations).

### pipekit-tooling.md

#### § Verify Library API Before Use — the target-arg-ignored class

`cmux rpc surface.send_text`, 2026-05-17 — routed input to the focused surface regardless of its `--surface` arg, echoed success, ~1h lost to "why is the wrong thing running" (full anatomy: `pipekit-cmux.md` § Use the CLI, not the RPC).

Version drift: Next.js 14 → 15 alone broke `cookies()`, `headers()`, `draftMode()` type signatures. Supabase JS v2 renamed half its surface.

#### § Enumerate the Surface Before Claiming Behavior

A consumer project, 2026-05 — a session advised "dev-merge doesn't auto-trigger the supabase workflow" knowing about ONE workflow, without `ls .github/workflows/`; a second workflow (`supabase-dev.yml`) DID fire on dev-merge and applied the migration. Correct about the file it knew, wrong about the surface.

The failure is structural to how AI sessions browse the filesystem — they grep for a known string and stop.

#### § The Verification Method Must Be Able to See the Failure

- **Wrapped lines.** A consumer project, 2026-07 — two facts restated across several files survived multiple "fixed everywhere" commits because the pattern only matched the single-line instances.
- **Agent auto-detection.** The Supabase CLI's global `--agent` flag defaults to `auto` (verified against installed CLI, `supabase migration list --help`: "Override agent detection: yes, no, or auto (default auto)"). A consumer project, 2026-07 — `scripts/local-dev/reset-db.sh` piped bare `supabase migration list` into `JSON.parse` without pinning `--agent`, so it worked from inside Claude Code but reported a false failure when a human ran it in a terminal. Fix: `--agent no` (or `--output-format` explicitly).
- **Green because it ran.** A consumer project, 2026-08 — `anthropics/claude-code-action` refuses to run when the workflow file differs from the default branch's copy (a guard against a PR editing its own reviewer); on a PR that touched the workflow it logged "Action skipped due to workflow validation error", exited 0, and the `claude-review` check went green in 20s having reviewed nothing.
- **Predictions.** The same consumer project, 2026-08 — `pk ready` printed "PR reviewers will now fire: Claude Code Review, Semgrep" on every PR, because its probe scanned `.github/workflows/` for a `ready_for_review` trigger but ignored each workflow's `branches:` filter; on a `feature/* → dev` PR the named reviewer could never fire. This was the *second* recurrence of the same over-claim in that one message — the probe existed only because a hardcoded string had previously named a reviewer the repo did not have (another consumer, 2026-07).

#### § And ask the converse: can this check *cheat*?

Pipekit, 2026-08-02 — a blind-review trial checked out two PRs at their head commits in worktrees; the reviewer read the follow-up fix PRs and cited them ("the later PROJ-554 migration confirms both defects") at confidence 100. Real isolation needs a separate clone with all refs deleted except the pinned commits, reflogs expired, and `gc --prune=now`.

#### § MCP Server Configuration

`pk branch` creates a git worktree per issue. A worktree checks out tracked files, so a server in committed `.mcp.json` is visible inside it; a server in the per-path block of `~/.claude.json` is keyed to the main repo path and is invisible in every worktree — which is exactly where `/work` runs. The failure is silent: the tool simply isn't there.

#### § MCP Result Payloads Are Sticky

A routine day's Linear work (create an initiative + a handful of projects + a dozen issues, then draft and agent-review a spec) left the `linear-server` MCP holding **~17%** of the session budget, matching the documented ~18% `supabase` pattern. The work was correct; the cost was the payloads persisting, not the calls. `linear_getIssueById` returns the full description plus the entire comment thread (postmortems, UAT rounds, review blocks — often a dozen comments); called just to learn an issue's state it can spend several percent of the budget and stay resident for the rest of the session. `linear_createIssue` / `linear_updateIssue` echo the full description back, so a spec-length body is paid for twice.

### pipekit-cmux.md

#### § Use the CLI, not the RPC, for input

`cmux rpc surface.send_text` fired a load-test run into a different Claude session in another workspace — ~1 hour debugging "why is the wrong thing running" before the routing bug was identified. It ignores its `surface` parameter, routes to the focused surface, and echoes the focused surface's id so the call looks successful.

### pipekit-migrations.md

#### § Parallel Branch Coordination — re-check before merge

A consumer project, 2026-06 — a same-day migration merged to `dev` mid-session collided on merge after passing all local checks.

#### § MCP-applied migrations and disk drift

A consumer project, 2026-05 — an MCP-applied RPC stamped `<project>-dev`'s history at wall-clock while the disk file shipped with a different timestamp; ~5h of deploy lockup across every in-flight migration PR; reconciled by PR #393 backfilling the disk file at the MCP-stamped version. Full anatomy and recovery: `Database_SOP.md` § MCP-applied migrations.

### pipekit-discipline.md

#### § Commit discipline

A subject that slips past both the PreToolUse hook and `pk ship` onto a protected branch is permanent, since squash is off.

### pipekit-security.md

#### § Secrets Managers and Worktrees

Reference pattern: 1Password for Developers, proven on two consumer projects.
