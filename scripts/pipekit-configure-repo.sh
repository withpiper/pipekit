#!/usr/bin/env bash
# pipekit-configure-repo.sh
#
# Configure a GitHub repo with Pipekit's recommended merge strategy
# (v1.8.0.6+):
#
#   - Repo level: rebase, squash, AND merge-commits all allowed
#       → gives you flexibility on feature → dev (rebase or merge-commit, your choice)
#   - main branch: squash-only enforced via GitHub Ruleset
#       → prevents accidental merge-commits to main (the phantom-conflict trap)
#   - delete_branch_on_merge: true (auto-delete remote branches)
#
# Why Rulesets instead of just disallowing merge_commit globally?
# Earlier (v1.7.0–v1.8.0.5) we disallowed merge_commit at the repo level. That
# prevented the phantom-conflict trap on main, but also banned merge bubbles
# on dev — which some users prefer for feature-branch readability in
# GitKraken / git-log. Rulesets let us be precise: main = squash-only,
# dev/everything-else = your choice.
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

RULESET_NAME="pipekit-main-squash-only"

echo "Repo: $REPO"
echo

# ---------------------------------------------------------------------------
# Step 1: repo-level merge settings — allow rebase, squash, AND merge-commits
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

echo "Applying: merge=on, squash=on, rebase=on, auto-delete=on..."
gh api "repos/$REPO" --method PATCH \
  -f delete_branch_on_merge=true \
  -f allow_merge_commit=true \
  -f allow_squash_merge=true \
  -f allow_rebase_merge=true \
  --jq '{
    delete_branch_on_merge,
    allow_merge_commit,
    allow_squash_merge,
    allow_rebase_merge
  }'

echo

# ---------------------------------------------------------------------------
# Step 2: main-branch ruleset — squash-only on PRs targeting main
# ---------------------------------------------------------------------------

echo "Step 2 — Main-branch ruleset ($RULESET_NAME)"
echo

# Check for existing ruleset by name
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
        "allowed_merge_methods": ["squash"]
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
echo "  dev → main         → Squash (enforced by ruleset; UI dropdown will show only Squash)"
echo "  Auto-delete remote branches on merge → enabled."
