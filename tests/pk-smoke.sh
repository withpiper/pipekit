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
Migration dir: supabase/migrations
Ship environments: dev,beta,main
Quoted key: `backticked`
```
'
unit_config() {
  # Runs in a subshell so sourcing pk never leaks into the harness.
  ( cd "$FIXTURE" && source "$PK" && pk_config "$@" )
}

v=$(unit_config "Migration dir" "")
[ "$v" = "supabase/migrations" ] && ok "config: code-block form" || fail "config: code-block form" "got '$v', want 'supabase/migrations'"

v=$(unit_config "Quoted key" "")
[ "$v" = "backticked" ] && ok "config: backticks stripped" || fail "config: backticks stripped" "got '$v'"

v=$(unit_config "Nonexistent" "fallback")
[ "$v" = "fallback" ] && ok "config: default fallback" || fail "config: default fallback" "got '$v'"

write_config '# Config

| Key | Value | Notes |
|-----|-------|-------|
| **Migration dir** | `db/migrate` | legacy table form |
'
v=$(unit_config "Migration dir" "")
[ "$v" = "db/migrate" ] && ok "config: legacy table form" || fail "config: legacy table form" "got '$v', want 'db/migrate'"

write_config '# Config

| **Migration dir** | `db/migrate` | table says db/migrate |

```
Migration dir: supabase/migrations
```
'
v=$(unit_config "Migration dir" "")
[ "$v" = "supabase/migrations" ] && ok "config: code-block wins over table" || fail "config: code-block wins over table" "got '$v', want 'supabase/migrations'"

# The template's V2 table: a blank Value cell, or a cell holding a format hint
# instead of a value, must fall through to the default — a fresh `pk init`
# project used to resolve its Linear key to the literal "name, e.g. LINEAR_API_KEY".
write_config '# Config

| Key | Value | Format | Default | Used by |
|-----|-------|--------|---------|---------|
| **Linear API key env var** |  | name, e.g. `LINEAR_API_KEY` | `LINEAR_API_KEY` | `pk *` |
| **Linear transport** | `api` \| `mcp` | | `api` | skills |
| **Migration dir** | e.g. `supabase/migrations/` | | (none) | reviews |
'
v=$(unit_config "Linear API key env var" "LINEAR_API_KEY")
[ "$v" = "LINEAR_API_KEY" ] && ok "config: blank table cell → default" || fail "config: blank table cell → default" "got '$v'"
v=$(unit_config "Linear transport" "api")
[ "$v" = "api" ] && ok "config: 'a \| b' hint cell → default" || fail "config: 'a \| b' hint cell → default" "got '$v'"
v=$(unit_config "Migration dir" "")
[ -z "$v" ] && ok "config: 'e.g. …' hint cell → default" || fail "config: 'e.g. …' hint cell → default" "got '$v'"

# The key variable's NAME comes from the config and reaches the process env
# by indirect expansion — never eval. A non-name reads as unset and says so.
write_config '```
Linear API key env var: PKTEST_LINEAR_KEY
```'
v=$( cd "$FIXTURE" && source "$PK" && PKTEST_LINEAR_KEY=lin_test pk_linear_api_key 2>/dev/null )
[ "$v" = "lin_test" ] && ok "api key: resolved from the named env var" || fail "api key: resolved from the named env var" "got '$v'"
write_config '```
Linear API key env var: x:-}; touch INJECTED; :${y
```'
v=$( cd "$FIXTURE" && source "$PK" && pk_linear_api_key 2>"$FIXTURE/.err" )
if [ -z "$v" ] && [ ! -e "$FIXTURE/INJECTED" ] && grep -q "not a variable name" "$FIXTURE/.err"; then
  ok "api key: non-name var reads as unset, nothing executed"
else
  fail "api key: non-name var reads as unset, nothing executed" "got '$v' injected=$([ -e "$FIXTURE/INJECTED" ] && echo yes || echo no) err=$(cat "$FIXTURE/.err")"
fi

# Ship environments left blank derives from the integration branch, and pk done
# and pk promote read the same derivation (they used to default differently).
unit_first_env() { ( cd "$FIXTURE" && source "$PK" && pk_first_env_state_name ); }
unit_ship_envs() { ( cd "$FIXTURE" && source "$PK" && pk_ship_envs ); }
write_config '```
Integration branch: dev
```'
v=$(unit_ship_envs); [ "$v" = "dev,main" ] && ok "ship envs: blank + dev integration → dev,main" || fail "ship envs: blank + dev integration → dev,main" "got '$v'"
v=$(unit_first_env); [ "$v" = "In Dev" ] && ok "ship envs: pk done lands on In Dev for a dev-integrated project" || fail "ship envs: pk done lands on In Dev" "got '$v'"
write_config '```
Integration branch: main
```'
v=$(unit_first_env); [ "$v" = "Done" ] && ok "ship envs: blank + main integration → single-tier (Done)" || fail "ship envs: blank + main → Done" "got '$v'"
write_config '```
Integration branch: dev
Ship environments: main
```'
v=$(unit_first_env); [ "$v" = "Done" ] && ok "ship envs: an explicit chain wins over the derivation" || fail "ship envs: explicit wins" "got '$v'"

# Merge method: the gh pr merge strategy pk done --merge uses, validated.
unit_merge() { ( cd "$FIXTURE" && source "$PK" && pk_merge_method 2>/dev/null ); }
write_config '```
Team name: Eng
```'
v=$(unit_merge); [ "$v" = "merge" ] && ok "merge method: blank → merge" || fail "merge method: blank → merge" "got '$v'"
write_config '```
Merge method: rebase
```'
v=$(unit_merge); [ "$v" = "rebase" ] && ok "merge method: rebase honoured" || fail "merge method: rebase honoured" "got '$v'"
write_config '```
Merge method: fast-forward
```'
v=$(unit_merge); code=$?
[ $code -eq 2 ] && [ -z "$v" ] && ok "merge method: unknown value refused (exit 2)" || fail "merge method: unknown value refused" "exit $code, got '$v'"

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

# ── Unit tests: supabase workdir for pk done's migration check (sourced) ─────
# pk done runs `supabase migration list`; with the chain in a subdir (Migration dir
# "apps/legacy/supabase/migrations/") a bare call from the repo root wrote
# <root>/supabase/.temp and, with no link there, reported every migration "not matched".

echo "== supabase workdir (sourced) =="

unit_sbwd()  { ( cd "$REPO_ROOT" && source "$PK" && pk_supabase_workdir "$1" ); }
unit_sbln()  { ( cd "$REPO_ROOT" && source "$PK" && pk_supabase_linked "$1" ); }

for case_ in "supabase/migrations/|." "supabase/migrations|." "apps/legacy/supabase/migrations/|apps/legacy" \
             "a/b/c/supabase/migrations|a/b/c" "db/migrations/|." "prisma/migrations/|."; do
  in="${case_%%|*}"; want="${case_##*|}"
  v=$(unit_sbwd "$in")
  [ "$v" = "$want" ] && ok "supabase workdir: '$in' → '$want'" || fail "supabase workdir: '$in'" "got '$v', want '$want'"
done

LINKD=$(mktemp -d)
unit_sbln "$LINKD" && fail "supabase linked: no .temp → not linked" "reported linked" || ok "supabase linked: no .temp → not linked"
mkdir -p "$LINKD/supabase/.temp" && : > "$LINKD/supabase/.temp/project-ref"
unit_sbln "$LINKD" && fail "supabase linked: empty project-ref → not linked" "reported linked" || ok "supabase linked: empty project-ref → not linked"
echo "abcdefghijklmnopqrst" > "$LINKD/supabase/.temp/project-ref"
unit_sbln "$LINKD" && ok "supabase linked: project-ref present → linked" || fail "supabase linked: project-ref present" "reported not linked"
rm -rf "$LINKD"

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

# Blocker In Progress → blocked; Done/Canceled → ready; none → ready. A merged
# blocker parked in a post-merge "In <Env>" state is ready too (its code is on the
# base branch already); "In Progress" is the one "In " state that still blocks.
DEP_IN='[
  {"identifier":"A","title":"open blocker","priority":1,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"X1","state":{"name":"In Progress"}}}]}},
  {"identifier":"B","title":"done blocker","priority":3,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"X2","state":{"name":"Done"}}}]}},
  {"identifier":"C","title":"cancelled blocker","priority":3,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"X3","state":{"name":"Canceled"}}}]}},
  {"identifier":"D","title":"no relations","priority":4,"inverseRelations":{"nodes":[]}},
  {"identifier":"E","title":"merged blocker","priority":3,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"X5","state":{"name":"In Beta"}}}]}},
  {"identifier":"F","title":"uat blocker","priority":3,"inverseRelations":{"nodes":[{"type":"blocks","issue":{"identifier":"X6","state":{"name":"UAT"}}}]}}
]'
ann=$(printf '%s' "$DEP_IN" | unit_annotate)
v=$(printf '%s' "$ann" | jq -c '[.[] | {id:.identifier, blocked:.blocked}]')
[ "$v" = '[{"id":"A","blocked":true},{"id":"B","blocked":false},{"id":"C","blocked":false},{"id":"D","blocked":false},{"id":"E","blocked":false},{"id":"F","blocked":true}]' ] \
  && ok "annotate: In Progress/UAT blocker→blocked; Done/Canceled/In <Env>/none→ready" \
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
  E — merged blocker
  D — no relations
  A — open blocker  ⛔ blocked by X1
  F — uat blocker  ⛔ blocked by X6'
[ "$out" = "$exp" ] && ok "flat render: ready-first, blocked sunk + tagged" || fail "flat render" "got:
$out"

# Fail-safe: an issue with NO inverseRelations field at all → ready, no crash.
v=$(printf '%s' '[{"identifier":"N","priority":2}]' | unit_annotate | jq -c '.[0].blocked')
[ "$v" = "false" ] && ok "annotate: absent inverseRelations → ready (fail-safe)" || fail "annotate: absent relations" "got $v"

# ── Unit tests: focus lanes (sourced) ────────────────────────────────────────
# pk_focus_lanes_json maps Linear PROJECT priority 1/2/3 → tier A/B/C (0/4 = not
# in focus), drops completed/canceled projects, orders A,B,C and flags a tier
# held by two lanes as dup (kept, never hidden). Tags parse both P<N>. and
# I<N>.P<N>. names; pk_focus_lane_match backs `pk next --lane`.

echo "== focus lanes (sourced) =="

unit_lanes()   { ( cd "$REPO_ROOT" && source "$PK" && pk_focus_lanes_json ); }
unit_lane_m()  { ( cd "$REPO_ROOT" && source "$PK" && pk_focus_lane_match "$1" ); }
unit_strip()   { ( cd "$REPO_ROOT" && source "$PK" && pk_focus_strip ); }
unit_support() { ( cd "$REPO_ROOT" && source "$PK" && pk_focus_supporting_json "$1" ); }

FOCUS_FIX='{"data":{"initiatives":{"nodes":[
  {"name":"i5. Build","status":"Active","projects":{"nodes":[
    {"id":"c","name":"I5.P1. Medium lane","state":"started","priority":3},
    {"id":"a","name":"P2. Urgent lane","state":"planned","priority":1},
    {"id":"b","name":"I5.P3. High lane","state":"backlog","priority":2},
    {"id":"x","name":"I5.P4. Done but urgent","state":"completed","priority":1},
    {"id":"y","name":"I5.P5. Low","state":"planned","priority":4},
    {"id":"z","name":"I5.P6. None","state":"planned","priority":0}]}},
  {"name":"Theme","status":"Active","projects":{"nodes":[{"id":"t","name":"P3. Theme lane","state":"planned","priority":3}]}}
]}}}'

v=$(printf '%s' "$FOCUS_FIX" | unit_lanes | jq -c 'map([.tier, .tag])')
[ "$v" = '[["A","I5.P2"],["B","I5.P3"],["C","I5.P1"],["C","P3"]]' ] \
  && ok "focus: priority→tier, ordered A,B,C; completed/Low/None excluded; P2.→I5.P2, I5.P3.→I5.P3, theme P3.→P3" \
  || fail "focus: lanes derivation" "got $v"

v=$(printf '%s' "$FOCUS_FIX" | unit_lanes | jq -c 'map(.dup)')
[ "$v" = '[false,false,true,true]' ] && ok "focus: dup flagged only on the shared tier (C), both kept" || fail "focus: dup flag" "got $v"

v=$(printf '%s' '{"data":{"initiatives":{"nodes":[{"name":"i1. X","status":"Active","projects":{"nodes":[{"id":"p","name":"I1.P1. Y","state":"planned","priority":0}]}}]}}}' | unit_lanes)
[ "$v" = '[]' ] && ok "focus: no prioritized project → [] (pk next output unchanged)" || fail "focus: no lanes" "got $v"

v=$(printf '%s' '' | unit_lanes 2>/dev/null || true)
[ -z "$v" ] || [ "$v" = '[]' ] && ok "focus: empty input → no crash" || fail "focus: empty input" "got '$v'"

# --lane matcher: case-insensitive, trailing dot tolerated, bare P<N> matches the
# I<N>.P<N> tag; a Low-priority lane is still pinnable; unknown tag → [].
v=$(printf '%s' "$FOCUS_FIX" | unit_lane_m "i5.p5." | jq -c 'map([.tier, .tag, .dup])')
[ "$v" = '[["A","I5.P5",false]]' ] && ok "lane match: i5.p5. → I5.P5 as sole tier A (priority ignored)" || fail "lane match: exact" "got $v"
v=$(printf '%s' "$FOCUS_FIX" | unit_lane_m "P2" | jq -c 'map(.tag)')
[ "$v" = '["I5.P2"]' ] && ok "lane match: bare P2 matches I5.P2" || fail "lane match: bare P" "got $v"
v=$(printf '%s' "$FOCUS_FIX" | unit_lane_m "I9.P9")
[ "$v" = '[]' ] && ok "lane match: unknown tag → [] (caller errors)" || fail "lane match: unknown" "got $v"
v=$(printf '%s' "$FOCUS_FIX" | unit_lane_m "I5.P4")
[ "$v" = '[]' ] && ok "lane match: completed project not pinnable" || fail "lane match: completed" "got $v"

# pk status strip.
v=$(printf '%s' '[{"tier":"A","tag":"I8.P6"},{"tier":"C","tag":"I8.P5"},{"tier":"C","tag":"I8.P7"}]' | unit_strip)
[ "$v" = 'Focus  A I8.P6 · B — · C I8.P5+I8.P7' ] && ok "focus strip: A/B/C with — for empty tier, + for dup" || fail "focus strip" "got '$v'"
v=$(printf '%s' '[]' | unit_strip)
[ -z "$v" ] && ok "focus strip: no lanes → no line" || fail "focus strip: empty" "got '$v'"

# Supporting group: open blockers of lane issues, deduped, tier = best tier they
# unblock, blockers inside a focus lane excluded, Done blockers excluded.
SUP_IN='[
  {"identifier":"L1","laneTier":"B","inverseRelations":{"nodes":[
    {"type":"blocks","issue":{"identifier":"S1","title":"shared blocker","priority":3,"state":{"name":"Approved"},"project":{"name":"I8.P2. Other"}}},
    {"type":"blocks","issue":{"identifier":"S2","title":"in-lane blocker","priority":1,"state":{"name":"Approved"},"project":{"name":"I8.P6. Lane"}}},
    {"type":"related","issue":{"identifier":"R1","title":"related only","priority":1,"state":{"name":"Approved"},"project":null}}]}},
  {"identifier":"L2","laneTier":"A","inverseRelations":{"nodes":[
    {"type":"blocks","issue":{"identifier":"S1","title":"shared blocker","priority":3,"state":{"name":"Approved"},"project":{"name":"I8.P2. Other"}}},
    {"type":"blocks","issue":{"identifier":"S3","title":"done blocker","priority":1,"state":{"name":"Done"},"project":null}},
    {"type":"blocks","issue":{"identifier":"S4","title":"orphan blocker","priority":2,"state":{"name":"Needs Spec"},"project":null}}]}}
]'
v=$(printf '%s' "$SUP_IN" | unit_support '["I8.P6. Lane"]' | jq -c 'map([.identifier, .tier])')
[ "$v" = '[["S4","A"],["S1","A"]]' ] \
  && ok "supporting: deduped, inherits best tier (S1: B+A→A), in-lane/Done/related excluded, priority-sorted" \
  || fail "supporting" "got $v"

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

for sub in ship done promote branch next ready status focus; do
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

# The usage text carries backticks; an unquoted heredoc ran them as commands
# and printed "Area: command not found" on every --help and unknown-subcommand path.
run_pk --help
case "$RUN_OUT" in
  *"command not found"*) fail "pk --help runs none of its own text" "$(echo "$RUN_OUT" | grep 'command not found' | head -1)" ;;
  *'`Area:`'*) ok "pk --help runs none of its own text" ;;
  *) fail "pk --help runs none of its own text" "backticked text missing from usage" ;;
esac

# ── CLI tests: ship guard rails ──────────────────────────────────────────────

echo "== ship guard rails =="

# ship swallowed unknown flags, so a typo (`--revew`) shipped anyway. Every
# other verb rejects with exit 2 before touching gh; ship now matches.
: > "$GH_LOG"
run_pk ship --revew
if [ $RUN_CODE -eq 2 ] && [ ! -s "$GH_LOG" ]; then
  case "$RUN_OUT" in *"unknown arg"*) ok "ship: unknown flag rejected (exit 2, no gh)" ;; *) fail "ship: unknown flag rejected (exit 2, no gh)" "output: $RUN_OUT" ;; esac
else
  fail "ship: unknown flag rejected (exit 2, no gh)" "exit $RUN_CODE gh=$(cat "$GH_LOG")"
fi

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

# A pk from another clone, run against this project, is named with both
# versions and fails doctor — it used to report the running pk's version as
# the project's sync state, so a stale symlink looked up to date.
mkdir -p "$FIXTURE/bin" && printf '#!/usr/bin/env bash\nPK_VERSION="1.2.3"\n' > "$FIXTURE/bin/pk"
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" METHOD_REPO="$METHOD_FIXTURE" "$PK" doctor 2>&1)
case "$RUN_OUT" in
  *"not this project's bin/pk (v1.2.3)"*) ok "doctor: a foreign pk is named, with the project's own version" ;;
  *) fail "doctor: a foreign pk is named, with the project's own version" "$(echo "$RUN_OUT" | grep -i 'bin/pk' | head -2)" ;;
esac
case "$RUN_OUT" in
  *"synced Pipekit is v1.2.3"*) ok "doctor: staleness reads the project's bin/pk version" ;;
  *) fail "doctor: staleness reads the project's bin/pk version" "$(echo "$RUN_OUT" | grep -i 'synced' | head -2)" ;;
esac
rm -rf "${FIXTURE:?}/bin"

# Template placeholders fail doctor instead of passing as a configured team.
write_config '```
Project name: your-project
Team name: YourTeam
Team ID: 00000000-0000-0000-0000-000000000000
```'
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" METHOD_REPO="$FIXTURE/no-such-repo.git" "$PK" doctor 2>&1)
case "$RUN_OUT" in
  *"template placeholder for: 'Project name' 'Team name' 'Team ID'"*) ok "doctor: template placeholders are an error, not a configured team" ;;
  *) fail "doctor: template placeholders are an error, not a configured team" "$(echo "$RUN_OUT" | grep -i 'team\|placeholder' | head -3)" ;;
esac
rm -rf "$METHOD_FIXTURE"

# ── CLI tests: ship guard rails ──────────────────────────────────────────────

echo "== ship guard rails =="

write_config '```
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

# ── Unit tests: reviewer probe respects the base-branch filter ───────────────
# Second recurrence of the over-claim class. The probe learned to scan
# .github/workflows/ (SiteLine 2026-07-29, above) but still ignored each
# workflow's `branches:` filter, so a reviewer scoped to [beta, main] was
# announced on a feature -> dev PR that it could never fire on.
# Anchor: Piper PIPER-699 / PR #674, 2026-08-19 — `pk ready` printed
# "PR reviewers will now fire: Claude Code Review, Semgrep" on a dev-based PR;
# only Semgrep ran. The PR looked reviewed and nothing said otherwise.

echo "== reviewer probe honours branches: filter (sourced) =="

make_fixture
unit_rfr_base() { ( cd "$FIXTURE" && source "$PK" && pk_ready_for_review_list "$1" ); }
write_wf() { mkdir -p "$FIXTURE/.github/workflows"; printf '%s
' "$2" > "$FIXTURE/.github/workflows/$1"; }

write_wf claude-code-review.yml 'name: Claude Code Review
on:
  pull_request:
    types: [opened, ready_for_review]
    branches:
      - beta
      - main'
write_wf semgrep.yml 'name: Semgrep
on:
  pull_request:
    types: [opened, ready_for_review]'

out=$(unit_rfr_base dev)
[ "$out" = "Semgrep" ] && ok "rfr-base: beta/main-scoped reviewer not claimed on a dev PR" || fail "rfr-base: beta/main-scoped reviewer not claimed on a dev PR" "out='$out'"

out=$(unit_rfr_base beta)
[ "$out" = "Claude Code Review, Semgrep" ] && ok "rfr-base: same reviewer IS claimed on a beta PR" || fail "rfr-base: same reviewer IS claimed on a beta PR" "out='$out'"

# Unknown base (probe called with no argument) must stay permissive — the old
# behaviour — rather than silently under-claiming.
out=$(unit_rfr_base "")
[ "$out" = "Claude Code Review, Semgrep" ] && ok "rfr-base: empty base stays permissive" || fail "rfr-base: empty base stays permissive" "out='$out'"

# A `push:` branches filter in the same file must not be read as the PR one.
rm -f "$FIXTURE/.github/workflows/claude-code-review.yml" "$FIXTURE/.github/workflows/semgrep.yml"
write_wf mixed.yml 'name: Mixed
on:
  push:
    branches: [main]
  pull_request:
    types: [ready_for_review]'
out=$(unit_rfr_base dev)
[ "$out" = "Mixed" ] && ok "rfr-base: push branches filter not mistaken for the PR one" || fail "rfr-base: push branches filter not mistaken for the PR one" "out='$out'"

# Flow-sequence form of the filter.
write_wf mixed.yml 'name: Mixed
on:
  pull_request:
    types: [ready_for_review]
    branches: [dev, "beta"]'
out=$(unit_rfr_base dev)
[ "$out" = "Mixed" ] && ok "rfr-base: flow-sequence branches parsed" || fail "rfr-base: flow-sequence branches parsed" "out='$out'"
out=$(unit_rfr_base main)
[ -z "$out" ] && ok "rfr-base: flow-sequence excludes an unlisted base" || fail "rfr-base: flow-sequence excludes an unlisted base" "out='$out'"

# Globs must match the way GitHub means them.
write_wf mixed.yml 'name: Mixed
on:
  pull_request:
    types: [ready_for_review]
    branches:
      - "releases/**"'
out=$(unit_rfr_base releases/v2)
[ "$out" = "Mixed" ] && ok "rfr-base: glob base pattern matches" || fail "rfr-base: glob base pattern matches" "out='$out'"
out=$(unit_rfr_base dev)
[ -z "$out" ] && ok "rfr-base: glob does not over-match" || fail "rfr-base: glob does not over-match" "out='$out'"

# branches-ignore is the inverse: listed bases are the ones that do NOT fire.
write_wf mixed.yml 'name: Mixed
on:
  pull_request:
    types: [ready_for_review]
    branches-ignore: [docs]'
out=$(unit_rfr_base docs)
[ -z "$out" ] && ok "rfr-base: branches-ignore excludes a listed base" || fail "rfr-base: branches-ignore excludes a listed base" "out='$out'"
out=$(unit_rfr_base dev)
[ "$out" = "Mixed" ] && ok "rfr-base: branches-ignore admits an unlisted base" || fail "rfr-base: branches-ignore admits an unlisted base" "out='$out'"
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

# ── CLI tests: commit-format ship gate (v4.35.0) ─────────────────────────────
# pk ship reads the REAL subjects the branch adds over its base and refuses to
# push an off-format one. The hook denies at commit time; this catches what the
# hook never saw (a human commit, or one made outside Claude Code). Same escapes
# as the verify gate: --force logs a Linear comment, PK_COMMITFMT_BYPASS=1 skips.

echo "== commit-format ship gate (E2E) =="

make_fixture
write_config '```
Integration branch: main
Ship environments: dev,beta,main
```'
git -C "$FIXTURE" checkout -q -b feat/ABC-321-subjects
git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "docs: runbook without a scope"
git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "feat(gate): a scoped one"
# The base ref the gate compares against: a fetched origin/main, simulated.
git -C "$FIXTURE" update-ref refs/remotes/origin/main "$(git -C "$FIXTURE" rev-parse main)"
CF_HEAD=$(git -C "$FIXTURE" rev-parse HEAD)
mkdir -p "$FIXTURE/Logs/Verify/20260101/ABC-321"
printf 'sha: %s\n' "$CF_HEAD" > "$FIXTURE/Logs/Verify/20260101/ABC-321/verify-complete.md"

# (a) One off-format subject → refuse before push, naming the offender only.
: > "$GH_LOG"
run_pk ship
g=0; p=0; scoped=0
case "$RUN_OUT" in *"do not match {type}({scope}): {desc}"*) g=1 ;; esac
case "$RUN_OUT" in *Pushing*) p=1 ;; esac
case "$RUN_OUT" in *"a scoped one"*) scoped=1 ;; esac
if [ $RUN_CODE -ne 0 ] && [ $g -eq 1 ] && [ $p -eq 0 ] && [ ! -s "$GH_LOG" ]; then
  ok "ship gate: off-format subject refuses before push/gh"
else
  fail "ship gate: off-format subject refuses before push/gh" "rc=$RUN_CODE gate_msg=$g pushed=$p gh='$(cat "$GH_LOG")'"
fi
case "$RUN_OUT" in
  *"runbook without a scope"*) ok "ship gate: refusal names the offending subject" ;;
  *) fail "ship gate: refusal names the offending subject" "output: $(echo "$RUN_OUT" | head -4)" ;;
esac
[ $scoped -eq 0 ] && ok "ship gate: the scoped commit is not listed" || fail "ship gate: the scoped commit is not listed" "output: $(echo "$RUN_OUT" | head -4)"

# (b) --force → proceeds to push (fails with no real remote; we assert the gate let it through).
run_pk ship --force
case "$RUN_OUT" in
  *"bypassed via --force"*) ok "ship gate: --force waives the format gate" ;;
  *) fail "ship gate: --force waives the format gate" "output: $(echo "$RUN_OUT" | head -4)" ;;
esac

# (c) PK_COMMITFMT_BYPASS=1 → gate skipped entirely.
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" PK_COMMITFMT_BYPASS=1 "$PK" ship 2>&1)
case "$RUN_OUT" in
  *"commit-format gate bypassed via PK_COMMITFMT_BYPASS"*) ok "ship gate: PK_COMMITFMT_BYPASS=1 skips the format gate" ;;
  *) fail "ship gate: PK_COMMITFMT_BYPASS=1 skips the format gate" "output: $(echo "$RUN_OUT" | head -4)" ;;
esac

# (d) Merge commits are skipped: "Merge branch ..." must not trip the gate.
git -C "$FIXTURE" checkout -q main
git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "chore(main): advance"
git -C "$FIXTURE" update-ref refs/remotes/origin/main "$(git -C "$FIXTURE" rev-parse main)"
git -C "$FIXTURE" checkout -q feat/ABC-321-subjects
git -C "$FIXTURE" -c user.email=t@t -c user.name=t merge -q --no-ff -m "Merge branch 'main' into feat/ABC-321-subjects" main
CF_BAD_NOW=$(cd "$FIXTURE" && source "$PK" && pk_offformat_subjects origin/main)
case "$CF_BAD_NOW" in
  *"Merge branch"*) fail "ship gate: merge commits are skipped" "listed: $CF_BAD_NOW" ;;
  *"runbook without a scope"*) ok "ship gate: merge commits are skipped, real offenders still listed" ;;
  *) fail "ship gate: merge commits are skipped, real offenders still listed" "listed: $CF_BAD_NOW" ;;
esac

# (e) No base to compare against (fresh clone, no remote, no local base) → skip, not crash.
CF_NONE=$(cd "$FIXTURE" && source "$PK" && pk_offformat_subjects "")
[ -z "$CF_NONE" ] && ok "ship gate: empty base ref is a skip" || fail "ship gate: empty base ref is a skip" "got: $CF_NONE"

cleanup

# ── Ship reminders (v5.3.0) ──────────────────────────────────────────────────
# pk ship prints a method.config.md § Ship Reminders message for each rule whose
# ERE matches a file the branch changes over its base. Informational: it never
# blocks and never changes pk ship's exit code. The case that motivated it: a
# backend change the PR preview does not run (Piper PIPER-1366).

echo "== ship reminders =="

make_fixture
write_config '```
Integration branch: main
```

## Ship Reminders

```text
# backend paths the preview does not run
^app/api/ => PHP changed: deploy this branch to dev before UAT
^db/migrations/ => Migration changed: apply it to the dev DB before UAT
docs/( => broken pattern
```'
git -C "$FIXTURE" update-ref refs/remotes/origin/main "$(git -C "$FIXTURE" rev-parse main)"
git -C "$FIXTURE" checkout -q -b feat/ABC-400-reminders
mkdir -p "$FIXTURE/app/api" "$FIXTURE/web"
echo x > "$FIXTURE/app/api/save.php"; echo x > "$FIXTURE/web/page.ts"
git -C "$FIXTURE" add app web
git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -q -m "feat(api): save"

SR_OUT=$(cd "$FIXTURE" && source "$PK" && pk_ship_reminders origin/main 2>"$FIXTURE/.sr-err")
SR_ERR=$(cat "$FIXTURE/.sr-err")
case "$SR_OUT" in
  *"⚑ PHP changed: deploy this branch to dev before UAT"*) ok "ship reminders: a matching rule prints its message" ;;
  *) fail "ship reminders: a matching rule prints its message" "got: $SR_OUT" ;;
esac
case "$SR_OUT" in
  *"Migration changed"*) fail "ship reminders: a rule with no matching file is silent" "got: $SR_OUT" ;;
  *) ok "ship reminders: a rule with no matching file is silent" ;;
esac
case "$SR_OUT" in
  *"backend paths"*) fail "ship reminders: # lines are comments" "got: $SR_OUT" ;;
  *) ok "ship reminders: # lines are comments" ;;
esac
case "$SR_ERR" in
  *"not a valid ERE, skipped: docs/("*) ok "ship reminders: an invalid pattern warns and the rest still run" ;;
  *) fail "ship reminders: an invalid pattern warns and the rest still run" "stderr: $SR_ERR" ;;
esac
SR_NONE=$(cd "$FIXTURE" && source "$PK" && pk_ship_reminders "")
[ -z "$SR_NONE" ] && ok "ship reminders: no base ref is a skip" || fail "ship reminders: no base ref is a skip" "got: $SR_NONE"

# E2E: the reminder reaches pk ship's output; the exit code is what it would be without it.
SR_HEAD=$(git -C "$FIXTURE" rev-parse HEAD)
mkdir -p "$FIXTURE/Logs/Verify/20260101/ABC-400"
printf 'sha: %s\n' "$SR_HEAD" > "$FIXTURE/Logs/Verify/20260101/ABC-400/verify-complete.md"
git init -q --bare "$FIXTURE/.remote.git"
git -C "$FIXTURE" remote add origin "$FIXTURE/.remote.git"
# The PR already exists, so pk ship needs no Linear title lookup; CI has no key.
cat > "$FIXTURE/shim/gh" <<EOF
#!/usr/bin/env bash
echo "gh \$*" >> "$GH_LOG"
case "\$1 \$2" in
  "pr view") echo '{"state":"OPEN","url":"https://example.test/pr/1","number":1,"baseRefName":"main"}' ;;
esac
exit 0
EOF
run_pk ship
SR_RC_WITH=$RUN_CODE
case "$RUN_OUT" in
  *"⚑ PHP changed: deploy this branch to dev before UAT"*) ok "ship reminders: pk ship prints the reminder" ;;
  *) fail "ship reminders: pk ship prints the reminder" "output: $(echo "$RUN_OUT" | tail -6)" ;;
esac
write_config '```
Integration branch: main
```'
run_pk ship
case "$RUN_OUT" in
  *"⚑ PHP changed"*) fail "ship reminders: no section, no reminder" "output: $(echo "$RUN_OUT" | tail -6)" ;;
  *) ok "ship reminders: no section, no reminder" ;;
esac
[ "$SR_RC_WITH" = "$RUN_CODE" ] && ok "ship reminders: pk ship exit code unchanged ($RUN_CODE)" || fail "ship reminders: pk ship exit code unchanged" "with=$SR_RC_WITH without=$RUN_CODE"

cleanup

# ── Board reads fail loudly without a Linear key (v4.35.0) ───────────────────
# cmd_status and cmd_next swallow per-state read errors so one flaky call can't
# blank the board — which meant an UNSET key rendered every column "(none)",
# indistinguishable from an empty board. Found 2026-09-02: both consumers read
# as idle while carrying 290 open issues between them.

echo "== board reads fail loudly without a Linear key =="
make_fixture
write_config '```
Team name: Piper
Integration branch: main
```'
RUN_OUT=$(cd "$FIXTURE" && env -u LINEAR_API_KEY PATH="$FIXTURE/shim:$PATH" "$PK" status 2>&1); RUN_CODE=$?
case "$RUN_OUT" in
  *"Linear API key not set"*)
    [ $RUN_CODE -ne 0 ] && ok "status: missing key is an error, not an empty board" || fail "status: missing key is an error, not an empty board" "rc=0 with error text" ;;
  *) fail "status: missing key is an error, not an empty board" "rc=$RUN_CODE out=$(echo "$RUN_OUT" | head -3)" ;;
esac
case "$RUN_OUT" in
  *"(none)"*) fail "status: no phantom empty columns without a key" "printed (none)" ;;
  *) ok "status: no phantom empty columns without a key" ;;
esac
RUN_OUT=$(cd "$FIXTURE" && env -u LINEAR_API_KEY PATH="$FIXTURE/shim:$PATH" "$PK" next 2>&1); RUN_CODE=$?
case "$RUN_OUT" in
  *"Linear API key not set"*)
    [ $RUN_CODE -ne 0 ] && ok "next: missing key is an error, not 'No Approved issues'" || fail "next: missing key is an error" "rc=0 with error text" ;;
  *) fail "next: missing key is an error, not 'No Approved issues'" "rc=$RUN_CODE out=$(echo "$RUN_OUT" | head -3)" ;;
esac
cleanup

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

echo "== verify drift: worktree lookup (v5.3.1) =="
# A project that gitignores Logs/Verify never commits the evidence, so from the
# parent neither the checkout nor the branch's tree holds it; only the branch's
# worktree does (Piper PIPER-1369: pk ready reported "none" with a HEAD-matching
# sentinel sitting in the worktree).

make_fixture
gitf() { git -C "$FIXTURE" -c user.email=t@t -c user.name=t "$@"; }
WT="$FIXTURE/.wt/ABC-8"
gitf worktree add -q -b feature/ABC-8-wt "$WT" main
gitw() { git -C "$WT" -c user.email=t@t -c user.name=t "$@"; }
WT_VERIFIED=$(gitw rev-parse HEAD)
mkdir -p "$WT/Logs/Verify/20260101/ABC-8"
printf 'sha: %s\n' "$WT_VERIFIED" > "$WT/Logs/Verify/20260101/ABC-8/verify-complete.md"   # never committed
mkdir -p "$WT/src"; echo x > "$WT/src/app.js"
gitw add src; gitw commit -q -m "fix(app): pushed after verify"
WT_HEAD=$(gitw rev-parse HEAD)

sl3() { ( cd "$FIXTURE" && source "$PK" && pk_verify_sentinel_latest "$@" ); }
out=$(sl3 ABC-8 feature/ABC-8-wt)
[ "${out##*$'\t'}" = "$WT_VERIFIED" ] && ok "worktree: parent finds uncommitted evidence in the branch's worktree" || fail "worktree: parent finds uncommitted evidence in the branch's worktree" "got '$out'"
case "${out%%$'\t'*}" in
  "$(cd "$WT" && pwd -P)"/Logs/Verify/*) ok "worktree: reported path is the worktree's file" ;;
  *) fail "worktree: reported path is the worktree's file" "got '${out%%$'\t'*}'" ;;
esac

drw() { ( cd "$FIXTURE" && source "$PK" && pk_verify_drift_report "$@" 2>/dev/null ); }
[ "$(drw ABC-8 "$WT_HEAD" feature/ABC-8-wt)" = "source" ] && ok "worktree: source commit after verify is caught from the parent" || fail "worktree: source commit after verify is caught from the parent" "got '$(drw ABC-8 "$WT_HEAD" feature/ABC-8-wt)'"
[ "$(drw ABC-8 "$WT_VERIFIED" feature/ABC-8-wt)" = "fresh" ] && ok "worktree: HEAD at the verified sha is fresh" || fail "worktree: HEAD at the verified sha is fresh" "got '$(drw ABC-8 "$WT_VERIFIED" feature/ABC-8-wt)'"

# Inside the worktree, the working-tree source answers and the helper skips itself.
out=$( cd "$WT" && source "$PK" && pk_branch_worktree feature/ABC-8-wt )
[ -z "$out" ] && ok "worktree: the current checkout is not its own extra source" || fail "worktree: the current checkout is not its own extra source" "got '$out'"
out=$( cd "$WT" && source "$PK" && pk_verify_sentinel_latest ABC-8 feature/ABC-8-wt )
[ "${out##*$'\t'}" = "$WT_VERIFIED" ] && ok "worktree: lookup from inside the worktree still works" || fail "worktree: lookup from inside the worktree still works" "got '$out'"

out=$( cd "$FIXTURE" && source "$PK" && pk_branch_worktree no/such/branch )
[ -z "$out" ] && ok "worktree: a branch with no worktree adds no source" || fail "worktree: a branch with no worktree adds no source" "got '$out'"

# v5.3.2: pk ready from the parent must compare against the BRANCH's commit. Its
# HEAD there is the integration branch, so a fresh branch read as source drift
# (Piper PIPER-1369, PR #1153: verified 1447fc0c, compared against dev's a9476f26).
printf 'sha: %s\n' "$WT_HEAD" > "$WT/Logs/Verify/20260101/ABC-8/verify-complete.md"
bh() { ( cd "$FIXTURE" && source "$PK" && pk_branch_head "$@" ); }
[ "$(bh feature/ABC-8-wt)" = "$WT_HEAD" ] && ok "branch head: from the parent, the branch's commit, not the parent's HEAD" || fail "branch head: from the parent, the branch's commit" "got '$(bh feature/ABC-8-wt)' want $WT_HEAD"
[ "$(bh no/such/branch)" = "$(gitf rev-parse HEAD)" ] && ok "branch head: unknown branch falls back to HEAD" || fail "branch head: unknown branch falls back to HEAD" "got '$(bh no/such/branch)'"
cat > "$FIXTURE/shim/gh" <<EOF
#!/usr/bin/env bash
echo "gh \$*" >> "$GH_LOG"
case "\$1 \$2" in
  "pr view") echo '{"state":"OPEN","url":"https://example.test/pr/8","number":8,"baseRefName":"main","isDraft":true}' ;;
esac
exit 0
EOF
run_pk ready ABC-8
case "$RUN_OUT" in
  *"Source changed after the verify"*) fail "pk ready from the parent: a fresh branch is not read as drift" "output: $(echo "$RUN_OUT" | head -6)" ;;
  *) ok "pk ready from the parent: a fresh branch is not read as drift" ;;
esac
gitw commit -q --allow-empty -m "fix(app): another after verify"; echo y >> "$WT/src/app.js"; gitw commit -qam "fix(app): source after verify"
run_pk ready ABC-8
case "$RUN_OUT" in
  *"Source changed after the verify"*) ok "pk ready from the parent: real drift on the branch still blocks" ;;
  *) fail "pk ready from the parent: real drift on the branch still blocks" "output: $(echo "$RUN_OUT" | head -6)" ;;
esac

grep -q 'means ship was forced or skipped' "$PK" && fail "pk ready: 'none' message no longer blames a forced ship" "old wording still present" || ok "pk ready: 'none' message no longer blames a forced ship"
gitf worktree remove --force "$WT" >/dev/null 2>&1 || true
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

# ── CLI tests: pk done after delete-branch-on-merge (SiteLine, 2026-10-09) ────
# A PR merged in the GitHub UI on a repo with delete-branch-on-merge leaves no
# branch locally or on origin by the time pk done runs. The resolver only knew
# those two places, so pk done errored "no branch found" before the merge check
# ever ran, and the issue sat In Progress with no Shipped record and nothing
# saying so (PIPER-1086/1128/1142). GitHub still has the merged PR under its
# head name. These tests stub gh with the REAL `gh pr list --json` shape
# (headRefName, headRefOid, mergeCommit{oid}, mergedAt, state) and the Linear
# write path, and assert on what reaches Linear — never on a mocked verdict.

echo "== done: merged PR whose branch was deleted (delete-branch-on-merge) =="

make_fixture
write_config '```
Team name: Eng
Integration branch: main
Ship environments: dev,beta,main
```'

# The exact post-UI-merge state: a real merge commit on main (squash is off in
# consuming repos), origin holding main but NOT the branch, branch gone locally.
gd_git() { git -C "$FIXTURE" -c user.email=t@t -c user.name=t "$@"; }
gd_git checkout -q -b feature/GD-1-gone
printf 'a\n' > "$FIXTURE/a.txt"; gd_git add a.txt; gd_git commit -q -m "feat(gd): add a"
gd_git commit -q --allow-empty -m "fix(gd): tidy a"
GD_HEAD=$(gd_git rev-parse HEAD)
gd_git checkout -q main
gd_git merge -q --no-ff feature/GD-1-gone -m "Merge pull request #7 from t/feature/GD-1-gone"
GD_MERGE=$(gd_git rev-parse HEAD)
# A merged PR whose branch is still local — the ordinary path, used as the control.
gd_git checkout -q -b feature/GD-5-local
gd_git commit -q --allow-empty -m "feat(gd): local five"
gd_git checkout -q main
gd_git merge -q --no-ff feature/GD-5-local -m "Merge pull request #5 from t/feature/GD-5-local"
git init -q --bare "$FIXTURE/remote.git"
gd_git remote add origin "$FIXTURE/remote.git"
gd_git push -q origin main
gd_git branch -D feature/GD-1-gone >/dev/null

# gh pr list answers, in the shape gh 2.102.0 returns for
# --json number,state,url,headRefName,headRefOid,mergeCommit,mergedAt.
# GD-1: two merged PRs (newest must win) plus a decoy whose head only shares the
# ID as a prefix (GD-10) — the glob filter must drop it even though the server
# matched it. GD-2: closed, never merged. GD-4: merged, but the merge commit is
# not in the local object store.
printf '[{"headRefName":"feature/GD-10-decoy","headRefOid":"1111111111111111111111111111111111111111","mergeCommit":{"oid":"2222222222222222222222222222222222222222"},"mergedAt":"2026-10-10T09:00:00Z","number":10,"state":"MERGED","url":"https://github.com/t/r/pull/10"},
 {"headRefName":"feature/GD-1-first","headRefOid":"3333333333333333333333333333333333333333","mergeCommit":{"oid":"4444444444444444444444444444444444444444"},"mergedAt":"2026-10-01T09:00:00Z","number":6,"state":"MERGED","url":"https://github.com/t/r/pull/6"},
 {"headRefName":"feature/GD-1-gone","headRefOid":"%s","mergeCommit":{"oid":"%s"},"mergedAt":"2026-10-09T13:17:12Z","number":7,"state":"MERGED","url":"https://github.com/t/r/pull/7"}]\n' \
  "$GD_HEAD" "$GD_MERGE" > "$FIXTURE/gh-GD-1.json"
printf '[{"headRefName":"feature/GD-2-closed","headRefOid":"813e609777b7d28c4e4f2eb25dde4b062e0ba559","mergeCommit":null,"mergedAt":null,"number":8,"state":"CLOSED","url":"https://github.com/t/r/pull/8"}]\n' > "$FIXTURE/gh-GD-2.json"
printf '[{"headRefName":"fix/GD-4-remote","headRefOid":"5555555555555555555555555555555555555555","mergeCommit":{"oid":"6666666666666666666666666666666666666666"},"mergedAt":"2026-10-09T14:00:00Z","number":9,"state":"MERGED","url":"https://github.com/t/r/pull/9"}]\n' > "$FIXTURE/gh-GD-4.json"
# REST repos/{slug}/pulls/9/commits, trimmed to the fields pk reads.
printf '[{"sha":"abc1234abc1234abc1234abc1234abc1234abc12","commit":{"message":"fix(gd): remote one\\n\\nbody line"}},
 {"sha":"def5678def5678def5678def5678def5678def56","commit":{"message":"test(gd): remote two"}}]\n' > "$FIXTURE/gh-pr9-commits.json"

cat > "$FIXTURE/shim/gh" <<EOF
#!/usr/bin/env bash
echo "gh \$*" >> "$GH_LOG"
case "\$*" in
  *"pr list"*"head:feature/GD-1-"*) cat "$FIXTURE/gh-GD-1.json" ;;
  *"pr list"*"head:feature/GD-2-"*) cat "$FIXTURE/gh-GD-2.json" ;;
  *"pr list"*"head:feature/GD-3-"*) echo '[]' ;;
  *"pr list"*"head:feature/GD-4-"*) cat "$FIXTURE/gh-GD-4.json" ;;
  *"pulls/9/commits"*)              cat "$FIXTURE/gh-pr9-commits.json" ;;
esac
exit 0
EOF
chmod +x "$FIXTURE/shim/gh"

# Linear: log every call, answer the reads cmd_done makes (issue lookup, comment
# thread, workflow state) and confirm the writes. The issue sits in UAT so the
# "advance" ladder lets it move to In Dev.
GD_GQL_LOG="$FIXTURE/gql.log"
cat > "$FIXTURE/gd-gql-stub.sh" <<'EOF'
pk_linear_gql() {
  printf '%s\t%s\n' "$1" "$(printf '%s' "${2:-null}" | jq -c .)" >> "$GD_GQL_LOG"
  case "$1" in
    mutation*issueUpdate*)   echo '{"data":{"issueUpdate":{"success":true}}}' ;;
    mutation*commentCreate*) echo '{"data":{"commentCreate":{"success":true}}}' ;;
    *workflowStates*)        echo '{"data":{"workflowStates":{"nodes":[{"id":"st-in-dev","name":"In Dev"}]}}}' ;;
    *"issue(id:"*)           echo '{"data":{"issue":{"id":"uuid-gd","state":{"name":"UAT"},"comments":{"nodes":[]}}}}' ;;
    *) echo '{}' ;;
  esac
}
EOF
gd_done() { # $@ = pk done args → GD_OUT (combined output), GD_RC
  : > "$GD_GQL_LOG"; : > "$GH_LOG"
  GD_OUT=$( cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" && source "$PK" \
    && source "${GD_STUB:-$FIXTURE/gd-gql-stub.sh}" && LINEAR_API_KEY=lin_test cmd_done "$@" 2>&1 ); GD_RC=$?
}
# Logged mutations in order, as "name<TAB>variables" (compact JSON).
gd_writes() { awk -F'\t' '/^mutation/ { match($1, /\{ *[A-Za-z]+/); n = substr($1, RSTART, RLENGTH); sub(/^\{ */, "", n); print n "\t" $2 }' "$GD_GQL_LOG"; }
gd_comment_body() { gd_writes | awk -F'\t' '$1 == "commentCreate" { print $2; exit }' | jq -r '.body // empty'; }

# (a) Merged PR, branch gone locally and on origin, merge commit local → the
#     newest merged PR resolves, the Shipped comment carries PR + diffstat + the
#     merge's own commit list (^1..^2, so no main commits), and the issue moves.
gd_done GD-1
case "$GD_OUT" in
  *"resolved from merged PR #7 on GitHub"*)
    [ $GD_RC -eq 0 ] && ok "done: deleted branch resolves from the newest merged PR (decoy and older PR skipped)" \
      || fail "done: deleted branch resolves from merged PR" "resolved but rc=$GD_RC: $GD_OUT" ;;
  *"no branch found"*) fail "done: deleted branch resolves from merged PR" "still branch-not-found: $(echo "$GD_OUT" | head -2)" ;;
  *) fail "done: deleted branch resolves from merged PR" "rc=$GD_RC out=$GD_OUT" ;;
esac
GD_BODY=$(gd_comment_body)
case "$GD_BODY" in
  "**Shipped — GD-1**"*"PR: https://github.com/t/r/pull/7"*"Diff: 1 file changed"*"**Commits:**"*"fix(gd): tidy a"*"feat(gd): add a"*)
    case "$GD_BODY" in
      *" init"*|*"local five"*) fail "done: Shipped comment lists only the merge's commits" "range leaked main commits: $GD_BODY" ;;
      *) ok "done: Shipped comment carries PR URL, diffstat and the merge's commit list (merge^1..merge^2)" ;;
    esac ;;
  *) fail "done: Shipped comment carries PR URL, diffstat and commit list" "body: ${GD_BODY:-<no commentCreate>}" ;;
esac
GD_NAMES=$(gd_writes | cut -f1 | paste -sd, -)
GD_STATE=$(gd_writes | awk -F'\t' '$1 == "issueUpdate" { print $2; exit }' | jq -r '.state // empty')
if [ "$GD_NAMES" = "commentCreate,issueUpdate" ] && [ "$GD_STATE" = "st-in-dev" ]; then
  ok "done: issue transitioned UAT → In Dev after the Shipped comment"
else
  fail "done: issue transitioned UAT → In Dev" "writes=$GD_NAMES state=$GD_STATE"
fi
if grep -q "pr merge" "$GH_LOG"; then
  fail "done: no gh pr merge on a PR already known merged" "$(cat "$GH_LOG")"
else
  ok "done: no gh pr merge on a PR already known merged"
fi

# (b) Closed, never merged, branch gone → refuse with the not-merged wording,
#     and nothing reaches Linear.
gd_done GD-2
case "$GD_OUT" in
  *"PR for feature/GD-2-closed is not merged (state: CLOSED)"*)
    if [ $GD_RC -ne 0 ] && [ -z "$(gd_writes)" ]; then
      ok "done: closed unmerged PR with deleted branch refuses, no Linear write"
    else
      fail "done: closed unmerged PR refuses" "rc=$GD_RC writes=$(gd_writes | cut -f1 | paste -sd, -)"
    fi ;;
  *) fail "done: closed unmerged PR refuses with not-merged wording" "rc=$GD_RC out=$GD_OUT" ;;
esac

# (c) No PR anywhere → the branch-not-found error, now saying GitHub was searched
#     too, still naming the globs; nothing reaches Linear.
gd_done GD-3
case "$GD_OUT" in
  *"no branch found for GD-3"*"feature/GD-3-*"*"GitHub PRs"*)
    if [ $GD_RC -ne 0 ] && [ -z "$(gd_writes)" ]; then
      ok "done: no branch and no PR → error names the GitHub search, no Linear write"
    else
      fail "done: no branch and no PR" "rc=$GD_RC writes=$(gd_writes | cut -f1 | paste -sd, -)"
    fi ;;
  *) fail "done: no branch and no PR → error names the GitHub search" "rc=$GD_RC out=$GD_OUT" ;;
esac

# (d) Merged PR, merge commit NOT local (parent has not pulled yet) → the commit
#     list comes from REST pulls/<n>/commits, diffstat is skipped and said so.
gd_done GD-4
GD_BODY=$(gd_comment_body)
case "$GD_OUT" in
  *"resolved from merged PR #9 on GitHub"*"not local — commit list comes from GitHub"*)
    case "$GD_BODY" in
      *"Diff:"*) fail "done: unfetched merge takes the commit list from GitHub" "diffstat claimed without a local range: $GD_BODY" ;;
      "**Shipped — GD-4**"*"PR: https://github.com/t/r/pull/9"*"- abc1234 fix(gd): remote one"*"- def5678 test(gd): remote two"*)
        grep -q "pulls/9/commits" "$GH_LOG" && [ $GD_RC -eq 0 ] \
          && ok "done: unfetched merge takes the commit list from GitHub (first lines only), no diffstat" \
          || fail "done: unfetched merge takes the commit list from GitHub" "rc=$GD_RC gh=$(cat "$GH_LOG")" ;;
      *) fail "done: unfetched merge takes the commit list from GitHub" "body: ${GD_BODY:-<no commentCreate>} rc=$GD_RC out=$GD_OUT" ;;
    esac ;;
  *) fail "done: unfetched merge announces the GitHub commit list" "rc=$GD_RC out=$GD_OUT" ;;
esac

# (e) --merge on the fallback path: nothing to merge by name, must not call
#     gh pr merge and must not strand the issue.
gd_done GD-1 --merge
case "$GD_OUT" in
  *"already merged — nothing for --merge to do"*)
    if ! grep -q "pr merge" "$GH_LOG" && [ "$(gd_writes | cut -f1 | paste -sd, -)" = "commentCreate,issueUpdate" ]; then
      ok "done --merge: already-merged PR with deleted branch skips gh pr merge and still ships"
    else
      fail "done --merge: already-merged PR skips gh pr merge" "gh=$(cat "$GH_LOG") writes=$(gd_writes | cut -f1 | paste -sd, -)"
    fi ;;
  *) fail "done --merge: already-merged PR with deleted branch" "rc=$GD_RC out=$GD_OUT" ;;
esac

# (f) Control: a merged PR whose branch still exists never reaches the GitHub
#     search — the ordinary path is untouched (it stops at the shim's empty
#     pulls?head= answer, as before).
gd_done GD-5
if grep -q "pr list" "$GH_LOG"; then
  fail "done: an existing branch never triggers the GitHub PR search" "$(cat "$GH_LOG")"
else
  case "$GD_OUT" in
    *"PR for feature/GD-5-local is not merged (state: NOT_FOUND)"*) ok "done: an existing branch never triggers the GitHub PR search (ordinary path unchanged)" ;;
    *) fail "done: ordinary path unchanged for an existing branch" "out=$GD_OUT" ;;
  esac
fi

# (g) TPM follow-through (v5.1.0): an `[tpm DATE] on-merge:` note on the issue
#     is listed after the Shipped comment + transition and before the worktree
#     goes; PK_ON_MERGE=print never runs it and the only Linear writes are
#     still the ship record and the state change. Same stub, with a thread.
cat > "$FIXTURE/gd-gql-stub-tpm.sh" <<'EOF'
pk_linear_gql() {
  printf '%s\t%s\n' "$1" "$(printf '%s' "${2:-null}" | jq -c .)" >> "$GD_GQL_LOG"
  case "$1" in
    mutation*issueUpdate*)   echo '{"data":{"issueUpdate":{"success":true}}}' ;;
    mutation*commentCreate*) echo '{"data":{"commentCreate":{"success":true}}}' ;;
    *workflowStates*)        echo '{"data":{"workflowStates":{"nodes":[{"id":"st-in-dev","name":"In Dev"}]}}}' ;;
    *"issue(id:"*)           echo '{"data":{"issue":{"id":"uuid-gd","state":{"name":"UAT"},"comments":{"nodes":[{"body":"UAT round 1: fine"},{"body":"[tpm 2026-10-11] on-merge: pk focus I7.P10 C --swap · tier C moves to Finance settings once this merges"}]}}}}' ;;
    *) echo '{}' ;;
  esac
}
EOF
GD_STUB="$FIXTURE/gd-gql-stub-tpm.sh" PK_ON_MERGE=print gd_done GD-1
case "$GD_OUT" in
  *"TPM follow-through — [tpm] on-merge notes on GD-1:"*"  pk focus I7.P10 C --swap"*"  not run — run each by hand"*"Removing worktree..."*)
    if [ $GD_RC -eq 0 ] && [ "$(gd_writes | cut -f1 | paste -sd, -)" = "commentCreate,issueUpdate" ]; then
      ok "done: [tpm] on-merge note listed after the transition; PK_ON_MERGE=print leaves it to the human"
    else
      fail "done: tpm follow-through with PK_ON_MERGE=print" "rc=$GD_RC writes=$(gd_writes | cut -f1 | paste -sd, -)"
    fi ;;
  *"Run now?"*) fail "done: tpm follow-through with PK_ON_MERGE=print" "prompted despite print mode: $GD_OUT" ;;
  *) fail "done: tpm follow-through header" "rc=$GD_RC out=$GD_OUT" ;;
esac
# (h) Default mode off a TTY (CI, a pipe): same listing, no prompt, nothing run.
GD_STUB="$FIXTURE/gd-gql-stub-tpm.sh" gd_done GD-1
case "$GD_OUT" in
  *"Run now?"*) fail "done: tpm follow-through off a TTY" "prompted with no terminal: $GD_OUT" ;;
  *"TPM follow-through — [tpm] on-merge notes on GD-1:"*"  not run — run each by hand"*)
    [ $GD_RC -eq 0 ] && ok "done: tpm follow-through off a TTY lists the notes and does not prompt" \
      || fail "done: tpm follow-through off a TTY" "rc=$GD_RC" ;;
  *) fail "done: tpm follow-through off a TTY" "rc=$GD_RC out=$GD_OUT" ;;
esac
# (i) No note on the thread → not a word about follow-through.
gd_done GD-1
case "$GD_OUT" in
  *"TPM follow-through"*) fail "done: no on-merge note → no follow-through section" "out=$GD_OUT" ;;
  *) [ $GD_RC -eq 0 ] && ok "done: no on-merge note → no follow-through section" || fail "done: no on-merge note" "rc=$GD_RC" ;;
esac

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
    *"does not match {type}({scope})"*) ok "hook: bad subject nudges" ;;
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

  # ── PreToolUse (v4.35.0): the same script DENIES an off-format commit before it
  # runs. Anchor: piper PR #771, 2026-09-02 — the PostToolUse nudge fired, the
  # session pushed with a raw `git push` anyway, and an unscoped subject is now
  # permanent on a protected branch (squash is off). PostToolUse cannot block.
  pre() { printf '%s' "$1" | bash "$HOOK" 2>&1; }   # $1 = PreToolUse JSON on stdin

  out=$(pre '{"hook_event_name":"PreToolUse","tool_input":{"command":"git commit -m \"docs: no scope\""}}')
  case "$out" in
    *'"permissionDecision": "deny"'*) ok "hook/pre: bad subject is denied" ;;
    *) fail "hook/pre: bad subject is denied" "output: $out" ;;
  esac
  case "$out" in
    *'"hookEventName": "PreToolUse"'*) ok "hook/pre: deny names the PreToolUse event" ;;
    *) fail "hook/pre: deny names the PreToolUse event" "output: $out" ;;
  esac

  # The incident shape: a compound command whose commit is not command-initial.
  out=$(pre '{"hook_event_name":"PreToolUse","tool_input":{"command":"cd ~/Projects/piper && git commit -m \"docs: runbook records X\""}}')
  case "$out" in
    *'"permissionDecision": "deny"'*) ok "hook/pre: cd && git commit (incident shape) is denied" ;;
    *) fail "hook/pre: cd && git commit (incident shape) is denied" "output: $out" ;;
  esac

  out=$(pre '{"hook_event_name":"PreToolUse","tool_input":{"command":"git commit -m \"feat(work): scoped\""}}')
  [ -z "$out" ] && ok "hook/pre: good subject is silent (no decision)" || fail "hook/pre: good subject is silent (no decision)" "output: $out"

  # A false positive now BLOCKS a tool call, so the data-vs-invocation corpus must
  # stay silent under PreToolUse too.
  out=$(pre '{"hook_event_name":"PreToolUse","tool_input":{"command":"grep -rn \"git commit\" docs/"}}')
  [ -z "$out" ] && ok "hook/pre: grep-pattern data does not block" || fail "hook/pre: grep-pattern data does not block" "output: $out"

  out=$(pre '{"hook_event_name":"PreToolUse","tool_input":{"command":"gh pr comment 1 --body \"$(cat <<EOF\nFix: git commit -m \\\"feat: x\\\" now works.\nEOF\n)\""}}')
  [ -z "$out" ] && ok "hook/pre: heredoc prose does not block" || fail "hook/pre: heredoc prose does not block" "output: $out"

  out=$(pre '{"hook_event_name":"PreToolUse","tool_input":{"command":"git commit -F- <<EOF\nbad subject no scope\nbody\nEOF"}}')
  case "$out" in
    *'"permissionDecision": "deny"'*) ok "hook/pre: -F- heredoc bad subject is denied" ;;
    *) fail "hook/pre: -F- heredoc bad subject is denied" "output: $out" ;;
  esac

  printf '%s' '{"hook_event_name":"PreToolUse","tool_input":{"command":"git commit -m \"nope\""}}' | bash "$HOOK" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "hook/pre: deny is the JSON path (exit 0)" || fail "hook/pre: deny is the JSON path (exit 0)" "nonzero exit"

  # The PostToolUse text is an instruction (amend now), not a report.
  out=$(hook_run '{"hook_event_name":"PostToolUse","tool_input":{"command":"git commit -m \"docs: no scope\""}}')
  case "$out" in
    *"git commit --amend"*) ok "hook/post: nudge instructs to amend before pushing" ;;
    *) fail "hook/post: nudge instructs to amend before pushing" "output: $out" ;;
  esac
fi

# ── sync registers the hook once per event (v4.35.0) ─────────────────────────
# Consumers registered before v4.35.0 carry only the PostToolUse entry. A
# single "already registered anywhere" guard would report OK and never wire
# PreToolUse — the one that blocks — on any existing consumer.

echo "== sync-method registers validate-commit.sh per event =="
HK_TMP=$(mktemp -d)
mkdir -p "$HK_TMP/proj/.claude" "$HK_TMP/method/skills/demo" "$HK_TMP/method/templates/hooks"
echo 'upstream demo body' > "$HK_TMP/method/skills/demo/SKILL.md"
cp "$REPO_ROOT/templates/hooks/validate-commit.sh" "$HK_TMP/method/templates/hooks/validate-commit.sh"
cat > "$HK_TMP/proj/.claude/settings.json" <<'EOF'
{"hooks":{"PostToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-commit.sh","timeout":10}]}]}}
EOF
HK_OUT=$(SYNC_METHOD_REEXEC=1 SYNC_METHOD_TEMP="$HK_TMP/method" \
  bash "$REPO_ROOT/scripts/sync-method.sh" --dry-run --target="$HK_TMP/proj" 2>&1)
case "$HK_OUT" in
  *"already registered (PostToolUse)"*) ok "hook registration: existing PostToolUse entry is recognised" ;;
  *) fail "hook registration: existing PostToolUse entry is recognised" "$(echo "$HK_OUT" | grep -i validate-commit | head -3)" ;;
esac
case "$HK_OUT" in
  *"WOULD REGISTER validate-commit.sh (PreToolUse)"*) ok "hook registration: missing PreToolUse entry is added" ;;
  *) fail "hook registration: missing PreToolUse entry is added" "$(echo "$HK_OUT" | grep -i validate-commit | head -3)" ;;
esac
rm -rf "$HK_TMP"

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

# The script resolves its package root from its own location
# (scripts/lib/package-root.sh), not from cwd, so each fixture gets its own copy.
install_drift_sh() {
  mkdir -p "$1/scripts/lib"
  cp "$REPO_ROOT/scripts/check-migration-drift.sh" "$1/scripts/"
  cp "$REPO_ROOT/scripts/lib/package-root.sh" "$1/scripts/lib/"
}

make_fixture
install_drift_sh "$FIXTURE"
DRIFT_SH="$FIXTURE/scripts/check-migration-drift.sh"
# (1) No Migration dir configured → clean skip, exit 0.
write_config '```
Integration branch: main
```'
out=$(cd "$FIXTURE" && "$DRIFT_SH" 2>&1); rc=$?
[ $rc -eq 0 ] && case "$out" in *skipping*) ok "drift: no Migration dir → skip (exit 0)" ;; *) fail "drift: no Migration dir → skip (exit 0)" "out: $out" ;; esac \
  || fail "drift: no Migration dir → skip (exit 0)" "rc=$rc"

# Build a migration history: base (main) carries 001+003, feature branches vary.
write_config '```
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

# (6) Nested package (SiteLine's apps/legacy/ layout): the package's own config
# and migration dir are found, and a backdated migration there is still flagged.
make_fixture
PKG="$FIXTURE/apps/legacy"
mkdir -p "$PKG/db/migrations"
install_drift_sh "$PKG"
printf '%s\n' '```' 'Integration branch: main' 'Migration dir: db/migrations' '```' > "$PKG/method.config.md"
echo "select 1;" > "$PKG/db/migrations/20260101000000_init.sql"
echo "select 3;" > "$PKG/db/migrations/20260103000000_third.sql"
git -C "$FIXTURE" add -A && git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -qm "nested base"
git -C "$FIXTURE" checkout -qb feat/nested-collide
echo "select 2;" > "$PKG/db/migrations/20260102000000_backdated.sql"
git -C "$FIXTURE" add -A && git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -qm "nested backdated"
out=$(cd "$PKG" && "$PKG/scripts/check-migration-drift.sh" --base main 2>&1); rc=$?
[ $rc -eq 1 ] && case "$out" in *"branch collision"*) ok "drift: nested package's backdated migration flagged" ;; *) fail "drift: nested package's backdated migration flagged" "out: $out" ;; esac \
  || fail "drift: nested package's backdated migration flagged" "rc=$rc (want 1) out: $out"
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

# ── Canonical rules word budget (v5.2.0) ─────────────────────────────────────
# templates/rules/*.md load into every session of every consumer, so their size
# is paid on every turn. A new rule that breaches the budget displaces or
# tightens an old one (sop/Rules_SOP.md § Writing a rule); raising the number
# is a decision, not a side effect.

RULES_WORD_BUDGET=3750
echo "== canonical rules word budget =="
rules_words=$(cat "$REPO_ROOT"/templates/rules/*.md | wc -w | tr -d ' ')
if [ "$rules_words" -le "$RULES_WORD_BUDGET" ]; then
  ok "rules budget: templates/rules/ is $rules_words words (budget $RULES_WORD_BUDGET)"
else
  fail "rules budget: templates/rules/ is $rules_words words, over the $RULES_WORD_BUDGET budget" "cut or move an anchor to sop/Rules_SOP.md before adding"
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

# ── Saved workflows parse and ship (v4.34.0) ──────────────────────────────────
# workflows/*.js are Claude Code saved-workflow scripts: an `export const meta`
# literal first, then a plain-JS body with top-level await and a top-level
# `return`. `node --check` rejects a bare top-level return, so wrap the body in
# an async IIFE for the parse check — the meta block is a plain const there.

echo "== saved workflow scripts parse =="
if command -v node >/dev/null 2>&1; then
  WF_CHECK_DIR=$(mktemp -d)
  for wf in "$REPO_ROOT"/workflows/*.js; do
    [ -f "$wf" ] || continue
    wf_name=$(basename "$wf")
    if head -1 "$wf" | grep -q '^export const meta = {'; then
      ok "workflow meta is the first statement: $wf_name"
    else
      fail "workflow meta is not the first statement: $wf_name" "Claude Code drops /<name> from autocomplete"
    fi
    { echo '(async () => {'; sed 's/^export const meta/const meta/' "$wf"; echo '})()'; } > "$WF_CHECK_DIR/check.mjs"
    if node --check "$WF_CHECK_DIR/check.mjs" >/dev/null 2>&1; then
      ok "workflow parses: $wf_name"
    else
      fail "workflow does not parse: $wf_name" "$(node --check "$WF_CHECK_DIR/check.mjs" 2>&1 | head -3)"
    fi
  done
  rm -rf "$WF_CHECK_DIR"
else
  ok "workflow parse check: node not installed → skipped"
fi

# sync-method.sh must ship workflows/ to the consumer's .claude/workflows/, or
# /work's Step 5.2 falls back to sequential Agent dispatch on every project.
echo "== sync-method ships saved workflows =="
WF_TMP=$(mktemp -d)
mkdir -p "$WF_TMP/proj/.claude" "$WF_TMP/method/skills/demo" "$WF_TMP/method/workflows"
echo 'upstream demo body' > "$WF_TMP/method/skills/demo/SKILL.md"
printf 'export const meta = { name: "demo", description: "d" }\nreturn 1\n' > "$WF_TMP/method/workflows/demo.js"
WF_OUT=$(SYNC_METHOD_REEXEC=1 SYNC_METHOD_TEMP="$WF_TMP/method" \
  bash "$REPO_ROOT/scripts/sync-method.sh" --dry-run --target="$WF_TMP/proj" 2>&1)
case "$WF_OUT" in
  *"WOULD UPDATE .claude/workflows/demo.js"*)
    ok "workflows: a saved workflow ships to .claude/workflows/" ;;
  *)
    fail "workflows: demo.js not shipped" "$(echo "$WF_OUT" | grep -i -A2 'Workflows' | head -4)" ;;
esac
rm -rf "$WF_TMP"

# ── Overrides cover the whole skill directory (v4.31.3) ──────────────────────
# The skills-override discovery used `find ... -name '*.md'`, so a project could
# override SKILL.md but NOT skill.json — whose `description` is what Claude routes
# on. A project pinning a superseded skill to a redirect stub kept the stub in
# prose and had the metadata reverted to upstream on every sync, silently.
# Anchor: SiteLine, 2026-08-26 — repo-security-review, guarded since 2026-08-20,
# had been leaking its json description back on each sync the whole time.

echo "== sync-method overrides cover non-.md skill files =="
OVR_TMP=$(mktemp -d)
mkdir -p "$OVR_TMP/proj/.claude/skills/demo" \
         "$OVR_TMP/proj/.claude/overrides/skills/demo" \
         "$OVR_TMP/method/skills/demo"
# The fake method tree needs a skills/ dir: the portable-skills step pipes
# `ls -d "$TEMP/skills/"*/` into xargs, and under `set -o pipefail` an empty
# TEMP makes that pipeline fail and aborts the whole sync before Overrides.
echo 'upstream demo body' > "$OVR_TMP/method/skills/demo/SKILL.md"
echo 'upstream body'                    > "$OVR_TMP/proj/.claude/skills/demo/SKILL.md"
echo '{"description":"UPSTREAM"}'       > "$OVR_TMP/proj/.claude/skills/demo/skill.json"
echo 'local redirect stub'              > "$OVR_TMP/proj/.claude/overrides/skills/demo/SKILL.md"
echo '{"description":"SUPERSEDED"}'     > "$OVR_TMP/proj/.claude/overrides/skills/demo/skill.json"

# SYNC_METHOD_REEXEC=1 is load-bearing: without it the self-update guard would
# copy the fixture's (absent) sync-method.sh over the real one.
OVR_OUT=$(SYNC_METHOD_REEXEC=1 SYNC_METHOD_TEMP="$OVR_TMP/method" \
  bash "$REPO_ROOT/scripts/sync-method.sh" --dry-run --target="$OVR_TMP/proj" 2>&1)

case "$OVR_OUT" in
  *"WOULD OVERRIDE skills/demo/skill.json"*)
    ok "overrides: a non-.md file in the skill dir is discovered" ;;
  *)
    fail "overrides: skill.json override not discovered" \
         "find in sync-method.sh is filtering the skill-override set again" ;;
esac

case "$OVR_OUT" in
  *"WOULD OVERRIDE skills/demo/SKILL.md"*)
    ok "overrides: SKILL.md still discovered (no regression)" ;;
  *)
    fail "overrides: SKILL.md override not discovered" "the base case broke" ;;
esac

# The summary must not contradict the lines it just printed.
case "$OVR_OUT" in
  *"(no overrides found)"*)
    fail "overrides: dry-run summary says none while listing some" \
         "OVERRIDES_APPLIED not recorded on the DRY_RUN path" ;;
  *)
    ok "overrides: dry-run summary agrees with the overrides it listed" ;;
esac

rm -rf "$OVR_TMP"

# ── Branch resolution matches follow-up prefixes (v4.32.0, PIPER-793) ─────────
# pk ready and pk done both globbed feature/<ID>-* alone, so a follow-up fix on
# fix/<ID>-* was invisible: pk done errored "no local feature branch found"
# (which reads as "unknown issue"), the second PR never reached the Linear ship
# record, and the branch was never cleaned up. cmd_done also lacked the remote
# fallback cmd_ready had, so it gave up whenever the local branch was gone.
# Anchor: SiteLine — all five multi-PR issues across 185 ID-prefixed merged PRs
# had this shape; POC-426 and PIPER-782 were hand-patched five weeks apart.

echo "== branch resolution: feature|fix|hotfix, newest wins, remote fallback =="

# The picker must EXIT 0 on empty input, not merely print nothing. Under the
# `set -euo pipefail` at bin/pk:28, the natural grep|sort|head pipeline returns 1
# when grep matches nothing — and bash 3.2 honours errexit for a bare call while
# suppressing it inside `$( )`, so the fragile form is invisible to any test that
# only inspects captured output. Assert the status from a bare call, or this
# whole block is decorative: the exit code is the only channel the defect uses.
unit_pick() { ( cd "$REPO_ROOT" && source "$PK" && pk_branch_pick_newest "$1" ); }
unit_pick_rc() {
  ( cd "$REPO_ROOT" && source "$PK" >/dev/null 2>&1
    pk_branch_pick_newest "$1" >/dev/null )
  echo $?
}

[ "$(unit_pick_rc '')" = "0" ] && ok "pick-newest: empty input exits 0 (no errexit abort)" \
  || fail "pick-newest: empty input exits 0" "rc=$(unit_pick_rc '') — a failing pipeline here aborts the caller before its remote fallback"
[ "$(unit_pick_rc '

')" = "0" ] && ok "pick-newest: blank-only input exits 0 (no errexit abort)" \
  || fail "pick-newest: blank-only input exits 0" "rc=$(unit_pick_rc '

')"
[ -z "$(unit_pick '')" ] && ok "pick-newest: empty input → empty output" \
  || fail "pick-newest: empty input" "got: $(unit_pick '')"
[ "$(unit_pick '100 feature/A-1-x')" = "feature/A-1-x" ] \
  && ok "pick-newest: single candidate" || fail "pick-newest: single candidate" "got: $(unit_pick '100 feature/A-1-x')"
pick_many=$(unit_pick '100 feature/A-1-x
900 fix/A-1-y
50 hotfix/A-1-z')
[ "$pick_many" = "fix/A-1-y" ] \
  && ok "pick-newest: highest timestamp wins regardless of listing order" \
  || fail "pick-newest: highest timestamp wins" "got: $pick_many"

BR_TMP=$(mktemp -d)
mkdir -p "$BR_TMP/repo" "$BR_TMP/shim"
printf '#!/usr/bin/env bash\nexit 0\n' > "$BR_TMP/shim/gh"
chmod +x "$BR_TMP/shim/gh"

git -C "$BR_TMP/repo" init -q -b main
printf '```\nIntegration branch: main\n```\n' > "$BR_TMP/repo/method.config.md"
br_commit() { # $1 = committer date, $2 = message
  GIT_COMMITTER_DATE="$1" git -C "$BR_TMP/repo" \
    -c user.email=t@t -c user.name=t -c committer.email=t@t \
    commit -q --allow-empty -m "$2"
}
# Committer date, not author date: the sort key is %(committerdate:unix), and a
# fixture that only sets --date leaves every branch stamped "now" and silently
# tests nothing.
br_commit "2026-08-01T10:00:00" init
br_commit "2026-08-02T10:00:00" feature-work
git -C "$BR_TMP/repo" branch feature/PK-1-original
br_commit "2026-08-20T10:00:00" followup-fix
git -C "$BR_TMP/repo" branch fix/PK-1-followup
git -C "$BR_TMP/repo" branch hotfix/PK-2-urgent
git -C "$BR_TMP/repo" branch refactor/PK-5-extract
git -C "$BR_TMP/repo" branch chore/PK-6-deps
git -C "$BR_TMP/repo" branch docs/PK-7-guide
git -C "$BR_TMP/repo" branch wip/PK-11-override

run_br() { # $@ = pk args; captures combined output
  BR_OUT=$(cd "$BR_TMP/repo" && PATH="$BR_TMP/shim:$PATH" "$PK" "$@" 2>&1)
}

# The gh shim answers every call with exit 0 and no JSON, so pk gets as far as
# "no PR / not merged" and names the branch it resolved. That name IS the
# assertion — reaching this error at all means resolution succeeded.
run_br done PK-1
case "$BR_OUT" in
  *"no local feature branch found"*|*"no branch found for PK-1"*)
    fail "pk done resolves a follow-up fix/ branch" "still branch-not-found: $(echo "$BR_OUT" | head -1)" ;;
  *"fix/PK-1-followup"*)
    ok "pk done resolves a follow-up fix/ branch (newest commit wins over feature/)" ;;
  *)
    fail "pk done resolves a follow-up fix/ branch" "got: $(echo "$BR_OUT" | head -1)" ;;
esac

# The main path must not regress: a plain feature/ branch with no follow-up is
# what every ordinary issue looks like.
git -C "$BR_TMP/repo" branch feature/PK-3-solo
for sub in done ready; do
  run_br "$sub" PK-3
  case "$BR_OUT" in
    *"feature/PK-3-solo"*) ok "pk $sub still resolves a plain feature/ branch (main path)" ;;
    *) fail "pk $sub resolves a plain feature/ branch" "got: $(echo "$BR_OUT" | head -1)" ;;
  esac
done

run_br ready PK-1
case "$BR_OUT" in
  *"fix/PK-1-followup"*)
    ok "pk ready resolves a follow-up fix/ branch" ;;
  *)
    fail "pk ready resolves a follow-up fix/ branch" "got: $(echo "$BR_OUT" | head -1)" ;;
esac

run_br done PK-2
case "$BR_OUT" in
  *"hotfix/PK-2-urgent"*) ok "hotfix/ prefix resolves too" ;;
  *) fail "hotfix/ prefix resolves too" "got: $(echo "$BR_OUT" | head -1)" ;;
esac

# Every prefix in PK_BRANCH_PREFIXES must actually resolve. The original bug
# (PIPER-793) was a prefix list narrower than the naming convention it served;
# the re-widening is only safe if each entry is exercised here.
for pair in "refactor/PK-5-extract:PK-5" "chore/PK-6-deps:PK-6" "docs/PK-7-guide:PK-7"; do
  want=${pair%%:*}; id=${pair##*:}
  run_br ready "$id"
  case "$BR_OUT" in
    *"$want"*) ok "pk ready resolves ${want%%/*}/ prefix" ;;
    *) fail "pk ready resolves ${want%%/*}/ prefix" "got: $(echo "$BR_OUT" | head -1)" ;;
  esac
done

# PK_BRANCH_PREFIXES is caller-overridable. The override is the point of the
# env var, so it gets the coverage the hardcoded list lacked (PIPER-793).
BR_OUT=$(cd "$BR_TMP/repo" && PATH="$BR_TMP/shim:$PATH" PK_BRANCH_PREFIXES="wip" "$PK" ready PK-11 2>&1)
case "$BR_OUT" in
  *"wip/PK-11-override"*) ok "PK_BRANCH_PREFIXES override resolves a custom prefix" ;;
  *) fail "PK_BRANCH_PREFIXES override resolves a custom prefix" "got: $(echo "$BR_OUT" | head -1)" ;;
esac

# A whitespace-only override is neither unset nor empty, so ${x:-default} does not
# catch it and it word-splits to zero prefixes — every lookup would silently miss.
BR_OUT=$(cd "$BR_TMP/repo" && PATH="$BR_TMP/shim:$PATH" PK_BRANCH_PREFIXES="   " "$PK" ready PK-3 2>&1)
case "$BR_OUT" in
  *"feature/PK-3-solo"*) ok "whitespace-only PK_BRANCH_PREFIXES falls back to the default" ;;
  *) fail "whitespace-only PK_BRANCH_PREFIXES falls back to the default" "got: $(echo "$BR_OUT" | head -1)" ;;
esac

# The value is caller-controlled and was consumed by an unquoted `for p in $VAR`,
# which glob-expands as well as word-splits: a value containing a pattern would
# splice matching filenames from the cwd in as bogus "prefixes".
: > "$BR_TMP/repo/globbait1"; : > "$BR_TMP/repo/globbait2"
BR_OUT=$(cd "$BR_TMP/repo" && PATH="$BR_TMP/shim:$PATH" PK_BRANCH_PREFIXES="feature globbait*" "$PK" ready PK-404 2>&1)
case "$BR_OUT" in
  *globbait1*|*globbait2*) fail "PK_BRANCH_PREFIXES is not glob-expanded against the cwd" "leaked a filename: $(echo "$BR_OUT" | head -1)" ;;
  *) ok "PK_BRANCH_PREFIXES is not glob-expanded against the cwd" ;;
esac
rm -f "$BR_TMP/repo/globbait1" "$BR_TMP/repo/globbait2"

# The error must name every glob actually searched. The old text named only
# feature/<ID>-*, so a miss on a fix/ branch read as "I don't know this issue"
# rather than "I looked in three places and none matched".
for sub in done ready; do
  run_br "$sub" PK-404
  miss=""
  case "$BR_OUT" in *"feature/PK-404-*"*) ;; *) miss="feature" ;; esac
  case "$BR_OUT" in *"fix/PK-404-*"*)     ;; *) miss="$miss fix" ;; esac
  case "$BR_OUT" in *"hotfix/PK-404-*"*)  ;; *) miss="$miss hotfix" ;; esac
  case "$BR_OUT" in *"refactor/PK-404-*"*) ;; *) miss="$miss refactor" ;; esac
  case "$BR_OUT" in *"chore/PK-404-*"*)    ;; *) miss="$miss chore" ;; esac
  case "$BR_OUT" in *"docs/PK-404-*"*)     ;; *) miss="$miss docs" ;; esac
  if [ -z "$miss" ]; then
    ok "pk $sub: not-found error names every searched prefix"
  else
    fail "pk $sub: not-found error names every searched prefix" "missing:$miss — got: $(echo "$BR_OUT" | head -1)"
  fi
done

# Remote fallback: cmd_ready always had one, cmd_done did not. With the local
# branches deleted, both must still resolve from origin — and pk done must say
# out loud that there is nothing local to clean up rather than quietly posting a
# ship record with no commit list.
git -C "$BR_TMP/repo" init -q --bare "$BR_TMP/remote.git" 2>/dev/null || git init -q --bare "$BR_TMP/remote.git"
git -C "$BR_TMP/repo" remote add origin "$BR_TMP/remote.git"
git -C "$BR_TMP/repo" push -q origin main fix/PK-1-followup
git -C "$BR_TMP/repo" branch -D fix/PK-1-followup feature/PK-1-original >/dev/null 2>&1

run_br done PK-1
case "$BR_OUT" in
  *"fix/PK-1-followup"*) ok "pk done falls back to origin when no local branch (parity with pk ready)" ;;
  *) fail "pk done remote fallback" "got: $(echo "$BR_OUT" | head -1)" ;;
esac
case "$BR_OUT" in
  *"resolved from origin"*) ok "pk done says a remote-only resolution has nothing local to clean up" ;;
  *) fail "pk done announces remote-only resolution" "no advisory in: $(echo "$BR_OUT" | head -2)" ;;
esac

run_br ready PK-1
case "$BR_OUT" in
  *"fix/PK-1-followup"*) ok "pk ready remote fallback still works (no regression)" ;;
  *) fail "pk ready remote fallback" "got: $(echo "$BR_OUT" | head -1)" ;;
esac

rm -rf "$BR_TMP"

# ── Follow-up ship records (v4.32.0, PIPER-793) ──────────────────────────────
# A second pk done on an already-shipped issue must read as a follow-up, not as
# a repeat of the first ship. Fails closed: anything that isn't a provable prior
# ship (no key, unreachable Linear, malformed response) is treated as a first
# ship, because mislabelling a genuine first ship is the worse error.

echo "== follow-up ship record detection =="

unit_shipped() { # $1 = stubbed pk_linear_comments payload, $2 = issue id
  ( cd "$REPO_ROOT" && source "$PK" \
    && eval "pk_linear_comments() { printf '%s' '$1'; }" \
    && pk_has_shipped_comment "$2" )
}

if unit_shipped '[{"body":"**Shipped — PK-1**\nPR: http://x/1"}]' PK-1; then
  ok "shipped-detect: prior Shipped comment → follow-up"
else
  fail "shipped-detect: prior Shipped comment" "returned false"
fi

if unit_shipped '[]' PK-1; then
  fail "shipped-detect: empty thread" "returned true"
else
  ok "shipped-detect: empty thread → first ship"
fi

if unit_shipped '' PK-1; then
  fail "shipped-detect: Linear unreachable" "returned true — must fail closed"
else
  ok "shipped-detect: unreachable Linear → first ship (fails closed)"
fi

# A Shipped record for a DIFFERENT issue must not mark this one a follow-up.
if unit_shipped '[{"body":"**Shipped — PK-9**\nPR: http://x/9"}]' PK-1; then
  fail "shipped-detect: other issue's record" "returned true"
else
  ok "shipped-detect: another issue's Shipped record does not count"
fi

# Substring collision: PK-10's record must not mark PK-1 a follow-up.
if unit_shipped '[{"body":"**Shipped \u2014 PK-10**\nPR: http://x/10"}]' PK-1; then
  fail "shipped-detect: PK-10 vs PK-1" "substring match — id comparison is not exact"
else
  ok "shipped-detect: PK-10's record does not mark PK-1 a follow-up"
fi

# Third ship stays a follow-up — the header it matches is its own.
if unit_shipped '[{"body":"**Shipped (follow-up) — PK-1**\nPR: http://x/2"}]' PK-1; then
  ok "shipped-detect: a follow-up record also counts (third ship stays follow-up)"
else
  fail "shipped-detect: follow-up record counts" "returned false"
fi

# The --force ship audit line ("Shipped without a HEAD-matching...") is NOT a
# ship record and must not suppress the first real Shipped comment.
if unit_shipped '[{"body":"Shipped without a HEAD-matching verify-complete.md (--force) PK-1"}]' PK-1; then
  fail "shipped-detect: --force audit line" "counted as a ship record"
else
  ok "shipped-detect: the --force audit comment is not a ship record"
fi

# ── TPM on-merge notes (v5.1.0, sourced) ─────────────────────────────────────
# /tpm leaves `[tpm DATE] on-merge: <cmd> · <why>` comments on an issue; pk done
# parses them back after the merge. The parser is pure (comment text on stdin →
# one command per line); the fetch fails closed to nothing, exit 0.

echo "== tpm on-merge notes (sourced) =="

unit_on_merge()      { ( cd "$REPO_ROOT" && source "$PK" && pk_tpm_on_merge_from_text ); }
unit_on_merge_cmds() { # $1 = stubbed pk_linear_comments payload
  ( cd "$REPO_ROOT" && source "$PK" \
    && eval "pk_linear_comments() { printf '%s' '$1'; }" \
    && pk_tpm_on_merge_commands PK-1 )
}

v=$(printf '[tpm 2026-10-11] on-merge: pk focus I7.P10 C --swap · tier C moves to Finance settings once this merges\n' | unit_on_merge)
[ "$v" = "pk focus I7.P10 C --swap" ] && ok "on-merge: one note → one command, the rationale after · dropped" || fail "on-merge: one note" "got '$v'"
v=$(printf 'Review round 1\n[tpm 2026-10-11] on-merge: pk focus I7.P10 C --swap · first\n**Shipped — PK-1**\nPR: http://x/1\n[tpm 2026-10-12] on-merge: pk issue relate PK-9 --blocked-by PK-1 · second\n' | unit_on_merge | paste -sd '|' -)
[ "$v" = "pk focus I7.P10 C --swap|pk issue relate PK-9 --blocked-by PK-1" ] && ok "on-merge: two notes across a thread → two commands, in order" || fail "on-merge: two notes" "got '$v'"
v=$(printf '[tpm 2026-10-11] on-merge: pk focus I7.P10 C --swap\n' | unit_on_merge)
[ "$v" = "pk focus I7.P10 C --swap" ] && ok "on-merge: no · → the whole remainder is the command" || fail "on-merge: no separator" "got '$v'"
v=$(printf 'as agreed, on-merge: pk focus I7.P10 C\nsee [tpm 2026-10-11] on-merge: pk focus X\n[tpm 2026-10-11]on-merge: pk focus Y\n' | unit_on_merge)
[ -z "$v" ] && ok "on-merge: on-merge: anywhere but the start of a [tpm DATE] line → ignored" || fail "on-merge: mid-line" "got '$v'"
v=$(printf '[tpm 2026-10-11] MUST — ship PK-1 by Thursday\n[tpm 2026-10-11] WAIT — PK-7 blocked by vendor\n' | unit_on_merge)
[ -z "$v" ] && ok "on-merge: [tpm DATE] MUST / WAIT notes → nothing" || fail "on-merge: MUST note" "got '$v'"
v=$(printf '[tpm 2026-10-11] on-merge:    pk focus I7.P10 C    · padded\n[tpm 2026-10-11] on-merge: pk focus I7.P11 B   \n' | unit_on_merge | sed -n l | paste -sd '|' -)
[ "$v" = 'pk focus I7.P10 C$|pk focus I7.P11 B$' ] && ok "on-merge: surrounding and trailing spaces trimmed" || fail "on-merge: trim" "got '$v'"
v=$(printf '[tpm 2026-10-11] on-merge:  · nothing before the dot\n' | unit_on_merge)
[ -z "$v" ] && ok "on-merge: an empty command is dropped" || fail "on-merge: empty" "got '$v'"

# Fetch: one command per note across two comments, oldest first.
v=$(unit_on_merge_cmds '[{"body":"[tpm 2026-10-11] on-merge: pk focus I7.P10 C --swap · first"},{"body":"**Shipped — PK-1**"},{"body":"[tpm 2026-10-12] on-merge: pk issue relate PK-9 --blocked-by PK-1 · second"}]' | paste -sd '|' -)
[ "$v" = "pk focus I7.P10 C --swap|pk issue relate PK-9 --blocked-by PK-1" ] && ok "on-merge fetch: two comments → two commands in thread order" || fail "on-merge fetch: two comments" "got '$v'"
v=$(unit_on_merge_cmds '{"errors":[{"message":"nope"}]}'); code=$?
[ $code -eq 0 ] && [ -z "$v" ] && ok "on-merge fetch: non-array response → nothing, exit 0" || fail "on-merge fetch: non-array" "exit $code, got '$v'"
# No API key: pk_linear_gql refuses, the fetch stays silent and exit 0.
make_fixture
write_config '```
Team name: Eng
```'
v=$( cd "$FIXTURE" && unset LINEAR_API_KEY && source "$PK" && pk_tpm_on_merge_commands PK-1 2>&1 ); code=$?
[ $code -eq 0 ] && [ -z "$v" ] && ok "on-merge fetch: no API key → nothing, exit 0 (never fails pk done)" || fail "on-merge fetch: no key" "exit $code, got '$v'"
cleanup

# ── Unit tests: pk sessions (sourced) ────────────────────────────────────────
# pk sessions reads Claude Code transcript tails. The fixtures live under a temp
# projects root (PK_CLAUDE_PROJECTS_DIR), never the real ~/.claude/projects.
# Slug directories start with a dash, as the real ones do. The scan helper takes
# `now` as an argument, so file age is pinned by a fixed mtime plus an offset.

echo "== pk sessions (sourced) =="

# Fixture transcripts have no running process behind them. {} is the "process
# table could not answer" value, which leaves every state alone — the liveness
# filter itself is covered directly below.
export PK_SESSIONS_LIVE_CWDS='{}'

unit_sess_live() { ( cd "$REPO_ROOT" && source "$PK" && pk_sessions_apply_liveness "$1" ); }
LIVE_IN='[
  {"sessionId":"a","cwd":"/w/one","state":"waiting","age_secs":30,"ask":"verdict?"},
  {"sessionId":"b","cwd":"/w/one","state":"waiting","age_secs":900,"ask":"older"},
  {"sessionId":"c","cwd":"/w/two","state":"waiting","age_secs":60,"ask":"q"},
  {"sessionId":"d","cwd":"/w/three","state":"working","age_secs":5,"ask":""}
]'
# One process in /w/one → the newer transcript is live, the older is closed;
# /w/two has no process → closed; /w/three has one → untouched.
v=$(printf '%s' "$LIVE_IN" | unit_sess_live '{"/w/one":1,"/w/three":1}' | jq -c 'sort_by(.sessionId) | map([.sessionId,.state,.ask])')
[ "$v" = '[["a","waiting","verdict?"],["b","closed",""],["c","closed",""],["d","working",""]]' ] \
  && ok "sessions liveness: newest transcript per live process stays, the rest close" \
  || fail "sessions liveness" "got $v"
v=$(printf '%s' "$LIVE_IN" | unit_sess_live '{"/w/one":2}' | jq -c '[.[] | select(.cwd=="/w/one") | .state]')
[ "$v" = '["waiting","waiting"]' ] \
  && ok "sessions liveness: two processes in one worktree keep both sessions" \
  || fail "sessions liveness: shared worktree" "got $v"
v=$(printf '%s' "$LIVE_IN" | unit_sess_live '{}' | jq -c '[.[].state]')
[ "$v" = '["waiting","waiting","waiting","working"]' ] \
  && ok "sessions liveness: unknown process table ({}) leaves every state alone" \
  || fail "sessions liveness: fail-open" "got $v"

SESS_ROOT=$(mktemp -d)
SESS_DIR="$SESS_ROOT/-Users-t-Projects-app"
mkdir -p "$SESS_DIR"

unit_sess_scan()   { ( cd "$REPO_ROOT" && source "$PK" && pk_sessions_scan_file "$@" ); }
unit_sess_render() { ( cd "$REPO_ROOT" && source "$PK" && pk_sessions_render "$@" ); }
unit_sess_link()   { ( cd "$REPO_ROOT" && source "$PK" && PK_CLAUDE_PROJECTS_DIR="$SESS_ROOT" CLAUDE_SESSION_ID="${1:-}" CLAUDE_CODE_SESSION_ID="" pk_sessions_crosslink ); }
# GNU first: on GNU, `stat -f` is --file-system and prints to stdout before failing.
sess_mtime()       { stat -c %Y -- "$1" 2>/dev/null || stat -f %m -- "$1"; }

S_META='"cwd":"/Users/t/Projects/app/.worktrees/PK-12-thing","gitBranch":"feature/PK-12-thing","isSidechain":false'
S_USER='{"type":"user",'"$S_META"',"message":{"role":"user","content":"go"}}'
S_TOOL='{"type":"assistant",'"$S_META"',"message":{"role":"assistant","stop_reason":"tool_use","content":[{"type":"tool_use","id":"t1","name":"Bash"}]}}'
S_RESULT='{"type":"user",'"$S_META"',"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"t1"}]}}'
S_END='{"type":"assistant",'"$S_META"',"message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"done"}]}}'

# waiting: end_turn, followed by the trailing lines a finished turn really
# leaves (hook summary, duration, title, snapshot) plus types pk has never seen.
{
  echo 'ntent":[{"type":"text","text":"cut mid-object by the tail"}]}}'
  echo "$S_USER"; echo "$S_TOOL"; echo "$S_RESULT"; echo "$S_END"
  echo '{"type":"system","subtype":"stop_hook_summary",'"$S_META"'}'
  echo '{"type":"system","subtype":"turn_duration",'"$S_META"'}'
  echo '{"type":"ai-title","aiTitle":"Auto title","sessionId":"s-wait"}'
  echo '{"type":"custom-title","customTitle":"Named by hand","sessionId":"s-wait"}'
  echo '{"type":"file-history-snapshot","snapshot":{}}'
  echo '{"type":"never-seen-before","payload":[1,2]}'
  echo '["not","an","object"]'
  echo 'not json at all'
} > "$SESS_DIR/s-wait.jsonl"

# waiting via away_summary, with the ask; ai-title only; main checkout (no id).
{
  echo '{"type":"user","cwd":"/Users/t/Projects/app","gitBranch":"main","message":{"role":"user","content":"go"}}'
  echo '{"type":"assistant","cwd":"/Users/t/Projects/app","gitBranch":"main","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"plan"}]}}'
  echo '{"type":"ai-title","aiTitle":"Auto title","sessionId":"s-away"}'
  echo '{"type":"system","subtype":"away_summary","cwd":"/Users/t/Projects/app","gitBranch":"main","content":"The plan is written.\n  Next I need your verdict: proceed or revise. (disable recaps in /config)"}'
} > "$SESS_DIR/s-away.jsonl"

# An away_summary from before the latest user turn is an answered question.
{
  echo '{"type":"system","subtype":"away_summary",'"$S_META"',"content":"Old question"}'
  echo "$S_USER"; echo "$S_END"
} > "$SESS_DIR/s-answered.jsonl"

{ echo "$S_USER"; echo "$S_TOOL"; } > "$SESS_DIR/s-tool.jsonl"
{ echo "$S_USER"; echo "$S_TOOL"; echo "$S_RESULT"; } > "$SESS_DIR/s-work.jsonl"
# A subagent's lines never decide the parent session's state.
{ echo "$S_USER"; echo "$S_TOOL"; echo "$S_RESULT"
  echo '{"type":"assistant","isSidechain":true,"message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"sub"}]}}'
} > "$SESS_DIR/s-side.jsonl"

touch -t 202601010000.00 "$SESS_DIR"/*.jsonl
SESS_T0=$(sess_mtime "$SESS_DIR/s-wait.jsonl")

sess_field() { # file, age-offset, jq-filter [, window]
  unit_sess_scan "$SESS_DIR/$1.jsonl" "$((SESS_T0 + $2))" "${4:-0}" | jq -r "$3"
}
sess_expect() { # name, got, want
  if [ "$2" = "$3" ]; then ok "$1"; else fail "$1" "want '$3', got '$2'"; fi
}

sess_expect "sessions: end_turn is waiting"                 "$(sess_field s-wait 10 .state)" "waiting"
sess_expect "sessions: unknown line types are ignored"      "$(sess_field s-wait 10 '.state + "/" + .sessionId')" "waiting/s-wait"
sess_expect "sessions: a partial first line is tolerated"   "$(sess_field s-wait 10 '.cwd')" "/Users/t/Projects/app/.worktrees/PK-12-thing"
sess_expect "sessions: custom-title beats ai-title"         "$(sess_field s-wait 10 .title)" "Named by hand"
sess_expect "sessions: ai-title when there is no custom"    "$(sess_field s-away 10 .title)" "Auto title"
sess_expect "sessions: issue id parsed from the branch"     "$(sess_field s-wait 10 .issue)" "PK-12"
sess_expect "sessions: no id falls back to the cwd's name"  "$(sess_field s-away 10 .issue)" "app"
sess_expect "sessions: away_summary is waiting"             "$(sess_field s-away 10 .state)" "waiting"
sess_expect "sessions: ask is the away_summary, collapsed"  "$(sess_field s-away 10 .ask)" "The plan is written. Next I need your verdict: proceed or revise."
sess_expect "sessions: an answered away_summary is no ask"  "$(sess_field s-answered 10 '.state + "/" + .ask')" "waiting/"
sess_expect "sessions: quiet unanswered tool call is waiting?" "$(sess_field s-tool 300 .state)" "waiting?"
sess_expect "sessions: a fresh tool call is working"        "$(sess_field s-tool 10 .state)" "working"
sess_expect "sessions: tool_result last is working"         "$(sess_field s-work 300 .state)" "working"
sess_expect "sessions: sidechain lines do not decide state" "$(sess_field s-side 300 .state)" "working"
sess_expect "sessions: older than the window is stale"      "$(sess_field s-wait 7200 .state 3600)" "stale"
sess_expect "sessions: age is human-readable"               "$(sess_field s-wait 20 .age)/$(sess_field s-wait 720 .age)/$(sess_field s-wait 10800 .age)" "20s/12m/3h"

LONG_ASK=$(printf 'x%.0s' $(seq 1 200))
echo '{"type":"system","subtype":"away_summary",'"$S_META"',"content":"'"$LONG_ASK"'"}' > "$SESS_DIR/s-long.jsonl"
touch -t 202601010000.00 "$SESS_DIR/s-long.jsonl"
sess_expect "sessions: ask is clipped to 90 chars"          "$(sess_field s-long 10 '.ask | length')" "91"

SESS_RENDER=$(printf '%s' '[
  {"state":"stale","issue":"PK-9","age":"3h","age_secs":10800,"ask":"","title":"Old one"},
  {"state":"working","issue":"app","age":"1m","age_secs":60,"ask":"","title":"Focus lanes"},
  {"state":"working","issue":"PK-3","age":"20s","age_secs":20,"ask":"","title":"Table"},
  {"state":"waiting?","issue":"PK-2","age":"4m","age_secs":240,"ask":"","title":"Ignored"},
  {"state":"waiting","issue":"PK-1","age":"12m","age_secs":720,"ask":"Next I need your verdict","title":"T"}
]' | unit_sess_render "last 60 min")
sess_expect "sessions render: header counts live rows (not stale) and both waiting states" \
  "$(printf '%s\n' "$SESS_RENDER" | sed -n 1p)" "4 live sessions (last 60 min) — 2 waiting on you"
sess_expect "sessions render: waiting → waiting? → working → stale, then age" \
  "$(printf '%s\n' "$SESS_RENDER" | sed -n '3,$p' | awk '{print $2}' | tr '\n' ' ')" "PK-1 PK-2 PK-3 app PK-9 "
sess_expect "sessions render: waiting row quotes the ask" \
  "$(printf '%s\n' "$SESS_RENDER" | sed -n 3p)" 'waiting   PK-1  12m  "Next I need your verdict"'
sess_expect "sessions render: waiting? row names the unanswered tool call" \
  "$(printf '%s\n' "$SESS_RENDER" | sed -n 4p)" 'waiting?  PK-2   4m  unanswered tool call (permission?)'
sess_expect "sessions render: empty array" "$(printf '[]' | unit_sess_render "last 60 min")" "No live sessions (last 60 min)."

# Cross-link and the command itself walk the real clock, so age the fixtures
# relative to now: two waiting (s-wait, s-away), one waiting? (s-tool, 5 min
# quiet), one working (s-work).
rm -f "$SESS_DIR/s-answered.jsonl" "$SESS_DIR/s-side.jsonl" "$SESS_DIR/s-long.jsonl"
touch "$SESS_DIR/s-wait.jsonl" "$SESS_DIR/s-away.jsonl" "$SESS_DIR/s-work.jsonl"
touch -t "$(date -v-5M +%Y%m%d%H%M.%S 2>/dev/null || date -d '5 minutes ago' +%Y%m%d%H%M.%S)" "$SESS_DIR/s-tool.jsonl"
mkdir -p "$SESS_DIR/s-wait/subagents"
echo "$S_END" > "$SESS_DIR/s-wait/subagents/agent-1.jsonl"

sess_expect "sessions cross-link: counts waiting + waiting?" \
  "$(unit_sess_link | sed -n 1p)" "3 sessions are waiting on you → pk sessions"
sess_expect "sessions cross-link: one line and a blank" "$(unit_sess_link | wc -l | tr -d ' ')" "2"
sess_expect "sessions cross-link: the current session is excluded" \
  "$(unit_sess_link s-wait | sed -n 1p)" "2 sessions are waiting on you → pk sessions"

rm -f "$SESS_DIR/s-wait.jsonl" "$SESS_DIR/s-away.jsonl" "$SESS_DIR/s-tool.jsonl"
sess_expect "sessions cross-link: silent when nobody waits" "$(unit_sess_link | wc -c | tr -d ' ')" "0"
if ( cd "$REPO_ROOT" && source "$PK" && PK_CLAUDE_PROJECTS_DIR="$SESS_ROOT/missing" pk_sessions_crosslink ) >/dev/null 2>&1; then
  ok "sessions cross-link: a missing projects dir never fails the caller"
else
  fail "sessions cross-link: missing projects dir" "returned non-zero"
fi

make_fixture
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" PK_CLAUDE_PROJECTS_DIR="$SESS_ROOT" "$PK" sessions --json 2>&1)
sess_expect "pk sessions --json: subagent transcripts are not sessions" \
  "$(printf '%s' "$RUN_OUT" | jq -r 'map(.sessionId) | join(",")')" "s-work"
RUN_OUT=$(cd "$FIXTURE" && PATH="$FIXTURE/shim:$PATH" PK_CLAUDE_PROJECTS_DIR="$SESS_ROOT" "$PK" sessions --minutes nope 2>&1); RUN_CODE=$?
if [ $RUN_CODE -ne 0 ]; then ok "pk sessions: a non-numeric --minutes is refused"; else fail "pk sessions: --minutes nope" "exit 0"; fi
rm -rf "$FIXTURE" "$SESS_ROOT"; FIXTURE=""

# ── Unit tests: pk focus / pk issue set|relate|comment (sourced, stubbed) ─────
# Every Linear write goes through pk_linear_gql, so the stub below replaces it
# after pk is sourced: it logs each (query, variables) pair, answers reads from
# two fixture files, and APPLIES a projectUpdate to the initiatives fixture so
# the re-read pk focus insists on sees what was written (STUB_FREEZE=1 drops the
# write, for the unconfirmed-write case). Nothing here touches the network.

echo "== pk focus (sourced, stubbed network) =="

make_fixture
write_config '```
Team name: Eng
```'
GQL_LOG="$FIXTURE/gql.log"; STUB_STATE="$FIXTURE/initiatives.json"; STUB_ISSUES="$FIXTURE/issues.json"
STUB_TEAM="$FIXTURE/team.json"; STUB_SEARCH="$FIXTURE/search.json"
cat > "$FIXTURE/gql-stub.sh" <<'EOF'
pk_linear_gql() {
  printf '%s\t%s\n' "$1" "$(printf '%s' "${2:-null}" | jq -c .)" >> "$GQL_LOG"
  case "$1" in
    mutation*projectUpdate*)
      if [ -z "${STUB_FREEZE:-}" ]; then
        jq -c --arg id "$(printf '%s' "$2" | jq -r .id)" --argjson p "$(printf '%s' "$2" | jq -r .p)" \
          '(.data.initiatives.nodes[].projects.nodes[] | select(.id == $id) | .priority) = $p' \
          "$STUB_STATE" > "$STUB_STATE.n" && mv "$STUB_STATE.n" "$STUB_STATE"
      fi
      echo '{"data":{"projectUpdate":{"success":true}}}' ;;
    mutation*issueUpdate*)         echo '{"data":{"issueUpdate":{"success":true}}}' ;;
    mutation*issueCreate*)         echo '{"data":{"issueCreate":{"success":true,"issue":{"id":"u31","identifier":"RS-31","url":"https://linear.app/t/issue/RS-31"}}}}' ;;
    mutation*issueRelationCreate*) echo '{"data":{"issueRelationCreate":{"success":true}}}' ;;
    mutation*commentCreate*)       echo '{"data":{"commentCreate":{"success":true}}}' ;;
    # Reads behind the v5.0.0 verbs. `teams(filter` precedes `*initiatives*`
    # because the projects selection nests an initiatives sub-field.
    *"teams(filter"*)   cat "$STUB_TEAM" ;;
    *workflowStates*)   echo '{"data":{"workflowStates":{"nodes":[{"id":"s-ns","name":"Needs Spec"},{"id":"s-appr","name":"Approved"},{"id":"s-ip","name":"In Progress"}]}}}' ;;
    *issueLabels*)      echo '{"data":{"issueLabels":{"nodes":[{"id":"l-bug","name":"bug","isGroup":false},{"id":"l-tq","name":"tier:quick","isGroup":false},{"id":"l-grp","name":"tier","isGroup":true}]}}}' ;;
    *"issues(filter"*)  cat "$STUB_SEARCH" ;;
    *gqlErrorFixture*)  echo '{"data":null,"errors":[{"message":"Field nope not found"}]}' ;;
    *gqlOkFixture*)     echo '{"data":{"viewer":{"id":"me"}}}' ;;
    *initiatives*)  cat "$STUB_STATE" ;;
    *"issue(id:"*)  jq -c --arg id "$(printf '%s' "$2" | jq -r .id)" '{data:{issue:(.[$id] // null)}}' "$STUB_ISSUES" ;;
    *) echo '{}' ;;
  esac
}
EOF
unit_focus() { ( cd "$FIXTURE" && source "$PK" && source "$FIXTURE/gql-stub.sh" && LINEAR_API_KEY=lin_test cmd_focus "$@" 2>&1 ); }
unit_issue() { ( cd "$FIXTURE" && source "$PK" && source "$FIXTURE/gql-stub.sh" && LINEAR_API_KEY=lin_test cmd_issue "$@" 2>&1 ); }
unit_project() { ( cd "$FIXTURE" && source "$PK" && source "$FIXTURE/gql-stub.sh" && LINEAR_API_KEY=lin_test cmd_project "$@" 2>&1 ); }
unit_gql() { ( cd "$FIXTURE" && source "$PK" && source "$FIXTURE/gql-stub.sh" && LINEAR_API_KEY=lin_test cmd_gql "$@" ); }
# Logged mutations in order, as "name<TAB>variables" (compact JSON).
gql_writes() { awk -F'\t' '/^mutation/ { match($1, /\{ *[A-Za-z]+/); n = substr($1, RSTART, RLENGTH); sub(/^\{ */, "", n); print n "\t" $2 }' "$GQL_LOG"; }
write_names() { gql_writes | cut -f1 | paste -sd, -; }
write_vars()  { gql_writes | sed -n "${1}p" | cut -f2; }
# Logged reads (everything that is not a mutation), same shape: "query<TAB>variables".
gql_reads()  { awk -F'\t' '!/^[[:space:]]*mutation/ { print }' "$GQL_LOG"; }
read_query() { gql_reads | sed -n "${1}p" | cut -f1; }
read_vars()  { gql_reads | sed -n "${1}p" | cut -f2; }

FOCUS_STATE_FIX='{"data":{"initiatives":{"nodes":[
  {"name":"i5. Build","status":"Active","projects":{"nodes":[
    {"id":"c","name":"I5.P1. Medium lane","state":"started","priority":3},
    {"id":"a","name":"P2. Urgent lane","state":"planned","priority":1},
    {"id":"b","name":"I5.P3. High lane","state":"backlog","priority":2},
    {"id":"z","name":"I5.P6. None","state":"planned","priority":0}]}}]}}}'
reset_focus() { printf '%s' "$FOCUS_STATE_FIX" > "$STUB_STATE"; : > "$GQL_LOG"; }

# Read mode: the strip plus one line per lane, nothing written.
reset_focus
out=$(unit_focus); code=$?
exp='Focus  A I5.P2 · B I5.P3 · C I5.P1
  A  P2. Urgent lane
  B  I5.P3. High lane
  C  I5.P1. Medium lane'
[ $code -eq 0 ] && [ "$out" = "$exp" ] && [ -z "$(gql_writes)" ] \
  && ok "focus: read mode prints strip + one line per lane, no write" \
  || fail "focus: read mode" "exit $code, got:
$out"

# Exclusive tiers: a held tier is refused without --swap, and nothing is written.
reset_focus
out=$(unit_focus I5.P3 A); code=$?
[ $code -ne 0 ] && [ "$out" = "A is held by I5.P2 — pass --swap to move it to none" ] && [ -z "$(gql_writes)" ] \
  && ok "focus: held tier refused without --swap (exit 1, no write)" \
  || fail "focus: held tier refused" "exit $code, out: $out, writes: $(gql_writes)"

# --swap: clear the holder (a → 0) THEN set the lane (b → 1), both via projectUpdate
# carrying input.priority; the strip afterwards is the re-read.
reset_focus
out=$(unit_focus I5.P3 A --swap); code=$?
if [ $code -eq 0 ] && [ "$(write_names)" = "projectUpdate,projectUpdate" ] \
   && [ "$(write_vars 1)" = '{"id":"a","p":0}' ] && [ "$(write_vars 2)" = '{"id":"b","p":1}' ]; then
  ok "focus: --swap clears the holder (a→0) then sets the lane (b→1)"
else
  fail "focus: --swap order" "exit $code, writes: $(gql_writes), out: $out"
fi
grep -q 'projectUpdate(id: \$id, input: {priority: \$p})' "$GQL_LOG" \
  && ok "focus: mutation is projectUpdate(id, input: {priority}) — ProjectUpdateInput.priority" \
  || fail "focus: projectUpdate shape" "$(grep mutation "$GQL_LOG")"
if printf '%s\n' "$out" | grep -q '^I5.P3 → A$' && printf '%s\n' "$out" | grep -q '^Focus  A I5.P3 · B — · C I5.P1$'; then
  ok "focus: after --swap the strip is the re-read (A I5.P3, B freed)"
else
  fail "focus: post-swap strip" "got:
$out"
fi

# Idempotent: already at that tier → say so, no write (args are case-insensitive).
reset_focus
out=$(unit_focus i5.p1 c); code=$?
[ $code -eq 0 ] && [ "$out" = "I5.P1 already tier C (skip)" ] && [ -z "$(gql_writes)" ] \
  && ok "focus: already at tier → skip, no write" \
  || fail "focus: no-op" "exit $code, out: $out, writes: $(gql_writes)"

# none → priority 0; then a free tier is set without --swap.
reset_focus
out=$(unit_focus I5.P3 none); code=$?
[ $code -eq 0 ] && [ "$(write_vars 1)" = '{"id":"b","p":0}' ] && printf '%s\n' "$out" | grep -q '^I5.P3 → none$' \
  && ok "focus: none → priority 0" \
  || fail "focus: none" "exit $code, writes: $(gql_writes), out: $out"
: > "$GQL_LOG"
out=$(unit_focus I5.P6 B); code=$?
[ $code -eq 0 ] && [ "$(write_vars 1)" = '{"id":"z","p":2}' ] && printf '%s\n' "$out" | grep -q '^Focus  A I5.P2 · B I5.P6 · C I5.P1$' \
  && ok "focus: free tier set without --swap; strip from re-read" \
  || fail "focus: free tier" "exit $code, writes: $(gql_writes), out: $out"

# A write the re-read does not confirm is an error, and no tier is printed
# (the mutation still answers success:true — only the re-read tells the truth).
reset_focus
out=$(STUB_FREEZE=1 unit_focus I5.P3 none); code=$?
if [ $code -ne 0 ] && printf '%s\n' "$out" | grep -q 'write did not land' && ! printf '%s\n' "$out" | grep -q '→ none'; then
  ok "focus: unconfirmed write → error, never prints the unconfirmed tier"
else
  fail "focus: unconfirmed write" "exit $code, out: $out"
fi

# Unknown tag, ambiguous bare tag, bad tier → exit 1, no write.
reset_focus
out=$(unit_focus I9.P9 A); code=$?
[ $code -ne 0 ] && printf '%s\n' "$out" | grep -q 'matches no live' && [ -z "$(gql_writes)" ] \
  && ok "focus: unknown tag → exit 1, lists live lanes" || fail "focus: unknown tag" "exit $code, out: $out"
printf '%s' '{"data":{"initiatives":{"nodes":[
  {"name":"i5. Build","status":"Active","projects":{"nodes":[{"id":"c","name":"I5.P1. One","state":"started","priority":0}]}},
  {"name":"i6. Next","status":"Active","projects":{"nodes":[{"id":"d","name":"I6.P1. Two","state":"planned","priority":0}]}}]}}}' > "$STUB_STATE"
: > "$GQL_LOG"
out=$(unit_focus P1 A); code=$?
[ $code -ne 0 ] && printf '%s\n' "$out" | grep -q 'ambiguous' && [ -z "$(gql_writes)" ] \
  && ok "focus: bare P1 across two initiatives is ambiguous, no write" || fail "focus: ambiguous" "exit $code, out: $out"
reset_focus
out=$(unit_focus I5.P6 Z); code=$?
[ $code -ne 0 ] && [ -z "$(gql_writes)" ] && ok "focus: tier must be A|B|C|none" || fail "focus: bad tier" "exit $code, out: $out"

echo "== pk issue set / relate / comment (sourced, stubbed network) =="

# RS-30 is already blocked by RS-28 and merely `related` to RS-29.
cat > "$STUB_ISSUES" <<'EOF'
{"RS-30":{"id":"u30","identifier":"RS-30","title":"Blocked one","priority":3,"sortOrder":100,
          "state":{"id":"s-appr","name":"Approved"},"project":null,"labels":{"nodes":[{"id":"l-bug","name":"bug"}]},
          "relations":{"nodes":[{"type":"blocks","relatedIssue":{"id":"u31","identifier":"RS-31"}},{"type":"duplicate","relatedIssue":{"id":"u12","identifier":"RS-12"}}]},
          "inverseRelations":{"nodes":[{"type":"blocks","issue":{"id":"u28","identifier":"RS-28"}},{"type":"related","issue":{"id":"u29","identifier":"RS-29"}}]}},
 "RS-29":{"id":"u29","identifier":"RS-29","title":"Blocker","priority":0,"inverseRelations":{"nodes":[]},
          "state":{"id":"s-ns","name":"Needs Spec"},"project":null,"labels":{"nodes":[]}},
 "RS-28":{"id":"u28","identifier":"RS-28","title":"Existing blocker","priority":2,"inverseRelations":{"nodes":[]},
          "state":{"id":"s-ip","name":"In Progress"},"project":{"id":"pa","name":"I5.P1. Medium lane"},"labels":{"nodes":[]}}}
EOF

: > "$GQL_LOG"
out=$(unit_issue set RS-30 --priority 1); code=$?
if [ $code -eq 0 ] && [ "$out" = "  Linear: RS-30 priority 3 → 1" ] && [ "$(write_names)" = "issueUpdate" ] \
   && [ "$(write_vars 1)" = '{"id":"u30","p":1}' ] && grep -q 'issueUpdate(id: \$id, input: {priority: \$p})' "$GQL_LOG"; then
  ok "issue set: issueUpdate input.priority on the resolved UUID, prints old → new"
else
  fail "issue set: mutation" "exit $code, out: $out, writes: $(gql_writes)"
fi
: > "$GQL_LOG"
out=$(unit_issue set RS-30 --priority 3); code=$?
[ $code -eq 0 ] && [ -z "$(gql_writes)" ] && printf '%s\n' "$out" | grep -q 'already 3 (skip)' \
  && ok "issue set: unchanged priority → skip, no write" || fail "issue set: no-op" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue set RS-30 --priority 7); code=$?
[ $code -ne 0 ] && [ -z "$(gql_writes)" ] && ok "issue set: priority outside 0–4 refused" || fail "issue set: range" "exit $code, out: $out"

# Direction (the load-bearing assertion): the query binds issueId to $blocker and
# relatedIssueId to $blocked, and the variables carry blocker=u29, blocked=u30 —
# so with type blocks, RS-29 (issue) blocks RS-30 (relatedIssue). A `related`
# relation from RS-29 does not count as existing.
: > "$GQL_LOG"
out=$(unit_issue relate RS-30 --blocked-by RS-29); code=$?
if [ $code -eq 0 ] && [ "$(write_names)" = "issueRelationCreate" ] && [ "$(write_vars 1)" = '{"blocker":"u29","blocked":"u30"}' ] \
   && grep -q 'issueRelationCreate(input: {issueId: \$blocker, relatedIssueId: \$blocked, type: blocks})' "$GQL_LOG"; then
  ok "issue relate: issueId = blocker (RS-29), relatedIssueId = blocked (RS-30), type blocks"
else
  fail "issue relate: direction" "exit $code, out: $out, writes: $(gql_writes)"
fi
: > "$GQL_LOG"
out=$(unit_issue relate RS-30 --blocked-by RS-28 --why "dup"); code=$?
[ $code -eq 0 ] && [ -z "$(gql_writes)" ] && [ "$out" = "  Linear: RS-30 already blocked by RS-28 (skip)" ] \
  && ok "issue relate: existing blocks relation → skip (no relation, no --why comment)" \
  || fail "issue relate: idempotent" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue relate RS-30 --blocked-by RS-29 --why "needs the schema first"); code=$?
[ $code -eq 0 ] && [ "$(write_names)" = "issueRelationCreate,commentCreate" ] \
  && printf '%s' "$(write_vars 2)" | grep -qE '^\{"issue":"u30","body":"\[tpm [0-9]{4}-[0-9]{2}-[0-9]{2}\] blocked by RS-29 — needs the schema first"\}$' \
  && ok "issue relate: --why posts the [tpm] comment on the blocked issue after the relation" \
  || fail "issue relate: --why" "exit $code, out: $out, writes: $(gql_writes)"
out=$(unit_issue relate RS-30 --blocked-by RS-30); code=$?
[ $code -ne 0 ] && ok "issue relate: an issue cannot block itself" || fail "issue relate: self" "exit $code, out: $out"

: > "$GQL_LOG"
out=$(unit_issue comment RS-30 "hello there"); code=$?
[ $code -eq 0 ] && [ "$(write_names)" = "commentCreate" ] && [ "$(write_vars 1)" = '{"issue":"u30","body":"hello there"}' ] \
  && ok "issue comment: commentCreate on the resolved UUID" || fail "issue comment: body arg" "exit $code, out: $out, writes: $(gql_writes)"
printf 'from a file\nline two\n' > "$FIXTURE/body.md"
: > "$GQL_LOG"
out=$(unit_issue comment RS-30 --body-file "$FIXTURE/body.md"); code=$?
[ $code -eq 0 ] && [ "$(write_vars 1 | jq -r .body)" = "$(printf 'from a file\nline two')" ] \
  && ok "issue comment: --body-file" || fail "issue comment: --body-file" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(printf 'from stdin' | unit_issue comment RS-30 -); code=$?
[ $code -eq 0 ] && [ "$(write_vars 1 | jq -r .body)" = "from stdin" ] \
  && ok "issue comment: - reads stdin" || fail "issue comment: stdin" "exit $code, out: $out, writes: $(gql_writes)"
out=$(unit_issue comment RS-30); code=$?
[ $code -ne 0 ] && ok "issue comment: empty body refused" || fail "issue comment: empty" "exit $code, out: $out"
out=$(unit_issue bogus RS-30); code=$?
[ $code -ne 0 ] && printf '%s\n' "$out" | grep -q 'show, set, relate, comment' \
  && ok "issue: unknown subverb lists the verbs" || fail "issue: unknown subverb" "exit $code, out: $out"
run_pk issue
[ $RUN_CODE -eq 0 ] && printf '%s\n' "$RUN_OUT" | grep -q 'pk issue relate' && printf '%s\n' "$RUN_OUT" | grep -q 'pk issue show' \
  && ok "issue: usage lists show and the new verbs" || fail "issue: usage" "exit $RUN_CODE: $RUN_OUT"

# ── Unit tests: pk issue search / create / update (v5.0.0, same stub) ────────
# The team fixture is what `teams(filter: …) { projects }` answers: the team UUID
# plus five projects (one completed, one unprefixed, one bare P2. that borrows i5).

echo "== pk issue search / create / update (sourced, stubbed network) =="

cat > "$STUB_TEAM" <<'EOF'
{"data":{"teams":{"nodes":[{"id":"team-uuid","projects":{"nodes":[
  {"id":"pa","name":"I5.P1. Medium lane","state":"started","priority":3,"progress":0.4,"description":"Lane for medium work","initiatives":{"nodes":[{"name":"i5. Build"}]}},
  {"id":"pb","name":"P2. Urgent lane","state":"planned","priority":1,"progress":0,"initiatives":{"nodes":[{"name":"i5. Build"}]}},
  {"id":"pc","name":"I5.P3. High lane","state":"completed","priority":2,"progress":1,"initiatives":{"nodes":[{"name":"i5. Build"}]}},
  {"id":"pd","name":"Ops theme","state":"backlog","priority":0,"progress":0.125,"initiatives":{"nodes":[]}},
  {"id":"pe","name":"I6.P1. Later","state":"planned","priority":0,"progress":0,"initiatives":{"nodes":[{"name":"i6. Next"}]}}]}}]}}}
EOF
cat > "$STUB_SEARCH" <<'EOF'
{"data":{"issues":{"nodes":[
  {"id":"u30","identifier":"RS-30","title":"Blocked one","priority":3,"state":{"name":"Approved"},"project":{"id":"px","name":"I5.P2. Lanes"}},
  {"id":"u29","identifier":"RS-29","title":"Blocker","priority":0,"state":{"name":"Needs Spec"},"project":null}]}}}
EOF

# search: title-only containsIgnoreCase, team-scoped by name (no Team ID in the
# fixture), first:$n with the default 20, lean selection, one line per issue.
: > "$GQL_LOG"
out=$(unit_issue search block); code=$?
exp='RS-30  Approved  I5.P2. Lanes  Blocked one
RS-29  Needs Spec  —  Blocker'
if [ $code -eq 0 ] && [ "$out" = "$exp" ] && [ -z "$(gql_writes)" ] && [ "$(read_vars 1)" = '{"n":20,"q":"block","team":"Eng"}' ] \
   && printf '%s' "$(read_query 1)" | grep -q 'title: {containsIgnoreCase: \$q}' \
   && printf '%s' "$(read_query 1)" | grep -q 'team: {name: {eq: \$team}}' \
   && printf '%s' "$(read_query 1)" | grep -q 'first: \$n'; then
  ok "issue search: issues(filter: {team, title containsIgnoreCase}, first: n=20) → identifier  state  project|—  title"
else
  fail "issue search: default" "exit $code, out: $out, reads: $(gql_reads)"
fi
printf '%s' "$(read_query 1)" | grep -q 'description' \
  && fail "issue search: lean selection" "list selection carries description: $(read_query 1)" \
  || ok "issue search: list selection never carries description"
: > "$GQL_LOG"
out=$(unit_issue search block --state approved --label bug --limit 99); code=$?
if [ $code -eq 0 ] && [ "$(read_vars 1)" = '{"n":50,"q":"block","state":"approved","label":"bug","team":"Eng"}' ] \
   && printf '%s' "$(read_query 1)" | grep -q 'state: {name: {eqIgnoreCase: \$state}}' \
   && printf '%s' "$(read_query 1)" | grep -q 'labels: {name: {eqIgnoreCase: \$label}}'; then
  ok "issue search: --state/--label filter by name; --limit is capped at 50"
else
  fail "issue search: filters" "exit $code, out: $out, reads: $(gql_reads)"
fi
: > "$GQL_LOG"
out=$(unit_issue search lanes --project i5.p1.); code=$?
if [ $code -eq 0 ] && printf '%s' "$(read_query 1)" | grep -q 'teams(filter' && [ "$(read_vars 2 | jq -r .project)" = "pa" ] \
   && printf '%s' "$(read_query 2)" | grep -q 'project: {id: {eq: \$project}}'; then
  ok "issue search: --project resolves the I5.P1 tag to its id with one projects read, then filters by id"
else
  fail "issue search: --project" "exit $code, out: $out, reads: $(gql_reads)"
fi
: > "$GQL_LOG"
out=$(unit_issue search x --project nope); code=$?
[ $code -ne 0 ] && [ "$out" = "ERROR: unknown project: nope (team has: I5.P1. Medium lane, P2. Urgent lane, Ops theme, I6.P1. Later)" ] && [ "$(gql_reads | wc -l | tr -d ' ')" = "1" ] \
  && ok "issue search: unknown --project → error listing live projects, no issues read" \
  || fail "issue search: unknown project" "exit $code, out: $out, reads: $(gql_reads)"
: > "$GQL_LOG"
out=$(unit_issue search block --json); code=$?
[ $code -eq 0 ] && [ "$(printf '%s' "$out" | jq -r 'map(.identifier) | join(",")')" = "RS-30,RS-29" ] && [ "$(printf '%s' "$out" | jq -r '.[0].id + "/" + .[0].project.id')" = "u30/px" ] \
  && printf '%s' "$(read_query 1)" | grep -q 'nodes { id identifier title priority state { name } project { id name } }' \
  && ok "issue search: --json prints the array, with the Linear id beside identifier (and the project's id)" || fail "issue search: --json" "exit $code, out: $out, reads: $(gql_reads)"
# A filter with no query text is a list ("all issues in state X"), not a title match.
: > "$GQL_LOG"
out=$(unit_issue search --state Approved); code=$?
if [ $code -eq 0 ] && [ "$(read_vars 1)" = '{"n":20,"state":"Approved","team":"Eng"}' ] && ! printf '%s' "$(read_query 1)" | grep -q 'title:'; then
  ok "issue search: no query text + a filter → the title clause is omitted (plain list by state/label/project)"
else
  fail "issue search: filter-only" "exit $code, out: $out, reads: $(gql_reads)"
fi
printf '%s' '{"data":{"issues":{"nodes":[]}}}' > "$STUB_SEARCH"
out=$(unit_issue search nothing); code=$?
[ $code -eq 0 ] && [ "$out" = "no issues match" ] && ok "issue search: empty result → 'no issues match', exit 0" || fail "issue search: empty" "exit $code, out: $out"
out=$(unit_issue search); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q '^Usage: pk issue search' && ok "issue search: no query and no filter → usage" || fail "issue search: usage" "exit $code, out: $out"
out=$(unit_issue search x --limit 0); code=$?
[ $code -ne 0 ] && ok "issue search: --limit 0 refused" || fail "issue search: limit 0" "exit $code, out: $out"

# create: one issueCreate(input: $input); teamId resolved from the team read when
# Team ID is unset; names → ids with one read per kind.
: > "$GQL_LOG"
out=$(unit_issue create --title "New thing"); code=$?
if [ $code -eq 0 ] && [ "$out" = "created RS-31  https://linear.app/t/issue/RS-31" ] && [ "$(write_names)" = "issueCreate" ] \
   && [ "$(write_vars 1)" = '{"input":{"teamId":"team-uuid","title":"New thing"}}' ] \
   && grep -q 'issueCreate(input: \$input) { success issue { id identifier url } }' "$GQL_LOG"; then
  ok "issue create: issueCreate(input: {teamId, title}) → 'created RS-31  <url>'"
else
  fail "issue create: minimal" "exit $code, out: $out, writes: $(gql_writes)"
fi
printf 'from a file\nline two\n' > "$FIXTURE/body.md"
: > "$GQL_LOG"
out=$(unit_issue create --title T --state approved --label bug --label tier:quick --project I5.P1 --priority 2 --parent RS-29 --description-file "$FIXTURE/body.md"); code=$?
exp='{"input":{"teamId":"team-uuid","title":"T","description":"from a file\nline two","stateId":"s-appr","labelIds":["l-bug","l-tq"],"projectId":"pa","priority":2,"parentId":"u29"}}'
if [ $code -eq 0 ] && [ "$(write_vars 1 | jq -cS .)" = "$(printf '%s' "$exp" | jq -cS .)" ]; then
  ok "issue create: every flag lands in IssueCreateInput (state/labels/project resolved, parent → UUID, description from file)"
else
  fail "issue create: full input" "exit $code, out: $out, writes: $(gql_writes)"
fi
reads_kinds=$(gql_reads | cut -f1 | sed -e 's/.*teams(filter.*/teams/' -e 's/.*workflowStates.*/states/' -e 's/.*issueLabels.*/labels/' -e 's/.*issue(id:.*/issue/' | sort | uniq -c | awk '{print $2 "=" $1}' | paste -sd, -)
[ "$reads_kinds" = "issue=1,labels=1,states=1,teams=1" ] \
  && ok "issue create: one read per kind (team+projects, states, labels, parent) — serial, never fanned out" \
  || fail "issue create: read count" "got $reads_kinds; reads: $(gql_reads | cut -f1)"
: > "$GQL_LOG"
out=$(printf 'piped body' | unit_issue create --title T -); code=$?
[ $code -eq 0 ] && [ "$(write_vars 1 | jq -r .input.description)" = "piped body" ] \
  && ok "issue create: - reads the description from stdin" || fail "issue create: stdin" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue create --state Approved); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q '^Usage: pk issue create --title' && [ -z "$(gql_writes)" ] \
  && ok "issue create: missing --title → usage, no write" || fail "issue create: no title" "exit $code, out: $out"
: > "$GQL_LOG"
out=$(unit_issue create --title T --state Nope); code=$?
[ $code -ne 0 ] && [ "$out" = "ERROR: unknown state: Nope (team has: Needs Spec, Approved, In Progress)" ] && [ -z "$(gql_writes)" ] \
  && ok "issue create: unknown state → error listing the team's states, no write" || fail "issue create: unknown state" "exit $code, out: $out"
: > "$GQL_LOG"
out=$(unit_issue create --title T --label tier); code=$?
[ $code -ne 0 ] && [ "$out" = "ERROR: unknown label: tier (team has: bug, tier:quick)" ] && [ -z "$(gql_writes)" ] \
  && ok "issue create: a group label is not applicable → unknown label, no write" || fail "issue create: group label" "exit $code, out: $out"
: > "$GQL_LOG"
out=$(unit_issue create --title T --parent RS-99); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q 'issue RS-99 not found' && [ -z "$(gql_writes)" ] \
  && ok "issue create: unknown --parent → not found, no write" || fail "issue create: parent" "exit $code, out: $out"
out=$(unit_issue create --title T --priority 9); code=$?
[ $code -ne 0 ] && ok "issue create: priority outside 0–4 refused" || fail "issue create: priority" "exit $code, out: $out"
out=$(unit_issue create --title T --json); code=$?
[ $code -eq 0 ] && [ "$(printf '%s' "$out" | jq -c .)" = '{"identifier":"RS-31","id":"u31","url":"https://linear.app/t/issue/RS-31"}' ] \
  && ok "issue create: --json prints {identifier,id,url}" || fail "issue create: --json" "exit $code, out: $out"

# update: one read of the issue, ONE issueUpdate carrying only what differs.
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --state "in progress" --priority 1); code=$?
exp='  Linear: RS-30 state Approved → In Progress
  Linear: RS-30 priority 3 → 1'
if [ $code -eq 0 ] && [ "$out" = "$exp" ] && [ "$(write_names)" = "issueUpdate" ] \
   && [ "$(write_vars 1)" = '{"id":"u30","input":{"stateId":"s-ip","priority":1}}' ] \
   && grep -q 'issueUpdate(id: \$id, input: \$input) { success }' "$GQL_LOG"; then
  ok "issue update: issueUpdate(id, input: {stateId, priority}) with one 'old → new' line per changed field"
else
  fail "issue update: state+priority" "exit $code, out: $out, writes: $(gql_writes)"
fi
printf '%s' "$(read_query 1)" | grep -q 'description' \
  && fail "issue update: lean read" "issue read carries description without --description-file: $(read_query 1)" \
  || ok "issue update: the issue read skips description unless it is about to be compared"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --add-label tier:quick --remove-label bug); code=$?
[ $code -eq 0 ] && [ "$out" = "  Linear: RS-30 labels bug → tier:quick" ] \
  && [ "$(write_vars 1)" = '{"id":"u30","input":{"addedLabelIds":["l-tq"],"removedLabelIds":["l-bug"]}}' ] \
  && ok "issue update: labels via IssueUpdateInput.addedLabelIds / removedLabelIds (never the full labelIds set)" \
  || fail "issue update: labels" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --add-label bug --state Approved --priority 3 --title "Blocked one" --project none); code=$?
[ $code -eq 0 ] && [ "$out" = "  Linear: RS-30 no changes" ] && [ -z "$(gql_writes)" ] \
  && ok "issue update: every requested value already holds → 'no changes', no write" \
  || fail "issue update: no changes" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --project I5.P1); code=$?
[ $code -eq 0 ] && [ "$out" = "  Linear: RS-30 project — → I5.P1. Medium lane" ] && [ "$(write_vars 1)" = '{"id":"u30","input":{"projectId":"pa"}}' ] \
  && ok "issue update: --project <tag> → projectId" || fail "issue update: project" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue update RS-28 --project none); code=$?
[ $code -eq 0 ] && [ "$out" = "  Linear: RS-28 project I5.P1. Medium lane → —" ] && [ "$(write_vars 1)" = '{"id":"u28","input":{"projectId":null}}' ] \
  && ok "issue update: --project none → projectId: null" || fail "issue update: project none" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --title "Renamed" --description-file "$FIXTURE/body.md"); code=$?
exp='  Linear: RS-30 title Blocked one → Renamed
  Linear: RS-30 description updated'
[ $code -eq 0 ] && [ "$out" = "$exp" ] && [ "$(write_vars 1 | jq -cS .input)" = '{"description":"from a file\nline two","title":"Renamed"}' ] \
  && printf '%s' "$(read_query 1)" | grep -q 'description' \
  && ok "issue update: --title and --description-file (description read only then)" \
  || fail "issue update: title+description" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --priority 1 --json); code=$?
[ $code -eq 0 ] && [ "$(printf '%s' "$out" | jq -c .)" = '{"identifier":"RS-30","id":"u30","input":{"priority":1}}' ] \
  && ok "issue update: --json prints {identifier,id,input}" || fail "issue update: --json" "exit $code, out: $out"
: > "$GQL_LOG"
out=$(unit_issue update RS-30); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q '^Usage: pk issue update <ID>' && [ -z "$(gql_reads)" ] \
  && ok "issue update: no flags → usage, nothing read" || fail "issue update: usage" "exit $code, out: $out"
out=$(unit_issue update RS-99 --priority 1); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q 'issue RS-99 not found' && ok "issue update: unknown issue → not found" || fail "issue update: not found" "exit $code, out: $out"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --state Nope); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q '^ERROR: unknown state: Nope (team has: ' && [ -z "$(gql_writes)" ] \
  && ok "issue update: unknown state → error, no write" || fail "issue update: unknown state" "exit $code, out: $out"
out=$(unit_issue bogus RS-30); code=$?
printf '%s\n' "$out" | grep -q 'search, create, update' && ok "issue: unknown subverb also lists search, create, update" || fail "issue: unknown subverb v4.39" "$out"
run_pk issue
printf '%s\n' "$RUN_OUT" | grep -q 'pk issue search <query>' && printf '%s\n' "$RUN_OUT" | grep -q 'pk issue create --title' && printf '%s\n' "$RUN_OUT" | grep -q 'pk issue update <ID>' \
  && ok "issue: usage lists search, create, update" || fail "issue: usage v4.39" "$RUN_OUT"

# update --sort-order: rides the same issueUpdate as projectId (a move re-ranks
# sortOrder, so two calls would undo each other); numeric no-op check.
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --project I5.P1 --sort-order 50); code=$?
exp='  Linear: RS-30 project — → I5.P1. Medium lane
  Linear: RS-30 sortOrder 100 → 50'
[ $code -eq 0 ] && [ "$out" = "$exp" ] && [ "$(write_vars 1)" = '{"id":"u30","input":{"projectId":"pa","sortOrder":50}}' ] && [ "$(write_names)" = "issueUpdate" ] \
  && ok "issue update: --sort-order lands in the SAME issueUpdate as projectId (IssueUpdateInput.sortOrder: Float)" \
  || fail "issue update: sort-order" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --sort-order -12.5); code=$?
[ $code -eq 0 ] && [ "$(write_vars 1 | jq -c .input)" = '{"sortOrder":-12.5}' ] && ok "issue update: --sort-order takes a negative float" || fail "issue update: sort-order float" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --sort-order 100.0); code=$?
[ $code -eq 0 ] && [ "$out" = "  Linear: RS-30 no changes" ] && [ -z "$(gql_writes)" ] \
  && ok "issue update: --sort-order equal to the current value (numerically) → no changes" || fail "issue update: sort-order no-op" "exit $code, out: $out, writes: $(gql_writes)"
: > "$GQL_LOG"
out=$(unit_issue update RS-30 --sort-order abc); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q 'sort-order must be a number' && [ -z "$(gql_reads)" ] \
  && ok "issue update: non-numeric --sort-order refused before any read" || fail "issue update: sort-order bad" "exit $code, out: $out"

# show --fields relations: both relation sides, one flat list; --comments alone
# is the full read (description rides along), an explicit --fields still wins.
: > "$GQL_LOG"
out=$(unit_issue show RS-30 --fields relations); code=$?
[ $code -eq 0 ] && [ "$out" = "relations: blocked by RS-28 · blocks RS-31 · duplicate of RS-12 · related to RS-29" ] \
  && printf '%s' "$(read_query 1)" | grep -q 'relations(first: 50) { nodes { type relatedIssue { id identifier } } } inverseRelations(first: 50) { nodes { type issue { id identifier } } }' \
  && ok "issue show: --fields relations → 'blocked by · blocks · duplicate of · related to' from relations + inverseRelations" \
  || fail "issue show: relations text" "exit $code, out: $out, reads: $(gql_reads)"
out=$(unit_issue show RS-30 --fields relations --json); code=$?
[ $code -eq 0 ] && [ "$(printf '%s' "$out" | jq -c '.relations | map(.relation + " " + .identifier + "=" + .id)')" = '["blocked by RS-28=u28","blocks RS-31=u31","duplicate of RS-12=u12","related to RS-29=u29"]' ] \
  && [ "$(printf '%s' "$out" | jq 'has("inverseRelations")')" = "false" ] \
  && ok "issue show: --fields relations --json → .relations is one flat array of {relation, identifier, id}" \
  || fail "issue show: relations json" "exit $code, out: $out"
out=$(unit_issue show RS-29 --fields relations); code=$?
[ $code -eq 0 ] && [ "$out" = "relations: —" ] && ok "issue show: no relations → '—'" || fail "issue show: relations empty" "exit $code, out: $out"
: > "$GQL_LOG"
out=$(unit_issue show RS-30 --comments); code=$?
[ $code -eq 0 ] && printf '%s' "$(read_query 1)" | grep -q ' description' && printf '%s' "$(read_query 1)" | grep -q 'comments(orderBy: createdAt)' \
  && printf '%s' "$out" | grep -q -- '--- description ---' \
  && ok "issue show: --comments alone implies description (the one full-content read)" || fail "issue show: --comments implies description" "exit $code, out: $out, reads: $(gql_reads)"
: > "$GQL_LOG"
out=$(unit_issue show RS-30 --fields id --comments); code=$?
[ $code -eq 0 ] && printf '%s' "$(read_query 1)" | grep -q 'comments(orderBy: createdAt)' && ! printf '%s' "$(read_query 1)" | grep -q ' description' \
  && ok "issue show: an explicit --fields still wins (--comments adds comments only)" || fail "issue show: --fields wins" "exit $code, out: $out, reads: $(gql_reads)"
: > "$GQL_LOG"
out=$(unit_issue show RS-30); code=$?
[ $code -eq 0 ] && ! printf '%s' "$(read_query 1)" | grep -q ' description' && ! printf '%s' "$(read_query 1)" | grep -q 'comments(' \
  && ok "issue show: the default read still fetches neither description nor comments" || fail "issue show: default lean" "exit $code, reads: $(gql_reads)"

# ── Unit tests: pk project list (v5.0.0, same stub) ─────────────────────────

echo "== pk project list (sourced, stubbed network) =="

: > "$GQL_LOG"
out=$(unit_project list); code=$?
exp='I5.P1. Medium lane  started  tier C  40%
P2. Urgent lane  planned  tier A  0%
I6.P1. Later  planned  tier —  0%
Ops theme  backlog  tier —  13%'
if [ $code -eq 0 ] && [ "$out" = "$exp" ] && [ -z "$(gql_writes)" ] \
   && printf '%s' "$(read_query 1)" | grep -q 'teams(filter: {name: {eq: \$team}}, first: 1)' \
   && printf '%s' "$(read_query 1)" | grep -q 'projects(first: 250) { nodes { id name state priority progress'; then
  ok "project list: I<N>.P<N>. walk order (bare P2. borrows i5), unprefixed last; name  state  tier  progress%; completed hidden"
else
  fail "project list: default" "exit $code, out:
$out
reads: $(gql_reads)"
fi
out=$(unit_project list --all); code=$?
[ $code -eq 0 ] && [ "$(printf '%s\n' "$out" | sed -n 3p)" = "I5.P3. High lane  completed  tier B  100%" ] && [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = "5" ] \
  && ok "project list: --all shows completed/canceled in place" || fail "project list: --all" "exit $code, out:
$out"
printf '%s' "$(read_query 1)" | grep -q 'description' \
  && fail "project list: lean text read" "text listing fetched description: $(read_query 1)" \
  || ok "project list: the text listing (and the resolvers behind search/create/update) never fetch description"
: > "$GQL_LOG"
out=$(unit_project list --json); code=$?
[ $code -eq 0 ] && [ "$(printf '%s' "$out" | jq -c 'map(.id)')" = '["pa","pb","pe","pd"]' ] && [ "$(printf '%s' "$out" | jq -c '.[0] | keys')" = '["description","id","name","priority","progress","state"]' ] \
  && [ "$(printf '%s' "$out" | jq -r '.[0].description')" = "Lane for medium work" ] && printf '%s' "$(read_query 1)" | grep -q 'priority progress description initiatives' \
  && ok "project list: --json prints the sorted array with id,name,state,priority,progress,description (description fetched only here)" || fail "project list: --json" "exit $code, out: $out, reads: $(gql_reads)"
printf '%s' '{"data":{"teams":{"nodes":[{"id":"team-uuid","projects":{"nodes":[]}}]}}}' > "$STUB_TEAM.empty"
out=$( STUB_TEAM="$STUB_TEAM.empty" unit_project list ); code=$?
[ $code -eq 0 ] && [ "$out" = "no projects" ] && ok "project list: empty team → 'no projects', exit 0" || fail "project list: empty" "exit $code, out: $out"
out=$(unit_project); code=$?
[ $code -eq 0 ] && printf '%s' "$out" | grep -q '^Usage: pk project list \[--all\] \[--json\]' && ok "project: bare 'pk project' prints usage" || fail "project: usage" "exit $code, out: $out"
out=$(unit_project bogus); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q '(list)' && ok "project: unknown subverb lists the verbs" || fail "project: unknown subverb" "exit $code, out: $out"

# ── Unit tests: pk gql (v5.0.0, same stub) ──────────────────────────────────

echo "== pk gql (sourced, stubbed network) =="

: > "$GQL_LOG"
out=$(unit_gql 'query { gqlOkFixture }' 2>&1); code=$?
[ $code -eq 0 ] && [ "$(printf '%s' "$out" | jq -r .data.viewer.id)" = "me" ] && [ "$(read_query 1)" = 'query { gqlOkFixture }' ] && [ "$(read_vars 1)" = '{}' ] \
  && ok "gql: passes the query through pk_linear_gql, pretty-prints the response" || fail "gql: ok" "exit $code, out: $out, reads: $(gql_reads)"
: > "$GQL_LOG"
out=$(unit_gql 'query($a: Int) { gqlOkFixture }' '{"a":1}' 2>&1); code=$?
[ $code -eq 0 ] && [ "$(read_vars 1)" = '{"a":1}' ] && ok "gql: positional variables JSON" || fail "gql: positional vars" "exit $code, reads: $(gql_reads)"
: > "$GQL_LOG"
out=$(unit_gql 'query($a: Int) { gqlOkFixture }' --vars '{"a":2}' 2>&1); code=$?
[ $code -eq 0 ] && [ "$(read_vars 1)" = '{"a":2}' ] && ok "gql: --vars <json>" || fail "gql: --vars" "exit $code, reads: $(gql_reads)"
: > "$GQL_LOG"
# A multi-line query spans log lines; the variables sit on the line that has the tab.
out=$(printf 'query {\n  gqlOkFixture\n}\n' | unit_gql - '{"a":3}' 2>&1); code=$?
[ $code -eq 0 ] && [ "$(awk -F'\t' 'NF > 1 { print $2 }' "$GQL_LOG")" = '{"a":3}' ] && grep -q '^query {$' "$GQL_LOG" && grep -q 'gqlOkFixture' "$GQL_LOG" \
  && ok "gql: - reads the (multi-line) query from stdin; variables still positional" || fail "gql: stdin" "exit $code, out: $out, reads: $(gql_reads)"
: > "$GQL_LOG"
stdout=$(unit_gql 'query { gqlErrorFixture }' 2>/dev/null); code=$?
stderr=$(unit_gql 'query { gqlErrorFixture }' 2>&1 >/dev/null)
[ $code -ne 0 ] && [ "$stderr" = "Field nope not found" ] && [ "$(printf '%s' "$stdout" | jq -r '.errors[0].message')" = "Field nope not found" ] \
  && ok "gql: an errors envelope → exit 1, .errors[].message on stderr, raw JSON still on stdout" \
  || fail "gql: errors" "exit $code, stdout: $stdout, stderr: $stderr"
: > "$GQL_LOG"
out=$(unit_gql '' 2>&1); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q "^Usage: pk gql" && [ ! -s "$GQL_LOG" ] \
  && ok "gql: empty query → usage, nothing sent" || fail "gql: empty" "exit $code, out: $out"
out=$(unit_gql 2>&1); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q "^Usage: pk gql" && ok "gql: no args → usage" || fail "gql: no args" "exit $code, out: $out"
out=$(unit_gql 'query { gqlOkFixture }' 'not json' 2>&1); code=$?
[ $code -ne 0 ] && printf '%s' "$out" | grep -q 'variables must be a JSON object' && ok "gql: non-JSON variables refused" || fail "gql: bad vars" "exit $code, out: $out"
: > "$GQL_LOG"
out=$(unit_gql 'mutation { issueUpdate(id: "x", input: {priority: 1}) { success } }' 2>&1); code=$?
[ $code -eq 0 ] && [ "$(write_names)" = "issueUpdate" ] \
  && ok "gql: a mutation reaches pk_linear_gql unchanged (so it pays the workspace guard)" || fail "gql: mutation passthrough" "exit $code, out: $out, writes: $(gql_writes)"
run_pk help
printf '%s\n' "$RUN_OUT" | grep -q '^  pk project list \[--all\] \[--json\]' && printf '%s\n' "$RUN_OUT" | grep -q "^  pk gql '<query>'" \
  && printf '%s\n' "$RUN_OUT" | grep -q '^  pk issue search <query>' && printf '%s\n' "$RUN_OUT" | grep -q '^  pk issue create --title' && printf '%s\n' "$RUN_OUT" | grep -q '^  pk issue update <ID>' \
  && ok "help: lists issue search/create/update, project list, gql" || fail "help: v4.39 verbs" "$RUN_OUT"

# ── CLI tests: the missing-key error names the op run route (v5.0.0) ─────────
# A direnv-less shell should self-serve from the message instead of falling
# back to an MCP: every "Linear API key not set" site carries the op run hint,
# and the hint names the reference file this repo actually carries (v5.1.2 —
# secrets.op in Piper, op-references.conf in SiteLine).

echo "== missing key names the op run route =="

no_key_pk() {
  RUN_OUT=$(cd "$FIXTURE" && env -u LINEAR_API_KEY PATH="$FIXTURE/shim:$PATH" "$PK" "$@" 2>&1); RUN_CODE=$?
}
rm -f "$FIXTURE/secrets.op" "$FIXTURE/op-references.conf"
no_key_pk gql 'query { viewer { id } }'
[ $RUN_CODE -ne 0 ] && printf '%s' "$RUN_OUT" | grep -q 'Linear API key not set' && printf '%s' "$RUN_OUT" | grep -qF 'op run --env-file=<op:// reference file> -- pk' \
  && ok "no key, no reference file: pk_linear_gql's error names the generic op run recipe" || fail "no key: gql generic" "exit $RUN_CODE: $RUN_OUT"
: > "$FIXTURE/op-references.conf"
no_key_pk gql 'query { viewer { id } }'
[ $RUN_CODE -ne 0 ] && printf '%s' "$RUN_OUT" | grep -qF 'op run --env-file=op-references.conf -- pk' \
  && ok "no key: op-references.conf in the repo → the hint names it" || fail "no key: op-references.conf" "exit $RUN_CODE: $RUN_OUT"
rm -f "$FIXTURE/op-references.conf"; : > "$FIXTURE/secrets.op"
no_key_pk gql 'query { viewer { id } }'
[ $RUN_CODE -ne 0 ] && printf '%s' "$RUN_OUT" | grep -qF 'op run --env-file=secrets.op -- pk' \
  && ok "no key: secrets.op in the repo → the hint names it" || fail "no key: secrets.op" "exit $RUN_CODE: $RUN_OUT"
no_key_pk next
printf '%s' "$RUN_OUT" | grep -q 'Linear API key not set' && printf '%s' "$RUN_OUT" | grep -qF 'op run --env-file=secrets.op -- pk' \
  && ok "no key: pk_require_linear_key's error names op run" || fail "no key: next" "exit $RUN_CODE: $RUN_OUT"
no_key_pk doctor
printf '%s' "$RUN_OUT" | grep -q '✗ Linear API key not set' && printf '%s' "$RUN_OUT" | grep -qF 'op run --env-file=secrets.op -- pk' \
  && ok "no key: pk doctor's line names op run" || fail "no key: doctor" "exit $RUN_CODE: $RUN_OUT"
rm -f "$FIXTURE/secrets.op"
grep -c 'Linear API key not set' "$PK" | grep -qx "$(grep -c 'Linear API key not set.*pk_op_run_hint' "$PK")" \
  && ok "no key: every 'Linear API key not set' site in bin/pk carries the op run hint" \
  || fail "no key: sites" "$(grep -n 'Linear API key not set' "$PK" | grep -v 'pk_op_run_hint')"
cleanup

# ── Unit tests: runbook nudge (sourced) ──────────────────────────────────────
# pk_runbook_nudge prints exactly one line when the `<!-- tpm:begin · agreed
# YYYY-MM-DD` marker is older than `Runbook stale days` (default 7 → 8+ days
# prints), and nothing on a fresh marker, missing file, missing marker or bad
# date. It never fails the caller. Dates are pinned relative to today (UTC).

echo "== runbook nudge (sourced) =="

unit_nudge()    { ( cd "$FIXTURE" && source "$PK" && pk_runbook_nudge ); }
# BSD first here (test side only): GNU rejects -v with nothing on stdout.
days_ago()      { date -u -v-"$1"d +%F 2>/dev/null || date -u -d "$1 days ago" +%F; }
write_runbook() { mkdir -p "$(dirname "$1")"; printf '# Runbook\n\n<!-- tpm:begin · agreed %s · cadence weekly -->\nbody\n<!-- tpm:end -->\n' "$2" > "$1"; }

make_fixture
write_config '```
Team name: Eng
```'
write_runbook "$FIXTURE/engineering/RUNBOOK.md" "$(days_ago 8)"
v=$(unit_nudge); code=$?
[ $code -eq 0 ] && [ "$v" = "runbook agreed 8d ago → /tpm" ] && ok "nudge: 8-day-old agreement → one line" || fail "nudge: stale" "exit $code, got '$v'"
write_runbook "$FIXTURE/engineering/RUNBOOK.md" "$(days_ago 7)"
v=$(unit_nudge); [ -z "$v" ] && ok "nudge: exactly 7 days is not older than 7 → nothing" || fail "nudge: boundary" "got '$v'"
write_runbook "$FIXTURE/engineering/RUNBOOK.md" "$(days_ago 0)"
v=$(unit_nudge); [ -z "$v" ] && ok "nudge: fresh agreement → nothing" || fail "nudge: fresh" "got '$v'"
printf '# Runbook\n\nno marker here\n' > "$FIXTURE/engineering/RUNBOOK.md"
v=$(unit_nudge); [ -z "$v" ] && ok "nudge: missing marker → nothing" || fail "nudge: no marker" "got '$v'"
printf '# Runbook\n\n<!-- tpm:begin · agreed YYYY-MM-DD · derived from Linear · written by /tpm, regenerate don\x27t edit -->\n_(no agreement yet — run /tpm)_\n<!-- tpm:end -->\n' > "$FIXTURE/engineering/RUNBOOK.md"
v=$(unit_nudge); code=$?
[ $code -eq 0 ] && [ "$v" = "runbook: no agreement yet → /tpm" ] && ok "nudge: synced skeleton (marker, no date) → no-agreement line (v5.0.1)" || fail "nudge: skeleton" "exit $code, got '$v'"
write_runbook "$FIXTURE/engineering/RUNBOOK.md" "2026-13-45"
v=$(unit_nudge); code=$?
[ $code -eq 0 ] && [ -z "$v" ] && ok "nudge: unparsable date → nothing, exit 0" || fail "nudge: bad date" "exit $code, got '$v'"
rm -f "$FIXTURE/engineering/RUNBOOK.md"
v=$(unit_nudge); code=$?
[ $code -eq 0 ] && [ -z "$v" ] && ok "nudge: missing file → nothing, exit 0 (never fails the caller)" || fail "nudge: missing file" "exit $code, got '$v'"

# Custom path and threshold.
write_config '```
Runbook path: docs/RB.md
Runbook stale days: 3
```'
write_runbook "$FIXTURE/docs/RB.md" "$(days_ago 5)"
v=$(unit_nudge); [ "$v" = "runbook agreed 5d ago → /tpm" ] && ok "nudge: Runbook path + Runbook stale days honoured" || fail "nudge: custom config" "got '$v'"

# pk next leads with the nudge (after the sessions line) even before the board read.
RUN_OUT=$(cd "$FIXTURE" && env -u LINEAR_API_KEY PATH="$FIXTURE/shim:$PATH" PK_CLAUDE_PROJECTS_DIR="$FIXTURE/no-sessions" "$PK" next 2>&1)
[ "$(printf '%s\n' "$RUN_OUT" | sed -n 1p)" = "runbook agreed 5d ago → /tpm" ] \
  && ok "pk next: nudge is the first line" || fail "pk next: nudge placement" "got: $(printf '%s\n' "$RUN_OUT" | head -3)"
cleanup

# Runbook primary: the marker is read from the sibling repo's runbook.
NUDGE_PARENT=$(mktemp -d)
mkdir -p "$NUDGE_PARENT/repo" "$NUDGE_PARENT/SiteLine"
git -C "$NUDGE_PARENT/repo" init -q -b main
printf '```\nRunbook primary: ../SiteLine\n```\n' > "$NUDGE_PARENT/repo/method.config.md"
write_runbook "$NUDGE_PARENT/SiteLine/engineering/RUNBOOK.md" "$(days_ago 10)"
v=$( cd "$NUDGE_PARENT/repo" && source "$PK" && pk_runbook_nudge )
[ "$v" = "runbook agreed 10d ago → /tpm" ] && ok "nudge: Runbook primary reads the sibling repo's runbook" || fail "nudge: primary" "got '$v'"
rm -rf "$NUDGE_PARENT"

# ── Unit tests: plan nudge (v5.1.0, sourced) ─────────────────────────────────
# The weekly plan (`Plan path`, default engineering/WEEKLY_PLAN.md) carries the
# tpm:begin marker since v5.1.0 and wins whenever the file exists; the runbook
# tests above (no plan in the fixture) exercise the fallback. `Plan primary`
# and `Plan stale days` default to their Runbook counterparts.

echo "== plan nudge (v5.1.0, sourced) =="

unit_plan_nudge() { ( cd "$FIXTURE" && source "$PK" && pk_plan_nudge ); }
write_plan()      { mkdir -p "$(dirname "$1")"; printf '# X — Weekly Plan\n<!-- tpm:begin · agreed %s · derived from Linear · written by /tpm, regenerate don\x27t edit -->\nbody\n<!-- tpm:end -->\n' "$2" > "$1"; }

make_fixture
write_config '```
Team name: Eng
```'
write_plan "$FIXTURE/engineering/WEEKLY_PLAN.md" "$(days_ago 8)"
v=$(unit_plan_nudge); code=$?
[ $code -eq 0 ] && [ "$v" = "plan agreed 8d ago → /tpm" ] && ok "plan nudge: 8-day-old agreement → one line" || fail "plan nudge: stale" "exit $code, got '$v'"
write_plan "$FIXTURE/engineering/WEEKLY_PLAN.md" "$(days_ago 7)"
v=$(unit_plan_nudge); [ -z "$v" ] && ok "plan nudge: exactly 7 days → nothing" || fail "plan nudge: boundary" "got '$v'"
write_plan "$FIXTURE/engineering/WEEKLY_PLAN.md" "YYYY-MM-DD"
v=$(unit_plan_nudge); code=$?
[ $code -eq 0 ] && [ "$v" = "plan: no agreement yet → /tpm" ] && ok "plan nudge: synced skeleton (marker, no date) → no-agreement line" || fail "plan nudge: skeleton" "exit $code, got '$v'"
# The plan wins: a fresh plan beside a stale runbook is silence, and a stale
# plan beside a fresh runbook is the plan line — the runbook is not consulted.
write_plan "$FIXTURE/engineering/WEEKLY_PLAN.md" "$(days_ago 0)"
write_runbook "$FIXTURE/engineering/RUNBOOK.md" "$(days_ago 30)"
v=$(unit_plan_nudge); code=$?
[ $code -eq 0 ] && [ -z "$v" ] && ok "plan nudge: fresh plan + stale runbook → nothing (plan wins)" || fail "plan nudge: plan wins" "exit $code, got '$v'"
write_plan "$FIXTURE/engineering/WEEKLY_PLAN.md" "$(days_ago 9)"
write_runbook "$FIXTURE/engineering/RUNBOOK.md" "$(days_ago 0)"
v=$(unit_plan_nudge)
[ "$v" = "plan agreed 9d ago → /tpm" ] && ok "plan nudge: stale plan + fresh runbook → the plan line" || fail "plan nudge: stale plan" "got '$v'"
v=$(unit_nudge)
[ "$v" = "plan agreed 9d ago → /tpm" ] && ok "plan nudge: pk_runbook_nudge (pre-5.1.0 name) reads the plan too" || fail "plan nudge: old name" "got '$v'"
rm -f "$FIXTURE/engineering/WEEKLY_PLAN.md"
v=$(unit_plan_nudge)
[ -z "$v" ] && ok "plan nudge: plan removed → back to the runbook (fresh → nothing)" || fail "plan nudge: fallback after removal" "got '$v'"
# `Plan path: none`: no weekly plan on this project, so no nudge — not even
# the runbook's, which would otherwise send a solo project to /tpm forever.
write_config '```
Plan path: none
```'
write_plan "$FIXTURE/engineering/WEEKLY_PLAN.md" "YYYY-MM-DD"
write_runbook "$FIXTURE/engineering/RUNBOOK.md" "$(days_ago 30)"
v=$(unit_plan_nudge); code=$?
[ $code -eq 0 ] && [ -z "$v" ] && ok "plan nudge: Plan path none → silent (plan and runbook ignored)" || fail "plan nudge: Plan path none" "exit $code, got '$v'"
rm -f "$FIXTURE/engineering/WEEKLY_PLAN.md" "$FIXTURE/engineering/RUNBOOK.md"
rm -f "$FIXTURE/engineering/RUNBOOK.md"
v=$(unit_plan_nudge); code=$?
[ $code -eq 0 ] && [ -z "$v" ] && ok "plan nudge: neither file → nothing, exit 0" || fail "plan nudge: neither file" "exit $code, got '$v'"

# Custom path and threshold, and the threshold's fallback to the Runbook key.
write_config '```
Plan path: docs/WEEK.md
Plan stale days: 3
```'
write_plan "$FIXTURE/docs/WEEK.md" "$(days_ago 5)"
v=$(unit_plan_nudge); [ "$v" = "plan agreed 5d ago → /tpm" ] && ok "plan nudge: Plan path + Plan stale days honoured" || fail "plan nudge: custom config" "got '$v'"
write_config '```
Plan path: docs/WEEK.md
Runbook stale days: 3
```'
v=$(unit_plan_nudge); [ "$v" = "plan agreed 5d ago → /tpm" ] && ok "plan nudge: Plan stale days unset → Runbook stale days" || fail "plan nudge: stale-days fallback" "got '$v'"
write_config '```
Plan path: docs/WEEK.md
Plan stale days: 10
Runbook stale days: 3
```'
v=$(unit_plan_nudge); [ -z "$v" ] && ok "plan nudge: a set Plan stale days beats Runbook stale days" || fail "plan nudge: plan key precedence" "got '$v'"

# pk next leads with the plan nudge.
write_config '```
Plan path: docs/WEEK.md
Plan stale days: 3
```'
RUN_OUT=$(cd "$FIXTURE" && env -u LINEAR_API_KEY PATH="$FIXTURE/shim:$PATH" PK_CLAUDE_PROJECTS_DIR="$FIXTURE/no-sessions" "$PK" next 2>&1)
[ "$(printf '%s\n' "$RUN_OUT" | sed -n 1p)" = "plan agreed 5d ago → /tpm" ] \
  && ok "pk next: plan nudge is the first line" || fail "pk next: plan nudge placement" "got: $(printf '%s\n' "$RUN_OUT" | head -3)"
cleanup

# Plan primary, and Runbook primary alone (a consumer synced before v5.1.0):
# both read the sibling repo's plan.
NUDGE_PARENT=$(mktemp -d)
mkdir -p "$NUDGE_PARENT/repo" "$NUDGE_PARENT/SiteLine"
git -C "$NUDGE_PARENT/repo" init -q -b main
write_plan "$NUDGE_PARENT/SiteLine/engineering/WEEKLY_PLAN.md" "$(days_ago 10)"
write_runbook "$NUDGE_PARENT/SiteLine/engineering/RUNBOOK.md" "$(days_ago 0)"
printf '```\nPlan primary: ../SiteLine\n```\n' > "$NUDGE_PARENT/repo/method.config.md"
v=$( cd "$NUDGE_PARENT/repo" && source "$PK" && pk_plan_nudge )
[ "$v" = "plan agreed 10d ago → /tpm" ] && ok "plan nudge: Plan primary reads the sibling repo's plan" || fail "plan nudge: Plan primary" "got '$v'"
printf '```\nRunbook primary: ../SiteLine\n```\n' > "$NUDGE_PARENT/repo/method.config.md"
v=$( cd "$NUDGE_PARENT/repo" && source "$PK" && pk_plan_nudge )
[ "$v" = "plan agreed 10d ago → /tpm" ] && ok "plan nudge: Runbook primary alone still finds the sibling's plan" || fail "plan nudge: Runbook primary fallback" "got '$v'"
rm -rf "$NUDGE_PARENT"

# ── CLI tests: pk config dump carries the TPM keys with defaults ─────────────

echo "== pk config dump: TPM keys =="

make_fixture
write_config '```
Integration branch: main
```'
run_pk config
cfg_has() { printf '%s\n' "$RUN_OUT" | grep -Eq "^$1: +$2\$"; }
cfg_has "Runbook path" "engineering/RUNBOOK.md" && ok "config dump: Runbook path defaults to engineering/RUNBOOK.md" || fail "config dump: Runbook path" "$RUN_OUT"
cfg_has "Weekly capacity days" "6" && ok "config dump: Weekly capacity days defaults to 6" || fail "config dump: Weekly capacity days" "$RUN_OUT"
cfg_has "Runbook stale days" "7" && ok "config dump: Runbook stale days defaults to 7" || fail "config dump: Runbook stale days" "$RUN_OUT"
printf '%s\n' "$RUN_OUT" | grep -q '^Runbook primary:' && printf '%s\n' "$RUN_OUT" | grep -q '^Portfolio repos:' \
  && ok "config dump: Runbook primary + Portfolio repos listed (empty default)" || fail "config dump: empty-default keys" "$RUN_OUT"
cfg_has "Plan path" "engineering/WEEKLY_PLAN.md" && ok "config dump: Plan path defaults to engineering/WEEKLY_PLAN.md (v5.1.0)" || fail "config dump: Plan path" "$RUN_OUT"
cfg_has "Plan stale days" "7" && ok "config dump: Plan stale days defaults to 7 (v5.1.0)" || fail "config dump: Plan stale days" "$RUN_OUT"
printf '%s\n' "$RUN_OUT" | grep -q '^Plan primary:' && ok "config dump: Plan primary listed (empty default)" || fail "config dump: Plan primary" "$RUN_OUT"
cfg_has "Integration branch" "main" && ok "config dump: existing keys unchanged" || fail "config dump: existing keys" "$RUN_OUT"
cfg_has "Linear transport" "api" && ok "config dump: Linear transport defaults to api" || fail "config dump: Linear transport" "$RUN_OUT"
write_config '```
Runbook stale days: 14
```'
run_pk config
cfg_has "Runbook stale days" "14" && ok "config dump: a set TPM key overrides its default" || fail "config dump: override" "$RUN_OUT"
cleanup

# ── Skills cite only pk verbs that exist (v5.0.0) ──
# Every backticked `pk <verb> [<sub>]` in skills/*/SKILL.md must be a case label
# in bin/pk's top-level dispatcher — and, for `pk issue …` / `pk project …`, in
# that sub-dispatcher — so a skill never names a verb pk does not have. The
# labels are read from the source, not hardcoded, so a new verb needs no edit here.

echo "== skills cite only pk verbs that exist =="

# Case labels of `case "$<var>" in` inside function <fn>, one per line (a|b split).
pk_case_labels() {
  awk -v fn="$1" -v cv="$2" '
    $0 == fn "() {" { inf = 1; next }
    inf && /^}/ { exit }
    inf && index($0, "case \"$" cv "\" in") { inc = 1; next }
    inc && /^ *esac/ { exit }
    inc && match($0, /^ *[^ )]+\)/) {
      l = substr($0, RSTART, RLENGTH); sub(/^ */, "", l); sub(/\)$/, "", l)
      n = split(l, a, "|"); for (i = 1; i <= n; i++) print a[i]
    }' "$PK"
}
TOP_VERBS=$(pk_case_labels main sub)
ISSUE_VERBS=$(pk_case_labels cmd_issue subverb)
PROJECT_VERBS=$(pk_case_labels cmd_project subverb)
printf '%s\n' "$TOP_VERBS" | grep -qx next && printf '%s\n' "$TOP_VERBS" | grep -qx gql \
  && printf '%s\n' "$ISSUE_VERBS" | grep -qx show && printf '%s\n' "$PROJECT_VERBS" | grep -qx list \
  && ok "skills: dispatcher labels read from bin/pk (top has next+gql, issue has show, project has list)" \
  || fail "skills: label extraction" "top: $(printf '%s' "$TOP_VERBS" | paste -sd, -); issue: $(printf '%s' "$ISSUE_VERBS" | paste -sd, -); project: $(printf '%s' "$PROJECT_VERBS" | paste -sd, -)"

# "file: pk verb" for every citation whose verb (or issue/project sub-verb) is
# not a dispatcher label. A second word starting with - or < is not a sub-verb
# and is excluded by the regex itself. (A function, not an inline $( case … ):
# bash 3.2 mis-parses an unparenthesised `issue)` label inside $( ).)
pk_cited_missing() {
  local f skill v1 v2 _
  for f in "$REPO_ROOT"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    skill="skills/$(basename "$(dirname "$f")")/SKILL.md"
    grep -oE '`pk [a-z][a-z-]*( [a-z][a-z-]*)?' "$f" 2>/dev/null | sed 's/^`//' | sort -u | while read -r _ v1 v2; do
      if ! printf '%s\n' "$TOP_VERBS" | grep -qx -- "$v1"; then
        printf '%s: pk %s\n' "$skill" "$v1"
      elif [ -n "$v2" ]; then
        case "$v1" in
          (issue)   printf '%s\n' "$ISSUE_VERBS"   | grep -qx -- "$v2" || printf '%s: pk issue %s\n' "$skill" "$v2" ;;
          (project) printf '%s\n' "$PROJECT_VERBS" | grep -qx -- "$v2" || printf '%s: pk project %s\n' "$skill" "$v2" ;;
        esac
      fi
    done
  done | sort -u
}
CITE_MISSING=$(pk_cited_missing)
if [ -z "$CITE_MISSING" ]; then
  ok "skills: every backticked pk verb in skills/*/SKILL.md is a bin/pk dispatcher label"
else
  fail "skills: cited pk verbs missing from bin/pk" "$CITE_MISSING"
fi

# ── CLI tests: pk issue create — Area-label intake guard ─────────────────────

echo "== issue create: Area guard =="

# Four filers once created issues with no Area: label on a board whose
# method.config.md lists them (SiteLine, 2026-10-27). The guard fires before
# any network call, so these run with no token and must fail on the guard
# (or, past it, on anything but the guard).
make_fixture
write_config '```
Team ID: 00000000-0000-0000-0000-000000000000
Area labels: Area: Security, Area: Budget Editor, Area: Platform
```'

run_pk issue create --title "x" --label Bug
case "$RUN_CODE:$RUN_OUT" in
  0:*) fail "issue create: refuses without Area: label" "exit 0" ;;
  *"no Area: label"*"Area: Security"*) ok "issue create: refuses without Area: label, names the configured set" ;;
  *) fail "issue create: refuses without Area: label" "got: $RUN_OUT" ;;
esac

run_pk issue create --title "x" --label Bug --label "Area: Platform"
case "$RUN_OUT" in
  *"no Area: label"*) fail "issue create: Area: label passes the guard" "guard fired: $RUN_OUT" ;;
  *) ok "issue create: Area: label passes the guard" ;;
esac

run_pk issue create --title "x" --no-area
case "$RUN_OUT" in
  *"no Area: label"*) fail "issue create: --no-area waives the guard" "guard fired: $RUN_OUT" ;;
  *) ok "issue create: --no-area waives the guard" ;;
esac

# No Area labels configured (not the lanes model): the guard is off.
write_config '```
Team ID: 00000000-0000-0000-0000-000000000000
```'
run_pk issue create --title "x"
case "$RUN_OUT" in
  *"no Area: label"*) fail "issue create: guard off without Area labels config" "guard fired: $RUN_OUT" ;;
  *) ok "issue create: guard off without Area labels config" ;;
esac

# ── pk verify: every gate command counts, not just the last (v5.2.4) ──────────
# The gate is one bash script. Its exit status used to be the LAST command's, so
# an early failure under a green last line passed `pk verify` and let
# `pk promote` open its PR (Piper PIPER-1362: three `pnpm: command not found`
# lines, then a skipped `if` leg exiting 0).

echo "== pk verify gate exit status (v5.2.4) =="

gate_config() {
  # $1 = gate body (one command per line)
  write_config "$(printf '## Pre-Deploy Gate\n\n```bash\n%s\n```' "$1")"
}

make_fixture

gate_config 'false
true'
run_pk verify
if [ $RUN_CODE -ne 0 ]; then ok "verify gate: early failure under a green last line fails"
else fail "verify gate: early failure under a green last line fails" "rc=$RUN_CODE out: $(echo "$RUN_OUT" | tail -3)"; fi

gate_config 'pk-smoke-no-such-command-xyz
if false; then false; fi'
run_pk verify
if [ $RUN_CODE -ne 0 ]; then ok "verify gate: command-not-found before a skipped if-leg fails"
else fail "verify gate: command-not-found before a skipped if-leg fails" "rc=$RUN_CODE out: $(echo "$RUN_OUT" | tail -3)"; fi
case "$RUN_OUT" in *"gate command failed (exit 127): pk-smoke-no-such-command-xyz"*) ok "verify gate: names the failing command" ;;
  *) fail "verify gate: names the failing command" "out: $(echo "$RUN_OUT" | tail -3)" ;; esac

gate_config 'cat >/dev/null
false'
run_pk verify
if [ $RUN_CODE -ne 0 ]; then ok "verify gate: the gate is not fed on stdin (a reader cannot swallow later lines)"
else fail "verify gate: the gate is not fed on stdin (a reader cannot swallow later lines)" "rc=$RUN_CODE"; fi

gate_config 'true
if false; then false; fi
git rev-parse -q --verify HEAD >/dev/null || { echo "no HEAD" >&2; exit 1; }
true && true'
run_pk verify
if [ $RUN_CODE -eq 0 ]; then ok "verify gate: skipped if-legs and guarded || legs stay green"
else fail "verify gate: skipped if-legs and guarded || legs stay green" "rc=$RUN_CODE out: $(echo "$RUN_OUT" | tail -3)"; fi

gate_config 'f() { false; }
f
true'
run_pk verify
case "$RUN_OUT" in *"gate command failed (exit 1): false"*) ok "verify gate: a failure inside a function is named" ;;
  *) fail "verify gate: a failure inside a function is named" "rc=$RUN_CODE out: $(echo "$RUN_OUT" | tail -3)" ;; esac

gate_config 'if true; then (exit 3); fi
true'
run_pk verify
if [ $RUN_CODE -ne 0 ]; then ok "verify gate: a failing subshell inside a taken if-leg fails"
else fail "verify gate: a failing subshell inside a taken if-leg fails" "rc=$RUN_CODE"; fi

# pk promote must stop at step 2, before the PR opens.
make_fixture
GE_REMOTE=$(mktemp -d); git -C "$GE_REMOTE" init -q --bare
git -C "$FIXTURE" remote add origin "$GE_REMOTE"
git -C "$FIXTURE" branch dev
git -C "$FIXTURE" push -q -u origin main dev 2>/dev/null
git -C "$FIXTURE" checkout -q dev
git -C "$FIXTURE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m "dev work"
git -C "$FIXTURE" push -q origin dev 2>/dev/null
git -C "$FIXTURE" checkout -q main
write_config '```
Integration branch: dev
Ship environments: dev,main
```

## Pre-Deploy Gate

```bash
pk-smoke-no-such-command-xyz
true
```'
: > "$GH_LOG"
run_pk promote main
o=0; case "$RUN_OUT" in *"Open promote PR"*) o=1 ;; esac
p=0; grep -q 'pr create' "$GH_LOG" && p=1
if [ $RUN_CODE -ne 0 ] && [ $o -eq 0 ] && [ $p -eq 0 ]; then ok "promote: failing gate line stops before the PR opens"
else fail "promote: failing gate line stops before the PR opens" "rc=$RUN_CODE opened=$o gh_pr_create=$p out: $(echo "$RUN_OUT" | tail -3)"; fi
rm -rf "$GE_REMOTE"

# ── Synced docs carry no consumer's retired names (v5.2.5) ───────────────────
# Every sync copies these files over the consumer's, so a consumer-specific name
# here reverts that consumer's own fix on each run (Piper PIPER-1363: `vercel
# --prod`, retired by PIPER-1309; `../SiteLine`, gone since Piper's repo merge;
# `/sync-legacy`, a skill Piper deleted). Use a generic placeholder instead.

echo "== synced docs: no consumer-retired names (v5.2.5) =="

RETIRED_HITS=$(cd "$REPO_ROOT" && grep -rnE 'vercel --prod|\.\./SiteLine|/sync-legacy' \
  skills templates sop agents workflows RUNBOOK.md method.md GUIDE.md 2>/dev/null)
if [ -z "$RETIRED_HITS" ]; then ok "synced docs name no consumer-retired command or path"
else fail "synced docs name no consumer-retired command or path" "$(echo "$RETIRED_HITS" | cut -c1-140 | head -5)"; fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo
echo "pk smoke: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo "failed:$FAILED_NAMES"
  exit 1
fi
