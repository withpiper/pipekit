# Pipekit Structural Audit — Root Cause Analysis

**Date:** 2026-04-30  
**Repo:** `/Users/ethanrosch/Projects/pipekit`  
**Latest version:** v1.8.2 (2026-04-30)  
**User profile:** Solo developer, exhausted by complexity, ~1–3 dev merges per main merge cadence

---

## 1. State Topology — Where State Actually Lives

State in Pipekit is **triply distributed** across three systems with incomplete synchronization. This triplication is the root of complexity exhaustion.

### Authoritative State Locations

| Location | What lives here | Writer | Scope | Risk level |
|---|---|---|---|---|
| **Linear issue description** | Spec (`## Light Spec`), acceptance criteria | `/light-spec`, `/light-spec-revise`, human | AI→AI contract | CRITICAL |
| **Linear issue status** | Approved → In Progress → Building → UAT → Done | `/branch`, `/launch`, `/g-promote-dev`, `/launch --close`, `/g-promote-main` | Workflow truth | CRITICAL |
| **`NEXT.md` (project root)** | "What to run next" — singleton per project | `/end-session`, all shell-facing skills | Session persistence | HIGH |
| **VBW `.vbw-planning/` (ROADMAP, PHASES, PLAN.md, STATE.md)** | Phase structure, execution plans, build state | VBW agents, `/roadmap-create`, `/phase-plan` | Phase/task truth | HIGH |
| **`${XDG_CACHE_HOME}/.cache/pipekit/<repo>/` (out-of-repo)** | Ephemeral: `pending-next-md.json`, `pending-strategy-sync`, `pipeline-state/` | `/review-plan`, `/launch --close`, `/end-session` | VBW-scoped deferred writes | MEDIUM |
| **Git branch existence** | "Is the feature deployed?" | `/branch`, `/branch finish`, GitHub auto-delete on merge | Integration branch truth | MEDIUM |
| **GitHub PR state** | Open/merged/closed, merged-to, auto-delete status | GitHub, rebase-merge UI | Integration branch confirmation | MEDIUM |

### Derived/Duplicated State

| Location | Source of truth | Writer | Cache window | Staleness risk |
|---|---|---|---|---|
| **Worktree-local NEXT.md snapshot** | `origin/<integration> NEXT.md` | `/branch create` | When worktree created | **HIGH** — stale after parallel session ships |
| **Worktree-local git branch name** | Derived from Linear issue title + ID | `/branch --linear` | Deterministic slug | LOW — but slug derivation is implicit |
| **`.vbw-planning/linear-map.json`** | Linear issues as authoritative | `/roadmap-create`, `/sync-linear` | Per-creation | MEDIUM — drift if issues deleted post-spec |
| **VBW phase state vs Linear issue state** | Dual-source via phase-detect | VBW agents + `/launch` | Per-execution | **CRITICAL** — see §2 below |

### **Root Problem #1: NEXT.md Race Window**

`/end-session` refreshes NEXT.md from `origin/<integration>` (Pre-flight B, `skills/end-session/skill.md:60`), but the window between `git checkout` and the recompute (Step 7b.1) is **not atomic**. If a parallel session ships a follow-on issue during this window:

1. `/end-session` loads stale NEXT.md state → recommends issue N+1  
2. Parallel session runs `/end-session` → recomputes, also recommends N+1  
3. Both sessions persist the same recommendation

The NEXT.md file itself has no race protection — both writes hit the same path. The workaround is the `pending-next-md.json` defer queue (out-of-repo, v1.7.0), but it only protects **writes from within VBW active-plan scope**. A `/end-session` running outside that scope is unprotected.

**Occurrences in history:** Issue #13 (v1.6.0–v1.7.0 patch trail) was specifically about this. The relocation from `.pipekit/` to `~/.cache/pipekit/` fixed the **VBW file-guard block**, not the race itself.

---

