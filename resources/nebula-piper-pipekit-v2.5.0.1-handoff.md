# Piper Handoff — Pipekit v2.5.0.1 Update

**From:** Nebula / pipekit repo (Ethan + Claude session, 2026-05-15)
**To:** Piper Claude session (cwd: `~/Projects/piper`)
**Purpose:** Adopt Pipekit v2.5.0.1 (env-as-status). Sync the methodology, finish the partial Linear migration, reclassify in-flight `UAT` issues, smoke-test the new flow.

This handoff is self-contained — read top-to-bottom, do the steps in order. Pause at every ✋ checkpoint to confirm with Ethan before continuing.

**Piper-specifics already true (don't redo):**
- 3-tier topology (`dev,beta,main`)
- Linear `Released` state has already been renamed to **`In Beta`** (manual UI edit earlier today)
- Linear **`In Dev`** state has already been created (manual UI edit earlier today)
- Branch protection on `dev` (sync commits route through a PR, not a direct push)
- WIT-414 is the known-merged issue still sitting in `UAT` — needs reclassification to `In Dev`. There may be others from PRs Ethan shipped after WIT-414.

**Bug fixes folded in from RS-Vault's v2.5.0 migration:**
- F1: v2.5.0.1 patches `sync-method.sh` so absolute-path invocation works correctly + refuses to sync into pipekit itself
- F4: sync commits route through a PR (Piper's `dev` branch is protected — RS-Vault hit this)
- F5: pre-flight lists all started-type Linear states (RS-Vault has extras; Piper likely does too)
- F2: documented caveat — `pk promote` writes terminal state at PR-open, not merge

Full RS-Vault learnings: `~/Projects/pipekit/resources/rs-vault-v2.5.0-migration-followup.md`.

---

## What's new in v2.5.0.1

| State (v2.5.0+) | Means |
|----------------|-------|
| `UAT` | PR open on preview branch (pre-merge) |
| `In Dev` | Merged to dev — first deploy env |
| `In Beta` | Promoted to beta (Piper-specific, 3-tier) |
| `Done` | Promoted to main — final |

**Behavior:**
- `pk done` now transitions Linear `UAT → In Dev` after verifying merge. Optional `--merge` flag runs `gh pr merge` first.
- `pk promote beta --confirmed` writes `In Beta` (was: `Released`).
- `pk promote main --confirmed` writes `Done`.
- `--confirmed` gate on `pk promote` refuses if any bundled issue is still in `UAT` (PR not merged).
- v2.5.0.1: `sync-method.sh` honors `$PWD` and refuses to sync into pipekit itself (RS-Vault F1 fix).

---

## Step 0 — Pre-flight

### 0a. Git state

```bash
cd ~/Projects/piper
git status -s
git worktree list
git rev-parse --abbrev-ref HEAD
```

✋ **Stop and report if:**
- Anything other than untracked `Logs/Sessions/` shows in `git status`
- Worktrees other than the parent itself are listed
- Current branch is not `dev`

(Ethan confirmed all Piper worktrees are shut down and git is pushed — verify this matches.)

### 0b. Verify Piper's env topology

```bash
grep -E "^Ship environments:" ~/Projects/piper/method.config.md
```

Should print `Ship environments: dev,beta,main`. If different, **STOP** — the handoff assumed 3-tier.

### 0c. Audit current Linear started-type states (F5)

Use Linear MCP to list all started-type workflow states for the Piper team:

```
Tool: mcp__claude_ai_Linear__list_issue_statuses
Args: { team: "Withpiper" }
```

⚠ **Team-name gotcha:** the Linear team name is **`Withpiper`**, NOT `Piper`. The 2026-05-15 migration session hit this — `team: "Piper"` returns empty. Before any Linear MCP call in this handoff, verify with:

```bash
grep -E "^Team name:" ~/Projects/piper/method.config.md
```

Whatever that prints is the canonical name (don't guess from the project nickname).

Report back to Ethan: full list of started-type states. Expected: `In Progress`, `Building`, `UAT`, `In Dev`, `In Beta`. Anything extra (e.g. `In Review`, `Code Review`, `QA`) is fine but worth surfacing so we know what the board looks like.

### 0d. Verify the two pre-migrated states have UUIDs

Check `~/Projects/piper/method.config.md`'s Workflow State IDs table:

```bash
grep -A 30 "Workflow State IDs" ~/Projects/piper/method.config.md | head -40
```

Look for rows for `In Dev` and `In Beta`. If they're missing or marked `TBD`, you'll add them in Step 3.

### 0e. Verify Linear access

```bash
test -f ~/Projects/piper/.env.local && grep -E "^LINEAR_API_KEY=" ~/Projects/piper/.env.local && echo "✓ Linear API key present" || echo "✗ MISSING"
```

✋ **Report back to Ethan with all five 0a-0e outputs.** Wait for go-ahead before Step 1.

---

## Step 1 — Sync Pipekit v2.5.0.1 into Piper

### 1a. Create a sync branch (F4: Piper's `dev` is branch-protected)

```bash
cd ~/Projects/piper
git checkout dev
git pull --ff-only
git checkout -b chore/pipekit-sync-v2.5.0.1
```

### 1b. Run the sync

```bash
bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0.1
```

Expected output:

- "Source: https://github.com/withpiper/pipekit.git @ v2.5.0.1"
- "Target: /Users/ethanrosch/Projects/piper"   ← **must say piper, NOT pipekit**. v2.5.0.1 fixes this. If it says pipekit, STOP and call Ethan in.
- File-by-file sync output, including new `.claude/rules/pipekit-migrations.md`
- Drift warnings only if Piper has `.claude/overrides/`

After sync:

```bash
cd ~/Projects/piper
./bin/pk version   # expected: pk 2.5.0.1
```

✋ **Stop and report** if `pk version` doesn't print `2.5.0.1`.

### 1c. Stage and commit the sync

```bash
cd ~/Projects/piper
git status -s
# Review the synced files — should be skills/, sop/, templates/, method.md,
# RUNBOOK.md, GUIDE.md, STARTUP.md, scripts/sync-method.sh, scripts/pipekit-*.sh,
# .claude/rules/pipekit-*.md, bin/pk, possibly CLAUDE.md
git add <the listed files>   # be explicit; don't use git add -A
git commit -m "$(cat <<'EOF'
chore(pipekit): sync to v2.5.0.1 — env-as-status + sync-method.sh patch

Pulls Pipekit v2.5.0.1. Two methodology changes:

1. v2.5.0 env-as-status: Linear state names now derive from Ship
   environments chain position. UAT (PR open on preview) → In Dev
   (merged to dev) → In Beta (promoted to beta) → Done (promoted
   to main). Released retired (renamed to In Beta in Linear UI).
   pk done regains state transition (UAT → In Dev) with --merge
   opt-in. pk promote writes In <Env> instead of Released.

2. v2.5.0.1 sync-method.sh fix: PROJECT_ROOT now defaults to
   $PWD; refuses to sync Pipekit into itself if the cwd's git
   origin matches METHOD_REPO. RS-Vault v2.5.0 Finding #1.

Source: https://github.com/withpiper/pipekit.git @ v2.5.0.1
EOF
)"
```

✋ **Do NOT push yet.** Next step adds the config commit.

---

## Step 2 — Linear migration (already mostly done)

### 2a. Confirm the pre-migration

In Linear UI (Settings → Workspace → Teams → Piper → Workflow), verify the final ladder reads:

```
... → In Progress → Building → UAT → In Dev → In Beta → Done
```

The `Released` state should no longer exist by name (it was renamed `In Beta` earlier today — Linear's UUID survives).

✋ Report what you see. If `Released` still exists as a separate state, or `In Dev` is missing, STOP and call Ethan in.

### 2b. Note the UUIDs

In Linear, click `In Dev` and `In Beta` in workflow settings. The URL fragment is the UUID. Note both — needed for Step 3.

---

## Step 3 — Update `method.config.md` Workflow State IDs

Edit Piper's `method.config.md`:

```bash
nano ~/Projects/piper/method.config.md
```

Find the **Workflow State IDs** table. Make these changes:

1. **If a `Released` row exists**: rename to `In Beta` (keep the UUID — Linear preserved it across the rename).
2. **Add an `In Dev` row** with the new UUID from Step 2b.

Expected final state — Piper's table should have rows for:

```
| State        | ID         |
|--------------|-----------:|
| Triage       | ...        |
| Ideas        | ...        |
| ...          | ...        |
| Building     | ...        |
| In Progress  | ...        |
| UAT          | ...        |
| In Dev       | {NEW UUID} |
| In Beta      | {RENAMED — same UUID Released had} |
| Done         | ...        |
| Canceled     | ...        |
| Duplicate    | ...        |
```

Commit:

```bash
cd ~/Projects/piper
git add method.config.md
git commit -m "chore(config): add In Dev UUID + rename Released→In Beta (Pipekit v2.5.0.1 migration)

In Beta UUID matches the renamed Released state. In Dev is new.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Step 4 — Push the sync branch + open PR (F4: branch-protected dev)

```bash
cd ~/Projects/piper
git push -u origin chore/pipekit-sync-v2.5.0.1
gh pr create --base dev --title "chore(pipekit): sync to v2.5.0.1 — env-as-status" --body "$(cat <<'EOF'
## Summary
- Syncs Pipekit v2.5.0.1: env-as-status rename + sync-method.sh wrong-target patch (RS-Vault F1)
- Adds In Dev / In Beta state UUIDs to method.config.md
- Updates synced methodology docs + skills + canonical rules

## Behavior changes
- pk done now transitions Linear UAT → In Dev (was: cleanup-only)
- pk promote writes In <Env> instead of Released
- pk done --merge flag (opt-in) runs gh pr merge first
- pk promote --confirmed refuses if any bundled issue still in UAT

## Migration runbook
See `~/Projects/pipekit/resources/nebula-piper-pipekit-v2.5.0.1-handoff.md`
on the source machine for the full migration flow. Linear UI changes
(Released → In Beta rename + In Dev added) executed manually earlier
in the same session.

## Test plan
- [ ] CI green
- [ ] After merge: smoke-test a sandbox WIT through pk branch → pk ship → pk done → pk promote beta → pk promote main
- [ ] After merge: reclassify currently-UAT issues whose PRs are merged → In Dev (WIT-414 known case)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Wait for the PR's CI checks to go green. Then merge it (via GH UI or `gh pr merge --merge`).

✋ Report when the PR is open. Hold here until Ethan confirms merge.

---

## Step 5 — Reclassify in-flight UAT issues (after sync PR is merged)

Once the sync PR is merged to `dev`, pull dev locally:

```bash
cd ~/Projects/piper
git checkout dev
git pull --ff-only
```

### 5a. List currently-UAT Piper issues

```
Tool: mcp__claude_ai_Linear__list_issues
Args: { state: "UAT", team: "Withpiper" }   # NOT "Piper" — see Step 0c
```

For each issue:

1. Check the linked PR's status (Linear issue panel shows it, or `gh pr view <#> --json state`).
2. **PR merged** → move issue to `In Dev` (Linear MCP `save_issue` with the `In Dev` state UUID from Step 3).
3. **PR still open / no PR** → leave in `UAT`. UAT now means exactly that.

**Known target: WIT-414** (PR #279 merged 2026-05-14). Move to `In Dev`.

### 5b. Sanity check

After all reclassifications, the `UAT` state should only contain issues with open PRs (or no PR yet).

✋ Report: how many issues started in `UAT`, how many moved to `In Dev`, how many stayed in `UAT` (and confirm each remaining one has a still-open PR).

---

## Step 6 — Smoke test the new flow

Pick a low-stakes Piper WIT (something tiny or a sandbox issue — not anything currently in flight elsewhere). Walk it through the full chain.

```bash
cd ~/Projects/piper
pk branch <WIT-ID>
# Linear: → In Progress
```

In the worktree:

```bash
cd .worktrees/<WIT-ID>-<slug>
claude --dangerously-skip-permissions
# Inside Claude: trivial work, commit, then:
/verify --auto-ship
# /verify on Pass → pk ship → Linear: UAT
```

Back in the parent repo, after PR review + merge (or `pk done --merge`):

```bash
cd ~/Projects/piper
pk done <WIT-ID>
# Expect: PR merge verified, worktree cleaned up, Linear: UAT → In Dev
```

Promote chain:

```bash
pk promote beta --confirmed
# Expect: Linear In Dev → In Beta
# ⚠ F2 CAVEAT: This writes In Beta IMMEDIATELY at PR-open, even though
# the dev→beta PR isn't merged yet. Linear is ahead of reality until
# the promote PR merges. This is documented behavior since v2.3.0.
# If you abort the promote, manually revert the state.

# After the dev→beta PR actually merges:
pk promote main --confirmed
# Expect: Linear In Beta → Done
# Same F2 caveat applies — Done is written at PR-open.
```

✋ Report each state transition AND the F2 timing observation. Note any anomalies.

---

## Step 7 — Wrap

After the smoke test passes:

```bash
cd ~/Projects/piper
# Smoke-test branch (if you created one for Step 6) should be cleaned up by pk done
git status                       # should be clean
git log --oneline -5
```

Run `/pk-exit` to write the session log.

Final report to Ethan: success-criteria checklist below, plus any anomalies.

---

## F2 caveat — read before Step 6

`pk promote` writes the terminal state name (e.g. `In Beta` or `Done`) to Linear at the moment it opens the promote PR — NOT at the moment that PR merges. This means:

- For ~5 min (until the promote PR merges), Linear shows the WIT as `In Beta` while the code is actually still on dev.
- If the promote PR is held up (CI flake, reviewer feedback, abort), Linear is ahead of reality.

This is documented behavior since v2.3.0 and applies in v2.5.0+ identically — only the state name changed (Released → In Beta). It is **not** a bug introduced by v2.5.0.

If a promote PR is aborted, manually revert the WIT's state in Linear before re-running `pk promote`.

A future v2.6.0 may split this into a two-phase transition (open PR + intermediate state, then post-merge writes terminal). Tracked as Finding F2 from RS-Vault's v2.5.0 migration.

---

## Rollback

If something goes badly wrong before Step 4's PR is merged:

```bash
cd ~/Projects/piper
git checkout dev
git branch -D chore/pipekit-sync-v2.5.0.1   # discard the sync branch locally
git push origin --delete chore/pipekit-sync-v2.5.0.1   # discard remotely
```

In Linear: rename `In Beta` back to `Released`, delete the `In Dev` state. Issues survive renames (UUIDs persist).

After the sync PR is merged, rollback is harder — call Ethan in. The sync touched 20+ files; reverting needs a careful revert commit, not a delete.

---

## Success criteria

- [ ] `pk version` prints `2.5.0.1` in Piper
- [ ] `~/Projects/piper/.claude/rules/pipekit-migrations.md` exists
- [ ] Linear workflow has `In Dev` and `In Beta` (no `Released`)
- [ ] `method.config.md` has correct UUIDs for `In Dev` and `In Beta`
- [ ] Sync PR merged into `dev`
- [ ] WIT-414 reclassified `UAT → In Dev`
- [ ] All other previously-`UAT` issues with merged PRs reclassified
- [ ] Smoke test issue walked the full chain with correct state at each step
- [ ] F2 timing observation noted in smoke-test report

When all eight are ticked, ping Ethan with the success report.

---

## Open questions to flag

- **`sync-method.sh` self-update guard** updates the script in-place. Piper's local `scripts/sync-method.sh` may have been from the pre-v2.5.0.1 version pre-sync. After the sync, it should be v2.5.0.1's version with the safety check. Verify by re-running with no args after sync; should see "Target: /Users/ethanrosch/Projects/piper" not pipekit.
- **Extra started-type Linear states** beyond `In Progress / Building / UAT / In Dev / In Beta` — note them but don't retire them as part of this migration (separate decision).
- **Stale `Released` references in Piper's `method.config.md`** — if you find a `Released` row in any table or block, that's stale; clean it up in the same Step 3 config commit.
- **F2 timing observation** — report the time gap (in seconds or minutes) between `pk promote` writing the state and the actual PR merging. Useful data for the v2.6.0 design decision on whether to two-phase the transition.

End of handoff.
