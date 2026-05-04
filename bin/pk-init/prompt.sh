#!/usr/bin/env bash
# prompt.sh — interactive dialogue for state fields with status=needs_input.
#
# Reads state.json, iterates needs_input fields, prompts the user, and rewrites
# state.json with their choices applied (status flips to detected, source set
# to "user prompt"). Skipped fields stay needs_input — the diff/edit step lets
# the user fill them manually.
#
# If stdin is not a tty (piped/test mode), skip all prompts and exit 0.
#
# Special-case: linear_team_key + linear_team_id are paired. We prompt once
# on team_key and apply the matching team_id at the same array index.
set -euo pipefail

STATE="${1:?usage: prompt.sh <state.json>}"
[ -f "$STATE" ] || { echo "ERROR: state missing: $STATE" >&2; exit 1; }

if [ ! -t 0 ]; then
  # Non-interactive: nothing to do.
  exit 0
fi

# Helper: rewrite a single field in state.json to status=detected.
set_detected() {
  local field="$1" value="$2" source="$3"
  local tmp
  tmp=$(mktemp)
  jq --arg f "$field" --arg v "$value" --arg s "$source" \
    '.[$f] = {status:"detected", value:$v, source:$s}' "$STATE" > "$tmp"
  mv "$tmp" "$STATE"
}

# Helper: present a numbered choice list and return the picked value via stdout.
# Args: $1=field name, $2=JSON candidates array, $3=reason
# Returns: chosen value on stdout, or empty if skipped.
ask_choice() {
  # All UI goes to stderr; only the chosen value (or empty) goes to stdout
  # so callers can use `picked=$(ask_choice ...)` cleanly.
  local field="$1" cands_json="$2" reason="$3"
  local count
  count=$(echo "$cands_json" | jq 'length')
  {
    echo ""
    echo "┌─ $field ─────────────────────────────────────"
    echo "│ Reason: $reason"
    if [ "$count" -gt 0 ]; then
      echo "│ Candidates:"
      local i=1
      while IFS= read -r c; do
        echo "│   $i. $c"
        i=$((i+1))
      done < <(echo "$cands_json" | jq -r '.[]')
      echo "│ [1-$count] pick  [s] skip  [q] abort"
    else
      echo "│ No candidates auto-detected."
      echo "│ Type a value, [s] skip, [q] abort"
    fi
    printf "└─ "
  } >&2
  local choice
  read -r choice
  case "$choice" in
    q|Q) echo "Aborted." >&2; exit 1 ;;
    s|S|"") echo "" ;;
    *)
      if [ "$count" -gt 0 ] && [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        echo "$cands_json" | jq -r ".[$((choice-1))]"
      else
        echo "$choice"
      fi
      ;;
  esac
}

echo ""
echo "── pk init: prompts ──"

# Special-case: Linear team pair. Handle before the generic loop so we can
# pop both fields together.
team_key_status=$(jq -r '.linear_team_key.status // ""' "$STATE")
if [ "$team_key_status" = "needs_input" ]; then
  cands=$(jq -c '.linear_team_key.candidates // []' "$STATE")
  reason=$(jq -r '.linear_team_key.reason // ""' "$STATE")
  picked=$(ask_choice "linear_team_key" "$cands" "$reason")
  if [ -n "$picked" ]; then
    set_detected linear_team_key "$picked" "user prompt"
    # Find matching team_id at the same index (only valid when both came from
    # the same Linear API response and arrays are aligned).
    idx=$(echo "$cands" | jq --arg p "$picked" 'to_entries | map(select(.value == $p)) | .[0].key // -1')
    id_cands=$(jq -c '.linear_team_id.candidates // []' "$STATE")
    if [ "$idx" != "-1" ] && [ "$(echo "$id_cands" | jq 'length')" -gt "$idx" ]; then
      matched_id=$(echo "$id_cands" | jq -r ".[$idx]")
      set_detected linear_team_id "$matched_id" "paired with linear_team_key"
      echo "  → linear_team_id auto-paired: $matched_id"
    fi
  fi
fi

# Generic loop for remaining needs_input fields.
# (Bash 3.2-compatible — no `mapfile`.)
fields=()
while IFS= read -r line; do
  [ -n "$line" ] && fields+=("$line")
done < <(jq -r '
  to_entries
  | map(select(.value.status == "needs_input"))
  | map(select(.key != "linear_team_id" and .key != "linear_team_key"))
  | .[].key
' "$STATE")

if [ ${#fields[@]} -eq 0 ]; then
  echo "No fields needing input."
  exit 0
fi

for field in "${fields[@]}"; do
  cands=$(jq -c --arg f "$field" '.[$f].candidates // []' "$STATE")
  reason=$(jq -r --arg f "$field" '.[$f].reason // ""' "$STATE")
  picked=$(ask_choice "$field" "$cands" "$reason")
  if [ -n "$picked" ]; then
    set_detected "$field" "$picked" "user prompt"
  fi
done
