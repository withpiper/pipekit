#!/usr/bin/env bash
# test-pk-v2.4.3.sh — fixture-based tests for the v2.4.3 additions:
#   #1   pk done UAT-state code refusal (--confirmed opt-out)
#   #2   pk promote UAT-state code refusal (--confirmed opt-out)
#   #3a  pk install --force re-links valid symlinks (was silent no-op)
#
# Network-dependent paths (real Linear lookups) are exercised by stubbing
# pk_linear_get_state so the harness doesn't need LINEAR_API_KEY.
#
# Run: bash scripts/test-pk-v2.4.3.sh   (exit 0 on pass, 1 on first failure)

set -uo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)

fail=0
pass=0

ok()   { pass=$((pass + 1)); printf '  ok  %s\n' "$1"; }
nope() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    ok "$name"
  else
    nope "$name" "expected: $(printf %q "$expected") got: $(printf %q "$actual")"
  fi
}

# ─── Finding 3a: pk install --force re-links a valid symlink ────────────────
echo "pk install --force: re-links a valid symlink (was silent no-op pre-v2.4.3)"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

# Two parallel "bin/pk" sources — content-identical (since we only test the
# symlink re-link semantics, not source-of-truth resolution).
mkdir -p "$stage/projA/bin" "$stage/projB/bin" "$stage/install"
cp "$repo_root/bin/pk" "$stage/projA/bin/pk"
cp "$repo_root/bin/pk" "$stage/projB/bin/pk"
chmod +x "$stage/projA/bin/pk" "$stage/projB/bin/pk"

# Pre-install: ~/.local/bin/pk → projA/bin/pk
ln -s "$stage/projA/bin/pk" "$stage/install/pk"

# Sanity: existing symlink resolves to projA
existing_target=$(readlink "$stage/install/pk")
assert_eq "pre-state: install symlink points at projA" "$stage/projA/bin/pk" "$existing_target"

# Run pk install --force with HOME=$stage so target_dir is $stage/.local/bin.
# This validates the --force path no longer short-circuits on "Already installed".
# We invoke projA's bin/pk so $src resolves to projA — same as $existing_target.
# Without the v2.4.3 fix this prints "Already installed" and returns 0 without
# touching the symlink. With the fix, --force re-links (rm -f + ln -s), and
# prints "Re-linked".
mkdir -p "$stage/home/.local/bin"
ln -sf "$stage/projA/bin/pk" "$stage/home/.local/bin/pk"
pre_inode=$(ls -i "$stage/home/.local/bin/pk" | awk '{print $1}')

# Invoke install --force via the projA copy. Use HOME override to point at our
# staged install dir; /usr/local/bin/ on the real machine isn't writable in the
# common case, so install will fall back to $HOME/.local/bin. We inherit the
# caller's PATH so the dispatcher's jq/gh preconditions resolve.
out=$(HOME="$stage/home" bash "$stage/projA/bin/pk" install --force 2>&1) || true
if echo "$out" | grep -qiE 're-linked|installed'; then
  ok "pk install --force emits a re-link/install message (not silent)"
else
  nope "pk install --force should report what it did" "got: $out"
fi
if echo "$out" | grep -q "Already installed"; then
  # Strictly speaking the v2.4.3 fix replaces "Already installed" with
  # "Re-linked" when --force is set. If we still see "Already installed"
  # under --force, the early-return bug is back.
  nope "pk install --force should not short-circuit with 'Already installed'" "got: $out"
fi

post_inode=$(ls -i "$stage/home/.local/bin/pk" | awk '{print $1}')
# After rm -f + ln -s, the inode of the new symlink differs from the old one.
# (Symlink itself is a new filesystem object even if it points at the same target.)
if [ "$pre_inode" != "$post_inode" ]; then
  ok "pk install --force creates a fresh symlink inode (rm -f + ln -s ran)"
else
  nope "pk install --force did not replace the symlink (inode unchanged)" "pre=$pre_inode post=$post_inode"
fi

# ─── Findings 1 + 2: pk_linear_get_state helper presence ────────────────────
echo ""
echo "pk_linear_get_state: helper defined and callable"
# shellcheck disable=SC1091
source "$repo_root/bin/pk"
if declare -F pk_linear_get_state >/dev/null; then
  ok "pk_linear_get_state is defined"
else
  nope "pk_linear_get_state should be defined"
fi

