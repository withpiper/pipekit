# cmux Parallel-Native Batch Orchestrator Prompt

A reusable Claude Code prompt for batch-shipping a cluster of small Linear WITs in parallel via cmux-orchestrated worker sessions running `/work --backend=native`. **This is a manual replacement for the dead Quick-tier + `/06-linear-todo-runner` integration**; the proper fix is v2.6.0 candidate #1 (wire tier inference back into `/work`).

## When to use this

Use this orchestrator when:

- You have 3-7 Linear WITs that are all small, all independent, all parallel-eligible, and ideally tagged as a single Wave/cycle cleanup
- Each WIT is ~10-60 min of work (Quick-Win class — anything heavier should run through `/work` solo or via VBW)
- You want them shipped today, not over the next 3 days
- The WITs are in `Approved` state in Linear with `## Acceptance Criteria` sections

Don't use this for:

- A single WIT (just run `/work WIT-XXX --backend=native` directly)
- Heavyweight WITs (>1h each — VBW dispatch via `Backend: auto` is better)
- WITs with cross-dependencies (run them serially)
- Manual-only WITs (e.g. LaunchDarkly UI archival — do those separately)

## Empirical track record

| Date | WITs | Wall-clock | Serial estimate | Speedup | Outcome |
|------|------|-----------|------------------|---------|---------|
| 2026-05-17 | 5 (Piper Wave 0F cleanup: WIT-474, 475, 480, 481, 482) | 75 min | 90-135 min | 1.5-1.8× | 5/5 clean, 3 audit-trail follow-ups filed (485/486/487), 0 incidents |

## Adaptation for non-Piper projects

The prompt below is Piper-specific in a few places. To use for another project, change:

