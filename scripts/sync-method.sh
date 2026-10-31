#!/bin/bash
#
# sync-method.sh — Pull method repo content into a consuming project
#
# Usage:
#   ./scripts/sync-method.sh              # Sync from main
#   ./scripts/sync-method.sh v1.0         # Sync from a specific tag/branch
#   ./scripts/sync-method.sh --dry-run    # Show what would change
#   ./scripts/sync-method.sh --auto-install   # After sync, auto-run pk install --force
#                                             # (no prompt) so the global pk stays in
#                                             # lockstep with the synced bin/pk.
#   ./scripts/sync-method.sh --help       # Usage; writes nothing
#
# What it syncs:
#   bin/pk, bin/pk-init/ <- The pk CLI and the config bootstrap `pk init` runs
#   pipekit/sop/        <- SOPs (Code Quality, Git, Linear, Skills)
#   pipekit/templates/  <- Spec and review templates
#   pipekit/method.md   <- The deeper methodology overview
#   <Runbook path>      <- The project runbook (v5.0.0+; `Runbook path` in
#                         method.config.md, default engineering/RUNBOOK.md).
#                         Created from templates/RUNBOOK.skeleton.md when
#                         absent; afterwards ONLY its "How we run" block
#                         (<!-- pipekit:begin … pipekit:end -->) is rewritten
#                         with the method repo's RUNBOOK.md. The "Now" block
#                         (/tpm) and everything else are the project's. The
#                         pre-v5.0.0 copy at pipekit/RUNBOOK.md is removed
#                         once the new file is in place.
#   <Plan path>         <- The weekly plan (v5.1.0+; `Plan path` in
#                         method.config.md, default engineering/WEEKLY_PLAN.md).
#                         /tpm's weekly agreement lives here; the runbook's
#                         "Now" block only points at it. Scaffolded ONCE from
#                         templates/WEEKLY_PLAN.skeleton.md when absent, then
#                         never touched — the whole file is /tpm's. Skipped
#                         when `Plan primary` / `Runbook primary` names a
#                         sibling repo that owns the plan.
#   pipekit/GUIDE.md    <- The full instruction manual
#   pipekit/STARTUP.md  <- The bootstrap reference
#   .claude/workflows/ <- Saved Workflow scripts that skills invoke by name
#                         (pk-execute for /work). Per-file copy; project-local
#                         workflows persist.
#   .claude/skills/    <- Portable skills (won't touch project-specific ones).
#                         A skill listed in the method repo's own
#                         .scaffold-once-skills is seeded once (if absent),
#                         then never touched again — see sop/Skills_SOP.md
#                         § Syncing Portable Skills.
#
# What it does NOT touch:
#   pipekit/decisions/       <- Project-specific ADRs
#   .claude/rules/          <- Project coding conventions
#   .claude/skills/{local}  <- Project-specific skills (incl. retired
#                              scaffold-once skills such as lane-map)
#   method.config.md        <- Project configuration
#   <Runbook path> outside the pipekit:begin/end block
#   <Plan path> once it exists (/tpm regenerates it; sync only scaffolds)
#
# Overrides (sync-safe customization):
#   .claude/overrides/skills/<name>/<file>        <- full-file replacement (any
#                                                   file in the skill dir, e.g.
#                                                   SKILL.md or skill.json)
#   .claude/overrides/sop/<file>.md               <- full-file replacement
#   .claude/overrides/method.md.patch             <- unified diff applied to method.md
#   .claude/overrides/RUNBOOK.md                  <- replaces the "How we run" block body
#   .claude/overrides/.upstream-snapshot/         <- managed by sync; do not edit
#   .claude/overrides/MANIFEST.md                 <- human-curated list (what + why)
#
# Overrides are applied AFTER upstream sync. Drift is surfaced when upstream
# changes a file that has an override — the user must review.

set -euo pipefail

METHOD_REPO="${METHOD_REPO:-https://github.com/withpiper/pipekit.git}"
DRY_RUN=false
AUTO_INSTALL=false
REF="main"
# v2.5.0.1: target is the cwd by default, NOT the script's parent directory.
# Pre-v2.5.0.1, PROJECT_ROOT was derived from $(dirname "$0")/.. which silently
# made absolute-path invocation (bash ~/Projects/pipekit/scripts/sync-method.sh)
# sync INTO the pipekit repo itself. Now we use $PWD (matches the
# `cd <project> && bash <pipekit>/scripts/sync-method.sh` flow) and refuse to
# sync into Pipekit if the cwd's origin matches METHOD_REPO. A consumer's
# v2.5.0 migration surfaced this.
PROJECT_ROOT="${PWD:-$(pwd)}"

usage() {
  cat <<'EOF'
Usage: scripts/sync-method.sh [<ref>] [--dry-run] [--auto-install] [--target=<dir>]

Pull Pipekit (skills, SOPs, templates, rules, workflows, bin/pk) into the
consuming project at the current directory.

  <ref>            tag or branch to sync from (default: main)
  --dry-run        show what would change; write nothing
  --auto-install   after the sync, run pk install --force without prompting
  --target=<dir>   the project to sync into (default: the current directory)
  -h, --help       this text
EOF
}

# Parse flags without mutating $@ — the self-update guard below re-execs with
# "$@", and a shift here would silently drop --dry-run across the re-exec.
# An unknown flag is an error, not a warning: `--help` used to warn and then
# run a full sync into the current directory.
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --auto-install) AUTO_INSTALL=true ;;
    --target=*) PROJECT_ROOT="${arg#--target=}" ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "ERROR: unknown flag: $arg" >&2; usage >&2; exit 2 ;;
    *) REF="$arg" ;;
  esac
done

# Refuse to sync Pipekit into itself. The original v2.5.0 bug: a forgotten
# `cd` left $PWD pointing at the pipekit repo itself, and PROJECT_ROOT
# derived from the script path made absolute-path invocation just as
# dangerous — both would clobber Pipekit's own working tree.
# Detection: compare normalized git origin URL against METHOD_REPO.
if [ -d "$PROJECT_ROOT/.git" ] || [ -f "$PROJECT_ROOT/.git" ]; then
  _norm_url() {
    echo "$1" | sed -E 's#^(https?://|git@)##; s#:#/#; s#\.git$##' | tr 'A-Z' 'a-z'
  }
  _project_origin=$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null || echo "")
  if [ -n "$_project_origin" ] && [ "$(_norm_url "$_project_origin")" = "$(_norm_url "$METHOD_REPO")" ]; then
    echo "ERROR: refusing to sync Pipekit into itself." >&2
    echo "  Target:      $PROJECT_ROOT" >&2
    echo "  Origin:      $_project_origin" >&2
    echo "  Method repo: $METHOD_REPO" >&2
    echo "" >&2
    echo "  This usually means you forgot to 'cd' into your consuming project." >&2
    echo "    cd ~/Projects/<your-project>" >&2
    echo "    bash <path-to-pipekit>/scripts/sync-method.sh $REF" >&2
    echo "" >&2
    echo "  Or run from inside the project with the local sync-method.sh:" >&2
    echo "    cd ~/Projects/<your-project>" >&2
    echo "    bash scripts/sync-method.sh $REF" >&2
    echo "" >&2
    echo "  If you genuinely intend to update Pipekit, edit files in the repo" >&2
    echo "  directly and commit — don't sync Pipekit into itself." >&2
    exit 1
  fi
fi

CHANGELOG="$PROJECT_ROOT/pipekit/.sync-changelog.md"
# Committed manifest of project-specific skills (one name per line, # comments
# allowed). Skills listed here are local-by-design — the sync reports them
# separately instead of flagging them as possibly-removed upstream skills.
LOCAL_MANIFEST="$PROJECT_ROOT/pipekit/.local-skills"

echo "=== Method Sync ==="
echo "Source: $METHOD_REPO @ $REF"
echo "Target: $PROJECT_ROOT"
echo ""

# Clone to temp directory (or reuse one passed from a self-update re-exec)
if [ -n "${SYNC_METHOD_TEMP:-}" ] && [ -d "$SYNC_METHOD_TEMP" ]; then
  TEMP="$SYNC_METHOD_TEMP"
  unset SYNC_METHOD_TEMP
  trap "rm -rf $TEMP" EXIT
  echo "Reusing repo clone from self-update re-exec."
