# Skills SOP

> For the full development pipeline, see [method.md](../method.md).

**v4.31.0** — Last updated: 2026-08-07  *(**v4.31.0 — `/security-review` → `/repo-security-review`.** Renamed to stop colliding with Claude Code's built-in `/security-review` (diff-scoped, pending changes) in every consumer's skill list, and genericized: SiteLine's audit checklist was baked into the canonical skill, so audit areas + primitives now live in a project areas file (`resources/repo-security-areas.md`, scaffolded from `templates/repo-security-areas.template.md`). Portable-skills table row updated. Consumers: the old `security-review/` directory is not auto-deleted — the sync flags it as undeclared with the removal command. Carries v4.30.0 — the legacy planning layer is gone (`bin/pk`'s phase-file/ID-map fallback, the `Backend` key and its whole chain, `/spec-preflight`'s dead `phase-detect` probe, `/review-plan`'s phase-slug path). Linear is the only initiative surface.)*

---

## How Skills Work

This method uses three layers to enforce development conventions:

| Layer | Purpose | Who it serves |
|---|---|---|
| **CLAUDE.md** | Documents conventions so the executor follows them automatically | The native-on-Workflow executor during plan execution |
| **CI / Hooks** | Hard enforcement — blocks merges that violate conventions | Everyone (agents and humans) |
| **Skills** | Interactive shortcuts for hands-on sessions | You, when working with Claude directly |

