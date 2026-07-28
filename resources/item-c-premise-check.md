# Item C Premise Check — Subagent Rule Inheritance (Empirical)

**Probed:** 2026-07-28, pipekit repo, Claude Code harness (session model Fable 5). Companion to `resources/rightsizing-phase2-batch2.md` § Item C.

## Verdict

**The delivery premise is REFUTED. The cost premise is CONFIRMED and worse than assumed.**

Item C's thesis was: always-on `.claude/rules/pipekit-*` files are billed to the main (frontier) session that least needs them, while spawned subagents — the tier the guard-rail prose targets — receive them only if the spawn prompt carries them. The second half is false on this harness.

## Method

Three parallel probe agents, instructed to call **zero tools** and report only what was already in their context at spawn: which file contents appear, a 10-marker verbatim check (one marker per rule file plus global CLAUDE.md, MEMORY.md, git status), system-reminder inventory, tool list, model id.

| Probe | Agent type | Model | Result |
|---|---|---|---|
| 1 | `general-purpose` | inherited (fable) | full claudeMd injection present |
| 2 | `scout` (restricted: Bash/Glob/Grep/Read) | haiku (per agent def) | full claudeMd injection present |
| 3 | `general-purpose` | pinned `haiku` | full claudeMd injection present |

## Findings

Every probe, regardless of agent type or model tier, received at spawn:

- **User-global `~/.claude/CLAUDE.md`** — full contents.
- **Project `CLAUDE.md`** — full contents.
- **Every `.claude/rules/*` file** — full contents (all 9/10 markers hit; the one miss was `pipekit-migrations.md`, which is *not in this repo's* `.claude/rules/` — i.e., injection exactly mirrors the on-disk rules dir).
- **Auto-memory `MEMORY.md`** — full index.
- **Git status block** (branch, recent commits) and env block (cwd, platform).
- (general-purpose only) the **skills roster** and **deferred-tools listing**.

Implications:

1. **Subagents do not need spawn prompts to carry rule content.** A haiku grounding agent already reads the same ~25k tokens of rules a frontier main session does.
2. **The always-on block is multiplied, not just resident.** SiteLine's /doctor measured ~28k always-resident tokens for the *main* session. That same block is injected into **every spawned agent** and re-billed as input on every one of *its* turns. A `/work` run with N task agents × M turns each pays it N×M additional times. Rule tokens are the most expensive tokens in the system.
3. **Embedding per-role guard-rail blocks at spawn sites would be pure duplication** — the agent gets the inlined copy *plus* the inherited copy, paying twice for content it already had.

## UNVERIFIED residual

- **The Workflow-primitive path** (native executor inside `/work`): not probed — running a Workflow requires explicit user opt-in, and the handoff authorized an Agent-tool probe. Circumstantial evidence says it behaves identically (Workflow's `agent()` resolves agent types "from the same registry as the Agent tool"). **Need:** a 1-agent probe workflow (~30s) on user say-so. This does not change the design verdict either way: if Workflow agents also inherit, the trim below helps them too; if they inherit nothing, the fix would be `/work`-task-prompt-local, not the six-skill guard-rail-block design.

## What survives from the original design

- **Step 1 (audit)** — survives, reframed. The question is no longer "which audience" (delivery is uniform; there is no subagent-only channel). It is: *which content earns always-on residency for every reader, main session and all subagents alike* — versus demand-load to an SOP, versus compress-to-anchor.
- **Step 4 (permission-denial precedent)** — stands **as-is**, but must not be generalized. It works precisely because the denial protocol is *task-specific instruction that lives in no always-on rule* — inlining it duplicates nothing. That is the boundary: spawn prompts carry task-specific behavior; rules carry always-on constraints; nothing lives in both.
- **Steps 2–3 (guard-rail blocks in Skills_SOP; six skills embed tier-matched blocks)** — **dead.** Built on the refuted premise; implementing them would raise cost.

## Redirected Item C — rules compression under multiplied-residency economics

Same doctrinal anchor (always-on = repo purpose + incident-anchored gotchas; judgment form over rigid rules), stronger economics. Move, don't delete — `sop/` syncs to consumers, so demand-loaded content stays reachable by a consumer main session on any model (this satisfies the handoff's "Risk to watch" directly). Canonical sources: `templates/rules/*` (52.2kB total incl. README).

| Rule (size) | Proposed action | Est. saving |
|---|---|---|
| `pipekit-cmux.md` (10.7kB) | Move § Orchestrating other Claude sessions (4 sub-rules + their anti-pattern rows) to a new `sop/Cmux_Orchestration_SOP.md`; keep a 2–3 line trigger. Orchestration is a session *mode*, not an every-turn constraint. Non-cmux projects already have `Skip rules`. | ~4.5kB |
| `pipekit-migrations.md` (13.2kB) | Move § Silent-Failure Patterns narratives to `sop/Database_SOP.md` (exists), keeping the three one-line invariants + audit greps in the rule. Compress the WIT-514 MCP-stamp incident to anchor form (rule keeps the prohibition + 2-line anchor; forensic walkthrough → SOP). Frozen-file core untouched. | ~4kB |
| `pipekit-tooling.md` (10.7kB) | Dedup the cmux-rpc case study (full version already lives in `pipekit-cmux.md`; keep the 2-line generalization + pointer). Compress the WIT-461 enumerate-surface case study to anchor form; the list-command table stays — it's the enforceable core. | ~1.7kB |
| `pipekit-discipline.md` (8.7kB) | Already rightsized in batch 1. Optional: demand-load the Expanded Plan Gate format block (trigger + inline format stay). | ~0.6kB |
| `pipekit-security.md` (5.1kB) | Keep. Smallest file, near-all enforceable constraints. (Borderline: § Secrets Managers and Worktrees is pattern-reference prose — revisit only if a secrets SOP materializes.) | 0 |

**Total: ~10–11kB (~20–25%) off the always-on block, multiplied across the main session and every spawned agent.** No skill spawn-site changes. No new delivery mechanism.

## Not in scope of the redirect

- The skills roster and deferred-tools listing also ride into every subagent — real cost, but harness-owned, not Pipekit-ownable (batch 1 already compressed Pipekit's description share).
- `bin/pk` sentinels, hooks, CI — deterministic gates, untouched, per the enforcement thesis.
