# Pipekit v2.5.0 Migration — Findings from RS-Vault

**From:** RS-Vault (Ethan + Claude, 2026-05-15)
**To:** Pipekit maintainer
**Status:** Migration succeeded end-to-end. State transitions verified across the full chain (Approved → In Progress → UAT → In Dev → Done). Five issues surfaced during execution — bugs and doc gaps — that warrant follow-up in Pipekit itself.

---

## TL;DR

| # | Issue | Severity | Where it lives |
|---|-------|----------|----------------|
| 1 | `sync-method.sh` syncs to its own repo when invoked by absolute path | **Bug** (script) | `scripts/sync-method.sh` |
| 2 | `pk promote` flips Linear to final state at PR-open, not PR-merge | **Design quirk** (pk) | `bin/pk` `promote` cmd |
| 3 | `bin/pk` shows as modified in fresh worktrees | Cosmetic | worktree creation flow |
| 4 | Protected-branch projects need a sync PR, not a direct push | **Doc gap** | handoff template |
| 5 | Workspaces with more than UAT/In Dev/Done started-states aren't flagged | Doc gap | handoff template |

---

## 1. `sync-method.sh` syncs into the wrong directory when run by absolute path

**Repro.** Following the v2.5.0 handoff exactly:

```bash
cd ~/Projects/rs-vault
bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0
```

Script output reports "SYNCED" for every file, including `.claude/rules/pipekit-migrations.md`. But afterwards:

- `./bin/pk version` → still prints `2.4.3.2`
- `.claude/rules/pipekit-migrations.md` does not exist in rs-vault
- `git status -s` in rs-vault shows nothing changed
- Meanwhile, `~/Projects/pipekit/` has uncommitted changes to its own `pipekit/`, `.claude/rules/`, etc.

**Root cause.** The script computes its target from its own location:

```bash
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
```

So when invoked as `~/Projects/pipekit/scripts/sync-method.sh`, `PROJECT_ROOT` resolves to `~/Projects/pipekit` — the pipekit repo itself — regardless of `cwd`.

**Workaround (what we did).** Use the project's local copy of the script that the previous sync installed:

```bash
cd ~/Projects/rs-vault
bash scripts/sync-method.sh v2.5.0   # this one resolves PROJECT_ROOT to rs-vault correctly
```

**Suggested fix.** Either:

- Make `PROJECT_ROOT` read from `$PWD` (or env var override) so absolute-path invocation works; OR
- Update the handoff template's Step 1 wording to `bash scripts/sync-method.sh v2.5.0` (relative, from inside the project), and add a check that errors out if `PROJECT_ROOT` looks like the pipekit repo itself.

Either would have caught this. The current handoff phrasing (`bash ~/Projects/pipekit/scripts/sync-method.sh v2.5.0`) is actively a trap.

**Knock-on effect on pipekit repo.** After the wrong-direction sync, pipekit had ~20 files modified in its own working tree. Those edits were never committed; reset on your end if you re-pull.

---

## 2. `pk promote` is optimistic about Linear

**Observed.** Running `pk promote main --confirmed` (2-tier topology) on rs-vault:

1. Opened promote PR (dev → main, 9 commits).
2. Immediately wrote `Linear: RS-117 In Dev → Done`.
3. Printed "Open the PR in browser and merge with 'Create a merge commit'."

Linear is now `Done` even though the PR is still open. If the promote PR is held up (CI flake, reviewer feedback, decision to abort), Linear is ahead of reality. We reverted RS-117 to `In Dev` manually, then re-ran `pk promote` after PR review, which optimistically re-flipped it to `Done` *before* the merge actually happened.

This is the v2.5.0-renamed version of the same v2.4.x behavior — pre-rename it would have written `Released` at the same wrong moment. The semantic stakes are slightly higher in v2.5.0 because state names now imply "the code is on env X" rather than the looser "released."

**Suggested fix.** Two options:

- **Two-phase transition.** `pk promote` writes `In <NextEnv>` or similar interim state at PR-open, then a separate post-merge hook (or `pk promote --finish`) writes `Done`. Mirrors the `pk ship` → `pk done` split for the first hop.
- **Wait-and-watch flag.** `pk promote main --confirmed --wait` blocks until the PR merges, then transitions. Trades CLI ergonomics for correctness; would also need an interrupt-safe state file so re-running picks up where it left off.

