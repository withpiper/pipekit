# Pipekit Per-Issue Runbook

The definitive step-by-step for shipping one Linear issue through the pipeline. Read once; refer back when you forget the exact order.

**Canonical pipeline:** `method.md` § Stages 1-5. **This doc:** the practical, tool-by-tool walkthrough.

---

## Quick Index — follow in order

**Per-issue loop:**

0. [Open the session](#0-open-the-session) — `/start-session`
1. [Pick the issue](#1-pick-the-issue) — NEXT.md / `/linear-status` / `/spec-preflight`
2. [Branch + worktree](#2-branch--worktree) — `/branch --linear RS-XX`
3. [Launch the auto-chain](#3-launch-the-auto-chain) — `/launch RS-XX --auto`
4. [Decision: plan-review verdict](#4-decision-plan-review-verdict) — Pass / Revise / Block
5. [Watch (don't intervene during) execution](#5-watch-dont-intervene-during-execution)
6. [Decision: QA verdict](#6-decision-qa-verdict) — Pass / Partial / Fail
7. [UAT](#7-uat) — `/vbw:vibe --verify` or local smoke
8. [Close the session — `/end-session` FIRST (v1.8.0+)](#8-close-the-session--end-session-first-v180)
9. [Open the PR — `/launch --close`](#9-open-the-pr--launch---close)
10. [Rebase-merge the PR](#10-rebase-merge-the-pr-github-ui-or-gh-pr-merge---rebase)
11. [Smoke against dev preview (optional)](#11-smoke-against-dev-preview-optional) — `/g-test-vercel`
12. [Worktree cleanup](#12-worktree-cleanup) — `/branch finish`

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

Same shape every time. ~10 steps from "I want to ship X" to "X is in production."

### 0. Open the session

In the project root (parent worktree, on `dev`):

```bash
/start-session
```

Surfaces NEXT.md, pending-strategy-sync marker, recent session log. Tells you what's next.

### 1. Pick the issue

Either trust NEXT.md's recommendation, or:

```bash
/linear-status                       # quick triage
/phase-plan --status                 # phase-aware view
```

Confirm the issue is **Approved** (or higher — Specced isn't ready). For an Approved issue, optionally:

```bash
/spec-preflight RS-XX                # empirical pre-flight on the spec
```

Verifies file paths, line refs, dependencies still real. Read-only. **Skip if you trust the spec was reviewed recently.**

### 2. Branch + worktree

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

### 3. Launch the auto-chain

In the worktree shell:

```bash
/launch RS-XX --auto
```

`--auto` is **Standard tier only**. Quick tier delegates to `/linear-todo-runner`. Heavy tier rejects (security review + `/strategy-sync` need human pacing).

The orchestration spawns each stage as a fresh Task subagent, preserving fresh-chat discipline:

```
vbw:vbw-lead → plan-reviewer → vbw:vbw-dev → vbw:vbw-qa → /launch --close
```

Pauses only at the two real decision points (steps 4 and 6 below).

### 4. Decision: plan-review verdict

`--auto` stops with the plan-reviewer's structured verdict. One of three:

| Verdict | What to do |
|---|---|
| **Pass** | Approve in chat → `--auto` resumes Dev |
| **Revise** | Tell the chat: feed corrections back to vbw:vbw-lead, re-spawn plan-reviewer. Same `--auto` orchestration handles round 2. |
| **Block** | Abort `--auto`. Either: (a) edit the spec and re-launch, or (b) escalate the issue back to spec review. Don't push through. |

Stalemate detection: if round 2 also Blocks on the same items, **stop and edit the spec by hand** rather than spinning further. Plan-reviewer can't reconcile a spec that's genuinely broken.

### 5. Watch (don't intervene during) execution

vbw:vbw-dev runs the plan with atomic commits. Don't review-as-you-go — let it finish. If you see permission denials surface (`EditPermissionDenied` / `HookFeedbackBlocked`), the agent should stop and surface; if it doesn't, kill the run and check the v1.4 permission-denial protocol.

### 6. Decision: QA verdict

vbw:vbw-qa returns Pass / Fail / Partial.

| Verdict | What to do |
|---|---|
| **Pass** | Approve → continues to UAT (step 7) |
| **Partial** | Read the verdict carefully. Often the right answer is **plan-amendment** (declare the deviation in SUMMARY.md) rather than re-running QA. Hand-driven amendment is one round; full re-execute is multiple agents. |
| **Fail** | Pause hard. `/vbw:vibe --verify` for inline UAT loop, or escalate. **Do not re-run --auto on Fail** — the gate has spoken. |

### 7. UAT

Either:
- `/vbw:vibe --verify` for the inline VBW UAT loop, or
- Smoke locally + smoke against preview deploy

Both are valid. Use `/vbw:vibe --verify` when you want the agent-mediated checklist; smoke directly when you trust the AC.

### 8. Close the session — `/end-session` FIRST (v1.8.0+)

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

The commit lands on the feature branch *before* the PR opens. Step 9 (`/launch --close`) then bundles everything into the single PR. **No cherry-pick; one PR per issue.**

### 9. Open the PR — `/launch --close`

```bash
/launch RS-XX --close
```

Opens feature → dev PR with code + session log + NEXT.md update. Linear → UAT. The PR has everything in one place.

### 10. Rebase-merge the PR (GitHub UI or `gh pr merge --rebase`)

Atomic commits flow onto dev linearly. Auto-delete handles the remote branch.

### 11. Smoke against dev preview (optional)

```bash
/g-test-vercel RS-XX           # project-side skill — pushes branch + smoke-tests preview URL
```

(Mostly relevant if you didn't run it during step 7. Otherwise skip.)

### 12. Worktree cleanup

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
/start-session
   │
   ├─ pick issue (NEXT.md or /linear-status)
   │
/branch --linear RS-XX        ← creates worktree + Linear In Progress
   │
   └─ inside worktree:
      /launch RS-XX --auto    ← Standard tier
         │
         ├─ Plan-review verdict?
         │    Pass → continue
         │    Revise → feedback loop, re-review
         │    Block → abort, edit spec, restart
         │
         ├─ (Dev runs autonomously)
         │
         ├─ QA verdict?
         │    Pass → /launch --close → Linear UAT
         │    Partial → plan-amendment usually
         │    Fail → stop, diagnose, no auto-rerun
         │
         ├─ UAT (/vbw:vibe --verify or local smoke)
         │
         ├─ /end-session              ← v1.8.0+: BEFORE --close
         │    (refuses on dev/main; refreshes NEXT.md from origin/dev tip;
         │     commits log + NEXT.md to feature branch)
         │
         ├─ /launch RS-XX --close     ← opens single PR with everything
         │
         ├─ Rebase-merge PR
         │
         └─ /branch finish (or claude-squad delete)

…then later, batch-promote dev → main:
   gh pr create --base main --head dev …
   /g-promote-main --post-merge
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
