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

# ── Unit tests: native phase derivation (sourced mode, no network) ───────────
# pk_native_phase_context / pk_native_roadmap_summary are pure: initiatives JSON
# in → derivation out. Order comes from the i<N>./P<N>. NAME PREFIX (Linear's
# sortOrder is an unreliable drag-rank); lifecycle from status/state. These guard
# the load-bearing jq against regression.

echo "== native phase derivation =="

NATIVE_FIXTURE='{"data":{"initiatives":{"nodes":[
  {"name":"i0. Setup","status":"Completed","projects":{"nodes":[{"id":"s1","name":"P1. Boot","state":"completed"}]}},
  {"name":"i1. Build","status":"Active","projects":{"nodes":[
    {"id":"p1","name":"P1. Foundation","state":"completed"},
    {"id":"p2","name":"P2. Editor","state":"planned"},
    {"id":"p10","name":"P10. Later","state":"backlog"}]}},
  {"name":"i2. Next","status":"Planned","projects":{"nodes":[{"id":"q1","name":"P1. Vendor","state":"backlog"}]}},
  {"name":"Strategic Theme","status":"Active","projects":{"nodes":[{"id":"z1","name":"Anything","state":"planned"}]}}
]}}}'

unit_native_ctx() { ( cd "$REPO_ROOT" && source "$PK" && pk_native_phase_context "$1" ); }
unit_roadmap()    { ( cd "$REPO_ROOT" && source "$PK" && pk_native_roadmap_summary "$1" ); }

v=$(unit_native_ctx "$NATIVE_FIXTURE")
[ "$v" = "$(printf 'i1. Build\tp2')" ] \
  && ok "native: phase=i1 (i0 Completed skipped), project=P2 (P1 done; P2<P10 numeric)" \
  || fail "native: derivation" "got '$v', want 'i1. Build<TAB>p2'"

v=$(unit_native_ctx '')
[ -z "$v" ] && ok "native: empty input → empty (no crash)" || fail "native: empty input" "got '$v'"

v=$(unit_native_ctx '{"data":{"initiatives":{"nodes":[{"name":"No Prefix","status":"Active","projects":{"nodes":[]}}]}}}')
[ -z "$v" ] && ok "native: no i<N>. prefix → empty (triggers file fallback)" || fail "native: no prefix" "got '$v'"

RM=$(unit_roadmap "$NATIVE_FIXTURE")
if   ! printf '%s\n' "$RM" | grep -q 'i1. Build  \[Active\]  → P2. Editor'; then fail "native: roadmap" "missing i1 line: $RM"
elif ! printf '%s\n' "$RM" | grep -q 'i2. Next  \[Planned\]  → P1. Vendor'; then fail "native: roadmap" "missing i2 line: $RM"
elif ! printf '%s\n' "$RM" | grep -q 'i0. Setup  \[Completed\]  → all projects done'; then fail "native: roadmap" "missing i0 done line: $RM"
elif   printf '%s\n' "$RM" | grep -q 'Strategic Theme'; then fail "native: roadmap" "strategic theme not excluded: $RM"
else ok "native: roadmap walk ordered by prefix, theme excluded, completed shown done"; fi

# v4.5.0: projects may carry the initiative number as a leading I<N>. prefix
# (I1.P2. label). The parser accepts both P<N>. and I<N>.P<N>.; the P-number still
# sets sub-phase order. This fixture mixes an I-prefixed phase with a P-only phase
# to prove backward compatibility in the same run.
NATIVE_FIXTURE_IPREFIX='{"data":{"initiatives":{"nodes":[
  {"name":"i1. Build","status":"Active","projects":{"nodes":[
    {"id":"p1","name":"I1.P1. Foundation","state":"completed"},
    {"id":"p2","name":"I1.P2. Editor","state":"planned"},
    {"id":"p10","name":"I1.P10. Later","state":"backlog"}]}},
  {"name":"i2. Next","status":"Planned","projects":{"nodes":[{"id":"q1","name":"P1. Vendor","state":"backlog"}]}}
]}}}'

