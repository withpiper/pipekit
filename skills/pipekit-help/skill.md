---
name: pipekit-help
description: Recommend the next pipeline step based on current project state. Use when unsure which Pipekit skill to run next. Use after finishing a step and wanting a deterministic "what now?" answer. Reads filesystem + Linear, not memory.
---

# Pipekit Help Skill

You read the project's current state, match it against the rules in `skills/pipekit-help/state-rules.md`, and produce a single-line recommendation with a one-line "why." This skill replaces the friction of "I just finished X — what comes next?" with a deterministic answer keyed off the file system + Linear, not memory.

## Triggers

- `/pipekit-help` — read state, recommend next step
- `/pipekit-help --explain` — same recommendation but with the full reasoning chain
- "what's next?" / "where am I in the pipeline?"

## When NOT to use

- Inside a long-running stage (e.g., mid-execution). The recommendation will be stale by the time you read it.
- When you already know what to do. This is a tiebreaker for ambiguous state, not a babysitter.

## Inputs (read-only)

Read each of these without writing. Stop reading as soon as a rule in `state-rules.md` matches — don't waste tool calls on later signals you don't need.

| Source | Purpose |
|--------|---------|
| `git rev-parse --abbrev-ref HEAD` | Current branch / worktree |
| `git log -5 --oneline` | Recent commits (look for Linear prefixes like `PROJ-XXX`) |
| `$STATE_DIR/pending-strategy-sync` (presence; `STATE_DIR=$(bash scripts/pipekit-state-dir.sh)`) | Post-archive hook marker — strategy sync owed |
| Linear `i{N}.`/`I{N}.P{N}.` initiative hierarchy (via `pk next` / `pk status`) | Foundation complete? Current initiative position |
| `.pk-work/<ID>-PLAN.md` (presence) | Native-backend task DAG materialized for the in-flight issue? |
| `.vbw-planning/phases/<latest>/PLAN.md` (presence, legacy-only) | Plan from an un-migrated project (legacy read-only fallback) |
| `method.config.md` | Project context for messages |
| Linear issue status (only if a single issue is clearly in scope) | Pipeline position |

If a legacy `.vbw-planning/phases/*/PLAN.md` is present (un-migrated project), resolve the *latest* initiative by mtime. Migrated projects derive initiative position live from Linear and the native `.pk-work/` plan — don't assume the `.vbw-planning/` tree exists.

## Algorithm

1. Read state signals in the order above. Stop on first decisive match.
2. Look up the matching rule in `state-rules.md`. Each rule has: matcher → recommendation → why.
3. Print exactly one recommendation in this format:
   ```
   ➜ Next: {skill or action}
     Why: {one-line reason tied to the matched signal}
   ```
4. With `--explain`, follow that with:
   ```
   Signals read:
     - {signal 1}: {observed value}
     - {signal 2}: {observed value}
   Matched rule: {rule name}
   ```
5. If no rule matches, print:
   ```
   ➜ Next: pk status
     Why: state didn't match any known rule — start from the full board view
   ```

## Rules of engagement

- **Honest about uncertainty.** If two rules could match, pick the earliest (higher-priority) and mention the alternative in `--explain`.
- **No state-mutating actions.** This skill never writes, transitions, or commits. It reads and recommends.
- **No Linear-side queries unless one issue is obviously in scope.** Inferring "which issue" from branch names is brittle. If the branch doesn't start with the project's issue prefix, skip Linear and recommend based on file-system signals only.
- **Don't recurse into the recommended skill.** Print the recommendation and stop. The user invokes the next skill themselves (fresh-chat discipline; see `method.md` § Fresh-Chat Discipline).

## Output examples

```
➜ Next: /work PROJ-247
  Why: branch matches PROJ-247 but no plan has executed yet — /work plans + executes on the native backend
```

```
➜ Next: /strategy-sync
  Why: pending-strategy-sync marker present (last archive triggered it)
```

```
➜ Next: pk ship
  Why: /verify passed and current branch matches PROJ-247 — ready to push + open PR
```

## Customization

`state-rules.md` is the rule table. To add a project-specific rule (e.g., a custom initiative marker), override the file via `.claude/overrides/skills/pipekit-help/state-rules.md` — see `method.md` § Sync-Safe Overrides.
