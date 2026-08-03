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

# ── Unit tests: pk issue show — lean read (sourced) ──────────────────────────
# pk_issue_show_render is a pure renderer (issue JSON on stdin, fields CSV arg).
# pk_linear_issue_full builds a GraphQL query that fetches the FAT fields
# (description, comments) ONLY when requested — the whole point of `pk issue
# show`: a low-token read that avoids MCP getIssueById's sticky full-thread
# payload (see .claude/rules/pipekit-tooling.md § MCP Result Payloads Are Sticky).

echo "== pk issue show — lean read (sourced) =="

unit_render() { ( cd "$REPO_ROOT" && source "$PK" && pk_issue_show_render "$1" ); }

ISSUE_FIX='{"identifier":"RS-30","title":"Widget","url":"https://l/RS-30","priorityLabel":"High","state":{"name":"In Progress"},"assignee":{"displayName":"Ethan"},"project":{"name":"I1.P2. Editor"},"labels":{"nodes":[{"name":"Feature"},{"name":"tier:standard"}]},"description":"body","comments":{"nodes":[{"body":"c1","createdAt":"t","user":{"displayName":"Ann"}}]}}'

v=$(printf '%s' "$ISSUE_FIX" | unit_render "id,title,state,labels")
if printf '%s\n' "$v" | grep -q 'labels:    Feature, tier:standard' \
   && printf '%s\n' "$v" | grep -q 'state:     In Progress'; then
  ok "issue show: default fields render (labels joined, aligned)"
else
  fail "issue show: default fields render" "got: $v"
fi

# A scalar read must not print the description body.
v=$(printf '%s' "$ISSUE_FIX" | unit_render "id,title,state,labels")
printf '%s\n' "$v" | grep -q 'body' \
  && fail "issue show: scalar render omits description" "leaked body: $v" \
  || ok "issue show: scalar render omits description body"

# Unknown field is surfaced, not silently dropped (a typo'd --fields must not
# look like an empty issue).
v=$(printf '%s' "$ISSUE_FIX" | unit_render "bogus")
[ "$v" = "bogus: (unknown field)" ] \
  && ok "issue show: unknown field surfaced" \
  || fail "issue show: unknown field surfaced" "got '$v'"

# Empty labels array → no crash, empty value.
v=$(printf '%s' '{"identifier":"X-1","labels":{"nodes":[]}}' | unit_render "labels")
[ "$v" = "labels:    " ] \
  && ok "issue show: empty labels → no crash" \
  || fail "issue show: empty labels" "got '$v'"

# Query-building: stub the network chokepoint, capture the query it was handed,
# and assert the fat fields are fetched only on demand.
GQL_STUB='pk_linear_gql() { printf "%s" "$1" > "$QFILE"; echo "{\"data\":{\"issue\":{\"identifier\":\"RS-30\"}}}"; }'
run_q() { QFILE="$1"; export QFILE; ( cd "$REPO_ROOT" && source "$PK" && eval "$GQL_STUB" && pk_linear_issue_full "RS-30" "$2" "$3" >/dev/null ); }
QF=$(mktemp)

run_q "$QF" "id,title,state,labels" ""
grep -q 'description' "$QF" && fail "issue show: default query omits description" "leaked into query" || ok "issue show: default query omits description"
grep -q 'comments'    "$QF" && fail "issue show: default query omits comments"    "leaked into query" || ok "issue show: default query omits comments"

run_q "$QF" "id,description" ""
grep -q 'description' "$QF" && ok "issue show: --fields description fetches it" || fail "issue show: --fields description fetches it" "not in query"

run_q "$QF" "id" "1"
grep -q 'comments' "$QF" && ok "issue show: --comments fetches comments" || fail "issue show: --comments fetches comments" "not in query"

# `comments` in --fields (without the flag) must also fetch — else it renders (0).
run_q "$QF" "id,comments" ""
grep -q 'comments' "$QF" && ok "issue show: --fields comments also fetches (symmetry)" || fail "issue show: --fields comments also fetches" "not in query"

rm -f "$QF"

# Trailing/empty field name is skipped, not rendered as "(unknown field)".
v=$(printf '%s' '{"identifier":"Z-9","title":"T"}' | unit_render "id,title,")
printf '%s\n' "$v" | grep -q 'unknown field' \
  && fail "issue show: trailing comma skipped" "rendered bogus line: $v" \
  || ok "issue show: trailing comma → empty field skipped"

# ── Unit tests: pk status project grouping (sourced) ─────────────────────────
# pk_issues_group_render groups a JSON issue array by project for pk status:
# project groups ordered by their highest-priority issue, issues priority-sorted
# within, orphans ("(no project)") last. Pure render (no network).

echo "== pk status project grouping (sourced) =="

unit_group() { ( cd "$REPO_ROOT" && source "$PK" && pk_issues_group_render ); }

# The orphan here carries Urgent (1) — it must STILL sink last (orphans are an
# anomaly to home, not normal work), proving orphan-last beats priority order.
GROUP_IN='[
  {"identifier":"POC-3","title":"client ask","priority":3,"project":{"name":"Export"}},
  {"identifier":"POC-1","title":"margin core","priority":2,"project":{"name":"Margin"}},
  {"identifier":"POC-9","title":"orphan","priority":1,"project":null},
  {"identifier":"POC-4","title":"label tweak","priority":3,"project":{"name":"Export"}}
]'
out=$(printf '%s' "$GROUP_IN" | unit_group)
# Margin (High=2) group leads; Export (Normal=3) next; orphan last despite Urgent.
exp='  Margin:
    POC-1 — margin core
  Export:
    POC-3 — client ask
    POC-4 — label tweak
  (no project):
    POC-9 — orphan'
[ "$out" = "$exp" ] && ok "group: projects by top priority; orphans last even when Urgent" \
  || fail "group: projects by top priority; orphans last even when Urgent" "got:
$out"

# Single project, no orphans → one group header.
out=$(printf '%s' '[{"identifier":"Z-1","title":"t","priority":2,"project":{"name":"Solo"}}]' | unit_group)
[ "$out" = "$(printf '  Solo:\n    Z-1 — t')" ] && ok "group: single project renders one header" || fail "group: single project" "got: $out"

out=$(printf '%s' '[]' | unit_group)
[ -z "$out" ] && ok "group: empty array → no output (no crash)" || fail "group: empty array" "got: $out"

# Blocked issues (annotated upstream) render with the ⛔ tag and sink within
# their project group, below ready work.
BLK_IN='[
  {"identifier":"R-2","title":"ready","priority":3,"project":{"name":"Solo"},"blocked":false},
  {"identifier":"R-1","title":"blocked hi","priority":2,"project":{"name":"Solo"},"blocked":true,"blockerIds":["R-9"]}
]'
out=$(printf '%s' "$BLK_IN" | unit_group)
exp='  Solo:
    R-2 — ready
    R-1 — blocked hi  ⛔ blocked by R-9'
[ "$out" = "$exp" ] && ok "group: blocked issue sinks within group + ⛔ tag" || fail "group: blocked tag/sink" "got:
$out"

# ── Unit tests: dependency-aware pk next (sourced) ───────────────────────────
# pk_issues_annotate_blocked reads Linear inverseRelations (type "blocks"; the
# .issue side is the blocker) and marks an issue blocked iff a blocker is not yet
# Done/Canceled. pk_first_ready_id picks the top-priority STARTABLE issue;
# pk_issues_flat_render sinks blocked work and tags it. Fail-safe on missing data.

echo "== dependency-aware pk next (sourced) =="

unit_annotate()  { ( cd "$REPO_ROOT" && source "$PK" && pk_issues_annotate_blocked ); }
unit_flat()      { ( cd "$REPO_ROOT" && source "$PK" && pk_issues_flat_render ); }
unit_ready()     { ( cd "$REPO_ROOT" && source "$PK" && pk_first_ready_id ); }

# Blocker In Progress → blocked; blocker Done → ready; Canceled → ready; none → ready.
DEP_IN='[
  {"identifier":"A","title":"open blocker","priority":1,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"X1","state":{"name":"In Progress"}}}]}},
  {"identifier":"B","title":"done blocker","priority":3,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"X2","state":{"name":"Done"}}}]}},
  {"identifier":"C","title":"cancelled blocker","priority":3,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"X3","state":{"name":"Canceled"}}}]}},
  {"identifier":"D","title":"no relations","priority":4,"inverseRelations":{"nodes":[]}}
]'
ann=$(printf '%s' "$DEP_IN" | unit_annotate)
v=$(printf '%s' "$ann" | jq -c '[.[] | {id:.identifier, blocked:.blocked}]')
[ "$v" = '[{"id":"A","blocked":true},{"id":"B","blocked":false},{"id":"C","blocked":false},{"id":"D","blocked":false}]' ] \
  && ok "annotate: open blocker→blocked; Done/Canceled/none→ready" \
  || fail "annotate: blocked detection" "got $v"

