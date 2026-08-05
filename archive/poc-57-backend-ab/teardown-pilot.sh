#!/usr/bin/env bash
# Remove the POC-57 pilot worktrees + branches. Run after judging is captured.
# Nothing here was pushed/merged, so this fully reverts SiteLine to pre-experiment state.
set -uo pipefail
SL="$HOME/Projects/SiteLine"
cd "$SL"
for arm in base vbw-1 native-1; do
  git worktree remove --force ".worktrees/POC-57-$arm" 2>/dev/null && echo "removed worktree POC-57-$arm"
done
for br in exp/POC-57-base exp/POC-57-vbw-1 exp/POC-57-native-1; do
  git branch -D "$br" 2>/dev/null && echo "deleted branch $br"
done
git worktree prune
echo "done — SiteLine reverted."
