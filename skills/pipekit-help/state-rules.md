# Pipekit Help — State Rules

> Ordered list of state matchers. First match wins. Each rule pairs a matcher with a recommendation and a one-line why.

Rules are evaluated top-to-bottom. Early rules handle blocking conditions and post-pipeline actions; later rules handle in-pipeline progression.

## 1. Foundation contract incomplete (mode-aware)

The foundation contract (see `method.md` § Foundation Contract) is the set of artifacts the dev pipeline requires. When any are missing, recommend a mode-appropriate `/startup` invocation rather than a generic one. Detection is top-down; first sub-rule wins.

### 1a. Empty project — greenfield

**Match:** No `concept-brief.md` AND no source tree (no `package.json`, no populated `src/`) AND no `Strategy/`.

**Recommend:** `/startup`
**Why:** Fresh project with no foundation artifacts and no code — run the full Stage 0 chain.

### 1b. Code present, no foundation — brownfield

**Match:** Source tree present (`package.json` or populated `src/`) AND no `Strategy/` directory AND no `method.config.md`.

**Recommend:** `/startup --mode=brownfield`
**Why:** Existing codebase adopting Pipekit — skip `/concept` and `/define`, route to `/strategy-create` with a manual-edit note.

### 1c. Foundation present, no recent activity — inherited or returning

**Match:** All foundation-contract artifacts present AND no commits in the last 14 days on the current branch AND no `PLAN.md` / `REVIEW.md` / `VERIFICATION.md` markers in the latest phase.

**Recommend:** `pk next`
**Why:** Foundation is intact and nothing is mid-flight — `pk next` is the phase-aware entry point that groups Linear by status with per-group hints. (Run `/startup --mode=inherited` if you want an explicit foundation audit first.)

### 1d. Partial foundation — diagnose first

**Match:** Some foundation-contract artifacts present, others missing — does not match 1a, 1b, or 1c above.

**Recommend:** `/startup --mode=inherited`
**Why:** Foundation is partially in place — run the Foundation Check to see exactly which artifacts are missing and which retrofit skills to run.

## 2. Pending strategy sync

**Match:** `$STATE_DIR/pending-strategy-sync` file exists (`STATE_DIR=$(bash scripts/pipekit-state-dir.sh)`).

**Recommend:** `/strategy-sync`
**Why:** Post-archive hook flagged a milestone close; strategy docs are out of date with shipped reality.

## 3. Verification done, ready to close

**Match:** Latest phase has `VERIFICATION.md` AND no PR has been opened for the matching issue (heuristic: branch name contains a `PROJ-XXX` token AND most recent commit on this branch is post-VERIFICATION.md timestamp AND `gh pr list --head <branch>` returns empty).

**Recommend:** `pk ship`
**Why:** QA passed; the only remaining step is push + open PR + Linear → UAT (`pk ship` does all three idempotently).

## 4. Plan reviewed but not executed

**Match:** Latest phase has `PLAN.md` AND `REVIEW.md` AND `REVIEW.md` indicates "Pass" or equivalent AND no execution-state evidence (no commits since the review on the current branch).

**Recommend:** `/vbw:vibe --execute`
**Why:** Plan is reviewed and approved; ready for atomic execution.

## 5. Plan exists but not reviewed

**Match:** Latest phase has `PLAN.md` AND no `REVIEW.md` (or REVIEW.md older than PLAN.md).

**Recommend:** `/review-plan`
**Why:** Plan must pass independent review before execution (Pipekit's value-add over raw VBW).

## 6. Issue Building, no plan yet

**Match:** Branch is project-prefixed (`PROJ-XXX`) AND no `PLAN.md` exists for any phase referencing this issue AND Linear issue status (if checked) is "In Progress" AND inferred tier is Standard or Heavy.

**Recommend:** `/work <issue>`
**Why:** Issue is in worktree-and-branch state but no plan has been generated yet. `/work` does the verdict-gate planning then dispatches execution per `Backend:` config. Start a fresh chat first (see method.md § Fresh-Chat Discipline).

## 6b. Quick tier — direct to batch runner

**Match:** Issue label includes `tier:quick` AND Linear status is "Building" AND no batch run has fired (no batch-runner output for this issue in recent transcripts).

**Recommend:** `/linear-todo-runner`
**Why:** Quick tier skips planning; AC is the plan.

## 7. Spec exists but not approved

**Match:** Linear issue status is "Specced" (not yet Approved) AND latest spec-review-agent comment exists.

**Recommend:** Read the spec-review comment in Linear. If revision needed → `/light-spec-revise PROJ-XXX`. If clean → human approval in Linear.
**Why:** Spec passed agent review but human approval is required before launch.

## 8. Spec drafted but not reviewed

**Match:** Linear issue has a `## Light Spec` section AND no spec-review-agent comment exists (or comment predates last spec edit).

**Recommend:** Trigger Linear's Spec Review Agent on the issue.
**Why:** Spec must be agent-reviewed before human approval and launch.

## 9. Approved issue waiting to launch

**Match:** Linear issue status is "Approved" AND no current branch matches the issue prefix.

**Recommend:** `pk branch PROJ-XXX`
**Why:** Issue is human-approved and ready to enter In Progress (`pk branch` creates the worktree + branch and transitions Linear). Then `cd` into the worktree and run `/work PROJ-XXX`.

## 10. Phase in flight, multiple candidates

**Match:** Multiple Linear issues are in "Building" or "In Progress" simultaneously.

**Recommend:** `pk status`
**Why:** Multiple in-flight issues — `pk status` shows the full unscoped board so you can pick the one to work on.

## 11. Fallback

**Match:** No prior rule matched.

**Recommend:** `pk status`
**Why:** State didn't match any known rule — start from the full board view.

---

## Adding rules

When adding a new rule:

1. Decide insertion order. Earlier = higher priority. Blocking conditions go first; ambiguous state goes last.
2. Make the matcher cheap. File presence > git log > Linear API call. Don't add a rule that requires expensive checks unless it's the only signal.
3. Keep the "why" to one line. If you can't, the rule is too complex — split it.
4. If the rule is project-specific, put it in `.claude/overrides/skills/pipekit-help/state-rules.md` instead of the upstream file.
