# Skills SOP

> For the full development pipeline, see [method.md](../method.md).

**v2.7.0** — Last updated: 2026-06-05  *(v2.7.0 final: `/pr-fix` row updated for the pluggable engine + historical finders + two-axis triage; `/light-spec` and `/verify` rows updated for the configured `Spec ready state` and the migration self-review verdict)*

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

| Command / Skill | Purpose | Pipeline Stage |
|-----------------|---------|---------------|
| `/concept` | Project-level ideation — produce a concept brief | Stage 0: Foundation |
| `/define` | Distill concept into full project definition | Stage 0: Foundation |
| `/strategy-create` | Bootstrap strategy docs from project definition | Stage 0: Foundation |
| `/roadmap-create` | Create ROADMAP.md and populate Linear | Stage 0: Foundation |
| `/phase-plan` | Select and manage execution phases | Stage 0: Foundation / Ongoing |
| `/startup` | Full project bootstrap orchestrator | Stage 0 (all steps) |
| `/roadmap-review` | Pre-pipeline health check (Stage 0 gate) | Stage 0 → Stage 1 gate |
| `/brainstorm` | Feature-level feasibility exploration | Stage 1: Spec |
| `/brainstorm-review` | Triage untriaged Linear issues | Stage 1: Spec |
| `/light-spec` | Structured spec generation with auto-cycled agent review (Phase 6 invokes `pk spec-cycle` + `/light-spec-revise` internally, max 3 passes). v2.7.0+: publishes to the configured `Spec ready state` (not a hardcoded `Specced`), so two-state boards (e.g. `Needs Spec → Approved`) work. | Stage 1: Spec |
| `/light-spec-revise` | Apply Spec Review Agent feedback surgically; detect stalemate loops. Usually invoked by `/light-spec` Phase 6, can also run standalone. | Stage 1: Spec |
| `pk spec-cycle <ID>` | Trigger Spec Review Agent v5, poll Linear for verdict, transition to Approved on Pass. Bash-side helper used by `/light-spec`'s cycle — keeps polling out of Claude's context. | Stage 1: Spec |
| `/spec-preflight` | Empirical pre-flight checks on a specced Linear issue (file paths, line refs, phase-detect baseline, Linear status). Read-only. | Stage 1 → Stage 2 gate |
| `pk next` | Phase-aware: groups Linear results by status (In Progress / Approved / Needs Spec) | Stage 2: Plan + Build |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent) | Stage 2: Plan + Build |
| `/work <ID>` | Plan + execute. Dispatches to `vbw` or `native` backend per `method.config.md`. | Stage 2: Plan + Build |
| `/review-plan` | Spawns `plan-reviewer` agent against `PLAN.md` (vbw backend). | Stage 2: Plan + Build |
| `/verify` (or `pk verify`) | Pre-deploy gate (types + lint + test); QA subagent if `Require QA review: true`. v2.7.0+: migration-touching diffs get a self-review subagent (M1–M8 rubric) carrying a Hold/Approve verdict, not a raw `git show`. | Stage 3: Verify + Ship |
| `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` flags review-in-flight + prints reviewer invocation. | Stage 3: Verify + Ship |
| `pk ready [<ID>]` | Flip Draft PR to Ready (v2.6.0+). Fires `ready_for_review` → outside reviewers (Semgrep + claude-review per `templates/ci/`) run. No Linear state change. | Stage 3: Verify + Ship |
| `/pr-fix` | Pluggable-engine PR review (`--engine=native` pr-review-toolkit default · `--engine=builtin` dependency-free fallback, fail-loud) + historical finders (git-history blame-regression + prior-PR-comments reapplication, v2.7.0, both engines); two-axis severity×confidence triage with INVESTIGATE quadrant; fixed / rejected / deferred + Linear summary. `--from-review` ingests GHA comments; `--runs=N` raises confidence on recurrence; `--second-opinion=gemini` adds a parallel Gemini Flash read. | Stage 3: Verify + Ship |
| `/pr-security-review` | Security-focused antagonistic review for migrations / RLS / SECURITY DEFINER / auth | Stage 3: Verify + Ship |
| `/pk-bug` | Bug pipeline: intake → reproduce → regression-test-first → fix → ship → postmortem. Wraps `/work` + `pk ship` with discipline gates. | Anytime (parallel pipeline) |
| `/pk-express` | Idea→Draft-PR autopilot for **simple** WITs: chains `/brainstorm` → `/light-spec` (auto-cycle to Approved) → `pk branch` → `/work` (auto verify+ship), advancing on success and stopping only at attention gates (not-Now, tier:heavy, spec stalemate, verify flags, Draft PR). Quick/Standard tier only. | Anytime (express lane) |
| `pk done <ID> [--merge]` | Post-merge cleanup: worktree+branch, commits to Linear, Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). v2.6.0+: also auto-pulls integration + writes `.vbw-planning/.../SUMMARY.md` + flips PLAN status. `--merge` lets pk run `gh pr merge` first. | Stage 4: Release |
| `pk promote <env>` | Phase 1 (v2.6.0+): opens promote PR along `Ship environments`. WITs stay in source state. 2-tier: `pk promote` with no arg picks the only hop. | Stage 4: Release |
| `pk promote <env> --finish` | Phase 2 (v2.6.0+): after the promote PR merges, transitions WITs → `In <Env>` (intermediate, e.g. `In Beta`) or → Done (final). | Stage 4: Release |
| `/strategy-sync` | Update Strategy docs after shipping | Stage 5: Doc Loop |
| `/pk-exit` | Narrative session log to `Logs/Sessions/<date>_<HHMM>.md` | Per session |
| `pk status` | Full unscoped Linear board view | Anytime |
| `pk doctor` | Diagnostic: config validity, Linear API access, worktree dir, stale artifacts | Anytime |
| `pk init` | One-time per consuming project: seeds `notepad.md`, `Logs/Sessions/`, checks config | One-time setup |
| `/linear` | Linear issue workflow helper | Anytime |
| `/sync-linear` | Bidirectional VBW ↔ Linear sync | Anytime |
| `/pipekit-help` | Read project state, recommend next pipeline step | Anytime |
| `/spec-validator` | Validate spec completeness | Stage 1: Spec |
| `/security-review` | Periodic repo security audit (different from `/pr-security-review`) | Anytime |
| `/financial-review` | Periodic financial-accuracy review for finance/calculation-heavy projects — cross-layer parity audit (DB view ↔ calc ↔ UI), severity-ranked report, recurring-WIT lifecycle. Portable **framework**; concrete checks live in a per-project checks file (`resources/financial-review-checks.md`, scaffolded from `templates/financial-review-checks.template.md`). No-op on projects without a checks file. | Anytime (domain: finance) |
| `/skill-index` | Sync skill index after changes | Anytime |
| `/task-processor` | Process Linear tasks systematically | Stage 2: Plan + Build |
| `/pipekit-update` | Pull latest Pipekit from GitHub into project | Anytime |
| `/release-changelog` | Generate draft CHANGELOG entry from git commits between tags. Output to stdout for human review + edit. | Pipekit-internal release work |

