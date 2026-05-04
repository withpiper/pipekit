#!/usr/bin/env bash
# pk-init/main.sh — bootstrap orchestrator.
#
# Flow: detect → prompt → render → review → confirm → write.
#
# Modes:
#   bootstrap (default): when method.config.md is missing. Renders draft from
#                        method.config.template.md.
#   --update:            when method.config.md exists. Re-runs detection,
#                        renders against the existing config as baseline, and
#                        lets the user merge in detection improvements.
set -euo pipefail

ROOT=""
MODE="bootstrap"
for arg in "$@"; do
  case "$arg" in
    --update) MODE="update" ;;
    --*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) [ -z "$ROOT" ] && ROOT="$arg" ;;
  esac
done
[ -n "$ROOT" ] || { echo "usage: main.sh <repo_root> [--update]" >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

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
echo "(state dir: $STATE_DIR  mode: $MODE)"
echo ""

fragments=()
for d in "${DETECTORS[@]}"; do
  frag="$STATE_DIR/${d%.sh}.json"
  if bash "$HERE/$d" "$ROOT" > "$frag" 2>"$STATE_DIR/${d%.sh}.err"; then
    fragments+=("$frag")
  else
    echo "  ✗ $d failed (see $STATE_DIR/${d%.sh}.err)" >&2
    fragments+=("$frag")
  fi
done

jq -s 'add // {}' "${fragments[@]}" > "$STATE"

# Initial scan summary (compact one-liner per field).
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

# Prompt for needs_input fields. Mutates state.json in place.
bash "$HERE/prompt.sh" "$STATE"

# Locate template (bootstrap) or existing config (update) as baseline.
TARGET="$ROOT/method.config.md"
if [ "$MODE" = "update" ]; then
  if [ ! -f "$TARGET" ]; then
    echo "ERROR: --update requires existing method.config.md at $TARGET" >&2
    exit 1
  fi
  BASELINE="$TARGET"
else
  BASELINE="$ROOT/method.config.template.md"
  if [ ! -f "$BASELINE" ]; then
    PIPEKIT_TEMPLATE="$(dirname "$HERE")/../method.config.template.md"
    if [ -f "$PIPEKIT_TEMPLATE" ]; then
      BASELINE="$PIPEKIT_TEMPLATE"
    else
      echo ""
      echo "ERROR: method.config.template.md not found in $ROOT or pipekit source." >&2
      echo "       Run scripts/sync-method.sh from pipekit first, or copy the template manually." >&2
      exit 1
    fi
  fi
fi

DRAFT="$STATE_DIR/method.config.md.draft"
bash "$HERE/render.sh" "$BASELINE" "$STATE" > "$DRAFT"
echo ""
echo "Draft:    $DRAFT"
echo "Target:   $TARGET"

# Review table (high-level summary).
bash "$HERE/summary.sh" "$STATE"
echo ""

while true; do
  printf "Write? [y]es  [d]iff (full)  [e]dit draft in \$EDITOR  [n]o, abort: "
  read -r choice
  case "$choice" in
    y|Y)
      if [ -e "$TARGET" ] && [ "$MODE" != "update" ]; then
        echo "ERROR: $TARGET already exists. Use 'pk init --update' to merge." >&2
        exit 1
      fi
      cp "$DRAFT" "$TARGET"
      bytes=$(wc -c < "$TARGET" | tr -d ' ')
      echo ""
      echo "✓ Wrote $bytes bytes → $TARGET"
      if [ "$MODE" = "bootstrap" ]; then
        echo ""
        echo "Next: pk init   (post-config health check)"
      fi
      break
      ;;
    d|D)
      echo ""
      echo "── diff (baseline → draft) ──"
      bash "$HERE/diff.sh" "$BASELINE" "$DRAFT"
      echo ""
      ;;
    e|E)
      "${EDITOR:-vi}" "$DRAFT"
      echo ""
      echo "── diff (baseline → draft, post-edit) ──"
      bash "$HERE/diff.sh" "$BASELINE" "$DRAFT"
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