# ─── Finding 1: cmd_done --confirmed arg parsing ────────────────────────────
echo ""
echo "cmd_done: --confirmed arg parses without erroring"
# We can't run cmd_done end-to-end without a real Linear issue + git branch.
# What we CAN test cheaply: the arg parser. Run cmd_done with an obviously
# fake ID and --confirmed; it should reach the "no local feature branch
# found" exit (return 1), NOT the "unknown arg" exit (return 2). That
# differentiates "flag parsed" from "flag rejected".
set +e
(
  cd "$stage"
  git init -q .
  out=$(cmd_done FAKE-99999 --confirmed 2>&1)
  echo "$out" >&2
  echo "exit=$?" >&2
) 2>"$stage/cmd_done.err"
err_body=$(cat "$stage/cmd_done.err")
set -e
if echo "$err_body" | grep -q "unknown arg"; then
  nope "cmd_done --confirmed flag was rejected as unknown arg" "$err_body"
else
  ok "cmd_done --confirmed flag accepted by arg parser"
fi
if echo "$err_body" | grep -qE "no local feature branch found|not in a git repo"; then
  ok "cmd_done with fake ID reaches the expected refusal path"
else
  nope "cmd_done with fake ID should refuse on missing branch" "$err_body"
fi

# ─── Finding 2: cmd_promote --confirmed arg parsing ─────────────────────────
echo ""
echo "cmd_promote: --confirmed arg parses without erroring"
set +e
(
  cd "$stage"
  out=$(cmd_promote --confirmed beta 2>&1)
  echo "$out" >&2
  echo "exit=$?" >&2
) 2>"$stage/cmd_promote.err"
prom_body=$(cat "$stage/cmd_promote.err")
set -e
if echo "$prom_body" | grep -q "unknown arg"; then
  nope "cmd_promote --confirmed flag was rejected as unknown arg" "$prom_body"
else
  ok "cmd_promote --confirmed flag accepted by arg parser"
fi

# ─── Finding 1: cmd_done UAT-state refusal — REMOVED in v2.5.0 ──────────────
# v2.5.0 dropped this refusal: pk done IS the transition out of UAT (it
# verifies merge then flips state UAT → In <FirstEnv>). The PR-merge check
# is now the load-bearing gate (was: PR-merge AND UAT-refusal). This block
# verifies the v2.5.0 behavior: cmd_done with state==UAT proceeds past the
# old gate and lands on the PR-merge check (which fails in this fixture
# because no real PR exists).
echo ""
echo "cmd_done (v2.5.0): UAT no longer refuses; proceeds to PR-merge check"
(
  cd "$stage"
  git init -q test-uat 2>/dev/null
  cd test-uat
  git config user.email test@local
  git config user.name test
  git commit --allow-empty -q -m "init"
  git branch feature/FAKE-99999-uat-test 2>/dev/null

  # Source pk into this subshell, then stub the helper.
  # shellcheck disable=SC1091
  source "$repo_root/bin/pk"
  pk_linear_get_state() { echo "UAT"; }

  # cmd_done with state==UAT (no --confirmed needed): should NOT refuse on
  # UAT; should fall through to the PR-merge check, which fails in this
  # fixture (no real PR open for FAKE-99999).
  out=$(cmd_done FAKE-99999 2>&1) || true
  if echo "$out" | grep -q "still in 'UAT'"; then
    echo "BAD_REFUSE: $out"
  elif echo "$out" | grep -q "is not merged"; then
    echo "OK_NO_REFUSE_THEN_MERGE_CHECK"
  else
    echo "UNEXPECTED: $out"
  fi

  # --confirmed should be accepted as a no-op for backward compat (v2.5.0):
  out_confirm=$(cmd_done FAKE-99999 --confirmed 2>&1) || true
  if echo "$out_confirm" | grep -q "unknown arg"; then
    echo "BAD_CONFIRMED_REJECTED: $out_confirm"
  else
    echo "OK_CONFIRMED_ACCEPTED"
  fi
) > "$stage/uat-test.out" 2>&1
uat_out=$(cat "$stage/uat-test.out")
if echo "$uat_out" | grep -q "OK_NO_REFUSE_THEN_MERGE_CHECK"; then
  ok "cmd_done (v2.5.0): state==UAT no longer refuses; lands on PR-merge check"
else
  nope "cmd_done (v2.5.0): expected no UAT refusal + PR-merge check error" "$uat_out"
fi
if echo "$uat_out" | grep -q "OK_CONFIRMED_ACCEPTED"; then
  ok "cmd_done (v2.5.0): --confirmed accepted as no-op (backward compat)"
else
  nope "cmd_done (v2.5.0): --confirmed should be accepted, not rejected" "$uat_out"
fi

echo ""
if [ "$fail" -eq 0 ]; then
  printf '✓ %d assertions passed\n' "$pass"
  exit 0
else
  printf '✗ %d failed, %d passed\n' "$fail" "$pass"
  exit 1
fi