### Project-Specific Skills (stay in each project)

In v2, the daily delivery loop (push, PR, promote, migrate) is covered by `pk ship`, `pk promote`, Vercel hooks, and GitHub Actions (`db-migrate.yml` + `db-pr-check.yml` for Supabase). Project-specific skills are limited to things that genuinely depend on your domain or schema:

- Component scaffolding (`/component`) — monorepo with shared UI
- Test data reset (`/reset-user`) — auth + user system
- Test data seeding (`/seed-data`) — repeatable fixtures
- Schema export (`/export-schema`) — sharing schema with non-Pipekit consumers

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

### Frontmatter Conventions

Two patterns are now standard:

**1. `description:` as trigger surface.** The `description` field is where you pack invocation triggers. Format:

```
description: <one-line what it does>. Use when <condition A>. Use when <condition B>.
```

The "Use when" clauses are what Claude scans to decide whether to auto-invoke. Vague descriptions ("Helper skill for X") will not be invoked when they should be; trigger-phrased descriptions will. Temporal variants (`Use after`, `Use before`, `Use as Stage 0 step…`) are acceptable when the trigger is sequential rather than conditional.

**2. `disable-model-invocation: true` for prompt-only skills.** Skills that should only run when the user explicitly types `/<name>` — never auto-invoked — set this key. Currently applied to: `/pk-exit`, `/concept`, `/define`. Cost is one frontmatter line; benefit is explicit intent signal and cheaper agent runs.