else
  TEMP=$(mktemp -d)
  trap "rm -rf $TEMP" EXIT

  echo "Fetching method repo..."
  git clone --depth 1 --branch "$REF" "$METHOD_REPO" "$TEMP" 2>/dev/null || {
    echo "ERROR: Failed to clone $METHOD_REPO at ref $REF"
    exit 1
  }
fi

# --- Self-update guard: if the upstream sync-method.sh differs from the one we're
# running, install the new version and re-exec with it. This makes single-invocation
# syncs always use the latest logic, even when new files or sync steps are added.
# The SYNC_METHOD_REEXEC flag prevents an infinite re-exec loop.
if [ -z "${SYNC_METHOD_REEXEC:-}" ] && [ -f "$TEMP/scripts/sync-method.sh" ]; then
  SELF_PATH=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")
  if [ -f "$SELF_PATH" ] && ! cmp -s "$TEMP/scripts/sync-method.sh" "$SELF_PATH"; then
    echo ""
    echo "=== sync-method.sh self-update detected — installing and re-execing ==="
    cp "$TEMP/scripts/sync-method.sh" "$SELF_PATH"
    chmod +x "$SELF_PATH"
    export SYNC_METHOD_REEXEC=1
    export SYNC_METHOD_TEMP="$TEMP"
    trap - EXIT   # keep TEMP alive for the re-exec
    exec "$SELF_PATH" "$@"
  fi
fi

# --- Pre-sync: snapshot current state for changelog ---
SNAP=$(mktemp -d)
snapshot_dir() {
  local dir="$1"
  local label="$2"
  if [ -d "$dir" ]; then
    find "$dir" -type f -exec md5sum {} \; 2>/dev/null | sort > "$SNAP/$label.md5"
  else
    touch "$SNAP/$label.md5"
  fi
}

snapshot_dir "$PROJECT_ROOT/.claude/skills" "skills"
snapshot_dir "$PROJECT_ROOT/pipekit" "method"

# Track changes
CHANGES=0
# Fail-closed conditions (a damaged runbook, below). The sync keeps going so
# the rest of the tree still lands, but the final exit status is non-zero.
SYNC_ERRORS=0

# Changelog arrays
NEW_SKILLS=""
UPDATED_SKILLS=""
REMOVED_SKILLS=""
LOCAL_SKILLS=""
UPDATED_FILES=""
NEW_FILES=""

sync_dir() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -d "$src" ]; then
    echo "  SKIP $label (source not found)"
    return
  fi

  mkdir -p "$dst"

  if $DRY_RUN; then
    local diff_count
    # `diff -rq` exits 1 when files differ — that's normal, not an error.
    # Without `|| true`, pipefail propagates the 1 and set -e kills the script.
    diff_count=$({ diff -rq "$src" "$dst" 2>/dev/null || true; } | wc -l | tr -d ' ')
    if [ "$diff_count" -gt 0 ]; then
      echo "  WOULD UPDATE $label ($diff_count files differ)"
      { diff -rq "$src" "$dst" 2>/dev/null || true; } | head -10 | sed 's/^/    /'
      CHANGES=$((CHANGES + diff_count))
    else
      echo "  OK $label (no changes)"
    fi
  else
    rsync -av --delete "$src/" "$dst/" | tail -n +2 | head -20 | sed 's/^/    /'
    echo "  SYNCED $label"
    CHANGES=$((CHANGES + 1))
  fi
}

sync_file() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ ! -f "$src" ]; then
    echo "  SKIP $label (source not found)"
    return
  fi

  if $DRY_RUN; then
    if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "  OK $label (no changes)"
    else
      echo "  WOULD UPDATE $label"
      CHANGES=$((CHANGES + 1))
    fi
  else
    # Idempotent (v2.6.0 #12): skip cp when content matches so unchanged
    # files don't get their mtime bumped. Prevents `git status` noise
    # (and the F3 "bin/pk drift in worktrees" symptom) on no-op syncs.
    if [ -f "$dst" ] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "  OK $label (no changes)"
    else
      cp "$src" "$dst"
      echo "  SYNCED $label"
      CHANGES=$((CHANGES + 1))
    fi
  fi
}

# Read a key's value from the consumer's method.config.md. Handles both config
# forms (mirrors bin/pk's pk_config): `Key: value` inside a fenced code block,
# and table rows `| **Key** | value | ... |`. Prints empty if absent.
config_value() {
  local label="$1"
  local path="$PROJECT_ROOT/method.config.md"
  [ -f "$path" ] || { echo ""; return 0; }
  local value
  value=$(awk -v label="$label" '
    /^```/    { in_fence = !in_fence; next }
    !in_fence { next }
    {
      sub(/^[[:space:]]+/, "")
      pos = index($0, ":")
      if (pos == 0) next
      key = substr($0, 1, pos - 1)
      if (key != label) next
      val = substr($0, pos + 1)
      sub(/^[[:space:]]+/, "", val)
      sub(/[[:space:]]+$/, "", val)
      gsub(/`/, "", val)
      print val
      exit
    }
  ' "$path" 2>/dev/null || true)
  if [ -n "$value" ]; then
    echo "$value"
    return 0
  fi
  local line
  line=$(grep -E "^\| \*\*${label}\*\*" "$path" 2>/dev/null | head -1 || true)
  if [ -n "$line" ]; then
    echo "$line" | awk -F'|' '{print $3}' | sed 's/`//g; s/\*\*//g; s/^ *//; s/ *$//'
    return 0
  fi
  echo ""
}

# --- Sync method docs ---
echo ""
echo "Method docs:"
mkdir -p "$PROJECT_ROOT/pipekit"
sync_dir "$TEMP/sop" "$PROJECT_ROOT/pipekit/sop" "sop/"
sync_dir "$TEMP/templates" "$PROJECT_ROOT/pipekit/templates" "templates/"
sync_file "$TEMP/method.md" "$PROJECT_ROOT/pipekit/method.md" "method.md"
# RUNBOOK.md is no longer copied to pipekit/ — it is composed into the project
# runbook after overrides are known (see "Project runbook" below).
sync_file "$TEMP/GUIDE.md" "$PROJECT_ROOT/pipekit/GUIDE.md" "GUIDE.md"
sync_file "$TEMP/STARTUP.md" "$PROJECT_ROOT/pipekit/STARTUP.md" "STARTUP.md"

# --- Sync Pipekit hook scripts (pipeline lifecycle integration) ---
echo ""
echo "Hook scripts:"
mkdir -p "$PROJECT_ROOT/scripts"
sync_file "$TEMP/scripts/pipekit-next-step-nudge.sh" "$PROJECT_ROOT/scripts/pipekit-next-step-nudge.sh" "scripts/pipekit-next-step-nudge.sh"
[ -f "$PROJECT_ROOT/scripts/pipekit-next-step-nudge.sh" ] && chmod +x "$PROJECT_ROOT/scripts/pipekit-next-step-nudge.sh"
sync_file "$TEMP/scripts/pipekit-state-dir.sh" "$PROJECT_ROOT/scripts/pipekit-state-dir.sh" "scripts/pipekit-state-dir.sh"
[ -f "$PROJECT_ROOT/scripts/pipekit-state-dir.sh" ] && chmod +x "$PROJECT_ROOT/scripts/pipekit-state-dir.sh"
sync_file "$TEMP/scripts/verify-next-md-defer.sh" "$PROJECT_ROOT/scripts/verify-next-md-defer.sh" "scripts/verify-next-md-defer.sh"
[ -f "$PROJECT_ROOT/scripts/verify-next-md-defer.sh" ] && chmod +x "$PROJECT_ROOT/scripts/verify-next-md-defer.sh"
sync_file "$TEMP/scripts/pipekit-configure-repo.sh" "$PROJECT_ROOT/scripts/pipekit-configure-repo.sh" "scripts/pipekit-configure-repo.sh"
[ -f "$PROJECT_ROOT/scripts/pipekit-configure-repo.sh" ] && chmod +x "$PROJECT_ROOT/scripts/pipekit-configure-repo.sh"
# v5.2.2 — the two check scripts below source this to find their package root, so it
# must land first; it is not executable, only sourced.
$DRY_RUN || mkdir -p "$PROJECT_ROOT/scripts/lib"
sync_file "$TEMP/scripts/lib/package-root.sh" "$PROJECT_ROOT/scripts/lib/package-root.sh" "scripts/lib/package-root.sh"
# v4.18.0 — migration-drift detector (gap #1 Tier 2; templates/ci/migration-drift.yml runs it in CI).
sync_file "$TEMP/scripts/check-migration-drift.sh" "$PROJECT_ROOT/scripts/check-migration-drift.sh" "scripts/check-migration-drift.sh"
[ -f "$PROJECT_ROOT/scripts/check-migration-drift.sh" ] && chmod +x "$PROJECT_ROOT/scripts/check-migration-drift.sh"
# v4.18.0 rider — check-no-self-references.sh was invoked by `pk verify` (Self-reference
# check key) and documented as synced, but was never in this list; consumers that enabled
# the key got a silent skip. Now actually synced.
sync_file "$TEMP/scripts/check-no-self-references.sh" "$PROJECT_ROOT/scripts/check-no-self-references.sh" "scripts/check-no-self-references.sh"
[ -f "$PROJECT_ROOT/scripts/check-no-self-references.sh" ] && chmod +x "$PROJECT_ROOT/scripts/check-no-self-references.sh"
# pipekit-journal-hook.sh retired in v2.1.2 — replaced by /pk-exit skill (writes Logs/Sessions/<date>_<HHMM>.md).

