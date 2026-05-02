# Pipekit Runbook (v2.0.0)

> **North star:** safe and frictionless. Helps, never adds work.

The v2 daily loop on one page. Read top-to-bottom. v1 commands are retired — preserved under `archive/v1-skills/` for reference only.

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

### Shipped in alpha.14 (2026-05-02 PM)

- `pk install` global installer (symlinks pk to `/usr/local/bin` or `~/.local/bin`)
- `pk done` — richer Linear comment (commits + diffstat + session count + PR URL)
- `pk promote --stash` / `--take-remote` flags for local-edit conflict resolution
- REST-first ordering in `pk_gh_pr_view` / `pk_gh_pr_create` (was burning GraphQL quota)

### v2.1 candidates

- **`resources/` vs `temp/` portable convention** — `resources/` for committed reference materials (design handoffs, spec dependencies); `temp/` fully gitignored for ephemera. Bake into `method.md`, `templates/`, and consuming-project bootstrap. Surfaced 2026-05-02 when RS-63's `/work` couldn't see the design handoff (lived in parent's `temp/`, gitignored, didn't travel to worktree).
- **`pk branch` worktree-aware resource sync** — copy `resources/` (and any `.pkignore`-listed paths) into new worktrees so gitignored-but-needed files travel with the work. Companion to the convention above.
- **Phase-aware `pk next`** — surfaces issues grouped by status within the current phase: In Progress, Approved, Needs Spec (with `/light-spec` hint per item), separated from "Other phases". Reads current phase from `PHASES.md`, scopes Linear queries by project ID from `linear-map.json`. Today's `pk next` only finds the first Approved issue anywhere — silent when current phase has none even though there's actionable work (`/light-spec` candidates). Surfaced 2026-05-02 during RS-63 execution: Phase 2.5 had RS-63 in flight + 6 Needs Spec issues but `pk next` was useless.
- **Mid-loop Linear visibility for review + fix** — `pk ship --review` (or `/ship` when it lands) should post a Linear comment summarizing the antagonistic review (severity counts, recommendation, PR comment URL) when the review is posted. `/pr-fix` should post a Linear comment when triage completes (fixes applied, findings rejected with reason, deferrals). Today's gap: Linear sees `In Progress → UAT → Done` but no record of "review found 16 things, 1 was a false positive verified via MCP, 7 fixed, 8 deferred." That context lives only on the PR. Surfaced 2026-05-02 during RS-63 review/fix cycle.

### Flowchart promotion (v2.1)

When the visual-review and cross-spec-verify items below ship as actual code/skill changes, the flowchart in §"Per-issue flowchart" needs an update:

- **Insert a new step between [4] Verify and [5] Ship**: visual-state verification — runs Playwright (or equivalent) against the worktree's running app at key user states, diffs against figma source. Optional gate (config: `Require visual review: true|false`). Catches the class of miss where components compile + tests pass but the integration didn't land (today's RS-64 example).
- **Update [5b] Antagonistic PR review** to call out the cross-spec handoff check explicitly: reviewer must fetch predecessor specs (any "X will…" references) and verify each promise landed in this PR.
- **Add a [5c] /pr-fix triage** step explicitly in the flowchart (currently implicit between 5b and merge).
- **Add a [5d] /pr-security-review** opt-in step (see new skill candidate below) — fires on PRs touching `supabase/migrations/`, `*.sql`, or `SECURITY DEFINER` functions.

Today's flowchart shows steps 1–8 with 5b inserted but no visual review, no /pr-fix, no security review. After v2.1 ships, the chain becomes: 1 → 2 → 3 → 4 → **4b (visual)** → 5 → 5b → **5c (/pr-fix)** → **5d (/pr-security-review, opt-in)** → 6 → 7 → 8.

### v2.1 — new skill: /pr-security-review

**Gap surfaced 2026-05-02 PM by RS-74:** rs-vault has `/security-review` (a periodic codebase audit) and `pr-review-toolkit:review-pr` (a generic antagonistic review), but **nothing purpose-built for "security-focused review of THIS PR's diff."** Migration PRs (new RLS policies, `SECURITY DEFINER` functions, audit-log access) need a focused skill that bakes in the right rubric.

Proposed `/pr-security-review` scope:

- Fires on PRs touching: `supabase/migrations/**`, `*.sql`, files containing `SECURITY DEFINER`, `auth.uid()` references, RLS policy definitions
- Loads a security-specific antagonistic prompt (RLS correctness, search_path hardening, function gate semantics, action allowlist coverage, PII / admin-only data leak vectors, type regen accuracy)
- Posts findings as a PR review comment via `gh api -X POST .../pulls/<N>/reviews` — same shape as `pk ship --review`, separate prompt
- Caller can run it in addition to `pk ship --review` (they cover different surface area) or instead, depending on PR shape
- Companion to `/pr-fix` — its triage flow already verifies findings before applying

This is **different from `/security-review`** (periodic repo-wide audit) and **different from `pr-review-toolkit:review-pr`** (broad PR review). Same skill family as `/pr-fix` — focused, PR-diff-scoped, opinionated rubric.

### Surfaced 2026-05-02 PM (RS-64 cross-spec miss)

A Phase 2.5 issue (RS-63) explicitly handed off integration work to its successor (RS-64) — *"RS-64 will replace the placeholder with real Drawer chrome + PropertyCard."* RS-64's PR shipped the components but never integrated them into `search-page.tsx`. Antagonistic review missed it (only had RS-64's AC to check). When the user later asked Claude in the worktree about the placeholder + provided a screenshot, Claude **rationalized the status quo** ("wiring harness for something to come later") rather than checking against intent. Three process gaps:

- **Cross-spec handoff verification** — when an issue's spec contains "`<other-issue>` will…" references, that's a load-bearing handoff promise. Antagonistic review and `/pr-fix` should fetch the predecessor's spec, extract its handoff statements, and verify each landed in the current PR. Right now reviewers only see the current issue's AC.
- **Visual-state verification step** — for any UI issue, the antagonistic-review prompt should explicitly require a screenshot of the running app at a key user-facing state (e.g., post-action, hover, modal-open) compared against the figma handoff or design source. Today the loop is all code review, no visual review. Could be `pk ship --review --visual <url>` or a new `/visual-review` skill that drives Playwright + diff against design source.
- **"Defended status quo" guardrail** — when Claude is asked about a UI/state question with a screenshot, the default behavior should be skepticism: re-read the spec, grep the integration site, check if what's shown matches what's intended. Today Claude pattern-matches on the artifact + nearest-comment-explanation and produces plausible-sounding rationale. Mitigation lives in skill prose (e.g., `/pr-fix` and `/work` should explicitly instruct: "if the user asks 'is this correct?' with a screenshot, do not defend — verify against spec first").
- Automated subagent dispatch from `pk ship --review` — see `temp/ship-skill-spec.md` for full scope. Crosses shell ↔ skill ↔ subagent boundary; needs `/ship` skill wrapper.

### beta candidates

- **beta.1** — multi-env `pk ship --env=<env>` for Piper (Vercel + Supabase branch + LaunchDarkly)
- **beta.1** — skills directory reorg: `skills/{loop,stage0,orthogonal}/` subdirs
- **beta.2** — GitHub Actions workflow `pr-review.yml` — antagonistic review on PR open (CI-side)
- **GA** — delete v1 skills (currently coexisting), retag `RUNBOOK.md` as v2-only

