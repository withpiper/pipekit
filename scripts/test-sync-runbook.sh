#!/usr/bin/env bash
# test-sync-runbook.sh — fixture-based tests for sync-method.sh's project
# runbook step (v5.0.0): one runbook per consumer, three regions, three
# owners (/tpm, the project, sync) — and the weekly plan it scaffolds once
# beside the runbook (v5.1.0).
#
# Covers:
#   fresh consumer          → created from the skeleton with all three blocks;
#                             the Now body points at the plan path; the plan
#                             is created from its skeleton with a dateless marker
#   existing file           → only the pipekit block changes; Notes, the tpm
#                             sentinel and trailing sections stay byte-identical;
#                             an existing plan is byte-identical and reported OK
#   damaged markers         → ERROR on stderr, file untouched, non-zero exit
#   legacy pipekit/RUNBOOK.md → removed and reported as MIGRATED
#   --dry-run               → WOULD CREATE / WOULD UPDATE block / WOULD MIGRATE,
#                             nothing written (plan included)
#   Runbook path key        → honored (code-block and table forms)
#   Plan path key           → honored; Plan primary / Runbook primary → SKIP
#   .claude/overrides/RUNBOOK.md → becomes the block body; drift warning when
#                             upstream moves underneath it
#   retired lane-map        → a consumer's local copy survives untouched
#
# No network: the sync is pointed at a throwaway method tree via
# SYNC_METHOD_TEMP (plus SYNC_METHOD_REEXEC=1 so the self-update guard doesn't
# copy the fixture's absent sync-method.sh over the real one). The script
# rm -rf's that tree on exit, so every run gets a fresh one.
#
# Run: bash scripts/test-sync-runbook.sh   (exit 0 on pass, 1 on any failure)

set -uo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
SYNC="$repo_root/scripts/sync-method.sh"

fail=0
pass=0

