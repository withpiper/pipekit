# RUNCARD — POC-48 vbwfull arm (real VBW full pipeline)

**Worktree:** `~/Projects/SiteLine/.worktrees/POC-48-vbwfull-1` (branch `exp/POC-48-vbwfull-1`)
**Backend:** real VBW — `/vbw:vibe` scope → plan (`vbw-lead`) → execute (`vbw-dev`) → verify (`vbw-qa`).
**Diff baseline:** `exp/POC-48-base` (`c9164a0c`). Branched off the same base for an identical baseline even though this arm ignores the Pipekit skill.

## Start
```bash
cd ~/Projects/SiteLine/.worktrees/POC-48-vbwfull-1 && claude --dangerously-skip-permissions
```
Then in that session:
```
/vbw:vibe
```
Scope it to POC-48 from the frozen contract: *"Build POC-48 per the frozen spec `POC-48-SPEC.frozen.md` in this worktree. Do not read Linear."*

## Controls (keep arms comparable — do NOT deviate)
- **No Linear writes**, no push, no `supabase db push` to shared envs. Local DB only.
- **New migration timestamp strictly later than `20260608120500`** (main tail). Re-check tail before any merge (frozen-file invariant).
- Drive it human-paced; discuss-vs-not at pauses → **discuss** (mirror real-world; round-1 control).
- Let the full pipeline run as designed — lead plans, dev executes, qa verifies. Don't short-circuit.

## What master (watcher) verifies for this arm
1. **Full pipeline actually fires:** `vbw-lead` (plan) → `vbw-dev` (execute) → `vbw-qa` (verify) — not just `vbw-dev`.
2. **JS↔SQL parity to the cent** (abs diff < 0.005) on admin base, each row charge, production fee, contingency, totals, profit.
3. Watch for the round-1 cost signature: nested subagent fan-out self-saturating the Max plan (tokens, wall-clock).
4. Capture: total tokens + wall-clock.

## Gate (shared with native)
- `/financial-review` PASS
- JS↔SQL parity tests green (< 0.005)
- `/verify` full (incl. `npm run test:rls` if DB touched)
