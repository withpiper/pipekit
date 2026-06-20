---
name: strategy-sync
description: Update Strategy docs to reflect what actually shipped. Use after a feature lands in prod and Strategy docs drifted. Use at phase close to reconcile docs with reality. Use a fresh chat — recall contaminates the diff.
---

# Strategy Sync Skill

> **Stage-isolation check.** Strategy sync diffs *shipped reality* against the docs, so it must read both as documents — an agent that watched the build can't independently judge its own assumptions. Start a fresh conversation; recall of build decisions contaminates the diff. This is deliberate isolation, **not** a context-window workaround — a 1M window doesn't relax it, because the risk is contaminated judgment, not lost memory. See `method.md` § Fresh-Chat Discipline.

You are a documentation synchronizer. Your job is to update Strategy docs to reflect what was actually built. Read `method.config.md` for project context. You close the documentation loop so that anyone reading the Strategy docs understands the product as it exists today — not just as it was originally envisioned.

## Triggers

- `/strategy-sync`
- "sync strategy docs"
- "update strategy docs"

## Purpose

Strategy docs are the human-readable explanation of the product. After features ship, these docs must be updated to reflect reality. Without this, the docs drift and become unreliable — a new reader gets a picture that doesn't match the actual app.

## The Documentation Loop

```
Strategy Docs (vision) → Light Specs → Plans → Code → Strategy Docs (reality)
                  ↑                                              |
                  └──────────── /strategy-sync ─────────────────┘
```

This skill closes the right side of that loop.

## Document Map

Read the project's strategy doc manifest from `method.config.md` under `## Strategy Docs`. This table defines which docs exist, their file paths, purposes, and audiences. Example:

| Doc | File | Purpose | Audience |
|-----|------|---------|----------|
| Conceptual Overview | `Strategy/ConceptualOverview.md` | What the product does | Stakeholders |
| Technical Architecture | `Strategy/TechnicalArchitecture.md` | System design, APIs, patterns | Developers |
| Permissions | `Strategy/Permissions.md` | Auth, roles, access control | Developers, Admins |

Use the **Purpose** field to determine the tone and depth of updates. Use the **Audience** field to calibrate language level (stakeholder docs stay simple, developer docs include technical detail).

If a Changelog doc exists in the manifest, it is excluded from sync content — Changelog entries are owned separately (`/release-changelog` for release notes, `/pk-exit` for per-session logs at `Logs/Sessions/`). However, this skill adds a single Changelog entry recording what was synced.

**If no Strategy Docs table exists in `method.config.md`:** warn the user and suggest running `/strategy-create` to set up the manifest.

## Execution Steps

### Phase 1 — Identify Shipped Work

1. Read `method.config.md` to get the strategy doc manifest
2. Read the first strategy doc's version header to get the last update date
3. Read `.vbw-planning/STATE.md` for recently completed phases
4. Query Linear for issues in Done state since the last Strategy doc update date:
   - Use `mcp__linear-server__linear_searchIssues` filtered by state = Done
   - Filter to issues completed after the last doc update
4b. **Merged-PR cross-check (mandatory — do not skip).** Linear `Done` routinely *lags* git reality: a WIT's PR merges to the integration branch but the issue stays in UAT / In <Env> because the post-merge transition (`pk done`) was skipped, run via the GitHub UI, or failed. Trusting Linear `Done` alone therefore **under-reports shipped work**, and this sync silently skips real features. Cross-check against merged PRs:
   - Get the integration branch (`method.config.md` → `integration_branch` / `## Ship environments`) and the project's issue-ID prefix (from the Linear team in `method.config.md` — e.g. `WIT-`, `RS-`, `PROJ-`).
   - List PRs merged since the last doc-update date (from step 2):
     ```bash
     gh pr list --state merged --base <integration-branch> --limit 100 \
       --json number,title,headRefName,mergedAt \
       --jq '.[] | select(.mergedAt >= "<last-doc-update-date>")'
     ```
   - Extract issue IDs from each PR's `headRefName` (e.g. `feature/WIT-434-…`) **and** its title/body (bundled `<PREFIX>-\d+`).
   - **Diff against the Done set from step 4.** Any merged-but-not-Done issue is shipped work — fold it into this sync, and tell the user its Linear state lags so they can reconcile.
   - Non-skippable: this guard is the only thing between a lagging Linear board and a doc-sync that misses real features. (Root cause: post-ship Linear transitions in Pipekit are command-driven, not merge-driven — an upstream `bin/pk` limitation, not a project bug.)
5. For each shipped issue (Done **or** merged-but-not-Done from 4b): check if it has a light spec (look for `## Light Spec` in description)
6. Group shipped features by complexity:
   - **Has light spec:** Full spec available — primary source for doc updates
   - **No spec (bug/fix):** Check if it changed user-visible behavior
   - **Internal only:** Skip (no doc impact)

### Phase 2 — Map to Strategy Sections

For each shipped feature with doc impact:

1. Read the light spec's Technical Context section for § references to specific strategy doc sections
2. If no explicit reference, match by keyword against each doc in the manifest:
   - Read each strategy doc's section headers
   - Match the feature's domain to relevant sections based on the doc's Purpose field
3. Build a mapping table:

```
| Feature | Affected Docs | Sections |
|---------|--------------|----------|
| PROJ-7 Rate Cards | Conceptual Overview §3.4, Technical Architecture §5.x | Update + new |
| PROJ-8 Block Types | Conceptual Overview §3.3 | Update |
```

