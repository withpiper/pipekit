# Context handoff — Nebula → Pipekit v2.1.2 → distill validation → Piper migration

> **Machine: Nebula** (Ethan's primary Mac). This file scopes to work originating on Nebula. Pick up from this when starting a new session here, or carry the contents to another machine if needed. Self-contained: nothing outside this file is required to continue. **You** = the next Claude session. **I** = the Nebula session that last updated this on `2026-05-03`.
>
> Originally written `2026-05-02` against Pipekit `v2.0.0`. Refreshed `2026-05-03` against `v2.1.2` after Pipekit shipped three same-week minor releases (v2.1.0 / .1 / .2). **Refreshed again `2026-05-03` evening** after a 7-PR v2 vocabulary scrub series (#42-#48) plus a polish PR (this session). Pipekit is now end-to-end v2-clean. Next move: validate on `../distill` (consumer test) before kicking off Piper migration. Material changes flagged below.

---

## TL;DR

- Pipekit shipped **v2.0.0** on 2026-05-02 (was v1.8.2), then `v2.1.0`, `v2.1.1`, **`v2.1.2`** in rapid succession. The v2 daily loop replaces the v1 launch chain.
- v2 was validated end-to-end on rs-vault — Phase 1 closeout (RS-25 / 30 / 60 / 61 / 62) plus a Heavy spike (RS-63: VBW backend, antagonistic review, /pr-fix triage). Pipeline holds.
- **Three v2.1.x deltas** to know about: `/pk-exit` (replaces the bash Stop hook for session logs), `notepad.md` (replaces retired `NEXT.md`), `/pr-security-review` (new) + phase-aware `pk next` (new).
- **VBW machine plugin updated** `1.35.0 → 1.36.0` on `2026-05-02`. Cache and manifest verified.
- **v2 vocabulary scrub series (PRs #42-#48 + polish #49) shipped 2026-05-03 evening.** The post-v2-cut docs were riddled with v1 vocabulary leaks: `/launch`, `/branch`, `/g-promote-*`, NEXT.md writes baked into 7 active skills, and `/pipekit-help` recommending retired skills. Series cleaned every active `*.md` / `*.sh` / `*.json` outside `archive/` and `CHANGELOG.md`. After this, the entire active repo speaks v2. See § "Session log — Nebula" entry `2026-05-03 evening` for the per-PR breakdown.
- **Next consumer test: `../distill`.** Then Piper. distill is the validation step before Piper because it's a smaller surface to catch any remaining v2 issues without putting Piper at risk. **All Piper migration questions resolved 2026-05-03.** See § "Migration decisions" for the resolved trade-offs (Q3 multi-env collapses into Q4 GitHub Actions port; `pk ship` becomes the single trigger for Vercel + Supabase via merge-time hooks). See § "Pending Piper-side action" for the ordered execution plan starting with a Piper-side inventory.

---

## Current machine state (verified 2026-05-03)

- **Pipekit repo:** `/Users/ethanrosch/Projects/pipekit` on branch `main` at tag `v2.1.2`, with PRs #41-#49 merged on top (post-tag). Origin `git@github.com:withpiper/pipekit.git`. `bin/pk version` → `2.1.2` (PR #49 closed the prior dispatcher-vs-tag skew). **`v2.1.3` tag pending** — should be cut to mark the docs/skill scrub as a release; would let consuming projects pin against a stable tag during sync.
- **Working tree state:** clean tracked. The earlier dogfood artifacts (`method/`, `method.config.md`) were deleted in the 2026-05-03 afternoon session; `resources/nebula-piper-migration-handoff.md` (this file) is committed and tracked.
- **Pre-existing stash:** `stash@{0}: On main: pre-terminology-rename-backup` — predates this session, left alone. The same-day `pre-v2.1.2-sync` stash was confirmed redundant (working-tree files hash-matched HEAD post-pull) and dropped.
- **VBW plugin:** `1.36.0` at `~/.claude/plugins/cache/vbw-marketplace/vbw/1.36.0/`. `installed_plugins.json` updated `2026-05-02T13:25:01Z`, gitCommitSha `1e32b9c`. Stale `1.35.0` cache dir is leftover but inert (version resolution sorts SemVer).
- **GitKraken hooks:** disabled in `~/.claude/settings.json` (preserved gsd-context-monitor / session-start / session-end). If a new session lands on a different machine, replicate the change. Symptom: `pk` says PR-not-found / `gh` says rate-limit-exceeded; check `gh api rate_limit --jq '.resources.graphql.remaining'`.
- **Restart Claude Code** before relying on the new VBW statusline or any in-session VBW commands.

---

## What the v2 daily loop is

Replaces v1's `/branch → /launch → /verify → /launch --close` chain with:

```
pk next            → Linear says: next Approved issue (phase-aware as of v2.1.0)
pk branch <ID>     → worktree + branch + Linear → In Progress (idempotent)
/work <ID>         → plan + execute (in-session); routes to vbw or native backend
/verify            → pre-deploy gate
pk ship [--review] → push, open PR, Linear → UAT, optionally invoke antagonistic review
pk done <ID>       → verify merged, cleanup worktree+branch, post commits to Linear
pk promote         → dev → main batch promote (multi-tier projects)
/pk-exit           → narrative session log to Logs/Sessions/<date>_<HHMM>.md (last command of every Claude session)
```

All `pk *` subcommands are **idempotent against Linear+git ground truth**. Recovery = rerun. Read state, decide what's left, do only that.

Stage 0 (foundation) and orthogonal skills (`/light-spec`, `/brainstorm`, `/pr-fix`, `/sync-linear`, `/strategy-sync`, `/roadmap-create`, `/phase-plan`, etc.) are **unchanged** in v2 — v2 only retired the daily loop.

Canonical doc: `RUNBOOK.md`. Read it.

---

## What got retired in v2.0.0 → v2.1.2 (current)

These v1 skills moved to `archive/v1-skills/` — preserved for reference, **no longer the recommended path:**

| Retired skill    | Replaced by                                             |
| ---------------- | ------------------------------------------------------- |
| `/branch`        | `pk branch <ID>`                                        |
| `/launch`        | `/work <ID>` + `pk ship`                                |
| `/launch-native` | `/work <ID> --backend=native`                           |
| `/start-session` | (no replacement — session-start is a no-op in v2)       |
| `/end-session`   | **`/pk-exit`** (narrative session log → Logs/Sessions/) |
| `/linear-status` | `pk status`                                             |
| `/g-promote-dev` | `pk promote`                                            |
| `NEXT.md` (file) | **`pk next`** for canonical "what's next?"; `notepad.md` (gitignored) for personal scratch |

**Important correction vs the v2.0 handoff:** that draft listed `/start-session` and `/end-session` as replaced by a "Stop hook." That hook (v2.0's `scripts/pipekit-journal-hook.sh`) was retired in **v2.1.2** because it fired on every assistant turn, dumped duplicate commit lists, and couldn't write narrative content. `/pk-exit` is the canonical replacement. If a consuming project still has a Stop block in `.claude/settings.json` or a leftover `scripts/pipekit-journal-hook.sh` after `sync-method.sh v2.1.2`, `pk doctor` will flag it for cleanup.

If Piper's CLAUDE.md or any Strategy doc references any of the above v1 names, those refs are stale.

---

## What's new in v2.1.x since v2.0.0 (handoff-relevant)

### v2.1.0 (2026-05-02)

- **`/pr-security-review` skill** — security-focused antagonistic PR review for migrations, RLS policies, SECURITY DEFINER functions, GRANT/REVOKE, auth code, and Server Actions on privileged tables. 30+ rubric items across 6 surface categories. Different from `/security-review` (periodic repo audit) and `/pr-fix` (broad PR review). **Highly relevant to Piper** given supabase/auth surface area.
- **Phase-aware `pk next`** — reads `## Current Phase:` from `.vbw-planning/PHASES.md`, matches to `linear-map.json` via `Phase X.Y` prefix, groups Linear results by status (In Progress / Approved / Needs Spec) with per-group hints. Falls back to legacy global behavior if no phase context. **The v2.0 handoff listed this as backlog item #1 — now shipped.**
- **Mid-loop Linear visibility** — `pk ship --review` posts a "review-in-flight" Linear comment; `/pr-fix` Phase 6.6 posts a triage-complete summary (fixed / rejected / deferred counts). Closes the gap where Linear saw `In Progress → UAT → Done` with no record of review findings.

### v2.1.1 (2026-05-02)

- **`pk init` seeds gitignored `notepad.md`** if absent and ensures `.gitignore` excludes it. Free-form personal scratch space; never committed.
- **`NEXT.md` officially retired** in `method.md`. Consuming projects should delete any committed `NEXT.md` and rely on `pk next`. `pk init` flags stale `NEXT.md` if found, suggests cleanup, does not auto-delete.

### v2.1.2 (2026-05-03)

- **`/pk-exit` skill** — writes a narrative session log to `Logs/Sessions/<YYYY-MM-DD>_<HHMM>.md` before `/exit`. Captures summary, commits shipped, decisions/findings, outstanding work, optional QA trail. Restores the v1 `/end-session` artifact shape without the v1 baggage. **User runs as the last command of every Claude Code session; no auto-trigger** (forget = no log, accepted tradeoff).
- **Bash Stop hook retired.** `scripts/pipekit-journal-hook.sh` deleted. `pk done` now reads commits directly from `git log` for its Linear close comment (no per-branch journal cache to drift). `pk log` repointed at `Logs/Sessions/`.
- **`pk init` / `pk doctor`** create/verify `Logs/Sessions/` and flag stale Stop-hook artifacts in consuming projects (Stop block in `.claude/settings.json`, retired script, `.pipekit/journal/` cache). `.pipekit/journal/` is gitignored and dies with branches on `pk done` — harmless to leave.
- **`templates/v2/settings-snippet.json` deleted** — no Stop hook to wire. `pk init` setup steps reduced from 7 to 6.
- **`method.config.template.md`** drops the `Journal in repo` config key.

---

## VBW v1.36.0 changelog highlights (relevant to Piper migration)

- `/vbw:research N` — context-only Scout research from a numbered todo without consuming the todo. Useful when Piper's planning state needs verification (`/00-roadmap-review` follow-ups).
- `/vbw:execute` parallelism fix — only goes parallel when the dep graph permits it. Linear plans stay serial. Relevant if/when running `--backend=vbw` on a Piper Heavy issue.
- `rtk` — explicit opt-in, runtime smoke proof capture. Skip unless you want it.
- `config` — typed pseudo-menu replaced with bounded structured prompts. UX change, no breaking impact.

No breaking changes for v2's daily loop.

---

## Piper-specific concerns (read carefully before migrating)

### Concern 1: Multi-environment delivery

Piper has **Vercel + Supabase branch + LaunchDarkly**. v2's `pk ship` is single-env today. Multi-env `pk ship --env=<env>` is on the **beta.1 backlog** (see `RUNBOOK.md § Backlog`).

**Decision point:** sync v2.1.2 to Piper now and accept single-env ship until beta.1 lands? Or wait for beta.1?

**My read:** v2.1.2 is fine for Piper IF Piper's existing deploy pipeline can layer on top. `pk ship` is just "push branch, open PR, transition Linear." Multi-env handling can stay in Piper's existing tooling/scripts. Don't block on beta.1 — adopt v2.1.2 now, layer Piper's existing deploy after `pk ship`.

### Concern 2: VBW backend

rs-vault was set to `Backend: native` in `method.config.md` (just Claude subagents, no VBW pipeline). Piper presumably runs `Backend: vbw` (full vbw-lead/vbw-dev/vbw-qa). The `/work --backend=vbw` flag gives per-invocation override if you want to test the other path.

We tested `--backend=vbw` on RS-63 — vbw-dev cruised through cleanly. Confirms Piper's `vbw` config will work in v2.

### Concern 3: Stale planning state

If Piper's `.vbw-planning/` files (PHASES.md, ROADMAP.md, linear-map.json) are out of date relative to current Linear reality, vbw-lead will fail or plan badly. We hit this on rs-vault when wiring up Phase 2.5 — had to add Phase 2.5 to all three files before `/work RS-63 --backend=vbw` was meaningful.

**Before running v2 on Piper:** verify the planning state matches Linear. Run `/00-roadmap-review` to surface drift. Update PHASES.md if a new phase is current. **Bonus with v2.1.0:** phase-aware `pk next` will only behave correctly if `## Current Phase:` in `PHASES.md` matches a `Phase X.Y` prefix in `linear-map.json` — fix any drift there too.

### Concern 4: GitKraken hooks

Already disabled at the user level on this Mac. If Piper runs on a different machine, replicate. Symptom: `pk` returns "PR not found" but the PR exists, OR `gh pr view` says rate-limit-exceeded.

### Concern 5: `temp/` vs `resources/` convention

Surfaced on rs-vault during RS-63 — design handoff lived in `temp/design_handoff_rs_vault/` (gitignored), didn't travel to worktrees, broke `/work`'s context. Convention going forward:

- **`resources/`** → committed reference materials (design handoffs, spec dependencies, this handoff doc).
- **`temp/`** → fully gitignored ephemera.

If Piper has reference materials in `temp/` today, they should move to `resources/` before any worktree-based v2 work. Not blocking but worth doing as a chore.

The convention is now in informal use; the **`pk branch` worktree resource sync** that would automatically copy `resources/` into worktrees is still on the v2.1.x backlog.

### Concern 6: Migration scripts

Piper has its own `supabase/migrations/`. We just shipped a **GitHub Action** for rs-vault that auto-applies migrations on push to main + a PR-time check workflow. Piper probably needs the same — `supabase db push` is not run by Vercel.

The two workflow files at rs-vault:

- `.github/workflows/db-migrate.yml` — push to main + workflow_dispatch with `dry_run` boolean
- `.github/workflows/db-pr-check.yml` — PR-time `supabase db reset` against ephemeral postgres

Required GitHub secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`.

**Recommend porting these to Piper as soon as v2 sync is done.** Same failure mode (migration on main but not in prod DB) is a real prod-incident risk.

**Pair with `/pr-security-review`** (v2.1.0) for any migration PR — it's the right tool for migration / RLS / SECURITY DEFINER review.

### Concern 7: Stop hook cleanup if Piper synced v2.0.x

If Piper ever synced **v2.0.x** (between 2026-05-02 and now), it may carry the retired Stop hook artifacts: a Stop block in `.claude/settings.json`, `scripts/pipekit-journal-hook.sh`, and a `.pipekit/journal/` dir. After `sync-method.sh v2.1.2`, `pk doctor` will flag these. Cleanup commands documented in CHANGELOG.md § v2.1.2 § Migration.

If Piper never synced v2.0.x and goes straight from v1 to v2.1.2, this concern is moot.

---

## Recommended migration sequence for Piper

Don't do all at once. Layer it:

### Stage 1 — Sync v2.1.2 (safe, low-risk)

```bash
cd ~/Projects/piper                           # or wherever Piper lives
./scripts/sync-method.sh                      # pulls latest pipekit
# OR if Piper uses /pipekit-update: invoke that instead
```

Verify:
- `bin/pk version` should print `2.1.2` (closed the prior dispatcher-vs-tag skew in PR #49).
- `RUNBOOK.md` should be the v2 one-page flowchart and reference `/pk-exit` and `notepad.md`.
- `pk doctor` should be clean OR flag the v2.0.x Stop-hook leftovers (see Concern 7).

### Stage 2 — Verify planning state

```bash
ls .vbw-planning/                             # PHASES.md, ROADMAP.md, linear-map.json present?
cat method.config.md | grep Backend           # confirm vbw or native
cat .vbw-planning/PHASES.md | grep "Current Phase:"  # for phase-aware pk next
```

Run `/00-roadmap-review` to surface drift. Fix any mismatches between PHASES.md and current Linear reality before running v2 on a real issue.

### Stage 3 — Try one issue end-to-end

Pick a Quick or Standard tier issue (NOT a Heavy spike — RS-63 was the Heavy validation, you don't need to redo that). Run the full loop:

```bash
pk next                                       # phase-aware: groups by status
pk branch <ID>
cd .worktrees/<ID>-<slug>
claude --dangerously-skip-permissions
/work <ID>
# verdict gate, proceed
/verify
# back to parent
pk ship --review
# triage findings via /pr-fix (or /pr-security-review for migration / RLS / auth PRs)
# merge PR
pk done <ID>
/pk-exit                                      # last command of the session — writes Logs/Sessions/<date>_<HHMM>.md
```

If anything goes sideways: paste the output back into your session and diagnose. Recovery for v2 is "rerun the command" — every step is idempotent.

### Stage 4 — Port the DB migration workflows

Copy `.github/workflows/db-migrate.yml` and `db-pr-check.yml` from rs-vault to Piper. Update the project ref. Add the 3 secrets. Test with `workflow_dispatch dry_run=true` first. Pair with `/pr-security-review` on the migration PR itself.

### Stage 5 — Promote / future state

When you're confident v2 is driving Piper cleanly, promote v2.1.2 patterns into Piper's discipline:

- Strategy docs reference `pk` commands instead of `/launch`.
- CLAUDE.md updated to say v2 is the daily loop, references `/pk-exit` for session close, references `notepad.md` (not `NEXT.md`).
- `temp/` cleanup → `resources/` for committed materials.
- Delete any committed `NEXT.md`. Add `notepad.md` to `.gitignore`. Make sure `Logs/Sessions/` exists (`pk init` creates it).

---

## Backlog you should know about (v2.1.x → v2.2)

Captured in `RUNBOOK.md § Backlog`. Phase-aware `pk next`, `/pr-security-review`, mid-loop Linear visibility, `/pk-exit`, `notepad.md`, and the v2 vocabulary scrub are **shipped** — don't re-build them.

Still open:

1. **`resources/` vs `temp/` portable convention enforcement** + `pk branch` worktree resource sync (the convention exists informally; auto-copy on `pk branch` is the missing piece).
2. **Cross-spec handoff verification at flowchart level** (skill prose shipped in v2.0; flowchart promotion deferred).
3. **Visual + functional verification step in flowchart** (Playwright + diff infra — too big for a same-day cut).
4. **"Defended status quo" guardrail at flowchart level** (already in `/work` prose; flowchart promotion deferred).
5. **Automated subagent dispatch from `pk ship --review`** — full spec at `temp/ship-skill-spec.md`, requires a new `/ship` skill wrapper.
6. **Multi-env `pk ship --env=`** for Piper-style environments (beta.1 blocker).
7. **`method.md` rewrite** for v2 — *partially closed by PR #43 (structural rewrite landed)*. Stage 0 / orthogonal-skill sections still want a refresh pass for v2 voice consistency. Lower priority now.

Don't try to land all of these at once. Pick by friction — the first one you actually hit on Piper is the right one to fix first.

### Small followups from the scrub series (one-line fixes)

These are pipekit-internal cleanups identified post-merge of the scrub series. Trivial to fix; bundling here so they don't get lost.

- **`method/sop/Skills_SOP.md:205` stale callout.** PR #44 added a "Known follow-up: the script's hardcoded skill list still references v1 names" callout flagging the un-fixed state of `scripts/pipekit-next-step-nudge.sh`. PR #48 actually fixed that script but the callout in the SOP wasn't removed. Net effect: the SOP claims a TODO that's no longer pending. One-line removal in a tiny pipekit PR.
- **Tag `v2.1.3`.** The scrub series (PRs #42-#49) represents ~30 files and ~1500 lines of cleanup — semver-wise a clear patch release. Tagging marks the scrub as a release cut and gives consuming projects a stable version to pin to during sync.
- **`pk *` graceful-degradation when Linear config is blank.** Not validated. If a consuming project has no Linear workspace and runs `pk ship`, it's unclear whether `pk ship` opens the PR with a Linear-failure warning (graceful) or aborts entirely (robustness gap). Worth a probe before any project that doesn't have Linear adopts pipekit. Low priority — Piper has Linear so it doesn't bite there.

---

## What was deliberately NOT done at the v2.0.0 cut and not yet done since

- ~~Did not rewrite `method.md`~~ — **closed by PR #43** (structural rewrite around v2 daily loop landed during the scrub series). A future polish pass on Stage 0 / orthogonal-skill sections is still possible but lower priority now.
- Did not delete v1 skills. Moved to `archive/v1-skills/`. Easy to reference, easy to undo. Deliberate.
- ~~Did not audit `scripts/sync-method.sh` for v1 paths~~ — **closed by PR #48** (scripts + templates final cleanup). Confirmed no v1-path leaks; one stale comment fixed.
- Did not test v2 on Piper directly. That's still the next session's job (post-distill-validation per § "Pending Piper-side action").

---

## Files to read first on Piper

In order:

1. **`pipekit/RUNBOOK.md`** — v2 daily loop, one page (now reflects v2.1.2 reality: `/pk-exit`, phase-aware `pk next`, `notepad.md`).
2. **`pipekit/CHANGELOG.md` § v2.1.2 / v2.1.1 / v2.1.0 / v2.0.0** — what's changed since v1.
3. **`pipekit/temp/ship-skill-spec.md`** — `/ship` skill design (for when we add auto-dispatch).
4. **`pipekit/resources/nebula-piper-migration-handoff.md`** — this file.
5. **`piper/CLAUDE.md`** — Piper's conventions (read after, in case it references v1 skills that are now retired).

---

## Calibration notes — things that surprised the v2 cutover sessions

- **GitHub squash ruleset breaks parent linking.** Every promote re-conflicts on files added on both sides (`bin/pk` add/add). Workaround: pre-merge locally with conflict resolution, PR the merged branch.
- **Antagonistic reviewer overcalls.** RS-63's review marked one finding "Critical" that turned out to be invalid (AG Grid does support `var()`). `/pr-fix` correctly verified before acting. Don't blindly fix Critical findings — verify them.
- **Squash merge `merge_method=merge` via gh API** still gets squashed if the repo ruleset enforces squash-only. The API parameter is advisory, not authoritative.
- **vbw-dev didn't dispatch vbw-lead.** v2 design: `/work` does the planning natively (in your context window), VBW only executes. If you want a planning subagent, use `--deep` for parallel grounding via Agent calls.
- **Old branch-journal hook converted `/` to `-` in branch names** (`feature/RS-X-foo` → `feature-RS-X-foo.md` in journal dir). That hook is gone in v2.1.2 — `Logs/Sessions/<date>_<HHMM>.md` doesn't use branch names. Mentioned only in case you find old `.pipekit/journal/` artifacts in a consuming project.
- **v2.0.x → v2.1.2 leaves Stop-hook artifacts behind in consuming projects.** `pk doctor` flags them post-upgrade. Cleanup is manual but documented.
- **The v2 cut left v1 vocabulary scattered through docs and skills.** Looked clean from RUNBOOK but the surrounding surface (method.md, GUIDE.md, SOPs, 17 skill files, 5 templates, scripts) still spoke v1. Worst offender: 7 skills (including Stage 0's `/startup`, `/roadmap-create`) wrote `NEXT.md` to the project root — would have polluted Piper from day 1. The 7-PR scrub series caught it. Lesson for future major version cuts: schedule the vocabulary-scrub work as part of the cut, don't assume the banner-on-top approach is enough.

---

## Migration decisions (resolved 2026-05-03)

The original open questions have been worked through with Ethan. Resolutions below; remaining work is execution-side, not decision-side. See "Pending Piper-side action" for the actual to-do list.

| # | Question | Decision |
|---|---|----------|
| 1 | Stage 1 sync timing | **After Piper-side pre-work.** Inventory Piper's current state, decide what to keep, update VBW config to accept new pipekit before running `sync-method.sh`. |
| 2 | `Backend:` value in Piper's `method.config.md` | **Confirmed `vbw`.** Heavy issues continue using the VBW pipeline. No per-invocation `--backend=` override needed unless explicitly testing the native path. |
| 3 | Multi-env strategy | **A — layer on top of `pk ship`**, conditional on Q4 shipping first. With Q4's GitHub Actions in place, opening a PR via `pk ship` auto-triggers Vercel preview + Supabase migration validation; merging to main auto-triggers Vercel prod + Supabase migration apply. LD flips stay config-side and manual. Today Ethan runs `/g-deploy` (or similar) post-push to enact Supabase updates — Q4 retires that step. |
| 4 | DB migration workflows | **Port now.** Lift `.github/workflows/db-migrate.yml` + `db-pr-check.yml` from rs-vault. Add 3 GitHub secrets (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`), update project ref, test with `workflow_dispatch dry_run=true` first. Pair with `/pr-security-review` on the migration PR itself. **Q3 depends on this.** |
| 5 | `temp/` cleanup | **Yes.** Inventory Piper's `temp/`, move anything that needs to be committed into `resources/` (the new shared-references convention). Truly ephemeral material stays in `temp/` (gitignored). |
| 6 | Stop-hook cleanup | **Probably no-op, verify on Piper side.** Ethan believes Piper already moved to `/pk-exit`. Quick check from Piper repo root: `grep -l "pipekit-journal-hook" .claude/settings.json scripts/ 2>/dev/null` and `ls scripts/pipekit-journal-hook.sh 2>/dev/null`. If both empty, clean. Otherwise see CHANGELOG § v2.1.2 § Migration. |

---

## Pending Piper-side action

This work cannot happen in the Pipekit repo — it requires being in `~/Projects/piper` (or wherever Piper lives). Order matters: don't pipeline these. Finish step 1's inventory and surface anything surprising before kicking off step 2.

1. **Inventory.** Before any sync, enumerate what the migration touches:
   - `.vbw-planning/` files (PHASES.md, ROADMAP.md, linear-map.json) — drift vs current Linear reality
   - `method.config.md` — confirm `Backend: vbw`, confirm Linear IDs / paths still match
   - `CLAUDE.md` and Strategy docs — flag references to retired v1 skills (`/branch`, `/launch`, `/launch-native`, `/start-session`, `/end-session`, `/linear-status`, `/g-promote-dev`, `NEXT.md`)
   - `temp/` contents — split into "promote to `resources/`" vs "stays gitignored"
   - Stop-hook artifacts (Q6) — `.claude/settings.json` Stop block, `scripts/pipekit-journal-hook.sh`, `.pipekit/journal/`
   - **Document what `/g-deploy` (or whatever Piper uses today) actually does** — so Q4's workflows replicate the right behavior, not just the rs-vault assumption of it
2. **Sync v2.1.2 into Piper.** `./scripts/sync-method.sh` (or `/pipekit-update`). Verify with `pk doctor`. Address anything `pk doctor` flags.
3. **Port DB migration workflows (Q4).** Copy the two workflow files from rs-vault, add the 3 GitHub secrets, update project ref, test with `workflow_dispatch dry_run=true` first. Once green, the Q3 layering assumption holds: `pk ship` becomes the single trigger for all three env channels.
4. **Run one issue end-to-end.** Quick or Standard tier — full v2 loop (`pk next` → `pk branch` → `/work` → `/verify` → `pk ship --review` → `pk done` → `/pk-exit`). Avoid Heavy on the first run; rs-vault already validated the Heavy path.
5. **Promote v2 patterns into Piper's discipline.** Strategy docs reference `pk` commands not `/launch`; CLAUDE.md updated to v2 vocabulary; any committed `NEXT.md` deleted; `notepad.md` in `.gitignore`; `Logs/Sessions/` exists (`pk init` creates it).

---

## Session log — Nebula

### 2026-05-02 afternoon

1. Verified pipekit checkout at tag `v2.0.0` (commit `d8731ff`), `bin/pk version` = `2.0.0`, `archive/v1-skills/` populated as expected.
2. Updated VBW plugin `1.35.0 → 1.36.0` via `/vbw:update`. Cache, manifest, and gitCommitSha verified.
3. Wrote this handoff to `resources/nebula-piper-migration-handoff.md` per the new `resources/` convention. Filename prefixed with the machine name (Nebula) so future sessions know which machine produced it.

No commits, no Linear writes, no Piper-side actions.

### 2026-05-03 morning

1. Detected drift: pipekit shipped `v2.1.0` / `v2.1.1` / `v2.1.2` overnight while Nebula's checkout sat at `v2.0.0`. Working tree had hand-edited `bin/pk` / `scripts/sync-method.sh` matching `origin/main`, plus untracked `method.config.md`, `method/`, `resources/`.
2. Stashed the two tracked mods (`pre-v2.1.2-sync`), checked out `main`, fast-forwarded `2c5e58d..b40d985` (22 commits, ~5,700 insertions). Verified stash contents hash-matched HEAD post-pull and dropped the stash. Pre-existing `pre-terminology-rename-backup` stash left alone.
3. Refreshed this handoff against v2.1.2 reality: corrected `/end-session` retirement target (Stop hook → `/pk-exit`), promoted phase-aware `pk next` and `/pr-security-review` from backlog → shipped, added `notepad.md` retirement of `NEXT.md`, added Concern 7 (Stop-hook cleanup for v2.0.x consumers), updated migration checklist in Stage 1 / 3 / 5.

No commits, no Linear writes, no Piper-side actions.

### 2026-05-03 afternoon

1. Cleaned up dogfood artifacts in pipekit working tree: deleted `method/` and `method.config.md` (both were outputs of running `sync-method.sh` against pipekit itself — the `method/.sync-changelog.md` confirmed source = `v2.1.2` synced 07:32). `resources/` left untracked, will be committed separately per the v2.1.2 convention (it's for shared committed materials, not gitignored scratch — `notepad.md` is the only gitignored personal file).
2. Walked Ethan through the original "Open questions" section interactively. Resolved all six: Q1 sync after Piper-side inventory; Q2 `Backend: vbw` confirmed; Q3 multi-env = layer on top of `pk ship` conditional on Q4; Q4 port DB workflows now; Q5 `temp/` cleanup yes; Q6 Stop-hook cleanup likely no-op but verify on Piper side.
3. **Key insight surfaced during Q3:** `pk ship` does NOT push migrations — it only opens the PR. Ethan currently runs `/g-deploy` (or similar) post-push to enact Supabase updates. Q4's GitHub Actions retire that step entirely (`db-pr-check.yml` validates on PR open, `db-migrate.yml` applies on main merge). So Q3 and Q4 collapse: with Q4 in place, `pk ship` becomes the single trigger for all three env channels. Without Q4, multi-env is broken.
4. Restructured § "Open questions" into § "Migration decisions" (resolved table) + § "Pending Piper-side action" (5-step ordered execution plan). Updated TL;DR's last bullet to point at the new sections.

No commits at end of session (working tree showed `resources/` untracked + `method/` / `method.config.md` deleted from disk — neither was tracked at HEAD). No Linear writes. PR #41 followed shortly after to commit `resources/`.

### 2026-05-03 evening — v2 vocabulary scrub series

A spawned Explore agent pre-Piper-migration audit surfaced that the post-v2-cut docs/skills still spoke v1 in many places. Ran a 7-PR scrub series + polish PR to clean it up before any Piper migration work touches `../piper`.

**Per-PR breakdown:**

| PR | Scope | Notable |
|---|---|---|
| **#42** | BLOCKER root docs (CLAUDE.md, README.md, STARTUP.md, RUNBOOK.md, method.config.template.md, method.md) + delete V2.md | V2.md was entirely stale (alpha-status framing); deleted outright. method.config.template lost its v1 `Stack` section (`/g-promote-*` consumers all retired). |
| **#43** | method.md structural rewrite | Section structure had been mirroring the v1 pipeline (Stage 2 "Launch & Planning" / Stage 3 "Execution"). Rebuilt around v2 stages (Plan + Build / Verify + Ship). |
| **#44** | SOPs + VBW_COMMANDS | `Skills_SOP.md` lost ~100 lines documenting the retired NEXT.md infrastructure (defer queue, file-guard workaround, deferral mechanism). `Git_and_Deployment.md` rewrote the workflow + DB-migration timing tables for v2's GitHub-Actions pattern. |
| **#45** | GUIDE.md (1215-line tutorial) rewrite | Stages 1-3 narrative + Skill Quick Reference table fully rebuilt around v2 daily loop. |
| **#46** | **Skill functional bugs (7 NEXT.md writers)** | Highest-stakes PR. `/startup`, `/roadmap-create`, `/01-light-spec`, `/02-light-spec-revise`, `/phase-plan`, `/review-plan`, `/06-linear-todo-runner` were all writing NEXT.md to the project root. `/review-plan` alone had a 40-line deferral mechanism for the v1 file-guard hook conflict — entirely dead code in v2. Stage 0 skills writing NEXT.md would have polluted Piper from day 1. |
| **#47** | Skill prose cleanup (10 cross-refs) | The big win: `/pipekit-help` was telling users to run retired skills (Rule 1c → `/start-session`, Rule 3 → `/launch --close`, Rule 9 → `/launch PROJ-XXX`, Rules 10/11 → `/linear-status`). Updated to v2 commands. Plus `/spec-preflight` (11 cross-refs to /launch as the spec consumer), `/linear`, `/brainstorm`, etc. |
| **#48** | Scripts + templates | `pipekit-next-step-nudge.sh` regex updated to match v2 skills (Stop-hook nudge had been silent for v2 work). `verify-next-md-defer.sh` deleted (130 lines verifying retired functionality). `CLAUDE.md.template` rebuilt — this seeds new project CLAUDE.md files, so Piper would have inherited v1 vocabulary on bootstrap. tier-quick/standard/heavy templates updated. |
| **#49** (this session) | Polish | RUNBOOK flowchart consistency (5 boxes had mixed `pk` vs `./bin/pk` forms; standardized on bare `pk` in the daily-loop flowchart while preserving `./bin/pk` in pre-install setup steps and the dual-form reference table). `bin/pk` PK_VERSION 2.1.1 → 2.1.2 (closes the dispatcher-vs-tag skew). This handoff updated to reflect scrub-complete state. |

**Net change across the series:** ~30 files touched, ~1500 lines added/removed. Largest single deletion: `verify-next-md-defer.sh` (130 lines). Largest single addition: `method.md` Step-by-Step table rebuild (+50 lines).

**Result:** every active `*.md` / `*.sh` / `*.json` outside `archive/v1-skills/` and `CHANGELOG.md` speaks v2. The remaining v1 references are intentional historical context (transition explanations in `CLAUDE.md:25`, provenance notes in `skills/spec-preflight/skill.md`, v1↔v2 comparison tables in `skills/work/skill.md`).

**Recommend tagging `v2.1.3`** to mark the scrub as a release cut. PR #49 is merged so this is unblocked — `git tag v2.1.3 && git push origin v2.1.3` from any clean checkout. Leaving the trigger to a future session.

**Next move:** validate end-to-end on `../distill`. The plan: sync the post-#49 pipekit into distill (`./scripts/sync-method.sh` or `/pipekit-update`), run `pk doctor`, then run a real v2 daily-loop cycle through one Linear issue (`pk next` → `pk branch <ID>` → `/work` → `/verify` → `pk ship` → merge → `pk done` → `/pk-exit`). distill is the smaller-surface validation step before Piper.

---

## End of handoff

If you're reading this on Piper: the v2 loop is solid, and the post-cut artifact-cleanup is also done as of 2026-05-03 evening. The pipeline is real, the migration trade-offs are decided, AND the docs/skills no longer leak v1 vocabulary into your project root. Start with § "Pending Piper-side action" step 1 (inventory). If you're reading this on distill or another consumer: the v2 daily loop is what's documented in `RUNBOOK.md`; sync the latest pipekit, run `pk doctor`, then run one full cycle. You're picking up after four productive Nebula sessions (v2.0.0 cut → v2.1.x rapid releases → migration plan → vocabulary scrub series). Don't break the streak.

— Pipekit session, Nebula, 2026-05-03
