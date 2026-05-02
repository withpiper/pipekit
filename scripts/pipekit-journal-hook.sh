#!/usr/bin/env bash
# pipekit-journal-hook.sh — Stop-event hook that appends a journal entry
# to .pipekit/journal/<branch>.md whenever a Claude session ends.
#
# Wire up in .claude/settings.json:
#   {
#     "hooks": {
#       "Stop": [
#         { "matcher": "", "hooks": [{ "type": "command", "command": "${PROJECT_ROOT}/scripts/pipekit-journal-hook.sh" }] }
#       ]
#     }
#   }
#
# v2 design: the journal lives IN the branch (.pipekit/journal/<branch>.md).
# It travels with the work, dies with the branch on `pk done`, and shows up
# in PR diffs as extra context.
#
# This hook is best-effort — failures log to stderr but never block the
# session from ending.

set -uo pipefail

# Find repo root (this script may be invoked from anywhere)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$REPO_ROOT" ]; then
  exit 0  # Not in a repo; nothing to do
fi

# Read journal-in-repo config (default: true)
JOURNAL_IN_REPO=true
CONFIG_PATH="$REPO_ROOT/method.config.md"
if [ -f "$CONFIG_PATH" ]; then
  cfg_value=$(grep -E '^\| \*\*Journal in repo\*\*' "$CONFIG_PATH" 2>/dev/null \
    | head -1 | awk -F'|' '{print $3}' | sed 's/`//g; s/\*\*//g; s/^ *//; s/ *$//')
  if [ "$cfg_value" = "false" ]; then
    JOURNAL_IN_REPO=false
  fi
fi

# Determine current branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$BRANCH" ]; then
  exit 0  # Detached HEAD; nothing to do
fi

# Skip integration/production branches — journals are per-feature
case "$BRANCH" in
  dev|main|master|beta) exit 0 ;;
esac

# Determine journal path
if $JOURNAL_IN_REPO; then
  JOURNAL_DIR="$REPO_ROOT/.pipekit/journal"
else
  STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/pipekit"
  REPO_NAME=$(basename "$REPO_ROOT")
  JOURNAL_DIR="$STATE_DIR/$REPO_NAME/journal"
fi

mkdir -p "$JOURNAL_DIR" 2>/dev/null || exit 0
# Replace / in branch name with - so feature/X-Y becomes feature-X-Y.md.
# Without this, branches with slashes (feature/*, chore/*, fix/*) write to
# nested subdirs that don't exist, causing silent journal-write failures.
BRANCH_SAFE="${BRANCH//\//-}"
JOURNAL_FILE="$JOURNAL_DIR/${BRANCH_SAFE}.md"

# Initialize journal if it doesn't exist
if [ ! -f "$JOURNAL_FILE" ]; then
  cat > "$JOURNAL_FILE" <<EOF
# Journal — $BRANCH

EOF
fi

# Read hook input from stdin (Claude Code Stop hook passes JSON)
HOOK_INPUT=$(cat 2>/dev/null || echo "{}")

# Capture session metadata
TIMESTAMP=$(date -Iseconds)
LATEST_COMMITS=$(git log -5 --oneline --no-decorate 2>/dev/null | head -5 || echo "")
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Append entry
cat >> "$JOURNAL_FILE" <<EOF

---

**$TIMESTAMP**

Recent commits:
\`\`\`
$LATEST_COMMITS
\`\`\`

Uncommitted: $DIRTY file(s) dirty.
EOF

# If hook input has a "session_id" or transcript, capture it (best-effort)
SESSION_ID=$(echo "$HOOK_INPUT" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)
if [ -n "$SESSION_ID" ]; then
  echo "" >> "$JOURNAL_FILE"
  echo "Session: \`$SESSION_ID\`" >> "$JOURNAL_FILE"
fi

# Done. Don't print to stdout (would interfere with hook protocol).
exit 0
