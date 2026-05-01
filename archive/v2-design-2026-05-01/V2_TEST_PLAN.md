# Pipekit v2 Alpha — Test Plan

**Tag:** `v2.0.0-alpha.3` (current)
**Date:** 2026-05-01
**Branch:** `v2/main` (long-running on `withpiper/pipekit`)
**Sync method:** **Option B** — sync onto consuming project's `dev` as a normal commit. v2 coexists with v1 (non-colliding names). Revert the sync commit if v2 breaks.

---

## Goal

Validate the v2 daily loop on **rs-vault first**, then **Piper**. Test that `pk` + `/work` + `/verify` + Stop hook can ship one Linear issue end-to-end without falling back to v1 commands.

---

## Setup (once per consuming project)

### Why Option B

- v2 file paths (`bin/pk`, `skills/work/`, `skills/verify/`, `scripts/pipekit-journal-hook.sh`) don't collide with anything v1 uses.
- All future feature branches off `dev` automatically inherit v2 — `pk` and the v2 skills are present inside worktrees.
- Failure recovery is one revert: `git revert <sync-commit-sha>` on dev.
- Compare: Option A (sync into `test/v2-validation` only) blocks at step 3 because `pk branch` creates a worktree off `dev`, which would lack v2 files.

### Steps

```bash
cd ~/Projects/rs-vault
git checkout dev && git pull --ff-only

# 1. Sync v2 alpha.2 onto dev
./scripts/sync-method.sh v2.0.0-alpha.3

# Inspect what changed (sync prints summary; also:)
git status

# Expect new files:
#   bin/pk                                  (executable)
#   .claude/skills/work/skill.md
#   .claude/skills/verify/skill.md
#   scripts/pipekit-journal-hook.sh         (executable)
#   method/templates/v2/settings-snippet.json
# Plus updates to method/method.md, etc.

# 2. Commit the sync
git add -A
git commit -m "chore: sync pipekit v2.0.0-alpha.3 (alpha — coexists with v1)"
git push

# 3. Add v2 keys to method.config.md (after the Stack section, see V2.md § examples)
#    rs-vault values:
#      Backend: native
#      Integration branch: main      (rs-vault is two-tier-via-main; or 'dev' if you want feature → dev)
#      Promote to main: false
#      Require QA review: false
#      Default deep flag: false
#      Ship environments: main
#      Linear API key env var: LINEAR_API_KEY
#      Journal in repo: true
#
#    Piper values (when Piper's turn comes):
#      Backend: vbw
#      Integration branch: dev
#      Promote to main: true
#      Require QA review: true
#      Default deep flag: false
#      Ship environments: dev,beta,main

git add method.config.md
git commit -m "chore: add v2 config keys to method.config.md"
git push

# 4. Export Linear API key (add to ~/.zshrc or shell rc for persistence)
export LINEAR_API_KEY=lin_api_xxx

# 5. Wire the Stop hook into .claude/settings.json
#    Open .claude/settings.json, merge the snippet from
#    method/templates/v2/settings-snippet.json under "hooks".

# 6. Verify setup
./bin/pk init      # walkthrough — surfaces any remaining gaps
./bin/pk doctor    # deeper check — expect all ✓ or ⚠ (no ✗)
```

