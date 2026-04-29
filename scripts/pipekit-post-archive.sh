#!/usr/bin/env bash
# pipekit-post-archive.sh <milestone-slug> <archive-path> <tag>
#
# Post-archive hook invoked by VBW after `/vbw:vibe --archive` completes.
# VBW calls user-configured hooks via scripts/post-archive-hook.sh, which
# reads `.hooks.post_archive` from `.vbw-planning/config.json`.
#
# This hook writes a marker file that the next Claude Code session picks up
# and uses to nudge the user to run /strategy-sync. We deliberately do NOT
# invoke Claude directly here — that would require a non-interactive CLI path
# and bypass the human-in-the-loop strategy review.
#
# Register this hook by adding to `.vbw-planning/config.json`:
#   {"hooks": {"post_archive": "scripts/pipekit-post-archive.sh"}}
#
# VBW resolves relative paths against the project root, so the entry above
# works from any repo with Pipekit synced.

set -u

MILESTONE_SLUG="${1:-}"
ARCHIVE_PATH="${2:-}"
TAG="${3:-}"

if [ -z "$MILESTONE_SLUG" ] || [ -z "$ARCHIVE_PATH" ]; then
  echo "[pipekit-post-archive] missing required args" >&2
  exit 0
fi

PROJECT_ROOT="${VBW_CONFIG_ROOT:-$(pwd -P 2>/dev/null || pwd)}"

# v1.7.0+: marker lives outside the repo (XDG cache) so VBW's file-guard
# never blocks the write. See scripts/pipekit-state-dir.sh and #13.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/pipekit-state-dir.sh" ]; then
  MARKER_DIR=$(cd "$PROJECT_ROOT" && bash "$SCRIPT_DIR/pipekit-state-dir.sh")
else
  # Fallback: inline the resolution logic so the hook doesn't hard-fail
  # on consumers mid-upgrade.
  REPO_BASE=$(cd "$PROJECT_ROOT" && git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null || echo "_default")
  MARKER_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/pipekit/$REPO_BASE"
fi
MARKER_FILE="$MARKER_DIR/pending-strategy-sync"

mkdir -p "$MARKER_DIR" 2>/dev/null || {
  echo "[pipekit-post-archive] could not create $MARKER_DIR; skipping" >&2
  exit 0
}

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
  echo "timestamp=$TIMESTAMP"
  echo "milestone_slug=$MILESTONE_SLUG"
  echo "archive_path=$ARCHIVE_PATH"
  echo "tag=$TAG"
} > "$MARKER_FILE"

echo "[pipekit-post-archive] milestone $MILESTONE_SLUG archived — run /strategy-sync to update strategy docs"

exit 0