# Only the UNFINISHED blocker is listed (a "related" relation is ignored, a Done blocker dropped).
MULTI='[{"identifier":"M","title":"t","priority":2,"inverseRelations":{"nodes":[
  {"type":"blocks","issue":{"identifier":"OPEN1","state":{"name":"UAT"}}},
  {"type":"blocks","issue":{"identifier":"DONE1","state":{"name":"Done"}}},
  {"type":"related","issue":{"identifier":"REL1","state":{"name":"Backlog"}}}
]}}]'
v=$(printf '%s' "$MULTI" | unit_annotate | jq -c '.[0].blockerIds')
[ "$v" = '["OPEN1"]' ] && ok "annotate: only unfinished blocks-relations counted" || fail "annotate: blocker filtering" "got $v"

# first ready = highest-priority unblocked. Here Urgent A is blocked, so B (Normal) wins over D (Low).
v=$(printf '%s' "$ann" | unit_ready)
[ "$v" = "B" ] && ok "first ready: skips blocked Urgent, picks top ready" || fail "first ready" "got '$v', want B"

# all blocked → empty (caller says 'all blocked' instead of suggesting one).
v=$(printf '%s' '[{"identifier":"Z","priority":1,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"Q","state":{"name":"Approved"}}}]}}]' | unit_annotate | unit_ready)
[ -z "$v" ] && ok "first ready: all blocked → empty" || fail "first ready: all blocked" "got '$v'"

# flat render: ready first (priority order), blocked sunk + tagged.
out=$(printf '%s' "$ann" | unit_flat)
exp='  B — done blocker
  C — cancelled blocker
  D — no relations
  A — open blocker  ⛔ blocked by X1'
[ "$out" = "$exp" ] && ok "flat render: ready-first, blocked sunk + tagged" || fail "flat render" "got:
$out"

# Fail-safe: an issue with NO inverseRelations field at all → ready, no crash.
v=$(printf '%s' '[{"identifier":"N","priority":2}]' | unit_annotate | jq -c '.[0].blocked')
[ "$v" = "false" ] && ok "annotate: absent inverseRelations → ready (fail-safe)" || fail "annotate: absent relations" "got $v"

# ── Unit tests: pk portfolio runway render (sourced) ─────────────────────────
# pk_runway_render groups issues by their P<N>. project (ordered by P<N>). Within
# a project, issues sort priority-first; blocked issues are NOT sunk, but a
# blocker is lifted to rank just above the most urgent issue it blocks. Columns
# are width-aligned so the action tag lines up across rows.

echo "== pk portfolio runway render (sourced) =="

unit_runway() { ( cd "$REPO_ROOT" && source "$PK" && pk_runway_render "$@" ); }

# Alpha: A-BLK (Normal) blocks A-HI (High). The blocker should lift ABOVE the
# high blocked issue; Urgent stays on top; Low stays at bottom; blocked NOT sunk.
# All carry the same updatedAt so per-project idle is deterministic below.
RW_IN='[
  {"identifier":"A-URG","title":"urgent ready","priority":1,"updatedAt":"2026-06-15T00:00:00.000Z","state":{"name":"Approved"},"blocked":false,"project":{"name":"I1.P1. Alpha"}},
  {"identifier":"A-BLK","title":"normal blocker","priority":3,"updatedAt":"2026-06-15T00:00:00.000Z","state":{"name":"Approved"},"blocked":false,"project":{"name":"I1.P1. Alpha"}},
  {"identifier":"A-HI","title":"high blocked","priority":2,"updatedAt":"2026-06-15T00:00:00.000Z","state":{"name":"Approved"},"blocked":true,"blockerIds":["A-BLK"],"project":{"name":"I1.P1. Alpha"}},
  {"identifier":"A-LO","title":"low ready","priority":4,"updatedAt":"2026-06-15T00:00:00.000Z","state":{"name":"Needs Spec"},"blocked":false,"project":{"name":"I1.P1. Alpha"}},
  {"identifier":"B-1","title":"beta work","priority":2,"updatedAt":"2026-06-15T00:00:00.000Z","state":{"name":"Needs Spec"},"blocked":false,"project":{"name":"I1.P2. Beta"}}
]'
out=$(printf '%s' "$RW_IN" | unit_runway)

# Project groups ordered by P<N>. (Alpha=P1 before Beta=P2). Header carries the count.
a_ln=$(printf '%s\n' "$out" | grep -n 'I1.P1. Alpha  (4)' | head -1 | cut -d: -f1)
b_ln=$(printf '%s\n' "$out" | grep -n 'I1.P2. Beta  (1)'  | head -1 | cut -d: -f1)
{ [ -n "$a_ln" ] && [ -n "$b_ln" ] && [ "$a_ln" -lt "$b_ln" ]; } \
  && ok "runway: groups by project (with count), ordered by P<N>." || fail "runway: project grouping/order/count" "got:
$out"

# Priority-first with blocker-lift: URG → BLK (lifted above HI) → HI (not sunk) → LO, then B-1.
seq=$(printf '%s\n' "$out" | awk '/^    [A-Z]/ {print $1}' | tr '\n' ',')
[ "$seq" = "A-URG,A-BLK,A-HI,A-LO,B-1," ] \
  && ok "runway: priority-first, blocker lifted above its blocked issue, blocked not sunk" \
  || fail "runway: priority-first + blocker-lift order" "got seq: $seq
$out"

# Action tags + the blocked issue still carries its ⛔ tag (just not sunk).
{ printf '%s\n' "$out" | grep -q 'A-URG .*spec ready → pk branch A-URG' \
  && printf '%s\n' "$out" | grep -q 'A-LO .*needs spec → /light-spec' \
  && printf '%s\n' "$out" | grep -q 'A-HI .*⛔ blocked by A-BLK'; } \
  && ok "runway: action tags + blocked ⛔ tag retained" || fail "runway: action tags" "got:
$out"

# Columns aligned: the "·" separator sits at the same offset on every issue row.
cols=$(printf '%s\n' "$out" | grep '·' | awk '{print index($0,"·")}' | sort -u | wc -l | tr -d ' ')
[ "$cols" = "1" ] && ok "runway: action column aligned across rows" || fail "runway: column alignment" "offsets:
$(printf '%s\n' "$out" | grep '·' | awk '{print index($0,"·")}')"

# Multi-phase: project groups order by initiative THEN sub-phase (I1.P2 before I2.P1).
MULTI_IN='[
  {"identifier":"X2","title":"i2 work","priority":1,"state":{"name":"Approved"},"blocked":false,"project":{"name":"I2.P1. Gamma"}},
  {"identifier":"X1","title":"i1p2 work","priority":1,"state":{"name":"Approved"},"blocked":false,"project":{"name":"I1.P2. Beta"}}
]'
mout=$(printf '%s' "$MULTI_IN" | unit_runway)
m12=$(printf '%s\n' "$mout" | grep -n 'I1.P2. Beta'  | head -1 | cut -d: -f1)
m21=$(printf '%s\n' "$mout" | grep -n 'I2.P1. Gamma' | head -1 | cut -d: -f1)
{ [ -n "$m12" ] && [ -n "$m21" ] && [ "$m12" -lt "$m21" ]; } \
  && ok "runway: groups order by initiative then sub-phase across phases" || fail "runway: cross-phase order" "got:
$mout"

# Momentum: idle flag absent when activity is recent, present (with N) when stale.
base='2026-06-15T00:00:00Z'
now_fresh=$(jq -n --arg d "$base" '($d|fromdateiso8601) + (5*86400)')
now_stale=$(jq -n --arg d "$base" '($d|fromdateiso8601) + (30*86400)')
out_fresh=$(printf '%s' "$RW_IN" | unit_runway "$now_fresh" 14)
printf '%s\n' "$out_fresh" | grep -q 'idle' \
  && fail "runway: recent activity → no idle flag" "got:
$out_fresh" \
  || ok "runway: recent activity → no idle flag"
out_stale=$(printf '%s' "$RW_IN" | unit_runway "$now_stale" 14)
printf '%s\n' "$out_stale" | grep -q '30d idle' \
  && ok "runway: stale project → ⚠ Nd idle flag" || fail "runway: stale project flag" "got:
$out_stale"

out=$(printf '%s' '[]' | unit_runway)
[ -z "$out" ] && ok "runway: empty array → no output (no crash)" || fail "runway: empty array" "got: $out"

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

# portfolio is wired into dispatch (not the unknown-subcommand path). With no
# Team configured it guards early — either way it must not fall through to help.
run_pk portfolio
case "$RUN_OUT" in
  *"Unknown subcommand"*) fail "portfolio: recognized subcommand" "fell through to unknown: $RUN_OUT" ;;
  *) ok "portfolio: recognized subcommand (routed to cmd_portfolio)" ;;
esac

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

# ── Unit tests: ready_for_review reviewer probe (sourced) ────────────────────
# pk_ready_for_review_workflows names the reviewers that will ACTUALLY fire on
# a Draft → Ready flip, by listing .github/workflows/ — replacing a hardcoded
# "(Semgrep, claude-review)" that asserted both on every project. Anchor:
# SiteLine 2026-07-29 — no Semgrep workflow, ever; pk claimed it would fire.

