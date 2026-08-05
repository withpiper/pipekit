# RUNCARD — Arm vbwfull-1 (real full VBW pipeline)

**Worktree:** `~/Projects/SiteLine/.worktrees/POC-57-vbwfull-1` (branch `exp/POC-57-vbwfull-1`)
**Pane:** `surface:61` (workspace:18), cd'd and ready.
**Base:** `exp/POC-57-base` (`0c52fcaa`). This arm does NOT use Pipekit `/work`, so the native-best skill in the base is irrelevant to it — diff vs base still isolates this arm's work.

**Purpose:** the real `vbw-lead`→`vbw-dev`→`vbw-qa` pipeline — the thing Pipekit's `/work` vbw backend never invokes. This is "VBW the system," not "vbw-dev the executor."

## Start

```bash
cd ~/Projects/SiteLine/.worktrees/POC-57-vbwfull-1 && claude
```

Then drive VBW's real entry (you know its flow better than a guessed incantation — `/vbw:vibe` is "the one command": plan→execute→verify):

```
/vbw:vibe   (scope POC-57 from the frozen spec, then --plan --execute --verify)
```

## The one wrinkle to navigate

VBW works off its **own `.vbw-planning` model**, and this worktree's `.vbw-planning/` carries SiteLine's existing milestones/ROADMAP. So **scope it to POC-57 explicitly** — add POC-57 as the requirement (paste the frozen spec from `experiments/poc-57-backend-ab/SPEC.frozen.md`), don't let `vibe` resume pre-existing SiteLine work. Let it run the full pipeline: `vbw-lead` plans → `vbw-dev` executes → `vbw-qa` verifies. **Do not** `--skip-qa` / `--yolo` — the QA gate is the whole point of this arm.

## Controls (same as the other arms)

- No Linear writes. No shared-DB push (`supabase db push`) / no `mcp.apply_migration` — migration on disk + local/branch DB only.
- Don't edit POC-57 in Linear during the experiment.
- Stop after the pipeline completes; no `pk ship`/`pk done`/`pk promote`.

## Capture when done

```bash
cd ~/Projects/SiteLine/.worktrees/POC-57-vbwfull-1
git log --oneline exp/POC-57-base..HEAD
git diff --stat exp/POC-57-base..HEAD -- ':(exclude).vbw-planning'   # code only
find .vbw-planning -name '*PLAN.md' -o -name '*SUMMARY.md' -o -name '*VERIFICATION.md' | xargs ls -t | head
# the vbw-lead PLAN + vbw-qa VERIFICATION are the artifacts this arm exists to produce
```

Plus your wall-clock, intervention count, and whether `vbw-lead`/`vbw-qa` actually fired (the fidelity check for this arm).