# --- Sync v2 bin/pk dispatcher (alpha) ---
# v2 daily-loop runner. Coexists with v1 skills — non-colliding names.
if [ -d "$TEMP/bin" ]; then
  echo ""
  echo "v2 bin/:"
  mkdir -p "$PROJECT_ROOT/bin"
  sync_file "$TEMP/bin/pk" "$PROJECT_ROOT/bin/pk" "bin/pk"
  [ -f "$PROJECT_ROOT/bin/pk" ] && chmod +x "$PROJECT_ROOT/bin/pk"
  # pk init resolves pk-init/main.sh beside the pk binary; without this a
  # synced project could never bootstrap its own method.config.md.
  sync_dir "$TEMP/bin/pk-init" "$PROJECT_ROOT/bin/pk-init" "bin/pk-init/"
  [ -d "$PROJECT_ROOT/bin/pk-init" ] && chmod +x "$PROJECT_ROOT/bin/pk-init/"*.sh 2>/dev/null || true
fi

# --- Sync v2 templates ---
if [ -d "$TEMP/templates/v2" ]; then
  mkdir -p "$PROJECT_ROOT/pipekit/templates/v2"
  sync_dir "$TEMP/templates/v2" "$PROJECT_ROOT/pipekit/templates/v2" "templates/v2/"
fi

# --- Sync canonical .claude/rules/ files ---
# Contract: Pipekit owns five canonical rule files prefixed `pipekit-`
# (pipekit-discipline, pipekit-tooling, pipekit-security, pipekit-migrations,
# pipekit-cmux) plus the README that tells a session the canonical files are sync-owned.
# These get overwritten on every sync — changes must round-trip through
# pipekit.
#
# The `pipekit-` prefix exists specifically to avoid collision with common
# project-specific filenames (security.md, tooling.md are typical names
# consumers use for app-specific rules). Before the prefix, sync would
# silently overwrite project content.
#
# Any OTHER file in .claude/rules/ is untouched (we use sync_file, not
# sync_dir --delete, so project-specific rules like patterns.md, naming.md,
# security.md (project-authored), or {library}-pitfalls.md persist).
#
# v4.21.0 — config-gated opt-out: a `Skip rules` key in method.config.md
# (e.g. `Skip rules: pipekit-cmux, pipekit-migrations`) stops the listed
# canonical rules from syncing and REMOVES them if previously synced. Rules
# are auto-loaded into every session turn, so a rule that opens "if the
# project doesn't use X, this rule is informational" still taxes every turn
# it doesn't apply to. Absent key = all five sync (unchanged behavior).
# README.md (the hub doc) is not skippable; unknown names warn and are
# ignored so a typo can't silently keep a rule the consumer meant to drop.
if [ -d "$TEMP/templates/rules" ]; then
  echo ""
  echo "Canonical rules (.claude/rules/):"
  mkdir -p "$PROJECT_ROOT/.claude/rules"
  SKIP_RULES=$(config_value "Skip rules" | tr ',' ' ' | sed 's/\.md//g')
  for canonical in README.md pipekit-discipline.md pipekit-tooling.md pipekit-security.md pipekit-migrations.md pipekit-cmux.md; do
    base="${canonical%.md}"
    skipped=false
    if [ "$canonical" != "README.md" ]; then
      for s in $SKIP_RULES; do
        [ "$s" = "$base" ] && skipped=true
      done
    fi
    if $skipped; then
      if [ -f "$PROJECT_ROOT/.claude/rules/$canonical" ]; then
        if $DRY_RUN; then
          echo "  WOULD REMOVE .claude/rules/$canonical (skip-listed in method.config.md)"
        else
          rm "$PROJECT_ROOT/.claude/rules/$canonical"
          echo "  REMOVED .claude/rules/$canonical (skip-listed in method.config.md)"
        fi
        CHANGES=$((CHANGES + 1))
      else
        echo "  SKIP .claude/rules/$canonical (skip-listed in method.config.md)"
      fi
      continue
    fi
    if [ -f "$TEMP/templates/rules/$canonical" ]; then
      sync_file "$TEMP/templates/rules/$canonical" "$PROJECT_ROOT/.claude/rules/$canonical" ".claude/rules/$canonical"
    fi
  done
  for s in $SKIP_RULES; do
    case "$s" in
      pipekit-discipline|pipekit-tooling|pipekit-security|pipekit-migrations|pipekit-cmux) ;;
      README|readme|README.md) echo "  WARN: Skip rules cannot skip README.md (the hub doc) — ignored" ;;
      *) [ -n "$s" ] && echo "  WARN: Skip rules entry '$s' is not a canonical rule — ignored (valid: pipekit-discipline, pipekit-tooling, pipekit-security, pipekit-migrations, pipekit-cmux)" ;;
    esac
  done
fi

