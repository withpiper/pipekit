#!/usr/bin/env bash
# diff.sh — show unified diff of draft against a baseline (template or existing config).
#
# Usage: diff.sh <baseline> <draft>
#   baseline: original file we're comparing against (template, or existing method.config.md for --update)
#   draft:    rendered candidate
#
# Prints colorized diff if stdout is a tty; plain otherwise. Exits 0 even
# when the files differ — caller decides what to do with the diff.
set -euo pipefail

BASELINE="${1:?usage: diff.sh <baseline> <draft>}"
DRAFT="${2:?usage: diff.sh <baseline> <draft>}"

[ -f "$BASELINE" ] || { echo "ERROR: baseline missing: $BASELINE" >&2; exit 1; }
[ -f "$DRAFT" ]    || { echo "ERROR: draft missing: $DRAFT" >&2; exit 1; }

if [ -t 1 ] && command -v diff >/dev/null 2>&1; then
  # Try `git diff --no-index --color` first — best output, handles binary safely.
  if command -v git >/dev/null 2>&1; then
    git --no-pager diff --no-index --color=always -- "$BASELINE" "$DRAFT" || true
    exit 0
  fi
fi

diff -u "$BASELINE" "$DRAFT" || true
