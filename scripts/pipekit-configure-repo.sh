#!/usr/bin/env bash
# pipekit-configure-repo.sh
#
# Configure a GitHub repo with Pipekit's recommended merge strategy
# (v2.2.0+):
#
#   - Repo level: rebase + merge-commit allowed; squash DISABLED
#       → squash creates orphan SHAs that diverge dev and main, causing
#         phantom conflicts on every subsequent dev → main promote
#   - main branch: merge-commit-only enforced via GitHub Ruleset
#       → guarantees a single anchor commit per promote (revert -m 1, log
#         --first-parent) and prevents accidental rebase or squash
#   - delete_branch_on_merge: true (auto-delete remote branches)
#
# Why no squash anywhere?
# v1.7.0–v2.1.x oscillated on this. v1.7.0 banned merge-commits everywhere
# (caused phantom conflicts via a different topology). v1.8.0.6 split the
# rules: rebase/merge for feature → dev, squash for dev → main. Both Piper
# and rs-vault hit phantom conflicts under v1.8.0.6 — squash on dev → main
# is the cause, not the cure. Squash collapses N atomic dev commits into
# one orphan commit on main; the next promote's merge-base sees divergent
# histories touching the same files and fails.
#
# v2.2.0 eliminates squash entirely. Atomic commits flow feature → dev →
# main with stable SHAs. Pipekit discipline already enforces "one atomic
# change per commit," so the cleanup-via-squash use case doesn't apply.
# `git log main --first-parent` gives the squash-equivalent view (one
# entry per promote) without losing the underlying commits for bisect/blame.
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

RULESET_NAME="pipekit-main-merge-only"
LEGACY_RULESET_NAME="pipekit-main-squash-only"

echo "Repo: $REPO"
echo

# ---------------------------------------------------------------------------
# Step 1: repo-level merge settings — disallow squash globally
# ---------------------------------------------------------------------------

echo "Step 1 — Repo-level merge settings"
echo

echo "Before:"
gh api "repos/$REPO" --jq '{
  delete_branch_on_merge,
  allow_merge_commit,
  allow_squash_merge,
  allow_rebase_merge
}'
echo

echo "Applying: merge=on, squash=OFF, rebase=on, auto-delete=on..."
gh api "repos/$REPO" --method PATCH \
  -f delete_branch_on_merge=true \
  -f allow_merge_commit=true \
  -F allow_squash_merge=false \
  -f allow_rebase_merge=true \
  --jq '{
    delete_branch_on_merge,
    allow_merge_commit,
    allow_squash_merge,
    allow_rebase_merge
  }'

echo

# ---------------------------------------------------------------------------
# Step 2: main-branch ruleset — merge-commit-only on PRs targeting main
# ---------------------------------------------------------------------------

echo "Step 2 — Main-branch ruleset ($RULESET_NAME)"
echo

# Migrate legacy v1.8.0.6+ ruleset if present (squash-only → merge-only).
LEGACY_ID=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$LEGACY_RULESET_NAME\") | .id" 2>/dev/null || echo "")
if [ -n "$LEGACY_ID" ]; then
  echo "Found legacy ruleset '$LEGACY_RULESET_NAME' (id=$LEGACY_ID) — deleting (will be replaced)..."
  gh api "repos/$REPO/rulesets/$LEGACY_ID" --method DELETE >/dev/null
fi

# Check for existing v2.2.0+ ruleset by name
EXISTING_ID=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null || echo "")

RULESET_BODY=$(cat <<JSON
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge"]
      }
    }
  ]
}
JSON
)

if [ -n "$EXISTING_ID" ]; then
  echo "Updating existing ruleset (id=$EXISTING_ID)..."
  echo "$RULESET_BODY" | gh api "repos/$REPO/rulesets/$EXISTING_ID" \
    --method PUT \
    --input - \
    --jq '{name, enforcement, allowed_merge_methods: (.rules[] | select(.type == "pull_request") | .parameters.allowed_merge_methods)}'
else
  echo "Creating new ruleset..."
  echo "$RULESET_BODY" | gh api "repos/$REPO/rulesets" \
    --method POST \
    --input - \
    --jq '{name, enforcement, allowed_merge_methods: (.rules[] | select(.type == "pull_request") | .parameters.allowed_merge_methods)}'
fi

echo
echo "Done. Effective merge policy:"
echo "  feature → dev      → Rebase OR Merge commit (your choice in the GitHub UI)"
echo "  dev → main         → Merge commit (enforced by ruleset; UI dropdown will show only Merge)"
echo "  Squash             → Disabled repo-wide (causes phantom conflicts on promote)"
echo "  Auto-delete remote branches on merge → enabled."