# --- Sync Pipekit agents (subagents spawned by Pipekit skills) ---
# Per-file copy (sync_file, not sync_dir --delete) so project-local agents
# like code-reviewer, supabase-reviewer, or {library}-pitfalls helpers persist
# across syncs. Mirrors the canonical-rules pattern above. Upstream agents
# are enumerated by what's present in the source tree.
if [ -d "$TEMP/agents" ]; then
  echo ""
  echo "Agents:"
  mkdir -p "$PROJECT_ROOT/.claude/agents"
  for agent_src in "$TEMP/agents"/*.md; do
    [ -f "$agent_src" ] || continue
    name=$(basename "$agent_src")
    sync_file "$agent_src" "$PROJECT_ROOT/.claude/agents/$name" ".claude/agents/$name"
  done
fi

# --- Sync Pipekit workflows (saved Workflow scripts skills invoke by name) ---
# Per-file copy, same pattern as agents, so a project-local workflow persists.
# .claude/workflows/ is a tracked path in consuming projects, which is what
# makes a saved workflow visible inside every pk worktree — the same argument
# as .mcp.json in pipekit-tooling.md § MCP Server Configuration.
if [ -d "$TEMP/workflows" ]; then
  echo ""
  echo "Workflows (.claude/workflows/):"
  mkdir -p "$PROJECT_ROOT/.claude/workflows"
  for wf_src in "$TEMP/workflows"/*.js; do
    [ -f "$wf_src" ] || continue
    name=$(basename "$wf_src")
    sync_file "$wf_src" "$PROJECT_ROOT/.claude/workflows/$name" ".claude/workflows/$name"
  done
fi

# --- Sync canonical .claude/hooks/ + register them ---
# Pipekit owns the advisory commit-format hook: the {type}({scope}): {desc}
# nudge on every commit. Ship the
# script, then idempotently register it in the consumer's committed
# .claude/settings.json. Project-authored hooks + other settings.json content are
# preserved — we append our block only if validate-commit.sh isn't already wired.
if [ -d "$TEMP/templates/hooks" ]; then
  echo ""
  echo "Canonical hooks (.claude/hooks/):"
  mkdir -p "$PROJECT_ROOT/.claude/hooks"
  for hook_src in "$TEMP/templates/hooks"/*.sh; do
    [ -f "$hook_src" ] || continue
    hname=$(basename "$hook_src")
    sync_file "$hook_src" "$PROJECT_ROOT/.claude/hooks/$hname" ".claude/hooks/$hname"
    chmod +x "$PROJECT_ROOT/.claude/hooks/$hname" 2>/dev/null || true
    # The hook is a version-controlled Pipekit artifact, but many projects
    # gitignore .claude/hooks/ (the old "hooks are per-machine" convention).
    # When they do, the shipped hook lands UNcommitted while its registration
    # sits in tracked .claude/settings.json — "wired but not really" for anyone
    # who pulls without running sync. Force-track it so the registration points
    # at a committed script. Non-fatal, dry-run-safe, no-op outside a git repo.
    if ! $DRY_RUN && command -v git >/dev/null 2>&1 \
         && git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1 \
         && git -C "$PROJECT_ROOT" check-ignore -q ".claude/hooks/$hname"; then
      if git -C "$PROJECT_ROOT" add -f ".claude/hooks/$hname" 2>/dev/null; then
        echo "  FORCE-TRACKED .claude/hooks/$hname (.claude/hooks/ is gitignored; committed so the hook reaches the whole repo, not just this machine)"
      else
        echo "  NOTE .claude/hooks/$hname is gitignored and could not be auto-tracked — run: git add -f .claude/hooks/$hname"
      fi
    fi
  done

  # Register validate-commit.sh in .claude/settings.json (idempotent), once
  # PER EVENT: PostToolUse (the advisory nudge) and PreToolUse (denies an
  # off-format `git commit` before it runs, v4.35.0). Consumers registered
  # before v4.35.0 carry only the PostToolUse entry, so the guard is per-event —
  # a single "already registered anywhere" check would leave PreToolUse
  # unwired on every existing consumer forever.
  SETTINGS="$PROJECT_ROOT/.claude/settings.json"
  HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/validate-commit.sh'
  if [ -f "$TEMP/templates/hooks/validate-commit.sh" ]; then
    if ! command -v jq >/dev/null 2>&1; then
      echo "  NOTE jq not found — register the commit-format hook in .claude/settings.json manually (snippet in templates/hooks/validate-commit.sh header)."
    elif [ -f "$SETTINGS" ] && ! jq empty "$SETTINGS" >/dev/null 2>&1; then
      echo "  NOTE .claude/settings.json is not valid JSON — register the commit-format hook manually."
    else
      for hook_event in PreToolUse PostToolUse; do
        if [ -f "$SETTINGS" ] && jq -e --arg ev "$hook_event" '
              [(.hooks[$ev] // [])[] | .hooks[]? | .command? // empty]
              | any(type=="string" and test("validate-commit\\.sh"))
            ' "$SETTINGS" >/dev/null 2>&1; then
          echo "  OK validate-commit.sh already registered ($hook_event) in .claude/settings.json"
        elif $DRY_RUN; then
          echo "  WOULD REGISTER validate-commit.sh ($hook_event) in .claude/settings.json"
          CHANGES=$((CHANGES + 1))
        else
          [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
          tmp=$(mktemp)
          if jq --arg cmd "$HOOK_CMD" --arg ev "$hook_event" '
                (.hooks //= {})
                | (.hooks[$ev] //= [])
                | .hooks[$ev] += [{matcher:"Bash",hooks:[{type:"command",command:$cmd,timeout:10}]}]
              ' "$SETTINGS" > "$tmp" 2>/dev/null && mv "$tmp" "$SETTINGS"; then
            echo "  REGISTERED validate-commit.sh ($hook_event) in .claude/settings.json"
            CHANGES=$((CHANGES + 1))
          else
            rm -f "$tmp"
            echo "  NOTE could not auto-register validate-commit.sh ($hook_event) — add it to .claude/settings.json manually."
          fi
        fi
      done
    fi
  fi
fi

# --- Sync portable skills ---
echo ""
echo "Portable skills:"

# Get list of portable skills from method repo
PORTABLE_SKILLS=$(ls -d "$TEMP/skills/"*/ 2>/dev/null | xargs -I{} basename {})

# Scaffold-once skills: declared by the METHOD repo (not the consuming
# project — contrast with $LOCAL_MANIFEST below), in the freshly-cloned
# $TEMP, one name per line. Seeded into the project once, if absent; never
# touched again once present. See sop/Skills_SOP.md § Syncing Portable
# Skills.
SCAFFOLD_ONCE_MANIFEST="$TEMP/.scaffold-once-skills"
is_scaffold_once() {
  [ -f "$SCAFFOLD_ONCE_MANIFEST" ] && grep -qx "$1" "$SCAFFOLD_ONCE_MANIFEST" 2>/dev/null
}

# Retired skills (v5.0.0): a scaffold-once skill that has left the method
# repo. The consumer's copy is theirs — curation and all — and they remove it
# when they choose. The loop below never visits a name absent upstream and
# never prunes, so plain upstream removal is already safe; this list closes
# the window where upstream still ships the directory but no longer declares
# it scaffold-once (which would resync over the curated copy), and keeps the
# changelog from flagging the skill as "not in upstream".
RETIRED_SKILLS="lane-map"
is_retired() {
  local s
  for s in $RETIRED_SKILLS; do [ "$s" = "$1" ] && return 0; done
  return 1
}

# Skills upstream renamed (the numbered dirs: the registered command is the
# directory name, so `/01-light-spec` and `/light-spec` would both exist) or
# retired outright. A consumer's copy came from a sync, so it goes — unless
# pipekit/.local-skills declares it project-owned, in which case it stays and
# is reported like any other local skill.
UPSTREAM_REMOVED_SKILLS="00-roadmap-review 01-light-spec 02-light-spec-revise 10-strategy-sync 06-linear-todo-runner task-processor skill-index spec-validator launch launch-native branch end-session start-session linear-status"
RETIRED_REMOVED=""

for s in $UPSTREAM_REMOVED_SKILLS; do
  [ -d "$PROJECT_ROOT/.claude/skills/$s" ] || continue
  if grep -qx "$s" "$LOCAL_MANIFEST" 2>/dev/null; then
    echo "  KEEP skill: $s (retired upstream; declared project-local)"
    continue
  fi
  if $DRY_RUN; then
    echo "  WOULD REMOVE skill: $s (retired or renamed upstream)"
  else
    rm -rf "${PROJECT_ROOT:?}/.claude/skills/$s"
    echo "  REMOVED skill: $s (retired or renamed upstream)"
    RETIRED_REMOVED="$RETIRED_REMOVED $s"
  fi
  CHANGES=$((CHANGES + 1))
done

for skill in $PORTABLE_SKILLS; do
  src="$TEMP/skills/$skill"
  dst="$PROJECT_ROOT/.claude/skills/$skill"

  if [ ! -d "$src" ]; then
    continue
  fi

  if is_retired "$skill"; then
    echo "  SKIP skill: $skill (retired upstream; the local copy is project-owned)"
    continue
  fi

  if is_scaffold_once "$skill"; then
    if [ -d "$dst" ]; then
      echo "  OK skill: $skill (scaffold-once, local — not touched)"
    elif $DRY_RUN; then
      echo "  WOULD SCAFFOLD skill: $skill (once, then local)"
      CHANGES=$((CHANGES + 1))
    else
      mkdir -p "$dst"
      rsync -av "$src/" "$dst/" >/dev/null 2>&1
      echo "  SCAFFOLDED skill: $skill (once, then local)"
      NEW_SKILLS="$NEW_SKILLS $skill"
      CHANGES=$((CHANGES + 1))
    fi
    # Declare it local from here on, so future syncs' "possibly
    # upstream-removed" check (below) treats it as project-owned and the
    # sync changelog reports it under "Project-local".
    if ! $DRY_RUN && [ -d "$dst" ]; then
      mkdir -p "$(dirname "$LOCAL_MANIFEST")" 2>/dev/null || true
      touch "$LOCAL_MANIFEST" 2>/dev/null || true
      grep -qx "$skill" "$LOCAL_MANIFEST" 2>/dev/null || echo "$skill" >> "$LOCAL_MANIFEST"
    fi
    continue
  fi

  # Track new vs updated
  if [ ! -d "$dst" ]; then
    NEW_SKILLS="$NEW_SKILLS $skill"
  elif ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
    UPDATED_SKILLS="$UPDATED_SKILLS $skill"
  fi

  mkdir -p "$dst"

  # Case migration (v4.22.0): upstream renamed skill.md → SKILL.md. A plain
  # copy can't apply a case-only rename on case-insensitive filesystems (and
  # git with core.ignorecase misses a disk-level rename entirely), so migrate
  # explicitly — git mv when tracked, plain mv otherwise. `ls | grep -x` reads
  # the true on-disk name; a stat-based [ -f ] test can't distinguish case.
  if ls "$dst" 2>/dev/null | grep -qx 'skill.md'; then
    if $DRY_RUN; then
      echo "  WOULD RENAME skill: $skill (skill.md → SKILL.md)"
      CHANGES=$((CHANGES + 1))
    else
      rel_dst="${dst#$PROJECT_ROOT/}"
      if git -C "$PROJECT_ROOT" ls-files --error-unmatch "$rel_dst/skill.md" >/dev/null 2>&1; then
        git -C "$PROJECT_ROOT" mv -f "$rel_dst/skill.md" "$rel_dst/SKILL.md" 2>/dev/null \
          || mv "$dst/skill.md" "$dst/SKILL.md"
      else
        mv "$dst/skill.md" "$dst/SKILL.md"
      fi
      echo "  RENAMED skill: $skill (skill.md → SKILL.md)"
    fi
  fi

  if $DRY_RUN; then
    if [ -d "$dst" ]; then
      diff_count=$({ diff -rq "$src" "$dst" 2>/dev/null || true; } | wc -l | tr -d ' ')
      if [ "$diff_count" -gt 0 ]; then
        echo "  WOULD UPDATE skill: $skill"
        CHANGES=$((CHANGES + 1))
      else
        echo "  OK skill: $skill"
      fi
    else
      echo "  WOULD CREATE skill: $skill"
      CHANGES=$((CHANGES + 1))
    fi
  else
    rsync -av "$src/" "$dst/" >/dev/null 2>&1
    echo "  SYNCED skill: $skill"
    CHANGES=$((CHANGES + 1))
  fi
