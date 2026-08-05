#!/usr/bin/env bash
# Round-2 head-to-head harness for POC-48 (1 native arm + 1 vbwfull arm).
# Safe + reversible: creates experiment branches/worktrees in SiteLine. No push, no Linear, no DB.
# Winner ships for real afterward (POC-48 is Approved/High). Teardown: teardown-headtohead.sh
set -euo pipefail

SL="$HOME/Projects/SiteLine"
PK="$HOME/Projects/pipekit"
BASE_SHA="4c65c828"                        # SiteLine origin/main @ experiment start (incl. merged POC-57)
PK_BRANCH="feat/native-workflow-executor"  # where improved native-best lives (HEAD 0933cfa)
SKILL="skills/work/skill.md"

cd "$SL"

# 1. Experiment base: main@BASE_SHA + the IMPROVED native-best skill, as ONE setup commit.
#    Both arms branch from here. vbwfull ignores the skill (uses /vbw:vibe) but shares the
#    identical diff baseline so the judge/parity comparison is apples-to-apples.
if ! git rev-parse --verify exp/POC-48-base >/dev/null 2>&1; then
  git worktree add -b exp/POC-48-base .worktrees/POC-48-base "$BASE_SHA"
  git -C "$PK" show "$PK_BRANCH:$SKILL" > ".worktrees/POC-48-base/.claude/skills/work/skill.md"
  ( cd .worktrees/POC-48-base
    git add .claude/skills/work/skill.md
    git commit -m "chore(exp): install improved native-best executor for POC-48 head-to-head

Source: pipekit $PK_BRANCH (commit 0933cfa — test-first + sequential-default fixes).
Experiment base only — never merged. Both arms branch from here." )
fi

# 2. Arm worktrees off the experiment base.
for arm in native-1 vbwfull-1; do
  wt=".worktrees/POC-48-$arm"
  br="exp/POC-48-$arm"
  if ! git rev-parse --verify "$br" >/dev/null 2>&1; then
    git worktree add -b "$br" "$wt" exp/POC-48-base
  fi
done

echo
echo "=== POC-48 head-to-head harness ready ==="
git worktree list | grep POC-48
echo
echo "base commit (arms diff against this):"
git rev-parse --short exp/POC-48-base
echo
echo "main migration tail (new POC-48 migrations must be strictly later):"
git ls-tree -r --name-only "$BASE_SHA" -- supabase/migrations/ | sort | tail -1
