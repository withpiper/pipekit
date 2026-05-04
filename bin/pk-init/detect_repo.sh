#!/usr/bin/env bash
# Emit: repo_org, repo_name, default_branch
set -euo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel)}"
. "$(dirname "$0")/lib.sh"

cd "$ROOT"

remote=$(git remote get-url origin 2>/dev/null || echo "")
org="" name=""
if [ -n "$remote" ]; then
  # Handles git@github.com:org/repo.git and https://github.com/org/repo(.git)
  stripped="${remote%.git}"
  case "$stripped" in
    *github.com:*|*github.com/*)
      tail="${stripped#*github.com[:/]}"
      org="${tail%%/*}"
      name="${tail#*/}"
      ;;
  esac
fi

default_branch=""
if git symbolic-ref refs/remotes/origin/HEAD >/dev/null 2>&1; then
  default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')
fi

out="{}"
if [ -n "$org" ]; then
  out=$(jq -s 'add' <(echo "$out") <(emit_detected repo_org "$org" "git remote origin"))
else
  out=$(jq -s 'add' <(echo "$out") <(emit_missing repo_org "no origin remote"))
fi
if [ -n "$name" ]; then
  out=$(jq -s 'add' <(echo "$out") <(emit_detected repo_name "$name" "git remote origin"))
else
  out=$(jq -s 'add' <(echo "$out") <(emit_missing repo_name "no origin remote"))
fi
if [ -n "$default_branch" ]; then
  out=$(jq -s 'add' <(echo "$out") <(emit_detected default_branch "$default_branch" "origin/HEAD"))
else
  out=$(jq -s 'add' <(echo "$out") <(emit_needs_input default_branch '["main","master"]' "origin/HEAD not set; pick default"))
fi

echo "$out"
