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
#
# What it syncs:
#   pipekit/sop/        <- SOPs (Code Quality, Git, Linear, Skills, VBW)
#   pipekit/templates/  <- Spec and review templates
#   pipekit/method.md   <- The deeper methodology overview
#   pipekit/RUNBOOK.md  <- The one-page operational doc (v2.3.1+)
#   pipekit/GUIDE.md    <- The full instruction manual
#   pipekit/STARTUP.md  <- The bootstrap reference
#   .claude/skills/    <- Portable skills (won't touch project-specific ones)
#
# What it does NOT touch:
#   pipekit/decisions/       <- Project-specific ADRs
#   .claude/rules/          <- Project coding conventions
#   .claude/skills/{local}  <- Project-specific skills
#   .vbw-planning/          <- Project state
#   method.config.md        <- Project configuration
#
# Overrides (sync-safe customization):
#   .claude/overrides/skills/<name>/skill.md      <- full-file replacement
#   .claude/overrides/sop/<file>.md               <- full-file replacement
#   .claude/overrides/method.md.patch             <- unified diff applied to method.md
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
# sync into Pipekit if the cwd's origin matches METHOD_REPO. RS-Vault
# v2.5.0 migration surfaced this.
PROJECT_ROOT="${PWD:-$(pwd)}"

# Parse flags without mutating $@ — the self-update guard below re-execs with
# "$@", and a shift here would silently drop --dry-run across the re-exec.
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --auto-install) AUTO_INSTALL=true ;;
    --target=*) PROJECT_ROOT="${arg#--target=}" ;;
    -*) echo "WARN: unknown flag: $arg" >&2 ;;
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

# --- Sync method docs ---
echo ""
echo "Method docs:"
mkdir -p "$PROJECT_ROOT/pipekit"
sync_dir "$TEMP/sop" "$PROJECT_ROOT/pipekit/sop" "sop/"
sync_dir "$TEMP/templates" "$PROJECT_ROOT/pipekit/templates" "templates/"
sync_file "$TEMP/method.md" "$PROJECT_ROOT/pipekit/method.md" "method.md"
sync_file "$TEMP/RUNBOOK.md" "$PROJECT_ROOT/pipekit/RUNBOOK.md" "RUNBOOK.md"
sync_file "$TEMP/GUIDE.md" "$PROJECT_ROOT/pipekit/GUIDE.md" "GUIDE.md"
sync_file "$TEMP/STARTUP.md" "$PROJECT_ROOT/pipekit/STARTUP.md" "STARTUP.md"

# --- Sync Pipekit hook scripts (VBW lifecycle integration) ---
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
fi

# --- Sync v2 templates ---
if [ -d "$TEMP/templates/v2" ]; then
  mkdir -p "$PROJECT_ROOT/pipekit/templates/v2"
  sync_dir "$TEMP/templates/v2" "$PROJECT_ROOT/pipekit/templates/v2" "templates/v2/"
fi

# --- Sync canonical .claude/rules/ files ---
# Contract: Pipekit owns five canonical rule files prefixed `pipekit-`
# (pipekit-discipline, pipekit-tooling, pipekit-security, pipekit-migrations,
# pipekit-cmux) plus the README that documents the hub-and-spoke model.
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
if [ -d "$TEMP/templates/rules" ]; then
  echo ""
  echo "Canonical rules (.claude/rules/):"
  mkdir -p "$PROJECT_ROOT/.claude/rules"
  for canonical in README.md pipekit-discipline.md pipekit-tooling.md pipekit-security.md pipekit-migrations.md pipekit-cmux.md; do
    if [ -f "$TEMP/templates/rules/$canonical" ]; then
      sync_file "$TEMP/templates/rules/$canonical" "$PROJECT_ROOT/.claude/rules/$canonical" ".claude/rules/$canonical"
    fi
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

