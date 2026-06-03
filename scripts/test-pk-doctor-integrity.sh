#!/usr/bin/env bash
# test-pk-doctor-integrity.sh — regression test for pk_git_build_evidence,
# the git-side of `pk doctor`'s Linear↔git false-ship cross-check.
#
# Verdict contract (echoes one word):
#   built     — >=1 commit references the id AND touches a non-doc file
#   docs-only — commits reference the id but ALL changed files are docs
#               (*.md, Logs/, docs/, Strategy/, CHANGELOG) → likely false-ship
#   none      — no commit reachable from <ref> references the id → likely false-ship
#
# Exercises the REAL helper by sourcing bin/pk — not a re-implemented copy.
# Linear is NOT involved here (the helper is pure git); the doctor section that
# calls it is gated on a live Linear ping, covered by manual/integration runs.
#
# Run: bash scripts/test-pk-doctor-integrity.sh   (exit 0 on pass, 1 on failure)

set -uo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)

fail=0
pass=0
ok()   { pass=$((pass + 1)); printf '  ok  %s\n' "$1"; }
nope() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

# bin/pk skips main() when sourced (BASH_SOURCE guard); it runs `set -euo
# pipefail` at top level, so clear errexit afterward for this harness.
# shellcheck disable=SC1091
source "$repo_root/bin/pk"
set +e

if ! command -v pk_git_build_evidence >/dev/null 2>&1; then
  echo "FAIL: pk_git_build_evidence not defined after sourcing bin/pk" >&2
  exit 1
fi

echo "pk_git_build_evidence: built / docs-only / none classification"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

# Build a throwaway repo with commits referencing assorted WIT ids.
(
  cd "$stage"
  git init -q
  git config user.email t@t.test
  git config user.name tester
  git config commit.gpgsign false

  mkdir -p src docs supabase/migrations Logs/Sessions

  # WIT-100: real implementation (non-doc file) — expect built
  echo "export const x = 1" > src/feature.ts
  git add -A && git commit -q -m "feat(x): implement thing for WIT-100"

  # WIT-200: docs only — expect docs-only
  echo "# notes" > docs/wit200.md
  echo "- entry" >> Logs/Sessions/2026-06-03_1000.md
  git add -A && git commit -q -m "docs(x): notes for WIT-200"

  # WIT-300: never referenced — expect none (no commit mentions it)
  echo "export const y = 2" > src/other.ts
  git add -A && git commit -q -m "feat(x): unrelated work"

  # WIT-497 / WIT-49 boundary: WIT-497 is docs-only; ensure WIT-49 (absent)
  # does NOT borrow WIT-497's commit via substring match.
  echo "# false ship notes" > docs/wit497.md
  git add -A && git commit -q -m "docs(x): close-out notes for WIT-497"
)

ref=$(cd "$stage" && git rev-parse --abbrev-ref HEAD)
run() { ( cd "$stage" && pk_git_build_evidence "$1" "$ref" ); }

assert() { local name="$1" exp="$2" got="$3"; [ "$exp" = "$got" ] && ok "$name ($got)" || nope "$name" "expected $exp, got $got"; }

assert "WIT-100 has implementation"        "built"     "$(run WIT-100)"
assert "WIT-200 docs-only flagged"          "docs-only" "$(run WIT-200)"
assert "WIT-300 absent → none"              "none"      "$(run WIT-300)"
assert "WIT-497 docs-only flagged"          "docs-only" "$(run WIT-497)"
assert "WIT-49 absent (no substring steal)" "none"      "$(run WIT-49)"

# Default ref (HEAD) path works without an explicit ref arg.
got_default=$( cd "$stage" && pk_git_build_evidence "WIT-100" )
assert "default ref resolves to HEAD"       "built"     "$got_default"

echo ""
printf 'passed: %d   failed: %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
