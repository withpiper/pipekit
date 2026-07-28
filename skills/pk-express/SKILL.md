---
name: pk-express
description: Idea→Draft-PR autopilot for simple (Quick/Standard) WITs — chains /brainstorm → /light-spec → pk branch → /work, stopping only at attention gates. /pk-express "<idea>" or resume with <ISSUE-ID>.
---

# /pk-express Skill

You run the **express lane**: a single hands-off pass that takes one *simple* idea from a raw sentence to an open Draft PR, driving the existing skills end-to-end and pausing **only** at points that genuinely need a human.

It is the connective glue over four stages that already self-drive:

```
/brainstorm "<idea>"  →  /light-spec <ID>  →  pk branch <ID>  →  /work <ID>
   (file the WIT)        (auto-cycle to        (worktree)         (execute → auto /verify
                          Approved)                                 --auto-ship → Draft PR)
```

`/light-spec` already loops `pk spec-cycle` ⇄ `/light-spec-revise` to Approved; `/work` already auto-rolls into `/verify --auto-ship`. This skill removes the *between-stage* typing and the two interactive triage/confirm prompts, so a simple WIT runs start to finish untouched.

## North star

Safe and frictionless — but **express, not reckless**. The deliberate gates that protect real risk stay intact: the `/verify` gate, the tier guard, and the human PR/UAT/merge gates. What this skill collapses is only the *low-judgment* friction (re-typing the next command, confirming an obvious "Now", waving through spec passes 2–3).

## When to use

