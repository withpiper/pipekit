# Skills SOP

> For the full development pipeline, see [method.md](../method.md).

**Last updated:** 2026-04-08

---

## How Skills Work

This method uses three layers to enforce development conventions:

| Layer | Purpose | Who it serves |
|---|---|---|
| **CLAUDE.md** | Documents conventions so VBW agents follow them automatically | VBW dev agents during plan execution |
| **CI / Hooks** | Hard enforcement — blocks merges that violate conventions | Everyone (agents and humans) |
| **Skills** | Interactive shortcuts for hands-on sessions | You, when working with Claude directly |

Skills are convenience wrappers. They automate the same conventions documented in CLAUDE.md. VBW agents don't call skills — they read CLAUDE.md and write code directly.

---

## Portable vs Project-Specific Skills

### Portable Skills (from method repo)

These skills work across any project that follows the method. They read `method.config.md` for project-specific values.

| Skill | Purpose | Pipeline Stage |
|-------|---------|---------------|
| `/concept` | Project-level ideation — produce a concept brief | Stage 0: Foundation |
| `/define` | Distill concept into full project definition | Stage 0: Foundation |
| `/strategy-create` | Bootstrap strategy docs from project definition | Stage 0: Foundation |
| `/roadmap-create` | Create ROADMAP.md and populate Linear | Stage 0: Foundation |
| `/phase-plan` | Select and manage execution phases | Stage 0: Foundation / Ongoing |
| `/roadmap-review` | Pre-pipeline health check (Stage 0 gate) | Stage 0 → Stage 1 gate |
| `/brainstorm` | Feature-level feasibility exploration | Stage 1: Definition |
| `/brainstorm-review` | Triage untriaged Linear issues | Stage 1: Definition |
| `/light-spec` | Structured spec generation with agent review | Stage 1: Definition |
| `/light-spec-revise` | Apply Spec Review Agent feedback surgically; detect stalemate loops | Stage 1: Definition |
| `/spec-preflight` | Empirical pre-flight checks on a Linear issue's spec — verifies file paths, line refs, phase-detect baseline, Linear status against reality. Read-only. | Stage 1 / pre-Launch gate |
| `/launch` | Formalized trigger: gates → routing → execution | Stage 2: Launch & Planning |
| `/linear-todo-runner` | Batch execution of specced issues | Stage 3: Execution |
| `/linear` | Linear issue workflow | Anytime |
| `/linear-status` | Quick triage view of board status | Anytime |
| `/sync-linear` | Bidirectional VBW ↔ Linear sync | Anytime |
| `/branch` | Create worktree + branch + optional Linear link | Anytime |
| `/start-session` | Review past progress, capture intentions | Anytime |
| `/end-session` | Session wrap-up: changelog, Linear updates | Anytime |
| `/strategy-sync` | Update Strategy docs after shipping | Stage 5: Documentation |
| `/pr-fix` | Precision PR review + fix workflow | Anytime |
| `/security-review` | Security review | Anytime |
| `/spec-validator` | Validate spec completeness | Stage 1: Definition |
| `/skill-index` | Sync skill index after changes | Anytime |
| `/task-processor` | Process Linear tasks systematically | Stage 3: Execution |
| `/startup` | Full project bootstrap orchestrator | Stage 0 (all steps) |
| `/pipekit-update` | Pull latest Pipekit from GitHub into project | Anytime |
| `/release-changelog` | Generate draft CHANGELOG entry from git commits between tags. Output to stdout for human review + edit. | Pipekit-internal release work |

### Project-Specific Skills (stay in each project)

These are tied to your stack, infrastructure, or deployment pipeline:

- Promotion skills (`/g-promote-dev`, `/g-promote-beta`, `/g-promote-main`)
- Deploy/verify skills (`/g-deploy`, `/g-test-vercel`)
- Migration skills (`/migrate`)
- Scaffold skills (`/component`)
- Data management skills (`/reset-user`)

---

## Skill Anatomy

Every skill lives in `.claude/skills/{name}/skill.md` with frontmatter:

```markdown
---
name: skill-name
description: One-line description of what the skill does
---

# Skill Name

[Full skill instructions...]
```

### Key Conventions

