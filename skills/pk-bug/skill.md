---
name: pk-bug
description: Bug pipeline — intake, reproduce, regression-test-first, fix, ship, postmortem. Wraps /work and pk ship with discipline gates. Invoke when a bug is reported or spotted. Linear is the source of truth — resume by passing the issue ID.
---

# /pk-bug Skill

You run the **bug pipeline**: a disciplined wrapper around the daily loop that enforces *regression-test-first* fixing. The point: a bug, once fixed, must never silently re-ship — there must be a test that would have caught it.

## When to use

Invoke when:
- A bug is reported by a user
- You spot a bug during dev or QA
- You're resuming a bug already in flight (`/pk-bug <ISSUE-ID>`)

Do NOT use for:
- New features (use `pk next` → `/work`)
- Spec work (use `/light-spec`)
- PR review of an unrelated change (use `/pr-fix`)

## Invocation forms

```
/pk-bug                       # new bug, prompts for everything
/pk-bug "<one-liner>"         # new bug, description prefilled
/pk-bug <ISSUE-ID>            # resume — reads Linear, routes to right phase
```

## Source of truth

**Linear is authoritative.** This skill stores no local state. Every resume reads the Linear issue (status, body, comments) and routes to the correct phase. New session safe.

Read `method.config.md` for:
- Linear team ID, workflow state IDs
- Pre-deploy gate commands
- Backend (`vbw` or `native`) — passed through to `/work`

## Resume routing

When invoked with an existing `<ISSUE-ID>`, query Linear and enter the phase below:

Routing keys off Linear's `statusType` (not display name) so projects with custom statuses like `Parked` route correctly.

| Linear state                                                            | Enter phase |
|------------------------------------------------------------------------|-------------|
| Issue not yet created                                                   | 1 — Intake |
| `statusType=backlog`, no "Reproduced:" comment                          | 2 — Reproduce |
| `statusType=backlog` + "Reproduced:" comment, no test file              | 3 — Diagnose + Test |
| Test file exists, no branch                                             | 4 — Worktree handoff |
| `statusType=started` (e.g. In Progress)                                 | 5 — Fix + Ship |
| `statusType=started` + PR open (or status named UAT/Review)             | 6 — PR review + merge to dev |
| Merged to dev, not on main                                              | 7 — Promote dev → main |
| `statusType=completed`, no postmortem comment (priority ≤ Medium = 3)   | 8 — Postmortem |
| `statusType=completed`, postmortem present                              | report complete, exit |

Heuristics for state detection:
- "Reproduced" = Linear comment starting with `Reproduced:` (you write this in Phase 2)
- "Test file exists" = grep the issue body for `## Regression Test` section filled in
- "Branch exists" = `git branch --list <ISSUE-ID>` returns a result
- "Postmortem present" = Linear comment containing `# Postmortem` heading

---

## Phase 1 — Intake

**Goal:** create a well-formed Linear issue.

1. Ask the user the questions in `templates/intake.md`. If a one-liner was passed, prefill the description hint.
2. **Priority heuristic** to show the user (Linear `priority` field — native, no custom labels):
   - `Urgent` (1) — data loss / auth bypass / money / production down
   - `High` (2) — core flow broken (e.g. sign-out failing for magic-link users)
   - `Medium` (3) — degraded UX, workaround exists
   - `Low` (4) — cosmetic / single-user / edge case
3. **Urgent fast path:** if user picks `Urgent`, skip detailed intake — capture one-liner + priority, mark issue body with `**Fast-path: Urgent** — fill in details during postmortem`. Postmortem becomes mandatory + reviewer sign-off in Phase 8.
4. Create Linear issue:
   - Team: from `method.config.md`
   - Status: backlog-type (e.g. `Backlog` or `Parked` — anything with `statusType=backlog`)
   - Priority: 1–4 per the heuristic above
   - Labels: `Bug` (no severity labels — priority is the native field)
   - Body: filled `templates/intake.md`
5. Echo `<ISSUE-ID>` to the user. Advance to Phase 2.

---

## Phase 2 — Reproduce  *(GATE)*

**Goal:** reproduce locally before any diagnosis.

1. Read repro steps from the Linear issue body.
2. Reproduce by the most direct path:
   - **UI bug:** Playwright MCP, walk the steps
   - **Backend logic:** `curl` / direct test invocation
   - **Auth flow** (e.g. magic-link sign-out): full e2e — sign in, observe state, sign out, assert state changed
3. **Gate decision:**
   - **Reproduced** → comment on Linear:
     ```
     Reproduced: <one-line evidence>
     - Method: <Playwright | curl | manual>
     - Artifact: <screenshot path | log snippet | n/a>
     ```
     Advance to Phase 3.
   - **Cannot reproduce** → Linear status to `Triage` or label `needs-info`, comment with everything tried. **STOP. Do not guess-fix.** Inform user, exit.

---

## Phase 3 — Diagnose + Failing Regression Test  *(GATE)*

**Goal:** find root cause AND write a test that fails because the bug exists. **Done on `main` branch — test file is uncommitted.**

### 3a — Diagnose

Use the scientific method:
1. State a hypothesis (1 sentence)
2. Verify by reading the relevant code / logs / DB
3. Narrow until you have a one-paragraph root-cause statement
4. Append the root cause to the Linear issue body under `## Root Cause`

