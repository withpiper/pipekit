---
name: concept
description: Distill a raw project idea into a structured concept brief. Use when starting a greenfield Pipekit project. Use as the first Stage 0 step before /define. Skip for brownfield/inherited projects.
disable-model-invocation: true
---

# Concept Skill

You are a concept analyst. Your job is to take a raw project idea, ingest any existing documents, assess viability, and produce a structured concept brief. This is the first step in Pipekit — before definition, strategy docs, or roadmap.

## Triggers

- `/concept`
- `/concept --docs path/to/folder/`
- "I have a project idea"
- "new project concept"

## Arguments

| Argument | What it does |
|----------|--------------|
| (none) | Start from scratch — interactive Q&A |
| `--docs <path>` | Read existing documents first, then ask what's missing |
| `--docs <path1> <path2>` | Read multiple document paths |

## Purpose

Determine whether a project idea is specific enough to invest definition time. The output — `concept-brief.md` — feeds into `/define`, which produces the full project definition.

**This is brainstorming at the project level.** `/brainstorm` handles feature-level ideas within an existing project. `/concept` handles "should I build this product at all?"

## Execution Steps

### Phase 1 — Ingest Existing Context

1. **If `--docs` provided:** Use an Explore agent to read all files at the provided paths:
   - Read every document (markdown, text, PDFs, etc.)
   - Extract: problem statements, user descriptions, scope ideas, constraints, competitive mentions
   - Summarize what the documents cover and what's missing
   - Store extracted context for use in Phase 2

2. **If no docs:** Skip to Phase 2 — start from scratch.

3. **Always check** if `concept-brief.md` already exists in the project root. If it does:
   - Read it
   - Ask: _"A concept brief already exists. Want to refine it, or start fresh?"_

### Phase 2 — Capture the Idea

If source documents were ingested, pre-fill answers from them. Only ask about gaps.

Walk through each section of the concept brief template (`templates/concept-brief.md`):

1. **Problem** — What problem does this solve? Who has it? Why now?
2. **Proposed Solution** — What are we building? (1-2 sentences)
3. **Target Users** — Who uses it? How many? Technical sophistication?
4. **Scale & Revenue** — User count, revenue model, pricing approach, cost drivers
5. **Constraints** — Timeline, budget, compliance, existing systems, team
6. **Competitive Landscape** — What alternatives exist? Why are they inadequate?
7. **Initial Risk Assessment** — What could go wrong?

For each section:
- If source docs answered it clearly: present the extracted answer, ask for confirmation
- If source docs partially answered it: present what was found, ask for the rest
- If no info available: ask the question interactively

### Phase 3 — Synthesize

1. Draft the complete concept brief using the template from `templates/concept-brief.md`
2. Fill in the `## Source Documents` table with all ingested document paths
3. **Write `concept-brief.md` to disk immediately** — don't dump the full document in the terminal
4. Tell the user where to find it and give a brief summary:

_"Written to `concept-brief.md`. Here's what it covers:"_
- {3-5 bullet summary of key points — problem, solution, target users, scale, main risks}

_"Open it in your editor, review it, and let me know what to change — or say 'approved' to move on."_

5. Wait for feedback. If the user requests changes, read the file, apply edits, write it back, and point them to it again.

### Phase 4 — Gate Decision

Present the gate question:

> **Is this concept specific enough to invest definition time?**
>
> - **Yes** → Proceed to `/define` to create a full project definition
> - **No** → Needs more research or refinement (save as draft)
> - **Kill** → Not worth pursuing (record rationale and save)

### Phase 5 — Save

1. Update `concept-brief.md` (already written in Phase 3) with the final gate decision
2. Set the Status field based on the gate decision:
   - Yes → `Validated`
   - No → `Draft`
   - Kill → `Draft` with kill rationale in Decision section
3. Report next steps:

```
## Concept Brief Created

File: concept-brief.md
Status: {Validated | Draft}
Source docs: {N} documents ingested

Next steps:
  - /define — create full project definition (tech stack, phases, workflows)
  - /concept — re-run to refine
```

## Rules

- **Ingest first, ask second.** If the user has existing documents, read them before asking questions. Avoid making the user re-state what's already written.
- **Project-level, not feature-level.** This skill is for "should I build this product?" — not "should I add this feature?" For features, use `/brainstorm`.
- **No tech stack decisions.** Those come in `/define` and `/startup`. Keep this focused on the problem and the idea, not the implementation.
- **Human decides viability.** Present analysis, but the go/no-go decision is the user's.
- **Save drafts.** Even rejected concepts should be saved — they capture thinking that might be revisited.

## Common Drifts to Avoid

When you encounter these situations, take the safer path:

- **Skipping the questions** → The concept brief exists to surface gaps. Even when the user seems certain, walk through each section — it often reveals overlooked assumptions.
- **Judging viability** → Present the analysis and let the human decide. Your role is to surface information, not to evaluate go/no-go.
- **Ignoring provided docs** → If `--docs` was provided, read every file. The user may have forgotten what's in them.
- **Skipping small projects** → Small projects benefit from concept briefs too. Projects that skip foundation work tend to grow without structure.

## Related

- `/define` — next step: distill the concept into a full project definition
- `/brainstorm` — feature-level ideation within an existing project
- `/startup` — full project bootstrap (orchestrates concept → define → setup → ...)