v=$(unit_native_ctx "$NATIVE_FIXTURE_IPREFIX")
[ "$v" = "$(printf 'i1. Build\tp2')" ] \
  && ok "native: I<N>.P<N>. prefix parses (project=I1.P2; P2<P10 numeric)" \
  || fail "native: I-prefix derivation" "got '$v', want 'i1. Build<TAB>p2'"

RM2=$(unit_roadmap "$NATIVE_FIXTURE_IPREFIX")
if   ! printf '%s\n' "$RM2" | grep -q 'i1. Build  \[Active\]  → I1.P2. Editor'; then fail "native: I-prefix roadmap" "missing i1 line: $RM2"
elif ! printf '%s\n' "$RM2" | grep -q 'i2. Next  \[Planned\]  → P1. Vendor'; then fail "native: I-prefix roadmap" "P<N>.-only project not handled alongside I-prefix: $RM2"
else ok "native: I<N>.P<N>. and bare P<N>. projects coexist (backward-compatible)"; fi

# ── Unit tests: issue priority sort (sourced) ────────────────────────────────
# pk_issues_priority_sort orders a JSON issue array most-important-first so
# pk next/pk status surface the top item and .[0] (the suggested next action) is
# the highest priority. Linear priority ints: 1 Urgent, 2 High, 3 Normal, 4 Low,
# 0 None → None must sort LAST (not first, as a naive numeric sort would put it).

echo "== issue priority sort (sourced) =="

unit_prio_sort() { ( cd "$REPO_ROOT" && source "$PK" && pk_issues_priority_sort ); }

PRIO_IN='[{"identifier":"A","priority":3},{"identifier":"B","priority":0},{"identifier":"C","priority":1},{"identifier":"D","priority":4},{"identifier":"E","priority":2}]'
v=$(printf '%s' "$PRIO_IN" | unit_prio_sort | jq -c 'map(.identifier)')
[ "$v" = '["C","E","A","D","B"]' ] \
  && ok "prio sort: Urgent>High>Normal>Low>None (None last)" \
  || fail "prio sort: Urgent>High>Normal>Low>None" "got $v, want [\"C\",\"E\",\"A\",\"D\",\"B\"]"

# Missing/absent priority field is treated as None → sorts last, never crashes.
v=$(printf '%s' '[{"identifier":"X"},{"identifier":"Y","priority":2}]' | unit_prio_sort | jq -c 'map(.identifier)')
[ "$v" = '["Y","X"]' ] && ok "prio sort: absent priority → last" || fail "prio sort: absent priority → last" "got $v"

v=$(printf '%s' '[]' | unit_prio_sort)
[ "$v" = '[]' ] && ok "prio sort: empty array → empty (no crash)" || fail "prio sort: empty array" "got $v"

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

# ── CLI tests: pk deploy (script-deploy delegation) ──────────────────────────
# cmd_deploy resolves <env> → method.config.md "Deploy command[ <env>]" and exec's
# it, passing args after `--` through verbatim. Thin delegate: it must reach the
# configured script, never call gh, and point branch-promotion projects at pk promote.

echo "== pk deploy (script-deploy delegation) =="

make_fixture
# Stand-in deploy scripts that prove they ran and echo any passthrough args.
cat > "$FIXTURE/deploy-prod.sh" <<'EOF'
#!/usr/bin/env bash
echo "DEPLOYED-PROD args=[$*]"
EOF
cat > "$FIXTURE/deploy-dev.sh" <<'EOF'
#!/usr/bin/env bash
echo "DEPLOYED-DEV args=[$*]"
EOF
chmod +x "$FIXTURE/deploy-prod.sh" "$FIXTURE/deploy-dev.sh"