Invoke when **all** of these hold:
- The idea is genuinely small (you'd tag it Trivial/Low/Medium).
- You want it built without babysitting each stage.
- You're fine being pulled back in only if something surprises the pipeline.

Do **NOT** use for:
- Anything you suspect is `tier:heavy` — this skill refuses it (see Tier guard). Use `/brainstorm` → `/light-spec` → `/work` manually so the heavy gates apply.
- Bugs — use `/pk-bug` (regression-test-first discipline).
- Work that already has an Approved spec — just `pk branch <ID>` + `/work <ID>`.

## Invocation forms

```
/pk-express "<one-line idea>"   # full lane: brainstorm → spec → branch → work
/pk-express <ISSUE-ID>          # resume: reads Linear state, joins the lane at the right stage
```

## Source of truth

**Linear is authoritative.** This skill stores no local state. On resume, read the issue's Linear state and route to the correct stage (see Resume routing). New-session safe.

Read `method.config.md` for: Linear team/IDs, Backend (passed through to `/work`), Spec ready/approved state names, integration branch.

## The express contract — auto-advance vs. stop

**Auto-advance** (no prompt) on these success signals:
- `/brainstorm` returns a **Now** disposition → continue with the issue ID it reports.
- `/light-spec` reaches the **Spec approved state** (its internal cycle returned `VERDICT: Pass`) **and** the derived tier is `quick` or `standard` → continue.
- `pk branch <ID>` succeeds → continue.
- `/work` → `/verify --auto-ship` returns **Pass + 0 flags** → Draft PR is open → terminal success.

**Stop and tag the user** (print the ⏸ block below; the session's Stop/Notification hooks fire the cmux notify) at exactly these points — nowhere else:

| # | Stop trigger | Why it needs you |
|---|---|---|
| 1 | `/brainstorm` verdict is **Later / Kill**, or the idea is too ambiguous to scope | The premise itself is a judgment call — don't auto-spec something that shouldn't be built. |
| 2 | Derived tier is **`tier:heavy`** | Express lane is for simple work; heavy work needs the full planning + antagonistic gates. Spec is preserved. |
| 3 | Spec **stalemate** (`/light-spec` hit 3 cycles without a Pass) | The review agent and the spec disagree — you decide override vs. rework. |
| 4 | `/verify` raises **any flag** or a non-Pass verdict | A migration, QA sub-finding, antagonistic finding, or gate failure — your RECONCILE call. (This is `/verify`'s own pause; surface it verbatim.) |
| 5 | **Draft PR opened** (terminal success) | The downstream gates are deliberately yours: `pk ready` → reviewer + UAT → `pk done` → `pk promote`. |
| — | Any **hard error** (brainstorm can't file, `pk branch` fails, push rejected) | Surface verbatim, stop. Never auto-retry. |

Standardized pause block:

```
⏸ pk-express paused — needs you
Issue:  <ID or "(not yet filed)">
Stage:  <brainstorm | spec | tier-guard | work/verify | done>
Reason: <one line>
Next:   <the single command or decision to unblock>
```

## Pipeline

### Stage 0 — Resolve entry

**`/pk-express <ISSUE-ID>` (take an existing WIT through to completion) is the primary form** — you've already brainstormed/captured the idea; this drives it from wherever it is to a Draft PR. `/pk-express "<idea>"` is the convenience form that prepends the brainstorm step.

Read the issue's current Linear state and jump in:

| Current state | Enter at | Notes |
|---|---|---|
| `Triage` / `Ideas` / untriaged | Stage 1 (brainstorm disposition only, no re-file) | then follow Stage 1's state-branch (Approved → Stage 3, Spec-ready-state → Stage 2) |
| `Needs Spec` (the `Spec ready state`) | Stage 2 | needs a spec |
| `Specced` (mid-cycle) | Stage 2's cycle loop | resume reviewing |
| `Approved` (the `Spec approved state`) | **Stage 3** | spec done/skipped → branch + work. **The clean WIT path.** |
| `In Progress` (worktree exists) | Stage 4 | resume work |
| `UAT` or later | — | already past the lane; report and **stop (gate 5)** |

For `/pk-express "<idea>"` (no ID), start at Stage 1.

### Stage 1 — Brainstorm (Express: auto-accept a clear "Now")

Invoke the `/brainstorm` skill (Skill tool, `skill="brainstorm"`) with the idea. Run its feasibility analysis and filing. **Override its interactive HOLD prompt:** if the disposition is a clear **Now**, proceed automatically — do not prompt. If the disposition is **Later/Kill** or genuinely ambiguous, **stop (gate 1)**.

Capture the issue identifier brainstorm reports; it is the `<ID>` for every downstream stage.

**Branch on where brainstorm routed the issue** — a "Now" item lands in one of two states, and they take different paths:

- **Approved** — brainstorm classified it **Quick/Low ("no spec needed")** and sent it straight to the spec-approved state. **Skip Stage 2 entirely** → go to Stage 3. (Quick is by definition not heavy, so the tier guard is satisfied; there is no spec to cycle.)
- **Spec ready state** (the configured `Spec ready state`, e.g. `Needs Spec`) — brainstorm classified it **Standard/Heavy** → it needs a spec → go to **Stage 2**.

Read the resulting state from brainstorm's output (or `pk` Linear lookup). Don't force a state — honor whichever brainstorm set.

### Stage 2 — Spec to Approved (Express: no pass-2/3 prompts; skipped for Quick items)

> Only runs when Stage 1 left the issue in the `Spec ready state`. Quick items routed to Approved skip straight to Stage 3.

Invoke `/light-spec <ID>` (Skill tool, `skill="light-spec"`). It drafts the spec, derives the tier (Phase 3.6, prints `Derived tier: tier:<x>`), publishes the spec, and **auto-enters the spec-review cycle**.

> **Config note:** `/light-spec` publishes to the configured `Spec ready state` and `pk spec-cycle` requires that same state on entry, so the interlock holds on any board — the only requirement is that `Spec ready state` names a state your Linear workflow actually has. If the publish fails because the configured state doesn't exist, surface it and stop (gate-style); it's a `method.config.md` ↔ workflow mismatch, not a pk-express fault.

**Express overrides for this invocation:**
- **Tier guard (gate 2):** as soon as the derived tier is known and it is `tier:heavy`, **stop** — the spec is published and useful, but do not auto-cycle/branch/work it. (For `tier:quick`/`tier:standard`, continue.)
- **Suppress the pass-2/3 confirmation prompts** — let the cycle run all three passes unattended.
- On **Approved** (`VERDICT: Pass`) → continue to Stage 3.
- On **stalemate** (3 passes, no Pass) → **stop (gate 3)**.

### Stage 3 — Branch

Run `pk branch <ID>` (bash). It creates the worktree + branch and moves Linear → In Progress. On failure → stop (hard error). On success → continue.

### Stage 4 — Work → verify → ship

Invoke `/work <ID>` (Skill tool, `skill="work"`) — run it as if from inside the worktree. `/work`'s mandatory Step 7 rollover auto-runs `/verify --auto-ship`, which on **Pass + 0 flags** auto-runs `pk ship` (Draft PR, Linear → UAT).

- **Pass + 0 flags** → Draft PR is open → **terminal success (gate 5).**
- **Any flag / non-Pass** → `/verify` already paused → surface its verdict verbatim and **stop (gate 4).**

Do **not** invoke `pk ready`, `pk done`, or `pk promote` — ever. Those are the deliberate human gates the express lane hands back at gate 5 (the `pk done` auto-run prohibition is the WIT-451 canary, 2026-05-13).

### Terminal hand-off (success)

```
✅ pk-express complete — <ID>
   Draft PR: <url>     Linear: UAT
   Your gates from here:  pk ready <ID>  →  reviewers + UAT  →  pk done <ID> [--merge]  →  pk promote
   Run /pk-exit at end of session.
```

## What this skill does NOT do

- No heavy-tier work (gate 2 refuses it).
- No `pk ready` / `pk done` / `pk promote` (human gates).
- No local state — resume reads Linear.
- No silent retries on hard errors — surface and stop.
- No new pacing logic in the sub-skills — it reuses `/brainstorm`, `/light-spec`, `/work`, `/verify`, `pk` as-is, only overriding the two interactive prompts named above.