If diagnosis takes more than ~30 minutes of investigation, consider spawning the `vbw-debugger` agent. Don't burn the main context on a deep dive.

### 3b — Write the failing test

Pick the right test type for the bug:

| Bug type | Test type | Location convention |
|----------|-----------|---------------------|
| Logic / data layer | Unit or integration | colocated `*.test.ts` |
| UI behavior | Playwright e2e | `tests/e2e/` |
| Pure visual / spacing | Playwright visual snapshot (`toHaveScreenshot()`) | `tests/e2e/visual/` |
| Auth / session flow | Playwright e2e (full session lifecycle) | `tests/e2e/auth/` |

**Auth-flow test shape (illustrative — adapt to your stack):**
```ts
test('user state is fully cleared after sign-out', async ({ page }) => {
  await signIn(page, testUser);
  await expect(page).toHaveURL('/dashboard');
  await signOut(page);
  await expect(page).toHaveURL('/login');
  // Critical: session is actually gone, not just UI redirect
  const cookies = await page.context().cookies();
  expect(cookies.find(c => c.name.includes('auth'))).toBeUndefined();
  await page.goto('/dashboard');
  await expect(page).toHaveURL('/login');  // protected route bounces
});
```

### Gate

Run the test. It MUST fail for the **right reason** — the bug exists, not a setup error.

- ✅ Test imports cleanly, the bug-specific assertion fails → continue
- ❌ Import error / fixture missing / timeout / 500 from setup → fix the test, do not advance

Append test path to Linear issue body under `## Regression Test`.

---

## Phase 4 — Worktree handoff

**Goal:** move from main into an isolated worktree, with the test as the first commit.

1. Run `pk branch <ISSUE-ID>`
   - Creates worktree, branch, sets Linear → `In Progress`
2. `cd` into the worktree
3. Move the test file from main into the worktree (or recreate — usually a git stash + apply)
4. Commit ONLY the test:
   ```
   git add <test-path>
   git commit -m "test(<ISSUE-ID>): add failing regression test for <one-liner>"
   ```
5. Verify: `git log --oneline` shows the test commit. Run the test from the worktree — must still fail.

This commit is the audit trail. Anyone reading `git log` later sees the test landed before the fix.

---

## Phase 5 — Fix + Verify + Ship

**Goal:** make the test pass, ship.

1. Hand off to `/work <ISSUE-ID>` with this directive in the prompt:
   > A regression test exists at `<test-path>` and currently fails. Your job is to make it pass without modifying the test file. The root cause is documented in the issue body under `## Root Cause`.
2. After `/work` completes:
   - Run the regression test alone — must pass
   - Run `/verify` — full pre-deploy gate
3. `pk ship` — opens PR, Linear → `UAT`
   - For auth / RLS / migration bugs: `pk ship --review` to invoke the antagonistic reviewer

---

## Phase 6 — PR review + merge to dev

1. Optional but encouraged for priority ≤ Medium (1–3):
   - Auth / security bugs → `/pr-security-review`
   - General code quality → `/pr-fix`
2. Address review feedback (commit on the same branch)
3. Merge PR to `dev`
4. `pk done <ISSUE-ID>` — verifies merged, cleans worktree+branch, posts commit summary to Linear

---

## Phase 7 — Promote dev → main

- `Urgent` → run `pk promote` immediately (solo promote, do not batch)
- `High` / `Medium` / `Low` → leave for the next batched promote. Comment on Linear: `Awaiting next dev → main promote.`

After main deploys, Linear should auto-transition to `Done` (per the existing automation).

---

## Phase 8 — Postmortem

**Mandatory for priority ≤ Medium (1–3). Optional but recommended for low.**

1. Append a Linear comment using `templates/postmortem.md`:
   - What broke (1 sentence)
   - Which gate should have caught it
   - One change to prevent recurrence
2. **Urgent only:** request reviewer sign-off in the comment thread before marking complete.
3. If "one change to prevent recurrence" is concrete (e.g. "add Playwright e2e for every auth-method × sign-out combo"), create a follow-up Linear issue or add a rule to `.claude/rules/`.

---

## Invariants

| Rule | Enforcement |
|------|-------------|
| No fix code before failing test exists | Phase 3 gate; Phase 4 commits test first |
| Cannot repro → STOP | Phase 2 gate; mark `needs-info`, exit |
| Linear is the source of truth | Resume always re-reads Linear, never local state |
| Postmortem mandatory for priority 1–3 | Phase 8; reviewer sign-off if Urgent |
| Urgent → solo promote | Phase 7 |
| Test commit lands before fix commit | Phase 4 step 4 |

## Failure modes to avoid

- **Don't skip Phase 2** because the bug "obviously" exists. Unrepro'd bugs get guess-fixed and ship as silent regressions.
- **Don't write the test after the fix.** A test written against passing code tests the fix, not the spec — it won't catch the same bug class re-introduced later.
- **Don't fold test + fix into one commit.** The audit trail is part of the value.
- **Don't promote `Urgent` bugs in a batch.** Blast radius mismatch.

## Origin

Built locally in rs-vault, dogfooded on RS-94 (magic-link Enter-key OAuth misroute, 2026-05-07), promoted to Pipekit upstream after the first clean run. The pattern: build a candidate skill in a consuming project under `.claude/skills/<name>/`, dogfood on a real ticket, promote to `pipekit/skills/<name>/` once it earns its keep, sync back via `sync-method.sh`.
