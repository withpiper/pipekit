# pk-init shared helpers — sourced by detect_*.sh and main.sh.
#
# Field shape:
#   detected:    {"status":"detected","value":<x>,"source":"<where>"}
#   needs_input: {"status":"needs_input","candidates":[...],"reason":"<why>"}
#   missing:     {"status":"missing","reason":"<why>"}
#
# Each detect_*.sh prints ONE JSON object: { field: <Field>, ... }.
# main.sh merges them with `jq -s add`.

emit_detected() {
  # $1 field, $2 value (string), $3 source
  jq -n --arg f "$1" --arg v "$2" --arg s "$3" \
    '{($f): {status:"detected", value:$v, source:$s}}'
}

emit_detected_array() {
  # $1 field, $2 JSON array string, $3 source
  jq -n --arg f "$1" --argjson v "$2" --arg s "$3" \
    '{($f): {status:"detected", value:$v, source:$s}}'
}

emit_needs_input() {
  # $1 field, $2 JSON array of candidates, $3 reason
  jq -n --arg f "$1" --argjson c "$2" --arg r "$3" \
    '{($f): {status:"needs_input", candidates:$c, reason:$r}}'
}

emit_missing() {
  # $1 field, $2 reason
  jq -n --arg f "$1" --arg r "$2" \
    '{($f): {status:"missing", reason:$r}}'
}
