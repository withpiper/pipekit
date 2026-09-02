#!/usr/bin/env bash
# dogfood-sync.sh — refresh pipekit's OWN .claude/ working copies from source.
#
# Why this exists
# ---------------
# Pipekit's product is skills and rules. For Claude Code to *use* them while
# developing pipekit, they have to sit in .claude/ — but the canonical copies
# live elsewhere in the tree (skills/, templates/rules/, agents/,
# workflows/, templates/hooks/). Consuming projects get their .claude/ written by
# sync-method.sh; pipekit itself had no equivalent, so its .claude/ copies were
# made by hand and then rotted.
#
# Measured 2026-07-31, before this script existed: all 25 mirrored skills
# differed from source, 6 skills were missing entirely, .claude/rules/ was
# missing pipekit-migrations.md, and .claude/skills/verify/SKILL.md was 157
# lines behind — still carrying the ${PIPESTATUS[0]} gate bug that v4.26.0
# fixed. Sessions in this repo were running a broken copy of the file the same
# release had just repaired.
#
# Usage
# -----
#   scripts/dogfood-sync.sh           refresh the mirrors
#   scripts/dogfood-sync.sh --check   report drift, exit 1 if any (no writes)
#
# Never deletes. Anything present in a mirror but absent from source is
# reported, not removed — same philosophy as sync-method.sh's per-file copy,
# so a pipekit-local experiment can't be destroyed by a refresh.

set -euo pipefail

CHECK_ONLY=false
[ "${1:-}" = "--check" ] && CHECK_ONLY=true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Guard: this script writes into .claude/ and is meaningless outside pipekit.
if [ ! -f "$ROOT/bin/pk" ] || [ ! -d "$ROOT/skills" ] || [ ! -f "$ROOT/method.md" ]; then
  echo "ERROR: not the pipekit repo (expected bin/pk, skills/, method.md at $ROOT)" >&2
  exit 1
fi

# source_dir : mirror_dir
PAIRS="
skills:.claude/skills
templates/rules:.claude/rules
agents:.claude/agents
workflows:.claude/workflows
templates/hooks:.claude/hooks
"

DRIFT=0
EXTRA=0

for pair in $PAIRS; do
  src="${pair%%:*}"
  dst="${pair##*:}"
  [ -d "$src" ] || continue

  # Every regular file under src, path-relative, so nested files
  # (skills/pr-fix/references/*.md, skill.json) travel too.
  while IFS= read -r rel; do
    s="$src/$rel"
    d="$dst/$rel"
    if [ -f "$d" ] && cmp -s "$s" "$d"; then
      continue
    fi
    DRIFT=$((DRIFT + 1))
    if [ "$CHECK_ONLY" = true ]; then
      [ -f "$d" ] && echo "  DRIFT   $d" || echo "  MISSING $d"
    else
      mkdir -p "$(dirname "$d")"
      cp "$s" "$d"
      echo "  synced  $d"
    fi
  done < <(cd "$src" && find . -type f ! -name '.DS_Store' | sed 's|^\./||' | sort)

  # Report-only: present in the mirror, absent from source.
  [ -d "$dst" ] || continue
  while IFS= read -r rel; do
    [ -f "$src/$rel" ] && continue
    EXTRA=$((EXTRA + 1))
    echo "  EXTRA   $dst/$rel (not in $src/ — left alone)"
  done < <(cd "$dst" && find . -type f ! -name '.DS_Store' | sed 's|^\./||' | sort)
done

echo ""
if [ "$CHECK_ONLY" = true ]; then
  if [ "$DRIFT" -gt 0 ]; then
    echo "dogfood mirrors are STALE: $DRIFT file(s) drifted or missing."
    echo "Fix: scripts/dogfood-sync.sh"
    exit 1
  fi
  echo "dogfood mirrors are current${EXTRA:+ ($EXTRA extra file(s) reported above)}."
else
  echo "dogfood sync complete: $DRIFT file(s) refreshed, $EXTRA extra left alone."
fi
