# RS-Vault Handoff — Pipekit v2.5.0 Update

**From:** Nebula / pipekit repo (Ethan + Claude session, 2026-05-15)
**To:** RS-Vault Claude session
**Purpose:** Adopt Pipekit v2.5.0 (env-as-status). Update Linear workspace, sync the methodology, reclassify in-flight issues, smoke-test the new flow.

This handoff is self-contained — read top-to-bottom, do the steps in order. Pause at every checkpoint (✋) to confirm with Ethan before continuing.

---

## What's new in v2.5.0

Linear state names now derive from `Ship environments` chain position. The state column on the Linear board literally tells you which env an issue is currently on.

| Old (v2.4.x) | New (v2.5.0) | Meaning |
|--------------|---------------|---------|
| `UAT` | `UAT` *(narrower)* | PR open on preview branch (pre-merge) |
| — | `In <FirstEnv>` (e.g. `In Dev`) | Merged to first deploy env |
| `Released` | `In <Env>` (e.g. `In Beta`) | Promoted to intermediate env (3-tier only) |
| `Done` | `Done` | Promoted to final env |

**Behavior changes:**

- `pk done` now transitions Linear `UAT → In <FirstEnv>` (or → `Done` for 1-tier) after verifying the PR is merged. **Adds `--merge` flag**: pass it and `pk done` runs `gh pr merge` for you before the state transition + cleanup. `--confirmed` is still accepted (backward compat) but is now a no-op.
- `pk promote <env>` writes `In <Env>` for intermediate hops and `Done` for the final hop (replaces v2.4.x `Released` / `Done` binary).
- `pk promote --confirmed` gate retained — refuses if any bundled issue is still in `UAT` (PR not merged).

Full release notes: `CHANGELOG.md` § v2.5.0 in the pipekit repo.

---

## Step 0 — Pre-flight (read before doing anything)

Before touching anything, verify the RS-Vault state is safe to update.

### 0a. No in-flight work that would conflict

```bash
cd ~/Projects/rs-vault
git status
git worktree list
```

- ✋ **Stop if there are uncommitted changes in `~/Projects/rs-vault`** that aren't yours — tell Ethan, don't sync over them.
- ✋ **Stop if there are active worktrees** (`.worktrees/RS-*`) that another Claude session might be using right now.

### 0b. Verify RS-Vault's env topology

```bash
grep -E "^Ship environments:" ~/Projects/rs-vault/method.config.md
```

- **2-tier (`dev,main`)** → simpler migration (just add `In Dev`; no `Released` to rename).
- **3-tier (`dev,beta,main`)** → full migration (rename `Released` → `In Beta`, add `In Dev`).
- **1-tier (`main`)** → no `In <Env>` states needed; `pk done` writes `Done` directly. Just sync the code; no Linear UI work.

Note the topology — Step 2 branches on it.

### 0c. Verify Linear access

```bash
test -f ~/Projects/rs-vault/.env.local && grep -E "^LINEAR_API_KEY=" ~/Projects/rs-vault/.env.local && echo "✓ Linear API key present" || echo "✗ Linear API key missing"
```

If missing, fix that before continuing — the reclassification work needs Linear MCP access.

### 0d. Confirm with Ethan

✋ **Report back to Ethan with:**