echo "== ready_for_review reviewer probe (sourced) =="

make_fixture
unit_rfr() { ( cd "$FIXTURE" && source "$PK" && pk_ready_for_review_list ); }
write_wf() { # $1 filename  $2 file content
  mkdir -p "$FIXTURE/.github/workflows"
  printf '%s\n' "$2" > "$FIXTURE/.github/workflows/$1"
}

out=$(unit_rfr)
[ -z "$out" ] && ok "rfr: no .github/workflows dir → no reviewers claimed" || fail "rfr: no .github/workflows dir → no reviewers claimed" "out='$out'"

write_wf lint.yml 'name: Lint
on:
  pull_request:
    types: [opened, synchronize]'
out=$(unit_rfr)
[ -z "$out" ] && ok "rfr: non-reviewer workflow not counted" || fail "rfr: non-reviewer workflow not counted" "out='$out'"

write_wf claude-code-review.yml 'name: Claude Code Review
on:
  pull_request:
    types: [opened, ready_for_review, synchronize]'
out=$(unit_rfr)
[ "$out" = "Claude Code Review" ] && ok "rfr: single reviewer named from workflow name:" || fail "rfr: single reviewer named from workflow name:" "out='$out'"

# The SiteLine case: claude-review installed, Semgrep never was. The old
# hardcoded string named Semgrep here; the probe must not.
case "$out" in *Semgrep*) fail "rfr: uninstalled Semgrep not claimed (SiteLine class)" "out='$out'" ;; *) ok "rfr: uninstalled Semgrep not claimed (SiteLine class)" ;; esac

write_wf semgrep.yml 'name: Semgrep
on:
  pull_request:
    types: [opened, ready_for_review]'
out=$(unit_rfr)
[ "$out" = "Claude Code Review, Semgrep" ] && ok "rfr: both reviewers joined, sorted" || fail "rfr: both reviewers joined, sorted" "out='$out'"

# A commented-out trigger fires nothing — it must not be reported as a reviewer.
rm -f "$FIXTURE/.github/workflows/semgrep.yml" "$FIXTURE/.github/workflows/claude-code-review.yml"
write_wf disabled.yml 'name: Disabled Review
on:
  pull_request:
    # types: [ready_for_review]
    types: [opened]'
out=$(unit_rfr)
[ -z "$out" ] && ok "rfr: commented-out trigger not counted" || fail "rfr: commented-out trigger not counted" "out='$out'"

# No `name:` field → fall back to the filename stem rather than printing blank.
rm -f "$FIXTURE/.github/workflows/disabled.yml"
write_wf nameless.yaml 'on:
  pull_request:
    types: [ready_for_review]'
out=$(unit_rfr)
[ "$out" = "nameless" ] && ok "rfr: unnamed workflow falls back to filename stem" || fail "rfr: unnamed workflow falls back to filename stem" "out='$out'"
cleanup
FIXTURE=""

# ── Unit tests: fires-once-only reviewer probe (sourced) ─────────────────────
# pk_review_workflows_without_sync names ready_for_review reviewers that omit
# `synchronize`, i.e. that review the Ready flip and nothing you push after it.
# Anchor: SiteLine PIPER-345 `879748e5` and PIPER-499 `778edbec` both merged
# with their final head unreviewed, recorded in three separate session logs.

echo "== fires-once-only reviewer probe (sourced) =="

make_fixture
unit_nosync() { ( cd "$FIXTURE" && source "$PK" && pk_review_without_sync_list ); }
write_wf() { mkdir -p "$FIXTURE/.github/workflows"; printf '%s\n' "$2" > "$FIXTURE/.github/workflows/$1"; }

out=$(unit_nosync)
[ -z "$out" ] && ok "nosync: no workflows dir → nothing claimed" || fail "nosync: no workflows dir → nothing claimed" "out='$out'"

# Reviewer WITH synchronize: reviews every push, so it must NOT be flagged.
write_wf claude-code-review.yml 'name: Claude Code Review
on:
  pull_request:
    types: [opened, ready_for_review, synchronize]'
out=$(unit_nosync)
[ -z "$out" ] && ok "nosync: reviewer carrying synchronize is not flagged" || fail "nosync: reviewer carrying synchronize is not flagged" "out='$out'"

# The real SiteLine shape: ready_for_review, no synchronize.
write_wf claude-code-review.yml 'name: Claude Code Review
on:
  pull_request:
    types: [opened, ready_for_review]'
out=$(unit_nosync)
[ "$out" = "Claude Code Review" ] && ok "nosync: fires-once reviewer flagged (SiteLine class)" || fail "nosync: fires-once reviewer flagged (SiteLine class)" "out='$out'"

# A commented-out synchronize triggers nothing — must still count as no-sync.
write_wf claude-code-review.yml 'name: Claude Code Review
on:
  pull_request:
    # types: [ready_for_review, synchronize]
    types: [ready_for_review]'
out=$(unit_nosync)
[ "$out" = "Claude Code Review" ] && ok "nosync: commented-out synchronize does not exempt" || fail "nosync: commented-out synchronize does not exempt" "out='$out'"

# A non-reviewer workflow that has synchronize but no ready_for_review is out of
# scope entirely — it is not a Ready-flip reviewer, so it must not be named.
rm -f "$FIXTURE/.github/workflows/claude-code-review.yml"
write_wf lint.yml 'name: Lint
on:
  pull_request:
    types: [opened, synchronize]'
out=$(unit_nosync)
[ -z "$out" ] && ok "nosync: non-reviewer workflow never named" || fail "nosync: non-reviewer workflow never named" "out='$out'"

# Guard the set -euo pipefail abort class: the helper must exit 0 and print
# nothing when no workflow matches, not kill pk after the Draft flip landed.
( cd "$FIXTURE" && source "$PK" && pk_review_without_sync_list >/dev/null ) \
  && ok "nosync: exits 0 on no match (no set -e abort)" \
  || fail "nosync: exits 0 on no match (no set -e abort)" "non-zero exit"
cleanup
FIXTURE=""

# ── Unit tests: conflicting-PR warning (sourced) ─────────────────────────────
# A conflicting PR gets ZERO pull_request workflows — GitHub cannot build the
# merge ref — so required checks never run and the board keeps its last state.
# Anchor: SiteLine PIPER-174 merged with its sole required gate never having run.
# Must warn on CONFLICTING and stay silent on every other value, including
# UNKNOWN: asserting a state we did not observe is the bug class, not the fix.

echo "== conflicting-PR warning (sourced) =="

make_fixture
# Override `gh` with a shell function after sourcing — functions beat PATH, so
# this stubs the single call the helper makes without touching the shim.
unit_conflict() { ( cd "$FIXTURE" && source "$PK" && eval "gh() { echo '$1'; }" && pk_warn_if_conflicting 42 ); }

out=$(unit_conflict CONFLICTING)
case "$out" in *CONFLICTS*) ok "conflict: CONFLICTING warns" ;; *) fail "conflict: CONFLICTING warns" "out='$out'" ;; esac
case "$out" in *stale*) ok "conflict: warning says the green is stale" ;; *) fail "conflict: warning says the green is stale" "out='$out'" ;; esac

out=$(unit_conflict MERGEABLE)
[ -z "$out" ] && ok "conflict: MERGEABLE is silent" || fail "conflict: MERGEABLE is silent" "out='$out'"

out=$(unit_conflict UNKNOWN)
[ -z "$out" ] && ok "conflict: UNKNOWN is silent (never claims unobserved state)" || fail "conflict: UNKNOWN is silent (never claims unobserved state)" "out='$out'"

