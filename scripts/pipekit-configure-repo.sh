#!/usr/bin/env bash
# pipekit-configure-repo.sh
#
# Idempotent one-shot to configure a GitHub repo with the merge-strategy
# combination Pipekit recommends (v1.8.0+):
#   - rebase merges allowed (for feature → dev)
#   - squash merges allowed (for dev → main)
#   - merge commits disallowed (kills phantom-conflict topology)
#   - auto-delete head branches on merge (remote cleanup)
#
# Usage:
#   bash scripts/pipekit-configure-repo.sh <org>/<repo>
#   bash scripts/pipekit-configure-repo.sh                  # auto-detect from `gh repo view`
#
# Output: shows before-and-after state. Safe to re-run.

set -euo pipefail

REPO="${1:-}"

if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
  if [ -z "$REPO" ]; then
    echo "ERROR: pass <org>/<repo> as the first argument or run from inside a gh-linked repo." >&2
    exit 1
  fi
fi

echo "Repo: $REPO"
echo

echo "Before:"
gh api "repos/$REPO" --jq '{
  delete_branch_on_merge,
  allow_merge_commit,
  allow_squash_merge,
  allow_rebase_merge
}'
echo

echo "Applying Pipekit-recommended settings..."
gh api "repos/$REPO" --method PATCH \
  -f delete_branch_on_merge=true \
  -f allow_merge_commit=false \
  -f allow_squash_merge=true \
  -f allow_rebase_merge=true \
  --jq '{
    delete_branch_on_merge,
    allow_merge_commit,
    allow_squash_merge,
    allow_rebase_merge
  }'

echo
echo "Done. Next time you 'Merge pull request' in the UI:"
echo "  feature → dev      → Rebase and merge"
echo "  dev → main         → Squash and merge"
echo "  Anything to merge-commit is disabled (intentional)."
