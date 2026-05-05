#!/usr/bin/env bash
# check-no-self-references.sh — fail if the current branch's source still
# contains references to its own ticket ID outside the files it edited.
#
# Catches the RS-29 failure mode: a ticket ships, all tests pass, gate is
# green, but a predecessor's placeholder branch in an un-touched file still
# references the current ticket ("until RS-29 ships"). The integration is
# incomplete.
#
# Usage:
#   scripts/check-no-self-references.sh             # auto-detect issue ID + source root
#   scripts/check-no-self-references.sh RS-29       # explicit issue ID
#   scripts/check-no-self-references.sh RS-29 src/  # explicit ID + source root
#
# Exit codes:
#   0 — no matches outside edited files (or no issue ID detected → skip)
#   1 — matches found in non-edited, non-allowlisted source files
#   2 — usage / configuration error
#
# Configuration (read from method.config.md if present):
#   Source root        — defaults to `src/`
#   Allowlist          — globs always excluded (defaults: *.md, *.test.*,
#                        Logs/Sessions/**, .vbw-planning/**, CHANGELOG*)

set -euo pipefail

# --- Locate repo + config --------------------------------------------------

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not in a git repo" >&2
  exit 2
}
cd "$REPO_ROOT"

CONFIG="$REPO_ROOT/method.config.md"

# Prefer pk_config (read structured value from method.config.md). Falls back
# to defaults when pk isn't on PATH or method.config.md is missing.
read_config() {
  local key="$1" default="$2"
  if command -v pk >/dev/null 2>&1 && [ -f "$CONFIG" ]; then
    pk pk_config "$key" "$default" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# --- Resolve issue ID ------------------------------------------------------

ISSUE="${1:-}"
if [ -z "$ISSUE" ]; then
  CURRENT=$(git branch --show-current 2>/dev/null || echo "")
  ISSUE=$(echo "$CURRENT" | grep -oE '[A-Z]+-[0-9]+' | head -1 || true)
fi
if [ -z "$ISSUE" ]; then
  echo "  ⓘ check-no-self-references: no issue ID detected (branch: ${CURRENT:-<none>}); skipping"
  exit 0
fi

# --- Resolve source root ---------------------------------------------------

SOURCE_ROOT="${2:-}"
if [ -z "$SOURCE_ROOT" ]; then
  SOURCE_ROOT=$(read_config "Source root" "src/")
fi
if [ ! -d "$REPO_ROOT/$SOURCE_ROOT" ]; then
  # Fallback: try common roots
  for cand in src/ app/ packages/; do
    if [ -d "$REPO_ROOT/$cand" ]; then
      SOURCE_ROOT="$cand"
      break
    fi
  done
fi
if [ ! -d "$REPO_ROOT/$SOURCE_ROOT" ]; then
  echo "  ⓘ check-no-self-references: source root '$SOURCE_ROOT' not found; skipping" >&2
  exit 0
fi

# --- Determine merge-base + edited files -----------------------------------

# Default base branch: try origin/dev → origin/main → main → empty.
BASE=""
for cand in origin/dev origin/main main dev; do
  if git rev-parse --verify "$cand" >/dev/null 2>&1; then
    BASE="$cand"
    break
  fi
done

EDITED_FILES=""
if [ -n "$BASE" ]; then
  EDITED_FILES=$(git diff --name-only "$BASE"...HEAD 2>/dev/null | sort -u)
fi

# --- Run the grep ----------------------------------------------------------

# Pathspec exclusions for the allowlist. Globs use git's pathspec syntax.
ALLOWLIST=(
  ":(exclude)*.md"
  ":(exclude)*.test.*"
  ":(exclude)*.spec.*"
  ":(exclude)**/__tests__/**"
  ":(exclude)Logs/Sessions/**"
  ":(exclude).vbw-planning/**"
  ":(exclude)CHANGELOG*"
)

# Run grep in source root + allowlist exclusions.
matches=$(git grep -nE "$ISSUE" -- "$SOURCE_ROOT" "${ALLOWLIST[@]}" 2>/dev/null || true)

if [ -z "$matches" ]; then
  echo "✓ check-no-self-references: no '$ISSUE' references in $SOURCE_ROOT (excluding tests/docs)"
  exit 0
fi

# --- Filter out edited files ----------------------------------------------

unexpected=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  file="${line%%:*}"
  if [ -n "$EDITED_FILES" ] && echo "$EDITED_FILES" | grep -qx "$file"; then
    continue  # legitimate — this file was edited by the current branch
  fi
  unexpected+="$line"$'\n'
done <<< "$matches"

if [ -z "$unexpected" ]; then
  edited_count=$(echo "$matches" | wc -l | tr -d ' ')
  echo "✓ check-no-self-references: $edited_count match(es) for '$ISSUE', all in edited files"
  exit 0
fi

# --- Report failures -------------------------------------------------------

echo ""
echo "✗ check-no-self-references: '$ISSUE' is referenced in non-edited source files:"
echo ""
printf '%s' "$unexpected" | sed 's/^/  /'
echo ""
echo "These are likely placeholder branches a predecessor scaffolded for this ticket"
echo "to replace. Either (a) make the edit to remove them, or (b) re-run with"
echo "AGREED_PLACEHOLDER=1 to bypass after surfacing them in the hand-off summary."
echo ""

if [ "${AGREED_PLACEHOLDER:-0}" = "1" ]; then
  echo "  AGREED_PLACEHOLDER=1 — bypassing (matches above must be in hand-off summary)"
  exit 0
fi

exit 1
