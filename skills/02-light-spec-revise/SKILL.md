---
name: light-spec-revise
description: Apply Spec Review Agent feedback to a Light Spec — surgical edits only. Use when the Spec Review Agent posted unresolved blockers. Use when iterating a spec without rewriting from scratch. Detects stalemate loops.
---

# Light Spec Revise Skill

> **Fresh-chat check.** If this conversation drafted the spec being revised, start a new conversation. The revision must read the published spec + agent comment as documents, not recall the draft. See `method.md` § Fresh-Chat Discipline.

Close the feedback loop between Linear's Spec Review Agent and a published Light Spec. Reads the latest agent comment, diffs it against the current description, and either applies targeted fixes for unresolved blockers or reports that the agent's verdict is stale.

## Triggers

- `/light-spec-revise PROJ-123` — revise based on the latest Spec Review Agent comment on that issue

## Purpose

Apply **only** the fixes the agent asked for, preserving everything else. Detects **stalemate loops** where the agent keeps flagging issues the description already addresses, and avoids the spec drift that comes from re-running the full `/light-spec` capture-and-redraft flow just to patch one blocker.

## When to Use

- The spec has already been published (via `/light-spec` Phase 5).
- The Spec Review Agent has posted at least one review comment (via the MCP trigger from `/light-spec` Phase 6).
- You want to incorporate that feedback without rewriting the spec from scratch.

## When NOT to Use

- The issue has no agent review comment yet → use `/light-spec` first, then trigger the agent.
- The latest agent verdict is `Pass` → no revision needed; proceed to planning.
- You want to substantially rethink the spec → use `/light-spec` for a full redraft; this skill only handles incremental agent-driven revisions.

## Inputs

| Input | Source | Required |
|-------|--------|----------|
| Issue ID (e.g., `PROJ-123`) | Argument | Yes |

## Execution Steps

### Phase 1 — Fetch issue and comments

1. Fetch the issue via `mcp__linear-server__linear_getIssueById` (`id: "PROJ-123"`, `includeRelations: true`). Extract `description` and `title`.
2. Fetch comments via `mcp__linear-server__linear_getComments` (`issueId: "PROJ-123"`). `linear_getIssueById` does **not** return comments — they must be fetched separately.

   The agent's review arrives as a **threaded child comment** — a reply inside the trigger comment's thread, not a new top-level comment. Fetch the full comment list (thread replies included) and filter per step 3. Never read "the newest comment" from a top-level-only view: a `comments(last: 1)`-style read returns the `pk spec-cycle` trigger itself, not the verdict.

3. Filter to Spec Review Agent comments. Identify by **either**:
   - `author.name` contains `Linear` or `Agent` (case-insensitive), **or**
   - `body` starts with a verdict line (regex: `^(?:Verdict:|###\s+Verdict)`, case-insensitive) — bare `Verdict:` is what the `pk spec-cycle` trigger demands and what the agent returns on cycle-triggered reviews (Format C below); the `### Verdict` heading form appears on older reviews.

   Body-matching is the safer signal — author names vary across workspaces.

4. Sort matched comments by `createdAt` descending. The newest is the authoritative review. Older comments are historical and must never be treated as current feedback (they belong to superseded revisions).

5. If zero agent comments found → abort. Tell the user: _"No Spec Review Agent comment found on PROJ-XXX. Use `/light-spec PROJ-XXX` to trigger one first."_

### Phase 2 — Parse the latest agent comment

Extract structured fields from the newest comment's `body`:

The agent emits three formats in the wild. All must be handled:

**Format C — plain-line** (current; the shape the `pk spec-cycle` trigger explicitly demands, and what the agent returns on cycle-triggered reviews):
```
Verdict: Revise
Recommended Flag: Spec: Revise
Readiness Score: 7/10
Blocking Issues:
- <blocker text>
Non-Blocking Improvements: None
Fast Path to Pass: <1-2 sentences>
Decomposition Readiness: Yes
Final Recommendation: <1-2 sentences>
```

The verdict is the **first line** of the body — bare, no heading, no bold. `bin/pk` parses it with `^Verdict:` (case-insensitive) and this skill must accept the same. `pk spec-cycle` only reads the Verdict line; every other field is parsed by this skill alone.

**Format A — heading-based** (legacy; still possible on nudge-path re-reviews, where no trigger restates the format and the agent falls back to its configured rubric, `templates/spec_review_skill.md` § Output Format):
```
### Verdict

Revise

### Readiness Score

8/10

### Blocking Issues

* <blocker text>

### Non-Blocking Improvements
...
```

**Format B — inline-bullet** (legacy; observed on Pass verdicts, Score ≥ 9, minimal content):
```
* **Verdict:** Pass
* **Recommended Flag:** Ready
* **Readiness Score:** 9/10
* **Decomposition Readiness:** Yes
* **Final Recommendation:** Proceed to planning.
```

Field locators must match **any** of the three formats:

