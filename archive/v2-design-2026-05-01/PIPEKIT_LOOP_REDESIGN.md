# Pipekit Loop Redesign — Recommendation

**Date:** 2026-04-30
**Inputs:** Internal audit (`audit-findings.md`), external survey (`external-survey.md`), first-principles redesign (`redesign-proposal.md`)
**Audience:** You, in the morning.

---

## TL;DR

**The loop is hard because three state machines (Linear, VBW, Git) were never designed to talk to each other, and you are the human bus that carries state between them.** No off-the-shelf tool fixes this for your specific stack. The right move is **not** to rebuild from scratch, **not** to switch to BMAD/Cursor, **not** to add another tier or guard. The right move is to **delete most of Pipekit** and rebuild the daily loop as **2 skills + 5 deterministic scripts + 2 hooks, ~500 LOC total** (down from ~1900 + 417-line runbook). Linear becomes the single source of truth for "what's next." NEXT.md dies. Tiers collapse. Recovery becomes "rerun the same command."

**One decision needed before shipping:** Do you keep the `dev` branch (for staging deploys, batch testing) or go feature → main directly? Default recommendation: **keep dev** because you already have squash-only Rulesets configured and the v1.8.0.6 work just paid for itself. But move the dev/main promote out of the per-issue runbook entirely.

---

## Why the loop is hard (root cause)

Not "complexity." Not "skill prose drift." Not "agents misread instructions." The audit found one structural cause:

> Five skills write to Linear issue status with no canonical ownership map. Each skill makes independent assumptions about what state the issue *should* be in. The user's mental working memory is constantly refreshing local copies of state across NEXT.md, Linear, VBW STATE.md, git, and GitHub. **The complexity is well-engineered; the cognitive load is not.**

Concrete evidence:
- **6 separate state locations** for one issue's lifecycle (Linear status, Linear description, NEXT.md, `.vbw-planning/`, `~/.cache/pipekit/`, git/GitHub).
- **5 skills mutate Linear status** with no defined ownership (`branch.md:150`, `launch.md:215`, `launch.md:359`, `g-promote-dev.md:168`, `g-promote-main`). The v1.8.2 CHANGELOG explicitly defers fixing this.
- **NEXT.md has a race window** in `/end-session` Pre-flight B that cannot be closed without architectural change.
- **3 recurring bug classes** in v1.4 → v1.8.2 history: state-sync races (6×), idempotence failures (4×), context-assumption violations (5×). Each was patched, not fixed.
- **The user's "10 steps" expand to ~20** with hidden agent invocations, decision branches, and cleanup substeps.

**The 1900-line skill prose + 417-line runbook are not the disease, they are the immune response.** Every guard clause, every "comment-on-presence" pattern, every NEXT.md refresh exists because something broke once. Cutting prose without fixing the architecture would just bring the bugs back.

---

## What's out there (and why nothing replaces it cleanly)

External survey investigated 30+ tools. Bottom line:

| Path | Coverage | Cost | Verdict |
|---|---|---|---|
| **Charlie (in Linear)** | TS-only, eats steps 3–6 | Linear free + Charlie pricing | Supplement if TS, ignore otherwise |
| **Cursor BG Agents + Linear + Graphite** | ~70% of mechanical loop | $20–40/mo | Real candidate, but **rewrites your habits**, not your tools |
| **BMAD-METHOD fork** | Methodology prose replacement | Free MIT | Spiritual sibling, but you'd trade your prose for theirs (still need Linear/VBW glue) |
| **Nimbalyst** (you flagged it) | Worktree GUI + task tracker | Open source | Confirmed: no native Linear integration. Your "lacking" assessment was right. |
| **Devin / OpenHands** | Autonomous SWE | Opaque or roadmap | Skip — neither is Linear-native today |
| **Conductor / claude-squad / ccmanager** | Worktree TUI | Free | Layer-in, not replacement |

**Real defensible niches Pipekit covers that nothing else does:**
1. Solo-dev SDLC wrapping a planning agent framework + Linear + worktrees + dev/main promote.
2. Stage-0 "Foundation contract" (greenfield/brownfield/inherited).
3. Sync-safe overrides (`sync-method.sh` + `.claude/overrides/`).