### Body Conventions for High-Stakes Skills

Skills that gate ship/merge decisions (`/verify`, `/pr-fix`, `/pr-security-review`, `/work`, `/pk-bug`) include two extra body sections:

- **`## When NOT to use`** — explicit anti-criteria. Prevents misuse on the wrong surface. Example for `/verify`: "Not for design review — see `/pr-fix`. Not for security audits — see `/security-review`."
- **`## Common Rationalizations`** — three to five sentences the user might say to skip the skill, paired with the rebuttal. Example for `/verify`: "'It's a small change' → run the gate anyway; the gate is the gate."

These sections are *not* required for low-stakes skills (`/sync-linear`, `/skill-index`) — they'd be noise. Apply only where misuse has a meaningful cost.

### Key Conventions

1. **Read `method.config.md`** for project-specific values (Linear team, issue prefix, state IDs)
2. **Read `CLAUDE.md`** for project coding conventions
3. **Use Linear MCP tools** for issue management (`mcp__linear-server__*`)
4. **Dispatch heavy planning + execution through `/work`** (which routes to the `vbw` or `native` backend per `method.config.md`). Don't invoke `vbw:vbw-lead`, `vbw:vbw-dev`, or `vbw:vbw-qa` directly from skills — that bypasses Pipekit's backend dispatch and visibility layer. Skills that genuinely need a planning subagent for narrow internal work (e.g., spec-review agents in `/light-spec`) may still spawn dedicated subagents; the rule is about replacing the daily-loop work pipeline, not all `Agent()` calls.

### "What's next?" in v2 — `pk next` reads Linear

v2 retired the v1 `NEXT.md` mirror. The single source of truth for "what should I do next?" is **Linear**, accessed via:

- **`pk next`** — phase-aware (reads `## Current Phase:` from `PHASES.md`, matches to `linear-map.json`, groups Linear issues by status with per-group hints). Falls back to global "next Approved" when no phase context. Best when you know you want to pick up the next issue.
- **`pk status`** — full unscoped board view across all phases. Best when you want the wider picture.
- **`/pipekit-help`** — context-aware skill recommendation based on full project state (Linear, `PHASES.md`, recent transitions, pipeline-state files). Best when you're not sure *which step* in the pipeline to run next.

Skills should **not** write a `NEXT.md` file. Skills MAY still print `➜ Next:` inline at the end of their output as a courtesy hint to the current user, but the persistence layer is Linear, not a sidecar markdown file.

`pk init` (v2.1.1+) seeds a gitignored `notepad.md` at the project root for personal free-form notes (replaces NEXT.md as a human scratch space). It is never committed and never auto-written by skills.

#### Pipekit machine-local state directory

Pipekit's ephemeral, per-machine state (post-archive marker, per-issue pipeline-state records) lives **outside** the repo at:

```
${XDG_CACHE_HOME:-$HOME/.cache}/pipekit/<repo-basename>/
├── pending-strategy-sync          # post-archive marker (see /strategy-sync)
└── pipeline-state/
    └── <issue-id>.json            # per-skill transition state
```

**Why out-of-repo:** earlier Pipekit placed these files at `<repo>/.pipekit/`, which sits inside the repo and got blocked by VBW's file-guard hook during active-plan scope. Moving the directory outside the repo lets VBW's file-guard ignore it entirely, so writes succeed unconditionally.

**Resolving the path:** every skill that reads/writes Pipekit state uses the helper:

```bash
STATE_DIR=$(bash scripts/pipekit-state-dir.sh)
mkdir -p "$STATE_DIR"
```

`scripts/pipekit-state-dir.sh` resolves `${XDG_CACHE_HOME:-$HOME/.cache}/pipekit/<repo-basename>` (basename derived from `git rev-parse --show-toplevel`). All file paths below are *relative to* `$STATE_DIR`.

#### Pipeline state file

Each pipeline skill that completes a meaningful state transition writes a small JSON file to `$STATE_DIR/pipeline-state/<issue-id>.json` capturing the transition:

```json
{
  "issue_id": "RS-19",
  "stage": "work",
  "timestamp": "2026-04-29T14:32:00-04:00",
  "verdict": "Pass",
  "cwd": "/Users/x/Projects/rs-vault"
}
```

