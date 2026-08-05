# RUNCARD — Arm native-1 (pilot)

**Worktree:** `~/Projects/SiteLine/.worktrees/POC-57-native-1` (branch `exp/POC-57-native-1`)
**Base:** `exp/POC-57-base` (`0c52fcaa`) = SiteLine `origin/main` `2fb49a14` + native-best skill installed.

## Start

Open a **fresh** Claude Code session in the worktree (fresh = no context bleed from other arms):

```bash
cd ~/Projects/SiteLine/.worktrees/POC-57-native-1 && claude
```

Then run exactly:

```
/work POC-57 --backend=native --no-rollover
```

## Controls (enforce if the session drifts)

- **Backend = native.** Confirm it runs the rebuilt Step 5n path: writes `.pk-work/POC-57-PLAN.md` (task DAG), executes with verify-before-integrate. If it falls back to a single blob subagent, the wrong skill is installed — stop.
- **No Linear writes.** No status transitions, no comments. (`--no-rollover` + manual worktree means it shouldn't touch Linear; verify it doesn't.)
- **No shared DB.** Never `supabase db push` to a shared env; never `mcp.apply_migration`. Migration file on disk only; local/branch DB at most.
- **Spec source:** POC-57 is Approved in Linear and frozen-by-agreement during the experiment (== `SPEC.frozen.md`). Don't edit POC-57 in Linear until the experiment is done.
- **Stop after execution.** `--no-rollover` blocks the auto `/verify`+`pk ship`. Do not run `pk ship`/`pk done`/`pk promote`.

## Capture when done (paste back to the master session)

```bash
cd ~/Projects/SiteLine/.worktrees/POC-57-native-1
git log --oneline exp/POC-57-base..HEAD
git diff --stat exp/POC-57-base..HEAD
cat .pk-work/POC-57-PLAN.md
cat .pk-work/POC-57-SUMMARY.md
```

Plus, from your observation: wall-clock, # of times you had to intervene, any blockers it surfaced.
