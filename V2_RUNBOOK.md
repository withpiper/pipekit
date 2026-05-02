# Pipekit v2 — Runbook (alpha.12+)

> **North star:** safe and frictionless. Helps, never adds work.

The v2 daily loop on one page. Read top-to-bottom. Coexists with v1 — v1 commands still work, choose whichever you trust.

---

## One-time setup (per consuming project)

```
1. ./scripts/sync-method.sh v2.0.0-alpha.12       (or latest tag)
2. Append "## V2" config block to method.config.md (see V2.md § examples)
3. Add LINEAR_API_KEY=lin_api_xxx to .env.local    (gitignored, project-local)
4. Wire Stop hook into .claude/settings.json       (paste from method/templates/v2/)
5. ./bin/pk init     →  ./bin/pk doctor            (expect all green)
```

---

## Per-issue flowchart

```
┌─────────────────────────────────────────────────────────────────┐
│  PARENT REPO       cwd: ~/Projects/<repo>     branch: dev       │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [1] Find next issue                                      │
  │     ./bin/pk next                                        │
  │     • reads Linear (Approved, prio desc) + git state     │
  │     • prints next issue + suggested command              │
  │     • optional: ./bin/pk status   (full board view)      │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [2] Branch + worktree                                    │
  │     ./bin/pk branch <ID>                                 │
  │     • creates feature/<ID>-<3-word-slug>                 │
  │     • worktree at .worktrees/<ID>-<slug>                 │
  │     • symlinks .env / .env.local / .mcp.json             │
  │     • copies parent's bin/pk into worktree (alpha.12+)   │
  │     • Linear: Approved → In Progress                     │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       cd .worktrees/<ID>-<slug>
       claude --dangerously-skip-permissions
       │
┌──────┴──────────────────────────────────────────────────────────┐
│  WORKTREE       cwd: .worktrees/<ID>-<slug>     branch: feature │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [3] Plan + execute                                       │
  │     /work <ID>            (or /work <ID> --deep)         │
  │     • reads spec from Linear                             │
  │     • plans (one-screen)                                 │
  │     • verdict: proceed | revise: <feedback> | abort      │
  │     • dispatches dev (vbw or native per config)          │
  │     • atomic commits, gate-aware                         │
  │     • --deep adds spec-validator + plan-review +         │
  │       security-review subagents                          │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [4] Verify                                               │
  │     /verify         (or ./bin/pk verify)                 │
  │     • runs § Pre-Deploy Gate from method.config.md       │
  │     • if Require QA review=true: spawns QA subagent      │
  │     • returns Pass / Partial / Fail with per-AC table    │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [5] Ship   (still in worktree, still on feature branch)  │
  │     ./bin/pk ship           (or --env=<env>)             │
  │     • push (idempotent)                                  │
  │     • gh pr create against integration branch            │
  │     • Linear: Building → UAT (or → In Review)            │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [5b] Antagonistic PR review  (RECOMMENDED — opt-in)      │
  │      ./bin/pk ship --review     OR                       │
  │      Invoke pr-review-toolkit:code-reviewer manually     │
  │                                                          │
  │      • Spawns reviewer subagent against the diff         │
  │      • Rubric: auth correctness, brand hygiene, test     │
  │        coverage gaps, prod-posture invariants,           │
  │        unspec'd-but-needed cross-cutting concerns        │
  │      • Posts findings as PR review comment via gh REST   │
  │      • Severity-ranked: Critical / High / Medium / Low   │
  │                                                          │
  │      Why: catches things /work and /verify don't —       │
  │      they validate spec adherence, the reviewer plays    │
  │      devil's advocate. RS-60 ship found 1 critical +     │
  │      3 high real issues this way. Don't skip on          │
  │      anything auth/security/financial.                   │
  │                                                          │
  │      alpha.12 status: --review prints the invocation     │
  │      template; you copy-run it. alpha.13 will auto-      │
  │      dispatch the subagent and post directly.            │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [6] Merge PR (manual, GitHub UI)                         │
  │     • feature → dev: merge-commit (history visibility)   │
  │     • feature → main: squash (single commit per release) │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       (Stop hook auto-writes journal entry on session close)
       │
       exit                       (leave Claude in worktree)
       cd ~/Projects/<repo>       (back to parent repo)
       claude --dangerously-skip-permissions
       │
┌──────┴──────────────────────────────────────────────────────────┐
│  PARENT REPO       cwd: ~/Projects/<repo>     branch: dev       │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [7] Cleanup                                              │
  │     ./bin/pk done <ID>                                   │
  │     • verifies PR merged                                 │
  │     • posts journal highlights to Linear                 │
  │     • Linear: UAT → Done                                 │
  │     • removes worktree, deletes local branch             │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       ◇ accumulated 1-3 dev merges?
              │
       No  ───┼───→  loop to [1]
              │
       Yes ───┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [8] Promote dev → main      (separate, batched)          │
  │     ./bin/pk promote                                     │
  │     • only runs if Promote to main: true in config       │
  │     • git pull dev, run pre-deploy gate                  │
  │     • opens dev → main PR (squash-merge per ruleset)     │
  └──────────────────────────────────────────────────────────┘
```