ok()  { pass=$((pass + 1)); printf '  ok  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n       %s\n' "$1" "$2"; }

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then ok "$name"; else bad "$name" "expected: $expected · got: $actual"; fi
}
assert_contains() {
  local name="$1" needle="$2" hay="$3"
  case "$hay" in *"$needle"*) ok "$name" ;; *) bad "$name" "missing: $needle" ;; esac
}
assert_not_contains() {
  local name="$1" needle="$2" hay="$3"
  case "$hay" in *"$needle"*) bad "$name" "unexpectedly present: $needle" ;; *) ok "$name" ;; esac
}
assert_file()    { if [ -f "$2" ]; then ok "$1"; else bad "$1" "no such file: $2"; fi; }
assert_no_file() { if [ -f "$2" ]; then bad "$1" "file exists: $2"; else ok "$1"; fi; }
assert_same()    { if cmp -s "$2" "$3"; then ok "$1"; else bad "$1" "files differ: $2 vs $3"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home"

# ─── Fixtures ───────────────────────────────────────────────────────────────

BODY='upstream how-we-run body v1'
WITH_LANE_MAP=0   # 1 → upstream still ships skills/lane-map (transitional window)
NO_RUNBOOK=0      # 1 → upstream has no RUNBOOK.md (the smoke-suite fixture shape)

# A minimal method tree. skills/demo is load-bearing: the portable-skills step
# pipes `ls -d "$TEMP/skills/"*/` through xargs under pipefail, and an empty
# skills/ aborts the sync. Its SKILL.md deliberately has no `description:`
# line — until v5.0.0 that made the changelog's "### New" grep fail the
# assignment under pipefail and set -e killed the sync, so a first sync here
# also guards that fix. method.config.template.md is load-bearing too: a
# consumer without method.config.md gets it cp'd, and set -e dies if absent.
make_method() {
  local m="$1"
  mkdir -p "$m/skills/demo" "$m/templates" "$m/bin"
  echo 'upstream demo body' > "$m/skills/demo/SKILL.md"
  cp "$repo_root/templates/RUNBOOK.skeleton.md" "$m/templates/RUNBOOK.skeleton.md"
  cp "$repo_root/templates/WEEKLY_PLAN.skeleton.md" "$m/templates/WEEKLY_PLAN.skeleton.md"
  printf '#!/bin/bash\nPK_VERSION="9.9.9"\n' > "$m/bin/pk"
  mkdir -p "$m/bin/pk-init"
  printf '#!/bin/bash\necho pk-init\n' > "$m/bin/pk-init/main.sh"
  printf '# Method Configuration\n\n| **Project name** | `your-project` |\n' > "$m/method.config.template.md"
  if [ "$NO_RUNBOOK" -eq 0 ]; then
    printf '# Pipekit Runbook\n\n**v9.9.9** — stamp line\n\n%s\n' "$BODY" > "$m/RUNBOOK.md"
  fi
  if [ "$WITH_LANE_MAP" -eq 1 ]; then
    mkdir -p "$m/skills/lane-map"
    echo 'upstream lane-map body' > "$m/skills/lane-map/SKILL.md"
  fi
}

SYNC_OUT=""
SYNC_ERR=""
SYNC_CODE=0
run_sync() {   # $1 = project dir, rest = sync flags
  local proj="$1"; shift
  local m="$TMP/method.$pass.$fail.$RANDOM"
  make_method "$m"
  SYNC_OUT=$(HOME="$TMP/home" SYNC_METHOD_REEXEC=1 SYNC_METHOD_TEMP="$m" \
    bash "$SYNC" --target="$proj" "$@" 2>"$TMP/stderr")
  SYNC_CODE=$?
  SYNC_ERR=$(cat "$TMP/stderr")
}

new_proj() { local p="$TMP/$1"; mkdir -p "$p"; printf '%s' "$p"; }

# Everything outside the pipekit block, for byte-identity checks.
outside_block() {
  local f="$1" b e
  b=$(grep -n -m1 '^<!-- pipekit:begin' "$f" | cut -d: -f1)
  e=$(grep -n -m1 '^<!-- pipekit:end' "$f" | cut -d: -f1)
  awk -v b="$b" 'NR < b' "$f"
  tail -n +"$((e + 1))" "$f"
}

write_existing() {   # a hand-maintained runbook with a stale pipekit block
  cat > "$1" <<'EOF'
# RUNBOOK — Hand Edited

## Now
<!-- tpm:begin · agreed 2026-10-01 · derived from Linear · written by /tpm, regenerate don't edit -->
TPM-SENTINEL-7f3a: lane A then lane B
<!-- tpm:end -->

## Notes
My notes & my *formatting* — keep every byte.
  indented line with trailing spaces

## How we run
<!-- pipekit:begin · v0.0.1 · synced from Pipekit, do not edit; override via .claude/overrides/RUNBOOK.md -->
stale body
<!-- pipekit:end -->

## Appendix
after the block, also mine
EOF
}

# ─── 1. Fresh consumer ──────────────────────────────────────────────────────
echo "1. fresh consumer → created from the skeleton"
P=$(new_proj fresh)
run_sync "$P"
RB="$P/engineering/RUNBOOK.md"
assert_eq       "fresh: exit 0" 0 "$SYNC_CODE"
assert_file     "fresh: engineering/RUNBOOK.md created" "$RB"
assert_contains "fresh: CREATED reported" "CREATED engineering/RUNBOOK.md" "$SYNC_OUT"
content=$(cat "$RB" 2>/dev/null)
assert_contains "fresh: heading is the repo dir name"   "# RUNBOOK — fresh" "$content"
assert_contains "fresh: ## Now"                         "## Now" "$content"
assert_contains "fresh: tpm:begin"                      "<!-- tpm:begin · agreed YYYY-MM-DD" "$content"
assert_contains "fresh: Now body points at the plan"    "_(this week → engineering/WEEKLY_PLAN.md — run /tpm to agree it)_" "$content"
assert_contains "fresh: tpm:end"                        "<!-- tpm:end -->" "$content"
assert_contains "fresh: ## Notes"                       "## Notes" "$content"
assert_contains "fresh: ## How we run"                  "## How we run" "$content"
assert_contains "fresh: pipekit:begin carries version"  "<!-- pipekit:begin · v9.9.9 · synced from Pipekit" "$content"
assert_contains "fresh: upstream body present"          "$BODY" "$content"
assert_contains "fresh: pipekit:end"                    "<!-- pipekit:end -->" "$content"
assert_not_contains "fresh: no unfilled placeholders"   "{{" "$content"
assert_eq       "fresh: exactly one pipekit:begin" 1 "$(grep -c '^<!-- pipekit:begin' "$RB")"
assert_eq       "fresh: exactly one pipekit:end"   1 "$(grep -c '^<!-- pipekit:end' "$RB")"
assert_eq       "fresh: end marker on its own line after the body" \
  "$BODY" "$(grep -B1 '^<!-- pipekit:end' "$RB" | head -1)"
assert_no_file  "fresh: no pipekit/RUNBOOK.md copy" "$P/pipekit/RUNBOOK.md"
assert_contains "fresh: changelog lists the runbook" '`engineering/RUNBOOK.md` — updated' \
  "$(cat "$P/pipekit/.sync-changelog.md" 2>/dev/null)"
PLAN="$P/engineering/WEEKLY_PLAN.md"
assert_file     "fresh/plan: engineering/WEEKLY_PLAN.md created" "$PLAN"
assert_contains "fresh/plan: CREATED reported" "CREATED engineering/WEEKLY_PLAN.md" "$SYNC_OUT"
plan=$(cat "$PLAN" 2>/dev/null)
assert_contains "fresh/plan: heading carries the project name" "# fresh — Weekly Plan" "$plan"
assert_contains "fresh/plan: dateless tpm:begin marker" "<!-- tpm:begin · agreed YYYY-MM-DD · derived from Linear · written by /tpm, regenerate don't edit -->" "$plan"
assert_contains "fresh/plan: placeholder body" "_(no agreement yet — run /tpm)_" "$plan"
assert_contains "fresh/plan: tpm:end" "<!-- tpm:end -->" "$plan"
assert_not_contains "fresh/plan: no unfilled placeholders" "{{" "$plan"
assert_eq       "fresh/plan: byte-identical to the rendered skeleton" \
  "$(sed 's/{{PROJECT_NAME}}/fresh/' "$repo_root/templates/WEEKLY_PLAN.skeleton.md")" "$plan"
assert_contains "fresh/plan: changelog lists the plan" '`engineering/WEEKLY_PLAN.md` — updated' \
  "$(cat "$P/pipekit/.sync-changelog.md" 2>/dev/null)"

echo "1b. second sync, same upstream → no-op"
cp "$RB" "$TMP/fresh.before"
cp "$PLAN" "$TMP/fresh.plan.before"
run_sync "$P"
assert_eq       "no-op: exit 0" 0 "$SYNC_CODE"
assert_contains "no-op: reported OK" "OK engineering/RUNBOOK.md" "$SYNC_OUT"
assert_same     "no-op: file byte-identical" "$TMP/fresh.before" "$RB"
assert_contains "no-op/plan: reported OK, owned by /tpm" "OK engineering/WEEKLY_PLAN.md (owned by /tpm, not touched)" "$SYNC_OUT"
assert_same     "no-op/plan: byte-identical" "$TMP/fresh.plan.before" "$PLAN"
assert_not_contains "no-op/plan: changelog does not list the plan" '`engineering/WEEKLY_PLAN.md` — updated' \
  "$(cat "$P/pipekit/.sync-changelog.md" 2>/dev/null)"

# ─── 2. Existing file: only the pipekit block moves ─────────────────────────
echo "2. existing file → only the pipekit block changes"
P=$(new_proj existing)
mkdir -p "$P/engineering"
write_existing "$P/engineering/RUNBOOK.md"
RB="$P/engineering/RUNBOOK.md"
cp "$RB" "$TMP/existing.before"
# A plan /tpm already wrote — an agreed week, nothing like the skeleton.
printf '# Existing — Weekly Plan\n<!-- tpm:begin · agreed 2026-10-06 · derived from Linear · written by /tpm, regenerate don'"'"'t edit -->\nPLAN-SENTINEL-9c1d: MUST lane A · NEXT lane B  \n<!-- tpm:end -->\nafter the block, also /tpm'"'"'s' > "$P/engineering/WEEKLY_PLAN.md"
cp "$P/engineering/WEEKLY_PLAN.md" "$TMP/existing.plan.before"
BODY='upstream how-we-run body v2'
run_sync "$P"
assert_eq       "existing: exit 0" 0 "$SYNC_CODE"
assert_contains "existing: UPDATED reported" "UPDATED engineering/RUNBOOK.md" "$SYNC_OUT"
assert_same     "existing/plan: byte-identical after sync" "$TMP/existing.plan.before" "$P/engineering/WEEKLY_PLAN.md"
assert_contains "existing/plan: reported OK, owned by /tpm" "OK engineering/WEEKLY_PLAN.md (owned by /tpm, not touched)" "$SYNC_OUT"
assert_not_contains "existing/plan: never CREATED over an existing plan" "CREATED engineering/WEEKLY_PLAN.md" "$SYNC_OUT"
content=$(cat "$RB")
assert_contains     "existing: new body present"         "$BODY" "$content"
assert_not_contains "existing: stale body gone"          "stale body" "$content"
assert_contains     "existing: version stamp moved"      "<!-- pipekit:begin · v9.9.9 ·" "$content"
assert_not_contains "existing: old stamp gone"           "v0.0.1" "$content"
assert_contains     "existing: tpm sentinel intact"      "TPM-SENTINEL-7f3a: lane A then lane B" "$content"
assert_contains     "existing: heading intact"           "# RUNBOOK — Hand Edited" "$content"
outside_block "$TMP/existing.before" > "$TMP/existing.outside.before"
outside_block "$RB"                  > "$TMP/existing.outside.after"
assert_same "existing: everything outside the block is byte-identical" \
  "$TMP/existing.outside.before" "$TMP/existing.outside.after"
assert_eq   "existing: still exactly one pipekit:begin" 1 "$(grep -c '^<!-- pipekit:begin' "$RB")"
assert_eq   "existing: still exactly one pipekit:end"   1 "$(grep -c '^<!-- pipekit:end' "$RB")"
assert_contains "existing: changelog lists the runbook" '`engineering/RUNBOOK.md` — updated' \
  "$(cat "$P/pipekit/.sync-changelog.md")"

# ─── 3. Damaged markers fail closed ─────────────────────────────────────────
echo "3. damaged markers → ERROR, untouched, non-zero exit"
damaged_case() {   # $1 = label, $2 = file content
  local P RB
  P=$(new_proj "damaged-$1")
  mkdir -p "$P/engineering" "$P/pipekit"
  printf '%s' "$2" > "$P/engineering/RUNBOOK.md"
  echo 'legacy copy' > "$P/pipekit/RUNBOOK.md"
  RB="$P/engineering/RUNBOOK.md"
  cp "$RB" "$TMP/damaged-$1.before"
  run_sync "$P"
  if [ "$SYNC_CODE" -ne 0 ]; then ok "damaged/$1: non-zero exit"; else bad "damaged/$1: non-zero exit" "exit 0"; fi
  assert_contains "damaged/$1: ERROR on stderr" \
    "ERROR: runbook markers damaged in engineering/RUNBOOK.md — not written; restore the markers or delete the file to re-create it" "$SYNC_ERR"
  assert_same     "damaged/$1: file untouched" "$TMP/damaged-$1.before" "$RB"
  assert_file     "damaged/$1: legacy copy NOT migrated" "$P/pipekit/RUNBOOK.md"
  assert_not_contains "damaged/$1: no MIGRATED" "MIGRATED" "$SYNC_OUT"
}
damaged_case none        $'# RUNBOOK\n\n## Notes\nno markers at all\n'
damaged_case begin-only  $'# RUNBOOK\n<!-- pipekit:begin · v1 -->\nbody\n'
damaged_case end-only    $'# RUNBOOK\nbody\n<!-- pipekit:end -->\n'
damaged_case reversed    $'# RUNBOOK\n<!-- pipekit:end -->\nbody\n<!-- pipekit:begin · v1 -->\n'
damaged_case duplicated  $'# RUNBOOK\n<!-- pipekit:begin · v1 -->\nb\n<!-- pipekit:end -->\n<!-- pipekit:begin · v1 -->\nb\n<!-- pipekit:end -->\n'

echo "3b. damaged markers under --dry-run → still an error"
P=$(new_proj damaged-dry)
mkdir -p "$P/engineering"
printf '# RUNBOOK\nno markers\n' > "$P/engineering/RUNBOOK.md"
run_sync "$P" --dry-run
if [ "$SYNC_CODE" -ne 0 ]; then ok "damaged/dry-run: non-zero exit"; else bad "damaged/dry-run: non-zero exit" "exit 0"; fi
assert_contains "damaged/dry-run: ERROR on stderr" "ERROR: runbook markers damaged" "$SYNC_ERR"

# ─── 4. Legacy pipekit/RUNBOOK.md migrates ──────────────────────────────────
echo "4. legacy pipekit/RUNBOOK.md → migrated and removed"
P=$(new_proj legacy)
mkdir -p "$P/pipekit"
echo 'old synced runbook' > "$P/pipekit/RUNBOOK.md"
run_sync "$P"
assert_eq       "legacy: exit 0" 0 "$SYNC_CODE"
assert_file     "legacy: new runbook created" "$P/engineering/RUNBOOK.md"
assert_no_file  "legacy: pipekit/RUNBOOK.md removed" "$P/pipekit/RUNBOOK.md"
assert_contains "legacy: MIGRATED reported" \
  "MIGRATED pipekit/RUNBOOK.md → engineering/RUNBOOK.md (How we run block)" "$SYNC_OUT"
run_sync "$P"
assert_no_file  "legacy: not re-created on the next sync" "$P/pipekit/RUNBOOK.md"
assert_not_contains "legacy: no second MIGRATED" "MIGRATED" "$SYNC_OUT"

# ─── 5. --dry-run writes nothing ────────────────────────────────────────────
echo "5. --dry-run → announces, writes nothing"
P=$(new_proj dry-fresh)
run_sync "$P" --dry-run
assert_eq       "dry/fresh: exit 0" 0 "$SYNC_CODE"
assert_contains "dry/fresh: WOULD CREATE" "WOULD CREATE engineering/RUNBOOK.md" "$SYNC_OUT"
assert_no_file  "dry/fresh: nothing written" "$P/engineering/RUNBOOK.md"
assert_contains "dry/fresh/plan: WOULD CREATE" "WOULD CREATE engineering/WEEKLY_PLAN.md" "$SYNC_OUT"
assert_no_file  "dry/fresh/plan: nothing written" "$P/engineering/WEEKLY_PLAN.md"

P=$(new_proj dry-existing)
mkdir -p "$P/engineering" "$P/pipekit"
write_existing "$P/engineering/RUNBOOK.md"
echo 'old synced runbook' > "$P/pipekit/RUNBOOK.md"
cp "$P/engineering/RUNBOOK.md" "$TMP/dry-existing.before"
run_sync "$P" --dry-run
assert_eq       "dry/existing: exit 0" 0 "$SYNC_CODE"
assert_contains "dry/existing: WOULD UPDATE block" "WOULD UPDATE block in engineering/RUNBOOK.md" "$SYNC_OUT"
assert_contains "dry/existing: WOULD MIGRATE" \
  "WOULD MIGRATE pipekit/RUNBOOK.md → engineering/RUNBOOK.md (How we run block)" "$SYNC_OUT"
assert_same     "dry/existing: runbook untouched" "$TMP/dry-existing.before" "$P/engineering/RUNBOOK.md"
assert_file     "dry/existing: legacy copy still present" "$P/pipekit/RUNBOOK.md"

# ─── 6. Runbook path + project name from method.config.md ───────────────────
echo "6. Runbook path and Project display name honored"
P=$(new_proj custom-path)
cat > "$P/method.config.md" <<'EOF'
# method.config.md

```
Project name: widget-co
Project display name: Widget Co
Runbook path: docs/ops/RUNBOOK.md
```
EOF
run_sync "$P"
assert_eq       "custom: exit 0" 0 "$SYNC_CODE"
assert_file     "custom: created at docs/ops/RUNBOOK.md" "$P/docs/ops/RUNBOOK.md"
assert_no_file  "custom: nothing at the default path" "$P/engineering/RUNBOOK.md"
assert_contains "custom: heading is the display name" "# RUNBOOK — Widget Co" "$(cat "$P/docs/ops/RUNBOOK.md" 2>/dev/null)"
assert_contains "custom: changelog uses the custom path" '`docs/ops/RUNBOOK.md` — updated' \
  "$(cat "$P/pipekit/.sync-changelog.md")"
# No Plan path set → the plan still lands at its default, and the custom
# runbook's Now body names that default.
assert_file     "custom/plan: default plan path beside a custom runbook path" "$P/engineering/WEEKLY_PLAN.md"
assert_contains "custom/plan: Now body names the default plan path" "_(this week → engineering/WEEKLY_PLAN.md — run /tpm to agree it)_" "$(cat "$P/docs/ops/RUNBOOK.md" 2>/dev/null)"

P=$(new_proj custom-plan)
cat > "$P/method.config.md" <<'EOF'
```
Project display name: Widget Co
Plan path: docs/WEEK.md
```
EOF
run_sync "$P"
assert_eq       "custom-plan: exit 0" 0 "$SYNC_CODE"
assert_file     "custom-plan: created at docs/WEEK.md" "$P/docs/WEEK.md"
assert_no_file  "custom-plan: nothing at the default plan path" "$P/engineering/WEEKLY_PLAN.md"
assert_contains "custom-plan: CREATED reported with the custom path" "CREATED docs/WEEK.md" "$SYNC_OUT"
assert_contains "custom-plan: heading is the display name" "# Widget Co — Weekly Plan" "$(cat "$P/docs/WEEK.md" 2>/dev/null)"
assert_contains "custom-plan: runbook Now body names the custom plan path" "_(this week → docs/WEEK.md — run /tpm to agree it)_" "$(cat "$P/engineering/RUNBOOK.md" 2>/dev/null)"
assert_contains "custom-plan: changelog uses the custom path" '`docs/WEEK.md` — updated' "$(cat "$P/pipekit/.sync-changelog.md")"

P=$(new_proj custom-table)
cat > "$P/method.config.md" <<'EOF'
| Key | Value |
|-----|-------|
| **Project name** | `widget-co` |
| **Runbook path** | `ops/RUNBOOK.md` |
EOF
run_sync "$P"
assert_file     "custom/table: created at ops/RUNBOOK.md" "$P/ops/RUNBOOK.md"
assert_contains "custom/table: heading falls back to Project name" "# RUNBOOK — widget-co" "$(cat "$P/ops/RUNBOOK.md" 2>/dev/null)"

# ─── 7. Override replaces the block body, with drift detection ──────────────
echo "7. .claude/overrides/RUNBOOK.md → block body, drift-checked"
P=$(new_proj override)
mkdir -p "$P/.claude/overrides"
echo 'OVERRIDE BODY — ours' > "$P/.claude/overrides/RUNBOOK.md"
BODY='upstream how-we-run body v1'
run_sync "$P"
RB="$P/engineering/RUNBOOK.md"
assert_eq           "override: exit 0" 0 "$SYNC_CODE"
assert_contains     "override: OVERRIDE reported" "OVERRIDE RUNBOOK.md (How we run block body)" "$SYNC_OUT"
content=$(cat "$RB" 2>/dev/null)
assert_contains     "override: body is the override"     "OVERRIDE BODY — ours" "$content"
assert_not_contains "override: upstream body absent"     "$BODY" "$content"
assert_contains     "override: version stamp still upstream's" "<!-- pipekit:begin · v9.9.9 ·" "$content"
assert_file         "override: upstream snapshot written" "$P/.claude/overrides/.upstream-snapshot/RUNBOOK.md"
assert_contains     "override: snapshot holds the upstream body" "$BODY" \
  "$(cat "$P/.claude/overrides/.upstream-snapshot/RUNBOOK.md" 2>/dev/null)"
assert_not_contains "override: no drift on first sync" "DRIFT RUNBOOK.md" "$SYNC_OUT"

BODY='upstream how-we-run body v2'
run_sync "$P"
assert_contains "override/drift: warning when upstream moves" "⚠ DRIFT RUNBOOK.md — upstream changed" "$SYNC_OUT"
assert_contains "override/drift: summary names it" "Override drift detected on: RUNBOOK.md" "$SYNC_OUT"
assert_contains "override/drift: changelog Drift section" "## Overrides" "$(cat "$P/pipekit/.sync-changelog.md")"
assert_contains "override/drift: block still the override" "OVERRIDE BODY — ours" "$(cat "$RB")"
run_sync "$P"
assert_not_contains "override/drift: quiet once snapshot caught up" "DRIFT RUNBOOK.md" "$SYNC_OUT"

# ─── 8. Retired lane-map survives sync ──────────────────────────────────────
echo "8. retired lane-map → consumer's local copy untouched"
P=$(new_proj retired)
mkdir -p "$P/.claude/skills/lane-map"
printf 'my curated lane map — groupings, collision notes, artifact URL\n' > "$P/.claude/skills/lane-map/SKILL.md"
cp "$P/.claude/skills/lane-map/SKILL.md" "$TMP/lane-map.before"
run_sync "$P"
assert_eq   "retired: exit 0" 0 "$SYNC_CODE"
assert_same "retired: local lane-map untouched (upstream has none)" "$TMP/lane-map.before" "$P/.claude/skills/lane-map/SKILL.md"
assert_not_contains "retired: not flagged as undeclared" '`/lane-map` — exists locally but not in the method repo' \
  "$(cat "$P/pipekit/.sync-changelog.md")"
WITH_LANE_MAP=1
run_sync "$P"
WITH_LANE_MAP=0
assert_same     "retired: local lane-map untouched (upstream still ships it)" "$TMP/lane-map.before" "$P/.claude/skills/lane-map/SKILL.md"
assert_contains "retired: skip reported" "SKIP skill: lane-map (retired upstream" "$SYNC_OUT"

# ─── 9. Upstream without RUNBOOK.md → step skipped cleanly ──────────────────
echo "9. upstream without RUNBOOK.md → skipped"
P=$(new_proj no-runbook)
NO_RUNBOOK=1
run_sync "$P"
NO_RUNBOOK=0
assert_eq       "no-runbook: exit 0" 0 "$SYNC_CODE"
assert_contains "no-runbook: SKIP reported" "SKIP runbook (source not found)" "$SYNC_OUT"
assert_no_file  "no-runbook: nothing created" "$P/engineering/RUNBOOK.md"
assert_no_file  "no-runbook: no plan either (same SKIP)" "$P/engineering/WEEKLY_PLAN.md"

# ─── 10. Sibling repo: the plan lives in the primary → SKIP ─────────────────
echo "10. Plan primary / Runbook primary → plan SKIPped, not created"
P=$(new_proj sibling-rb)
cat > "$P/method.config.md" <<'EOF'
```
Runbook primary: ../x
```
EOF
run_sync "$P"
assert_eq       "sibling/runbook-primary: exit 0" 0 "$SYNC_CODE"
assert_contains "sibling/runbook-primary: SKIP names the primary" "SKIP engineering/WEEKLY_PLAN.md (plan lives in ../x)" "$SYNC_OUT"
assert_no_file  "sibling/runbook-primary: plan not created" "$P/engineering/WEEKLY_PLAN.md"
assert_no_file  "sibling/runbook-primary: nothing at ../x either" "$TMP/x/engineering/WEEKLY_PLAN.md"
assert_file     "sibling/runbook-primary: the runbook itself is still created" "$P/engineering/RUNBOOK.md"

P=$(new_proj sibling-plan)
cat > "$P/method.config.md" <<'EOF'
```
Plan primary: ../SiteLine
Plan path: docs/WEEK.md
```
EOF
run_sync "$P" --dry-run
assert_eq       "sibling/plan-primary: exit 0" 0 "$SYNC_CODE"
assert_contains "sibling/plan-primary: SKIP names the primary and the custom path" "SKIP docs/WEEK.md (plan lives in ../SiteLine)" "$SYNC_OUT"
assert_not_contains "sibling/plan-primary: no WOULD CREATE for the plan" "WOULD CREATE docs/WEEK.md" "$SYNC_OUT"
assert_no_file  "sibling/plan-primary: plan not created" "$P/docs/WEEK.md"

# ─── 11. Plan path: none → no plan, runbook says so ─────────────────────────
echo "11. Plan path: none → plan SKIPped, runbook Now block names no file"
P=$(new_proj no-plan)
cat > "$P/method.config.md" <<'EOF'
```
Plan path: none
```
EOF
run_sync "$P"
assert_eq       "none: exit 0" 0 "$SYNC_CODE"
assert_contains "none: SKIP line" "SKIP weekly plan (Plan path: none)" "$SYNC_OUT"
assert_no_file  "none: no plan file" "$P/engineering/WEEKLY_PLAN.md"
assert_no_file  "none: no file literally called none" "$P/none"
assert_file     "none: the runbook itself is still created" "$P/engineering/RUNBOOK.md"
content=$(cat "$P/engineering/RUNBOOK.md")
assert_contains     "none: Now body says there is no plan" "no weekly plan on this project" "$content"
assert_not_contains "none: Now body does not point at 'none'" "→ none" "$content"

# ─── 12. --help writes nothing; unknown flag refuses; bin/pk-init ships ──────
echo "12. --help / unknown flag write nothing; bin/pk-init/ is synced"
P=$(new_proj flags)
run_sync "$P" --help
assert_eq       "help: exit 0" 0 "$SYNC_CODE"
assert_contains "help: usage printed" "Usage: scripts/sync-method.sh" "$SYNC_OUT"
assert_no_file  "help: nothing synced" "$P/bin/pk"
run_sync "$P" --bogus
assert_eq       "unknown flag: exit 2" 2 "$SYNC_CODE"
assert_contains "unknown flag: named" "unknown flag: --bogus" "$SYNC_ERR"
assert_no_file  "unknown flag: nothing synced" "$P/bin/pk"
run_sync "$P"
assert_eq       "pk-init: sync exit 0" 0 "$SYNC_CODE"
assert_file     "pk-init: main.sh synced beside bin/pk" "$P/bin/pk-init/main.sh"
[ -x "$P/bin/pk-init/main.sh" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "  FAIL pk-init: main.sh executable"; }

echo ""
if [ "$fail" -eq 0 ]; then
  printf '✓ %d assertions passed\n' "$pass"
  exit 0
else
  printf '✗ %d failed, %d passed\n' "$fail" "$pass"
  exit 1
fi
