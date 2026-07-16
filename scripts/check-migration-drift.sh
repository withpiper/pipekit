#!/usr/bin/env bash
# check-migration-drift.sh — detect migration-history drift before it blocks a deploy.
#
# Tier 2 of gap #1 (migration safety). Tier 1 (the artifact rule, sop/Database_SOP.md)
# constrains how a migration is born; this script catches the drift classes that
# survive it — each anchored to a real incident:
#
#   A. Parallel-branch timestamp collision (Piper WIT-550, 2026-06-02): a long-lived
#      branch's new migration is not strictly later than the base branch's migration
#      tail. Invisible in the worktree — passes local validation and /verify, because
#      both only see your branch's tree — then collides on merge.
#   B. Duplicate or malformed version prefixes on disk (two branches picked the same
#      timestamp; a hand-named file the tool will mis-order).
#   C. (--remote, best-effort) Disk vs remote history — the class behind the MCP
#      wall-clock-stamp incident (Piper, 2026-05-27: ~5h deploy lockup from "Remote
#      migration versions not found in local migrations directory"). Delegates to
#      `supabase db push --dry-run`, which refuses loudly on exactly this drift.
#      Requires the supabase CLI + a linked project; skipped with a note otherwise.
#
# Usage:
#   scripts/check-migration-drift.sh                     # base = origin/<Integration branch>
#   scripts/check-migration-drift.sh --base origin/dev   # explicit base (CI: the PR base ref)
#   scripts/check-migration-drift.sh --remote            # add the remote-history check (C)
#   scripts/check-migration-drift.sh --dir db/migrations # override the migration dir
#
# Config (method.config.md, read via `pk config` when available):
#   Migration dir       — no value / missing dir → exit 0 skip (non-migration project)
#   Integration branch  — default base for check A (default: dev, else origin/HEAD)
#
# Exit codes: 0 = clean or skipped; 1 = drift found; 2 = usage / not a git repo

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "ERROR: not in a git repo" >&2
  exit 2
}
cd "$REPO_ROOT"

read_config() {
  local key="$1" default="$2" v=""
  if command -v pk >/dev/null 2>&1 && [ -f method.config.md ]; then
    v=$(pk config "$key" "" 2>/dev/null || true)
  fi
  if [ -z "$v" ] && [ -f method.config.md ]; then
    # Table row: | **Key** | value | …   — or colon form: Key: value
    v=$(grep -E "^\| \*\*${key}\*\* \|" method.config.md 2>/dev/null \
        | head -1 | awk -F'|' '{print $3}' | sed 's/[` ]//g' || true)
    [ -z "$v" ] && v=$(grep -E "^${key}:" method.config.md 2>/dev/null \
        | head -1 | cut -d: -f2- | sed 's/^ *//; s/ *$//' || true)
  fi
  echo "${v:-$default}"
}

BASE="" REMOTE=false DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base)   BASE="$2"; shift 2 ;;
    --base=*) BASE="${1#--base=}"; shift ;;
    --remote) REMOTE=true; shift ;;
    --dir)    DIR="$2"; shift 2 ;;
    --dir=*)  DIR="${1#--dir=}"; shift ;;
    *) echo "usage: $0 [--base <ref>] [--dir <migration-dir>] [--remote]" >&2; exit 2 ;;
  esac
done

# --- Resolve migration dir (the opt-in: no dir configured → clean skip) ----
[ -z "$DIR" ] && DIR=$(read_config "Migration dir" "")
DIR="${DIR%/}"
if [ -z "$DIR" ]; then
  echo "  ⓘ check-migration-drift: no 'Migration dir' configured — skipping (not a migration project)"
  exit 0
fi
if [ ! -d "$DIR" ]; then
  echo "  ⚠ check-migration-drift: 'Migration dir' is '$DIR' but the directory doesn't exist — skipping"
  exit 0
fi

# Version prefix = leading digits of the basename (>=4 digits to count as
# versioned; Supabase uses 14, Rails 14, Knex/others vary but stay numeric).
version_of() { basename "$1" | grep -oE '^[0-9]{4,}' || true; }

DRIFT=0