---

## Command cheat sheet

| # | Step | Command | Where | Auth |
|---|---|---|---|---|
| 1 | Find next | `./bin/pk next` | parent, dev | reads Linear |
| 1 | Quick status | `./bin/pk status` | parent | reads Linear |
| 2 | Branch | `./bin/pk branch <ID>` | parent, dev | writes Linear (In Progress) |
| 3 | Plan + execute | `/work <ID>` | worktree | reads Linear |
| 3 | (Variant) | `/work <ID> --deep` | worktree | reads Linear; spawns 3 grounding agents |
| 4 | Verify | `/verify` or `./bin/pk verify` | worktree | local-only |
| 5 | Ship | `./bin/pk ship` | worktree | push + gh pr create + writes Linear (UAT) |
| 5 | (Variant) | `./bin/pk ship --env=<env>` | worktree | + targets specific environment |
| **5b** | **Antagonistic review** | **`./bin/pk ship --review`** | **worktree** | **spawns code-reviewer agent → posts findings to PR** |
| 7 | Cleanup | `./bin/pk done <ID>` | parent, dev | writes Linear (Done) + removes worktree |
| 8 | Promote | `./bin/pk promote` | parent, dev | dev → main batch |
| meta | Diagnose | `./bin/pk doctor` | anywhere | config + API ping |
| meta | Bootstrap | `./bin/pk init` | repo root | walks setup |
| meta | View journal | `./bin/pk log` | worktree, feature | local-only |
| meta | Linear Agent | `./bin/pk delegate <ID> <prompt>` | anywhere | posts @Linear-mentioned comment |
| meta | Help | `./bin/pk help` | anywhere | — |

---

## Configuration (`method.config.md` § V2)

| Key | Values | Default | Used by |
|---|---|---|---|
| **Backend** | `vbw` \| `native` | `vbw` | `/work` agent dispatch |
| **Integration branch** | `dev` \| `main` | derived from § Git Architecture | `pk ship` PR base |
| **Promote to main** | `true` \| `false` | `true` if integration is `dev` | `pk promote` enabled |
| **Require QA review** | `true` \| `false` | `false` | `/verify` runs QA subagent |
| **Default deep flag** | `true` \| `false` | `false` | `/work` always uses `--deep` |
| **Ship environments** | comma list | `dev,main` | `pk ship --env=<name>` |
| **Linear API key env var** | name | `LINEAR_API_KEY` | `pk` Linear access |
| **Journal in repo** | `true` \| `false` | `true` | Stop-hook journal location |

Secret resolution priority (alpha.9+): **`.env.local` > `.env` > process env**.

---

## Antagonistic PR review (the third gate)

The v2 pipeline has three gates, only the first two are mandatory:

| Gate | What it catches | When |
|---|---|---|
| `/work` plan-verdict | Spec ambiguity, missing AC coverage, scope mismatch | Before any code is written |
| `/verify` (gate + QA) | Build/lint/type errors, AC traceability, omissions, scope creep | After code is written, before push |
| **`pk ship --review`** | **Cross-cutting concerns NOT in the spec** — auth posture, security headers, brand hygiene, test rot, double-click races, race conditions, things-the-spec-didn't-think-to-mention | **After PR opens, before merge** |

The first two validate **spec adherence**. The third plays **devil's advocate** — finds what the spec didn't ask but should have.

### When to use `--review`

Always opt in for:
- Anything touching auth, RLS, sessions, OAuth
- Financial logic (math, FX, tax, invoicing)
- New external API integrations
- Security headers / CSP changes
- Anything labeled `auth-rls`, `payments`, `pii`, `compliance`, `breaking-change`

Skip for:
- Pure copy/UI tweaks
- Internal-only refactors with no external surface

