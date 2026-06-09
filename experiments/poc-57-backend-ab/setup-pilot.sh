#!/usr/bin/env bash
# Pilot harness for the POC-57 native-vs-VBW A/B (1 VBW + 1 native arm).
# Safe + reversible: creates experiment branches/worktrees in SiteLine. No push, no Linear, no DB.
# Teardown: scripts/teardown-pilot.sh
set -euo pipefail

SL="$HOME/Projects/SiteLine"
PK="$HOME/Projects/pipekit"
BASE_SHA="2fb49a14"                       # SiteLine origin/main @ experiment start (pinned; re-based 2026-06-07)
PK_BRANCH="feat/native-workflow-executor" # where native-best lives
SKILL="skills/work/skill.md"

cd "$SL"

# 1. Experiment base: main@BASE_SHA + the rebuilt native-best skill, as ONE setup commit.
#    Both arms branch from here; the judge diffs each arm against exp/POC-57-base, so this
#    skill swap never pollutes scoring.
if ! git rev-parse --verify exp/POC-57-base >/dev/null 2>&1; then
  git worktree add -b exp/POC-57-base .worktrees/POC-57-base "$BASE_SHA"
  git -C "$PK" show "$PK_BRANCH:$SKILL" > ".worktrees/POC-57-base/.claude/skills/work/skill.md"
  ( cd .worktrees/POC-57-base
    git add .claude/skills/work/skill.md
    git commit -m "chore(exp): install native-best executor for POC-57 A/B

Source: pipekit $PK_BRANCH (commit 3954890). Experiment base only — never merged.
Judge diffs each arm against this commit so the skill swap is invisible to scoring." )
fi

# 2. Pilot arm worktrees off the experiment base.
for arm in vbw-1 native-1; do
  wt=".worktrees/POC-57-$arm"
  br="exp/POC-57-$arm"
  if ! git rev-parse --verify "$br" >/dev/null 2>&1; then
    git worktree add -b "$br" "$wt" exp/POC-57-base
  fi
done

echo
echo "=== pilot harness ready ==="
git worktree list | grep POC-57
echo
echo "base commit (arms diff against this):"
git rev-parse --short exp/POC-57-base
