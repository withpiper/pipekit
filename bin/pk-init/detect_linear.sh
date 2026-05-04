#!/usr/bin/env bash
# Emit: linear_team_key, linear_team_id
# If LINEAR_API_KEY (or configured var) is set, query teams via GraphQL.
# Otherwise mark needs_input — user can fill manually or set the key and rerun.
set -euo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel)}"
. "$(dirname "$0")/lib.sh"

key_var="${LINEAR_API_KEY_VAR:-LINEAR_API_KEY}"
key="${!key_var:-}"

if [ -z "$key" ]; then
  out=$(jq -s 'add' \
    <(emit_needs_input linear_team_key '[]' "\$$key_var not set; export it and rerun, or fill manually") \
    <(emit_needs_input linear_team_id  '[]' "\$$key_var not set; export it and rerun, or fill manually"))
  echo "$out"; exit 0
fi

resp=$(curl -sS -X POST https://api.linear.app/graphql \
  -H "Authorization: $key" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ teams { nodes { id key name } } }"}' 2>/dev/null || echo '{}')

teams=$(echo "$resp" | jq -c '.data.teams.nodes // []' 2>/dev/null || echo '[]')
count=$(echo "$teams" | jq 'length')

if [ "$count" = "0" ]; then
  out=$(jq -s 'add' \
    <(emit_missing linear_team_key "Linear API returned no teams") \
    <(emit_missing linear_team_id  "Linear API returned no teams"))
elif [ "$count" = "1" ]; then
  k=$(echo "$teams" | jq -r '.[0].key')
  i=$(echo "$teams" | jq -r '.[0].id')
  out=$(jq -s 'add' \
    <(emit_detected linear_team_key "$k" "Linear API (sole team)") \
    <(emit_detected linear_team_id  "$i" "Linear API (sole team)"))
else
  keys=$(echo "$teams" | jq '[.[].key]')
  ids=$(echo "$teams" | jq '[.[].id]')
  out=$(jq -s 'add' \
    <(emit_needs_input linear_team_key "$keys" "$count teams accessible; pick one") \
    <(emit_needs_input linear_team_id  "$ids"  "$count teams accessible; pick one (must match team_key choice)"))
fi
echo "$out"