done

# Check for skills that exist locally but not in the method repo. The committed
# manifest (pipekit/.local-skills) declares which are project-specific by
# design; anything undeclared is flagged — upstream removed/renamed it, or it's
# a local skill that should be declared. Replaces the pre-v3.0.1 check, which
# flagged every local skill (`grep -qv` against the multi-line skill list is
# true whenever any other skill exists) and leaned on .sync-changelog.md
# history that v2.8.0-rc1 made transient by gitignoring the file.
if [ -d "$PROJECT_ROOT/.claude/skills" ]; then
  for existing_skill_dir in "$PROJECT_ROOT/.claude/skills"/*/; do
    existing_skill=$(basename "$existing_skill_dir")
    if [ ! -d "$TEMP/skills/$existing_skill" ] && { [ -f "$existing_skill_dir/SKILL.md" ] || [ -f "$existing_skill_dir/skill.md" ]; }; then
      if is_retired "$existing_skill" || { [ -f "$LOCAL_MANIFEST" ] && grep -qx "$existing_skill" "$LOCAL_MANIFEST" 2>/dev/null; }; then
        LOCAL_SKILLS="$LOCAL_SKILLS $existing_skill"
      else
        REMOVED_SKILLS="$REMOVED_SKILLS $existing_skill"
      fi
    fi
  done
fi

# --- Sync scripts ---
echo ""
echo "Scripts:"
sync_file "$TEMP/scripts/drift-check.sh" "$PROJECT_ROOT/scripts/drift-check.sh" "drift-check.sh"
# Also update the sync script itself
sync_file "$TEMP/scripts/sync-method.sh" "$PROJECT_ROOT/scripts/sync-method.sh" "sync-method.sh"
# Make scripts executable
for script in drift-check.sh sync-method.sh; do
  if [ -f "$PROJECT_ROOT/scripts/$script" ]; then
    chmod +x "$PROJECT_ROOT/scripts/$script"
  fi
done

# --- Apply overrides ---
# Project-local overrides live under .claude/overrides/. After upstream sync,
# we replay full-file overrides for skills/sop and apply method.md.patch.
# We snapshot the upstream version we replaced so the *next* sync can detect
# upstream drift on overridden files.
OVERRIDES_DIR="$PROJECT_ROOT/.claude/overrides"
OVERRIDE_SNAPSHOT="$OVERRIDES_DIR/.upstream-snapshot"
OVERRIDES_APPLIED=""
OVERRIDE_DRIFT=""

apply_override() {
  # $1 = override file path (under OVERRIDES_DIR)
  # $2 = target file path (in project)
  # $3 = label for output
  local override="$1"
  local target="$2"
  local label="$3"

  if [ ! -f "$target" ]; then
    echo "  SKIP override $label (target missing: $target)"
    return
  fi

  local rel="${override#$OVERRIDES_DIR/}"
  local snap_path="$OVERRIDE_SNAPSHOT/$rel"
  mkdir -p "$(dirname "$snap_path")"

  # Drift check: if a previous snapshot exists and doesn't match the upstream
  # version we just synced, upstream changed underneath the override.
  if [ -f "$snap_path" ] && ! cmp -s "$snap_path" "$target"; then
    OVERRIDE_DRIFT="$OVERRIDE_DRIFT $label"
    echo "  ⚠ DRIFT $label — upstream changed; review override against new upstream"
  fi

  if $DRY_RUN; then
    echo "  WOULD OVERRIDE $label"
    # Record in dry-run too, or the summary below contradicts the lines just
    # printed with "(no overrides found)" — the one report a --dry-run user is
    # reading to confirm their overrides are wired up.
    OVERRIDES_APPLIED="$OVERRIDES_APPLIED $label"
  else
    # Snapshot the upstream version BEFORE overwriting it.
    cp "$target" "$snap_path"
    cp "$override" "$target"
    echo "  OVERRIDE $label"
    OVERRIDES_APPLIED="$OVERRIDES_APPLIED $label"
  fi
}

apply_patch_override() {
  # $1 = patch file (under OVERRIDES_DIR)
  # $2 = target file (in project)
  # $3 = label
  local patch_file="$1"
  local target="$2"
  local label="$3"

  if [ ! -f "$target" ]; then
    echo "  SKIP patch $label (target missing: $target)"
    return
  fi

  local rel="${patch_file#$OVERRIDES_DIR/}"
  local snap_path="$OVERRIDE_SNAPSHOT/$rel.target"
  mkdir -p "$(dirname "$snap_path")"

  # Drift check on patches: compare new upstream target to last-known upstream.
  if [ -f "$snap_path" ] && ! cmp -s "$snap_path" "$target"; then
    OVERRIDE_DRIFT="$OVERRIDE_DRIFT $label"
    echo "  ⚠ DRIFT $label — upstream changed; patch may not apply cleanly"
  fi

  if $DRY_RUN; then
    echo "  WOULD PATCH $label"
    OVERRIDES_APPLIED="$OVERRIDES_APPLIED $label"
    return
  fi

  # Snapshot upstream BEFORE patching.
  cp "$target" "$snap_path"

  # Apply patch. Use --dry-run first to fail loud rather than half-apply.
  if patch --dry-run -p1 -d "$(dirname "$target")" -i "$patch_file" >/dev/null 2>&1; then
    patch -p1 -d "$(dirname "$target")" -i "$patch_file" >/dev/null
    echo "  PATCHED $label"
    OVERRIDES_APPLIED="$OVERRIDES_APPLIED $label"
  else
    echo "  ✗ PATCH FAILED $label — upstream diverged from patch context."
    echo "    Inspect: $patch_file"
    echo "    Upstream snapshot: $snap_path"
    echo "    Sync continuing; resolve patch manually before next sync."
  fi
}

if [ -d "$OVERRIDES_DIR" ]; then
  echo ""
  echo "Overrides:"

  # Skill overrides: .claude/overrides/skills/<name>/<any file>
  if [ -d "$OVERRIDES_DIR/skills" ]; then
    while IFS= read -r -d '' override_file; do
      skill_name=$(basename "$(dirname "$override_file")")
      override_base=$(basename "$override_file")
      # Legacy lowercase override names keep targeting the renamed file.
      [ "$override_base" = "skill.md" ] && override_base="SKILL.md"
      target="$PROJECT_ROOT/.claude/skills/$skill_name/$override_base"
      apply_override "$override_file" "$target" "skills/$skill_name/$override_base"
      # NOT -name '*.md'. A skill directory is more than its SKILL.md: skill.json
      # carries the `description` Claude routes on, so a project that pins a skill
      # to a redirect stub via SKILL.md had the json silently reverted to upstream
      # on every sync — the guard held in prose and leaked in metadata. Dotfiles
      # stay excluded (.DS_Store would just log a missing-target SKIP).
    done < <(find "$OVERRIDES_DIR/skills" -type f ! -name '.*' -print0 2>/dev/null)
  fi

  # SOP overrides: .claude/overrides/sop/<file>.md
  if [ -d "$OVERRIDES_DIR/sop" ]; then
    while IFS= read -r -d '' override_file; do
      target="$PROJECT_ROOT/pipekit/sop/$(basename "$override_file")"
      apply_override "$override_file" "$target" "sop/$(basename "$override_file")"
    done < <(find "$OVERRIDES_DIR/sop" -type f -name '*.md' -print0 2>/dev/null)
  fi

  # method.md patch
  if [ -f "$OVERRIDES_DIR/method.md.patch" ]; then
    apply_patch_override \
      "$OVERRIDES_DIR/method.md.patch" \
      "$PROJECT_ROOT/pipekit/method.md" \
      "method.md.patch"
  fi

  if [ -z "$OVERRIDES_APPLIED" ] && [ -z "$OVERRIDE_DRIFT" ]; then
    echo "  (no overrides found)"
  fi
fi

# --- Project runbook (v5.0.0) + weekly plan (v5.1.0) ---
# One runbook per consumer at `Runbook path` (method.config.md; default
# engineering/RUNBOOK.md), three regions, three owners:
#   ## Now         <!-- tpm:begin … tpm:end -->          written by /tpm
#   ## Notes       free text                              the project's
#   ## How we run  <!-- pipekit:begin … pipekit:end -->  this script
# Since v5.1.0 the Now block is a one-line pointer: the week's agreement
# itself lives in the weekly plan at `Plan path` (default
# engineering/WEEKLY_PLAN.md), a file /tpm owns outright. This step
# scaffolds that file once (below, after the runbook) and never touches it
# again.
# Absent, the runbook is created from templates/RUNBOOK.skeleton.md (its Now
# body names the plan path). Present, ONLY the pipekit block is rewritten —
# begin line inclusive, so the version stamp moves. Anything else in the file
# (the tpm block, Notes, extra sections) is never read, let alone written.
# Damaged markers fail closed: the file is left alone, the error goes to
# stderr, and the script exits non-zero at the end. .claude/overrides/RUNBOOK.md
# replaces the block body, drift-checked against the upstream snapshot exactly
# like apply_override. Runs after the overrides step so the body source is
# settled, and before the method.config.md template copy so a fresh consumer's
# heading is its repo name rather than the template's placeholder.
RUNBOOK_REL=$(config_value "Runbook path")
[ -n "$RUNBOOK_REL" ] || RUNBOOK_REL="engineering/RUNBOOK.md"
case "$RUNBOOK_REL" in
  /*) RUNBOOK_PATH="$RUNBOOK_REL" ;;
  *)  RUNBOOK_PATH="$PROJECT_ROOT/$RUNBOOK_REL" ;;
esac
RUNBOOK_SKELETON="$TEMP/templates/RUNBOOK.skeleton.md"
PLAN_REL=$(config_value "Plan path")
[ -n "$PLAN_REL" ] || PLAN_REL="engineering/WEEKLY_PLAN.md"
# `none`: the project keeps no weekly plan — nothing scaffolded, and the
# runbook's Now block says so instead of pointing at a file.
case "$PLAN_REL" in
  none) PLAN_PATH="" ;;
  /*)   PLAN_PATH="$PLAN_REL" ;;
  *)    PLAN_PATH="$PROJECT_ROOT/$PLAN_REL" ;;
esac
PLAN_SKELETON="$TEMP/templates/WEEKLY_PLAN.skeleton.md"
LEGACY_RUNBOOK="$PROJECT_ROOT/pipekit/RUNBOOK.md"
RB_BEGIN_RE='^<!-- pipekit:begin'
RB_END_RE='^<!-- pipekit:end'

# Replace every occurrence of placeholder $2 in $1 with $3, literally. Not
# ${s//p/r}: bash 5.2's patsub_replacement expands an unquoted `&` in the
# replacement, and the quoted form is rejected by bash 3.2.
rb_subst() {
  local s="$1" p="$2" r="$3" out=""
  while case "$s" in *"$p"*) true ;; *) false ;; esac; do
    out="$out${s%%"$p"*}$r"
    s="${s#*"$p"}"
  done
  printf '%s' "$out$s"
}

# cat $1 with a guaranteed trailing newline, so the end marker is on its own line.
rb_cat_nl() {
  cat "$1"
  if [ -n "$(tail -c1 "$1")" ]; then echo; fi
}

echo ""
echo "Project runbook ($RUNBOOK_REL):"
if [ ! -f "$TEMP/RUNBOOK.md" ] || [ ! -f "$RUNBOOK_SKELETON" ]; then
  echo "  SKIP runbook (source not found)"
else
  # Version stamp: bin/pk is the release's source of truth; the RUNBOOK.md
  # header stamp covers a tree without bin/.
  RB_VERSION=$(grep -m1 '^PK_VERSION=' "$TEMP/bin/pk" 2>/dev/null | sed 's/^PK_VERSION="*\([^"]*\)"*$/\1/' || true)
  [ -n "$RB_VERSION" ] || RB_VERSION=$(grep -o -m1 '^\*\*v[0-9][^*]*\*\*' "$TEMP/RUNBOOK.md" 2>/dev/null | sed 's/^\*\*v//; s/\*\*$//' || true)
  [ -n "$RB_VERSION" ] || RB_VERSION="unknown"

  # Heading: the display name reads best; fall back to the slug, then the dir.
  RB_NAME=$(config_value "Project display name")
  [ -n "$RB_NAME" ] || RB_NAME=$(config_value "Project name")
  [ -n "$RB_NAME" ] || RB_NAME=$(basename "$PROJECT_ROOT")

  # Block body: the override wins, with apply_override's drift semantics —
  # the snapshot is the upstream the override last stood in for.
  RB_BODY="$TEMP/RUNBOOK.md"
  RB_OVERRIDE="$OVERRIDES_DIR/RUNBOOK.md"
  if [ -f "$RB_OVERRIDE" ]; then
    if [ -f "$OVERRIDE_SNAPSHOT/RUNBOOK.md" ] && ! cmp -s "$OVERRIDE_SNAPSHOT/RUNBOOK.md" "$TEMP/RUNBOOK.md"; then
      OVERRIDE_DRIFT="$OVERRIDE_DRIFT RUNBOOK.md"
      echo "  ⚠ DRIFT RUNBOOK.md — upstream changed; review override against new upstream"
    fi
    if $DRY_RUN; then
      echo "  WOULD OVERRIDE RUNBOOK.md (How we run block body)"
    else
      echo "  OVERRIDE RUNBOOK.md (How we run block body)"
    fi
    OVERRIDES_APPLIED="$OVERRIDES_APPLIED RUNBOOK.md"
    RB_BODY="$RB_OVERRIDE"
  fi

  # The begin line lives in the skeleton only, so the stamp format has one home.
  rb_begin_line=$(grep -m1 "$RB_BEGIN_RE" "$RUNBOOK_SKELETON" || true)
  rb_begin_line=$(rb_subst "$rb_begin_line" '{{PK_VERSION}}' "$RB_VERSION")
  rb_end_line=$(grep -m1 "$RB_END_RE" "$RUNBOOK_SKELETON" || true)

  rb_render_block() {
    printf '%s\n' "$rb_begin_line"
    rb_cat_nl "$RB_BODY"
    printf '%s\n' "$rb_end_line"
  }
  rb_render_new() {
    local line
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        '<!-- pipekit:begin'*|'<!-- pipekit:end'*) ;;   # emitted with the body
        '{{PIPEKIT_BODY}}') rb_render_block ;;
        *)
          line=$(rb_subst "$line" '{{PROJECT_NAME}}' "$RB_NAME")
          line=$(rb_subst "$line" '{{PK_VERSION}}' "$RB_VERSION")
          if [ "$PLAN_REL" = "none" ]; then
            case "$line" in *'{{PLAN_PATH}}'*) line='_(no weekly plan on this project — `Plan path: none`)_' ;; esac
          else
            line=$(rb_subst "$line" '{{PLAN_PATH}}' "$PLAN_REL")
          fi
          printf '%s\n' "$line" ;;
      esac
    done < "$RUNBOOK_SKELETON"
  }
  plan_render_new() {
    local line
    while IFS= read -r line || [ -n "$line" ]; do
      line=$(rb_subst "$line" '{{PROJECT_NAME}}' "$RB_NAME")
      printf '%s\n' "$line"
    done < "$PLAN_SKELETON"
  }
  rb_render_update() {   # $1 = existing file, $2/$3 = begin/end line numbers
    if [ "$2" -gt 1 ]; then sed -n "1,$(($2 - 1))p" "$1"; fi
    rb_render_block
    tail -n +"$(($3 + 1))" "$1"
  }

  # Pre-write hash so the changelog's doc loop can see the runbook change
  # (the pipekit/ snapshot above doesn't cover this path).
  if [ -f "$RUNBOOK_PATH" ]; then
    md5sum "$RUNBOOK_PATH" 2>/dev/null >> "$SNAP/method.md5" || true
  fi

  rb_new=$(mktemp)
  rb_status=""
  if [ ! -f "$RUNBOOK_PATH" ]; then
    rb_render_new > "$rb_new"
    rb_status=create
  else
    nb=$(grep -c "$RB_BEGIN_RE" "$RUNBOOK_PATH" || true)
    ne=$(grep -c "$RB_END_RE" "$RUNBOOK_PATH" || true)
    lb=$(grep -n -m1 "$RB_BEGIN_RE" "$RUNBOOK_PATH" | cut -d: -f1 || true)
    le=$(grep -n -m1 "$RB_END_RE" "$RUNBOOK_PATH" | cut -d: -f1 || true)
    if [ "$nb" -eq 1 ] && [ "$ne" -eq 1 ] && [ "$lb" -lt "$le" ]; then
      rb_render_update "$RUNBOOK_PATH" "$lb" "$le" > "$rb_new"
      if cmp -s "$rb_new" "$RUNBOOK_PATH"; then rb_status=ok; else rb_status=update; fi
    else
      rb_status=error
    fi
  fi

  case "$rb_status" in
    error)
      echo "ERROR: runbook markers damaged in $RUNBOOK_REL — not written; restore the markers or delete the file to re-create it" >&2
      SYNC_ERRORS=$((SYNC_ERRORS + 1)) ;;
    ok)
      echo "  OK $RUNBOOK_REL (How we run block unchanged)" ;;
    create)
      if $DRY_RUN; then
        echo "  WOULD CREATE $RUNBOOK_REL"
      else
        mkdir -p "$(dirname "$RUNBOOK_PATH")"
        cp "$rb_new" "$RUNBOOK_PATH"
        echo "  CREATED $RUNBOOK_REL"
      fi
      CHANGES=$((CHANGES + 1)) ;;
    update)
      if $DRY_RUN; then
        echo "  WOULD UPDATE block in $RUNBOOK_REL (How we run)"
      else
        cp "$rb_new" "$RUNBOOK_PATH"
        echo "  UPDATED $RUNBOOK_REL (How we run block)"
      fi
      CHANGES=$((CHANGES + 1)) ;;
  esac
  rm -f "$rb_new"

  # Snapshot the upstream the override stood in for — only once it actually did.
  if ! $DRY_RUN && [ "$rb_status" != error ] && [ -f "$RB_OVERRIDE" ]; then
    mkdir -p "$OVERRIDE_SNAPSHOT"
    cp "$TEMP/RUNBOOK.md" "$OVERRIDE_SNAPSHOT/RUNBOOK.md"
  fi

  # Migration: the pre-v5.0.0 copy goes once the new file is in place.
  if [ "$rb_status" != error ] && [ -f "$LEGACY_RUNBOOK" ] && [ "$LEGACY_RUNBOOK" != "$RUNBOOK_PATH" ]; then
    if $DRY_RUN; then
      echo "  WOULD MIGRATE pipekit/RUNBOOK.md → $RUNBOOK_REL (How we run block)"
    else
      rm "$LEGACY_RUNBOOK"
      echo "  MIGRATED pipekit/RUNBOOK.md → $RUNBOOK_REL (How we run block)"
    fi
    CHANGES=$((CHANGES + 1))
  fi

  # --- Weekly plan (v5.1.0) ---
  # Scaffolded once from templates/WEEKLY_PLAN.skeleton.md; an existing plan is
  # never read or written — the whole file is /tpm's. A sibling repo that names
  # a `Plan primary` (or, pre-5.1.0, a `Runbook primary`) reads that repo's
  # plan and gets none of its own.
  if [ -f "$PLAN_PATH" ]; then
    md5sum "$PLAN_PATH" 2>/dev/null >> "$SNAP/method.md5" || true
  fi
  echo ""
  echo "Weekly plan ($PLAN_REL):"
  PLAN_PRIMARY=$(config_value "Plan primary")
  [ -n "$PLAN_PRIMARY" ] || PLAN_PRIMARY=$(config_value "Runbook primary")
  if [ "$PLAN_REL" = "none" ]; then
    echo "  SKIP weekly plan (Plan path: none)"
  elif [ -n "$PLAN_PRIMARY" ]; then
    echo "  SKIP $PLAN_REL (plan lives in $PLAN_PRIMARY)"
  elif [ ! -f "$PLAN_SKELETON" ]; then
    echo "  SKIP $PLAN_REL (source not found)"
  elif [ -f "$PLAN_PATH" ]; then
    echo "  OK $PLAN_REL (owned by /tpm, not touched)"
  elif $DRY_RUN; then
    echo "  WOULD CREATE $PLAN_REL"
    CHANGES=$((CHANGES + 1))
  else
    mkdir -p "$(dirname "$PLAN_PATH")"
    plan_render_new > "$PLAN_PATH"
    echo "  CREATED $PLAN_REL"
    CHANGES=$((CHANGES + 1))
  fi
fi

# --- Check for method.config.md ---
echo ""
if [ ! -f "$PROJECT_ROOT/method.config.md" ]; then
  if $DRY_RUN; then
    echo "NOTE: method.config.md not found. Would copy template."
  else
    cp "$TEMP/method.config.template.md" "$PROJECT_ROOT/method.config.md"
    echo "CREATED method.config.md from template — fill in your project values!"
  fi
fi

# --- Post-sync: generate changelog ---
if ! $DRY_RUN; then
  # Compare method files. The runbook and the weekly plan live at their own
  # paths, hashed into the same snapshot just before they were written.
  for f in method.md GUIDE.md STARTUP.md "$RUNBOOK_REL" "$PLAN_REL"; do
    [ "$f" = "none" ] && continue
    case "$f" in
      "$RUNBOOK_REL") dst="$RUNBOOK_PATH" ;;
      "$PLAN_REL")    dst="$PLAN_PATH" ;;
      *)              dst="$PROJECT_ROOT/pipekit/$f" ;;
    esac
    if [ -f "$dst" ]; then
      old_hash=$(grep "$dst" "$SNAP/method.md5" 2>/dev/null | awk '{print $1}' || true)
      new_hash=$(md5sum "$dst" 2>/dev/null | awk '{print $1}')
      if [ "$old_hash" != "$new_hash" ]; then
        UPDATED_FILES="$UPDATED_FILES $f"
      fi
    fi
  done

  # Write changelog
  SYNC_DATE=$(date '+%Y-%m-%d %H:%M')
  cat > "$CHANGELOG" << CHLOG
# Sync Changelog

**Synced:** $SYNC_DATE
**Source:** $METHOD_REPO @ $REF

## Skills

CHLOG

  if [ -n "$NEW_SKILLS" ]; then
    echo "### New" >> "$CHANGELOG"
    for s in $NEW_SKILLS; do
      desc=""
      sf="$PROJECT_ROOT/.claude/skills/$s/SKILL.md"
      [ -f "$sf" ] || sf="$PROJECT_ROOT/.claude/skills/$s/skill.md"
      if [ -f "$sf" ]; then
        # `|| true`: under pipefail a SKILL.md with no description: line made
        # this assignment fail and set -e killed the sync mid-changelog.
        desc=$(grep '^description:' "$sf" 2>/dev/null | head -1 | sed 's/^description: *//' || true)
      fi
      echo "- \`/$s\` — $desc" >> "$CHANGELOG"
    done
    echo "" >> "$CHANGELOG"
  fi

  if [ -n "$UPDATED_SKILLS" ]; then
    echo "### Updated" >> "$CHANGELOG"
    for s in $UPDATED_SKILLS; do
      echo "- \`/$s\`" >> "$CHANGELOG"
    done
    echo "" >> "$CHANGELOG"
  fi

  if [ -n "$LOCAL_SKILLS" ]; then
    echo "### Project-local (declared in pipekit/.local-skills)" >> "$CHANGELOG"
    for s in $LOCAL_SKILLS; do
      echo "- \`/$s\`" >> "$CHANGELOG"
    done
    echo "" >> "$CHANGELOG"
  fi

  if [ -n "$RETIRED_REMOVED" ]; then
    echo "### Removed (retired or renamed upstream)" >> "$CHANGELOG"
    for s in $RETIRED_REMOVED; do
      echo "- \`/$s\`" >> "$CHANGELOG"
    done
    echo "" >> "$CHANGELOG"
  fi

  if [ -n "$REMOVED_SKILLS" ]; then
    echo "### Not in upstream (undeclared)" >> "$CHANGELOG"
    for s in $REMOVED_SKILLS; do
      echo "- \`/$s\` — exists locally but not in the method repo and is not declared in \`pipekit/.local-skills\`. If project-specific by design, declare it; if it was a portable skill, upstream removed or renamed it (check the method repo's CHANGELOG and \`archive/\`)." >> "$CHANGELOG"
    done
    echo "" >> "$CHANGELOG"
    echo "Declare project-specific skills with:" >> "$CHANGELOG"
    echo '```' >> "$CHANGELOG"
    printf 'printf '\''%%s\\n'\''' >> "$CHANGELOG"
    for s in $REMOVED_SKILLS; do printf ' %s' "$s" >> "$CHANGELOG"; done
    echo " >> pipekit/.local-skills" >> "$CHANGELOG"
    echo '```' >> "$CHANGELOG"
    echo "" >> "$CHANGELOG"
  fi

  if [ -z "$NEW_SKILLS" ] && [ -z "$UPDATED_SKILLS" ] && [ -z "$REMOVED_SKILLS" ]; then
    echo "No skill changes." >> "$CHANGELOG"
    echo "" >> "$CHANGELOG"
  fi

  echo "## Method Docs" >> "$CHANGELOG"
  if [ -n "$UPDATED_FILES" ]; then
    for f in $UPDATED_FILES; do
      echo "- \`$f\` — updated" >> "$CHANGELOG"
    done
  else
    echo "No doc changes." >> "$CHANGELOG"
  fi
  echo "" >> "$CHANGELOG"

  echo "## Config" >> "$CHANGELOG"
  # Report template config KEYS the project hasn't set yet. Compare key PRESENCE,
  # NOT whole rows. The old check diffed full `| **Key** | value |` rows between
  # template and project, which garbled the section two ways (a consumer, 2026-07):
  #   1. The template ships placeholder values, so every field a project actually
  #      filled in differed from its placeholder → falsely reported as "new".
  #   2. A project written in code-block form (`Key: value`) matched zero `| **Key** |`
  #      rows, so the diff dumped the ENTIRE template as "new fields".
  # Fix: take the template's declared keys (its bolded table-row keys) and treat each
  # as present if the project names it in EITHER form — `**Key**` (table) or `Key:`
  # (code-block). Erring toward "present" under-reports rather than dumps.
  if [ -f "$PROJECT_ROOT/method.config.md" ] && [ -f "$TEMP/method.config.template.md" ]; then
    proj="$PROJECT_ROOT/method.config.md"
    new_fields=""
    while IFS= read -r key; do
      [ -z "$key" ] && continue
      if grep -qiF -- "**$key**" "$proj" 2>/dev/null; then continue; fi
      if grep -qiF -- "$key:"    "$proj" 2>/dev/null; then continue; fi
      new_fields="$new_fields