Items 2 and 3 are bespoke abstractions only you need. Item 1 is a real market gap, but it's a **~200-line gap, not a 1900-line gap**.

**Switching costs are real:** BMAD migration is a habit rewrite. Cursor switch ditches Claude Code + VBW. Charlie locks you to TS. None of these saves a tired solo dev *more time than they cost*. Stay + simplify wins on time-to-relief.

---

## The proposed system

### State model — three places, no fourth

```
LINEAR              ← source of truth: what's next, status, spec
   ↓ (read live via MCP, never mirrored)
GIT + GITHUB        ← source of truth: what's in flight (branch, worktree, PR)
   ↓
.pipekit/journal/<branch>.md   ← per-branch session log, written by Stop hook
```

**Killed:** `NEXT.md`, `~/.cache/pipekit/<repo>/pending-next-md.json`, `Logs/Sessions/*` as a separate tree, `linear-map.json` as a synced mirror.

**Why:** every state-sync bug in the v1.4 → v1.8.2 history was about reconciling a *mirror* of Linear with Linear itself. Stop mirroring.

### Two skills + five scripts + two hooks

| Step | Command | Type | LOC | What it does |
|---|---|---|---|---|
| 1 Start | `pk next` | script | ~40 | Reads Linear (assigned, Todo, prio desc) + git (current branch). Prints next command. |
| 2 Branch | `pk branch <ID>` | script | ~80 | Worktree, branch, env symlinks, Linear → In Progress. Idempotent. |
| 3+4+5 Launch/Plan/Work | `/work` | skill | ~200 | Reads spec from Linear → plans → presents plan (one-screen verdict) → dispatches dev → commits. `--deep` adds spec-validator + plan-review + security-review subagents. |
| 6 UAT | `/verify` | skill | ~150 | Runs tests, spawns QA review agent, returns verdict. |
| 7 Paperwork | (Stop hook) | hook | ~30 | Appends to `.pipekit/journal/<branch>.md` on Claude Stop. No user action. |
| 8 Ship-Dev | `pk ship` | script | ~100 | `gh pr create`, Linear → In Review, `--auto-merge` if green. |
| 9 Exit | (no command) | — | 0 | Closing the Claude session = exit. |
| 10 Shutdown | `pk done` | script | ~60 | Verifies PR merged, extracts journal highlights → Linear comment, deletes worktree + branch, Linear → Done. |

**Total daily-loop LOC: ~660** (skills: ~350, scripts: ~280, hooks: ~30). Down from ~1900.

All scripts live in a single `bin/pk` bash dispatcher.

### What gets deleted from current Pipekit

| Skill | Verdict |
|---|---|
| `/start-session`, `/end-session` | DELETE — replaced by `pk next` (script) + Stop hook (journal) |
| `/branch` | REPLACE with `pk branch` script |
| `/launch`, `/launch-native`, `/review-plan` | MERGE into `/work` skill, drop tiers, drop 3-round verdict loop |
| `/pipekit-help` | DELETE — `pk next` answers "what now?" deterministically |
| `/sync-linear`, `/linear` | DELETE — Linear is source of truth, nothing to sync |
| `/linear-status` | REPLACE with `pk status` (20-LOC script) |
| `/g-promote-dev` | KEEP if dev branch survives, otherwise DELETE |
| `/06-linear-todo-runner` | KEEP for batch mode (orthogonal to daily loop) |
| `/spec-preflight` | KEEP, shrink to ~80 lines, called by `/work --deep` |
| `/light-spec`, `/light-spec-revise`, `/spec-validator` | KEEP (Stage 0, not daily) |
| `/concept`, `/define`, `/strategy-create`, `/startup`, `/roadmap-create`, `/phase-plan` | KEEP (Stage 0, run once per project) |
| `/strategy-sync`, `/release-changelog`, `/pr-fix`, `/security-review` | KEEP (orthogonal) |
| `/brainstorm`, `/brainstorm-review`, `/pipekit-update` | KEEP (orthogonal) |
| `/skill-index`, `/task-processor` | AUDIT — likely DELETE for solo loop |

### Failure model — "rerun the same command"

Every script's first 5 lines: read current state from Linear+git, decide what's left to do, do only that. Same shape as `terraform apply` or `make`. Recovery procedures in the runbook collapse to one rule: **run the command again**.

