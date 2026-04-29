#!/usr/bin/env bash
# verify-next-md-defer.sh
#
# Reproducible end-to-end check for the v1.6.0 NEXT.md defer + apply
# round-trip introduced by #12. Exercises the deferral detection logic
# from skills/review-plan/skill.md (Step 7) and the apply logic from
# skills/end-session/skill.md (Step 7b.0).
#
# Usage:
#   bash scripts/verify-next-md-defer.sh
#
# Behavior:
#   1. Builds an ephemeral fake project tree under a temp dir.
#   2. Creates a fake VBW PLAN.md with a files_modified field that
#      does NOT include NEXT.md (the conflict that #12 fixes).
#   3. Runs the deferral check inline; expects DEFER_NEXT_MD=1.
#   4. Writes a queue file at .pipekit/pending-next-md.json.
#   5. Runs the apply step (/end-session Step 7b.0); expects NEXT.md
#      to receive the queued content and the queue file to be deleted.
#
# Exit status: 0 on success, non-zero on failure with a diagnostic line.
#
# This is dogfooding — the same logic shipped in the skill prose, run
# end-to-end. Re-run after any future edit to the deferral mechanism.

set -euo pipefail

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cd "$TMP"
mkdir -p .vbw-planning/phases/test-phase .pipekit/pipeline-state

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

# --- Queue write (review-plan would do this) ---
cat > .pipekit/pending-next-md.json <<JSON
{
  "queued_at": "2026-04-29T14:32:00-04:00",
  "writer": "/review-plan",
  "active_plan": "$ACTIVE_PLAN",
  "content": "# Next Step\n\n**Last updated:** 2026-04-29 14:32 local by /review-plan\n\n## Recommended next command\n\`/vbw:vibe --execute test-phase\`\n"
}
JSON

if [ ! -f .pipekit/pending-next-md.json ]; then
  echo "FAIL: queue file not written" >&2
  exit 1
fi

# --- Apply (end-session Step 7b.0) ---
QUEUE=".pipekit/pending-next-md.json"
python3 -c "import json,sys; open('NEXT.md','w').write(json.load(open('$QUEUE'))['content'])"
rm -f "$QUEUE"

if [ ! -f NEXT.md ]; then
  echo "FAIL: NEXT.md not written by apply step" >&2
  exit 1
fi

if [ -f .pipekit/pending-next-md.json ]; then
  echo "FAIL: queue file not cleaned up" >&2
  exit 1
fi

if ! grep -q "/vbw:vibe --execute test-phase" NEXT.md; then
  echo "FAIL: NEXT.md missing expected next-command" >&2
  exit 1
fi

echo "OK: defer detection, queue write, and apply round-trip all passed."