If `pk doctor` shows any ✗, fix it before the smoke test. The most common gaps:
- `LINEAR_API_KEY` not exported in current shell (`source ~/.zshrc`)
- Team name / Team ID missing in `method.config.md` (read from Linear UI: Settings → API → Personal API key for the keys; team data is in the team's URL)
- Stop hook not yet wired in `.claude/settings.json`

---

## Smoke test sequence (one Linear issue, end-to-end)

For rs-vault, pick **one small Approved issue** — RS-30 (export threshold alert) is ideal because it's small, isolated, and was already flagged for the native-backend test.

### Step 1 — Pick an issue

```bash
./bin/pk next      # should print: "Next: RS-30 — Export threshold alert (>50 records)"
./bin/pk status    # should show Approved + In Progress + UAT + worktrees
```

**Pass:** prints the next issue with the correct ID and a sensible "Run: pk branch RS-XX" hint.
**Fail:** missing or wrong issue, no hint.

### Step 2 — Branch

```bash
./bin/pk branch RS-30
```

**Pass:** worktree created at `.worktrees/RS-30-<slug>`, env files (`.env`, `.env.local`, etc.) symlinked, Linear → In Progress.
**Fail:** worktree missing, Linear status unchanged, env files not symlinked.

**Idempotency check:** run `./bin/pk branch RS-30` again. Should print "Worktree already exists" + "Linear: RS-30 already in 'In Progress' (skip)" and exit 0.

### Step 3 — Enter worktree, run /work

```bash
cd .worktrees/RS-30-export-threshold-alert
claude --dangerously-skip-permissions

# Inside Claude:
/work RS-30
```

**Pass:** skill reads spec from Linear (verify by checking that the plan references actual AC text), presents a one-screen plan, asks `proceed | revise | abort`.
- On `proceed` (native backend): dispatches a `general-purpose` Task subagent OR works inline if ≤3 files. Atomic commits made.
- On `revise: <feedback>`: edits the plan, re-prints, re-asks.

**Fail:** any of: spec not fetched, multi-screen plan, round-2 verdict loop without explicit user revise, auto-shipping at the end, NEXT.md write attempt, `/end-session` invocation attempt.

### Step 4 — Verify

```bash
/verify
# OR from shell:
./bin/pk verify
```

**Pass:**
- Runs § Pre-Deploy Gate from `method.config.md`. Prints output. If gate fails, prints failing command + last 30 lines, stops.
- If gate passes AND `Require QA review: true` (or `--qa` flag), spawns QA subagent. Returns Pass/Partial/Fail with per-AC table.
- For rs-vault default (`Require QA review: false`), only the gate runs — that's expected.

**Fail:** gate not run, no verdict, hangs, or auto-ships on Pass.

### Step 5 — Ship

```bash
./bin/pk ship
# rs-vault will target main if Integration branch=main, or dev if Integration branch=dev.
# Piper would use:  ./bin/pk ship --env=dev
```

**Pass:** push succeeds, PR created with Linear-derived title + body, Linear → UAT (or "In Review").
**Fail:** push failure, PR creation failure, Linear unchanged.

**Idempotency check:** rerun `./bin/pk ship`. Should print "PR already exists: <url>" and only update Linear status if needed.

### Step 6 — Stop hook fires journal write

Exit Claude session (Ctrl+D or `/exit`). Then:

```bash
cat .pipekit/journal/feature/RS-30-*.md
```

**Pass:** file exists with timestamp + recent commits + uncommitted-file count.
**Fail:** file missing, hook didn't fire, hook printed to stdout (would break Claude's hook protocol).

`pk log` from inside the worktree shows the same content.

### Step 7 — Merge PR (manual, GitHub UI)

- rs-vault: squash-merge to main (or merge-commit to dev if integration is dev)
- Piper: merge-commit to dev (per-feature history kept; squash to main happens later)

### Step 8 — Done (cleanup)

```bash
exit               # leave worktree shell — back to repo root shell
cd ~/Projects/rs-vault
claude
./bin/pk done      # from parent
```

**Pass:**
- Verifies PR is MERGED.
- Posts journal highlights to Linear comment.
- Linear → Done.
- Removes worktree.
- Deletes local branch.