# gh absent/failing → the shim echoes to its log, not stdout, so mergeable is
# empty. Must stay silent AND exit 0 rather than aborting pk under set -e.
out=$( cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" bash -c "source '$PK' && pk_warn_if_conflicting 42" 2>&1 )
rc=$?
[ -z "$out" ] && [ "$rc" = "0" ] \
  && ok "conflict: unreadable mergeable stays silent, exits 0" \
  || fail "conflict: unreadable mergeable stays silent, exits 0" "out='$out' rc=$rc"
cleanup
FIXTURE=""

# Structural: bin/pk must never shell out to `pk`. Inside the script, `pk` is
# whatever is on PATH — the installed copy, often a symlink into a DIFFERENT
# repo's working tree — not this file. It also simply does not exist for anyone
# who never ran `pk install`, so under `set -euo pipefail` the substitution
# fails and aborts the caller. Internal reads go through pk_config /
# pk_integration_branch. Caught in CI on v4.26.0: a `pk config` call passed
# locally only because the author had pk on PATH, and failed on a clean runner.
selfcall=$(grep -nE '\$\(pk [a-z]' "$PK" || true)
[ -z "$selfcall" ] \
  && ok "structure: bin/pk never shells out to \`pk\` (PATH-dependent)" \
  || fail "structure: bin/pk never shells out to \`pk\` (PATH-dependent)" "$selfcall"

# ── Unit tests: pk_linear_tier no-silent-default (v4.26.1) ───────────────────
# pk_linear_tier must return empty on a miss (no tier: label, or the query
# failing) — never "standard". A silent default is indistinguishable from an
# issue that was actually tier:standard; the caller (skills/verify/SKILL.md
# Step 0) owns the fallback and is the one that can warn it's guessing.

echo "== pk_linear_tier no-silent-default (sourced) =="

TIER_STUB='pk_linear_gql() { echo "{\"data\":{\"issue\":{\"labels\":{\"nodes\":${TIER_LABELS}}}}}"; }'
unit_tier() { ( cd "$REPO_ROOT" && source "$PK" && eval "$TIER_STUB" && pk_linear_tier "ANY-1" ); }

export TIER_LABELS='[{"name":"Feature"},{"name":"tier:heavy"}]'
v=$(unit_tier)
[ "$v" = "heavy" ] && ok "pk_linear_tier: explicit tier:heavy resolved" || fail "pk_linear_tier: explicit tier:heavy resolved" "got '$v'"

export TIER_LABELS='[{"name":"Feature"},{"name":"Bug"}]'
v=$(unit_tier)
[ -z "$v" ] && ok "pk_linear_tier: no tier label -> empty, not a silent standard default" || fail "pk_linear_tier: no tier label -> empty, not a silent standard default" "got '$v'"

export TIER_LABELS='[]'
v=$(unit_tier)
[ -z "$v" ] && ok "pk_linear_tier: empty label set -> empty" || fail "pk_linear_tier: empty label set -> empty" "got '$v'"

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

# ── Unit tests: pk_gate_verdict (pure, shared by secgate + prodready gates) ──
# v4.17.0: one decision table serves both sentinel gates. Precedence is pinned:
# bypass-env > skip(unconfigured) > ok(sentinel) > bypass-force > block.

echo "== gate verdict (pure, v4.17.0) =="

make_fixture
gv() { ( cd "$FIXTURE" && source "$PK" && pk_gate_verdict "$@" ); }

[ "$(gv 1 0 0 1)" = "bypass-env" ]   && ok "gate verdict: bypass env wins"                    || fail "gate verdict: bypass env wins" "got $(gv 1 0 0 1)"
[ "$(gv 0 0 0 1)" = "bypass-env" ]   && ok "gate verdict: bypass env beats unconfigured"      || fail "gate verdict: bypass env beats unconfigured" "got $(gv 0 0 0 1)"
[ "$(gv 0 0 0 0)" = "skip" ]         && ok "gate verdict: unconfigured → skip"                || fail "gate verdict: unconfigured → skip" "got $(gv 0 0 0 0)"
[ "$(gv 1 1 0 0)" = "ok" ]           && ok "gate verdict: configured + sentinel → ok"         || fail "gate verdict: configured + sentinel → ok" "got $(gv 1 1 0 0)"
[ "$(gv 1 0 1 0)" = "bypass-force" ] && ok "gate verdict: missing sentinel + --force"          || fail "gate verdict: missing sentinel + --force" "got $(gv 1 0 1 0)"
[ "$(gv 1 0 0 0)" = "block" ]        && ok "gate verdict: configured + missing → block"       || fail "gate verdict: configured + missing → block" "got $(gv 1 0 0 0)"

# ── Unit tests: secgate + prodready sentinel matchers ────────────────────────

echo "== secgate / prodready sentinel matchers (v4.17.0) =="

HEAD_SHA="0123456789abcdef0123456789abcdef01234567"
OTHER_SHA="ffffffffffffffffffffffffffffffffffffffff"
sg() { ( cd "$FIXTURE" && source "$PK" && pk_secgate_sentinel_for_head "$@" ); }
pr() { ( cd "$FIXTURE" && source "$PK" && pk_prodready_sentinel_for_sha "$@" ); }

mkdir -p "$FIXTURE/Logs/SecurityGate/20260101/ABC-123"
printf '# secgate-complete\n\nissue: ABC-123\nstatus: PASS\nsha: %s\n' "$HEAD_SHA" \
  > "$FIXTURE/Logs/SecurityGate/20260101/ABC-123/secgate-complete.md"
out=$(sg ABC-123 "$HEAD_SHA"); rc=$?
[ $rc -eq 0 ] && [ -n "$out" ] && ok "secgate matcher: HEAD-matching sentinel found" || fail "secgate matcher: HEAD-matching sentinel found" "rc=$rc"
out=$(sg ABC-123 "$OTHER_SHA"); rc=$?
[ $rc -ne 0 ] && ok "secgate matcher: non-matching sha rejected" || fail "secgate matcher: non-matching sha rejected" "rc=$rc out='$out'"
out=$(sg XYZ-999 "$HEAD_SHA"); rc=$?
[ $rc -ne 0 ] && ok "secgate matcher: other-issue sentinel ignored" || fail "secgate matcher: other-issue sentinel ignored" "rc=$rc"

mkdir -p "$FIXTURE/Logs/ProdReady/20260101"
printf '# prodready-complete\n\nstatus: PASS\nsha: %s\n' "$HEAD_SHA" \
  > "$FIXTURE/Logs/ProdReady/20260101/prodready-complete.md"
out=$(pr "$HEAD_SHA"); rc=$?
[ $rc -eq 0 ] && [ -n "$out" ] && ok "prodready matcher: sha-matching sentinel found (any date)" || fail "prodready matcher: sha-matching sentinel found (any date)" "rc=$rc"
out=$(pr "$OTHER_SHA"); rc=$?
[ $rc -ne 0 ] && ok "prodready matcher: non-matching sha rejected" || fail "prodready matcher: non-matching sha rejected" "rc=$rc out='$out'"
cleanup
FIXTURE=""

# ── Unit tests: verify-drift (ship→merge window, v4.27.0) ────────────────────
# `pk ship` proves the sentinel matched at ship time; commits landing during PR
# review move HEAD past it and nothing re-checks. Anchor: SiteLine PIPER-490
# (PR #774) merged with a PASS artifact describing an RLS predicate that a
# post-ship commit had rewritten.

echo "== verify drift: classifier (pure, v4.27.0) =="

make_fixture
dc() { ( cd "$FIXTURE" && source "$PK" && pk_verify_drift_class "$@" ); }

[ "$(printf ''                                        | dc)" = "fresh" ]      && ok "drift class: no files → fresh"            || fail "drift class: no files → fresh" "got $(printf '' | dc)"
[ "$(printf 'Logs/Verify/x/e.txt\nREADME.md\n'        | dc)" = "docs" ]       && ok "drift class: evidence+prose → docs"       || fail "drift class: evidence+prose → docs" "got $(printf 'Logs/Verify/x/e.txt\nREADME.md\n' | dc)"
[ "$(printf 'src/app/js/auth.js\n'                    | dc)" = "source" ]     && ok "drift class: source → source"             || fail "drift class: source → source" "got $(printf 'src/app/js/auth.js\n' | dc)"
[ "$(printf 'tests/rls/a.test.js\n'                   | dc)" = "source" ]     && ok "drift class: tests count as source"       || fail "drift class: tests count as source" "got $(printf 'tests/rls/a.test.js\n' | dc)"
[ "$(printf 'supabase/migrations/a.sql\nsrc/b.js\n'   | dc)" = "migrations" ] && ok "drift class: migration outranks source"   || fail "drift class: migration outranks source" "got $(printf 'supabase/migrations/a.sql\nsrc/b.js\n' | dc)"
[ "$(printf 'apps/api/supabase/migrations/a.sql\n'    | dc)" = "migrations" ] && ok "drift class: nested monorepo migration"   || fail "drift class: nested monorepo migration" "got $(printf 'apps/api/supabase/migrations/a.sql\n' | dc)"
[ "$(printf 'db/migrate/001.rb\n'                     | dc 'db/migrate')"    = "migrations" ] && ok "drift class: configured non-Supabase migration dir" || fail "drift class: configured non-Supabase migration dir" "got $(printf 'db/migrate/001.rb\n' | dc 'db/migrate')"
[ "$(printf 'supabase/migrations/a.sql\n'             | dc 'supabase/migrations')" = "migrations" ] && ok "drift class: migration dir without trailing slash" || fail "drift class: migration dir without trailing slash" "got $(printf 'supabase/migrations/a.sql\n' | dc 'supabase/migrations')"

echo "== verify drift: block/allow contract (pure, v4.27.0) =="

db() { ( cd "$FIXTURE" && source "$PK" && pk_verify_drift_blocks "$@" ); }

[ "$(db source)" = "block" ]      && ok "drift blocks: source → block"          || fail "drift blocks: source → block" "got $(db source)"
[ "$(db migrations)" = "block" ]  && ok "drift blocks: migrations → block"      || fail "drift blocks: migrations → block" "got $(db migrations)"
# unreachable must BLOCK. pk ship's gate needs an exact sha match, so a rebased
# branch cannot ship at all — allowing the Ready flip would make this gate looser
# than the one it reinforces, and a pre-review rebase would defeat it entirely.
[ "$(db unreachable)" = "block" ] && ok "drift blocks: unreachable → block (fails closed)" || fail "drift blocks: unreachable → block (fails closed)" "got $(db unreachable)"
[ "$(db docs)" = "allow" ]        && ok "drift blocks: docs → allow"            || fail "drift blocks: docs → allow" "got $(db docs)"
[ "$(db fresh)" = "allow" ]       && ok "drift blocks: fresh → allow"           || fail "drift blocks: fresh → allow" "got $(db fresh)"
[ "$(db none)" = "allow" ]        && ok "drift blocks: none → allow (ship gates it)" || fail "drift blocks: none → allow" "got $(db none)"
[ "$(db)" = "allow" ]             && ok "drift blocks: empty arg → allow"       || fail "drift blocks: empty arg → allow" "got $(db)"

echo "== verify drift: evidence lookup + fallback (v4.27.0) =="

sl() { ( cd "$FIXTURE" && source "$PK" && pk_verify_sentinel_latest "$@" ); }

out=$(sl NOPE-1); rc=$?
[ $rc -ne 0 ] && ok "sentinel latest: no artifacts → rc!=0" || fail "sentinel latest: no artifacts → rc!=0" "rc=$rc out='$out'"

# The PIPER-490 shape: no verify-complete.md, sha only in evidence.txt as "# sha:".
# Keying solely on the sentinel would make this gate blind to its own anchor case.
mkdir -p "$FIXTURE/Logs/Verify/20260731/ABC-490"
printf '# sha: %s\n# tier: heavy\n' "$HEAD_SHA" > "$FIXTURE/Logs/Verify/20260731/ABC-490/evidence.txt"
out=$(sl ABC-490)
[ "${out##*$'\t'}" = "$HEAD_SHA" ] && ok "sentinel latest: falls back to evidence.txt '# sha:'" || fail "sentinel latest: falls back to evidence.txt '# sha:'" "got '$out'"

# reality-check.md records a SHORT sha with a "- sha:" marker.
mkdir -p "$FIXTURE/Logs/Verify/20260731/ABC-491"
printf -- '- sha: %s\n' "${HEAD_SHA:0:8}" > "$FIXTURE/Logs/Verify/20260731/ABC-491/reality-check.md"
out=$(sl ABC-491)
[ "${out##*$'\t'}" = "${HEAD_SHA:0:8}" ] && ok "sentinel latest: falls back to reality-check '- sha:' (short)" || fail "sentinel latest: falls back to reality-check '- sha:' (short)" "got '$out'"

# verify-complete.md is authoritative and must win over the weaker fallbacks.
printf 'sha: %s\n' "$OTHER_SHA" > "$FIXTURE/Logs/Verify/20260731/ABC-490/verify-complete.md"
out=$(sl ABC-490)
[ "${out##*$'\t'}" = "$OTHER_SHA" ] && ok "sentinel latest: verify-complete.md outranks evidence.txt" || fail "sentinel latest: verify-complete.md outranks evidence.txt" "got '$out'"
cleanup
FIXTURE=""

echo "== verify drift: branch-ref lookup (v4.27.1) =="
# pk ready is documented as runnable from the parent repo, and pk done runs from
# it BY DESIGN — where the feature branch's verify artifacts are not in the
# checkout at all. Working-tree-only lookup made pk done blind every time.

make_fixture
gitf() { git -C "$FIXTURE" -c user.email=t@t -c user.name=t "$@"; }
sl2() { ( cd "$FIXTURE" && source "$PK" && pk_verify_sentinel_latest "$@" ); }

BRANCH_SHA="1111111111111111111111111111111111111111"
gitf checkout -q -b feature/ABC-7-thing
mkdir -p "$FIXTURE/Logs/Verify/20260101/ABC-7"
printf 'sha: %s\n' "$BRANCH_SHA" > "$FIXTURE/Logs/Verify/20260101/ABC-7/verify-complete.md"
gitf add -A >/dev/null 2>&1; gitf commit -q -m "verify artifacts"
gitf checkout -q main   # parent-repo state: branch artifacts NOT in the checkout

[ ! -e "$FIXTURE/Logs/Verify/20260101/ABC-7" ] && ok "branch ref: artifacts absent from parent checkout (precondition)" || fail "branch ref: artifacts absent from parent checkout (precondition)" "still present"

out=$(sl2 ABC-7); rc=$?
[ $rc -ne 0 ] && ok "branch ref: without a ref, parent-repo lookup finds nothing (the bug)" || fail "branch ref: without a ref, parent-repo lookup finds nothing" "rc=$rc out='$out'"

out=$(sl2 ABC-7 feature/ABC-7-thing)
[ "${out##*$'\t'}" = "$BRANCH_SHA" ] && ok "branch ref: with a ref, branch-only sentinel is found" || fail "branch ref: with a ref, branch-only sentinel is found" "got '$out'"

# Preference is per-artifact, not per-source: the authoritative sentinel on the
# branch must beat a weaker fallback that merely happens to be in the checkout.
WT_SHA="2222222222222222222222222222222222222222"
mkdir -p "$FIXTURE/Logs/Verify/20260101/ABC-7"
printf '# sha: %s\n' "$WT_SHA" > "$FIXTURE/Logs/Verify/20260101/ABC-7/evidence.txt"
out=$(sl2 ABC-7 feature/ABC-7-thing)
[ "${out##*$'\t'}" = "$BRANCH_SHA" ] && ok "branch ref: branch verify-complete.md outranks working-tree evidence.txt" || fail "branch ref: branch verify-complete.md outranks working-tree evidence.txt" "got '$out'"

# An uncommitted sentinel in the worktree is the PIPER-490 case — it must still win.
WT_SENT="3333333333333333333333333333333333333333"
printf 'sha: %s\n' "$WT_SENT" > "$FIXTURE/Logs/Verify/20260101/ABC-7/verify-complete.md"
out=$(sl2 ABC-7 feature/ABC-7-thing)
[ "${out##*$'\t'}" = "$WT_SENT" ] && ok "branch ref: uncommitted worktree sentinel still wins (PIPER-490 case)" || fail "branch ref: uncommitted worktree sentinel still wins" "got '$out'"

out=$(sl2 ABC-7 no/such/branch); rc=$?
[ $rc -eq 0 ] && ok "branch ref: unresolvable ref degrades to working tree, no crash" || fail "branch ref: unresolvable ref degrades to working tree" "rc=$rc"
cleanup
FIXTURE=""

echo "== verify drift: class list not duplicated (v4.27.1 regression guard) =="
# cmd_done restated `source|migrations` inline and so never matched `unreachable`
# once cmd_ready started blocking on it. pk_verify_drift_blocks is the single
# source of truth; both gate call sites must go through it.
BLOCKS_CALLS=$(grep -c 'pk_verify_drift_blocks "' "$PK")
[ "$BLOCKS_CALLS" -ge 2 ] && ok "class list: both gate sites call pk_verify_drift_blocks ($BLOCKS_CALLS)" || fail "class list: both gate sites call pk_verify_drift_blocks" "only $BLOCKS_CALLS call(s)"
DUPES=$(grep -n 'source|migrations' "$PK" | grep -v 'pk_verify_drift_blocks()' | grep -vc 'source|migrations|unreachable' || true)
[ "$DUPES" -eq 0 ] && ok "class list: no partial re-statement of the blocking classes" || fail "class list: no partial re-statement of the blocking classes" "$DUPES site(s) list source|migrations without unreachable"

echo "== verify drift: report against real commits (v4.27.0) =="

make_fixture
gitf() { git -C "$FIXTURE" -c user.email=t@t -c user.name=t "$@"; }
dr() { ( cd "$FIXTURE" && source "$PK" && pk_verify_drift_report "$@" ); }

mkdir -p "$FIXTURE/supabase/migrations" "$FIXTURE/src" "$FIXTURE/Logs/Verify/20260101/ABC-1"
printf 'x\n' > "$FIXTURE/src/a.js"
gitf add -A >/dev/null 2>&1; gitf commit -q -m base
BASE=$(gitf rev-parse HEAD)
printf 'sha: %s\n' "$BASE" > "$FIXTURE/Logs/Verify/20260101/ABC-1/verify-complete.md"

[ "$(dr ABC-1 "$BASE" 2>/dev/null)" = "fresh" ] && ok "drift report: sentinel == HEAD → fresh" || fail "drift report: sentinel == HEAD → fresh" "got $(dr ABC-1 "$BASE" 2>/dev/null)"

# Docs-only drift: the /verify artifacts themselves moving must stay benign, or
# the gate would fire on every normal verify-docs commit.
printf 'note\n' > "$FIXTURE/Logs/Verify/20260101/ABC-1/reality-check.md"
gitf add -A >/dev/null 2>&1; gitf commit -q -m docs
H=$(gitf rev-parse HEAD)
[ "$(dr ABC-1 "$H" 2>/dev/null)" = "docs" ] && ok "drift report: evidence-only drift → docs (benign)" || fail "drift report: evidence-only drift → docs (benign)" "got $(dr ABC-1 "$H" 2>/dev/null)"

printf 'y\n' > "$FIXTURE/src/a.js"
gitf add -A >/dev/null 2>&1; gitf commit -q -m src
H=$(gitf rev-parse HEAD)
[ "$(dr ABC-1 "$H" 2>/dev/null)" = "source" ] && ok "drift report: post-verify source change → source" || fail "drift report: post-verify source change → source" "got $(dr ABC-1 "$H" 2>/dev/null)"

# The PIPER-490 shape: a migration rewritten after the verify that exercised it.
printf 'select 1;\n' > "$FIXTURE/supabase/migrations/20260101_a.sql"
gitf add -A >/dev/null 2>&1; gitf commit -q -m mig
H=$(gitf rev-parse HEAD)
[ "$(dr ABC-1 "$H" 2>/dev/null)" = "migrations" ] && ok "drift report: post-verify migration change → migrations" || fail "drift report: post-verify migration change → migrations" "got $(dr ABC-1 "$H" 2>/dev/null)"

printf 'sha: %s\n' "$OTHER_SHA" > "$FIXTURE/Logs/Verify/20260101/ABC-1/verify-complete.md"
[ "$(dr ABC-1 "$H" 2>/dev/null)" = "unreachable" ] && ok "drift report: orphaned sha (rebase) → unreachable" || fail "drift report: orphaned sha (rebase) → unreachable" "got $(dr ABC-1 "$H" 2>/dev/null)"

[ "$(dr NOPE-9 "$H" 2>/dev/null)" = "none" ] && ok "drift report: no evidence at all → none" || fail "drift report: no evidence at all → none" "got $(dr NOPE-9 "$H" 2>/dev/null)"
cleanup
FIXTURE=""

# ── CLI tests: security-gate ship gate (E2E, v4.17.0) ────────────────────────
# Armed only when the `Security categories` file exists. A verify sentinel is
# planted at HEAD throughout so only the NEW gate varies.

echo "== security-gate ship gate (E2E, v4.17.0) =="

make_fixture
write_config '```
Backend: native
Integration branch: main
Security categories: ./sec-cats.md
```'
git -C "$FIXTURE" checkout -q -b feat/ABC-123-widget
SG_HEAD=$(git -C "$FIXTURE" rev-parse HEAD)
mkdir -p "$FIXTURE/Logs/Verify/20260101/ABC-123"
printf 'sha: %s\n' "$SG_HEAD" > "$FIXTURE/Logs/Verify/20260101/ABC-123/verify-complete.md"
echo "auth: src/auth/**" > "$FIXTURE/sec-cats.md"

# (a) categories file + no secgate sentinel → abort before push/gh.
: > "$GH_LOG"
run_pk ship
g=0; p=0
case "$RUN_OUT" in *"no secgate-complete.md matching"*) g=1 ;; esac
case "$RUN_OUT" in *Pushing*) p=1 ;; esac
if [ $RUN_CODE -ne 0 ] && [ $g -eq 1 ] && [ $p -eq 0 ] && [ ! -s "$GH_LOG" ]; then
  ok "secgate ship: armed + no sentinel aborts before push/gh"
else
  fail "secgate ship: armed + no sentinel aborts before push/gh" "rc=$RUN_CODE gate_msg=$g pushed=$p"
fi

# (a2) --force waives verify ONLY — it must NOT waive an armed secgate (v4.20.0).
#      Verify sentinel is present, so --force here has nothing to do for verify;
#      the split means the security gate still blocks with no secgate sentinel.
: > "$GH_LOG"
run_pk ship --force
g=0; p=0
case "$RUN_OUT" in *"no secgate-complete.md matching"*) g=1 ;; esac
case "$RUN_OUT" in *Pushing*) p=1 ;; esac
if [ $RUN_CODE -ne 0 ] && [ $g -eq 1 ] && [ $p -eq 0 ] && [ ! -s "$GH_LOG" ]; then
  ok "secgate ship: --force does NOT waive the security gate (v4.20.0 split)"
else
  fail "secgate ship: --force does NOT waive the security gate" "rc=$RUN_CODE gate_msg=$g pushed=$p"
fi

# (a3) --force-secgate is the explicit, separate waiver → bypasses (logs, proceeds).
run_pk ship --force-secgate
case "$RUN_OUT" in
  *"bypassed via --force-secgate"*) ok "secgate ship: --force-secgate waives the security gate" ;;
  *) fail "secgate ship: --force-secgate waives the security gate" "output: $(echo "$RUN_OUT" | head -4)" ;;
esac

# (b) HEAD-matching secgate sentinel → passes both gates (reaches push).
mkdir -p "$FIXTURE/Logs/SecurityGate/20260101/ABC-123"
printf 'issue: ABC-123\nstatus: PASS\nsha: %s\n' "$SG_HEAD" \
  > "$FIXTURE/Logs/SecurityGate/20260101/ABC-123/secgate-complete.md"
run_pk ship
case "$RUN_OUT" in
  *Pushing*) ok "secgate ship: HEAD-matching sentinel passes gate" ;;
  *) fail "secgate ship: HEAD-matching sentinel passes gate" "output: $(echo "$RUN_OUT" | head -4)" ;;
esac

# (c) no categories file → gate unarmed → ships without any secgate sentinel
#     (the zero-behavior-change guarantee for un-opted projects).
rm -rf "$FIXTURE/Logs/SecurityGate" "$FIXTURE/sec-cats.md"
run_pk ship
case "$RUN_OUT" in
  *Pushing*) ok "secgate ship: unarmed (no categories file) → no gate" ;;
  *) fail "secgate ship: unarmed (no categories file) → no gate" "output: $(echo "$RUN_OUT" | head -4)" ;;
esac

# (d) PK_SECGATE_BYPASS=1 → armed gate skipped, bypass logged.
echo "auth: src/auth/**" > "$FIXTURE/sec-cats.md"
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" PK_SECGATE_BYPASS=1 "$PK" ship 2>&1)
case "$RUN_OUT" in
  *"bypassed via PK_SECGATE_BYPASS"*) ok "secgate ship: PK_SECGATE_BYPASS=1 skips gate" ;;
  *) fail "secgate ship: PK_SECGATE_BYPASS=1 skips gate" "output: $(echo "$RUN_OUT" | head -4)" ;;
esac
cleanup
FIXTURE=""

# ── CLI tests: prod-ready promote gate (E2E, bare remote, v4.17.0) ───────────
# 2-env chain (dev,main): the only hop IS the final hop, so the gate arms when
# the `Prod-ready checks` file exists. Sentinel sha must match origin/dev.

echo "== prod-ready promote gate (E2E, v4.17.0) =="

make_fixture
PR_REMOTE=$(mktemp -d); git -C "$PR_REMOTE" init -q --bare
git -C "$FIXTURE" remote add origin "$PR_REMOTE"
git -C "$FIXTURE" branch dev
# -u: promote step 1 syncs the source branch with a tracking `git pull --ff-only`.
git -C "$FIXTURE" push -q -u origin main dev 2>/dev/null
git -C "$FIXTURE" checkout -q dev
git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "dev work"
git -C "$FIXTURE" push -q origin dev 2>/dev/null
git -C "$FIXTURE" checkout -q main
# A trivially-green Pre-Deploy Gate: promote step 2 runs cmd_verify, which
# returns 1 when the section is absent — the fixture must pass it to reach
# the prod-ready gate under test.
write_config '```
Backend: native
Integration branch: dev
Ship environments: dev,main
Prod-ready checks: ./prod-checks.md
```

## Pre-Deploy Gate

```bash
true
```'
echo "build: true" > "$FIXTURE/prod-checks.md"
PR_SRC_SHA=$(git -C "$FIXTURE" rev-parse origin/dev)

# (a) checks file + no sentinel → block before the PR opens.
: > "$GH_LOG"
run_pk promote main
g=0; o=0
case "$RUN_OUT" in *"no prodready-complete.md matching"*) g=1 ;; esac
case "$RUN_OUT" in *"Open promote PR"*) o=1 ;; esac
if [ $RUN_CODE -ne 0 ] && [ $g -eq 1 ] && [ $o -eq 0 ]; then
  ok "prodready promote: armed + no sentinel blocks final hop"
else
  fail "prodready promote: armed + no sentinel blocks final hop" "rc=$RUN_CODE gate_msg=$g opened=$o out: $(echo "$RUN_OUT" | tail -3)"
fi

# (b) sentinel matching origin/dev → gate passes, promote proceeds to the PR step.
mkdir -p "$FIXTURE/Logs/ProdReady/20260101"
printf 'status: PASS\nsha: %s\n' "$PR_SRC_SHA" > "$FIXTURE/Logs/ProdReady/20260101/prodready-complete.md"
run_pk promote main
g=0; o=0
case "$RUN_OUT" in *"no prodready-complete.md matching"*) g=1 ;; esac
case "$RUN_OUT" in *"Open promote PR"*) o=1 ;; esac
if [ $g -eq 0 ] && [ $o -eq 1 ]; then
  ok "prodready promote: matching sentinel passes gate"
else
  fail "prodready promote: matching sentinel passes gate" "gate_msg=$g opened=$o out: $(echo "$RUN_OUT" | tail -3)"
fi

# (c) no checks file → gate unarmed → proceeds without any sentinel.
rm -rf "$FIXTURE/Logs/ProdReady" "$FIXTURE/prod-checks.md"
run_pk promote main
g=0; o=0
case "$RUN_OUT" in *"no prodready-complete.md matching"*) g=1 ;; esac
case "$RUN_OUT" in *"Open promote PR"*) o=1 ;; esac
if [ $g -eq 0 ] && [ $o -eq 1 ]; then
  ok "prodready promote: unarmed (no checks file) → no gate"
else
  fail "prodready promote: unarmed (no checks file) → no gate" "gate_msg=$g opened=$o out: $(echo "$RUN_OUT" | tail -3)"
fi
rm -rf "$PR_REMOTE"
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

  # Cmd-subst heredoc commit (git commit -m "$(cat <<EOF ... )"): the -m value has no
  # closing quote on its line — the subject is heredoc line 1, NOT the literal "$(cat".
  # Pre-fix this false-fired with: does not match format ... Got: $(cat <<EOF
  out=$(hook_run '{"tool_input":{"command":"git commit -m \"$(cat <<EOF\nbad cmdsubst subject\nbody line\nEOF\n)\""}}')
  case "$out" in
    *"bad cmdsubst subject"*) ok "hook: -m cmd-subst heredoc subject validated" ;;
    *) fail "hook: -m cmd-subst heredoc subject validated" "output: $out" ;;
  esac

  out=$(hook_run '{"tool_input":{"command":"git commit -m \"$(cat <<'"'EOF'"'\nchore(release): v9.9.9 — subject in heredoc\nbody line\nEOF\n)\""}}')
  [ -z "$out" ] && ok "hook: -m cmd-subst heredoc good subject silent" || fail "hook: -m cmd-subst heredoc good subject silent" "output: $out"

  # Markdown inline code in a --body string: backtick-preceded "git commit" is DATA,
  # not legacy-backtick cmd-subst. Pre-fix, the doc-prose counted as a bare invocation
  # and a <<EOF elsewhere in the prose captured the NEXT body line as a "subject".
  out=$(hook_run '{"tool_input":{"command":"gh pr comment 1 --body \"- `git commit -m x` no longer misfires (the <<EOF shape)\nsecond body line\""}}')
  [ -z "$out" ] && ok "hook: markdown-backtick commit doc in --body not validated" || fail "hook: markdown-backtick commit doc in --body not validated" "output: $out"

  printf '%s' '{"tool_input":{"command":"git commit -m \"nope\""}}' | bash "$HOOK" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "hook: always exit 0 (advisory)" || fail "hook: always exit 0 (advisory)" "nonzero exit"
fi

# ── Unit tests: Linear write guard verdict (sourced, no network) ─────────────
# pk_linear_guard_verdict is pure: (team_id, slug, reachable, resolved_team,
# resolved_org_key) → "ok" | "skip:<why>" | "fail:<why>". It gates every Linear
# mutation at the pk_linear_gql chokepoint. Team ID (a globally-unique UUID) is
# the strong pin; Workspace slug is the fallback. Fails CLOSED only on a
# confirmed mismatch; fails OPEN (skip) when Linear is unreachable so a transient
# hiccup never false-blocks the daily loop.
unit_guard() { ( cd "$REPO_ROOT" && source "$PK" && pk_linear_guard_verdict "$@" ); }

case "$(unit_guard "TID-uuid" "" 1 "Eng" "")" in
  ok) ok "guard: team id resolves under token → ok" ;;
  *)  fail "guard: team id resolves under token → ok" "got: $(unit_guard "TID-uuid" "" 1 "Eng" "")" ;;
esac

case "$(unit_guard "TID-uuid" "" 1 "" "")" in
  fail:*) ok "guard: team id not visible → fail closed" ;;
  *)      fail "guard: team id not visible → fail closed" "got: $(unit_guard "TID-uuid" "" 1 "" "")" ;;
esac

case "$(unit_guard "TID-uuid" "piper-poc" "" "" "")" in
  skip:*) ok "guard: unreachable → skip (fail open)" ;;
  *)      fail "guard: unreachable → skip (fail open)" "got: $(unit_guard "TID-uuid" "piper-poc" "" "" "")" ;;
esac

case "$(unit_guard "" "piper-poc" 1 "" "piper-poc")" in
  ok) ok "guard: slug matches org urlKey → ok" ;;
  *)  fail "guard: slug matches org urlKey → ok" "got: $(unit_guard "" "piper-poc" 1 "" "piper-poc")" ;;
esac

case "$(unit_guard "" "piper-poc" 1 "" "other-org")" in
  fail:*) ok "guard: slug mismatch → fail closed" ;;
  *)      fail "guard: slug mismatch → fail closed" "got: $(unit_guard "" "piper-poc" 1 "" "other-org")" ;;
esac

case "$(unit_guard "" "" 1 "" "")" in
  skip:*) ok "guard: no pin configured → skip" ;;
  *)      fail "guard: no pin configured → skip" "got: $(unit_guard "" "" 1 "" "")" ;;
esac

# ── CLI tests: check-migration-drift.sh (gap #1 Tier 2, v4.18.0) ─────────────
# Git-only checks A (branch collision vs base tail — the WIT-550 class) and
# B (duplicate versions on disk). The --remote check needs a live supabase
# link and is not smoke-testable; A+B are what the CI template runs.

echo "== check-migration-drift (v4.18.0) =="

DRIFT_SH="$REPO_ROOT/scripts/check-migration-drift.sh"

make_fixture
# (1) No Migration dir configured → clean skip, exit 0.
write_config '```
Backend: native
```'
out=$(cd "$FIXTURE" && "$DRIFT_SH" 2>&1); rc=$?
[ $rc -eq 0 ] && case "$out" in *skipping*) ok "drift: no Migration dir → skip (exit 0)" ;; *) fail "drift: no Migration dir → skip (exit 0)" "out: $out" ;; esac \
  || fail "drift: no Migration dir → skip (exit 0)" "rc=$rc"

# Build a migration history: base (main) carries 001+003, feature branches vary.
write_config '```
Backend: native
Integration branch: main
Migration dir: db/migrations
```'
mkdir -p "$FIXTURE/db/migrations"
echo "select 1;" > "$FIXTURE/db/migrations/20260101000000_init.sql"
echo "select 3;" > "$FIXTURE/db/migrations/20260103000000_third.sql"
git -C "$FIXTURE" add -A
git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -qm "base migrations"

# (2) Clean: feature adds a migration strictly later than the base tail.
git -C "$FIXTURE" checkout -qb feat/clean
echo "select 4;" > "$FIXTURE/db/migrations/20260104000000_fourth.sql"
git -C "$FIXTURE" add -A && git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -qm "later migration"
out=$(cd "$FIXTURE" && "$DRIFT_SH" --base main 2>&1); rc=$?
[ $rc -eq 0 ] && case "$out" in *"no migration drift"*) ok "drift: later-than-tail migration is clean" ;; *) fail "drift: later-than-tail migration is clean" "out: $out" ;; esac \
  || fail "drift: later-than-tail migration is clean" "rc=$rc out: $out"

# (3) Collision: feature adds a migration EARLIER than the base tail (WIT-550).
git -C "$FIXTURE" checkout -q main && git -C "$FIXTURE" checkout -qb feat/collide
echo "select 2;" > "$FIXTURE/db/migrations/20260102000000_backdated.sql"
git -C "$FIXTURE" add -A && git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -qm "backdated migration"
out=$(cd "$FIXTURE" && "$DRIFT_SH" --base main 2>&1); rc=$?
[ $rc -eq 1 ] && case "$out" in *"branch collision"*) ok "drift: earlier-than-tail migration flagged (WIT-550 class)" ;; *) fail "drift: earlier-than-tail migration flagged (WIT-550 class)" "out: $out" ;; esac \
  || fail "drift: earlier-than-tail migration flagged (WIT-550 class)" "rc=$rc (want 1)"

# (4) Duplicate version prefixes on disk → exit 1.
git -C "$FIXTURE" checkout -q main
echo "select 3b;" > "$FIXTURE/db/migrations/20260103000000_dupe.sql"
out=$(cd "$FIXTURE" && "$DRIFT_SH" --base main 2>&1); rc=$?
[ $rc -eq 1 ] && case "$out" in *"duplicate migration version"*) ok "drift: duplicate version on disk flagged" ;; *) fail "drift: duplicate version on disk flagged" "out: $out" ;; esac \
  || fail "drift: duplicate version on disk flagged" "rc=$rc (want 1)"

# (5) Unresolvable base ref → warn + still exit 0 (never false-block).
rm -f "$FIXTURE/db/migrations/20260103000000_dupe.sql"
out=$(cd "$FIXTURE" && "$DRIFT_SH" --base origin/nope 2>&1); rc=$?
[ $rc -eq 0 ] && case "$out" in *"not resolvable"*) ok "drift: unresolvable base warns, never false-blocks" ;; *) fail "drift: unresolvable base warns, never false-blocks" "out: $out" ;; esac \
  || fail "drift: unresolvable base warns, never false-blocks" "rc=$rc (want 0)"
cleanup
FIXTURE=""

# ── Unit tests: spec-cycle trigger body is append-only (sourced) ─────────────
# Through v4.24.0 the trigger told the Linear agent to REPLACE the existing
# `## Agent Review` section, so pass 2 destroyed pass 1's rationale and pass 3
# destroyed both — including the human stalemate-override note that
# /02-light-spec-revise writes there and forbids deleting. Pure string
# generation, so no fixture or Linear call needed.

# ── /verify Step 7 writes the sha deterministically (v4.27.2) ────────────────
# reality-check.md is the fallback pk_verify_sentinel_latest reads when
# verify-complete.md is absent, so a missing `sha:` line silently downgrades the
# drift gate to "no evidence". Prose-rendered markdown drifts: measured on
# SiteLine 2026-08-02, the heredoc-written verify-complete.md carried a sha in
# 191/192 files while the prose-rendered reality-check.md managed 167/195, with
# the miss rate rising month over month. Step 7 must stay a heredoc.

echo "== /verify Step 7 sha determinism (v4.27.2) =="

VERIFY_SKILL="$REPO_ROOT/skills/verify/SKILL.md"
if [ ! -f "$VERIFY_SKILL" ]; then
  fail "verify step7: skill present" "missing $VERIFY_SKILL"
else
  step7=$(awk '/^## Step 7 /{f=1} /^## Step 8 /{f=0} f' "$VERIFY_SKILL")
  case "$step7" in
    *'cat > "$VERIFY_DIR/reality-check.md" <<EOF'*)
      ok "verify step7: reality-check.md written via heredoc" ;;
    *)
      fail "verify step7: reality-check.md written via heredoc" "no heredoc in Step 7 — prose rendering will drop the sha" ;;
  esac
  case "$step7" in
    *'- sha: $SHA'*) ok "verify step7: sha line interpolates a shell var" ;;
    *)              fail "verify step7: sha line interpolates a shell var" "sha line is a placeholder, not \$SHA" ;;
  esac
  case "$step7" in
    *'SHA=$(git rev-parse HEAD)'*) ok "verify step7: SHA assigned from git rev-parse HEAD" ;;
    *)                             fail "verify step7: SHA assigned from git rev-parse HEAD" "SHA never assigned" ;;
  esac
  # Step 8 consumes $STATUS but nothing used to assign it — a latent version of
  # the same drift, since an unset STATUS silently skips the sentinel write.
  case "$step7" in
    *'STATUS="PASS"'*) ok "verify step7: STATUS explicitly assigned for Step 8" ;;
    *)                 fail "verify step7: STATUS explicitly assigned for Step 8" "STATUS left implicit" ;;
  esac