- **$key**"
    done < <(grep -oE '^\| \*\*[^*]+\*\*' "$TEMP/method.config.template.md" 2>/dev/null \
               | sed -E 's/^\| \*\*[[:space:]]*//; s/[[:space:]]*\*\*$//' | sort -u || true)
    if [ -n "$new_fields" ]; then
      echo "Template keys not set in your method.config.md (add if the capability applies):" >> "$CHANGELOG"
      printf '%s\n' "$new_fields" | sed '/^$/d' >> "$CHANGELOG"
    else
      echo "No new config fields — method.config.md already has every template key." >> "$CHANGELOG"
    fi
  else
    echo "No config comparison available." >> "$CHANGELOG"
  fi
  echo "" >> "$CHANGELOG"
  echo "---" >> "$CHANGELOG"
  echo "_Read by \`/pipekit-update\` for reconciliation. Safe to delete after review._" >> "$CHANGELOG"

  if [ -n "$OVERRIDES_APPLIED" ] || [ -n "$OVERRIDE_DRIFT" ]; then
    echo "" >> "$CHANGELOG"
    echo "## Overrides" >> "$CHANGELOG"
    if [ -n "$OVERRIDES_APPLIED" ]; then
      echo "### Applied" >> "$CHANGELOG"
      for o in $OVERRIDES_APPLIED; do
        echo "- \`$o\`" >> "$CHANGELOG"
      done
    fi
    if [ -n "$OVERRIDE_DRIFT" ]; then
      echo "### Drift (review required)" >> "$CHANGELOG"
      for o in $OVERRIDE_DRIFT; do
        echo "- \`$o\` — upstream changed; verify override is still correct" >> "$CHANGELOG"
      done
    fi
  fi

  echo ""
  echo "Changelog written to: pipekit/.sync-changelog.md"

  # Self-heal: ensure the transient changelog is gitignored. It's regenerated
  # on every sync, so committing it is pure history noise (the method content
  # itself stays committed — worktrees + reproducibility depend on that).
  GITIGNORE="$PROJECT_ROOT/.gitignore"
  if [ -f "$GITIGNORE" ] && ! grep -qxF 'pipekit/.sync-changelog.md' "$GITIGNORE"; then
    printf '\n# Pipekit sync changelog (regenerated each sync; not version-controlled)\npipekit/.sync-changelog.md\n' >> "$GITIGNORE"
    echo "Added pipekit/.sync-changelog.md to .gitignore"
  fi