### Phase 3 — Compare and Draft

For each affected section, use an Explore agent to:

1. **Read the current Strategy doc text** for that section
2. **Read the shipped light spec** for the feature
3. **Read the actual implementation** (key schema, API routes, components) to catch any spec-to-code drift
4. **Draft an updated section** that:
   - Reflects what was ACTUALLY built (code is truth, not the spec)
   - Maintains the doc's tone and audience level based on the manifest's Audience field:
     - Stakeholder docs: simple, conceptual, no code — a non-technical reader should understand
     - Developer docs: technical, schema-level detail, code patterns
     - All-audience docs: step-by-step scenarios with concrete examples
   - Preserves descriptions of future-stage features that weren't built yet
   - Clearly distinguishes "what exists today" from "what's planned"

### Phase 4 — New Sections

For features that are entirely new (no existing Strategy doc section):

1. Determine the appropriate location in the doc structure
2. Draft a new section following the existing numbering convention
3. Add cross-references to related sections in other docs
4. For workflow-focused docs: draft a new workflow example if the feature has a distinct user flow

### Phase 5 — Present Diffs

Show each proposed change as a before/after comparison:

```markdown
## Conceptual Overview § 3.4 — Rate Cards

**Current (v2.6.1, Feb 2026):**
> Rate cards provide standard pricing templates at the entity level.

**Proposed (reflects PROJ-7 + PROJ-8 implementation):**
> Rate cards provide standard pricing at Entity, Client, or Project
> scope with optional lineage inheritance.

**What changed:** Cascade model replaced simple entity-level cards.
```

For each diff, ask: _"Approve this update? [yes / edit / skip]"_

### Phase 6 — Apply and Version

1. Apply all approved updates to Strategy docs
2. Bump the doc version using semver logic:
   - New features added → minor bump (e.g., v2.6.1 → v2.7.0)
   - Corrections/clarifications only → patch bump (e.g., v2.6.1 → v2.6.2)
3. Update the version header and date in each modified doc
4. If a Changelog doc exists in the manifest, add an entry summarizing the sync

### Phase 7 — Cross-Sync

After updating primary docs, check consistency across all docs in the manifest:

1. **Terminology:** Do docs use the same terms for the same concepts?
2. **Workflows:** Do workflow docs still match the updated conceptual docs?
3. **Permissions:** Do permission docs reflect any new tables, RLS policies, or role changes?
4. **Cross-references:** Are all § references between docs still valid?
5. Flag inconsistencies for manual review — do NOT auto-fix cross-doc issues without approval

### Phase 7b — Clear Post-Archive Marker

If `$STATE_DIR/pending-strategy-sync` exists (resolve `STATE_DIR=$(bash scripts/pipekit-state-dir.sh)`), it was written by `scripts/pipekit-post-archive.sh` to signal that a milestone archive left strategy docs potentially stale. (v1.7.0+: location moved out-of-repo to evade VBW's file-guard.) After Phase 6 applies approved updates, remove the marker:

```bash
STATE_DIR=$(bash scripts/pipekit-state-dir.sh)
rm -f "$STATE_DIR/pending-strategy-sync"
```

If no approved updates were applied (user skipped all diffs), leave the marker in place so the nudge persists into the next session.

### Phase 8 — Summary

```markdown
## Strategy Sync Complete — YYYY-MM-DD

### Updates Applied
| Doc | Sections Updated | New Sections | Version |
|-----|-----------------|--------------|---------|
| Conceptual Overview | §3.4, §4.2 | §3.8 | v2.7.0 |
| Technical Architecture | §5.1 | §5.9 | v2.7.0 |
| Permissions | §2.3 | — | v2.7.0 |

### Features Synced
- PROJ-7: Rate Cards → Conceptual Overview §3.4, Technical Architecture §5.x
- PROJ-8: Block Types → Conceptual Overview §3.3

### Skipped (no Strategy doc impact)
- PROJ-261: Foundation fix (internal only)

### Cross-Sync
- 0 terminology mismatches
- 1 workflow doc needs update (flagged)

### Doc Freshness
Strategy docs now reflect all shipped features through YYYY-MM-DD.
Next sync recommended after: [next phase ships]
```

## Cadence

Run at these moments:
- **After UAT passes** for a phase or stage — the primary trigger
- **Before stakeholder presentations** — ensure docs are current
- **Before onboarding a new team member** — they'll read these docs first
- **When `/roadmap-review` flags doc staleness**

## Rules

- **Code is truth.** If the code differs from the light spec, the Strategy doc should match the code — not the spec.
- **Preserve future-stage content.** Keep descriptions of features that haven't been built yet. Mark them clearly as planned.
- **Maintain audience level.** Use the manifest's Audience field. Stakeholder docs stay simple even when the feature is complex.
- **Present diffs for approval.** Always show proposed changes and get human approval before writing.
- **Version discipline.** Every sync bumps the version. Avoid silent edits.

## Related

- See `method.md` — this skill is the post-pipeline documentation step
- `/strategy-create` — bootstraps the docs this skill updates
- `/roadmap-review` — flags doc staleness; run this skill to resolve it
- `/release-changelog` — generates release-level Changelog entries from git commits; complementary to this skill which keeps Strategy docs current
- `/light-spec` — the specs that feed into this skill's comparison logic
