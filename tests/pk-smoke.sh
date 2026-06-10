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

run_pk promote
[ $RUN_CODE -eq 2 ] && case "$RUN_OUT" in *"Specify target"*) ok "promote: multi-hop chain requires explicit target" ;; *) fail "promote: multi-hop chain requires explicit target" "output: $RUN_OUT" ;; esac \
  || fail "promote: multi-hop chain requires explicit target" "exit $RUN_CODE, want 2"

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

# ── Summary ──────────────────────────────────────────────────────────────────

echo
echo "pk smoke: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo "failed:$FAILED_NAMES"
  exit 1
fi