Fields:
- `issue_id` — Linear ID (or phase slug for VBW-only flows)
- `stage` — skill / `pk` subcommand name (`work`, `verify`, `ship`, `done`, `review-plan`, etc.)
- `timestamp` — ISO-8601 with offset
- `verdict` — for skills that produce one (`Pass` / `Revise` / `Block` / `Fail`); `null` for transitions without a verdict
- `cwd` — absolute path of the project root at the time of write

The state file is consumed by `pk *` commands (e.g., `pk done` reads transition history when posting the Linear close comment) and by `/pipekit-help` for state-aware recommendations. Skills overwrite their own most-recent record — this is a state file, not an event log. The whole tree lives under `$STATE_DIR` (out-of-repo), so nothing needs gitignoring.

---

### Writing Skill Prompts: Be Explicit About Scope

Recent Claude models follow instructions more literally than older generations. The model won't silently generalize "update the doc" into "update all three docs" — it'll update one. This is good prompt hygiene regardless of which model you're on, so skill authors should always be explicit about scope:

- **Quantify loops.** "For each strategy doc in the manifest" not "for strategy docs." Specify the source list (e.g., the `method.config.md` Strategy Docs table) so there's no ambiguity about which items.
- **Name the fields.** "Populate these specific fields in method.config.md: Project name, Display name, Worktree prefix" not "update method.config.md with relevant values."
- **Scope modifiers.** When something should apply broadly, say so: "Apply this formatting to every section in the document, not just the first one."
- **Avoid relative qualifiers.** Words like "relevant," "appropriate," "as needed" let the model narrow scope. Replace with explicit criteria: "if the field is empty" rather than "update relevant fields."
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

Add an escape hatch (e.g., a `--deep` flag) when the skill routes to an execution agent that sometimes needs heavier reasoning — race conditions, silent failures, cross-layer bugs. See `skills/work/skill.md` for a worked example (`/work --deep` adds spec-validator + plan-review + security-review subagents).

This defaults-plus-flag pattern is the forerunner of Anthropic's model-use decision tree (in beta). When that ships, individual skills should migrate to it; this SOP section will point there instead.

---

## Syncing Portable Skills

Portable skills are maintained in the method repo and synced into projects via `scripts/sync-method.sh`. After syncing, the skills appear in `.claude/skills/` alongside project-specific skills.

To update: `./scripts/sync-method.sh [tag]`

---

## Next-Step Nudges (Opt-In Stop Hook)

Pipekit ships `scripts/pipekit-next-step-nudge.sh` — a Stop hook that suggests `/pipekit-help` after a pipeline-relevant skill finishes. The hook is **opt-in** (not registered automatically) and **scoped by behavior** (silent unless the most recent assistant turn invoked a tracked skill).

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

The corresponding skill-side discipline: every skill that spawns an agent expected to call `Edit`/`Write` includes a **permission-denial-stop instruction** in the agent's task description (see `skills/06-linear-todo-runner/skill.md` § Permission-denial protocol and the parallel block in `skills/work/skill.md`). Without that instruction, agents tend to retry on denial, exhaust attempts, and report partial progress — the user only finds out the work was blocked after burning turns. With it, the agent stops on first denial and surfaces the denied path, intended change, and rationale, so the user can either grant the exception (revise hook), redirect the work, or abort the issue.

When you add a new skill that spawns file-editing agents, copy the permission-denial block verbatim. When you protect a new path with a hook, document the protection in `method.config.md` so future readers know which paths are agent-write-locked and why.

## Customizing Synced Skills (Overrides)

If a project needs to change behavior of a synced skill, **do not edit the file in `.claude/skills/<name>/` directly** — it will be overwritten on the next sync. Use the override system instead:

1. Copy the skill into `.claude/overrides/skills/<name>/skill.md`.
2. Make your project-specific edits there.
3. Add a row to `.claude/overrides/MANIFEST.md` explaining what you changed and why.
4. Re-run `scripts/sync-method.sh` — the override is applied on top of the upstream sync.

The sync script saves a snapshot of the upstream version it replaced and warns on the next sync if upstream has changed the same file (so you can review whether your override is still appropriate).

See `method.md` § Sync-Safe Overrides for the full contract.
