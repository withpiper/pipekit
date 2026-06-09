# RUNCARD — Arm vbw-1 (pilot)

**Worktree:** `~/Projects/SiteLine/.worktrees/POC-57-vbw-1` (branch `exp/POC-57-vbw-1`)
**Base:** `exp/POC-57-base` (`0c52fcaa`) = SiteLine `origin/main` `2fb49a14` + native-best skill installed (VBW path is unchanged by the rebuild, so this base is identical-input for both arms).

## Start

Open a **fresh** Claude Code session in the worktree:

```bash
cd ~/Projects/SiteLine/.worktrees/POC-57-vbw-1 && claude
```

Then run exactly:

```
/work POC-57 --backend=vbw --no-rollover
```

## Controls (enforce if the session drifts)

- **Backend = vbw.** Confirm it actually spawns the real pipeline: `vbw:vbw-lead` (plan → `.vbw-planning/.../PLAN.md`) then `vbw:vbw-dev` (execute). If it just runs in-context, it's not VBW — stop.
- **No Linear writes.** No status transitions, no comments.
- **No shared DB.** Never `supabase db push` to a shared env; never `mcp.apply_migration`. Migration file on disk only; local/branch DB at most.
- **Spec source:** POC-57 is Approved in Linear and frozen-by-agreement during the experiment (== `SPEC.frozen.md`). Don't edit POC-57 in Linear until the experiment is done.
- **Stop after execution.** `--no-rollover` blocks the auto `/verify`+`pk ship`. Do not run `pk ship`/`pk done`/`pk promote`.

## Capture when done (paste back to the master session)

```bash
cd ~/Projects/SiteLine/.worktrees/POC-57-vbw-1
git log --oneline exp/POC-57-base..HEAD
git diff --stat exp/POC-57-base..HEAD
find .vbw-planning -newer .git -name '*POC-57*' -o -name '*-PLAN.md' -newer .git 2>/dev/null | head
# the vbw PLAN it generated (path printed by vbw-lead), plus any SUMMARY/VERIFICATION
```

Plus, from your observation: wall-clock, # of times you had to intervene, any blockers it surfaced.
