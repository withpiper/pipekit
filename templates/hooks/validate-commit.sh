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
# command-initial or preceded by a shell operator (; & | ( ) { } ` or newline) AND
# NOT inside a heredoc body. This rejects the false-positive class where
# "git commit" appears as DATA:
#   - a grep/search pattern:     grep -m1 "git commit" app.log   (was extracting "1")
#   - embedded in a quoted arg:  printf '... git commit -m "x" ...'
#   - a JSON literal / echo:     echo '{"cmd":"git commit -m ..."}'
#   - prose/examples in a heredoc body, e.g. documenting commit conventions inside
#     gh pr comment --body "$(cat <<EOF ... git commit -m "feat: x" ... EOF)"
# For a real commit, only the FIRST -m's value (up to the closing quote or end of
# line) is the subject; everything else is body or noise. Also handled cleanly:
#   - subject + body via two -m: git commit -m "feat(x): s" -m "body paragraph"
#   - chained commits:           git commit -m "fix(a): 1" && git commit -m "fix(b): 2"
#   - heredoc-authored commit:   git commit -F- <<EOF ... (first body line = subject)
#   - cmd-subst heredoc commit:  git commit -m "$(cat <<EOF ... )" (first body line = subject;
#     without this the truncated literal `$(cat <<EOF` false-fired the nudge)
# The awk runs line-by-line, tracking heredoc open/close so a body is never scanned
# for invocations — only consumed as the message of a bare `git commit ... <<DELIM`.
SUBJECTS=$(printf '%s\n' "$COMMAND" | awk '
  BEGIN { in_h = 0; want_body = 0; captured = 0 }
  {
    line = $0
    if (in_h) {                                   # inside a heredoc body
      chk = line
      if (h_dash) sub(/^\t+/, "", chk)            # <<- strips leading TABS on the closer
      if (chk == h_delim) { in_h = 0 }
      else if (want_body && captured == 0) {      # heredoc IS the commit message
        t = line; sub(/^[ \t]+/, "", t)
        if (t != "") { print t; captured = 1; want_body = 0 }
      }
      next
    }

    # Not in a heredoc: scan this line for real `git commit` invocations.
    s = line; real_bare = 0; msub = 0
    while ((gc = index(s, "git commit")) > 0) {
      pre = substr(s, 1, gc - 1)                  # text before this occurrence
      sub(/[ \t]+$/, "", pre)                     # trim trailing spaces/tabs only
      bc = substr(pre, length(pre), 1)            # char just before "git commit"
      # Backtick is deliberately NOT an operator here: markdown inline code
      # (`git commit -m ...` in a gh/PR --body string) is common Claude output,
      # while archaic `git commit`-in-backticks cmd-subst is essentially unused.
      # Treating ` as a boundary made doc-prose count as a real invocation and
      # (with a <<EOF elsewhere in the prose) nudge on the next body line.
      real = (length(pre) == 0 || bc ~ /[;&|(){}]/)    # invocation, not data?
      s = substr(s, gc + 10)                      # past this "git commit"
      ngc = index(s, "git commit")                # bound: next commit on this line
      seg = (ngc > 0) ? substr(s, 1, ngc - 1) : s
      if (real) {
        if (match(seg, /-m[ \t]+("|'\'')/)) {     # first -m of a real commit
          q = substr(seg, RSTART + RLENGTH - 1, 1)
          rest = substr(seg, RSTART + RLENGTH)
          cq = index(rest, q)
          if (cq == 0 && rest ~ /\$\(cat[ \t]+<</) {
            msub = 1                              # -m "$(cat <<EOF...)": subject = heredoc line 1
          } else {
            end = (cq > 0) ? cq - 1 : length(rest)  # subject ends at closing quote or EOL
            print substr(rest, 1, end)
          }
        } else {
          real_bare = 1                           # bare commit (no -m): maybe -F- <<EOF
        }
      }
      if (ngc > 0) s = substr(s, ngc); else s = ""
    }

    # Detect a heredoc opener on this line (ignore here-strings `<<<`).
    if (match(line, /<<-?[ \t]*("|'\''|\\)?[A-Za-z_][A-Za-z0-9_]*/)) {
      bef = (RSTART > 1) ? substr(line, RSTART - 1, 1) : ""
      if (bef != "<") {                           # not part of a `<<<` here-string
        op = substr(line, RSTART, RLENGTH)
        h_dash = (substr(op, 3, 1) == "-") ? 1 : 0
        d = op; sub(/^<<-?[ \t]*("|'\''|\\)?/, "", d)
        h_delim = d; in_h = 1; captured = 0
        want_body = ((real_bare || msub) ? 1 : 0) # message from body: bare -F- commits AND -m "$(cat <<EOF)"
      }
    }
  }')

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