fi

# Clean up snapshot
rm -rf "$SNAP"

# --- v2.4.3: install-lag check ---
# When the synced bin/pk differs from the globally-installed pk on PATH,
# warn (or auto-install with --auto-install). Closes the lag-bug anchor:
# Pendragon 2026-05-13, where ~/.local/bin/pk was at pk 2.3.2 but the
# synced bin/pk was 2.4.2, silently bypassing the v2.3.3 state-ladder
# gate. cmp -s follows symlinks, so symlinked installs that already point
# at the synced file produce no warning.
if ! $DRY_RUN && [ -f "$PROJECT_ROOT/bin/pk" ]; then
  install_lag=""
  for installed in "$HOME/.local/bin/pk" "/usr/local/bin/pk"; do
    if [ -e "$installed" ] && ! cmp -s "$installed" "$PROJECT_ROOT/bin/pk" 2>/dev/null; then
      install_lag="$installed"
      break
    fi
  done
  if [ -n "$install_lag" ]; then
    echo ""
    if $AUTO_INSTALL; then
      echo "→ --auto-install: refreshing $install_lag from synced bin/pk"
      if bash "$PROJECT_ROOT/bin/pk" install --force; then
        :
      else
        echo "  ⚠ pk install --force reported non-zero — re-run manually:"
        echo "    bash $PROJECT_ROOT/bin/pk install --force"
      fi
    else
      echo "⚠ Installed pk ($install_lag) differs from synced bin/pk."
      echo "  Run 'pk install --force' from this repo to refresh the global command,"
      echo "  or re-run sync-method.sh with --auto-install for unattended sync."
    fi
  fi
fi

# --- Summary ---
echo ""
echo "=== Sync Complete ==="
if $DRY_RUN; then
  echo "Dry run: $CHANGES items would change"
  echo "Remove --dry-run to apply"
else
  echo "Synced from: $METHOD_REPO @ $REF"
  if [ -n "$OVERRIDE_DRIFT" ]; then
    echo ""
    echo "⚠ Override drift detected on:$OVERRIDE_DRIFT"
    echo "  Upstream changed files you override. Review before committing."
  fi
  echo ""
  echo "Next steps:"
  echo "  1. Review pipekit/.sync-changelog.md for what changed"
  echo "  2. Run /pipekit-update reconciliation (restart Claude Code first)"
  echo "  3. Commit the synced files"
fi

if [ "$SYNC_ERRORS" -gt 0 ]; then
  echo "" >&2
  echo "✗ $SYNC_ERRORS error(s) — see the ERROR line(s) above; the affected file was not written." >&2
  exit 1
fi