- **WIT prefix** (`WIT-` → `RS-`, `PROJ-`, etc.) — read from project's `method.config.md` `Issue prefix:`
- **Linear team name** (`Withpiper` → project's team) — read from `method.config.md` `Team name:`
- **Repo path** (`~/Projects/piper` → `~/Projects/<project>`)
- **Worktree symlink list** — Piper needs 3 (`.env`, `.envrc`, `apps/web/.env.local`); other projects vary. Check the project's worktree-creation memory for the canonical list.
- **Phase prefix** in `02-*-PLAN.md` patterns (`02-piper-pitch-mvp` → project's current phase slug) — used in the stale-PLAN unblock step
- **Default-env URL pattern** for the UAT step (`dev.withpiper.ai` → project's dev URL)

## Known gotchas baked into the prompt

These are the empirically-confirmed pitfalls from the 2026-05-17 batch test. Each is mitigated in the prompt below:

1. **Stale `02-*-PLAN.md` `status: ready` blocks fresh worktree edits.** Until v2.6.0's `pk done --merge` write-SUMMARY-and-flip-status lands (candidate #2), workers must detect and unblock by writing the missing SUMMARY for any prior-shipped WIT whose PLAN.md still says ready. ~10-15 min wasted on this in the test before pattern was understood. **Mitigation:** before starting a batch, run a pre-flight sweep that flips every shipped-but-stale PLAN to `status: shipped`. The 2026-05-17 sweep covered 13 plans in one commit — see Piper `a6db75b` for the pattern.
2. **Sending `<digit>\n` to Claude menus from master is ambiguous.** "6\n" on a 6-option menu silently picked option 4 because rendered "Type something" / "Chat about this" rows aren't part of the numeric mapping. Use arrow-key + Enter instead.
3. **`send-key enter` needs 2-3s before next `read-screen`.** Claude repaints after the keystroke; immediate read-screen sees stale state and can mis-conclude "nothing happened."
4. **Piper's local `dev` doesn't auto-pull after `pk done --merge`.** After 5× merges, master's dev was 1 ahead + 5 behind. v2.6.0 candidate #5 will fix; until then, `git fetch && git pull --ff-only` manually at end of batch.
5. **`pipekit-cmux.md` may not be synced into the consumer project yet** (added to Pipekit main 2026-05-17, post-v2.5.0.1 tag). Reference the upstream Pipekit source path: `/Users/ethanrosch/Projects/pipekit/.claude/rules/pipekit-cmux.md` (or wherever your Pipekit checkout lives).

---

## The prompt (paste into a fresh Claude session in your project root)

The prompt assumes you're starting from your project's root directory with a clean tree. Replace the bracketed `[REPLACE]` values before pasting.

```
You are the master orchestrator for a parallel batch run of Linear WITs. Spawn worker Claude sessions in cmux panes, each running /work --backend=native on its assigned WIT, and coordinate the human gates as workers reach them.

## WITs to batch

[REPLACE with your list. Example format:]

| WIT | Title | Effort | Notes |
|-----|-------|--------|-------|
| WIT-XXX | Title | ~Nmin | category |
| ...   | ...   | ...    | ...      |

Total expected: [N] WITs, ~[X-Y] min serial estimate.

[REPLACE if any are NOT in this batch — e.g. UI-only work like LaunchDarkly flag archival should be done manually outside the runner. List those separately.]

## Backend

native per WIT. Use `/work WIT-XXX --backend=native` in each worker session. Do NOT use vbw backend.

## Canonical cmux discipline

Read /Users/ethanrosch/Projects/pipekit/.claude/rules/pipekit-cmux.md before spawning anything. Hard rules:

- Re-fetch `cmux identify --json` before splitting (refs go stale across turns)
- Use `cmux send --surface <ref>` for input — NEVER `cmux rpc surface.send_text` (routing bug)
- Pair every `send` with `cmux read-screen --surface <ref> --lines 20` to verify
- Wait 2-3s between `cmux send-key enter` and the next `read-screen` (Claude needs to repaint)
- NEVER send `<digit>\n` to a Claude menu — use `cmux send-key down/up` then `cmux send-key enter` instead. Numeric mapping is ambiguous when "Type something" / "Chat about this" rows interleave with numbered options.
- Track long-running work by PID, not by greping scrollback (sticky output lies)

## Pre-flight (do once at start)

1. `cd [REPLACE: ~/Projects/<project>] && git status` (must be clean) && `git checkout dev && git pull --ff-only`

2. For each WIT, verify in Linear via `mcp__claude_ai_Linear__list_issues`:
   - Team: [REPLACE: "Withpiper"]   (read from method.config.md Team name)
   - State is "Approved" (bump from Triage if needed via `save_issue` with the Approved state UUID)
   - Description has `## Acceptance Criteria` (if missing, STOP and surface to user — runner can't proceed without AC)

3. **Pre-flight stale-PLAN sweep.** Any PLAN.md with `status: ready` whose corresponding SUMMARY.md already exists is STALE and will block file-guard edits in fresh worktrees. Sweep them in one commit before the batch starts:

   ```bash
   cd [REPLACE: ~/Projects/<project>]
   for f in .vbw-planning/phases/[REPLACE: current-phase-slug]/02-*-PLAN.md; do
     plan_id=$(basename "$f" -PLAN.md)
     summary="${f%-PLAN.md}-SUMMARY.md"
     plan_status=$(grep -E "^status:" "$f" | head -1 | sed 's/status: *//')
     if [ -f "$summary" ] && [ "$plan_status" = "ready" ]; then
       sed -i '' 's/^status: ready$/status: shipped/' "$f"
       echo "Flipped $plan_id status: ready → shipped"
     fi
   done
   git diff --stat .vbw-planning/phases/[REPLACE: current-phase-slug]/   # verify
   git add .vbw-planning/phases/[REPLACE: current-phase-slug]/02-*-PLAN.md
   git commit -m "chore(plan): backfill status:shipped on stale PLANs (batch pre-flight)"
   git push origin dev   # admin bypass acceptable for non-code metadata sweep
   ```

   If any PLAN.md has `status: ready` but NO matching SUMMARY.md, STOP and surface — that's actual in-flight work, not stale.

   This step is v2.6.0 candidate #2 territory (`pk done --merge` should do this automatically). Until that lands, the pre-flight sweep is the workaround.

## Per-WIT orchestration sequence

For each WIT:

### Step A: pk branch + symlinks + spawn worker pane

```bash
# From master ([REPLACE: ~/Projects/<project>])
pk branch WIT-XXX
# Creates worktree + branch + sets Linear → In Progress

WT="$HOME/Projects/[REPLACE: <project>]-WIT-XXX-<slug>"   # find via `git worktree list`

# CRITICAL: [REPLACE: N] symlinks per project memory project-worktree-envrc-symlink
# Piper example (3 symlinks):
ln -s [REPLACE: ~/Projects/piper]/.env       "$WT/.env"
ln -s [REPLACE: ~/Projects/piper]/.envrc     "$WT/.envrc"
mkdir -p "$WT/apps/web"
ln -s [REPLACE: ~/Projects/piper]/apps/web/.env.local "$WT/apps/web/.env.local"
direnv allow "$WT"
```

Then spawn a cmux worker pane:

```bash
SRC=$(cmux identify --json | jq -r '.surface_ref')
WORKER=$(cmux new-split right --surface "$SRC" --focus false --json | jq -r '.surface_ref')

cmux send --surface "$WORKER" "cd $WT && claude --dangerously-skip-permissions"$'\n'
sleep 3
cmux read-screen --surface "$WORKER" --lines 20   # verify Claude is ready

cmux send --surface "$WORKER" "/work WIT-XXX --backend=native"$'\n'
```

Record `$WORKER` ref for each WIT.

### Step B: Poll worker progress

**Critical: master burns context on every `read-screen` poll. Don't poll on a fixed cadence — poll proportional to the WIT's expected effort, and prefer event-driven polls over time-driven ones.**

Per-WIT polling cadence (rough heuristic):

| WIT effort estimate | Poll interval | First poll |
|---------------------|---------------|------------|
| ~10 min (Quick) | 90s | T+60s |
| ~30 min (Medium) | 3 min | T+2min |
| ~45-60 min | 5 min | T+3min |
| >60 min | Spawn fewer of these; reconsider native-only |

The worker session has its own cmux notify hook on the Notification + Stop events (see `~/.claude/settings.json`). When a worker reaches an interactive gate or finishes its turn, your sidebar gets a ping. **Treat that ping as the natural polling trigger** — read the worker's screen right after the ping arrives, not before.

If `cmux notify` doesn't fire (e.g. the worker is mid-execution, not at a gate), fall back to the time-based cadence above. Do NOT poll every 60s reflexively — that's how master context gets blown on a 5-WIT batch.

```bash
cmux read-screen --surface "$WORKER" --lines 30
```

Look for the plan-verdict gate. When a worker reaches it, surface the plan to the user and ask for approval. Send the approval into that specific worker pane using arrow-key + Enter (NEVER `<digit>\n`):

```bash
# To select option 1 (default highlighted):
cmux send-key --surface "$WORKER" enter
sleep 2

# To select option 2 instead:
cmux send-key --surface "$WORKER" down
cmux send-key --surface "$WORKER" enter
sleep 2

cmux read-screen --surface "$WORKER" --lines 30
```

DO NOT auto-approve. Plan-verdict is a deliberate human gate.

### Step C: Worker auto-flow → PR open → UAT-state

After plan approval, the worker auto-chains /verify --auto-ship → pk ship. The worker session goes idle once Linear state is UAT and PR is open on preview. Surface to user:

> Worker WIT-XXX awaiting UAT. PR: <url>. Preview: <vercel-url>.

### Step D: User UATs (browser work, NOT master's job)

Master does NOT auto-approve UAT. Wait for explicit "WIT-XXX passes UAT" from user.

### Step E: pk done --merge from master

Once user signs off UAT for a specific WIT:

```bash
cd [REPLACE: ~/Projects/<project>]
pk done WIT-XXX --merge
```

Worker pane closes when its worktree is removed.

## Spawn concurrency

**Recommended: 3 at a time.** 5 panes simultaneously taxes screen real estate; 3 keeps each worker's screen readable. Spawn 3 initial workers, and as each one completes (pk done --merge), spawn the next.

If running ≤3 total WITs, spawn them all at once.

## Reporting protocol

Every state transition:

- Plan-verdict reached → surface plan + ask for approval
- Ship landed → surface PR URL + preview URL
- UAT signed off → run pk done --merge
- Done → next WIT spawned or final summary

Use `cmux notify` for end-of-batch:

```bash
cmux notify --title 'Pipekit' --subtitle 'parallel batch' --body 'All [N] WITs at UAT or Done'
```

## Stop conditions (escalate to user)

- Any WIT's `## Acceptance Criteria` is missing → STOP, don't proceed for that WIT
- Any worker's plan-verdict gate shows a >20-line plan → STOP, surface plan, ask user to read before approve
- Any worker fails /verify with non-trivial failures → STOP for that WIT, leave for user
- Any pk done --merge produces unexpected state (PR merge conflict, divergent dev) → STOP for that WIT
- Linear MCP becomes unreachable → STOP entire batch
- Stale 02-*-PLAN.md was found but the corresponding WIT is NOT in Linear state Done → STOP, surface ambiguity

## End-of-batch cleanup

After all workers complete:

```bash
cd [REPLACE: ~/Projects/<project>]
git fetch origin
git pull --ff-only origin dev || git pull origin dev   # master's local dev needs reconcile
```

(v2.6.0 candidate #5 will make this automatic.)

## End-of-batch summary report

Write a report covering:

- Per-WIT outcome (Done / Stuck / Reverted)
- Empirical timing (start → plan-approve → ship → UAT → Done per WIT)
- Any new findings worth folding into `/Users/ethanrosch/Projects/pipekit/resources/v2.6.0-candidates.md`
- Any working patterns worth celebrating (Step 6.5 self-checks, auto-scope-decisions, etc.)
- Total wall-clock vs sum-of-efforts estimate
- Follow-up WITs filed (with audit-trail provenance)

Begin with the pre-flight checklist. Surface state checks to me before spawning any workers.
```

---

## Iterations expected

The prompt above worked end-to-end on 2026-05-17 for Piper's 5-WIT Wave 0F cleanup. Future iterations may surface:

- Different project topologies (rs-vault is 2-tier; need different `pk promote` semantics)
- Different worker session contexts (some workers may want to dispatch `/light-spec` instead of `/work` if specs need refining mid-batch)
- Different gate patterns (some WITs may need `/db-review` or `/pr-security-review` adjuncts that this prompt doesn't surface)

Treat the prompt as a starting template, not a final spec. When you iterate, capture the new findings here so future batches benefit.

## Retirement criteria

This prompt becomes obsolete when v2.6.0 candidate #1 ships (tier inference + Quick→runner dispatch wired back into `/work`). At that point the canonical path is:

```
/06-linear-todo-runner --project <Linear-project> --max-agents 4
```

…and this orchestrator prompt is retired. Until then, this is the bridge.
