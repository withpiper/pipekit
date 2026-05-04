#!/usr/bin/env bash
# Emit: script_typecheck, script_lint, script_test, script_build
set -euo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel)}"
. "$(dirname "$0")/lib.sh"

pkg="$ROOT/package.json"

pick() {
  # $@ candidate script names; print first match in package.json scripts
  [ -f "$pkg" ] || return 0
  for name in "$@"; do
    if jq -e --arg n "$name" '.scripts[$n] // empty' "$pkg" >/dev/null 2>&1; then
      echo "$name"; return 0
    fi
  done
}

emit_or_missing() {
  local field="$1"; shift
  local picked
  picked=$(pick "$@")
  if [ -n "${picked:-}" ]; then
    emit_detected "$field" "$picked" "package.json scripts.$picked"
  else
    emit_missing "$field" "no matching script in package.json"
  fi
}

if [ ! -f "$pkg" ]; then
  out=$(jq -s 'add' \
    <(emit_missing script_typecheck "no package.json") \
    <(emit_missing script_lint      "no package.json") \
    <(emit_missing script_test      "no package.json") \
    <(emit_missing script_build     "no package.json"))
else
  out=$(jq -s 'add' \
    <(emit_or_missing script_typecheck typecheck check-types tsc) \
    <(emit_or_missing script_lint      lint check) \
    <(emit_or_missing script_test      test) \
    <(emit_or_missing script_build     build))
fi

echo "$out"
