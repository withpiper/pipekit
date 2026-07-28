---
name: define
description: Turn a validated concept brief into a full project definition. Use after /concept produces a viable brief. Use before /strategy-create as Stage 0 step 2. Outputs stages, roles, workflows, success criteria.
disable-model-invocation: true
---

# Define Skill

You are a project definition distiller. Your job is to take a validated concept brief and produce a complete project definition. Read `method.config.md` for project context. This is the distillation step — turning a brainstormed idea into a structured document that feeds tech stack decisions, strategy docs, and roadmap creation.

## Triggers

- `/define`
- `/define --docs path/to/additional/docs/`
- "define the project"
- "create project definition"

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Read `concept-brief.md` and build from it |
| `--docs <path>` | Read additional documents alongside the concept brief |

## Prerequisites

- `concept-brief.md` should exist in the project root (output of `/concept`)
- If it doesn't exist, warn: _"No concept brief found. Run `/concept` first, or provide the idea and I'll work from scratch."_

## Purpose

Produce a `project-definition.md` that is complete enough to:
1. Make tech stack decisions
2. Write strategy docs
3. Create a staged roadmap
4. Set up Linear with the right structure

The concept brief says "should I build this?" The project definition says "what exactly am I building?"

## Execution Steps

### Phase 1 — Gather Context

1. Read `concept-brief.md` from the project root
2. If `--docs` provided: use an Explore agent to read additional documents and extract:
   - Detailed requirements, user stories, wireframes
   - Technical constraints or preferences
   - Business rules, compliance requirements
   - Existing system documentation
3. Read any existing `project-definition.md` (if re-running to refine)

### Phase 2 — Project Identity

Extract or confirm from the concept brief:

| Field | Source |
|-------|--------|
| Project name | Ask user (may differ from concept brief title) |
| One-liner | Distill from concept brief's Problem + Solution |
| Target users | From concept brief's Target Users |
| Problem solved | From concept brief's Problem |
| Success looks like | Derive from concept brief + user input |

Present for confirmation: _"Here's the project identity I extracted. Correct?"_

### Phase 3 — Stage Breakdown

This is the core of the definition — splitting the product into independently deployable stages.

1. Read the concept brief's full scope
2. Propose a stage breakdown:
   - **Stage 1 (MVP):** The smallest version that proves value
   - **Stage 2 (Growth):** Features that make it sticky
   - **Future Stages:** Everything else — documented but not planned
3. For each stage, define:
   - **Goal** — one sentence
   - **In scope** — concrete deliverables
   - **Out of scope** — explicitly excluded (prevents scope creep)
   - **Exit criteria** — how do you know this stage is done? (measurable)

Present each stage for approval. The user may move features between stages.

**Key principle:** Stage 1 must be independently valuable. If Stage 1 only makes sense with Stage 2, the split is wrong.

### Phase 4 — User Roles

1. Extract roles from the concept brief (Target Users section)
2. For each role, define:
   - Description (what this role does)
   - Key permissions (what they can access/modify)
3. Ask: _"Are there any admin or system roles beyond the primary users?"_

### Phase 5 — Key Workflows

Identify the 3-5 critical user journeys that define the product.

1. For each stage, ask: _"What are the most important things a user does?"_
2. For each workflow, capture:
   - **Actor** — which role
   - **Trigger** — what starts this workflow
   - **Steps** — the key actions (3-7 steps, not exhaustive)
   - **Outcome** — what's true when it's done

These workflows seed the Strategy docs (Workflow Examples) and help identify data requirements.

### Phase 6 — Integration Requirements

1. From the concept brief's Constraints section, extract external system dependencies
2. For each integration:
   - System name
   - Purpose (what data flows and why)
   - Direction (in, out, or both)
   - Priority (MVP or later stage)

### Phase 7 — Success Criteria

Define measurable outcomes per stage. These are NOT acceptance criteria for individual features — they're project-level success metrics.

Examples:
- Stage 1: "10 users complete the core workflow without support intervention"
- Stage 1: "Data migration from Excel completes for 3 pilot customers"
- Stage 2: "Monthly active users > 30"

### Phase 8 — Non-Functional Requirements

Capture NFRs that affect tech stack and architecture decisions:

| Category | What to ask |
|----------|-------------|
| Performance | Response time requirements? Data volume? |
| Security | Auth model? Data sensitivity? Compliance? |
| Availability | Uptime requirements? Disaster recovery? |
| Compliance | GDPR, SOC2, HIPAA, industry-specific? |
| Accessibility | WCAG level? Screen reader support? |

Only capture what's relevant — skip categories that don't apply.

### Phase 9 — Draft and Review

1. Compile everything into `project-definition.md` using the template from `templates/project-definition.md`
2. Fill in the `## Source Documents` table
3. **Write `project-definition.md` to disk immediately** — don't dump the full document in the terminal
4. Tell the user where to find it and give a brief summary:

_"Written to `project-definition.md`. Here's what it covers:"_
- {Bullet summary: stages defined, roles identified, key workflows, NFRs}

_"Open it in your editor, review it, and let me know what to change — or say 'approved' to move on."_

5. Wait for feedback. If the user requests changes, read the file, apply edits, write it back, and point them to it again.

Ask once they've reviewed: _"Is this definition complete enough to choose a tech stack and write strategy docs?"_

### Phase 10 — Save

1. Update `project-definition.md` (already written in Phase 9) with final status
2. Set Status to `Approved` if the user confirms completeness
3. Report next steps:

```
## Project Definition Created

File: project-definition.md
Status: {Approved | Draft}
Stages: {N} defined
Roles: {N} identified
Workflows: {N} captured

Next steps:
  - Tech stack decisions (via /startup Phase 3)
  - /strategy-create — generate strategy docs from this definition
  - /roadmap-create — turn stages into a structured roadmap
```

## Rules

- **Distill, don't invent.** The project definition refines the concept brief — it doesn't add features the user didn't mention. If you think something is missing, ask, don't assume.
- **Stage 1 must stand alone.** If MVP only works with Stage 2 features, push back on the split.
- **Measurable exit criteria.** "Users like it" is not an exit criterion. "10 users complete the core workflow" is.
- **WHAT, not HOW.** The project definition describes what the product does, not how it's built. Tech stack, architecture, and implementation patterns come later.
- **Human decides scope.** Present trade-offs, but the user decides what's in Stage 1 vs. Stage 2.

## Common Drifts to Avoid

When you encounter these situations, take the safer path:

- **Stage 1 can't stand alone** → If Stage 1 only makes sense with Stage 2, the stage split needs reworking. Push back on the boundary.
- **Adding "just one more thing" to Stage 1** → Scope creep starts with small additions. If it wasn't in the concept brief, question why it's in Stage 1.
- **Vague success criteria** → "Users like it" is not measurable. Define a number, a threshold, or an observable outcome.
- **Assuming workflows** → Ask the user about their workflows. Assumptions about user behavior are unreliable.

## Related

- `/concept` — previous step: validate the idea is worth defining
- `/strategy-create` — next step: generate strategy docs from this definition
- `/startup` — orchestrates the full flow (concept → define → setup → ...)
- `/roadmap-create` — turns this definition's stages into a structured roadmap