- Git status: clean / dirty (and what's dirty)
- Active worktrees: count + which IDs
- Env topology: 1-tier / 2-tier / 3-tier
- Linear key: present / missing

Wait for go-ahead before running Step 1.

---

## Step 1 — Sync Pipekit v2.5.0 into RS-Vault

```bash
cd ~/Projects/rs-vault
bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0
```

Expected output:

- "Source: https://github.com/withpiper/pipekit.git @ v2.5.0"
- A list of synced files: skills, sop, templates, method.md, scripts, canonical rules
- Possibly drift warnings if RS-Vault has `.claude/overrides/` — those still apply, just surfaced for awareness.

After sync:

```bash
cd ~/Projects/rs-vault
./bin/pk version
# Expected: pk 2.5.0
```

✋ **Stop and report** if `pk version` doesn't print `2.5.0`. The sync may have failed silently.

### 1a. Check for v2.5.0's new canonical rule

```bash
cat ~/Projects/rs-vault/.claude/rules/pipekit-migrations.md | head -10
```

Should exist (new in v2.4.4-ish; v2.5.0 carries it). If RS-Vault touches a versioned migration system (Supabase, Prisma, etc.), this rule is now load-bearing.

### 1b. Commit the synced files

The sync script touches files in `~/Projects/rs-vault/`. Stage and commit them as a single sync commit:

```bash
cd ~/Projects/rs-vault
git status -s
# Review what changed — should be in skills/, sop/, templates/, method.md, scripts/, .claude/rules/
git add <the synced paths>
git commit -m "chore(pipekit): sync to v2.5.0 — env-as-status

Pulls Pipekit v2.5.0 (env-as-status rename). Linear state names now
derive from Ship environments chain position. pk done regains state
transition (UAT → In <FirstEnv>); pk promote writes In <Env> instead
of Released.

Source: https://github.com/withpiper/pipekit.git @ v2.5.0

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

✋ Pause. Do NOT push yet. Ethan reviews after the Linear migration lands.

---

## Step 2 — Linear workspace migration

Branch on the env topology from Step 0b.

### 2A. If RS-Vault is **1-tier** (`main` only)

No Linear UI changes needed. `pk done` will set `Done` directly. **Skip to Step 4 (smoke test).**

### 2B. If RS-Vault is **2-tier** (`dev,main`)

Open Linear → Settings → Workspace → Teams → RS-Vault team → Workflow.

1. **Verify `Released` is unused.** RS-Vault on 2-tier wouldn't have ever written to `Released`, so the state probably doesn't exist (or exists unused). Skip rename.
2. **Add new state: `In Dev`**
   - Type: `Started`
   - Position: between `UAT` and `Done`
   - Color: green or teal (active deployment vibe)
3. **Note the new UUID** — you'll capture it in Step 3.

Final ladder: `... → UAT → In Dev → Done`.

### 2C. If RS-Vault is **3-tier** (`dev,beta,main`)

Same as Piper's migration:

1. **Rename `Released` → `In Beta`** (Linear preserves UUIDs across renames; all existing issues stay attached).
2. **Add new state: `In Dev`**
   - Type: `Started`
   - Position: between `UAT` and `In Beta`
   - Color: green/teal
3. **Note both UUIDs** for Step 3.

Final ladder: `... → UAT → In Dev → In Beta → Done`.

✋ Pause after Step 2 and confirm with Ethan that the Linear workflow looks right before continuing.

---

## Step 3 — Update `method.config.md` Workflow State IDs

```bash
nano ~/Projects/rs-vault/method.config.md  # or your editor of choice
```

Find the **Workflow State IDs** table. Add rows for the new states.

For 2-tier:

| State | ID |
|-------|-----|
| ... existing rows ... | ... |
| In Dev | `{uuid from Step 2B}` |

For 3-tier:

| State | ID |
|-------|-----|
| ... existing rows ... | ... |
| In Dev | `{uuid from Step 2C}` |
| In Beta | `{uuid from Step 2C — same as old Released after rename}` |

If a `Released` row still exists in the table, **delete it** (the state was renamed; UUID survives but is now associated with "In Beta").

Commit:

```bash
cd ~/Projects/rs-vault
git add method.config.md
git commit -m "chore(config): add In Dev / In Beta state UUIDs (Pipekit v2.5.0 migration)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Step 4 — Reclassify in-flight UAT issues

Goal: any RS-Vault issue currently in `UAT` whose PR is already merged should move to `In Dev`. This catches the gap created by syncing v2.5.0 after some issues already crossed the merge line under v2.4.x.

### 4a. List currently-UAT issues

Use the Linear MCP:

```
Tool: mcp__claude_ai_Linear__list_issues
Args: { state: "UAT", team: "RS-Vault" }   # adjust team name to match your workspace
```

For each issue returned:

1. Look at the linked PR's status.
   - If you have `gh` configured: `gh pr view <PR-number> --json state,mergedAt` should return `MERGED` for moved issues.
2. **PR merged** → move issue to `In Dev` via Linear MCP `save_issue` with the new state UUID.
3. **PR still open / no PR yet** → leave in `UAT`. UAT now means exactly that.

### 4b. Sanity-check count

```bash
# Compare what was UAT before vs after
# Before reclass: N issues in UAT
# After:           K of them moved to In Dev; (N - K) stayed in UAT
```

Report numbers to Ethan: how many UAT issues found, how many moved, how many stayed (and why — were their PRs not yet merged?).

✋ Pause after Step 4. Confirm with Ethan before smoke-testing.

---

## Step 5 — Smoke test

Pick a low-stakes RS-Vault issue (not one currently In Progress with a real worker; a sandbox ticket or a tiny chore). Walk it through the new chain.

```bash
cd ~/Projects/rs-vault
pk branch <RS-ID>
# Linear: → In Progress
```

Then in the worktree:

```bash
cd .worktrees/<RS-ID>-<slug>
claude --dangerously-skip-permissions
# Inside Claude: do trivial work, commit, then:
/verify --auto-ship
# This will run /verify, on Pass invoke pk ship → Linear: UAT
```

Back in the parent repo, after the PR is merged (use GH UI or `pk done --merge`):

```bash
pk done <RS-ID>
# Expect: Linear UAT → In Dev (for 2-tier or 3-tier)
#         Linear UAT → Done (for 1-tier)
```

For 2-tier (the assumed RS-Vault topology):

```bash
pk promote main --confirmed
# Expect: Linear In Dev → Done
```

For 3-tier:

```bash
pk promote beta --confirmed
# Expect: Linear In Dev → In Beta
pk promote main --confirmed
# Expect: Linear In Beta → Done
```

✋ Report each state transition to Ethan. Note any:

- Linear state didn't change (likely: the state name in Linear doesn't match what `pk` is writing — check Step 2's workflow names)
- Linear comment didn't post
- pk error messages
- Worktree didn't clean up

---

## Step 6 — Push

After the smoke test passes:

```bash
cd ~/Projects/rs-vault
git push
```

Update RS-Vault's `Logs/Sessions/<date>_<HHMM>.md` via `/pk-exit` before this Claude session ends.

---

## Rollback (if something goes badly wrong)

The sync and Linear migration are reversible:

1. **Revert Pipekit sync commit:**
   ```bash
   cd ~/Projects/rs-vault
   git revert HEAD   # the sync commit
   ```

2. **Reset bin/pk to the pre-v2.5.0 copy:**
   ```bash
   # Pull the v2.4.3.3 binary back
   git checkout HEAD~1 -- bin/pk  # or whatever commit had v2.4.3.3
   ```

3. **Linear UI:** rename `In Dev` back to a parking state, rename `In Beta` → `Released`. Issues survive the rename (UUIDs persist).

If you need to roll back, **stop and call Ethan in.** Don't auto-execute rollback steps — it's a coordination point.

---

## Success criteria checklist

- [ ] `pk version` prints `2.5.0` in RS-Vault
- [ ] `~/Projects/rs-vault/.claude/rules/pipekit-migrations.md` exists
- [ ] Linear workflow has `In Dev` (and `In Beta` for 3-tier)
- [ ] `method.config.md` has new state UUIDs
- [ ] No issues stuck in `UAT` whose PR is already merged (reclassified to `In Dev`)
- [ ] Smoke test issue walked the full chain with correct state transitions at each step
- [ ] Sync + config commits on the RS-Vault branch, ready to push

When all six are ticked, ping Ethan with the success report and push.

---

## Open questions to flag if you hit them

- **Sync script complains about `.claude/overrides/` drift.** This is expected if RS-Vault overrides a canonical file. Surface the drift list to Ethan; don't auto-resolve.
- **Linear state UUID format unexpected.** Linear UUIDs are standard 36-char hex with dashes. If you see something different, double-check you copied from the right URL.
- **`pk done` doesn't transition the state.** Check that `In Dev` (or `Done` for 1-tier) exists in Linear AND the case matches exactly (`In Dev`, not `in dev` or `IN DEV`). Pipekit uses case-sensitive state matching.
- **`pk promote` writes "Released" or errors with "state not found"** despite v2.5.0 sync. Re-run `./scripts/sync-method.sh v2.5.0` — the sync may have been incomplete. Check `pk version` again.
- **Migration drift in RS-Vault's DB.** Read `.claude/rules/pipekit-migrations.md` for the new frozen-file invariant — applies if RS-Vault has migrations.

End of handoff.
