# Pipekit Per-Issue Runbook

The definitive step-by-step for shipping one Linear issue through the pipeline. Read once; refer back when you forget the exact order.

**Canonical pipeline:** `method.md` § Stages 1-5. **This doc:** the practical, tool-by-tool walkthrough.

---

## One-time setup (per repo)

Confirm these once per consuming project. They make the loop friction-free.

| Setting | Where | Why |
|---|---|---|
| Branch protection on `dev` and `main` | GitHub repo Settings → Branches | Forces all changes through PRs |
| **Squash-merge only** (disallow merge commits) | Settings → General → Pull Requests | Eliminates merge-commit topology that causes phantom conflicts on subsequent promotes |
| **Auto-delete head branches on merge** | Settings → General → Pull Requests | Remote cleanup is automatic; CWT/claude-squad handles local |
| Pipekit synced to **v1.7.0+** | `./scripts/sync-method.sh v1.7.0` | Out-of-repo state directory; defer mechanism actually works |

Verify in 30 seconds:

```bash
gh repo view <org>/<repo> --json deleteBranchOnMerge,squashMergeAllowed,mergeCommitAllowed \
  --jq '{deleteBranches:.deleteBranchOnMerge, squashOk:.squashMergeAllowed, mergeBlocked:(.mergeCommitAllowed|not)}'
# Expect: {deleteBranches: true, squashOk: true, mergeBlocked: true}

grep -m1 'v1\.' method/method.md   # expect v1.7.0 or later
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

What happens:
- Pre-checks Linear status (warns if already shipped/canceled).
- Creates `feature/<linear-slug>` (or `fix/`, `hotfix/`) branch off `dev`.
- Spawns worktree at `.worktrees/<branch-name>`.
- Symlinks `.env` and `node_modules` into the worktree.
- Transitions Linear: Approved → In Progress.
- Prints: `cd .worktrees/<branch-name> && claude` to enter.

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
| **Pass** | Approve → `--auto` runs `/launch --close`, transitions Linear to UAT, ends |
| **Partial** | Read the verdict carefully. Often the right answer is **plan-amendment** (declare the deviation in SUMMARY.md) rather than re-running QA. Hand-driven amendment is one round; full re-execute is multiple agents. |
| **Fail** | Pause hard. `/vbw:vibe --verify` for inline UAT loop, or escalate. **Do not re-run --auto on Fail** — the gate has spoken. |

### 7. UAT

Either:
- `/vbw:vibe --verify` for the inline VBW UAT loop, or
- Smoke locally + smoke against preview deploy

Both are valid. Use `/vbw:vibe --verify` when you want the agent-mediated checklist; smoke directly when you trust the AC.

### 8. Close the session

```bash
/end-session
```

What it does (v1.7.0+):
- Reads the deferred NEXT.md queue from `~/.cache/pipekit/<repo>/pending-next-md.json` and applies it (or recomputes if stale).
- Writes session log to `Logs/Sessions/YYYY-MM-DD_HHMM.md`.
- Recomputes NEXT.md (next Approved issue / `/strategy-sync` / `/phase-plan`).
- Commits log + NEXT.md + pushes to the **feature branch**.

⚠️ **Known friction (open):** /end-session writes log + NEXT.md to the feature branch. After PR merge, those commits are post-merge orphans on a deleted branch. **Workaround until v1.8.0:**

```bash
# In the parent worktree, before CWT-deleting the feature worktree:
cd ~/Projects/<repo>
git checkout dev && git pull --ff-only
git checkout -b chore/preserve-rs-XX-session-artifacts
git cherry-pick <feature-branch-tip>     # picks the /end-session commit only
git push -u origin chore/preserve-rs-XX-session-artifacts
gh pr create --base dev --title "chore(log): preserve RS-XX session artifacts"
# Squash-merge that PR.
```

### 9. Promote feature → dev (if not done by --close)

`/launch --close` opens the PR. Squash-merge it. Auto-delete handles the remote.

### 10. Worktree cleanup

```bash
/branch finish        # local: removes worktree + branch
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
         └─ /end-session
            └─ cherry-pick session log to dev (workaround)
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