**Fail:**
- Tries to delete branch before PR is merged (refuses with clear message — that's correct).
- Runs from inside worktree (refuses with clear message — that's correct).
- Linear unchanged after PR merged.

### Step 9 — Promote (Piper only, after 1–3 dev merges)

```bash
./bin/pk promote
```

**Pass (Piper):** opens dev → main PR, runs pre-deploy gate, instructs user to squash-merge in browser.
**Pass (rs-vault, with `Promote to main: false`):** prints "Promote to main is disabled" — correct.

---

## Comparison metrics (vs v1 on a same-shape issue)

Capture for one issue per project. Use a stopwatch or note timestamps in your journal.

| Metric | v1 (`/launch --auto`) | v2 (`/work` + `pk`) |
|---|---|---|
| Wall time (issue pick → PR open) | _____ | _____ |
| Token cost (approx, from Claude Code) | _____ | _____ |
| Commands user typed | _____ | _____ |
| Plan review rounds | _____ | _____ |
| Recovery procedures triggered | _____ | _____ |
| Confidence in shipped code (1–5) | _____ | _____ |
| Felt safer? Frictionless? (free text) | _____ | _____ |

---

## Decision criteria for promoting alpha → v2.0.0 GA

v2.0.0-alpha.3 graduates to v2.0.0 (with at most a minor alpha.3 in between) if:

- ✅ Wall time on rs-vault ≤ 1.2× v1 wall time on a comparable issue
- ✅ Commands typed ≤ v1 commands typed
- ✅ Zero recovery procedures triggered (i.e., every failure was solved by rerunning the same `pk` command)
- ✅ Subjective confidence delta ≥ −0.5 (it doesn't feel scarier than v1)
- ✅ At least one Piper WIT shipped via v2 with `Backend: vbw`

If any criterion fails on a project, that project stays on v1 until the specific gap is fixed in alpha.N+1.

---

## Per-backend tests (the second-order question)

Today's separate `launch-native` test on RS-30 informs the **Backend** key for rs-vault. v2's `/work` then uses that backend automatically.

### rs-vault: native backend
- `Backend: native` in method.config.md
- `/work` dispatches a `general-purpose` Task subagent (or works inline if ≤3 files)
- Compare: spec-to-PR delta on a pattern you've used VBW with for weeks

### Piper: vbw backend
- `Backend: vbw` in method.config.md
- `/work` hands off to `vbw:vbw-dev` via Task tool
- Compare: should feel similar to current `/launch --auto` minus tier system, minus 3-round verdict loop, minus auto-chain

---

## Known limitations of alpha.2

1. **Linear state names are hardcoded.** `pk_linear_set_state` looks up "Approved", "In Progress", "UAT", "Done", "In Review" by name. If your Linear workflow uses different names, transitions will fail. Workaround: rename your Linear states to match, or wait for alpha.3 (state-name configurability).

2. **`pk done` requires explicit `cd` to parent.** It refuses if you're inside the worktree being deleted (correct safety guard). The error message tells you what to do.

3. **`/verify` reads § Pre-Deploy Gate via `awk`/`grep`.** Robust to standard Markdown formatting. If your Pre-Deploy Gate block uses unusual formatting (tabs, nested blocks), it may fail to extract — file a gap as alpha.3 input.

4. **`pk done` Linear comment uses `head -50`** of the journal — crude. alpha.3 may polish to extract decisions/reflections sections specifically.

5. **No automated test coverage on `pk` itself.** All testing is via this plan, manual.

6. **`/work --deep` security review uses subagent_type `"security-review"`.** If your project doesn't have that subagent registered, the skill falls back to `general-purpose` — works but less precise. Project-side: register a `security-review` subagent if you do `--deep` often.

---

## Rollback plan

If alpha.2 fails on any criterion in any project:

1. **Don't delete v1.** It still works (`/launch`, `/branch`, `/start-session`, `/end-session`).
2. **Revert the sync commit** if you want to fully back v2 out: `git revert <sync-commit-sha> && git push`. dev returns to clean v1 state.
3. **File the gap** as a v2.0.0-alpha.3 todo (in this file or a fresh issue).
4. **Keep using v1** on the affected project until alpha.3 ships.
5. **Do not block production work on v2 alpha.**

---

## Post-test — what to capture and send back

For each project, after the test:

- Time-stamped notes in `.pipekit/journal/<branch>.md` (Stop hook captures automatically)
- Comparison table filled in (above)
- One paragraph subjective: "did v2 feel safer and more frictionless than v1, or worse?"
- Any commands that crashed, hung, or required v1 fallback
- Any v1-vs-v2 muscle-memory friction (e.g., "I kept typing /branch instead of pk branch")

Iterate to alpha.3 within a day of the report.

---

## Quick reference card (print this, tape to monitor)

```
┌─ rs-vault v2 daily loop ─────────────────────────────────┐
│                                                          │
│ pk init / pk doctor   ← first time only                  │
│                                                          │
│ pk next               ← what's next?                     │
│ pk branch RS-XX       ← create worktree                  │
│   cd .worktrees/...                                      │
│   claude                                                 │
│     /work RS-XX       ← plan + execute                   │
│     /verify           ← gate (+ optional QA)             │
│   exit                                                   │
│ cd ~/Projects/rs-vault                                   │
│ pk ship               ← PR + Linear → UAT                │
│ (merge PR in GitHub)                                     │
│ pk done               ← cleanup + Linear → Done          │
│                                                          │
│ Recovery: rerun the command. They're idempotent.         │
└──────────────────────────────────────────────────────────┘
```
