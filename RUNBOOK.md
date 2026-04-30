# Pipekit Per-Issue Runbook

The definitive step-by-step for shipping one Linear issue through the pipeline. Read once; refer back when you forget the exact order.

**Canonical pipeline:** `method.md` § Stages 1-5. **This doc:** the practical, tool-by-tool walkthrough.

---

## Quick Index — follow in order

**Per-issue loop:**

0. [Pick the issue (parent, lightweight)](#0-pick-the-issue-parent-lightweight) — NEXT.md / `/linear-status` / `/spec-preflight`
1. [Branch + worktree](#1-branch--worktree) — `/branch --linear RS-XX`
2. [Enter the worktree](#2-enter-the-worktree) — `cd … && claude --dangerously-skip-permissions`
3. [`/start-session` (worktree)](#3-start-session-worktree-on-feature-branch--paired-with-end-session) — orient on the issue
4. [Launch the auto-chain](#4-launch-the-auto-chain) — `/launch RS-XX --auto`
5. [Decision: plan-review verdict](#5-decision-plan-review-verdict) — Pass / Revise / Block
6. [Watch (don't intervene during) execution](#6-watch-dont-intervene-during-execution)
7. [Decision: QA verdict](#7-decision-qa-verdict) — Pass / Partial / Fail
8. [UAT](#8-uat) — `/vbw:vibe --verify` or local smoke
9. [Close the session — `/end-session`](#9-close-the-session--end-session-paired-with-step-3s-start-session)
10. [Open the PR — `/launch --close`](#10-open-the-pr--launch---close)
11. [Rebase-merge the PR](#11-rebase-merge-the-pr-github-ui-or-gh-pr-merge---rebase)
12. [Smoke against dev preview (optional)](#12-smoke-against-dev-preview-optional) — `/g-test-vercel`
13. [Worktree cleanup](#13-worktree-cleanup) — `/branch finish`

**Then periodically (separate flow):**

- P1–P4. [Promote dev → main](#promote-dev--main) — `/g-promote-main` → squash → `/g-promote-main --post-merge` → `/strategy-sync`

**If something goes wrong:**

- [Phantom conflicts on dev → main PR](#phantom-conflicts-on-dev--main-pr)
- [Stale git index lock](#stale-git-index-lock)
- [Plan-reviewer Block on round 2 (stalemate)](#plan-reviewer-block-on-round-2-stalemate)
- [State-file or NEXT.md write hook-blocked](#state-file-or-nextmd-write-hook-blocked)

**Reference:**

- [One-time setup (per repo)](#one-time-setup-per-repo) — squash/rebase/auto-delete config + `pipekit-configure-repo.sh`
- [Decision tree at a glance](#decision-tree-at-a-glance)
- [What's NOT in this runbook](#whats-not-in-this-runbook-separate-flows)

---

## One-time setup (per repo)

Confirm these once per consuming project. They make the loop friction-free.

| Setting | Where | Why |
|---|---|---|
| Branch protection on `dev` and `main` | GitHub repo Settings → Branches | Forces all changes through PRs |
| **Rebase-merge enabled, merge-commits disallowed** | Settings → General → Pull Requests | feature → dev keeps atomic commits readable; eliminates merge-commit topology that causes phantom conflicts |
| **Squash-merge enabled** | Same | dev → main collapses to one release commit; per-issue commits stay on dev |
| **Auto-delete head branches on merge** | Settings → General → Pull Requests | Remote cleanup is automatic; claude-squad handles local |
| Pipekit synced to **v1.8.0+** | `./scripts/sync-method.sh v1.8.0` | One-PR-per-issue flow (no cherry-pick); short branch names |

**Recommended merge strategy by hop:**
- feature → dev: **rebase** (preserves atomic commits, readable in GitKraken/git-log)
- dev → main: **squash** (single commit per release; kills merge-commit topology)
- merge-commits: **never** (creates phantom conflicts on subsequent promotes)

Verify in 30 seconds:

```bash
gh repo view <org>/<repo> --json deleteBranchOnMerge,squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed \
  --jq '{deleteBranches:.deleteBranchOnMerge, squashOk:.squashMergeAllowed, rebaseOk:.rebaseMergeAllowed, mergeBlocked:(.mergeCommitAllowed|not)}'
# Expect: {deleteBranches: true, squashOk: true, rebaseOk: true, mergeBlocked: true}

grep -m1 'v1\.' method/method.md   # expect v1.8.0 or later
```

**One-shot configure** (idempotent — safe to re-run):

```bash
gh api repos/<org>/<repo> --method PATCH \
  -f delete_branch_on_merge=true \
  -f allow_merge_commit=false \
  -f allow_squash_merge=true \
  -f allow_rebase_merge=true
```

---

## The loop

Same shape every time. ~12 steps from "I want to ship X" to "X is in production."

**Pairing model (v1.8.0.1+):** /start-session and /end-session both run **inside the worktree, on the feature branch**. /start-session orients you on the issue; /end-session writes the log when the issue is done. Both refresh NEXT.md from `origin/<integration>` so you see current state regardless of how long the worktree has lived.

### 0. Pick the issue (parent, lightweight)

In the project root (parent on `dev`), pick the issue *without* opening a full session:

```bash
cat NEXT.md                         # what was queued at end of last session
/linear-status                       # quick triage
/phase-plan --status                 # phase-aware view (optional)
```

Confirm the issue is **Approved** (or higher — Specced isn't ready). For an Approved issue, optionally:

```bash
/spec-preflight RS-XX                # empirical pre-flight on the spec
```

Verifies file paths, line refs, dependencies still real. Read-only. **Skip if you trust the spec was reviewed recently.**

(If you genuinely want a full /start-session at the project level — e.g. start of a workday, no specific issue yet in mind — run it now. Otherwise skip; step 4 below opens the real session inside the worktree.)

### 1. Branch + worktree

**Use `/branch`, not raw `git worktree`.** It handles Linear status transition, env symlinks, and worktree naming convention.

```bash
/branch --linear RS-XX
```

What happens (v1.8.0+):
- Pre-checks Linear status (warns if already shipped/canceled).
- Creates `feature/<PREFIX>-<NN>-<2-3-word-slug>` off `dev` — short, deterministic. E.g. `feature/RS-21-edit-delete`, not the verbose Linear gitBranchName.
- Spawns worktree at `.worktrees/<branch-name>`.
- Symlinks `.env` and `node_modules` into the worktree.
- Transitions Linear: Approved → In Progress.
- Prints: `cd .worktrees/<branch-name> && claude --dangerously-skip-permissions` to enter.

If you'd rather use a TUI for worktree management, claude-squad (`brew install claude-squad`) wraps the same primitives across multiple agents. CWT (archived 2026-04-29) — don't ingest.

### 2. Enter the worktree

Run the command /branch printed:

```bash
cd .worktrees/RS-XX-edit-delete && claude --dangerously-skip-permissions
```

Now you're in the worktree session, on the feature branch. Steps 3–9 all run here.

### 3. `/start-session` (worktree, on feature branch) — paired with /end-session

```bash
/start-session
```

What it does (v1.8.0.1+ inside a worktree):
- Refreshes NEXT.md to `origin/<integration>` tip (parallel-session-safe view).
- Surfaces NEXT.md, pending-strategy-sync marker, recent session log.
- Pulls up the issue spec from Linear (you /branch'd with --linear, so we know which one).
- Notes the start time for duration tracking.

This is the *real* session opener. It pairs with /end-session at step 9 — same scope (this feature branch), same NEXT.md base.

### 4. Launch the auto-chain

```bash
/launch RS-XX --auto
```

`--auto` is **Standard tier only**. Quick tier delegates to `/linear-todo-runner`. Heavy tier rejects (security review + `/strategy-sync` need human pacing).

The orchestration spawns each stage as a fresh Task subagent, preserving fresh-chat discipline:

```
vbw:vbw-lead → plan-reviewer → vbw:vbw-dev → vbw:vbw-qa
```

Pauses only at the two real decision points (steps 5 and 7 below).

### 5. Decision: plan-review verdict

`--auto` stops with the plan-reviewer's structured verdict. One of three:

| Verdict | Default action (v1.8.0.3+) | Notes |
|---|---|---|
| **Pass** | `proceed` → Dev runs next | The clean path |
| **Revise** | **`apply-fixes-and-re-review`** → Lead applies the blocking items, plan-reviewer re-runs as round 2 | Round-2 Pass → Dev. Round-2 Revise → loop to round 3 with stalemate detection. Round-2 Block → abort. Default is **NOT** "proceed" — that was a v1.6.0–v1.8.0.2 bug. |
| **Block** | `abort` → edit spec or escalate | Don't push through |

**Stalemate detection (round 3+):** if round 3's Revise verdict overlaps with round 2's blocking items, `--auto` pauses and surfaces: "Plan-reviewer is flagging the same items in round 3 that it flagged in round 2. The spec may need hand-editing rather than auto-revision." Default at this prompt is **pause**. The orchestrator does NOT auto-loop a 4th round.

**Override option:** if you genuinely want to skip the round-2 re-review (rare; almost always wrong), `proceed-without-re-review` is available. The override is logged to the pipeline state file (`override: "skip-plan-review-round-2"`) for audit.

### 6. Watch (don't intervene during) execution

vbw:vbw-dev runs the plan with atomic commits. Don't review-as-you-go — let it finish. If you see permission denials surface (`EditPermissionDenied` / `HookFeedbackBlocked`), the agent should stop and surface; if it doesn't, kill the run and check the v1.4 permission-denial protocol.

### 7. Decision: QA verdict

vbw:vbw-qa returns Pass / Fail / Partial.

| Verdict | What to do |
|---|---|
| **Pass** | Approve → continues to UAT (step 8) |
| **Partial** | Read the verdict carefully. Often the right answer is **plan-amendment** (declare the deviation in SUMMARY.md) rather than re-running QA. Hand-driven amendment is one round; full re-execute is multiple agents. |
| **Fail** | Pause hard. `/vbw:vibe --verify` for inline UAT loop, or escalate. **Do not re-run --auto on Fail** — the gate has spoken. |

### 8. UAT

Either:
- `/vbw:vibe --verify` for the inline VBW UAT loop, or
- Smoke locally + smoke against preview deploy

Both are valid. Use `/vbw:vibe --verify` when you want the agent-mediated checklist; smoke directly when you trust the AC.

### 9. Close the session — `/end-session` (paired with step 3's /start-session)

```bash
/end-session
```

What it does (v1.8.0+):
- Refuses to run if you're on `dev` or `main` (guard against accidental direct-to-integration writes).
- **Refreshes NEXT.md to `origin/<integration>` tip** — picks up any parallel-session updates so the recompute starts from a current base.
- Reads the deferred NEXT.md queue from `~/.cache/pipekit/<repo>/pending-next-md.json` and applies/discards as appropriate.
- Writes session log to `Logs/Sessions/YYYY-MM-DD_HHMM.md`.
- Recomputes NEXT.md (next Approved issue / `/strategy-sync` / `/phase-plan`) on top of the refreshed base.
- Commits log + NEXT.md to the **current feature branch**.

The commit lands on the feature branch *before* the PR opens. Step 10 (`/launch --close`) then bundles everything into the single PR. **No cherry-pick; one PR per issue.**

### 10. Open the PR — `/launch --close`

```bash
/launch RS-XX --close
```

Opens feature → dev PR with code + session log + NEXT.md update. Linear → UAT. The PR has everything in one place.

### 11. Rebase-merge the PR (GitHub UI or `gh pr merge --rebase`)

Atomic commits flow onto dev linearly. Auto-delete handles the remote branch.

### 12. Smoke against dev preview (optional)

```bash
/g-test-vercel RS-XX           # project-side skill — pushes branch + smoke-tests preview URL
```

(Mostly relevant if you didn't run it during step 8. Otherwise skip.)

### 13. Worktree cleanup

```bash
exit                           # leave the worktree session
/branch finish                 # in parent: removes local worktree + branch
```

Or claude-squad TUI: select the session → `d`. Same outcome.

---

## Promote dev → main

Separate flow. Run when you have one or more shipped issues on dev ready for production.

```bash
cd ~/Projects/<repo>
git checkout dev && git pull --ff-only

# Pre-deploy gate (whatever the project's gate is)
pnpm check-types && pnpm lint && pnpm test && <project gates>

# Open the promote PR
gh pr create --base main --head dev \
  --title "Promote dev → main (YYYY-MM-DD) — RS-XX[, RS-YY]" \
  --body "<commits + verification>"
```

Squash-merge the PR. Then:

```bash
/g-promote-main --post-merge
```

Runs:
- `supabase db push` (or project DB sync)
- Vercel/prod smoke
- Linear transitions: shipped issues → Done

---

## Recovery procedures

### Phantom conflicts on dev → main PR

Symptom: PR shows conflicts in files that should be identical, or files like `src/lib/...` show "add/add" against an old merge-base.

Cause: pre-squash-flip merge-commit topology. Fixed permanently going forward, but legacy merge commits leave divergent ancestry.

Fix:

```bash
git checkout main && git pull --ff-only
git checkout -b promote-YYYY-MM-DD
git merge origin/dev -X theirs --no-ff -m "Promote dev → main (YYYY-MM-DD)"
# -X theirs takes dev's content (which is the truth — it has RS-XX merged in)
pnpm <gate>          # confirm green
git push -u origin promote-YYYY-MM-DD
gh pr create --base main --head promote-YYYY-MM-DD --title "..."
```

Squash-merge that PR. The squash collapses to one commit on main; main and dev align cleanly going forward.

### Stale git index lock

`fatal: Unable to create '.git/index.lock': File exists.`

```bash
ps aux | grep -E '[g]it' | grep -v claude   # confirm no real git process
rm <repo>/.git/index.lock                    # safe when nothing's running
```

### Plan-reviewer Block on round 2 (stalemate)

Stop spinning. Edit the spec by hand, then `/launch RS-XX --auto` from scratch. Plan-reviewer can't reconcile a fundamentally broken spec — adding more rounds wastes agent budget.

### State-file or NEXT.md write hook-blocked

If you see `state-file writes are best-effort during scod stages — skipping silently`: you're on Pipekit < v1.7.0. Run `./scripts/sync-method.sh v1.7.0` and retry. v1.7.0 moved state out of repo so the hook can't block it.

---

## Decision tree at a glance

```
parent (on dev):
   pick issue (cat NEXT.md or /linear-status)
   │
   /branch --linear RS-XX        ← creates worktree + Linear In Progress
   │
   cd .worktrees/<slug> && claude --dangerously-skip-permissions
   │
worktree (on feature branch):
   /start-session                 ← v1.8.0.1+: paired with /end-session
   │   (refreshes NEXT.md from origin/dev tip; orients on issue)
   │
   /launch RS-XX --auto           ← Standard tier
      │
      ├─ Plan-review verdict?
      │    Pass → continue
      │    Revise → feedback loop, re-review
      │    Block → abort, edit spec, restart
      │
      ├─ (Dev runs autonomously)
      │
      ├─ QA verdict?
      │    Pass → continue to UAT
      │    Partial → plan-amendment usually
      │    Fail → stop, diagnose, no auto-rerun
      │
      ├─ UAT (/vbw:vibe --verify or local smoke)
      │
      ├─ /end-session             ← v1.8.0+: BEFORE --close
      │    (refuses on dev/main; refreshes NEXT.md;
      │     commits log + NEXT.md to feature branch)
      │
      ├─ /launch RS-XX --close    ← opens single PR with everything
      │
      ├─ Rebase-merge PR (atomic commits flow onto dev)
      │
      └─ exit (back to parent)

parent:
   /branch finish                 ← removes worktree + local branch

…then later, batch-promote dev → main:
   /g-promote-main → squash → /g-promote-main --post-merge
```

---

## What's NOT in this runbook (separate flows)

- `/concept`, `/define`, `/strategy-create` — Stage 0 (project bootstrap), see `STARTUP.md`.
- `/roadmap-create`, `/phase-plan` — milestone- and phase-level planning.
- `/light-spec`, `/light-spec-revise`, `/spec-preflight` — spec authoring (precedes /launch).
- `/strategy-sync`, `/release-changelog` — post-ship doc maintenance.
- `/linear-todo-runner` — Quick-tier batch flow (own runbook needed eventually).

For those, refer to `method.md` and the relevant skill files.

---

## When this runbook drifts

Skill behavior changes occasionally. If a step here disagrees with a skill's actual prose, **the skill is the truth**. Open a PR against this runbook to bring it back in line.
