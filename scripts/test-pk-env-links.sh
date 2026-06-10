#!/usr/bin/env bash
# test-pk-env-links.sh — regression test for pk_link_env_files (pk branch).
#
# Guards the worktree-env-linking contract that `pk branch` relies on:
#   - root-level env/config files are symlinked into the worktree (historical)
#   - NESTED per-app env files (monorepo apps/web/.env.local, packages/*/.env)
#     are symlinked too — the gap that left fresh worktrees reading the
#     *.example placeholder (NEXT_PUBLIC_SUPABASE_URL=your-project.supabase.co)
#     so the browser client had no backend to talk to
#   - *.example placeholders are NEVER linked (exact-name match)
#   - .env.prod is NEVER linked, root or nested (prod secrets stay out of
#     worktrees — pipekit-security.md § Secrets Managers and Worktrees)
#   - node_modules / .git / .worktrees are pruned (no dep-tree or sibling-worktree recursion)
#   - the operation is idempotent (re-run is a no-op, never errors)
#
# Exercises the REAL helper by sourcing bin/pk — not a re-implemented copy, so
# the test fails if the shipped logic drifts.
#
# Run: bash scripts/test-pk-env-links.sh   (exit 0 on pass, 1 on any failure)

set -uo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)

fail=0
pass=0
ok()   { pass=$((pass + 1)); printf '  ok  %s\n' "$1"; }
nope() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# bin/pk skips main() when sourced (BASH_SOURCE guard at its tail), so sourcing
# exposes its helpers without dispatching a subcommand. It does run
# `set -euo pipefail` at top level, which flips errexit on in this harness —
# clear it afterward so our intended `set -uo pipefail` (no -e) mode holds.
# shellcheck disable=SC1091
source "$repo_root/bin/pk"
set +e

if ! command -v pk_link_env_files >/dev/null 2>&1; then
  echo "FAIL: pk_link_env_files not defined after sourcing bin/pk" >&2
  exit 1
fi

echo "pk_link_env_files: root + nested env symlinking into a fresh worktree"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

root="$stage/repo"
wt="$root/.worktrees/RS-1-x"

# Parent repo: real (gitignored) env files, placeholders, and noise.
mkdir -p "$root/apps/web" "$root/packages/db" "$root/node_modules/pkg" "$root/.git"
printf 'NEXT_PUBLIC_SUPABASE_URL=https://real.supabase.co\n' > "$root/apps/web/.env.local"
printf 'NEXT_PUBLIC_SUPABASE_URL=your-project.supabase.co\n'  > "$root/apps/web/.env.local.example"
printf 'DB=postgres://real\n'                                 > "$root/packages/db/.env"
printf 'SHOULD_NOT_LINK=1\n'                                  > "$root/node_modules/pkg/.env"
printf 'ROOT=1\n'                                             > "$root/.env.local"
printf 'PROD_SECRET=1\n'                                      > "$root/.env.prod"
printf 'NESTED_PROD_SECRET=1\n'                               > "$root/apps/web/.env.prod"

# Fresh worktree: tracked dirs only, no gitignored env files present.
mkdir -p "$wt/apps/web" "$wt/packages/db"

link_output=$(pk_link_env_files "$root" "$wt")

# Nested real env file linked to the REAL value (the core regression).
if [ -L "$wt/apps/web/.env.local" ] && \
   [ "$(cat "$wt/apps/web/.env.local")" = "NEXT_PUBLIC_SUPABASE_URL=https://real.supabase.co" ]; then
  ok "nested apps/web/.env.local linked to real value"
else
  nope "nested apps/web/.env.local linked to real value" "got: $(readlink "$wt/apps/web/.env.local" 2>/dev/null || echo MISSING)"
fi

# Arbitrary nested depth.
[ -L "$wt/packages/db/.env" ] && ok "nested packages/db/.env linked" || nope "nested packages/db/.env linked"

# *.example must never be linked.
[ ! -e "$wt/apps/web/.env.local.example" ] && ok ".example placeholder not linked" || nope ".example placeholder not linked"

# node_modules pruned.
[ ! -e "$wt/node_modules/pkg/.env" ] && ok "node_modules pruned" || nope "node_modules pruned"

# Root-level file handled by pass (1).
[ -L "$wt/.env.local" ] && ok "root .env.local linked" || nope "root .env.local linked"

# .env.prod must never be linked — root or nested.
[ ! -e "$wt/.env.prod" ] && ok "root .env.prod NOT linked" || nope "root .env.prod NOT linked"
[ ! -e "$wt/apps/web/.env.prod" ] && ok "nested apps/web/.env.prod NOT linked" || nope "nested apps/web/.env.prod NOT linked"

# Linking is announced (visibility — plaintext propagation must not be silent).
case "$link_output" in
  *"Linked from parent"*) ok "linked files announced on stdout" ;;
  *) nope "linked files announced on stdout" "got: $link_output" ;;
esac
case "$link_output" in
  *"Skipped"*".env.prod"*) ok ".env.prod skip announced on stdout" ;;
  *) nope ".env.prod skip announced on stdout" "got: $link_output" ;;
esac

# Idempotency: a second run must not error and must not change anything.
before=$(cd "$wt" && find . -name '.env*' | sort)
if pk_link_env_files "$root" "$wt" >/dev/null 2>&1; then
  after=$(cd "$wt" && find . -name '.env*' | sort)
  [ "$before" = "$after" ] && ok "idempotent re-run (no change, no error)" || nope "idempotent re-run" "set changed"
else
  nope "idempotent re-run" "second invocation returned nonzero"
fi

# Does NOT clobber a real file already present in the worktree, even when the
# parent holds a (different) file at the same relative path.
mkdir -p "$wt/apps/api" "$root/apps/api"
printf 'PREEXISTING=1\n' > "$wt/apps/api/.env.local"
printf 'PARENT=1\n'      > "$root/apps/api/.env.local"
pk_link_env_files "$root" "$wt" >/dev/null
if [ ! -L "$wt/apps/api/.env.local" ] && [ "$(cat "$wt/apps/api/.env.local")" = "PREEXISTING=1" ]; then
  ok "pre-existing worktree env file not clobbered"
else
  nope "pre-existing worktree env file not clobbered" "got: $(cat "$wt/apps/api/.env.local" 2>/dev/null)"
fi

echo ""
printf 'passed: %d   failed: %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
