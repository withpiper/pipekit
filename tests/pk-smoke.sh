#!/usr/bin/env bash
# Smoke suite for bin/pk — zero dependencies beyond bash 3.2+, git, jq.
#
# Scope: the bug classes consumers actually hit, not full coverage.
# Each CLI test runs pk inside a throwaway git repo with a `gh` shim on
# PATH that logs every invocation — so a test can assert pk did NOT reach
# for GitHub (the `pk ship --help` regression class).
#
# Run: ./tests/pk-smoke.sh        (from the repo root or anywhere)
# CI:  .github/workflows/pk-smoke.yml

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PK="$REPO_ROOT/bin/pk"

PASS=0
FAIL=0
FAILED_NAMES=""

ok()   { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); FAILED_NAMES="$FAILED_NAMES $1"; printf '  FAIL  %s\n        %s\n' "$1" "$2"; }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed (pk requires it)"; exit 0; }

# ── Fixture ──────────────────────────────────────────────────────────────────

FIXTURE=""
GH_LOG=""

make_fixture() {
  FIXTURE=$(mktemp -d)
  GH_LOG="$FIXTURE/.gh-invocations.log"
  : > "$GH_LOG"

  # gh shim: satisfies pk's `command -v gh` preflight and records every call.
  mkdir -p "$FIXTURE/shim"
  cat > "$FIXTURE/shim/gh" <<EOF
#!/usr/bin/env bash
echo "gh \$*" >> "$GH_LOG"
exit 0
EOF
  chmod +x "$FIXTURE/shim/gh"

  git -C "$FIXTURE" init -q -b main
  git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

write_config() {
  # $1 = full method.config.md content
  printf '%s\n' "$1" > "$FIXTURE/method.config.md"
}

# Run pk in the fixture with the gh shim. Captures stdout+stderr and exit code.
RUN_OUT=""
RUN_CODE=0
run_pk() {
  RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" "$PK" "$@" 2>&1)
  RUN_CODE=$?
}

cleanup() { [ -n "$FIXTURE" ] && rm -rf "$FIXTURE"; }
trap cleanup EXIT

# ── Unit tests: pk_config (sourced mode) ─────────────────────────────────────
# bin/pk skips main() when sourced, exposing helpers directly.

echo "== pk_config parsing =="

make_fixture
write_config '# Config

```
Backend: native
Ship environments: dev,beta,main
Quoted key: `backticked`
```
'
unit_config() {
  # Runs in a subshell so sourcing pk never leaks into the harness.
  ( cd "$FIXTURE" && source "$PK" && pk_config "$@" )
}

v=$(unit_config "Backend" "")
[ "$v" = "native" ] && ok "config: code-block form" || fail "config: code-block form" "got '$v', want 'native'"

v=$(unit_config "Quoted key" "")
[ "$v" = "backticked" ] && ok "config: backticks stripped" || fail "config: backticks stripped" "got '$v'"

v=$(unit_config "Nonexistent" "fallback")
[ "$v" = "fallback" ] && ok "config: default fallback" || fail "config: default fallback" "got '$v'"

write_config '# Config

| Key | Value | Notes |
|-----|-------|-------|
| **Backend** | `vbw` | legacy table form |
'
v=$(unit_config "Backend" "")
[ "$v" = "vbw" ] && ok "config: legacy table form" || fail "config: legacy table form" "got '$v', want 'vbw'"

write_config '# Config

| **Backend** | `vbw` | table says vbw |

```
Backend: native
```
'
v=$(unit_config "Backend" "")
[ "$v" = "native" ] && ok "config: code-block wins over table" || fail "config: code-block wins over table" "got '$v', want 'native'"

cleanup

# ── CLI tests: dispatch + help guard ─────────────────────────────────────────

echo "== dispatch =="

make_fixture
write_config '```
Backend: native
Integration branch: main
Ship environments: dev,beta,main
Promote to main: true
```'

run_pk version
case "$RUN_OUT" in
  "pk "[0-9]*) ok "version prints pk + semver" ;;
  *) fail "version prints pk + semver" "got '$RUN_OUT'" ;;
esac

run_pk help
[ $RUN_CODE -eq 0 ] && ok "help exits 0" || fail "help exits 0" "exit $RUN_CODE"

run_pk frobnicate
[ $RUN_CODE -ne 0 ] && ok "unknown subcommand exits non-zero" || fail "unknown subcommand exits non-zero" "exit 0"

# Regression: `pk ship --help` once parsed --help as a ship arg and ran the
# ship (SiteLine, 2026-06-04). Any subcommand + -h/--help must print usage,
# exit 0, and never touch gh.
echo "== --help guard (regression: SiteLine 2026-06-04) =="

for sub in ship done promote branch next ready status; do
  : > "$GH_LOG"
  run_pk "$sub" --help
  if [ $RUN_CODE -ne 0 ]; then
    fail "pk $sub --help exits 0" "exit $RUN_CODE"
    continue
  fi
  case "$RUN_OUT" in
    *Subcommands:*) : ;;
    *) fail "pk $sub --help prints usage" "output: $(echo "$RUN_OUT" | head -2)"; continue ;;
  esac
  if [ -s "$GH_LOG" ]; then
    fail "pk $sub --help never calls gh" "gh log: $(cat "$GH_LOG")"
    continue
  fi
  ok "pk $sub --help: usage, exit 0, no gh"
done

# ── CLI tests: promote derivation / guard rails ──────────────────────────────

echo "== promote guard rails =="

# No arg on a 3+ env chain now AUTO-PICKS the next ready hop instead of refusing.
# This fixture has no origin remote, so no hop has unpromoted commits → no-op
# (exit 0, "Nothing to promote"). The positive auto-pick path is exercised in the
# bare-remote section below.
run_pk promote
[ $RUN_CODE -eq 0 ] && case "$RUN_OUT" in *"Nothing to promote"*) ok "promote: no-arg multi-hop auto-picks (level chain → no-op)" ;; *) fail "promote: no-arg multi-hop auto-picks (level chain → no-op)" "output: $RUN_OUT" ;; esac \
  || fail "promote: no-arg multi-hop auto-picks (level chain → no-op)" "exit $RUN_CODE, want 0"

run_pk promote prod
[ $RUN_CODE -eq 2 ] && case "$RUN_OUT" in *"not a valid promote target"*) ok "promote: invalid target rejected" ;; *) fail "promote: invalid target rejected" "output: $RUN_OUT" ;; esac \
  || fail "promote: invalid target rejected" "exit $RUN_CODE, want 2"

run_pk promote dev
[ $RUN_CODE -eq 2 ] && ok "promote: source env not a valid target" || fail "promote: source env not a valid target" "exit $RUN_CODE, want 2"

run_pk promote --bogus-flag
[ $RUN_CODE -eq 2 ] && ok "promote: unknown flag rejected" || fail "promote: unknown flag rejected" "exit $RUN_CODE, want 2"

write_config '```
Promote to main: false
```'
run_pk promote
[ $RUN_CODE -eq 0 ] && case "$RUN_OUT" in *disabled*) ok "promote: single-tier no-op" ;; *) fail "promote: single-tier no-op" "output: $RUN_OUT" ;; esac \
  || fail "promote: single-tier no-op" "exit $RUN_CODE, want 0"

cleanup
FIXTURE=""

# ── Unit tests: promote frontier (sourced + bare remote) ─────────────────────
# pk_promote_next_target walks the Ship-environments chain and returns the next
# hop's target — the earliest pair where origin/<src> is ahead of origin/<tgt>.
# This is the no-arg auto-pick that replaced the old "Specify target" refusal.

echo "== promote auto-pick frontier (sourced + bare remote) =="

make_fixture                                   # repo on main, one commit
REMOTE=$(mktemp -d); git -C "$REMOTE" init -q --bare
git -C "$FIXTURE" remote add origin "$REMOTE"
git -C "$FIXTURE" branch beta
git -C "$FIXTURE" branch dev
git -C "$FIXTURE" push -q origin main beta dev 2>/dev/null
# Advance dev one commit ahead of beta/main.
git -C "$FIXTURE" checkout -q dev
git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "dev work"
git -C "$FIXTURE" push -q origin dev 2>/dev/null
git -C "$FIXTURE" checkout -q main

next_target() { ( cd "$FIXTURE" && source "$PK" && git fetch -q origin 2>/dev/null; pk_promote_next_target "$@" ); }

out=$(next_target "dev beta main"); rc=$?
[ $rc -eq 0 ] && [ "$out" = "beta" ] && ok "promote frontier: picks earliest ready hop (dev→beta)" || fail "promote frontier: picks earliest ready hop (dev→beta)" "rc=$rc out='$out'"

# Catch beta up to dev → the frontier advances to the next hop (beta→main).
git -C "$FIXTURE" push -q origin dev:beta 2>/dev/null
out=$(next_target "dev beta main"); rc=$?
[ $rc -eq 0 ] && [ "$out" = "main" ] && ok "promote frontier: advances after catch-up (beta→main)" || fail "promote frontier: advances after catch-up (beta→main)" "rc=$rc out='$out'"

# Catch main up too → fully level → nothing to promote.
git -C "$FIXTURE" push -q origin dev:main 2>/dev/null
out=$(next_target "dev beta main"); rc=$?
[ $rc -ne 0 ] && [ -z "$out" ] && ok "promote frontier: level chain → nothing" || fail "promote frontier: level chain → nothing" "rc=$rc out='$out'"

rm -rf "$REMOTE"
cleanup
FIXTURE=""

# ── CLI tests: doctor upstream-staleness check ───────────────────────────────

echo "== doctor staleness check =="

make_fixture
write_config '```
Backend: native
Integration branch: main
Ship environments: dev,beta,main
```'

# Unreachable method repo → info line, never an error (offline-safe).
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" METHOD_REPO="$FIXTURE/no-such-repo.git" "$PK" doctor 2>&1)
case "$RUN_OUT" in
  *"skipped upstream-staleness check"*) ok "doctor: unreachable method repo is soft" ;;
  *) fail "doctor: unreachable method repo is soft" "no skip line in output" ;;
esac

# Local method repo whose latest tag is ahead of PK_VERSION → staleness warning.
METHOD_FIXTURE=$(mktemp -d)
git -C "$METHOD_FIXTURE" init -q -b main
git -C "$METHOD_FIXTURE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$METHOD_FIXTURE" tag v99.0.0
git -C "$METHOD_FIXTURE" tag v99.1.0-rc1   # rc tags must not count as "latest"
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" METHOD_REPO="$METHOD_FIXTURE" "$PK" doctor 2>&1)
case "$RUN_OUT" in
  *"latest release is v99.0.0"*) ok "doctor: warns when behind latest release (rc tags ignored)" ;;
  *) fail "doctor: warns when behind latest release (rc tags ignored)" "$(echo "$RUN_OUT" | grep -i 'pipekit v\|latest' | head -2)" ;;
esac
rm -rf "$METHOD_FIXTURE"

# ── CLI tests: ship guard rails ──────────────────────────────────────────────

echo "== ship guard rails =="

write_config '```
Backend: native
Integration branch: main
```'

# On main (not a feature branch) ship must refuse before touching anything.
: > "$GH_LOG"
run_pk ship
if [ $RUN_CODE -ne 0 ] && [ ! -s "$GH_LOG" ]; then
  case "$RUN_OUT" in
    *"not on a feature branch"*) ok "ship: refuses off feature branch, no gh" ;;
    *) fail "ship: refuses off feature branch, no gh" "output: $RUN_OUT" ;;
  esac
else
  fail "ship: refuses off feature branch, no gh" "exit $RUN_CODE, gh log: $(cat "$GH_LOG" 2>/dev/null)"
fi

cleanup
FIXTURE=""

# ── Unit tests: verify-complete gate matcher (sourced) ───────────────────────
# pk_verify_sentinel_for_head finds a verify-complete.md (any date dir) whose
# `sha:` matches HEAD. This is the core of the v4 ship gate that replaced the
# <today>-only + pk_linear_tier re-derivation (false-aborts on Linear flake /
# midnight rollover). Pure FS+grep, so we pass a fake sha — no real git needed.

echo "== verify-complete gate matcher (sourced) =="

make_fixture
HEAD_SHA="0123456789abcdef0123456789abcdef01234567"
OTHER_SHA="ffffffffffffffffffffffffffffffffffffffff"
unit_gate() { ( cd "$FIXTURE" && source "$PK" && pk_verify_sentinel_for_head "$@" ); }
write_sentinel() { # $1 date  $2 issue  $3 sha
  mkdir -p "$FIXTURE/Logs/Verify/$1/$2"
  printf '# verify-complete\n\nissue: %s\ntier: quick\nstatus: PASS\nsha: %s\n' "$2" "$3" \
    > "$FIXTURE/Logs/Verify/$1/$2/verify-complete.md"
}

write_sentinel 20260101 ABC-123 "$HEAD_SHA"
out=$(unit_gate ABC-123 "$HEAD_SHA"); rc=$?
[ $rc -eq 0 ] && [ -n "$out" ] && ok "gate: HEAD-matching sentinel found" || fail "gate: HEAD-matching sentinel found" "rc=$rc out='$out'"

out=$(unit_gate ABC-123 "$OTHER_SHA"); rc=$?
[ $rc -ne 0 ] && [ -z "$out" ] && ok "gate: non-matching sha rejected" || fail "gate: non-matching sha rejected" "rc=$rc out='$out'"

# Cross-date: a sentinel written yesterday still vouches for today's ship.
rm -rf "$FIXTURE/Logs/Verify"; write_sentinel 20251231 ABC-123 "$HEAD_SHA"
out=$(unit_gate ABC-123 "$HEAD_SHA"); rc=$?
[ $rc -eq 0 ] && ok "gate: cross-date sentinel found (midnight-rollover fix)" || fail "gate: cross-date sentinel found (midnight-rollover fix)" "rc=$rc"

# Wrong issue's sentinel must not satisfy this issue.
out=$(unit_gate XYZ-999 "$HEAD_SHA"); rc=$?
[ $rc -ne 0 ] && ok "gate: other-issue sentinel ignored" || fail "gate: other-issue sentinel ignored" "rc=$rc"

rm -rf "$FIXTURE/Logs/Verify"
out=$(unit_gate ABC-123 "$HEAD_SHA"); rc=$?
[ $rc -ne 0 ] && ok "gate: no sentinel → not found" || fail "gate: no sentinel → not found" "rc=$rc"

write_sentinel 20260101 ABC-123 "$HEAD_SHA"
out=$(unit_gate ABC-123 ""); rc=$?
[ $rc -ne 0 ] && ok "gate: empty HEAD never matches" || fail "gate: empty HEAD never matches" "rc=$rc out='$out'"
cleanup
FIXTURE=""

# ── CLI tests: verify-complete ship gate (E2E) ───────────────────────────────

echo "== verify-complete ship gate (E2E) =="

make_fixture
write_config '```
Backend: native
Integration branch: main
Ship environments: dev,beta,main
```'
git -C "$FIXTURE" checkout -q -b feat/ABC-123-widget
E2E_HEAD=$(git -C "$FIXTURE" rev-parse HEAD)

# (a) No sentinel → abort at the gate, before push and before any gh call.
: > "$GH_LOG"
run_pk ship
g=0; p=0
case "$RUN_OUT" in *"no verify-complete.md matching"*) g=1 ;; esac
case "$RUN_OUT" in *Pushing*) p=1 ;; esac
if [ $RUN_CODE -ne 0 ] && [ $g -eq 1 ] && [ $p -eq 0 ] && [ ! -s "$GH_LOG" ]; then
  ok "ship gate: no sentinel aborts before push/gh"
else
  fail "ship gate: no sentinel aborts before push/gh" "rc=$RUN_CODE gate_msg=$g pushed=$p gh='$(cat "$GH_LOG")'"
fi

# (b) HEAD-matching sentinel → passes the gate (reaches push; push fails with no
#     remote, which is fine — we only assert the gate let it through).
mkdir -p "$FIXTURE/Logs/Verify/20260101/ABC-123"
printf 'sha: %s\n' "$E2E_HEAD" > "$FIXTURE/Logs/Verify/20260101/ABC-123/verify-complete.md"
run_pk ship
case "$RUN_OUT" in
  *Pushing*) ok "ship gate: HEAD-matching sentinel passes gate" ;;
  *"no verify-complete.md matching"*) fail "ship gate: HEAD-matching sentinel passes gate" "gate still aborted" ;;
  *) fail "ship gate: HEAD-matching sentinel passes gate" "output: $(echo "$RUN_OUT" | head -3)" ;;
esac

# (c) PK_VERIFY_BYPASS=1 → gate skipped entirely (even with no sentinel).
rm -rf "$FIXTURE/Logs/Verify"
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" PK_VERIFY_BYPASS=1 "$PK" ship 2>&1)
case "$RUN_OUT" in
  *"gate bypassed via PK_VERIFY_BYPASS"*) ok "ship gate: PK_VERIFY_BYPASS=1 skips gate" ;;
  *) fail "ship gate: PK_VERIFY_BYPASS=1 skips gate" "output: $(echo "$RUN_OUT" | head -3)" ;;
esac
cleanup
FIXTURE=""

# ── Summary ──────────────────────────────────────────────────────────────────

echo
echo "pk smoke: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo "failed:$FAILED_NAMES"
  exit 1
fi
