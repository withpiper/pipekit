#!/usr/bin/env bash
# Sourced helper: resolves the package root from this file's own location, never
# from cwd or `show-toplevel`, so a script behaves the same whether the package
# sits at the repository root or under a subdirectory such as apps/legacy/.
#   PKG_ROOT   absolute, symlink-resolved package root
#   GIT_PREFIX package path inside the repository ('' at the root, 'apps/legacy/' nested)
# PKG_ROOT_PRINT=1 prints both and exits 99, so any script sourcing this is probe-able.
# Exit 99, never 0: several sourcing scripts are CI gates, and a leaked variable
# must turn them red, not green.
PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
# GIT_DIR / GIT_WORK_TREE are unset for the lookup: git hooks export them to their
# children, and with them set `git -C` reports the hook's work tree, not the
# package's (prefix "" while nested, so every layout decision would flip).
# Exit 3, never 0 or 2: check-schema-dump.sh maps 2 to "could not check", which
# its CI workflow renders green; a lib failure must never read as a pass.
# Unset for the whole script, not only this lookup: every later git call (diff
# --relative, ls-tree, archive) would otherwise answer for the hook's tree too.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
GIT_PREFIX="$(git -C "$PKG_ROOT" rev-parse --show-prefix 2>/dev/null)" || {
    echo "ERROR: not in a git repo ($PKG_ROOT is not inside a git work tree)" >&2
    exit 3
}
export PKG_ROOT GIT_PREFIX
if [ "${PKG_ROOT_PRINT:-}" = "1" ]; then
    printf 'root=%s\nprefix=%s\n' "$PKG_ROOT" "$GIT_PREFIX"
    exit 99
fi
