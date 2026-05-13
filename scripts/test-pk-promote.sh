#!/usr/bin/env bash
# test-pk-promote.sh — fixture-based tests for pk_state_rank and the
# missing-target-branch guard in cmd_promote.
#
# Covers regressions from the Gate 3 canary (Pipekit v2.3.3 handoff):
#   #25  pk promote exits 128 silently when origin/<target> is missing
#   #28  pk promote force-transitions Linear issues regardless of current state
#
# Run: bash scripts/test-pk-promote.sh   (exit 0 on pass, 1 on first failure)

set -uo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
source "$repo_root/bin/pk"

fail=0
pass=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    pass=$((pass + 1))
    printf '  ok  %s\n' "$name"
  else
    fail=$((fail + 1))
    printf '  FAIL %s\n       expected: %q\n       got:      %q\n' "$name" "$expected" "$actual"
  fi
}

assert_lt() {
  local name="$1" small="$2" big="$3"
  if [ "$small" -lt "$big" ]; then
    pass=$((pass + 1))
    printf '  ok  %s (%d < %d)\n' "$name" "$small" "$big"
  else
    fail=$((fail + 1))
    printf '  FAIL %s\n       expected: %d < %d\n' "$name" "$small" "$big"
  fi
}

# ─── pk_state_rank: canonical ladder ordering ───────────────────────────────
echo "pk_state_rank: canonical ladder is strictly monotonic"
prev=$(pk_state_rank "Triage")
for state in "Ideas" "Future Phases" "On Deck" "Needs Spec" "Specced" "Approved" "Building" "In Progress" "UAT" "Released" "Done"; do
  cur=$(pk_state_rank "$state")
  assert_lt "$state ranks above previous" "$prev" "$cur"
  prev=$cur
done

# ─── pk_state_rank: pairwise checks that matter for the gate ────────────────
echo "pk_state_rank: gate-relevant pairs"
assert_lt "Approved < Released" "$(pk_state_rank Approved)" "$(pk_state_rank Released)"
assert_lt "UAT < Released"      "$(pk_state_rank UAT)"      "$(pk_state_rank Released)"
assert_lt "Released < Done"     "$(pk_state_rank Released)" "$(pk_state_rank Done)"
assert_lt "On Deck < Approved"  "$(pk_state_rank "On Deck")" "$(pk_state_rank Approved)"

# Done must NOT rank below Released (no backward promote main → beta).
done_rank=$(pk_state_rank Done)
released_rank=$(pk_state_rank Released)
if [ "$done_rank" -gt "$released_rank" ]; then
  pass=$((pass + 1))
  printf '  ok  Done > Released (rejects backward Done→Released)\n'
else
  fail=$((fail + 1))
  printf '  FAIL Done > Released\n       Done=%d Released=%d\n' "$done_rank" "$released_rank"
fi

# ─── pk_state_rank: unknown + terminal-off-ladder ───────────────────────────
echo "pk_state_rank: unknown and terminal-off-ladder states"
assert_eq "Unknown state → 0 (allow transition for custom workflows)" "0" "$(pk_state_rank 'In Review')"
assert_eq "Empty state → 0"                                            "0" "$(pk_state_rank '')"
canceled_rank=$(pk_state_rank Canceled)
if [ "$canceled_rank" -gt "$done_rank" ]; then
  pass=$((pass + 1))
  printf '  ok  Canceled outranks Done (never promotes forward)\n'
else
  fail=$((fail + 1))
  printf '  FAIL Canceled > Done\n       Canceled=%d Done=%d\n' "$canceled_rank" "$done_rank"
fi

# ─── Missing-target-branch guard ────────────────────────────────────────────
# Build a temp bare "origin" with only `dev` present, then assert that
# git ls-remote --exit-code origin refs/heads/beta returns non-zero.
echo "missing-target-branch guard: git ls-remote semantics"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
(
  cd "$tmp"
  git init -q --bare origin.git
  git init -q work
  cd work
  git config user.email test@local
  git config user.name test
  git commit --allow-empty -q -m "init"
  git branch -M dev
  git remote add origin "$tmp/origin.git"
  git push -q origin dev
)
cd "$tmp/work"

# beta does not exist on origin → exit non-zero
if git ls-remote --exit-code origin refs/heads/beta >/dev/null 2>&1; then
  fail=$((fail + 1))
  printf '  FAIL ls-remote should have refused missing beta\n'
else
  pass=$((pass + 1))
  printf '  ok  ls-remote --exit-code refuses missing origin/beta\n'
fi

# dev exists on origin → exit 0
if git ls-remote --exit-code origin refs/heads/dev >/dev/null 2>&1; then
  pass=$((pass + 1))
  printf '  ok  ls-remote --exit-code accepts existing origin/dev\n'
else
  fail=$((fail + 1))
  printf '  FAIL ls-remote should have accepted existing dev\n'
fi
cd "$repo_root"

# ─── owner/repo extraction (used in the recovery-command message) ───────────
echo "owner/repo extraction from origin URL"
extract_owner_repo() {
  echo "$1" | sed -E 's#\.git$##' | sed -E 's#^.*github\.com[:/]##'
}
assert_eq "https URL"        "withpiper/piper" "$(extract_owner_repo 'https://github.com/withpiper/piper.git')"
assert_eq "https no .git"    "withpiper/piper" "$(extract_owner_repo 'https://github.com/withpiper/piper')"
assert_eq "ssh URL"          "withpiper/piper" "$(extract_owner_repo 'git@github.com:withpiper/piper.git')"
assert_eq "ssh no .git"      "withpiper/piper" "$(extract_owner_repo 'git@github.com:withpiper/piper')"

echo ""
if [ "$fail" -eq 0 ]; then
  printf '✓ %d assertions passed\n' "$pass"
  exit 0
else
  printf '✗ %d failed, %d passed\n' "$fail" "$pass"
  exit 1
fi