# --- Sync canonical .claude/hooks/ + register them ---
# Pipekit owns the advisory commit-format hook (re-homed from the retired VBW
# plugin so the {type}({scope}): {desc} nudge survives plugin removal). Ship the
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

  # Register validate-commit.sh in .claude/settings.json (idempotent).
  SETTINGS="$PROJECT_ROOT/.claude/settings.json"
  HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/validate-commit.sh'
  if [ -f "$TEMP/templates/hooks/validate-commit.sh" ]; then
    if ! command -v jq >/dev/null 2>&1; then
      echo "  NOTE jq not found — register the commit-format hook in .claude/settings.json manually (snippet in templates/hooks/validate-commit.sh header)."
    elif [ -f "$SETTINGS" ] && ! jq empty "$SETTINGS" >/dev/null 2>&1; then
      echo "  NOTE .claude/settings.json is not valid JSON — register the commit-format hook manually."
    elif [ -f "$SETTINGS" ] && jq -e '[.. | .command? // empty] | any(type=="string" and test("validate-commit\\.sh"))' "$SETTINGS" >/dev/null 2>&1; then
      echo "  OK validate-commit.sh already registered in .claude/settings.json"
    elif $DRY_RUN; then
      echo "  WOULD REGISTER validate-commit.sh in .claude/settings.json"
      CHANGES=$((CHANGES + 1))
    else
      [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
      tmp=$(mktemp)
      if jq --arg cmd "$HOOK_CMD" '
            (.hooks //= {})
            | (.hooks.PostToolUse //= [])
            | .hooks.PostToolUse += [{matcher:"Bash",hooks:[{type:"command",command:$cmd,timeout:10}]}]
          ' "$SETTINGS" > "$tmp" 2>/dev/null && mv "$tmp" "$SETTINGS"; then
        echo "  REGISTERED validate-commit.sh in .claude/settings.json"
        CHANGES=$((CHANGES + 1))
      else
        rm -f "$tmp"
        echo "  NOTE could not auto-register validate-commit.sh — add it to .claude/settings.json manually."
      fi
    fi
  fi
fi

# --- Sync portable skills ---
echo ""
echo "Portable skills:"

# Get list of portable skills from method repo
PORTABLE_SKILLS=$(ls -d "$TEMP/skills/"*/ 2>/dev/null | xargs -I{} basename {})

for skill in $PORTABLE_SKILLS; do
  src="$TEMP/skills/$skill"
  dst="$PROJECT_ROOT/.claude/skills/$skill"

  if [ ! -d "$src" ]; then
    continue
  fi

  # Track new vs updated
  if [ ! -d "$dst" ]; then
    NEW_SKILLS="$NEW_SKILLS $skill"
  elif ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
    UPDATED_SKILLS="$UPDATED_SKILLS $skill"
  fi

  mkdir -p "$dst"

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
    if [ ! -d "$TEMP/skills/$existing_skill" ] && [ -f "$existing_skill_dir/skill.md" ]; then
      if [ -f "$LOCAL_MANIFEST" ] && grep -qx "$existing_skill" "$LOCAL_MANIFEST" 2>/dev/null; then
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

  # Skill overrides: .claude/overrides/skills/<name>/skill.md
  if [ -d "$OVERRIDES_DIR/skills" ]; then
    while IFS= read -r -d '' override_file; do
      skill_name=$(basename "$(dirname "$override_file")")
      target="$PROJECT_ROOT/.claude/skills/$skill_name/$(basename "$override_file")"
      apply_override "$override_file" "$target" "skills/$skill_name/$(basename "$override_file")"
    done < <(find "$OVERRIDES_DIR/skills" -type f -name '*.md' -print0 2>/dev/null)
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
  # Compare method files
  for f in method.md RUNBOOK.md GUIDE.md STARTUP.md; do
    dst="$PROJECT_ROOT/pipekit/$f"
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
      if [ -f "$PROJECT_ROOT/.claude/skills/$s/skill.md" ]; then
        desc=$(grep '^description:' "$PROJECT_ROOT/.claude/skills/$s/skill.md" 2>/dev/null | head -1 | sed 's/^description: *//')
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
  # template and project, which garbled the section two ways (RS-Vault, 2026-07-20):
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