### Manual invocation (still required as of alpha.13 — auto-dispatch deferred to alpha.14)

If `pk ship --review` doesn't dispatch automatically, invoke directly:

```
Invoke `pr-review-toolkit:code-reviewer` agent on PR #<N> with antagonistic
rubric. Cite file:line for findings. Group by severity. Post review via:
  gh api -X POST repos/<owner>/<repo>/pulls/<N>/reviews \
    -f event=COMMENT -f body="<full markdown>"
```

### What it found tonight (RS-60 → PR #82)

- **Critical:** `enable_signup=false` documented but not boot-enforced
- **High:** e2e tests not in pre-deploy gate (will rot)
- **High:** `validateRedirectTo` zero e2e coverage for open-redirect attacks
- **High:** Server Action double-click race creates orphan PKCE codes

All four became RS-61 — none would have been caught by `/work` or `/verify` alone.

---

## Recovery (one rule)

**Rerun the command.** Every `pk *` is idempotent against Linear+git ground truth.

| Failure | Behavior |
|---|---|
| `pk branch` mid-failure | Rerun. Worktree exists? skip. Linear correct? skip. |
| `/work` interrupted during plan | Rerun. Plan committed? skip to dev. |
| `pk ship` after PR opens but Linear didn't transition | Rerun. PR exists? skip create, transition only. |
| `pk done` before merge | Refuses with "PR not merged yet." Merge first, retry. |
| `pk done` from inside worktree | Refuses. `exit && cd ~/Projects/<repo> && claude` then retry with `<ID>` arg. |
| Stop hook fails | Best-effort — never blocks the session. Manual `pk log` works regardless. |
| `gh pr view` returns empty / `pk ship` says "no PR" wrongly | GraphQL rate-limited. Alpha.13 added REST fallback in `pk_gh_pr_view` / `pk_gh_pr_create` — rerun. Confirm with `gh api rate_limit --jq '.resources.graphql.remaining'`. |
| Old VBW hook errors after `/plugin update vbw` | Plugin upgrades within a Claude Code session leave stale in-memory script paths. The disk cache is correct; the running session isn't. Restart Claude Code in the parent **and any active worktrees**. Errors are typically benign noise — restart at convenience, not mid-flow. |

If a `pk *` rerun doesn't resolve in one cycle, fall back to v1 (`/branch --linear`, `/launch --auto`, `/end-session`). Capture the failure and we patch in next alpha.

---

## Coexistence with v1

| Step | v1 | v2 |
|---|---|---|
| Find next | `cat NEXT.md` | `pk next` |
| Status | `/linear-status` | `pk status` |
| Branch | `/branch --linear <ID>` | `pk branch <ID>` |
| Session start | `/start-session` | (none — Stop hook handles paperwork) |
| Plan + work | `/launch <ID> --auto` | `/work <ID>` |
| Verify | `/vbw:vibe --verify` | `/verify` |
| End session | `/end-session` | (Stop hook) |
| Open PR | `/launch <ID> --close` | `pk ship` |
| Cleanup | `/branch finish <slug>` | `pk done <ID>` |
| Promote | `/g-promote-main` | `pk promote` |

Both work. Switch back at any time. v2 commands are non-colliding.

---

## Backlog

### Shipped in alpha.13 (2026-05-02)

- REST fallback for `gh pr view` / `gh pr create` (GraphQL rate-limit resilience)
- `/work --backend=vbw|native` per-invocation override
- `/brainstorm` + `/brainstorm-review` v2 tier routing
- Consolidated v2 alpha CHANGELOG entry

### alpha.14 candidates

- Automated subagent dispatch from `pk ship --review` (currently prints invocation, doesn't auto-run)
- `pk done` — extract richer journal highlights for Linear comment
- `pk promote` — detect local-edit conflict pattern with incoming dev, offer take-remote option
- `pk install` global installer so `pk` is on PATH (no `./bin/` prefix)

### beta candidates

- **beta.1** — multi-env `pk ship --env=<env>` for Piper (Vercel + Supabase branch + LaunchDarkly)
- **beta.1** — skills directory reorg: `skills/{loop,stage0,orthogonal}/` subdirs
- **beta.2** — GitHub Actions workflow `pr-review.yml` — antagonistic review on PR open (CI-side)
- **GA** — delete v1 skills (currently coexisting), retag `RUNBOOK.md` as v2-only
- **GA** — `pk install` global installer so `pk` is on PATH (no `./bin/pk` prefix)