# --- Check B: on-disk duplicates + malformed names --------------------------
declare -a DISK_FILES=() DISK_VERSIONS=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  DISK_FILES+=("$f")
  v=$(version_of "$f")
  if [ -z "$v" ]; then
    echo "  ⚠ unversioned file in $DIR: $(basename "$f") (no leading timestamp — the tool may mis-order it)"
  else
    DISK_VERSIONS+=("$v")
  fi
done < <(find "$DIR" -maxdepth 1 -type f \( -name '*.sql' -o -name '*.rb' -o -name '*.js' -o -name '*.ts' -o -name '*.py' \) | sort)

if [ "${#DISK_VERSIONS[@]}" -gt 0 ]; then
  dups=$(printf '%s\n' "${DISK_VERSIONS[@]}" | sort | uniq -d)
  if [ -n "$dups" ]; then
    while IFS= read -r d; do
      echo "  ✗ duplicate migration version on disk: $d"
      find "$DIR" -maxdepth 1 -name "${d}*" -exec basename {} \; | sed 's/^/      /'
    done <<< "$dups"
    DRIFT=1
  fi
fi

# --- Check A: new-on-this-branch vs base tail (the WIT-550 class) -----------
if [ -z "$BASE" ]; then
  ib=$(read_config "Integration branch" "dev")
  if git rev-parse --verify -q "origin/$ib" >/dev/null; then BASE="origin/$ib";
  elif git rev-parse --verify -q "$ib" >/dev/null; then BASE="$ib";
  fi
fi

if [ -z "$BASE" ] || ! git rev-parse --verify -q "$BASE" >/dev/null; then
  echo "  ⚠ base ref '${BASE:-<none>}' not resolvable — skipping the branch-collision check (fetch the base branch, or pass --base)"
else
  MB=$(git merge-base HEAD "$BASE" 2>/dev/null || true)
  if [ -n "$MB" ]; then
    # The base tail: the highest version the base branch already carries.
    base_tail=""
    while IFS= read -r bf; do
      bv=$(version_of "$bf")
      [ -n "$bv" ] && [ "$((10#$bv))" -gt "$((10#${base_tail:-0}))" ] && base_tail="$bv"
    done < <(git ls-tree -r --name-only "$BASE" -- "$DIR" 2>/dev/null)

    if [ -n "$base_tail" ]; then
      while IFS= read -r nf; do
        [ -n "$nf" ] || continue
        nv=$(version_of "$nf")
        [ -n "$nv" ] || continue
        if [ "$((10#$nv))" -le "$((10#$base_tail))" ]; then
          echo "  ✗ branch collision: $(basename "$nf") (version $nv) is not strictly later than the $BASE migration tail ($base_tail)."
          echo "      A migration landed on the base branch after you picked your timestamp."
          echo "      Rename it NOW — pre-merge is still before the freeze on the base DB"
          echo "      (pipekit-migrations.md § Parallel Branch Coordination, anchor: WIT-550)."
          DRIFT=1
        fi
      done < <(git diff --name-only --diff-filter=A "$MB..HEAD" -- "$DIR" 2>/dev/null)
    fi
  fi
fi

# --- Check C (--remote): disk vs remote history, via the tool itself --------
if $REMOTE; then
  if command -v supabase >/dev/null 2>&1 && [ -d supabase ]; then
    echo "  → remote-history check (supabase db push --dry-run)…"
    if out=$(supabase db push --dry-run 2>&1); then
      echo "  ✓ remote history consistent with disk"
    else
      echo "  ✗ remote-history drift (this is what blocks the next deploy):"
      echo "$out" | tail -12 | sed 's/^/      /'
      echo "      Recovery: supabase migration repair (human-confirmed — shared-state mutation;"
      echo "      see pipekit-migrations.md § MCP-applied migrations and disk drift)."
      DRIFT=1
    fi
  else
    echo "  ⓘ remote check skipped (supabase CLI not found or no supabase/ dir) — checks A+B still ran"
  fi
fi

if [ "$DRIFT" -eq 0 ]; then
  echo "  ✓ no migration drift ($DIR: ${#DISK_VERSIONS[@]} versioned files)"
fi
exit "$DRIFT"