fi

echo "== spec-cycle trigger body (sourced) =="

body=$( source "$PK" && pk_spec_cycle_trigger_body 2 )

case "$body" in
  *"replacing the existing"*|*"replace the existing"*)
    fail "spec-cycle: trigger never instructs a replace" "body still says replace" ;;
  *) ok "spec-cycle: trigger never instructs a replace" ;;
esac

case "$body" in
  *"by appending, never replacing"*) ok "spec-cycle: trigger instructs append" ;;
  *) fail "spec-cycle: trigger instructs append" "append instruction missing" ;;
esac

case "$body" in
  *"### Review 2 "*) ok "spec-cycle: trigger stamps the pass number" ;;
  *) fail "spec-cycle: trigger stamps the pass number" "no '### Review 2' in body" ;;
esac

# The prior-block protection is the load-bearing clause — an append instruction
# without it still lets an agent "tidy" earlier passes away.
case "$body" in
  *"do NOT remove human commentary"*) ok "spec-cycle: trigger protects prior blocks + human notes" ;;
  *) fail "spec-cycle: trigger protects prior blocks + human notes" "protection clause missing" ;;
esac

# Unstamped call must not emit a literal placeholder as if it were a number.
body=$( source "$PK" && pk_spec_cycle_trigger_body )
case "$body" in
  *"### Review N "*) ok "spec-cycle: unstamped call degrades to a readable placeholder" ;;
  *) fail "spec-cycle: unstamped call degrades to a readable placeholder" "no placeholder in body" ;;