write_config '```
Promote to main: false
Deploy command: ./deploy-prod.sh
Deploy command dev: ./deploy-dev.sh
```'

# (1) Core: bare deploy reaches the configured script, passes args after --, no gh.
: > "$GH_LOG"
run_pk deploy -- a.html --all
g=0; case "$RUN_OUT" in *"DEPLOYED-PROD args=[a.html --all]"*) g=1 ;; esac
if [ $RUN_CODE -eq 0 ] && [ $g -eq 1 ] && [ ! -s "$GH_LOG" ]; then
  ok "deploy: delegates to script + passes args after --, no gh"
else
  fail "deploy: delegates to script + passes args after --, no gh" "rc=$RUN_CODE matched=$g gh='$(cat "$GH_LOG")' out: $(echo "$RUN_OUT" | tail -1)"
fi

# (2) prod with no env-specific key falls back to bare "Deploy command".
run_pk deploy prod
case "$RUN_OUT" in *DEPLOYED-PROD*) ok "deploy: prod falls back to bare Deploy command" ;; *) fail "deploy: prod falls back to bare Deploy command" "out: $RUN_OUT" ;; esac

# (3) env-specific "Deploy command dev" key (space-suffixed) resolves to the dev script.
run_pk deploy dev
case "$RUN_OUT" in *DEPLOYED-DEV*) ok "deploy: env-specific 'Deploy command dev' key resolves" ;; *) fail "deploy: env-specific 'Deploy command dev' key resolves" "out: $RUN_OUT" ;; esac

# (4) Unknown env with no key → error, exit 1, never calls gh.
: > "$GH_LOG"
run_pk deploy staging
if [ $RUN_CODE -eq 1 ] && [ ! -s "$GH_LOG" ]; then
  case "$RUN_OUT" in *"no 'Deploy command staging'"*) ok "deploy: unknown env errors (exit 1), no gh" ;; *) fail "deploy: unknown env errors (exit 1), no gh" "out: $RUN_OUT" ;; esac
else
  fail "deploy: unknown env errors (exit 1), no gh" "rc=$RUN_CODE gh='$(cat "$GH_LOG")'"
fi

# (5) Unknown flag → exit 2 (deploy-script args belong after --).
run_pk deploy --bogus
[ $RUN_CODE -eq 2 ] && ok "deploy: unknown flag rejected (exit 2)" || fail "deploy: unknown flag rejected (exit 2)" "exit $RUN_CODE"

# (6) Extra positional after the env → exit 2.
run_pk deploy prod extra
[ $RUN_CODE -eq 2 ] && ok "deploy: extra positional rejected (exit 2)" || fail "deploy: extra positional rejected (exit 2)" "exit $RUN_CODE"

# (7) Branch-promotion project (no Deploy command, Promote to main: true) →
#     points at pk promote, exit 0, never calls gh.
write_config '```
Promote to main: true
Ship environments: dev,main
```'
: > "$GH_LOG"
run_pk deploy
if [ $RUN_CODE -eq 0 ] && [ ! -s "$GH_LOG" ]; then
  case "$RUN_OUT" in *"pk promote"*) ok "deploy: branch-promotion project points at pk promote" ;; *) fail "deploy: branch-promotion project points at pk promote" "out: $RUN_OUT" ;; esac
else
  fail "deploy: branch-promotion project points at pk promote" "rc=$RUN_CODE gh='$(cat "$GH_LOG")'"
fi

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

# ── CLI tests: pk done worktree guard (regression: SiteLine dead-session) ─────
# pk done removes the feature worktree, so it must refuse when invoked from
# inside one. The bug: the guard gated on `root != wt_path`, but pk_repo_root()
# is `git rev-parse --show-toplevel`, which from inside a linked worktree returns
# the worktree itself → root == wt_path → guard skipped → the worktree (and the
# calling session) torn down. With --merge, the PR was even merged first. These
# tests pin: refuse from inside, before any gh pr merge; don't misfire from the
# parent.

echo "== done worktree guard (regression: SiteLine dead-session) =="

make_fixture
write_config '```
Backend: native
Integration branch: main
Ship environments: dev,beta,main
```'

# Feature branch + linked worktree, mirroring what `pk branch` creates.
git -C "$FIXTURE" branch feature/WT-7-demo
WT_DIR="$FIXTURE/.wt/WT-7"
git -C "$FIXTURE" worktree add -q "$WT_DIR" feature/WT-7-demo 2>/dev/null

# (1) pk_in_linked_worktree distinguishes the main checkout from a linked worktree.
in_main=$( cd "$FIXTURE" && source "$PK" && pk_in_linked_worktree && echo yes || echo no )
in_wt=$(   cd "$WT_DIR"  && source "$PK" && pk_in_linked_worktree && echo yes || echo no )
[ "$in_main" = no ] && [ "$in_wt" = yes ] \
  && ok "done: pk_in_linked_worktree true in worktree, false in main" \
  || fail "done: pk_in_linked_worktree true in worktree, false in main" "main=$in_main wt=$in_wt"

# (2) pk done --merge from INSIDE the worktree refuses BEFORE merging.
: > "$GH_LOG"
OUT=$(cd "$WT_DIR" && PATH="$FIXTURE/shim:$PATH" "$PK" done WT-7 --merge 2>&1); RC=$?
refused=0; merged=0
case "$OUT" in *"must run from the parent repo"*) refused=1 ;; esac
grep -q "pr merge" "$GH_LOG" 2>/dev/null && merged=1
if [ $RC -ne 0 ] && [ $refused -eq 1 ] && [ $merged -eq 0 ]; then
  ok "done: refuses from inside worktree before merging (no gh pr merge)"
else
  fail "done: refuses from inside worktree before merging" "rc=$RC refused=$refused merged=$merged gh='$(cat "$GH_LOG")'"
fi

# (3) the refusal left the worktree intact (nothing torn down under the session).
[ -d "$WT_DIR" ] && ok "done: worktree intact after refusal" || fail "done: worktree intact after refusal" "$WT_DIR gone"

# (4) Positive control: from the PARENT repo the guard must NOT misfire. (It still
#     fails later at merge-verify — the gh shim returns no JSON — but must not
#     print the parent-repo refusal.)
: > "$GH_LOG"
OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" "$PK" done WT-7 2>&1); RC=$?
case "$OUT" in
  *"must run from the parent repo"*) fail "done: parent-repo run passes the guard" "guard misfired: $OUT" ;;
  *) ok "done: parent-repo run passes the guard" ;;
esac

git -C "$FIXTURE" worktree remove --force "$WT_DIR" 2>/dev/null
cleanup
FIXTURE=""

# ── commit-format hook ───────────────────────────────────────────────────────
echo "== commit-format hook (templates/hooks/validate-commit.sh) =="

HOOK="$REPO_ROOT/templates/hooks/validate-commit.sh"
hook_run() { printf '%s' "$1" | bash "$HOOK" 2>&1; }   # $1 = PostToolUse JSON on stdin

if [ ! -f "$HOOK" ]; then
  fail "hook: source present" "missing $HOOK"
else
  ok "hook: source present"

  out=$(hook_run '{"tool_input":{"command":"git commit -m \"added a thing\""}}')
  case "$out" in
    *"does not match format"*) ok "hook: bad subject nudges" ;;
    *) fail "hook: bad subject nudges" "output: $out" ;;
  esac

  out=$(hook_run '{"tool_input":{"command":"git commit -m \"feat(work): native phase surface\""}}')
  [ -z "$out" ] && ok "hook: good subject silent" || fail "hook: good subject silent" "output: $out"

  out=$(hook_run '{"tool_input":{"command":"git commit -m \"fix(pk): repoint\" -m \"a long body without a colon\""}}')
  [ -z "$out" ] && ok "hook: body via 2nd -m not validated" || fail "hook: body via 2nd -m not validated" "output: $out"

  out=$(hook_run '{"tool_input":{"command":"ls -la && echo hi"}}')
  [ -z "$out" ] && ok "hook: non-commit silent" || fail "hook: non-commit silent" "output: $out"

  out=$(hook_run '{"tool_input":{"command":"git commit -m \"chore(release): v4.2.0\" && git commit -m \"broken\""}}')
  case "$out" in
    *"broken"*) ok "hook: chained nudges only the bad subject" ;;
    *) fail "hook: chained nudges only the bad subject" "output: $out" ;;
  esac

  # "git commit" as DATA (search pattern / echoed reminder) must NOT be validated —
  # it is only a commit when command-initial or shell-operator/newline-preceded.
  out=$(hook_run '{"tool_input":{"command":"grep -rn \"git commit\" docs/"}}')
  [ -z "$out" ] && ok "hook: grep-pattern data not validated" || fail "hook: grep-pattern data not validated" "output: $out"

  out=$(hook_run '{"tool_input":{"command":"echo git commit -m \"x\" >> notes.log"}}')
  [ -z "$out" ] && ok "hook: embedded -m data not validated" || fail "hook: embedded -m data not validated" "output: $out"

  # The boundary anchor must NOT over-reject real commits preceded by ( / && / newline.
  out=$(hook_run '{"tool_input":{"command":"(cd sub && git commit -m \"nope\")"}}')
  case "$out" in
    *"nope"*) ok "hook: subshell/operator-preceded commit validated" ;;
    *) fail "hook: subshell/operator-preceded commit validated" "output: $out" ;;
  esac

  out=$(hook_run '{"tool_input":{"command":"cd sub\ngit commit -m \"nope\""}}')
  case "$out" in
    *"nope"*) ok "hook: newline-preceded commit validated" ;;
    *) fail "hook: newline-preceded commit validated" "output: $out" ;;
  esac

  # "git commit -m" inside a heredoc BODY is documentation/prose, not an invocation —
  # the classic misfire is documenting commits in a gh pr comment --body "$(cat <<EOF…)".
  out=$(hook_run '{"tool_input":{"command":"gh pr comment 1 --body \"$(cat <<EOF\nFix: git commit -m \\\"feat: x\\\" now works.\nEOF\n)\""}}')
  [ -z "$out" ] && ok "hook: -m inside heredoc body not validated" || fail "hook: -m inside heredoc body not validated" "output: $out"

  # A prose heredoc with no -m and a bare "git commit" must not be grabbed as a subject.
  out=$(hook_run '{"tool_input":{"command":"cat <<EOF\nHow to commit: run git commit then push.\nEOF"}}')
  [ -z "$out" ] && ok "hook: prose heredoc (no -m) not validated" || fail "hook: prose heredoc (no -m) not validated" "output: $out"

  # Legit heredoc-authored commit (git commit -F- <<EOF): first body line IS the subject.
  out=$(hook_run '{"tool_input":{"command":"git commit -F- <<EOF\nbad subject no scope\nbody\nEOF"}}')
  case "$out" in
    *"bad subject no scope"*) ok "hook: -F- heredoc subject validated" ;;
    *) fail "hook: -F- heredoc subject validated" "output: $out" ;;
  esac

  out=$(hook_run '{"tool_input":{"command":"git commit -F- <<EOF\nfeat(x): proper subject\nbody\nEOF"}}')
  [ -z "$out" ] && ok "hook: -F- heredoc good subject silent" || fail "hook: -F- heredoc good subject silent" "output: $out"

  printf '%s' '{"tool_input":{"command":"git commit -m \"nope\""}}' | bash "$HOOK" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "hook: always exit 0 (advisory)" || fail "hook: always exit 0 (advisory)" "nonzero exit"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo
echo "pk smoke: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo "failed:$FAILED_NAMES"
  exit 1
fi
