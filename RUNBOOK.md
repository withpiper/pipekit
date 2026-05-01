# Pipekit Loop — Current State (v1.8.2)

The whole per-issue loop on one page. Read top-to-bottom.

**Today's test mode:** step 4 has two paths.
- **RS-58** (Phase 2 closeout) → VBW path (`/launch --auto`)
- **RS-30** (export threshold alert) → native path (`launch-native`)
- After both, decide: which becomes the default in v2.0.0.

---

## Flowchart

```
┌─────────────────────────────────────────────────────────────────┐
│  PARENT REPO       cwd: ~/Projects/<repo>     branch: dev       │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [1] Pick issue                                           │
  │     cat NEXT.md                                          │
  │     /linear-status         (optional)                    │
  │     /spec-preflight RS-XX  (optional, if spec is older)  │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [2] Branch + worktree                                    │
  │     /branch --linear RS-XX                               │
  │     • creates feature/RS-XX-<slug>                       │
  │     • worktree at .worktrees/RS-XX-<slug>                │
  │     • symlinks .env, node_modules                        │
  │     • Linear:  Approved → In Progress                    │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       cd .worktrees/RS-XX-<slug>
       claude --dangerously-skip-permissions
       │
┌──────┴──────────────────────────────────────────────────────────┐
│  WORKTREE       cwd: .worktrees/RS-XX-<slug>     branch: feature │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [3] /start-session                                       │
  │     • refresh NEXT.md from origin/dev                    │
  │     • surface issue spec from Linear                     │
  │     • note start time                                    │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [4] Launch                                               │
  │                                                          │
  │  ┌─── VBW path ──────────┐    ┌─── Native path ────────┐ │
  │  │ /launch RS-XX --auto  │    │ launch-native RS-XX    │ │
  │  │                       │    │                        │ │
  │  │  vbw:lead             │    │  Task: planner         │ │
  │  │   → plan              │    │   → plan               │ │
  │  │                       │    │                        │ │
  │  │  plan-reviewer        │    │  human verdict         │ │
  │  │   ◇ Pass? Revise?     │    │   (one screen)         │ │
  │  │     Block?            │    │                        │ │
  │  │   Pass  → continue    │    │  Task: dev             │ │
  │  │   Revise→ apply+rerun │    │   → atomic commits     │ │
  │  │   Block → abort,      │    │                        │ │
  │  │           edit spec   │    │  tests + smoke         │ │
  │  │                       │    │                        │ │
  │  │  vbw:dev              │    └────────────────────────┘ │
  │  │   → atomic commits    │                               │
  │  │                       │                               │
  │  │  vbw:qa               │                               │
  │  │   ◇ Pass? Partial?    │                               │
  │  │     Fail?             │                               │
  │  │   Pass    → continue  │                               │
  │  │   Partial → amend     │                               │
  │  │   Fail    → stop      │                               │
  │  │                       │                               │
  │  │  /vbw:vibe --verify   │                               │
  │  │   (or local smoke)    │                               │
  │  └───────────────────────┘                               │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [5] /end-session                                         │
  │     • refuses on dev/main                                │
  │     • refresh NEXT.md from origin/dev                    │
  │     • write Logs/Sessions/<timestamp>.md                 │
  │     • commit log + NEXT.md to feature branch             │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [6] /launch RS-XX --close                                │
  │     • open feature → dev PR                              │
  │       (code + log + NEXT.md in one PR)                   │
  │     • Linear:  Building → UAT                            │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [7] Merge PR  (feature → dev)                            │
  │     gh pr merge --merge     (or GitHub UI: "Create       │
  │                              merge commit")              │
  │     • merge-commit preserves per-feature history on dev  │
  │     • absorbed cleanly when dev → main squashes          │
  │     • auto-delete remote branch                          │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       exit              (drops to shell at .worktrees/...)
       cd ~/Projects/<repo>
       claude            (parent session)
       │
┌──────┴──────────────────────────────────────────────────────────┐
│  PARENT REPO       cwd: ~/Projects/<repo>     branch: dev       │
└─────────────────────────────────────────────────────────────────┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [8] /branch finish RS-XX-<slug>                          │
  │     • remove worktree                                    │
  │     • delete local branch                                │
  └──────────────────────────────────────────────────────────┘
       │
       ▼
       ◇ accumulated 1–3 dev merges?
              │
       No  ───┼───→  loop to [1]
              │
       Yes ───┘
       │
       ▼
  ┌──────────────────────────────────────────────────────────┐
  │ [9] PROMOTE dev → main   (separate, batched flow)        │
  │     git checkout dev && git pull --ff-only               │
  │     pnpm check-types && pnpm lint && pnpm test           │
  │     gh pr create --base main --head dev                  │
  │     squash-merge          (Ruleset enforces)             │
  │     /g-promote-main --post-merge                         │
  │       • supabase db push                                 │
  │       • prod smoke                                       │
  │       • Linear:  UAT → Done                              │
  └──────────────────────────────────────────────────────────┘
```

---

## Step ↔ skill cheat sheet

| # | Step | Skill / command | Where you run it |
|---|---|---|---|
| 1 | Pick issue | `cat NEXT.md` / `/linear-status` | parent, on dev |
| 2 | Branch | `/branch --linear RS-XX` | parent, on dev |
| 3 | Start session | `/start-session` | worktree, feature |
| 4 | Launch (VBW) | `/launch RS-XX --auto` | worktree, feature |
| 4 | Launch (native) | `launch-native RS-XX` | worktree, feature |
| 5 | End session | `/end-session` | worktree, feature |
| 6 | Open PR | `/launch RS-XX --close` | worktree, feature |
| 7 | Merge (feature → dev) | `gh pr merge --merge` | anywhere |
| 8 | Cleanup | `/branch finish RS-XX-<slug>` | parent, on dev |
| 9 | Promote | `/g-promote-main --post-merge` | parent, on dev |

---

## Recovery (one rule)

**Rerun the skill.** Most current skills are idempotent. If a rerun doesn't fix it:

- **Plan-reviewer Block round-2:** edit spec by hand, restart `/launch --auto`.
- **QA Fail:** stop. `/vbw:vibe --verify` or escalate. Don't re-run `--auto`.
- **NEXT.md write blocked:** sync to v1.7.0+ (out-of-repo state).
- **Stale git index lock:** verify no real git process, then `rm <repo>/.git/index.lock`.
- **Phantom dev → main conflicts:** legacy pre-squash topology. Use `git merge -X theirs` workaround (see deprecated RUNBOOK.md § Recovery if needed).

For everything else: see `RUNBOOK.md` § Recovery (legacy reference).

---

## Test-mode annotations (2026-05-01)

- RS-58 → step 4 VBW path (already running, don't disrupt).
- RS-30 → step 4 native path (small, isolated, fast signal).
- Compare on: plan quality, dev execution, QA catches, wall time, token cost.
- Verdict feeds the v2.0.0 redesign (`/work` backend choice).