esac

# ── Skills cite method.config.md for values, not prose (v4.28.1) ─────────────
# method.config.md is project-owned and NEVER synced, so a section that exists
# only in method.config.template.md reaches new projects and no existing
# consumer. A skill citing one is a live pointer into a file the reader's repo
# does not contain, and it fails silently — the session looks, finds nothing,
# and proceeds on what it already believed. v4.28.0 shipped exactly this:
# /roadmap-create pointed at a `§ Board shapes` subsection that was dangling on
# both consumers the day it shipped. A pointer is legitimate only when its leaf
# resolves to a template section carrying a `| **Key** |` row, or to such a key
# itself. Rule: sop/Skills_SOP.md § Cite method.config.md for values.

echo "== skills cite method.config.md for values, not prose =="
if ! command -v python3 >/dev/null 2>&1; then
  ok "config pointers: python3 unavailable → skipped"
else
  cfg_out=$(python3 - "$REPO_ROOT" <<'PYEOF'
import re, sys, glob, os
root = sys.argv[1]
tmpl = open(os.path.join(root, 'method.config.template.md')).read()
KEY_ROW = r'\|\s*\*\*[^*]+\*\*\s*\|'
parts = re.split(r'^(#{2,4}) (.+)$', tmpl, flags=re.M)
secs = {}
for i in range(1, len(parts), 3):
    title = re.split(r'\s+\(', parts[i + 1].strip())[0].strip().lower()
    secs.setdefault(title, []).append(parts[i + 2])
keys = {k.strip().lower() for k in re.findall(r'\|\s*\*\*([^*]+)\*\*\s*\|', tmpl)}
bad = []
for f in sorted(glob.glob(os.path.join(root, 'skills', '*', 'SKILL.md'))):
    seen = set()
    for ref in re.findall(r'`method\.config\.md § ([^`]+)`', open(f).read()):
        leaf = ref.split('→')[-1].strip()
        if leaf in seen:
            continue
        seen.add(leaf)
        low = leaf.lower()
        if low in keys:
            continue
        if low not in secs:
            bad.append(f"{os.path.basename(os.path.dirname(f))} § {ref} (no such section or key)")
        elif not any(re.search(KEY_ROW, b) for b in secs[low]):
            bad.append(f"{os.path.basename(os.path.dirname(f))} § {ref} (prose-only section)")
print('; '.join(bad))
PYEOF
)
  if [ -z "$cfg_out" ]; then
    ok "config pointers: every skill § cite resolves to a config value"
  else
    fail "config pointers: skill cites prose a consumer's config won't have" "$cfg_out"
  fi
