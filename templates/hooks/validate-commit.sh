#!/bin/bash
set -u
# Pipekit-owned PostToolUse hook: validate git commit message format.
# Non-blocking feedback only (always exit 0). Surfaces an advisory nudge to the
# model when a commit subject does not match {type}({scope}): {desc}.
# Re-homed from the retired VBW plugin (validate-commit.sh) so the nudge in
# .claude/rules + CLAUDE.md survives plugin removal as a Pipekit-owned hook.
#
# Synced to consumers at .claude/hooks/validate-commit.sh by scripts/sync-method.sh.
# Register it in the consuming project's .claude/settings.json:
#   { "hooks": { "PostToolUse": [ { "matcher": "Bash", "hooks": [
#       { "type": "command",
#         "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-commit.sh",
#         "timeout": 10 } ] } ] } }

# Require jq for JSON output — fail-silent if missing (non-blocking hook)
if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only check git commit commands
if ! echo "$COMMAND" | grep -q "git commit"; then
  exit 0
fi

# Extract the SUBJECT line of each REAL `git commit` invocation in the command.
# A "git commit" occurrence only counts when it is an actual invocation —
# command-initial or preceded by a shell operator (; & | ( ) { } ` or newline).
# This rejects the false-positive class where "git commit" appears as DATA:
#   - a grep/search pattern:     grep -m1 "git commit" app.log   (was extracting "1")
#   - embedded in a quoted arg:  printf '... git commit -m "x" ...'
#   - a JSON literal / echo:     echo '{"cmd":"git commit -m ..."}'
# For a real commit, only the FIRST line of its FIRST -m is the subject; everything
# else is body or noise. This also handles, without false-positives:
#   - multi-line -m body:        git commit -m "feat(x): s\n\nbody"
#   - subject + body via two -m: git commit -m "feat(x): s" -m "body paragraph"
#   - chained commits:           git commit -m "fix(a): 1" && git commit -m "fix(b): 2"
# Subject = text up to the first newline or the closing quote (whichever first).
# Commits with no -m (-F-/heredoc/editor) fall through to the heredoc handler below.
SUBJECTS=$(printf '%s\n' "$COMMAND" | awk '
  { buf = buf $0 "\n" }
  END {
    s = buf
    while ((gc = index(s, "git commit")) > 0) {
      pre = substr(s, 1, gc - 1)                  # text before this occurrence
      sub(/[ \t]+$/, "", pre)                     # trim trailing spaces/tabs only
      bc = substr(pre, length(pre), 1)            # char just before "git commit"
      real = (length(pre) == 0 || bc ~ /[;&|(){}`\n]/)  # invocation, not data?
      s = substr(s, gc + 10)                      # past this "git commit"
      ngc = index(s, "git commit")                # bound: next commit in chain
      seg = (ngc > 0) ? substr(s, 1, ngc - 1) : s
      if (real && match(seg, /-m[ \t]+("|'\'')/)) {  # first -m of a real commit
        q = substr(seg, RSTART + RLENGTH - 1, 1)
        rest = substr(seg, RSTART + RLENGTH)
        nl = index(rest, "\n"); cq = index(rest, q)
        if (nl > 0 && (cq == 0 || nl < cq))      end = nl - 1
        else if (cq > 0)                          end = cq - 1
        else                                      end = length(rest)
        print substr(rest, 1, end)
      }
      if (ngc > 0) s = substr(s, ngc); else s = ""
    }
  }')

if [ -z "$SUBJECTS" ] && echo "$COMMAND" | grep -q 'cat <<'; then
  # Heredoc-authored commit (no -m): first non-blank line after the opener.
  SUBJECTS=$(printf '%s\n' "$COMMAND" | sed -n '/cat <</,$ p' | sed '1d' | sed '/^[[:space:]]*$/d' | head -1 | sed 's/^[[:space:]]*//')
fi

[ -z "$SUBJECTS" ] && exit 0

# Validate format: {type}({scope}): {desc} — check each subject, report misses once.
VALID_TYPES="feat|fix|test|refactor|perf|docs|style|chore"
BAD=""
while IFS= read -r subj; do
  [ -z "$subj" ] && continue
  if ! printf '%s' "$subj" | grep -qE "^($VALID_TYPES)\(.+\): .+"; then
    BAD="${BAD}${BAD:+; }${subj}"
  fi
done <<EOF
$SUBJECTS
EOF

if [ -n "$BAD" ]; then
  jq -n --arg msg "$BAD" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": ("Commit message does not match format {type}({scope}): {desc}. Got: " + $msg)
    }
  }'
fi

exit 0
