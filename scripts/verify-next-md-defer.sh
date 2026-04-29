#!/usr/bin/env bash
# verify-next-md-defer.sh
#
# Reproducible end-to-end check for the NEXT.md defer + apply round-trip
# (v1.6.0 #12, relocated v1.7.0 #13). Exercises the deferral detection
# logic from skills/review-plan/skill.md (Step 7) and the apply logic
# from skills/end-session/skill.md (Step 7b.0).
#
# v1.7.0 update: queue file lives at $STATE_DIR/pending-next-md.json
# where $STATE_DIR is resolved by scripts/pipekit-state-dir.sh and points
# OUTSIDE the repo (under $XDG_CACHE_HOME). This dodges VBW's file-guard
# hook which silently blocked the in-repo .pipekit/ path in v1.6.0.
#
# Usage:
#   bash scripts/verify-next-md-defer.sh
#
# Behavior:
#   1. Builds an ephemeral fake project tree under a temp dir, plus an
#      isolated XDG_CACHE_HOME so we don't pollute the real cache.
#   2. Symlinks pipekit-state-dir.sh into the fake repo so the helper
#      resolves correctly inside the temp tree.
#   3. Creates a fake VBW PLAN.md with a files_modified field that
#      does NOT include NEXT.md (the conflict that #12 fixes).
#   4. Runs the deferral check inline; expects DEFER_NEXT_MD=1.
#   5. Resolves $STATE_DIR via the helper and writes the queue file there.
#   6. Confirms the queue file is OUTSIDE the repo (the v1.7.0 fix).
#   7. Runs the apply step (/end-session Step 7b.0); expects NEXT.md
#      to receive the queued content and the queue file to be deleted.
#
# Exit status: 0 on success, non-zero on failure with a diagnostic line.
#
# This is dogfooding — the same logic shipped in the skill prose, run
# end-to-end. Re-run after any future edit to the deferral mechanism.

set -euo pipefail

REAL_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pipekit-state-dir.sh"
if [ ! -x "$REAL_HELPER" ]; then
  echo "FAIL: helper not found at $REAL_HELPER" >&2
  exit 1
fi

TMP=$(mktemp -d)
TMP_CACHE=$(mktemp -d)
trap 'rm -rf "$TMP" "$TMP_CACHE"' EXIT

export XDG_CACHE_HOME="$TMP_CACHE"

cd "$TMP"
git init -q
mkdir -p .vbw-planning/phases/test-phase scripts
ln -s "$REAL_HELPER" scripts/pipekit-state-dir.sh

cat > .vbw-planning/phases/test-phase/01-01-PLAN.md <<'PLAN'
# Test Phase Plan

files_modified:
  - apps/web/src/foo.ts
  - apps/web/src/bar.ts
PLAN

# --- Deferral detection (mirrors skills/review-plan/skill.md Step 7) ---
ACTIVE_PLAN=""
for plan in .vbw-planning/phases/*/[0-9]*-PLAN.md; do
  [ -f "$plan" ] || continue
  if grep -qE "^(files_modified:|## files_modified)" "$plan" 2>/dev/null; then
    ACTIVE_PLAN="$plan"
    break
  fi
done

DEFER_NEXT_MD=0
if [ -n "$ACTIVE_PLAN" ] && ! grep -q "NEXT\.md" "$ACTIVE_PLAN"; then
  DEFER_NEXT_MD=1
fi

if [ "$DEFER_NEXT_MD" != "1" ]; then
  echo "FAIL: expected DEFER_NEXT_MD=1, got $DEFER_NEXT_MD" >&2
  exit 1
fi

# --- Resolve out-of-repo state dir (v1.7.0 fix) ---
STATE_DIR=$(bash scripts/pipekit-state-dir.sh)
mkdir -p "$STATE_DIR"

# Confirm the fix: STATE_DIR must be outside the repo.
case "$STATE_DIR" in
  "$TMP"/*)
    echo "FAIL: STATE_DIR ($STATE_DIR) resolved inside the repo — v1.7.0 fix not applied" >&2
    exit 1
    ;;
esac

# --- Queue write (review-plan would do this) ---
QUEUE="$STATE_DIR/pending-next-md.json"
cat > "$QUEUE" <<JSON
{
  "queued_at": "2026-04-29T14:32:00-04:00",
  "writer": "/review-plan",
  "active_plan": "$ACTIVE_PLAN",
  "content": "# Next Step\n\n**Last updated:** 2026-04-29 14:32 local by /review-plan\n\n## Recommended next command\n\`/vbw:vibe --execute test-phase\`\n"
}
JSON

if [ ! -f "$QUEUE" ]; then
  echo "FAIL: queue file not written at $QUEUE" >&2
  exit 1
fi

# --- Apply (end-session Step 7b.0) ---
python3 -c "import json,sys; open('NEXT.md','w').write(json.load(open('$QUEUE'))['content'])"
rm -f "$QUEUE"

if [ ! -f NEXT.md ]; then
  echo "FAIL: NEXT.md not written by apply step" >&2
  exit 1
fi

if [ -f "$QUEUE" ]; then
  echo "FAIL: queue file not cleaned up" >&2
  exit 1
fi

if ! grep -q "/vbw:vibe --execute test-phase" NEXT.md; then
  echo "FAIL: NEXT.md missing expected next-command" >&2
  exit 1
fi

echo "OK: defer detection, out-of-repo queue write, and apply round-trip all passed."
echo "    STATE_DIR resolved to: $STATE_DIR"
