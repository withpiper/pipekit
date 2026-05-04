#!/usr/bin/env bash
# render.sh — substitute detected values into method.config.template.md.
#
# Inputs:  $1=template path, $2=state.json path
# Output:  rendered markdown on stdout
#
# Substitutions are conservative: only fields whose state is "detected" get
# applied. Ambiguous (needs_input) and missing fields keep template defaults
# so prompt phase (step 5) can fill them.
set -euo pipefail

TEMPLATE="${1:?usage: render.sh <template> <state.json>}"
STATE="${2:?usage: render.sh <template> <state.json>}"

[ -f "$TEMPLATE" ] || { echo "ERROR: template not found: $TEMPLATE" >&2; exit 1; }
[ -f "$STATE" ]    || { echo "ERROR: state not found: $STATE" >&2; exit 1; }

# jq helper: get .field.value if status==detected, else empty.
val() {
  jq -r --arg f "$1" '
    .[$f] // {} | select(.status == "detected") | .value // empty
  ' "$STATE"
}

# jq helper: get .field.value as JSON (for arrays) if detected.
valj() {
  jq -c --arg f "$1" '
    .[$f] // {} | select(.status == "detected") | .value // empty
  ' "$STATE"
}

repo_name=$(val repo_name)
repo_org=$(val repo_org)
default_branch=$(val default_branch)
pm=$(val package_manager)
backend=$(val backend)
team_key=$(val linear_team_key)
team_id=$(val linear_team_id)
tiers_json=$(valj tiers)

s_typecheck=$(val script_typecheck)
s_lint=$(val script_lint)
s_test=$(val script_test)
s_build=$(val script_build)

# Title-case repo_name for display name (foo-bar → Foo Bar).
display_name=""
if [ -n "$repo_name" ]; then
  display_name=$(echo "$repo_name" \
    | tr '_-' '  ' \
    | awk '{ for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2)) }1')
fi

# Decide integration branch: prefer dev if present in tiers, else default_branch, else main.
integration_branch="main"
if [ -n "$tiers_json" ] && echo "$tiers_json" | jq -e 'index("dev")' >/dev/null 2>&1; then
  integration_branch="dev"
elif [ -n "$default_branch" ]; then
  integration_branch="$default_branch"
fi

# Build pre-deploy gate block from detected scripts.
gate_lines=""
if [ -n "$pm" ] && { [ -n "$s_typecheck" ] || [ -n "$s_lint" ] || [ -n "$s_test" ]; }; then
  [ -n "$s_typecheck" ] && gate_lines+="$pm run $s_typecheck"$'\n'
  [ -n "$s_lint" ]      && gate_lines+="$pm run $s_lint"$'\n'
  [ -n "$s_test" ]      && gate_lines+="$pm run $s_test"$'\n'
fi

# Read template, apply substitutions.
content=$(cat "$TEMPLATE")

# Project name + display
if [ -n "$repo_name" ]; then
  content=${content//your-project/$repo_name}
  content=${content//Your Project/$display_name}
fi

# Linear team
if [ -n "$team_key" ]; then
  content=${content//YourTeam/$team_key}
fi
if [ -n "$team_id" ]; then
  content=${content//00000000-0000-0000-0000-000000000000/$team_id}
fi

# Backend (V2 keys row)
if [ -n "$backend" ]; then
  content=$(echo "$content" | awk -v val="$backend" '
    /^\| \*\*Backend\*\*/ { sub(/`vbw` \\\| `native`/, "`" val "`") } 1
  ')
fi

# Integration branch (V2 keys row)
content=$(echo "$content" | awk -v val="$integration_branch" '
  /^\| \*\*Integration branch\*\*/ { sub(/`dev` \\\| `main`/, "`" val "`") } 1
')

# Pre-Deploy Gate block — replace the example pnpm turbo lines if we have detections.
if [ -n "$gate_lines" ]; then
  gate_file=$(mktemp)
  printf '%s' "$gate_lines" > "$gate_file"
  content=$(echo "$content" | awk -v gate_file="$gate_file" '
    BEGIN {
      in_block=0; replaced=0
      while ((getline line < gate_file) > 0) gate = gate line "\n"
      close(gate_file)
    }
    /^## Pre-Deploy Gate/ { in_block=1; print; next }
    in_block && /^```bash/ && !replaced {
      print; printf "%s", gate; replaced=1; skipping=1; next
    }
    skipping && /^```/ { skipping=0; print; in_block=0; next }
    skipping { next }
    { print }
  ')
  rm -f "$gate_file"
fi

echo "$content"
