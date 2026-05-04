#!/usr/bin/env bash
# pk-init/main.sh — bootstrap orchestrator (step 2: detect-only).
#
# Phases (this file grows over steps 2-6):
#   2. Detect → state.json + dump      ← we are here
#   3. Resolve + render
#   4. Diff + confirm
#   5. Prompt for needs_input
#   6. Write
set -euo pipefail

ROOT="${1:?usage: main.sh <repo_root>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

# Per-run state dir; survives the run for inspection if --keep-state.
STATE_DIR="${TMPDIR:-/tmp}/pk-init-$$"
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/state.json"

DETECTORS=(
  detect_repo.sh
  detect_stack.sh
  detect_scripts.sh
  detect_tiers.sh
  detect_strategy.sh
  detect_vbw.sh
  detect_linear.sh
)

echo "── pk init: detect ──"
echo "(state dir: $STATE_DIR)"
echo ""

# Run each detector; collect fragments.
fragments=()
for d in "${DETECTORS[@]}"; do
  frag="$STATE_DIR/${d%.sh}.json"
  if bash "$HERE/$d" "$ROOT" > "$frag" 2>"$STATE_DIR/${d%.sh}.err"; then
    fragments+=("$frag")
  else
    echo "  ✗ $d failed (see $STATE_DIR/${d%.sh}.err)" >&2
    fragments+=("$frag")  # may be partial/empty; tolerated
  fi
done

# Merge.
jq -s 'add // {}' "${fragments[@]}" > "$STATE"

# Pretty-print summary.
echo "Detected fields:"
jq -r '
  to_entries
  | sort_by(.key)
  | .[]
  | "  " + (.key | . + ":" + (" " * (20 - length)))
    + (
        if   .value.status == "detected"    then "✓ " + (.value.value | tostring) + "  (" + .value.source + ")"
        elif .value.status == "needs_input" then "? candidates=" + (.value.candidates | tostring) + "  — " + .value.reason
        elif .value.status == "missing"     then "✗ " + .value.reason
        else "? unknown" end
      )
' "$STATE"

echo ""
echo "State file: $STATE"

# Step 5: prompt for needs_input fields. Mutates state.json in place.
bash "$HERE/prompt.sh" "$STATE"

# Step 3: render draft.
TEMPLATE="$ROOT/method.config.template.md"
if [ ! -f "$TEMPLATE" ]; then
  PIPEKIT_TEMPLATE="$(dirname "$HERE")/../method.config.template.md"
  if [ -f "$PIPEKIT_TEMPLATE" ]; then
    TEMPLATE="$PIPEKIT_TEMPLATE"
  else
    echo ""
    echo "ERROR: method.config.template.md not found in $ROOT or pipekit source." >&2
    echo "       Run scripts/sync-method.sh from pipekit first, or copy the template manually." >&2
    exit 1
  fi
fi

DRAFT="$STATE_DIR/method.config.md.draft"
bash "$HERE/render.sh" "$TEMPLATE" "$STATE" > "$DRAFT"
echo "Draft:      $DRAFT"
echo ""

# Step 4: diff + confirm.
echo "── diff (template → draft) ──"
bash "$HERE/diff.sh" "$TEMPLATE" "$DRAFT"
echo ""

TARGET="$ROOT/method.config.md"
echo "Target:     $TARGET"
echo ""

while true; do
  printf "Write? [y]es  [e]dit draft in \$EDITOR  [n]o, abort: "
  read -r choice
  case "$choice" in
    y|Y)
      echo "(step 6 not implemented — would write $DRAFT → $TARGET)"
      break
      ;;
    e|E)
      "${EDITOR:-vi}" "$DRAFT"
      echo ""
      echo "── diff (template → draft, post-edit) ──"
      bash "$HERE/diff.sh" "$TEMPLATE" "$DRAFT"
      echo ""
      ;;
    n|N|"")
      echo "Aborted. Draft kept at: $DRAFT"
      exit 1
      ;;
    *)
      echo "  unknown choice: $choice"
      ;;
  esac
done
