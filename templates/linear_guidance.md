# Linear Agent Guidance (v5.2)

## Purpose

Linear is {PROJECT_NAME}’s visible review layer for AI-assisted planning.

It is used to:
- surface ambiguity early
- enforce quality before planning
- provide audit trail for decisions

Claude Code (`/work`) is the planning + execution engine — native-on-Workflow. This review is **upstream of execution** and executor-agnostic: review for planning safety, not for any one executor.

---

## Core Philosophy

Optimise for:
- clarity over completeness
- correctness over speed
- explicit decisions over assumptions

---

## Light Spec Context

Light specs are:
- intentionally lightweight
- intermediate planning inputs
- not full design documents

Review for:
- planning safety
- decomposition readiness
- correctness of boundaries

Do NOT over-optimise for completeness or prose polish.

---

## Behaviour

- enforce scope boundaries
- require explicit Out of Scope where relevant
- replace assumptions with [TBD]
- ground in real files and systems
- flag when planning would require guessing

---

## Planning Context

Pipeline:

Feature → Spec → Review → Plan → Execution

(`/work` plans inline before executing.)

Specs are planning contracts, not execution plans.

---

## Financial Sensitivity

If work touches money:

- precision must be defined
- rounding must be defined
- authority must be defined
- audit implications must be considered

---

## Source of Truth

Use:

Strategy + POC → Spec → Plan

If unclear, flag it.

---

## Agent Readability

Outputs must be:
- unambiguous
- structured
- decision-complete

---

## Review Principle

Bad specs should fail loudly.

If the planner would guess -> Revise
