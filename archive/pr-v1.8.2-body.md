## Summary

Quick-tier fixes from the v1.8 code review (v1.7.0..v1.8.1). Four bugs, no behavior changes for the happy path.

- **`/start-session`** — replace literal `$(...)` placeholder with the same fallback resolver `/end-session` Step 0a uses. Skill couldn't run end-to-end on a feature worktree as written.
- **`/end-session`** — Pre-flight B used a no-op self-assignment with a forward reference to Step 0a. Inlined the resolver so Pre-flight B is self-contained; Step 0a still refines from `method.config.md` afterward.
- **`/g-promote-dev` step 3** — bare `$GATE_CMD` only invoked the first command in an `&&` chain. Wrapped in `eval` so the shell parses the chain.
- **`/g-promote-dev` step 5** — removed misleading "drop the `-u`" advice. `-u` is idempotent; the actual non-fast-forward case was already documented correctly.

## Deferred to v1.9.0

Three additional findings from the same review, drafted in `temp/issue-v1.9-*.md` (not part of this PR — file as issues separately):

- `pipekit-configure-repo.sh` hardening (Rulesets PUT preserves bypass actors, auth/admin precheck, error surfacing)
- `/g-promote-dev` Linear-state ownership boundary
- `/launch --auto` refactor (stalemate definition, Revise default ordering, possible state-machine restructure)

## Test plan

- [ ] Sync into a consumer project: `./scripts/sync-method.sh fix/v1.8.2-review-bugs`
- [ ] Run `/start-session` inside a feature worktree — confirm NEXT.md refresh runs without `bad substitution`
- [ ] Run `/end-session` Pre-flight B without Step 0a having executed — confirm `$INTEGRATION` resolves
- [ ] Run `/g-promote-dev` with a multi-command `$GATE_CMD` — confirm all commands execute
- [ ] Re-run `/g-promote-dev` with upstream already set — confirm `-u` is harmless

🤖 Generated with [Claude Code](https://claude.com/claude-code)
