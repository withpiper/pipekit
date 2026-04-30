# VBW Removal Spike

This branch tests whether VBW is still pulling its weight in the Pipekit pipeline now that Claude Code has native Plan Mode, typed subagents, worktree isolation as a parameter, and durable TaskCreate state.

If the spike wins, `/launch` gets rewritten to run without VBW, the `.vbw-planning/` ownership boundary goes away, and `/startup` drops the VBW plugin install step.

Branch: `spike/vbw-removal`
Do not merge until at least 3 real Linear issues validate the native path.

## What's in this branch

1. `skills/launch-native/skill.md` — a VBW-free variant of `/launch`. Same gates, same Linear transitions, same complexity routing. Plans go to `plans/{phase-slug}/` instead of `.vbw-planning/`. Planning runs on the native `Plan` subagent type with Opus. Execution and QA run on `general-purpose` with Sonnet. The `--deep` flag escalates execution to Opus.
2. `skills/launch/skill.md` on this branch is unchanged from `main`. That's intentional. You're comparing two live paths, not a before and after.

## How to run the spike

You need two worktrees so both skills can run against the same Linear issue without stepping on each other.

### One-time setup

```bash
git worktree add ../pipekit-main main
git worktree add ../pipekit-spike spike/vbw-removal
```

You now have two working copies of the repo: one on `main` (runs `/launch`), one on `spike/vbw-removal` (runs `/launch-native`).

### Per-issue protocol

1. Pick one Linear issue in Specced or Approved status. Medium complexity is ideal, High gives stronger signal.
2. Open Claude Code in `../pipekit-main`. Run `/launch PROJ-XXX`. Take it all the way through Building → UAT.
3. Open Claude Code in `../pipekit-spike`. Run `/launch-native PROJ-XXX` on a fresh copy of the same issue. Take it through the same states.
4. Record what you saw in `temp/spike-notes.md` (it's gitignored, so it stays local). Template is already there.

Run the spike on at least 3 issues before deciding. One issue is noise. Three is a signal.

### What to compare

1. Plan quality. Read both plans side by side. Which decomposes better?
2. Execution. Same tests pass? Same diff shape?
3. Friction. How many times did you think "I miss VBW" or "this is simpler"?
4. Linear visibility. Are the comments from `/launch-native` as useful as the ones from `/launch`?
5. Cost. Rough token spend parity?
6. Recovery. When something failed mid-pipeline, which path was easier to debug?

## Decision matrix

After 3 issues, pick one:

1. **Native wins.** Migrate `/launch` to use the native path, delete `/launch-native`, remove VBW from `/startup` install steps, update `method.md` ownership section, write a migration note for existing `.vbw-planning/` artifacts.
2. **VBW wins.** Delete `/launch-native`. Document in `method.md` what VBW does that the native path couldn't replicate. That's your answer for why it stays.
3. **Mixed.** Keep both. Document the cases where each is preferred (probably: VBW for high-complexity multi-task work, native for everything else).

## Why do this now

Claude Code shipped Plan Mode, typed `Agent` subagent_type, `isolation: "worktree"` as a parameter, and TaskCreate/TaskUpdate durable state since VBW was first built. Those are the exact primitives VBW was wrapping. If the wrapping is still adding value, great. If not, you're paying a dependency cost and an ownership-boundary cost for capability you already have.

Second reason: VBW has 1-2 active maintainers. That's a real bus-factor problem for a load-bearing piece of Pipekit. Evaluating the alternative now, while you still understand both paths, is cheaper than being forced to evaluate it 6 months from now when VBW has stalled and you're debugging drift.

## Known gaps in this spike

1. `/launch-native` uses `general-purpose` subagents. Some of VBW's value might live in its custom agent prompts. If the first spike round is inconclusive, a second variant could copy VBW's agent prompt text into the native `Agent` calls and re-test.
2. Low-complexity issues still route to `/linear-todo-runner`. The runner doesn't use VBW so there's no comparison to make there.
3. `.vbw-planning/ROADMAP.md` is read by other skills (`/roadmap-review`, `/phase-plan`). If native wins, roadmap location either stays or moves to `ROADMAP.md` at the repo root. Decide after the spike.

## If you're just reading this

The spike is meant to produce a clean yes/no signal in under a week of active use. If you find yourself writing more than a few paragraphs defending VBW's value after the comparison, that's a signal the value isn't obvious and probably isn't there.
