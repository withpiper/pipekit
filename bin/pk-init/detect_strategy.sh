#!/usr/bin/env bash
# Emit: strategy_docs (array of paths)
set -euo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel)}"
. "$(dirname "$0")/lib.sh"

found=()
for d in "docs/strategy" "Strategy" "strategy" "docs/Strategy"; do
  full="$ROOT/$d"
  [ -d "$full" ] || continue
  while IFS= read -r f; do
    rel="${f#$ROOT/}"
    found+=("$rel")
  done < <(find "$full" -maxdepth 2 -type f -name '*.md' 2>/dev/null)
done

if [ ${#found[@]} -gt 0 ]; then
  arr=$(printf '%s\n' "${found[@]}" | sort -u | jq -R . | jq -s .)
  emit_detected_array strategy_docs "$arr" "filesystem glob"
else
  emit_missing strategy_docs "no strategy docs found (expected docs/strategy/*.md or Strategy/*.md)"
fi