| Failure | Old | New |
|---|---|---|
| `pk branch` mid-failure | Recovery procedure | Rerun. Worktree exists? skip. Linear correct? skip. |
| `/work` crashes during plan | Manual cleanup | Rerun. Plan committed? skip to dev. |
| `pk ship` fails after PR open | Manual Linear update | Rerun. PR exists? skip create, just update. |
| `pk done` before merge | Stuck branch | Errors clearly: "PR not merged yet." |

**Result:** the 45-line "Recovery procedures" section of the runbook deletes entirely.

### Tier collapse

Quick / Standard / Heavy → one default + one flag (`--deep`). Tiers exist to control rigor; for one user with one judgment, the user knows when they need rigor — they don't need a skill to ask. Round-2/3 plan-review stalemate detection dies. If a plan needs 3 rounds, the spec is bad → kick back to `/light-spec-revise`. Detect once, exit, tell the user.

---

## The dev/main question (one decision needed)

The redesign proposal recommends killing the dev branch (feature → main with squash). The audit doesn't take a side. Survey is neutral.

**My recommendation: keep dev, but move dev → main entirely out of the per-issue runbook.** Reasons:

- You already paid the cost of v1.8.0.6 Rulesets and it works.
- The `dev` branch gives you a staging integration point (Vercel preview deploys hit dev).
- The pain isn't dev/main, it's running `g-promote-dev` *as part of* the per-issue loop. It shouldn't be.

Concrete change: dev → main is a separate `pk promote` script (script, not skill), run on cadence (e.g. 1×/day or every 2 dev merges), independent of any single Linear issue. The per-issue loop ends at "merged to dev," not "promoted to main." The runbook's "Promote dev → main" section becomes a one-page README in `sop/Promote.md`.

If staging deploys aren't actually a thing for you, kill dev and go feature → main with squash. Open question for you.

---

## Migration plan (a 1-week sprint)

This is shippable as **v2.0.0** or as a long-running `redesign/` branch you cut over to in one swap. Pick cutover, not gradual — gradual reintroduces the dual-state-machine problem you're trying to escape.

**Day 1 — write the scripts.** `bin/pk` bash file with `next`, `branch`, `ship`, `done`, `status`, `promote`. ~300 LOC. Idempotent. Tested manually against 1 dummy Linear issue.

**Day 2 — write `/work` and `/verify` skills.** Strip everything tier-related from current `/launch`. Inline plan-review as one-screen verdict. ~350 LOC total.

**Day 3 — Stop hook for journal.** ~30 LOC bash. Configure in `.claude/settings.json`. Add `.pipekit/journal/` to `.gitignore` (or commit them — open question 4 in redesign).

