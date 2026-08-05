# RUNCARD — POC-48 native arm (improved native-best executor)

**Worktree:** `~/Projects/SiteLine/.worktrees/POC-48-native-1` (branch `exp/POC-48-native-1`)
**Backend:** improved native (skill from pipekit `feat/native-workflow-executor` @ `0933cfa` — test-first + sequential-default).
**Diff baseline:** `exp/POC-48-base` (`c9164a0c`). Judge/parity diffs this arm against that.

## Start
```bash
cd ~/Projects/SiteLine/.worktrees/POC-48-native-1 && claude --dangerously-skip-permissions
```
Then in that session:
```
/work POC-48 --backend=native
```
Tell it up front: *"The frozen contract is `POC-48-SPEC.frozen.md` in this worktree — treat it as the spec. Do not read Linear."*

## Controls (keep arms comparable — do NOT deviate)
- **No Linear writes**, no push, no `supabase db push` to shared envs. Local DB only.
- **New migration timestamp strictly later than `20260608120500`** (main tail). Re-check tail before any merge (frozen-file invariant).
- Drive it human-paced; discuss-vs-not at pauses → **discuss** (mirror real-world; round-1 control).
- Let native own its plan — do NOT feed it the vbwfull arm's output.

## What master (watcher) verifies for this arm
1. **Native authors the parity/financial tests itself** (the round-1 gap that `0933cfa` is supposed to fix — this is the validation point).
2. **JS↔SQL parity to the cent** (abs diff < 0.005) on admin base, each row charge, production fee, contingency, totals, profit.
3. Native runs on **Step 5n** (materializes `.pk-work/POC-48-PLAN.md` task DAG; sequential-default execution).
4. Capture: total tokens + wall-clock.

## Gate (shared with vbwfull)
- `/financial-review` PASS
- JS↔SQL parity tests green (< 0.005)
- `/verify` full (incl. `npm run test:rls` if DB touched)