fi

# ── Scaffold-once manifest is well-formed (v4.29.0) ──────────────────────────
# .scaffold-once-skills declares which portable skills a consumer's sync
# seeds once and then never touches again (sop/Skills_SOP.md § Syncing
# Portable Skills). A stale entry — a name with no matching skills/<name>/ —
# would silently no-op in sync-method.sh's loop rather than fail, so check it
# here instead.

echo "== scaffold-once manifest =="
if [ ! -f "$REPO_ROOT/.scaffold-once-skills" ]; then
  ok "scaffold-once: no manifest present → skipped"
else
  missing=""
  while IFS= read -r name; do
    case "$name" in ""|\#*) continue ;; esac
    [ -f "$REPO_ROOT/skills/$name/SKILL.md" ] || missing="$missing $name"
  done < "$REPO_ROOT/.scaffold-once-skills"
  if [ -z "$missing" ]; then
    ok "scaffold-once: every declared skill has a matching skills/<name>/SKILL.md"
  else
    fail "scaffold-once: manifest names a skill with no source" "$missing"
  fi
fi

# ── Dogfood mirror freshness (local only) ────────────────────────────────────
# .claude/skills|rules|agents are generated mirrors of tracked sources, used by
# Claude Code sessions in THIS repo. They are gitignored, so they do not exist
# on a CI checkout — skip there rather than fail. Locally, a stale mirror means
# your own /verify, /work etc. are running old code: on 2026-07-31 the mirror
# was 157 lines behind and still carried the ${PIPESTATUS[0]} gate bug that the
# same release had just fixed.

echo "== dogfood mirror freshness =="
if [ ! -d "$REPO_ROOT/.claude/skills" ]; then
  ok "dogfood: no local mirror (CI checkout) → skipped"
elif bash "$REPO_ROOT/scripts/dogfood-sync.sh" --check >/dev/null 2>&1; then
  ok "dogfood: .claude/ mirrors match their tracked sources"
else
  fail "dogfood: .claude/ mirrors are stale" "run scripts/dogfood-sync.sh"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo
echo "pk smoke: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo "failed:$FAILED_NAMES"
  exit 1
fi
