#!/usr/bin/env bash
# summary.sh — render state.json as a human-readable review table.
# Grouped: detected → needs_input → missing. Truncates long values to fit width.
set -euo pipefail

STATE="${1:?usage: summary.sh <state.json>}"
[ -f "$STATE" ] || { echo "ERROR: state missing: $STATE" >&2; exit 1; }

# Column widths: field=20, value=28, source/reason=remainder
print_row() {
  local symbol="$1" field="$2" value="$3" extra="$4"
  # Truncate long values
  if [ ${#value} -gt 28 ]; then
    value="${value:0:25}..."
  fi
  printf "  %s  %-20s  %-28s  %s\n" "$symbol" "$field" "$value" "$extra"
}

print_group() {
  local title="$1" filter="$2"
  local rows
  # Use unit separator (\x1f) so empty fields aren't collapsed by read.
  rows=$(jq -r --arg filter "$filter" '
    to_entries
    | sort_by(.key)
    | map(select(.value.status == $filter))
    | .[]
    | [.key, (.value.value // "" | tostring), (.value.source // .value.reason // "")]
    | join("")
  ' "$STATE")
  if [ -z "$rows" ]; then
    return 0
  fi
  echo ""
  echo "$title"
  while IFS=$'\x1f' read -r field value extra; do
    case "$filter" in
      detected)    sym="✓" ;;
      needs_input) sym="?" ;;
      missing)     sym="✗" ;;
    esac
    # For arrays, jq emits JSON array as the value — shorten for display.
    if [[ "$value" == \[* ]]; then
      value=$(echo "$value" | jq -r 'join(", ")' 2>/dev/null || echo "$value")
    fi
    print_row "$sym" "$field" "$value" "$extra"
  done <<< "$rows"
}

echo "── pk init: review ──"
print_group "Detected:"    detected
print_group "Needs input:" needs_input
print_group "Missing:"     missing