| Field | Locator (alternation covers all formats) |
|-------|-------------------------------------------|
| Verdict | `(?:^Verdict:\s*\|###\s+Verdict\s*\n+\|\*\s+\*\*Verdict:\*\*\s*)(Pass\|Revise)` |
| Readiness Score | `(?:^Readiness Score:\s*\|###\s+Readiness Score\s*\n+\|\*\s+\*\*Readiness Score:\*\*\s*)(\d+)/10` |
| Decomposition Readiness | `(?:^Decomposition Readiness:\s*\|###\s+Decomposition Readiness\s*\n+\|\*\s+\*\*Decomposition Readiness:\*\*\s*)(Yes\|No)` |
| Blocking Issues | Format C: content after the `Blocking Issues:` label line, up to the next `Field:` label line (`None` → empty list). Format A: content between `### Blocking Issues` and the next `###` heading. Format B: absent (treat as empty list). |
| Non-Blocking Improvements | Format C: content after `Non-Blocking Improvements:` up to the next label line (`None` → empty list). Format A: content between `### Non-Blocking Improvements` and the next `###` heading. Format B: scan for `### Non-Blocking Improvements` anywhere in body; if absent, treat as empty list. |
| Fast Path to Pass | Format C: content after `Fast Path to Pass:` up to the next label line (`N/A` → absent). Format A: content between `### Fast Path to Pass` and the next `###` heading. Format B: often absent — treat as optional. |

Parse bulleted lists (`*` or `-` prefix) into per-item strings.

**Robustness rules:**

- Always detect format first: if the body's first line matches `^Verdict:\s*(Pass|Revise)` → Format C; else if `### Verdict` heading exists anywhere in the body → Format A; else if `* **Verdict:**` inline bullet exists → Format B; else → unrecognised, abort and report the raw body to the user.
- Format B is valid only when `Verdict` is `Pass`. A Format B body with `Verdict: Revise` is malformed — report to user, ask whether to abort or treat as manual-analysis input.
- Missing Blocking Issues in Format B is expected (Pass verdicts have none); `Blocking Issues: None` in Format C is expected on Pass. A `Revise` verdict with no Blocking Issues content — any format — is a parse failure.
- If a required field (Verdict, Readiness Score) is missing under either format → abort and report the raw body.

### Phase 3 — Verdict-gated branching

**If Verdict is `Pass`:**

1. Report: _"Latest agent verdict is **Pass** (score: X/10). No revision needed."_
2. If Non-Blocking Improvements exist, walk through them interactively — **one `AskUserQuestion` call per improvement**, with options:

   | Label | Description |
   |---|---|
   | `Apply (Recommended)` (or label adjusted to recommendation) | Why this improvement is worth folding in + what it changes in the spec. |
   | `Defer to follow-up issue` | Skip in this spec; capture as a follow-up Linear issue if the improvement is meaningful but out of scope. |
   | `Drop` | Reject the suggestion; note rationale in spec's Notes section. |

   For each improvement, the recommendation defaults to **Apply** unless the improvement contradicts an existing decision. Reasoning lives in the description.

   After all improvements: re-present the spec, confirm, then publish per Phase 7 rules.

3. Exit if user declines all and there are no remaining improvements.

**If Verdict is `Revise`:**

Proceed to Phase 4.

### Phase 4 — Blocker diff

For each Blocking Issue in the agent's comment:

1. **Extract the concrete demand.** Usually 1-3 sentences. Identify:
   - Which section of the description is affected (Scope, Decisions, Requirements, Acceptance Criteria, Technical Context, etc.)?
   - What concrete change does the agent want — added, changed, or removed?

2. **Check the current description for evidence the demand is already addressed.**
   - Search the description for keywords and constraints the agent names.
   - Classify as:
     - **Resolved-Stale** — description already has the fix.
     - **Unresolved** — description does not have the fix.
     - **Ambiguous** — the fix may be partial or hidden; ask user.

3. **Stalemate detection.** Compare the latest agent comment's Blocking Issues against the **second-newest** agent comment's Blocking Issues (if one exists). For each blocker where:
   - The same issue is flagged in both comments (fuzzy match on first 20 tokens), **and**
   - The current description addresses it,

   → mark the blocker as **Stalemate**.

### Phase 5 — Report before editing

Present a summary to the user **before making any changes**. Format:

```
Agent verdict: Revise (Score: N/10)
Latest review: <timestamp>

Blocking Issues:

  1. [Resolved-Stale | Unresolved | Ambiguous | Stalemate]
     "<first line of blocker>"
     → <evidence: line/section in description that addresses or fails to address it>
     → <stalemate note, if applicable>

  2. ...
```

Then list the user's options:

```
Options:
  [1] Apply surgical fixes for Unresolved blockers (I'll show each patch before applying)
  [2] Post nudge comment for Stalemate blockers (draft below)
  [3] Override agent verdict (append note to Agent Review section)
  [4] Manual review — show me each flagged section and let me decide
  [5] Abort
```

Do not proceed to Phase 6/7 until the user chooses.

### Phase 6 — Act on stalemate / override / manual choices

