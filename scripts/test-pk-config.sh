#!/usr/bin/env bash
# test-pk-config.sh — fixture-based tests for bin/pk helpers.
#
# Covers regressions from the v2.3.1 canary (WIT-280):
#   #15  pk_config silently returned defaults for code-block Key: Value configs
#   #3   /verify Step 0 Integration branch parser shared the same blind spot
#   #4   /verify Step 2 awk gate-extractor self-terminated on its own start line
#
# Run: bash scripts/test-pk-config.sh   (exit 0 on pass, 1 on first failure)

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

with_fixture() {
  # Run pk_config inside a temp git repo with $1 as method.config.md contents.
  local content="$1" key="$2" default="${3:-}"
  local dir
  dir=$(mktemp -d)
  trap 'rm -rf "$dir"' RETURN
  (
    cd "$dir"
    git init -q
    printf '%s' "$content" > method.config.md
    pk_config "$key" "$default"
  )
}

# ─── Fixture 1: Piper-style code-block V2 keys ──────────────────────────────
piper_cfg='# method.config.md (Piper-style)

## V2 keys

```
Backend: auto
Integration branch: dev
Promote to main: true
Require QA review: true
Default deep flag: false
Ship environments: dev,beta,main
```
'

echo "Fixture 1: code-block Key: Value (Piper-style)"
assert_eq "Backend"             "auto"          "$(with_fixture "$piper_cfg" "Backend" "vbw")"
assert_eq "Integration branch"  "dev"           "$(with_fixture "$piper_cfg" "Integration branch")"
assert_eq "Ship environments"   "dev,beta,main" "$(with_fixture "$piper_cfg" "Ship environments" "dev,main")"
assert_eq "Require QA review"   "true"          "$(with_fixture "$piper_cfg" "Require QA review" "false")"
assert_eq "Promote to main"     "true"          "$(with_fixture "$piper_cfg" "Promote to main" "true")"

# ─── Fixture 2: rs-vault-style single-tier code-block ───────────────────────
rsvault_cfg='## V2 keys

```
Backend: native
Integration branch: main
Promote to main: false
Ship environments: main
```
'

echo "Fixture 2: code-block Key: Value (rs-vault-style)"
assert_eq "Backend"            "native" "$(with_fixture "$rsvault_cfg" "Backend" "vbw")"
assert_eq "Integration branch" "main"   "$(with_fixture "$rsvault_cfg" "Integration branch")"
assert_eq "Promote to main"    "false"  "$(with_fixture "$rsvault_cfg" "Promote to main" "true")"

# ─── Fixture 3: legacy markdown-table format ────────────────────────────────
legacy_cfg='## V2 keys

| Key | Value | Default | Used by |
|-----|-------|---------|---------|
| **Backend** | `vbw` | `vbw` | `/work` |
| **Integration branch** | `dev` | derived | `pk ship` |
| **Ship environments** | `dev,main` | `dev,main` | `pk ship` |
'

echo "Fixture 3: legacy markdown-table"
assert_eq "Backend"             "vbw"      "$(with_fixture "$legacy_cfg" "Backend" "native")"
assert_eq "Integration branch"  "dev"      "$(with_fixture "$legacy_cfg" "Integration branch")"
assert_eq "Ship environments"   "dev,main" "$(with_fixture "$legacy_cfg" "Ship environments" "dev,beta,main")"

# ─── Fixture 4: missing key falls back to default ───────────────────────────
empty_cfg='# method.config.md
no v2 keys here
'
echo "Fixture 4: missing key → default"
assert_eq "Missing key default" "fallback" "$(with_fixture "$empty_cfg" "Backend" "fallback")"
assert_eq "Missing key no-default" "" "$(with_fixture "$empty_cfg" "Backend")"

# ─── Fixture 5: malformed (table-style label but blank value) ───────────────
malformed_cfg='## V2 keys

| **Backend** |   |  |  |
'
echo "Fixture 5: blank value → default"
assert_eq "Blank table value → default" "vbw" "$(with_fixture "$malformed_cfg" "Backend" "vbw")"

echo ""
if [ "$fail" -eq 0 ]; then
  printf '✓ %d assertions passed\n' "$pass"
  exit 0
else
  printf '✗ %d failed, %d passed\n' "$fail" "$pass"
  exit 1
fi