**Day 4 — kill the deletes.** Move `/start-session`, `/end-session`, `/launch`, `/launch-native`, `/branch`, `/pipekit-help`, `/sync-linear`, `/linear`, `/review-plan` to a `deprecated/` directory (don't delete files yet — keep for 2 weeks in case something goes wrong).

**Day 5 — rewrite RUNBOOK.md to ≤80 lines.** Single page. Decision tree at the top. No recovery section (rerun the command is the recovery). Move dev/main promote to `sop/Promote.md`.

**Day 6 — smoke test on 3 dummy Linear issues.** Quick fix, standard feature, deep change. Each through the full loop. Time it. If any takes >2× the current path, stop and diagnose.

**Day 7 — sync to one consuming project (rs-vault).** Use it for 1 real issue. If it works, ship v2.0.0.

**Defer to v2.1+:** Charlie integration, BMAD merge, Cursor experiment, ccmanager bolt-on. None of these are blockers.

---

## What NOT to do

From the audit + survey + redesign, these are tempting but wrong:

1. **Don't add a `LinearSync` agent** to detect drift. The drift exists because of the mirror. Delete the mirror.
2. **Don't split NEXT.md into two files.** Same reason — both are still mirrors.
3. **Don't fork BMAD this week.** It's a 2-month project disguised as a refactor. Park it. Re-evaluate in 6 weeks.
4. **Don't switch to Cursor.** It's a habit rewrite. You'll be just as exhausted on day 14.
5. **Don't ship v1.9.0 as a bunch of incremental bug fixes** to current architecture. Eight v1.8.0.x patches in 2 days proved that approach is what burned you out.
6. **Don't rebuild VBW.** It works. The problem isn't VBW; it's that *the daily loop* asks the user to mediate between VBW state and Linear state. Solve the latter.
7. **Don't keep tier system "for flexibility."** Flexibility costs prose. You'll never remember which tier to pick. Default + `--deep` is enough.
8. **Don't delete `/strategy-sync`, `/release-changelog`, Stage 0 skills.** They're orthogonal and run rarely. Leave them alone.

---

## Open questions (need your input)

1. **dev branch staging deploys** — yes/no? Determines whether to kill dev or just demote `g-promote-dev` from the daily loop. 
   1. **ER**: For projects like rs-vault i would kill dev.  For financial projects like Piper, having the extra testable gates seems smart.

2. **Journal location** — `.pipekit/journal/` in-repo (commits with branch, shows in PR) or `~/.local/share/pipekit/<repo>/` out-of-repo (cleaner PRs, less portable)?
   1. **ER**: in-repo

3. **VBW commitment** — `/work` as designed *can* drop VBW agents and use native Claude Code Agent tool. Is VBW pulling its weight, or is `launch-native` the future? **This is the biggest unanswered question.** If you commit to VBW, `/work` shells out to `vbw:lead`. If you commit to native, `vbw-*` agents leave the daily loop entirely.
   1. **ER**I have not tested native. Will do today

4. **`/verify` vs. `pk verify` script** — is QA-review subagent worth it, or is "run tests + smoke" sufficient? If sufficient, drop `/verify` and skills count = 1.
   1. **ER** i think so for piper and a financial heavy project?

5. **Migration window** — cutover (v2.0.0 swap) or gradual? I recommend cutover. You confirm.
   1. **ER** Hard cutover

6. **ER** Additional Thoughts
   1. my Stage 0 setup should be standalone - does not need to be integrated into pipekit
   2. we want safe and frictionless.  the tool should be help, not extra work.


---

## Bottom line

The system isn't broken; it's well-engineered for a use case (parallel team work, multi-session coordination) that you don't have. Strip it back to **what one solo dev shipping 1–3 issues per sprint actually needs**:

- Linear is the source of truth
- Git is the in-flight state
- A Stop hook handles paperwork
- 5 idempotent scripts handle deterministic state transitions
- 2 skills handle the things only an LLM can do (plan + review code)
- Recovery is "rerun the command"
- `/work --deep` opts in to rigor when the change is scary

That's the system. Shipping it deletes ~1300 lines of skill prose, ~340 lines of runbook, and most of the v1.4–v1.8.2 patch trail's reason for existing. **It also re-enables you to ship features instead of methodology.**

When you wake up: read this, answer the 5 open questions, and we cut a `redesign/v2` branch.

---

## Finalized Plan (2026-05-01)

**North star:** *Safe and frictionless. The tool helps, never adds work.* Every skill/script header carries this line.

### Decisions locked

1. **dev branch is per-project**, declared in `method.config.md`:
   ```
   integration_branch: dev   # or 'main'
   promote_to_main: true     # if integration_branch=dev
   ```
   `pk ship` reads it; rs-vault sets `main`, Piper keeps `dev`. The skill prose is identical across projects.

2. **Journal is in-repo:** `.pipekit/journal/<branch>.md`, committed with the branch. Stop hook appends. `pk done` extracts highlights into the Linear close comment.

3. **`/verify` stays** as a skill, gated by `--deep` or by `method.config.md` (`require_qa_review: true` for financial projects). Light path runs tests + smoke and exits.

4. **Hard cutover** to v2.0.0. `deprecated/` directory holds old skills for 2 weeks, then deletes.

5. **Stage 0 stays in Pipekit but as a separate skill set.** Reorganize `skills/` into category subdirs:
   - `skills/loop/` — daily (`work`, `verify`)
   - `skills/stage0/` — foundation (`concept`, `define`, `strategy-create`, `startup`, `roadmap-create`, `phase-plan`)
   - `skills/orthogonal/` — rare/utility (`light-spec*`, `spec-validator`, `strategy-sync`, `release-changelog`, `pr-fix`, `security-review`, `brainstorm*`, `pipekit-update`)

   `sync-method.sh` defaults to `loop/` + `orthogonal/`. `--with-stage0` opts in. One repo, one version, one PR for cross-cutting changes. Clean separation without the overhead of a separate bundle.

### One decision still blocked

6. **VBW vs native (`/work` backend).** You're testing `launch-native` today. Until that's done, `/work` cannot be written. **Day 2 of the migration plan is gated on this test.**

   When you test today, run launch-native on a Standard-tier issue you'd otherwise put through `/launch --auto`. Compare:
   - Plan quality (does the planner produce something a human would accept?)
   - Dev execution (atomic commits? deviations handled?)
   - QA verdict (does the native QA agent catch what vbw-qa does?)
   - Total wall time and token cost

   Verdict path:
   - **Native ≥ VBW:** drop VBW from the daily loop entirely. `/work` uses native subagents. Saves a dependency.
   - **VBW > Native:** `/work` shells out to `vbw:lead` / `vbw:dev` / `vbw:qa`. Keep VBW; adapt the skill to be a thin wrapper.
   - **Tie:** default to native. Less to maintain.

### Revised migration sprint

Same shape as before, but reordered around the VBW gate and the Stage 0 extraction:

**Day 0 (today) — VBW vs native test.** One real issue through `launch-native`. Decide.

**Day 1 — write `bin/pk` scripts.** `next`, `branch`, `ship`, `done`, `status`, `promote`. ~300 LOC bash. Idempotent. Reads `method.config.md` for integration branch + promote policy. Smoke against 1 dummy Linear issue.

**Day 2 — write `/work` and `/verify` skills.** Backend chosen by Day 0's test. ~350 LOC total. Tier system gone. One-screen plan verdict.

**Day 3 — Stop hook + journal.** `.pipekit/journal/<branch>.md` append on Stop. `.gitignore` does NOT exclude it (in-repo, committed). `pk done` extracts highlights to Linear close comment.

**Day 4 — reorganize `skills/` into `loop/` + `stage0/` + `orthogonal/`.** Move 6 Stage 0 skills into `skills/stage0/`. Update `sync-method.sh` with `--with-stage0` flag (defaults off; defaults pull `loop/` + `orthogonal/`). Update CLAUDE.md and `method.md` to reflect the layout.

**Day 5 — move deprecated skills.** `/start-session`, `/end-session`, `/launch`, `/launch-native`, `/branch`, `/pipekit-help`, `/sync-linear`, `/linear`, `/review-plan` → `deprecated/`. Don't delete (2-week safety window).

**Day 6 — rewrite RUNBOOK.md to ≤80 lines.** Single page. No recovery section. Move dev → main details to `sop/Promote.md`.

**Day 7 — smoke + ship v2.0.0.** Run 3 dummy issues end-to-end (rs-vault config, Piper config, deep change). If green, tag v2.0.0. Sync to rs-vault and Piper. Use for 1 real issue each before declaring done.

### Definition of done

- Daily-loop LOC ≤ 700 (skills + scripts + hooks).
- RUNBOOK.md ≤ 80 lines.
- One issue through the full loop in <5 minutes of human attention (excluding agent run time).
- Recovery procedure in the runbook = empty section ("rerun the command").
- North star line present at the top of every skill and script.
- Stage 0 lives in its own repo; consuming projects opt in.

### Risks remaining

- **Linear MCP latency on `pk next`.** If MCP is slow (>2s), the script feels heavy. Mitigation: 60-second cache in `/tmp/pk-next.json` if latency proves bad. Don't pre-optimize.
- **Hard cutover regression.** If something breaks during the v2.0.0 use, you're stuck without the old skills as muscle memory. Mitigation: `deprecated/` directory keeps them callable for 2 weeks; can fall back per-issue.
- **Stage 0 reorg breaks existing consuming-project sync.** If a project re-syncs without `--with-stage0`, Stage 0 skills won't be re-pulled. Existing copies stay (sync doesn't delete on consumer side), so no functional break — but new syncs need the flag for greenfield use. Document loudly.

### What's NOT in this sprint (defer to v2.1+)

- BMAD migration evaluation (revisit in 6 weeks)
- Charlie/Cursor/ccmanager integration
- jujutsu trial
- Spec Kit replacement of `/light-spec`
- Any "improvement" not on the Day 0–7 list

When the VBW test is done today, ping me with the verdict and we cut `redesign/v2`.