- **Post nudge (option 2)**: draft a short comment (under 50 words) pointing at the specific line in the description that addresses the stalemate blocker. Post it via `mcp__linear-server__linear_createComment` — the body MUST start with the literal text `@linear`. Format:

  ```
  mcp__linear-server__linear_createComment({
    issueId: "PROJ-XXX",
    body: "@linear this blocker has been addressed in the description — see the [section name] section where [specific line or text]. Please re-review."
  })
  ```

  Note: this is a targeted nudge, not a full re-review. For a full re-review, exit this skill and run `pk spec-cycle PROJ-XXX` — that's the canonical re-trigger path.

- **Override (option 3)**: append a note to the `## Agent Review` section of the description documenting that the latest verdict is stale. Include:
  - Date of the stale review being overridden.
  - Link back to the specific description content that addresses each flagged blocker.
  - Who overrode it (the user).
  - Update the issue description via `mcp__linear-server__linear_updateIssue`.

- **Manual review (option 4)**: for each blocker, show the user the flagged description section alongside the agent's demand. Let the user tell the skill what (if anything) to change. Treat each user-directed change as a patch to apply in Phase 7.

### Phase 7 — Apply surgical fixes (Unresolved blockers only)

For each **Unresolved** blocker:

1. Identify the exact section(s) of the description to patch.
2. Draft a **minimal** patch — the smallest change that resolves the blocker. Do not touch surrounding text.
3. Present the patch as a diff (before/after) to the user.
4. User approves or rejects per blocker.
5. Apply approved patches to the in-memory description.

**Hard constraints:**

- Never rewrite sections the agent did not flag.
- Never delete existing user commentary from the `## Agent Review` section.
- Never merge multiple blockers into a single rewrite; each patch stays distinct for reviewability.
- Never resolve a blocker by pasting code into the spec. If the agent's demand amounts to "show the code," satisfy it with a sharper reference — `path` + symbol/heading, per the template's code-reference discipline. Pasted blocks are only for contracts (exact expected diff, small type signature, content that doesn't exist yet).
- If applying a patch would require changes beyond the flagged section (e.g. a blocker on AC that forces a Scope edit), surface the cross-section dependency to the user and get explicit approval before touching the second section.

### Phase 8 — Non-Blocking Improvements (opt-in)

After blocker fixes (or immediately, if verdict was `Pass`):

1. List each Non-Blocking Improvement.
2. For each one, ask the user: _"Apply this improvement? (y/N)"_
3. For approved improvements, draft a minimal patch and apply with the same constraints as Phase 7.

Do **not** apply Non-Blocking Improvements silently or in bulk.

### Phase 9 — Publish

1. Update the issue description via `mcp__linear-server__linear_updateIssue`.
2. Append to the `## Agent Review` section of the description:

   ```markdown
   *Revised {YYYY-MM-DD} in response to Spec Review Agent feedback (pass N). Fixes applied:*
   - [fix 1 — one-line summary]
   - [fix 2 — one-line summary]

   *Non-blocking improvements applied:*
   - [improvement — one-line summary]

   *Stalemate blockers surfaced to user:*
   - [blocker — noted as addressed in {section}]

   *Ready for next-pass review.*
   ```

   Omit sub-sections that had zero entries.

3. Do NOT re-trigger the Spec Review Agent from this skill. Re-triggering is owned by `pk spec-cycle`, which the caller (`/01-light-spec` Phase 6 cycle) invokes after this skill returns. If this skill was run standalone (not via the cycle), tell the user: _"➜ next: pk spec-cycle PROJ-XXX"_.

### Phase 10 — Next-step output

Emit an inline `➜ Next:` line in your terminal output:

- If the revision is expected to pass on next review → `pk branch PROJ-XXX` (then `/work PROJ-XXX` inside the worktree)
- If another pass is likely (some Unresolved blockers remain, or the user deferred fixes) → `/light-spec-revise PROJ-XXX`
- If stalemate was surfaced and the user chose override → `pk branch PROJ-XXX` (override clears the path)

Do **not** write a `NEXT.md` file — v2 retired the mirror; `pk next` reads "what's next?" live from Linear.

---

## Stalemate Loop Policy

If the same blocker has been flagged in **≥ 2 consecutive agent comments** AND the description already addresses it, the skill MUST NOT apply further revisions. Available options reduce to:

- Post nudge comment
- Override verdict
- Manual review

Rationale: blind re-revision compounds drift. A stuck agent is a data problem (agent didn't re-read the updated description, or its parser is missing a recent addition), not a spec problem. The fix is to unstick the agent, not to rewrite the spec a third time.

## Output Contract

The skill MUST NEVER:

- Rewrite sections the agent did not flag.
- Delete user commentary from the `## Agent Review` section.
- Apply Non-Blocking Improvements without explicit per-item user approval.
- Proceed past Phase 5 without user choice.

## Related Skills

- `/light-spec` — creates the spec; Phase 6 sets up the feedback loop this skill closes.
- `pk branch` + `/work` — consumes `Pass`-verdict specs for planning + execution (v2 daily loop).
- `/spec-validator` — heavier validator for full Strategy docs (not Light Specs).