Skills are convenience wrappers. They automate the same conventions documented in CLAUDE.md. The executor doesn't call skills — it reads CLAUDE.md and writes code directly.

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
| `/linear-hygiene` | Fast placement janitor — homes orphaned / untriaged / unprioritized issues across all open states (placement, not disposition). Propose-then-apply; `--check` is read-only. | Anytime (board maintenance) |
| `/light-spec` | Structured spec generation with auto-cycled agent review (Phase 6 invokes `pk spec-cycle` + `/light-spec-revise` internally, max 3 passes). v2.7.0+: publishes to the configured `Spec ready state` (not a hardcoded `Specced`), so two-state boards (e.g. `Needs Spec → Approved`) work. | Stage 1: Spec |
| `/light-spec-revise` | Apply Spec Review Agent feedback surgically; detect stalemate loops. Usually invoked by `/light-spec` Phase 6, can also run standalone. | Stage 1: Spec |
| `pk spec-cycle <ID>` | Trigger Spec Review Agent v5, poll Linear for verdict, transition to Approved on Pass. Bash-side helper used by `/light-spec`'s cycle — keeps polling out of Claude's context. | Stage 1: Spec |
| `/spec-preflight` | Empirical pre-flight checks on a specced Linear issue (file paths, line refs, phase-detect baseline, Linear status). Read-only. | Stage 1 → Stage 2 gate |
| `pk next` | Initiative-aware: groups Linear results by status (In Progress / Approved / Needs Spec) | Stage 2: Plan + Build |
| `pk branch <ID>` | Worktree + branch + Linear → In Progress (idempotent) | Stage 2: Plan + Build |
| `/work <ID>` | Plan + execute on native-on-Workflow (the sole executor as of v4.0.0). | Stage 2: Plan + Build |
| `/review-plan` | Spawns `plan-reviewer` agent against the inline `PLAN.md` (optional gate). | Stage 2: Plan + Build |
| `/verify` (or `pk verify`) | Pre-deploy gate (types + lint + test); QA subagent if `Require QA review: true`. v2.7.0+: migration-touching diffs get a self-review subagent (M1–M8 rubric) carrying a Hold/Approve verdict, not a raw `git show`. | Stage 3: Verify + Ship |
| `pk ship [--review] [--ready]` | Push, open PR as **Draft** (v2.6.0+; `--ready` opts to Ready), Linear → UAT. `--review` flags review-in-flight + prints reviewer invocation. | Stage 3: Verify + Ship |
| `pk ready [<ID>]` | Flip Draft PR to Ready (v2.6.0+). Fires `ready_for_review` → outside reviewers (Semgrep + claude-review per `templates/ci/`) run. No Linear state change. | Stage 3: Verify + Ship |
| `/pr-fix` | Pluggable-engine PR review (`--engine=native` pr-review-toolkit default · `--engine=builtin` dependency-free fallback, fail-loud) + historical finders (git-history blame-regression + prior-PR-comments reapplication, v2.7.0, both engines); two-axis severity×confidence triage with INVESTIGATE quadrant; fixed / rejected / deferred + Linear summary. `--from-review` ingests GHA comments; `--runs=N` raises confidence on recurrence; `--second-opinion=gemini` adds a parallel Gemini Flash read. | Stage 3: Verify + Ship |
| `/pr-security-review` | Security-focused antagonistic review for migrations / RLS / SECURITY DEFINER / auth | Stage 3: Verify + Ship |
| `/security-gate [<ID>]` | Feature-scoped security gate (v4.4.0, gap #3). Runs at the Building → UAT seam — after `/verify`, before `pk ship`. Classifies the feature diff into six sensitive categories (auth/payments/user-input/external-APIs/file-storage/PII); none matched → instant PASS, a match → category checklist vs the diff → PASS/FAIL report + Linear comment. **Advisory** — doesn't block `pk ship`. Distinct from `/repo-security-review` (repo-wide audit) and `/pr-security-review` (PR-scoped). Portable **framework**; project category signals in `resources/security-categories.md` (scaffolded from `templates/security-categories.template.md`). No-op without a categories file. | Stage 3: Verify + Ship |
| `/pk-bug` | Bug pipeline: intake → reproduce → regression-test-first → fix → ship → postmortem. Wraps `/work` + `pk ship` with discipline gates. | Anytime (parallel pipeline) |
| `/pk-express` | Idea→Draft-PR autopilot for **simple** WITs: chains `/brainstorm` → `/light-spec` (auto-cycle to Approved) → `pk branch` → `/work` (auto verify+ship), advancing on success and stopping only at attention gates (not-Now, tier:heavy, spec stalemate, verify flags, Draft PR). Quick/Standard tier only. | Anytime (express lane) |
| `pk done <ID> [--merge]` | Post-merge cleanup: worktree+branch, commits to Linear, Linear UAT → `In <FirstEnv>` (or → Done for 1-tier). v2.6.0+: also auto-pulls integration. `--merge` lets pk run `gh pr merge` first. | Stage 4: Release |
| `/prod-ready [<ID>]` | Production-readiness gate (v4.3.0). Run **once** before the final `pk promote` (the last `Ship environments` entry; the merge to `main` on 1-tier). Verifies operational preconditions `/verify` doesn't — monitoring wired, no secrets in the built bundle, rate limits on new public routes, backups active, flag on risky paths, dashboard chart. PASS/FAIL report + Linear comment. **Advisory** — doesn't block `pk promote`. Portable **framework**; concrete checks live in a per-project checks file (`resources/prod-readiness-checks.md`, scaffolded from `templates/prod-readiness-checks.template.md`). No-op on projects without a checks file. | Stage 4: Release |
| `pk promote <env>` | Phase 1 (v2.6.0+): opens promote PR along `Ship environments`. WITs stay in source state. 2-tier: `pk promote` with no arg picks the only hop. | Stage 4: Release |
| `pk promote <env> --finish` | Phase 2 (v2.6.0+): after the promote PR merges, transitions WITs → `In <Env>` (intermediate, e.g. `In Beta`) or → Done (final). | Stage 4: Release |
| `/strategy-sync` | Update Strategy docs after shipping | Stage 5: Doc Loop |
| `/pk-exit` | Narrative session log to `Logs/Sessions/<date>_<HHMM>.md` | Per session |
| `pk status` | Full unscoped Linear board view | Anytime |
| `pk doctor` | Diagnostic: config validity, Linear API access, worktree dir, stale artifacts | Anytime |
| `pk init` | One-time per consuming project: seeds `notepad.md`, `Logs/Sessions/`, checks config | One-time setup |
| `/linear` | Linear issue workflow helper | Anytime |
| `/sync-linear` | Reconcile strategy-doc drift against the Linear initiative hierarchy | Anytime |
| `/pipekit-help` | Read project state, recommend next pipeline step | Anytime |
| `/spec-validator` | Validate spec completeness | Stage 1: Spec |
| `/repo-security-review` | Periodic **whole-repo** security audit (v4.31.0, renamed from `/security-review` — collided with Claude Code's built-in). Parallel area agents → adversarial verification → evidence-classified score report. Portable **framework**; project audit areas in `resources/repo-security-areas.md` (scaffolded from `templates/repo-security-areas.template.md`). No-op without an areas file. Distinct from `/pr-security-review` (PR-scoped) and `/security-gate` (feature-scoped). | Anytime |
| `/financial-review` | Periodic financial-accuracy review for finance/calculation-heavy projects — cross-layer parity audit (DB view ↔ calc ↔ UI), severity-ranked report, recurring-WIT lifecycle. Portable **framework**; concrete checks live in a per-project checks file (`resources/financial-review-checks.md`, scaffolded from `templates/financial-review-checks.template.md`). No-op on projects without a checks file. | Anytime (domain: finance) |
| `/skill-index` | Sync skill index after changes | Anytime |
| `/lane-map` | Renders the current initiative's board as a private web artifact — frontier of run-order heads, one row per lane, optional collision register. **Scaffold-once**: seeded into `.claude/skills/lane-map/` on first sync if absent, never touched again — curation (groupings, collision notes, artifact URL) is project-owned from there. Conventions in `sop/Lane_Map_SOP.md`. | Anytime (board visualization) |
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

Every skill lives in `.claude/skills/{name}/SKILL.md` with frontmatter:

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

Skills that gate ship/merge decisions (`/verify`, `/pr-fix`, `/pr-security-review`, `/work`, `/pk-bug`) include three extra body sections (all five carry them as of v4.16.0):

- **`## When NOT to use`** — explicit anti-criteria, each a *redirect* to the right skill ("security audit → `/repo-security-review`"). This is **not** the same as `## What this skill does NOT do`: that section is a *scope fence* (state the skill won't touch — "no Linear writes, no PR creation"), and having one does not satisfy this convention. A skill can need both; `/verify` and `/work` carry both.
- **`## Common Rationalizations`** — three to five things the *user* might say to skip or shortcut the skill, each paired with its rebuttal, as a two-column table ("You're about to say… | The rebuttal"). Example from `/verify`: "'It's a small change' → the gate is the gate." Distinct from `/work`'s `Anti-rationalization guard`, which guards against *Claude* defending broken visible state — that's a self-check, not a skip-excuse table.
- **Never-do guardrails** — hard "don't" lines. The heading varies by skill (`## Drifts to Avoid`, `## Failure modes to avoid`, or the hard bullets of `## What this skill does NOT do`) — the heading is not the requirement; this rule is: **every line must be a mistake that was actually made and corrected, with its anchor** (issue ID, date, or CHANGELOG version) when one exists — e.g. `/work`'s "No `pk done`, ever" (WIT-451, 2026-05-13), `/linear-hygiene`'s "never infer a `Roadmap: *` label from a re-homed `projectId`" (POC-382, 2026-07-14). A Never-do without a real incident behind it is a guess dressed as a rule — leave it out until the mistake happens. This is also why the sections stay short: they grow one corrected mistake at a time.

**Output-producing skills** (a report, spec, verdict, or changelog a human reads — `/light-spec`, `/verify`, the gate reports, `/release-changelog`): where the output shape is easy to get subtly wrong, show a **good/weak example pair** — one output that's right and one that looks right but isn't, with the difference named. One pair, not a gallery.

These sections are *not* required for low-stakes skills (`/sync-linear`, `/skill-index`) — they'd be noise. Apply only where misuse has a meaningful cost.

### Key Conventions

1. **Read `method.config.md`** for project-specific values (Linear team, issue prefix, state IDs)
2. **Read `CLAUDE.md`** for project coding conventions
3. **Use Linear MCP tools** for issue management (`mcp__linear-server__*`)
4. **Dispatch heavy planning + execution through `/work`** (which plans inline and executes on the native-on-Workflow executor, the sole executor as of v4.0.0). Don't spawn ad-hoc execution agents directly from skills — that bypasses Pipekit's execution and visibility layer. Skills that genuinely need a planning subagent for narrow internal work (e.g., spec-review agents in `/light-spec`) may still spawn dedicated subagents; the rule is about replacing the daily-loop work pipeline, not all `Agent()` calls.

### "What's next?" in v2 — `pk next` reads Linear

v2 retired the v1 `NEXT.md` mirror. The single source of truth for "what should I do next?" is **Linear**, accessed via:

- **`pk next`** — initiative-aware: derives the current initiative live from the Linear-native surface (lowest non-`Completed` `i{N}.` initiative → its lowest open `P{N}.` project, by numeric name prefix; legacy `PHASES.md`/`linear-map.json` fall back), then groups that initiative's Linear issues by status with per-group hints. Falls back to global "next Approved" when no initiative context. Best when you know you want to pick up the next issue.
- **`pk status`** — full unscoped board view across all initiatives. Best when you want the wider picture.
- **`/pipekit-help`** — context-aware skill recommendation based on full project state (Linear, `PHASES.md`, recent transitions, pipeline-state files). Best when you're not sure *which step* in the pipeline to run next.

Skills should **not** write a `NEXT.md` file. Skills MAY still print `➜ Next:` inline at the end of their output as a courtesy hint to the current user, but the persistence layer is Linear, not a sidecar markdown file.

A project may keep a **hand-curated** roadmap file (`NEXT.md` / `ROADMAP.md` at the project root — first-class optional artifact as of v3.1.0). The skill-facing rule is unchanged in both directions: never write it, and never read it as operational state. It's human narrative; Linear is the truth.

`pk init` (v2.1.1+) seeds a gitignored `notepad.md` at the project root for personal free-form notes (replaces NEXT.md as a human scratch space). It is never committed and never auto-written by skills.

#### Pipekit machine-local state directory

Pipekit's ephemeral, per-machine state (post-archive marker, per-issue pipeline-state records) lives **outside** the repo at:

```
${XDG_CACHE_HOME:-$HOME/.cache}/pipekit/<repo-basename>/
├── pending-strategy-sync          # post-archive marker (see /strategy-sync)
└── pipeline-state/
    └── <issue-id>.json            # per-skill transition state
```

**Why out-of-repo:** earlier Pipekit placed these files at `<repo>/.pipekit/`, which sits inside the repo and got blocked by a file-guard hook during active-plan scope. Moving the directory outside the repo lets that file-guard ignore it entirely, so writes succeed unconditionally — and the out-of-repo location keeps the state independent of any in-repo planning artifacts.

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
- `issue_id` — Linear ID (or phase slug for phase-scoped flows)
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

### Cite `method.config.md` for values, never for prose

<important>
A skill may point at `method.config.md` for a **project-specific value** it must read. It must never point there for **explanation** a reader is expected to go and study.
</important>

`method.config.md` is **project-owned and never synced** — `sync-method.sh` deliberately does not touch it. So a conceptual section added to `method.config.template.md` reaches *new* projects (which copy the template) and **no existing consumer, ever**. A skill citing that section is a live pointer into a file the reader's repo does not contain, and the failure is silent: the session goes looking, finds nothing, and proceeds on whatever it already believed.

The tell is what the pointer promises. "Read `method.config.md § X` for your team ID / label names / lane size" is a value lookup — correct. "Both shapes are documented in `method.config.md § X`" is documentation — wrong, because the consumer's file has no such section.

**Explanatory content belongs in a synced file** — `sop/*.md`, `method.md`, or the skill itself. Cite the config only for the value that says *which* case this project is in:

> ✅ Both shapes are documented in `sop/Linear_SOP.md § Board shapes`; which one this project uses is recorded in its `method.config.md` (a filled-in `§ Area Labels` means lanes).
> ❌ Both shapes are documented in `method.config.md § Initiative Surface → Board shapes`.

*(Anchor: v4.28.0 shipped exactly this defect — `/roadmap-create` pointed at a `§ Board shapes` subsection that existed only in the template, so it was dangling on both consumers the day it shipped. Caught in review of the sync PR, fixed in v4.28.1, and now guarded: `tests/pk-smoke.sh` fails when a skill cites a `method.config.md` section that carries no `| **Key** |` row.)*

### Pinning models on subagents — the Model Policy roles

Any skill that invokes `Agent()` should **explicitly pass `model:`** rather than relying on default inheritance. A skill that runs inside a frontier-model session will otherwise silently run execution agents on that model too — expensive and usually unnecessary.

**Skills reference roles, not model names.** The project's `method.config.md § Model Policy` maps each role to a model + effort tier; when the section (or a row) is absent, the defaults below apply. This is the same rule that keeps Linear IDs and paths out of portable skills — model names are hardcoded values that vary over *time* instead of per-project, and a docs-wide sweep at every model generation doesn't scale. Re-point one row in the config instead.

| Role | Used by | Default model | Default effort |
|------|---------|---------------|----------------|
| Grounding / lookup | read-only fact sweeps: Explore/scout-type subagents | `haiku` | `low` |
| Execution | native Workflow task agents, batch runners, mechanical file-shaping subagents, gate classifiers | `sonnet` | `medium` |
| Verification | QA review subagent | `sonnet` | `high` |
| Plan review / adversarial | `plan-reviewer`, antagonistic reviewer, spec reviewers | `opus` | `xhigh` |

**What earns a tier is the cost of a silent miss, not task difficulty.** Verification, adversarial review, and sign-off gates run at the top tiers because their failure mode is invisible — a miss ships. Execution runs mid-tier even when the task is hard, because verify, tests, and review sit behind it and fail loudly. Grounding lookups run cheapest — their errors surface immediately on use. When assigning a role to a new spawn site (or arguing a skill deserves an upgrade), derive from this rubric, not from felt difficulty.

When a skill spawns a subagent, spell out the role and its default inline — e.g. *"execution tier per `method.config.md § Model Policy`, default `sonnet`"* — so the skill still works in a project whose config predates the section.

Add an escape hatch (e.g., a `--deep` flag) when the skill routes to an execution agent that sometimes needs heavier reasoning — race conditions, silent failures, cross-layer bugs. See `skills/work/SKILL.md` for a worked example (`/work --deep` adds spec-validator + plan-review + security-review subagents). A structural sibling worth knowing about (not yet adopted): escalate-on-failure — start a task on the cheapest plausible role and re-run one tier up after repeated verify failures.

---

## Syncing Portable Skills

Portable skills are maintained in the method repo and synced into projects via `scripts/sync-method.sh`. After syncing, the skills appear in `.claude/skills/` alongside project-specific skills.

To update: `./scripts/sync-method.sh [tag]`

### Saved workflows (`workflows/` → `.claude/workflows/`)

A skill that needs deterministic control flow over many subagents — loops, fan-out, stop-on-first-failure — keeps that loop in a Claude Code **saved workflow** rather than in prose: a `workflows/<name>.js` script (an `export const meta` literal first, then a plain-JS body using `agent()` / `parallel()` / `pipeline()`) that the skill invokes by name with the `Workflow` tool, passing its input as structured `args`. The sync copies `workflows/*.js` per-file into the consumer's `.claude/workflows/`, which is a tracked path there, so the script is present in every `pk` worktree; project-local workflows persist across syncs, like agents. Pipekit's own mirror is refreshed by `scripts/dogfood-sync.sh`. `/work`'s `pk-execute` is the worked example. Before editing a script, load the `workflow-authoring` bundled skill — scripts have no filesystem access, `Date.now()` throws, and `meta` must stay a pure literal or the `/<name>` command disappears.

### Declaring project-specific skills (`pipekit/.local-skills`)

The sync flags any `.claude/skills/` entry that doesn't exist upstream — it can't otherwise tell a project's own skill from a portable skill that upstream removed or renamed. Declare your project-specific skills in a committed manifest, one name per line (`#` comments allowed):

```
# pipekit/.local-skills — skills that are ours by design
g-deploy
reset-user
```

Declared skills are listed under "Project-local" in the sync changelog; undeclared ones are flagged "Not in upstream (undeclared)" with the exact command to declare them. If a flagged skill *isn't* yours, upstream removed or renamed it — check the method repo's CHANGELOG and `archive/` before deleting.

### Scaffold-once skills (`.scaffold-once-skills`, method-repo-side)

A few portable skills carry conventions that must propagate on every sync, paired with curation that is genuinely per-project and can't be derived from upstream — a rendered artifact that reads project-specific groupings, chip notes, or brand tokens, for example. Fully portable would overwrite that curation on the next sync; fully local (`pipekit/.local-skills`) would mean no upstream fix ever reaches the project. Scaffold-once is the third mode: seeded from the upstream template **once**, on the first sync where `.claude/skills/<name>/` is absent, then never touched again.

The method repo declares which skills get this treatment in its own `.scaffold-once-skills` (one name per line, same format as `.local-skills`) — this is method-repo state, not project state; a consuming project has no manifest of its own to edit. On first scaffold, the sync auto-declares the skill in the project's own `pipekit/.local-skills`, so the "possibly upstream-removed" check above treats it as project-owned from that point on.

**The pattern requires a split file**, so a fix still reaches every project even though the instance file doesn't resync: the portable half (conventions, patterns, gotchas) lives in a normally-synced SOP; the scaffolded skill cites that SOP instead of restating it. `/lane-map` is the worked example — conventions in `sop/Lane_Map_SOP.md`, curation in the scaffolded `.claude/skills/lane-map/SKILL.md`.

Use this sparingly. Most skills should stay normally portable — reach for scaffold-once only when a skill's value is genuinely per-project curation that a normal resync would destroy.

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

Some files in a Pipekit project are **canonical** — they encode conventions that the executor (and any agent) should *read* but not *mutate*. The default protected set lives under `.claude/rules/*` (the portable `pipekit-discipline.md`, `pipekit-tooling.md`, `pipekit-security.md` hub-and-spoke template). Projects can opt additional paths into protection — `Strategy/`, `method.config.md`, and `PHASES.md` are common candidates.

Protection is enforced by **hook**, not by skill prose. A `PreToolUse` hook on `Edit` and `Write` blocks the call when the target path matches the protected set; the agent receives `EditPermissionDenied` (or `HookFeedbackBlocked`, depending on the hook variant). This is intentional: hooks win over `bypassPermissions` mode because hook-level guards are the project's last line of defense, and orchestrator-spawned agents are not exempt from project policy.

The corresponding skill-side discipline: every skill that spawns an agent expected to call `Edit`/`Write` includes a **permission-denial-stop instruction** in the agent's task description (see `skills/06-linear-todo-runner/SKILL.md` § Permission-denial protocol and the parallel block in `skills/work/SKILL.md`). Without that instruction, agents tend to retry on denial, exhaust attempts, and report partial progress — the user only finds out the work was blocked after burning turns. With it, the agent stops on first denial and surfaces the denied path, intended change, and rationale, so the user can either grant the exception (revise hook), redirect the work, or abort the issue.

When you add a new skill that spawns file-editing agents, copy the permission-denial block verbatim. When you protect a new path with a hook, document the protection in `method.config.md` so future readers know which paths are agent-write-locked and why.

## Customizing Synced Skills (Overrides)

If a project needs to change behavior of a synced skill, **do not edit the file in `.claude/skills/<name>/` directly** — it will be overwritten on the next sync. Use the override system instead:

1. Copy the skill into `.claude/overrides/skills/<name>/SKILL.md`. Any other file in the skill directory can be overridden the same way — `skill.json`, a data file — by putting it at the matching path.
2. Make your project-specific edits there.
3. Add a row to `.claude/overrides/MANIFEST.md` explaining what you changed and why.
4. Re-run `scripts/sync-method.sh` — the override is applied on top of the upstream sync.

The sync script saves a snapshot of the upstream version it replaced and warns on the next sync if upstream has changed the same file (so you can review whether your override is still appropriate).

See `method.md` § Sync-Safe Overrides for the full contract.