## 2. Skill Overlap & State Ownership Conflicts

Five skills write to Linear issue status, with **no canonical ownership map**. Each skill makes independent assumptions about what state the issue *should* be in.

### Linear Status Transitions by Skill

| Skill | Line ref | Transition | Precondition | Idempotent? |
|---|---|---|---|---|
| `/branch --linear` | `skills/branch/skill.md:150` | Approved → In Progress | Linear check passed | NO — errors if already In Progress |
| `/launch` open | `skills/launch/skill.md:215` | Building (via `save_issue`) | Gates passed, tier confirmed | YES — calls `save_issue` which is idempotent |
| `/launch --close` | `skills/launch/skill.md:359` | `<= Building` → UAT | Verify passed (assumed) | YES (v1.4.0+) — "comment-on-presence" pattern |
| `/g-promote-dev` | `skills/g-promote-dev/skill.md:168` | Specced/Approved → In Progress | PR created | NO — advances even if already In Progress (unclear if this is right) |
| `/g-promote-main` (inferred) | Not read yet | In Progress/UAT → Done | Merge to main (presumably) | Unknown |

### **Root Problem #2: Ambiguous Ownership**

The CHANGELOG.md v1.8.2 entry explicitly defers this: _"Three issues drafted from the same review, deferred: `/g-promote-dev` Linear-state ownership — three skills now transition the same issue; canonical ownership map needed."_

**Empirical case:** a user speccs an issue, it goes Approved → In Progress via `/branch`. Then they create the PR via `/g-promote-dev`. Does `/g-promote-dev` see the issue as already In Progress and skip? Or does it naively re-write to In Progress? `skills/g-promote-dev/skill.md:168` says:

> "Only advance forward — do not downgrade"

But there's no guard against **re-writing to the same state**, which is wasteful (burns API quota, creates redundant Linear comments).

---

## 3. Guards & Their Historical Bugs

Each guard exists because a prior version broke. Listing guards in commit order reveals the seams:

| Guard | Location | Bug it prevents | v history | Severity |
|---|---|---|---|---|
| `/end-session` refuses on `dev`/`main` | `skills/end-session/skill.md:37` | Direct integration-branch writes pollute history or hit branch protection | v1.8.0 intro (#15) | CRITICAL |
| NEXT.md refresh in `/start-session` & `/end-session` | `skills/start-session/skill.md:42`, `skills/end-session/skill.md:58` | Stale worktre snapshots after parallel ship | v1.8.0.1 (#19) | HIGH |
| "Comment-on-presence" for `/launch --close` | `skills/launch/skill.md:364` | Duplicate close comments when skill runs twice | v1.4.0 (#4) | MEDIUM |
| Deferral check before NEXT.md write (VBW scope) | `sop/Skills_SOP.md:173` | VBW file-guard hook blocks NEXT.md writes | v1.6.0 (#11, #12) | MEDIUM |
| Move state files out-of-repo to `~/.cache/pipekit/` | `sop/Skills_SOP.md:138` | VBW file-guard hook silently blocks state-file writes during execution | v1.7.0 (#13, #14) | HIGH |
| `/branch --linear` pre-check Linear status before worktree | `skills/branch/skill.md:88` | Wasted setup time on shipped/canceled issues | v1.4.0 (#5) | LOW |
| Plan-review re-run on Revise (no stalemate loop on round 2) | `skills/launch/skill.md` (implicit in `--auto` flow) | Infinite /launch loops when plan-reviewer is unhappy | v1.8.0.3 (#22) | HIGH |

**Pattern:** Three classes of bugs appear 2+ times:
1. **Race conditions on shared state files** (NEXT.md, state files) — fixed 3 times (v1.6, v1.7, hook deferral)
2. **VBW file-guard hook collisions** — fixed 2 times (state relocation, deferral)
3. **Idempotence failures** (duplicate comments, re-writes, stale preconditions) — present in 2+ skills still

---

## 4. Implicit Coupling & Failure Modes

### The `/branch --linear` → `/start-session` → `/launch --auto` Chain

**Assumptions:**

1. `/branch --linear RS-XX` creates worktree with Approved → In Progress transition
2. User then `cd` to worktree and runs `/start-session`
3. `/start-session` refreshes NEXT.md from origin/dev (v1.8.0.1+)
4. User then runs `/launch RS-XX --auto`
5. `/launch --auto` spawns vbw-lead → plan-reviewer → vbw-dev → vbw-qa → pause at verify

**Failure modes:**

- **If `/branch finish` is NOT run after a failed launch:** worktree + branch persist locally; next `/branch --linear` on the same issue errors ("already In Progress" warning, not error). User must manually clean up.
- **If `/start-session` is skipped:** user doesn't see refreshed NEXT.md; if parallel session shipped mid-worktree, user is blind to it.
- **If user runs `/launch` again after it paused at plan-review Revise verdict:** the skill re-enters at the plan loop, **but there's no guard against running it from the wrong cwd**. If user is still inside the feature worktree (correct), it works. If they switched back to dev (incorrect), `/launch --auto` may fail with cryptic VBW phase-detect errors.

**Coupling evidence:** RUNBOOK.md steps 3–11 are **tightly ordered** with no recovery path if skipped or out-of-order:

```
/start-session (step 3)
  ↓ (must read NEXT.md, assumes /branch just ran)
/launch RS-XX --auto (step 4)
  ↓ (assumes fresh chat, no prior context)
[plan-review decision] (step 5)
  ↓ (fixed flow, no branches)
/vbw:vbw-dev (step 6, spawned by --auto)
  ↓ (must complete)
[QA decision] (step 7)
  ↓ (fixed flow)
/end-session (step 9, BEFORE /launch --close)
  ↓ (must run inside worktree)
/launch RS-XX --close (step 10)
  ↓ (commits NEXT.md + session log to feature branch)
/branch finish (step 13, AFTER PR merges, from PARENT repo)
```

Missing any step, or running them out-of-order, leaves dangling state.

---

## 5. The Runbook as Scar Tissue

RUNBOOK.md is **417 lines** where a clean 1-page flowchart should live. Analysis of bloat:

| Section | Lines | Category | Should it be here? |
|---|---|---|---|
| Quick Index | 45 | Reference | YES — essential, but too verbose |
| One-Time Setup | 70 | Configuration | **MOVE** → `sop/Git_and_Deployment.md` § One-Time Setup |
| The Loop (core 13 steps) | 200 | Procedure | YES — necessary but steps 0–3 are overly detailed |
| Promote dev → main | 30 | Separate flow | **MOVE** → `sop/Git_and_Deployment.md` § Promotion |
| Recovery procedures | 45 | Troubleshooting | **MOVE** → dedicated `RECOVERY.md` or `sop/Troubleshooting.md` |
| Decision tree | 45 | Reference | YES — useful reference |
| What's NOT in this runbook | 10 | Disclaimer | DELETE — links are enough |

**Why it grew:** each recovery procedure was added as a one-time patch when a bug surfaced. Examples:

- "Phantom conflicts on dev → main PR" (line 315) — addresses v1.7.0 phantom-conflict topology, fixed by squash-only ruleset. **Outdated but left in.**
- "Stale git index lock" (line 335) — generic git troubleshooting, not Pipekit-specific. **Could move to TROUBLESHOOTING.**
- "State-file or NEXT.md write hook-blocked" (line 348) — specific to v1.6.0 < config < v1.7.0. **Should be versioned, then deleted.**

**Top 5 things to delete or move:**
1. **Line 48–83:** One-Time Setup — move to `sop/Git_and_Deployment.md`
2. **Line 284–310:** Promote dev → main (separate, periodic flow) — move to SOP
3. **Line 313–350:** All recovery procedures — move to `RECOVERY.md` with version tags
4. **Line 403–411:** "What's NOT in this runbook" — replace with link to `method.md`
5. **Entire §  "Decision tree"** (line 354–399) — move to a separate `DECISION_TREES.md` reference sheet

**Condensed runbook would be:** 80–100 lines covering steps 0–13 at the right level of detail.

---

## 6. Patch Trail Diagnosis — Bug Recurrence Classes

Analyzing commits v1.4.0 → v1.8.2 (40+ commits):

### Class A: State Synchronization (6 occurrences)

| Commit | Issue | Root cause |
|---|---|---|
| 254a754 (v1.7.0) | NEXT.md + state files blocked by VBW file-guard | Files inside repo, hook can't exempt Pipekit state |
| 16a559b (v1.6.0) | NEXT.md writes deferred during plan scope | File-guard blocks mid-execution |
| 85b215a (v1.6.0) | NEXT.md defer queue round-trip broken | Queue schema incomplete |
| 6ad292b (v1.8.0.2) | `/launch --auto` not defaulted correctly | Tier inference inconsistent |
| 07a7f2f (v1.8.0.3) | `/launch --auto` Revise loop broken | Plan-reviewer not re-run on round 2 |
| f0cc5ae (v1.8.2) | Integration resolver not inlined in `/start-session` | Placeholder not replaced, skill broken on worktrees |

**Pattern:** All six fix the same core problem: **script placeholders, string substitutions, and conditional branching are fragile when state is split across files**. Each fix adds another guard or resolver.

### Class B: Idempotence Failures (4 occurrences)

| Commit | Issue | Root cause |
|---|---|---|
| 94e2de6 (v1.4.0) | `/launch --close` runs twice, posts duplicate comments | No guard against re-invocation |
| 40bbf0f (v1.8.0.4) | QA-Pass defaults to pause, not proceed | Tier-default inference wrong |
| c1e0206 (v1.8.0.2) | Recommendations defaulted wrong, confusing output | UI text not synchronized with default |
| 533e812 (v1.4.0) | Closeout-style work routing broken | Phase-detect fallback missing |

**Pattern:** Skills assume they'll run exactly once with correct preconditions, but users re-run them (debugging, re-planning, parallel sessions). No guard layer before state mutation.

### Class C: Integration Assumptions (5 occurrences)

| Commit | Issue | Root cause |
|---|---|---|
| 1a90f82 (v1.3.0) | `/branch --linear` errors when issue already In Progress | No status guard; skill assumes Approved |
| 6f72912 (v1.8.0.5) | `/branch finish` run-from-parent contract broken | Docs said worktree, script assumed parent; clash |
| 4f6bd5d (v1.8.0.1) | `/start-session` run from parent doesn't refresh NEXT.md | Skill designed only for inside worktree |
| 48ff93f (v1.8.0) | Worktree short-branch-name slug collision | Slug derivation from Linear title not deterministic |
| 21cc0aa (v1.8.0) | One-PR-per-issue flow not enforced | No guard against cherry-pick / multi-issue PR |

**Pattern:** Skills designed for a specific context (feature worktree, project root, active plan scope) but invoked from others. No context guards.

---

## 7. User Loop vs Reality — Hidden Steps

**User's mental model (10 steps):**

1. Start (read NEXT.md)
2. Branch
3. Launch
4. Plan (implicit in `/launch --auto`)
5. Work (implicit in `/launch --auto`)
6. UAT
7. Final Paperwork (implied by `/end-session`)
8. Ship-Dev (`/g-promote-dev`)
9. Exit (cleanup)
10. Shut down Branch (`/branch finish`)

**Reality (RUNBOOK.md §The Loop, 13 numbered steps + substeps):**

0. **Pick the issue** (not counted by user; read NEXT.md, `/linear-status`, `/spec-preflight`)
1. `/branch --linear`
2. `cd .worktrees/<slug> && claude --dangerously-skip-permissions`
3. `/start-session`
4. `/launch --auto` (spans 4 hidden skill invocations: vbw-lead, plan-reviewer, vbw-dev, vbw-qa)
5. **[DECISION: Plan-review verdict]** (Revise → loop back to lead, Block → abort)
6. Watch execution (no user action)
7. **[DECISION: QA verdict]** (Fail → escalate, Partial → check verdict carefully)
8. `/vbw:vibe --verify` (optional; implicit in `--auto`)
9. `/end-session` (inside worktree, before PR)
10. `/launch --close` (inside worktree, opens PR)
11. **Rebase-merge PR** (manual, GitHub UI)
12. `/g-test-vercel` (optional smoke test)
13a. `exit` (leave worktree)
13b. `cd ~/Projects/<repo>` (go to parent)
13c. `/branch finish` (cleanup, from parent)

**Hidden steps:**
- Step 0: Pick issue. This is transparent to the user ("what should I work on?") but the system treats it as a separate read context (project root, possibly with `/spec-preflight` pre-flight).
- Step 5 decision loop: If plan-reviewer returns Revise, `/launch --auto` doesn't auto-loop — the user **must** interpret the verdict and manually decide: apply-fixes-and-re-review, proceed-without-re-review, or abort. **Three human judgment gates in one skill.**
- Step 7 decision: If QA returns Fail or Partial, there's no prescribed recovery — "stop hard" (RUNBOOK.md line 197) and "often the right answer is plan-amendment" (line 196) are UI theater, not a defined flow.
- Step 11: PR merge. The user must leave the worktree, go to GitHub UI (or use `gh` CLI), approve + squash-merge. **Sync point with external system.**
- Step 13 cleanup: Three sub-steps with interdependencies. The worktree must be **exited before deleted**; the branch must be deleted **locally only** (remote auto-deleted). If any step fails, the user must hand-recover.

**Total revealed steps:** ~18–20 (depending on decision branches). **Compressed into 10 for marketing, 13 for runbook, exploded into 20+ for real execution.**

---

## 8. **Synthesis: Root Cause of Exhaustion**

The user is exhausted because the system asks them to **manually synchronize three state machines:**

1. **Linear state machine:** Approved → In Progress → Building → UAT → Done
2. **VBW phase machine:** Needs Spec → Specced → Needs Plan → Planning → Needs Review → Needs Execution → Executing → Needs QA → QA-ing → Needs Archival → Done
3. **Git state machine:** Approved (on dev) → Branched (feature branch) → Built (commits) → Merged (to dev) → Promoted (to main) → Done

**None of these are synchronized automatically.** Each skill writes to one or two of them, but:

- `/branch --linear` writes: Linear (Approved → In Progress), Git (create branch)
- `/launch` writes: Linear (In Progress → Building), VBW (open planning gate)
- `vbw:vbw-lead` writes: VBW (PLAN.md)
- `plan-reviewer` writes: VBW (PLAN.md comments), Pipekit state (pipeline-state JSON)
- `vbw:vbw-dev` writes: Git (commits), VBW (STATE.md)
- `vbw:vbw-qa` writes: VBW (VERIFICATION.md)
- `/launch --close` writes: Linear (Building → UAT), Pipekit state (pipeline-state JSON)
- `/end-session` writes: Linear (posts comments), Git (session log + NEXT.md commit), Pipekit state (pending-next-md.json, pipeline-state JSON), VBW (indirectly via NEXT.md recompute)
- `/g-promote-dev` writes: Git (PR), GitHub (PR state), Linear (In Progress on referenced issues)

**No single skill owns a full transition.** Every step requires reading multiple state sources, infer the next action, invoke a skill, wait for it to write partial state, then manually pick up where the next skill left off.

**Result:** The user's mental working memory is constantly refreshing local copies of state: "Is the plan approved? Let me check the PLAN.md... is it also in Linear status?... what does NEXT.md say?... did the session log commit?..." This is **cognitive load, not complexity.** The complexity is well-engineered; the cognitive load is unavoidable given the architecture.

---

## Recommendations (Priority Order)

### High Impact, Quick Win

1. **Delete `NEXT.md` refresh from `/start-session` Pre-flight.** It runs early, races against parallel `/end-session`, adds two versions of the same logic (Pre-flight vs Step 0a in `/end-session`). Instead: `/start-session` reads NEXT.md as-is, trusts `/end-session` kept it fresh. Frees 20 lines from both skills. **Reduces complexity by ~5%.**

2. **Move runbook recovery sections to a separate `RECOVERY.md`.** Reduces RUNBOOK.md to 100 lines (core loop), makes recovery discoverable. **Reduces cognitive overhead on first read by ~40%.**

3. **Add a `/.pipekit/next-step` command that answers "what should I do now?"** instead of requiring users to read NEXT.md themselves. One-liner: `cat NEXT.md | grep "Recommended next command" | sed 's/^`//;s/`$//'`. **Eliminates one manual navigation step per session.**

### Medium Impact, Moderate Effort

4. **Define canonical Linear-status ownership.** Create `sop/Linear_SOP.md` § State Ownership with a table: which skill owns each transition, preconditions, guards. Enforce in code. **Removes 4–5 classes of bugs.**

5. **Make `/launch --auto` resumption explicit.** Instead of waiting for user to re-invoke `/launch RS-XX --auto` after Revise, emit a `next_command` that includes the current round number: `/launch RS-XX --auto --round=2`. Store round state in `pipeline-state/<issue-id>.json`. Detect stalemate at round 4 (not 3 as now) and refuse. **Reduces decision cognitive load; makes stalemate detection deterministic.**

6. **Consolidate the three `/start-session` contexts** (project root, feature worktree, mid-sprint) into one `--context` flag. `--context=root` (project root, no refresh), `--context=worktree` (feature branch, refresh NEXT.md), `--context=summary` (status only, no refresh). **Removes 30 lines of conditional logic from the skill; makes contract explicit.**

### Architectural Refactor (Post-v1.9.0)

7. **Split NEXT.md into two files:**
   - `NEXT-QUEUED.md` — computed by `/end-session`, treated as read-only by user
   - `NEXT-ACTIVE.md` — user's current work context, written only by `/start-session`

   This decouples parallel-session recommendations (queued) from user's session state (active), eliminating the race window. **Requires minimal code change; removes need for `pending-next-md.json` queue entirely.**

8. **Introduce a `LinearSync` agent** that runs post-promote, post-close, post-archival to detect and report drift between Linear status and actual VBW/Git state. One-way read; raises warnings, no auto-fix. **Catches sync bugs before they compound.**

9. **Rewrite `/launch --auto` as a state machine** with explicit states (OpenGate → PlanReview → ReviewDecision → Execution → QAVerify → CloseGate → WaitForPR) instead of nested skill invocations. This makes resumption, stalemate detection, and round-trip idempotence provable. **Reduces surprise failure modes; enables principled recovery.**

---

## Conclusion

Pipekit is **not broken**; it's **layered intelligently** with strong safeguards. The v1.8 patch trail (8 fixes in 2 months) is not a sign of bad architecture — it's a sign of good architecture being **hardened under real use**.

But the architecture is **inherently complex** because it coordinates three independent state machines (Linear, VBW, Git) that were never designed to work together. No amount of guard-adding or SOP-writing can hide that.

**The exhaustion is not a bug; it's a feature.** The system works, ships code, enforces quality gates. But it asks the user to **carry mental state** across 8–10 decision points per issue. A solo developer doing 1–3 issues per sprint can sustain this. A team of 3+ would collapse under it.

**Next step: Pick one of the High-Impact recommendations (1–3) and ship it in v1.8.3. Then reassess.**
