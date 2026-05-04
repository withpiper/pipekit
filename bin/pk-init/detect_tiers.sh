#!/usr/bin/env bash
# Emit: tiers (array of branches that look like environment tiers)
set -euo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel)}"
. "$(dirname "$0")/lib.sh"

cd "$ROOT"

# Look at remote and local branches; common tier names.
all=$( (git branch --format='%(refname:short)'; git branch -r --format='%(refname:short)') 2>/dev/null \
  | sed 's@^origin/@@' \
  | sort -u )

tiers=()
for t in main master dev develop staging uat preview production; do
  if echo "$all" | grep -qx "$t"; then
    tiers+=("$t")
  fi
done

if [ ${#tiers[@]} -gt 0 ]; then
  arr=$(printf '%s\n' "${tiers[@]}" | jq -R . | jq -s .)
  emit_detected_array tiers "$arr" "git branches"
else
  emit_missing tiers "no recognized tier branches"
fi
