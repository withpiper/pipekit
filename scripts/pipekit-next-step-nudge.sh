#!/bin/bash
#
# pipekit-next-step-nudge.sh — opt-in Stop hook that suggests /pipekit-help
# only after pipeline-relevant skills run.
#
# Wire up by adding the following to .claude/settings.local.json:
#
# {
#   "hooks": {
#     "Stop": [
#       {
#         "matcher": "",
#         "hooks": [{"type": "command", "command": "$CLAUDE_PROJECT_DIR/scripts/pipekit-next-step-nudge.sh"}]
#       }
#     ]
#   }
# }
#
# This hook is "scoped" by behavior: it inspects the transcript and stays silent
# unless the most recent assistant turn invoked one of the pipeline skills below.
# It never blocks or modifies output — it only emits a one-line nudge to stderr,
# which Claude Code surfaces back to the model as additional context.
#
# Pipeline skills the nudge cares about (others are intentionally ignored):
#   /work, /verify, /pr-fix, /pr-security-review, /pk-exit,
#   /light-spec, /light-spec-revise, /review-plan, /strategy-sync,
#   /vbw:vibe (any subcommand)
#
# pk subcommands (pk ship, pk done, pk promote) are not currently matched —
# they fire via the Bash tool and the transcript shape differs. Add a Bash-
# command matcher in a follow-up if the heuristic feels too quiet.
#
# Exit 0 always — never break the user's flow if the heuristic misfires.

set -u

# Stop hooks receive JSON on stdin. We read it best-effort; if the format
# changes or the env var is missing, we exit silently.
INPUT="$(cat 2>/dev/null || true)"
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "${TRANSCRIPT_PATH:-}" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# Grab the last ~200 lines of the transcript — enough to cover a single
# assistant turn without scanning the whole session.
RECENT=$(tail -n 200 "$TRANSCRIPT_PATH" 2>/dev/null || true)

if [ -z "$RECENT" ]; then
  exit 0
fi

# Pipeline-skill markers. Match either slash-command invocations or the
# skill-tool invocation name. Conservative — false negatives are fine,
# false positives are not.
if printf '%s' "$RECENT" | grep -E -q -i \
  '(/work|/verify|/pr-fix|/pr-security-review|/pk-exit|/light-spec|/light-spec-revise|/review-plan|/strategy-sync|/vbw:vibe|"skill"[[:space:]]*:[[:space:]]*"(work|verify|pr-fix|pr-security-review|pk-exit|01-light-spec|02-light-spec-revise|review-plan|10-strategy-sync)")' ; then
  echo "Pipeline skill just finished. Run /pipekit-help in a fresh chat to see what's next." >&2
fi

exit 0