If the existing behavior is by design (avoiding a second human step), document it explicitly in the handoff so users know "Linear says Done but the merge is still pending" is normal between `pk promote` and PR merge.

---

## 3. `bin/pk` drift in fresh worktrees

**Observed.** After `pk branch RS-117` created a worktree off `dev` (commit `3dc9610`, which predates the v2.5.0 sync), `git status` inside the worktree showed:

```
 M bin/pk
```

The worktree's checked-out tree had the old v2.4.3.2 binary, but the file on disk was the new v2.5.0 binary — somehow the install/sync touched the worktree's working tree without going through git. Caused a moment of confusion ("did I edit bin/pk? no — how is it modified?").

We worked around by running `git checkout -- bin/pk` inside the worktree before pulling in the synced dev branch.

**Suggested fix.** If `pk install --force` (or `sync-method.sh`) is rewriting `bin/pk` on disk, it should either:

- Skip git-tracked copies and only update the user-PATH copy at `~/.local/bin/pk`; OR
- Stage the update through the parent repo (commit on the sync branch) so worktrees inherit it cleanly when they update.

Not blocking — just surprising.

---

## 4. Protected-branch repos can't `git push` the sync commits directly

**Observed.** rs-vault's `dev` branch has GitHub branch protection requiring PR + the `pre-deploy-gate` status check. The handoff's Step 6 (`git push`) fails:

```
remote: error: GH013: Repository rule violations found for refs/heads/dev.
remote: - Required status check "pre-deploy-gate" is expected.
remote: - Changes must be made through a pull request.
```

So the sync commits had to be moved to a separate branch (`chore/pipekit-sync-v2.5.0`) and opened as a PR (`#208`), which adds two extra hand-off points (creating the PR, waiting for CI, merging) before the smoke test can run on a dev branch that actually carries v2.5.0.

**Suggested fix.** Handoff template should detect `dev` branch protection (or just always assume it exists) and write Step 6 as:

```bash
cd ~/Projects/<project>
git checkout -b chore/pipekit-sync-<version>
git push -u origin chore/pipekit-sync-<version>
gh pr create --base dev --title "chore(pipekit): sync to <version>" --body ...
```

Plus a note that the sync PR must merge before any smoke-test `pk done --merge` runs, because the promoted state UUIDs only exist on dev once the config commit lands.

---

## 5. Workspaces with extra "started"-type states aren't flagged

**Observed.** rs-vault's Linear team has three `started` states: `In Progress`, `Building`, and (newly added) `In Dev`. The handoff assumed only the canonical pair (`UAT` and the new `In Dev`). Not blocking — pk's transitions matched on exact state name, not type — but worth flagging during pre-flight so the user knows the workflow visualisation will look denser than the handoff diagram.

**Suggested fix.** Step 0 pre-flight could list all `started`-type states (via the existing Linear MCP `list_issue_statuses`) and call out any that aren't on the canonical ladder, so the user can decide whether to retire them.

---

## What worked perfectly

For balance: most of the migration was uneventful once the sync got into the right directory.

- `pk done --merge RS-117` cleanly transitioned `UAT → In Dev` with the new state name and cleaned up the worktree. **This is the new v2.5.0 behavior and it worked first try.**
- `pk promote main --confirmed`'s `--confirmed` gate works as advertised — refused to write `Done` for an issue still in `UAT`.
- `pk version` correctly reflects 2.5.0 after sync (once `bin/pk` lands).
- `pipekit-migrations.md` is a useful new rule for an SQL-migration project like rs-vault.
- Linear state names now reading "In Dev" / "Done" rather than "Released" / "Done" is a real ergonomic win — the status column tells you exactly where the code lives.

---

## Recap for the v2.5.0 handoff template

If you fold these into the next handoff template (`nebula-*-pipekit-v2.5.0-handoff.md`), the next project gets a smoother run:

1. Step 1 wording: invoke `bash scripts/sync-method.sh v<version>` (relative), not the pipekit-absolute path. ← biggest win
2. Step 6: assume protected `dev`, route through a sync PR.
3. Step 5 caveat: between `pk promote` and PR merge, Linear shows the terminal state before it's true. Either document the gap or split the transition.
4. Step 0c: list all `started`-type states so the user spots workspace particularities.

That's it — overall a clean migration. Thanks for the env-as-status rename; the state column on the Linear board is meaningfully better.

End of handoff-back.