1. **Read `method.config.md`** for project-specific values (Linear team, issue prefix, state IDs)
2. **Read `CLAUDE.md`** for project coding conventions
3. **Use Linear MCP tools** for issue management (`mcp__linear-server__*`)
4. **Use VBW agents** for planning and execution (`vbw:vbw-lead`, `vbw:vbw-dev`, `vbw:vbw-qa`)

### The `NEXT.md` Convention

Every Pipekit skill that produces a meaningful state transition (completes a pipeline step, promotes issues, ships a feature, etc.) MUST do two things in lockstep:

1. **Print `➜ Next:` inline** in the terminal — tells the current user what command to run next and why.
2. **Overwrite `NEXT.md` at the project root** with the same content — gives tomorrow's user (or a new session) the same pointer.

Because both are written by the same code path in the same skill run, drift is impossible. The file is fresh whenever the user closed the session.

**Required `NEXT.md` schema:**

```markdown
# Next Step

**Last updated:** {YYYY-MM-DD HH:MM local} by {skill name}

## Recommended next command
`{command}`

## Why this one
{1-3 sentences on why this is the highest-leverage next action}

## Parallelizable after this (optional)
- {other commands that can run in parallel once this one starts}

## Blocked, do later (optional)
- {commands that depend on this one completing first}
```

Always include both date and time in the `Last updated` line. A bare date hides multi-session days (common when shipping more than one issue) and makes it ambiguous whether `NEXT.md` is fresh or held over from morning. Local time is fine — users read this in their terminal, not machine-parse it.

**Which skills must write `NEXT.md`:**
- `/startup` — after each step completes (always point to the next step or `/start-session` if done)
- `/roadmap-create` — after roadmap is populated, point to `/phase-plan` or `/roadmap-review`
- `/phase-plan` — after phase is planned, point to `/01-light-spec {first issue}`
- `/01-light-spec` — after spec is drafted and approved, point to `/launch {issue}` or the next issue
- `/launch` — after gates pass, point to VBW execution or the next issue to spec
- `/strategy-sync` — after docs are updated, point to the next unshipped issue
- `/end-session` — after session log is written, recompute based on Linear state (next Approved issue, `/strategy-sync` if pending marker exists, or `/phase-plan` if phase complete). Prevents stale NEXT.md pointing at a just-shipped issue.

**`NEXT.md` lives at the project root** (not in `.vbw-planning/` — that directory is hidden and confusing for users). Visible alongside `concept-brief.md`, `project-definition.md`, `method.config.md`.

**`/start-session` reads and displays it** automatically at session start, so users don't need to navigate to the file.

---

### Writing Skill Prompts for Opus 4.7

Opus 4.7 follows instructions more literally than prior models. It won't silently generalize "update the doc" into "update all three docs" — it'll update one. Skill authors must be explicit about scope:

- **Quantify loops.** "For each strategy doc in the manifest" not "for strategy docs." Specify the source list (e.g., the `method.config.md` Strategy Docs table) so there's no ambiguity about which items.
- **Name the fields.** "Populate these specific fields in method.config.md: Project name, Display name, Worktree prefix" not "update method.config.md with relevant values."
- **Scope modifiers.** When something should apply broadly, say so: "Apply this formatting to every section in the document, not just the first one."
- **Avoid relative qualifiers.** Words like "relevant," "appropriate," "as needed" let Opus 4.7 narrow scope. Replace with explicit criteria: "if the field is empty" rather than "update relevant fields."
- **Batch questions in the first turn.** Don't drip-feed requirements across turns — it reduces both quality and token efficiency. Collect all clarifying questions and ask them together.
- **State acceptance criteria explicitly.** "Done when X, Y, and Z are all true" — not "when this looks good."

When a skill's behavior depends on tool calls or subagents, give explicit guidance on when to use them (see also: subagent guidance in individual skills).

---

### Pinning models on subagents

Any skill that invokes `Agent()` should **explicitly pass `model:`** rather than relying on default inheritance. A skill that runs inside an Opus session will otherwise silently run execution agents on Opus too — expensive and usually unnecessary.

Defaults we've found to work well:

| Agent role | Default model |
|------------|---------------|
| Planning (`vbw:vbw-lead`, `plan-reviewer`, spec reviewers) | `opus` |
| Execution (`vbw:vbw-dev`, batch runners) | `sonnet` |
| Verification (`vbw:vbw-qa`) | `sonnet` |

Add an escape hatch (e.g., a `--deep` flag) when the skill routes to an execution agent that sometimes needs heavier reasoning — race conditions, silent failures, cross-layer bugs. See `skills/launch/skill.md` for a worked example.

This defaults-plus-flag pattern is the forerunner of Anthropic's model-use decision tree (in beta). When that ships, individual skills should migrate to it; this SOP section will point there instead.

---

## Syncing Portable Skills

Portable skills are maintained in the method repo and synced into projects via `scripts/sync-method.sh`. After syncing, the skills appear in `.claude/skills/` alongside project-specific skills.

To update: `./scripts/sync-method.sh [tag]`

---

## Next-Step Nudges (Opt-In Stop Hook)

Pipekit ships `scripts/pipekit-next-step-nudge.sh` — a Stop hook that suggests `/pipekit-help` after a pipeline-relevant skill finishes. The hook is **opt-in** (not registered automatically) and **scoped by behavior** (silent unless the most recent assistant turn invoked `/launch`, `/light-spec`, `/light-spec-revise`, `/review-plan`, `/strategy-sync`, or `/vbw:vibe`).

To enable, add this to `.claude/settings.local.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {"type": "command", "command": "$CLAUDE_PROJECT_DIR/scripts/pipekit-next-step-nudge.sh"}
        ]
      }
    ]
  }
}
```

The hook prints a one-line nudge to stderr — Claude Code surfaces this back as additional context for the next turn. Exit code is always 0; the hook never blocks output.

Disable any time by removing the entry from `settings.local.json`. To customize which skills trigger the nudge, fork the script — the override system covers `skills/`, `sop/`, and `method.md` only; scripts are not currently in the override scope.

---

## Canonical-file protection (agent-protected paths)

Some files in a Pipekit project are **canonical** — they encode conventions that VBW agents should *read* but not *mutate*. The default protected set lives under `.claude/rules/*` (the portable `pipekit-discipline.md`, `pipekit-tooling.md`, `pipekit-security.md` hub-and-spoke template). Projects can opt additional paths into protection — `Strategy/`, `method.config.md`, and `PHASES.md` are common candidates.

Protection is enforced by **hook**, not by skill prose. A `PreToolUse` hook on `Edit` and `Write` blocks the call when the target path matches the protected set; the agent receives `EditPermissionDenied` (or `HookFeedbackBlocked`, depending on the hook variant). This is intentional: hooks win over `bypassPermissions` mode because hook-level guards are the project's last line of defense, and orchestrator-spawned agents are not exempt from project policy.

The corresponding skill-side discipline (since v1.4.0): every skill that spawns an agent expected to call `Edit`/`Write` includes a **permission-denial-stop instruction** in the agent's task description (see `skills/06-linear-todo-runner/skill.md` § Permission-denial protocol and the parallel block in `skills/launch/skill.md`). Without that instruction, agents tend to retry on denial, exhaust attempts, and report partial progress — the user only finds out the work was blocked after burning turns. With it, the agent stops on first denial and surfaces the denied path, intended change, and rationale, so the user can either grant the exception (revise hook), redirect the work, or abort the issue.

When you add a new skill that spawns file-editing agents, copy the permission-denial block verbatim. When you protect a new path with a hook, document the protection in `method.config.md` so future readers know which paths are agent-write-locked and why.

## Customizing Synced Skills (Overrides)

If a project needs to change behavior of a synced skill, **do not edit the file in `.claude/skills/<name>/` directly** — it will be overwritten on the next sync. Use the override system instead:

1. Copy the skill into `.claude/overrides/skills/<name>/skill.md`.
2. Make your project-specific edits there.
3. Add a row to `.claude/overrides/MANIFEST.md` explaining what you changed and why.
4. Re-run `scripts/sync-method.sh` — the override is applied on top of the upstream sync.

The sync script saves a snapshot of the upstream version it replaced and warns on the next sync if upstream has changed the same file (so you can review whether your override is still appropriate).

See `method.md` § Sync-Safe Overrides for the full contract.
