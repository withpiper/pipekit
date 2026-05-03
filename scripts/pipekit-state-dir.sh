#!/usr/bin/env bash
# pipekit-state-dir.sh
#
# Resolve Pipekit's per-repo machine-local state directory. Pipekit's ephemeral
# state (pipeline-state records, strategy-sync marker) lives outside the repo
# at an XDG-style cache path. Earlier Pipekit placed these in `<repo>/.pipekit/`
# but that path is inside the repo and gets blocked by VBW's file-guard hook
# when running inside an active-plan scope. The relocation to an out-of-repo
# cache dir lets writes succeed unconditionally.
#
# Path scheme:
#   ${XDG_CACHE_HOME:-$HOME/.cache}/pipekit/<repo-basename>/
#
# Usage:
#   STATE_DIR=$(bash scripts/pipekit-state-dir.sh)
#   mkdir -p "$STATE_DIR/pipeline-state"
#   echo "$payload" > "$STATE_DIR/pipeline-state/<issue-id>.json"
#
# Output: absolute path. Always succeeds; falls back to `_default` basename
# when not inside a git repo (e.g. the helper is invoked from an arbitrary cwd).
#
# Side effects: none. Does not create the directory — caller decides.

set -u

CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/pipekit"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$REPO_ROOT" ]; then
  REPO_BASE=$(basename "$REPO_ROOT")
else
  REPO_BASE="_default"
fi

echo "$CACHE_BASE/$REPO_BASE"
